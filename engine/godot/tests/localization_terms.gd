extends SceneTree
const L10n := preload("res://scenes/localization.gd")
const Terms := preload("res://scenes/term_text.gd")
const Decisions := preload("res://scenes/decision_text.gd")
var passed := 0
var failed := 0
func _initialize() -> void:
 PlayerProfile.path_override = "res://.godot/localization_terms_profile.cfg"
 _run.call_deferred()
func check(ok: bool, why: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  printerr("FAIL: ", why)
func _run() -> void:
 L10n.set_locale("ru")
 check(Decisions.text("GUILE") == "КОВАРСТВО" and Decisions.text("Guile") == "Коварство", "case-preserving aspect labels")
 check(Terms.name_of("CELESTIAL", "ru", "race") == "НЕБОЖИТЕЛЬ" and Terms.name_of("CELESTIAL", "ru", "region") == "НЕБЕСНЫЙ ОРДЕН", "race and region with the same source ID have distinct meanings")
 check(Decisions.text("ILLITHID") == "ИЛЛИТИД", "race label")
 check(Decisions.text("Ravenloft") == "Равенлофт", "region label")
 check(Decisions.text("Explore for Power: put a card into your hand").contains("Сила"), "resource in explore prompt")
 check(Decisions.text("Discard a card to Retain Treefolk").contains("Древолюда"), "Treefolk current Russian name")
 check(Decisions.text("Devotion: put Deva on top of your deck?").contains("Дао"), "legacy Deva prompt refers to current Dao")
 check(Decisions.text("Put Pirate Captain on top of your deck?").contains("Они"), "legacy Pirate Captain prompt refers to current Oni")
 var font := PixelTheme.theme().default_font
 for value: String in Terms.catalog().values():
  for ch: String in value:
   if ch != "\n": check(font.has_char(ch.unicode_at(0)), "native term glyph "+ch)
 var option := OptionCard.new("48306", "GUILE")
 root.add_child(option)
 var ru_image := option._tex.get_image().get_data()
 check(option._source_text == "GUILE", "dynamic source answer unchanged")
 L10n.set_locale("en")
 check(option._tex.get_image().get_data() != ru_image and option._source_text == "GUILE", "dynamic option changes only presentation")
 check(Decisions.text("Devotion: put Deva on top of your deck?").contains("Dao"), "English legacy Dao caption")
 check(Decisions.text("Put Pirate Captain on top of your deck?").contains("Oni"), "English legacy Oni caption")
 check(Decisions.text("unknown future caption") == "unknown future caption", "future English caption preserved")
 var host := Control.new()
 host.theme = PixelTheme.theme()
 root.add_child(host)
 var god := GodPanel.new(["red", "blue"])
 host.add_child(god)
 god.set_count(4)
 god.zone = "inner"
 god.set_search("illithid")
 var english_ids := god.visible_cards()
 god.set_search("иллитид")
 check(god.visible_cards() == english_ids and english_ids.has("50006") and english_ids.has("48702"), "search by Russian and English race includes cards without race in name")
 L10n.set_locale("ru")
 check(god.visible_cards() == english_ids and god._search.text == "иллитид" and god.count == 4 and god.zone == "inner", "locale switch preserves metadata filter and selected actions")
 god.set_search("тщеславие")
 check(god.visible_cards().has("48306"), "Russian aspect search")
 host.free()
 option.free()
 print("localized terms: ", passed, " checks, failed ", failed)
 quit(1 if failed else 0)
