extends SceneTree

const L10n := preload("res://scenes/localization.gd")
const Settings := preload("res://scenes/game_settings.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	Settings.path_override = "res://.godot/localization_setup_settings.cfg"
	Settings._cfg = null
	PlayerProfile.path_override = "res://.godot/localization_setup_profile.cfg"
	_run.call_deferred()

func check(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: ", why)

func shot(file: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + file)

func button(node: Node, source: String) -> Button:
	if node is Button and node.text == source:
		return node
	for child in node.get_children():
		var found := button(child, source)
		if found != null:
			return found
	return null

func press(control: Button) -> void:
	control.button_pressed = true
	control.pressed.emit()

func _run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(960, 540))
	L10n.set_locale("en")
	PlayerProfile.save_local({"name": "Tester", "emblem": ""})
	PlayerProfile.save_ban("")
	var menu := SetupScreen.new(SetupScreen.PAGE_ONLINE)
	root.add_child(menu)
	for i in 14:
		await process_frame
	var boxes := menu._col.find_children("*", "CheckBox", true, false)
	check(boxes.size() == 18, "all half-decks available")
	var drow := button(menu._col, "DROW") as CheckBox
	drow.button_pressed = true
	press(button(menu._col, "3"))
	var drow_id := drow.get_instance_id()
	var saved := FileAccess.get_file_as_string(PlayerProfile.path())
	L10n.set_locale("ru")
	check(drow.text == "ДРОУ" and drow.get_instance_id() == drow_id and drow.button_pressed, "half-deck name and selection preserved")
	check(PlayerProfile.ban() == "drow" and FileAccess.get_file_as_string(PlayerProfile.path()) == saved, "language writes no ban or profile data")
	check(menu._match_count == 3 and menu._match_market_text() == "Market: RANDOM 3.", "search mode ID preserved")
	check(drow.tooltip_text.contains("DROW") and drow.tooltip_text.contains("возвышение"), "bilingual deck tooltip")
	check(button(menu._col, "ДЕМОНЫ").tooltip_text.contains("Безумных изгоев"), "outcast term preserved")
	await shot("localization_search_ru.png")
	L10n.set_locale("en")
	check(drow.text == "DROW" and drow.tooltip_text == SetupScreen.DECK_TIPS.drow, "English half-deck presentation restored")
	menu.show_page(SetupScreen.PAGE_HOTSEAT)
	var newera := button(menu._col, "NEW ERA")
	press(newera)
	press(menu._new_era_buttons.freljord)
	press(menu._new_era_buttons.piltover)
	press(button(menu._col, "4"))
	press(button(menu._col, "BOTS"))
	var god := button(menu._col, "GOD MODE")
	god.button_pressed = true
	var chosen := menu._chosen_mode()
	var selected_id := (menu._new_era_buttons.freljord as Button).get_instance_id()
	L10n.set_locale("ru")
	check(menu._chosen_mode() == chosen and menu._count == 4 and menu._bots and menu._god, "game options preserved")
	check(menu._new_era_pair == ["freljord", "piltover"] and menu._new_era_row.visible, "New Era pair and mode preserved")
	check(menu._new_era_buttons.freljord.text == "ДОЛИНА ЛЕДЯНОГО ВЕТРА" and menu._new_era_buttons.freljord.get_instance_id() == selected_id, "New Era button translated in place")
	check(god.tooltip_text.contains("влияние и ПО") and god.button_pressed, "god mode tooltip and state")
	var message := SetupScreen.mode_message(chosen)
	check(L10n.text(message.l10n_key, message.parameters) == "НОВАЯ ЭРА (ГЛУБОКОВОДЬЕ + ДОЛИНА ЛЕДЯНОГО ВЕТРА)", "composite mode translated")
	var received: Array = []
	menu.started.connect(func(ids, mode, bots, teams, god_mode): received.assign([ids, mode, bots, teams, god_mode]))
	menu._action.pressed.emit()
	check(received == [GameScreen.player_ids_for(4), chosen, true, false, true], "start submits stable values")
	await shot("localization_newera_ru.png")
	L10n.set_locale("en")
	for mode: String in GameSetup.MODES + [chosen, "unknown-mode"]:
		var mode_message := SetupScreen.mode_message(mode)
		check(L10n.text(mode_message.l10n_key, mode_message.get("parameters", {})) == SetupScreen.mode_title(mode), "English mode " + mode)
	var net := NetSession.new()
	var lobby := LobbyScreen.new(net, "join_code")
	root.add_child(lobby)
	lobby.set_process(false)
	var col := VBoxContainer.new()
	lobby.add_child(col)
	lobby._description(col, "lobby.description", chosen)
	L10n.set_locale("ru")
	check(col.get_child(0).text.contains("НОВАЯ ЭРА (ГЛУБОКОВОДЬЕ + ДОЛИНА ЛЕДЯНОГО ВЕТРА)"), "lobby mode updates with selected decks")
	lobby.free()
	net.free()
	menu.free()
	await process_frame
	L10n.set_locale("en")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProfile.path()))
	print("setup localization: passed %d, failed %d" % [passed, failed])
	quit(1 if failed else 0)
