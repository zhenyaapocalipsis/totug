extends SceneTree

const L10n := preload("res://scenes/localization.gd")
const Settings := preload("res://scenes/game_settings.gd")
var failures := 0


func _initialize() -> void:
	Settings.path_override = "res://.godot/localization_match.cfg"
	Settings._cfg = null
	PlayerProfile.path_override = "res://.godot/localization_match_profile.cfg"
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 540))
	L10n.set_locale("en")
	var screen := GameScreen.new(7)
	root.add_child(screen)
	var guard := 0
	while screen.server.resolver.is_waiting() and guard < 20:
		guard += 1
		var decision: PendingDecision = screen.server.resolver.pending
		screen.server.apply_intent(Intent.make_decision(decision.player_id, decision.legal_options[0]))
	var state: GameState = screen.server.state
	var pid := state.current_player()
	state.players[pid].deck.hand.assign(["48306", "48320", "48426", "49120"])
	screen.viewer_id = pid
	var result := screen.server.apply_intent(Intent.play_card(pid, "48306"))
	screen.refresh(result.views[pid])
	for i in 12:
		await process_frame
	var pending: PendingDecision = screen.server.resolver.pending
	_check(pending != null and pending.choice_type == "choose_option", "card choice open")
	if pending == null:
		quit(1)
		return
	var pending_id := pending.get_instance_id()
	var before := StateSerializer.to_json(state, pid, pending)
	var options := screen._decision_dialog.find_children("*", "Control", true, false).filter(func(node): return node is OptionCard)
	var option_ids := options.map(func(node): return node.get_instance_id())
	_check(options.size() == 2, "two action cards before switching")
	screen._pause_menu.visible = true
	screen._pause_menu.show_settings(true)
	var language: Button = screen._pause_menu.find_child("LanguageButton", true, false)
	language.pressed.emit()
	_check(L10n.locale() == "ru", "switch through in-game settings")
	_check(screen.server.resolver.pending.get_instance_id() == pending_id, "same pending object")
	_check(StateSerializer.to_json(state, pid, screen.server.resolver.pending) == before, "same state and legal answers")
	var after := screen._decision_dialog.find_children("*", "Control", true, false).filter(func(node): return node is OptionCard)
	_check(after.map(func(node): return node.get_instance_id()) == option_ids, "same option controls")
	var old_hold: Variant = Settings.value("hold_seconds")
	Settings.set_value("hold_seconds", 5.0)
	screen._tick_space_hold(0.0)
	_check(screen._end_turn_button.tooltip_text.contains("Space 5 с"), "Russian tooltip uses configured hold duration")
	L10n.set_locale("en")
	_check(screen._end_turn_button.tooltip_text.contains("5 seconds"), "English tooltip uses configured hold duration")
	L10n.set_locale("ru")
	Settings.set_value("hold_seconds", old_hold)
	screen._tick_space_hold(0.0)
	screen._pause_menu.visible = false
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/localization_match_ru.png")
	var chosen: Variant = screen.server.resolver.pending.legal_options[0]
	var answer := screen.server.apply_intent(Intent.make_decision(pid, chosen))
	_check(int(answer.error) == GameServer.Error.OK, "choice still accepted after language switch")
	screen.free()
	for file in [Settings.path_override, PlayerProfile.path_override]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	print("language in match: 9 checks, failed %d" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", description)
