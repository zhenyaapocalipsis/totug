extends SceneTree

const L10n := preload("res://scenes/localization.gd")
const GameText := preload("res://scenes/game_text.gd")
const Settings := preload("res://scenes/game_settings.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	Settings.path_override = "res://.godot/localization_game_panels.cfg"
	Settings._cfg = null
	PlayerProfile.path_override = "res://.godot/localization_game_panels_profile.cfg"
	_run.call_deferred()

func check(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: ", why)

func _run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(960, 540))
	L10n.set_locale("en")
	PlayerProfile.seats = {"red": {"name": "START"}}
	BoardPanel.team_of = {}
	var counter := CounterLabel.make_localized("game.power", Color.RED)
	root.add_child(counter)
	counter.set_value(2, false)
	counter.set_value(8)
	counter._process(0.1)
	counter.set_process(false)
	var animation := [counter._shown, counter._target, counter._roll_left, counter._flash_left, counter._from]
	L10n.set_locale("ru")
	check([counter._shown, counter._target, counter._roll_left, counter._flash_left, counter._from] == animation and counter.is_animating(), "number animation preserved")
	check(counter.text == "СИЛА %d" % counter._shown and counter.target_text() == "СИЛА 8", "counter relabeled at current value")
	counter._process(1.0)
	check(counter.text == "СИЛА 8" and not counter.is_animating(), "counter reaches same target")
	counter.free()
	L10n.set_locale("en")
	var screen := GameScreen.new(7, ["drow", "dragons"], ["red", "blue", "green", "purple"])
	root.add_child(screen)
	screen.set_process(false)
	var guard := 0
	while screen.server.resolver.is_waiting() and guard < 20:
		guard += 1
		var pending: PendingDecision = screen.server.resolver.pending
		screen.server.apply_intent(Intent.make_decision(pending.player_id, pending.legal_options[0]))
	var state := screen.server.state
	var pid := state.current_player()
	state.players[pid].power = 8
	state.players[pid].influence = 6
	state.players[pid].troops_in_barracks = 0
	state.turn_flags["olaf"] = pid
	state.turn_flags["olaf_locked"] = 3
	state.players["red"].add_trophy("white")
	state.players["red"].add_trophy("blue")
	screen.viewer_id = pid
	var view := StateView.for_player_with_pending(state, pid, screen.server.resolver.pending)
	screen.refresh(view)
	await create_timer(1.6).timeout
	for i in 12:
		await process_frame
	var before := StateSerializer.to_json(state, pid, screen.server.resolver.pending)
	var powers := [screen._res_power._target, screen._res_influence._target]
	var power_id := screen._res_power.get_instance_id()
	var barracks_id: int = screen._barracks._boxes[pid].panel.get_instance_id()
	L10n.set_locale("ru")
	await process_frame
	check(StateSerializer.to_json(state, pid, screen.server.resolver.pending) == before, "game state and legal answers unchanged")
	check([screen._res_power._target, screen._res_influence._target] == powers and screen._res_power.get_instance_id() == power_id, "resource controls and targets preserved")
	check(screen._res_power.target_text() == "СИЛА 5" and screen._res_influence.target_text() == "ВЛИЯНИЕ 6" and screen._res_ice.text == "+3 ЛЁД", "ordinary and locked power separated in Russian")
	check(screen._res_zone.tooltip_text.contains("нельзя тратить на размещение войск"), "ICE restriction translated")
	check(screen._barracks._boxes[pid].panel.get_instance_id() == barracks_id and screen._barracks._boxes[pid].panel.tooltip_text.contains("Войска: 0"), "barracks numbers and control preserved")
	check(screen._players_panel._rows.red.name.text == "START" and screen._players_panel._rows.blue.name.text == "СИНИЙ", "custom names literal, default seats localized")
	check(screen._players_panel._rows.red.trophies.tooltip_text == "Трофеи: нейтральные 1, Синий 1", "trophy summary translated")
	check(screen._deploy_vp_button.text == "Разместить: 1 ПО", "empty barracks action translated")
	if DisplayServer.get_name() != "headless":
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/localization_game_panels_ru.png")
	L10n.set_locale("en")
	await process_frame
	check(screen._res_power.target_text() == "POWER 5" and screen._res_ice.text == "+3 ICE" and screen._players_panel._rows.blue.name.text == "BLUE", "English resource and seat labels restored")
	check(screen._res_zone.tooltip_text == GameScreen.ICE_TIP, "English resource tooltip unchanged")
	var panel := PlayersPanel.new()
	panel.theme = PixelTheme.theme()
	panel.size = Vector2(GameScreen.COL, 170)
	root.add_child(panel)
	var choice_view := view.duplicate(true)
	choice_view.pending_decision = {"choice_type": "target_player", "legal_options": ["red", "blue"]}
	panel.update_from_view(choice_view)
	panel._process(0.1)
	panel.set_process(false)
	var blink := panel._blink_time
	var choice_id: int = panel._choice_buttons.blue.get_instance_id()
	var chosen: Array = []
	panel.player_chosen.connect(func(who): chosen.append(who))
	L10n.set_locale("ru")
	check(panel._choice_buttons.blue.get_instance_id() == choice_id and panel._choice_buttons.blue.visible and panel._blink_time == blink and chosen.is_empty(), "player choice and blinking preserved without sending")
	check(panel._choice_buttons.blue.tooltip_text == "Выбрать: Синий", "player choice tooltip translated")
	panel._choice_buttons.blue.pressed.emit()
	check(chosen == ["blue"], "stable player ID emitted")
	choice_view.pending_decision = {"tag": "trophy_hall", "data": {"trophies": ["red|white", "red|blue"]}}
	panel.update_from_view(choice_view)
	var trophy_button: Button = panel._trophy_buttons[0][0]
	var trophy_id := trophy_button.get_instance_id()
	var trophy_digit_id: int = panel._trophy_buttons[0][1].get_instance_id()
	var answer: Array = []
	panel.trophy_chosen.connect(func(index): answer.append(index))
	L10n.set_locale("en")
	check(trophy_button.tooltip_text == "Take a neutral troop from START's trophy hall", "English trophy choice preserved")
	L10n.set_locale("ru")
	check(trophy_button.get_instance_id() == trophy_id and panel._trophy_buttons[0][1].get_instance_id() == trophy_digit_id and trophy_button.tooltip_text == "Взять войско: нейтральные. Зал трофеев: START.", "trophy choice controls preserved")
	trophy_button.pressed.emit()
	check(answer == [0], "stable trophy option index emitted")
	BoardPanel.team_of = {"red": "red", "green": "red", "blue": "blue", "purple": "blue"}
	PlayerProfile.seats = {}
	var team_bar := BarracksBar.new()
	root.add_child(team_bar)
	team_bar.update_from_view(view)
	L10n.set_locale("en")
	check(team_bar._boxes.red.panel.tooltip_text.begins_with("RED TEAM"), "English shared barracks")
	L10n.set_locale("ru")
	check(team_bar._boxes.red.panel.tooltip_text.begins_with("КРАСНАЯ КОМАНДА") and team_bar._boxes.size() == 2 and GameText.player_name("green") == "Красный 2", "shared barracks and team seat display")
	team_bar.free()
	panel.free()
	screen.free()
	await process_frame
	BoardPanel.team_of = {}
	PlayerProfile.seats = {}
	L10n.set_locale("en")
	print("game panels localization: passed %d, failed %d" % [passed, failed])
	quit(1 if failed else 0)
