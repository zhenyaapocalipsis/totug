extends SceneTree
const L10n := preload("res://scenes/localization.gd")
const Pages := preload("res://scenes/page_text.gd")
const Settings := preload("res://scenes/game_settings.gd")
var passed := 0
var failed := 0
func _initialize() -> void:
 Settings.path_override = "res://.godot/localization_collection_settings.cfg"
 Settings._cfg = null
 PlayerProfile.path_override = "res://.godot/localization_collection_profile.cfg"
 _run.call_deferred()
func check(ok: bool, why: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  printerr("FAIL: ", why)
func controls(node: Node) -> Array:
 var ids := []
 for child in node.get_children():
  if child is Control: ids.append(child.get_instance_id())
  ids.append_array(controls(child))
 return ids
func screenshot(file: String) -> void:
 if DisplayServer.get_name() == "headless": return
 for i in 8: await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://.godot/" + file)
func _run() -> void:
 if DisplayServer.get_name() != "headless":
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
  DisplayServer.window_set_size(Vector2i(960,540))
 var page_catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/pages_ru.json"))
 for value: String in page_catalog.exact.values():
  for ch: String in value.replace("\n", ""):
   check(PixelTheme.theme().default_font.has_char(ch.unicode_at(0)), "native collection glyph "+ch)
 var cfg := ConfigFile.new()
 cfg.set_value("collection", "dust", 2000)
 cfg.set_value("collection", "boxes", 3)
 cfg.save(PlayerProfile.path())
 L10n.set_locale("en")
 var host := Control.new()
 host.theme = PixelTheme.theme()
 host.size = Vector2(960,540)
 root.add_child(host)
 var page := CollectionPage.new()
 host.add_child(page)
 page.position = Vector2(12,12)
 page.size.x = 936
 page.show_faction("dragons")
 page.select("48426")
 var arts := AltArts.arts_of("48426")
 check(not arts.is_empty(), "alternate art fixture")
 page.select_art(arts[0])
 page.press_art()
 page._back_preview.set_process(false)
 page._back_preview.angle = 1.23
 var pending := page._pending_art
 var data := JSON.stringify(SkinCollection.load_data())
 var selected := page._art_selected
 var nodes := controls(page)
 L10n.set_locale("ru")
 for i in 4: await process_frame
 check(page._dust_label.text == "ПЫЛЬ 2000" and page._boxes_label.text == "ЛУТБОКСЫ 3", "resource captions")
 check(page._section_buttons.SHADERS.text == "ОБРАЗЫ" and page._section_buttons.CARDS.text == "КАРТЫ", "section captions")
 check(page._selected == "48426" and page._art_selected == selected and page._pending_art == pending and pending != "", "card, art and pending confirmation survive")
 check(controls(page) == nodes and is_equal_approx(page._back_preview.angle,1.23), "same controls and flip angle")
 check(JSON.stringify(SkinCollection.load_data()) == data, "locale switch spends no dust or boxes")
 check(page._note.text.contains("Нажмите ещё раз") and page._note.text.contains("Создать") and page._note.text.contains("ЛЕГЕНДАРНЫЙ"), "pending confirmation translates")
 check(Pages.text(" EPIC 1  ON") == " ЭПИЧЕСКИЙ 1  ВКЛ", "rarity, art index and active state")
 check(Pages.text("BOX: ART EPIC 75% / LEGENDARY 21%, SHADER ULTRA 4%; REPEAT = DUST").contains("75%") and Pages.text("BOX: ART EPIC 75% / LEGENDARY 21%, SHADER ULTRA 4%; REPEAT = DUST").begins_with("ШАНСЫ:"), "literal percentage formatting")
 for button: Button in page._faction_buttons.values():
  check(button.get_global_rect().end.x <= 960 and button.get_global_rect().position.x >= 0, "faction tab stays inside viewport")
 await screenshot("localization_collection_ru.png")
 page.show_faction("bandle")
 page.select("49906")
 page.next_form()
 var form_nodes := controls(page)
 L10n.set_locale("en")
 check(page.shown_card()=="49922" and controls(page)==form_nodes, "adult faerie form and controls survive")
 check(page._token_button.text.contains("FAERIE DRAGON YOUTH"), "form caption returns to original")
 L10n.set_locale("ru")
 check(page._token_button.text.contains("ЮНЫЙ ФЕЙСКИЙ ДРАКОН"), "form caption uses Russian card name: "+page._token_button.text)
 var reward := LootBoxReveal.new()
 host.add_child(reward)
 var results: Array[Dictionary] = [
  {"tier":AltArts.tier_of(arts[0]),"art":arts[0],"shader":"","dust":0,"duplicate":false},
  {"tier":"ultra","art":"","shader":"faerie","dust":0,"duplicate":false},
  {"tier":"legendary","art":"","shader":"","dust":150,"duplicate":true}]
 reward.setup(results,2,"48426")
 reward.set_process(false)
 reward._phase="roll"
 reward._t=0.43
 reward._tick=4
 reward._refresh()
 var rewards_json:=JSON.stringify(reward._results)
 var reward_nodes:=controls(reward)
 L10n.set_locale("en")
 check(reward._phase=="roll" and is_equal_approx(reward._t,0.43) and reward._tick==4 and controls(reward)==reward_nodes, "animation timing and objects survive")
 reward._enter("summary")
 reward._dim=1.0
 for i in 4: await process_frame
 var scroll:=reward._scroll
 var summary_nodes:=controls(reward)
 var scroll_y:=scroll.scroll_vertical
 L10n.set_locale("ru")
 for i in 4: await process_frame
 check(reward._scroll==scroll and controls(reward)==summary_nodes and scroll.scroll_vertical==scroll_y, "reward summary and scroll preserved")
 check(reward._title.text=="ОТКРЫТО ЛУТБОКСОВ: 3" and reward._sub.text=="НОВЫХ: 2, +150 ПЫЛИ", "reward summary captions")
 check(JSON.stringify(reward._results)==rewards_json and JSON.stringify(SkinCollection.load_data())==data, "loot data and saved economy unchanged")
 for pic: TextureRect in reward._summary_pics:
  check(pic.texture==reward._mini(reward._summary_pics[pic]), "reward thumbnail follows locale")
 await screenshot("localization_collection_rewards_ru.png")
 host.free()
 DirAccess.remove_absolute(PlayerProfile.path())
 DirAccess.remove_absolute(Settings.path_override)
 print("localized collection: ",passed," checks, failed ",failed)
 quit(1 if failed else 0)
