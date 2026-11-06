extends SceneTree

const L10n := preload("res://scenes/localization.gd")
const GameText := preload("res://scenes/game_text.gd")
const Settings := preload("res://scenes/game_settings.gd")
class FakeNet extends NetSession:
	var pauses: Array = []
	var reconnects := 0
	var intents: Array = []
	func request_pause(on: bool) -> void:
		pauses.append(on)
	func reconnect() -> int:
		reconnects += 1
		return ERR_CANT_CONNECT
	func send_intent(intent: Intent) -> void:
		intents.append(intent)
var passed := 0
var failed := 0
func _initialize() -> void:
	Settings.path_override = "res://.godot/localization_turn_piles.cfg"
	Settings._cfg = null
	PlayerProfile.path_override = "res://.godot/localization_turn_piles_profile.cfg"
	_run.call_deferred()
func check(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: ", why)
func shot(file: String) -> void:
	# Containers settle over deferred frames even when no screenshot is taken.
	for i in 8:
		await process_frame
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + file)
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(960, 540)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(960, 540))
	L10n.set_locale("en")
	PlayerProfile.seats = {"red": {"name": "START"}}
	var screen := GameScreen.new(7, ["drow", "dragons"], ["red", "blue"])
	root.add_child(screen)
	screen.set_process(false)
	var guard := 0
	while screen.server.resolver.is_waiting() and guard < 20:
		guard += 1
		var pending: PendingDecision = screen.server.resolver.pending
		screen.server.apply_intent(Intent.make_decision(pending.player_id, pending.legal_options[0]))
	var state := screen.server.state
	var pid := state.current_player()
	state.players[pid].deck.inner_circle.assign(["48306", "48320"])
	screen.viewer_id = pid
	var view := StateView.for_player_with_pending(state, pid, screen.server.resolver.pending)
	screen.refresh(view)
	await create_timer(1.6).timeout
	var before := StateSerializer.to_json(state, pid, screen.server.resolver.pending)
	screen._space_held = true
	screen._space_hold = 0.7
	var clock := [screen._time_left, screen._decision_left, screen._space_hold]
	screen._on_pause_pressed()
	var toast_tween := screen._note_toast._tween
	L10n.set_locale("ru")
	check(screen._pause_button.tr(screen._pause_button.text) == "ИГРАТЬ" and screen._local_pause, "local pause preserved and relabeled")
	check([screen._time_left, screen._decision_left, screen._space_hold] == clock and screen._space_held, "clocks and Space hold preserved")
	check(screen._note_toast._tween == toast_tween and screen._note_toast.last_text() == "Пауза: таймеры и боты остановлены.", "toast translates without restarting")
	check(screen._end_label.tr(screen._end_label.text) == "КОНЕЦ ХОДА" and screen._menu_button.tr(screen._menu_button.text) == "МЕНЮ", "game buttons translated")
	check(screen._deck_tracker._deck_label.text == "КОЛОДА" and screen._deck_tracker._discard_label.text == "СБРОС" and screen._pile_inner._caption.text == "КРУГ", "pile labels translated")
	var banner := screen._turn_banner
	banner.show_message({"l10n_key": "game.other_turn", "parameters": {"name": GameText.player_message("blue", true)}}, Color.BLUE, Rect2(screen._board_area.position, screen._board_area.size))
	await create_timer(0.05).timeout
	var tween := banner._tween
	var elapsed := tween.get_total_elapsed_time()
	L10n.set_locale("en")
	check(banner._label.text == "BLUE'S TURN" and banner._tween == tween and tween.get_total_elapsed_time() >= elapsed, "banner translates without replaying animation")
	L10n.set_locale("ru")
	check(banner._label.text == "ХОДИТ СИНИЙ" and banner.visible, "Russian turn banner")
	banner.show_message({"l10n_key": "game.forced_who", "parameters": {"name": GameText.player_message("purple", true), "by": GameText.player_message("green", true)}}, Color.PURPLE, Rect2(screen._board_area.position, screen._board_area.size))
	await shot("localization_turn_ru.png")
	check(banner.get_combined_minimum_size().x <= screen._board_area.size.x and banner._label.text.contains("\n"), "long Russian banner wraps within board")
	screen._open_pile("inner")
	var cards := screen._pile_dialog._grid.get_children()
	var card_ids := cards.map(func(c): return c.get_instance_id())
	L10n.set_locale("en")
	L10n.set_locale("ru")
	check(screen._pile_dialog.visible and screen._pile_dialog._grid.get_children().map(func(c): return c.get_instance_id()) == card_ids and screen._pile_dialog._title.text.contains("Внутренний круг — 2 карты"), "open inner circle and cards preserved")
	check(StateSerializer.to_json(state, pid, screen.server.resolver.pending) == before, "UI language sends no game action")
	screen._pile_dialog.close_pile()
	var pile := PileDialog.new()
	pile.theme = PixelTheme.theme()
	root.add_child(pile)
	var ids: Array = []
	for i in 45:
		ids.append("48306" if i % 2 == 0 else "48320")
	var original := ids.duplicate()
	pile.open_pile("Devoured cards", ids, "", "48320", true, {"l10n_key": "game.pile_devoured_title"})
	await process_frame
	pile._scroll.scroll_vertical = 50
	await process_frame
	var scroll := pile._scroll.scroll_vertical
	var controls := pile._grid.get_children().map(func(c): return c.get_instance_id())
	L10n.set_locale("en")
	check(pile._title.text == "Devoured cards — 45 cards\nGold card: you may recruit it this turn", "English offer title unchanged")
	L10n.set_locale("ru")
	await process_frame
	check(pile.visible and pile._scroll.scroll_vertical == scroll and pile._grid.get_children().map(func(c): return c.get_instance_id()) == controls, "pile scroll and card controls preserved")
	check(ids == original and pile._grid.get_child(0).card_id == "48320" and pile._title.text.contains("45 карт"), "offer order, source data and count preserved")
	await shot("localization_pile_ru.png")
	var offered: Array = []
	pile.offer_pressed.connect(func(cid): offered.append(cid))
	pile._grid.get_child(0).pressed.emit("48320")
	check(offered == ["48320"] and not pile.visible, "offer emits original card ID")
	pile.free()
	for pair in [[0, "0 карт"], [1, "1 карта"], [2, "2 карты"], [5, "5 карт"], [11, "11 карт"], [21, "21 карта"], [22, "22 карты"], [25, "25 карт"], [101, "101 карта"], [111, "111 карт"]]:
		var msg := GameText.card_count_message(pair[0])
		check(L10n.text(msg.l10n_key, msg.parameters) == pair[1], "Russian card count " + str(pair[0]))
	L10n.set_locale("en")
	var twenty_one := GameText.card_count_message(21)
	check(L10n.text(twenty_one.l10n_key, twenty_one.parameters) == "21 cards", "English plural remains correct")
	screen.hide()
	var net := FakeNet.new()
	var remote := GameScreen.new(0, [], [], GameSetup.MODE_STANDARD, {"session": net, "seat": pid, "board": screen.board_data, "view": view})
	root.add_child(remote)
	remote.set_process(false)
	remote._on_pause_changed({"absent": {"blue": 120.0}, "by": "", "left": 0.0})
	remote._tick_pause(12.2)
	var row: HBoxContainer = remote._pause_lines.get_child(0)
	var row_id := row.get_instance_id()
	var time: String = row.get_child(1).text
	var pause_elapsed := remote._pause_elapsed
	L10n.set_locale("ru")
	check(remote.is_paused() and remote._pause_elapsed == pause_elapsed and remote._pause_lines.get_child(0).get_instance_id() == row_id and row.get_child(1).text == time, "network pause timer and rows preserved")
	check(row.get_child(0).text == "СИНИЙ ОТКЛЮЧИЛСЯ" and remote._pause_hint.text.contains("Рейтинг не изменится"), "disconnect pause translated")
	check(net.pauses.is_empty() and net.intents.is_empty(), "language switch sends no network command")
	remote._on_pause_changed({"absent": {}, "by": pid, "left": 90.0})
	await shot("localization_pause_ru.png")
	check(remote._pause_resume.visible and remote._pause_lines.get_child(0).get_child(0).text == "ПАУЗУ ВКЛЮЧИЛ: ВЫ", "own pause and resume access preserved")
	remote._pause_resume.pressed.emit()
	check(net.pauses == [false], "resume sends original boolean action")
	net.connection_lost.emit("Could not connect")
	check(remote._reconnect_status.text == "Не удалось подключиться." and remote._note_toast.last_text() == "Не удалось подключиться.", "connection status and toast translated")
	net.connection_lost.emit("Different game version (yours 3, server 4): update the game")
	await shot("localization_reconnect_ru.png")
	check(remote._reconnect_banner.get_global_rect().position.x >= 0 and remote._reconnect_banner.get_global_rect().end.x <= root.size.x and remote._reconnect_status.size.y > PixelTheme.LINE_H, "long reconnect reason wraps inside viewport: " + str(remote._reconnect_banner.get_global_rect()) + " root=" + str(root.size) + " label=" + str(remote._reconnect_status.size))
	var reconnect_button: Button = remote._reconnect_banner.find_children("*", "Button", true, false)[0]
	reconnect_button.pressed.emit()
	L10n.set_locale("en")
	check(net.reconnects == 1 and remote._reconnect_status.text == "Could not reconnect.", "failed reconnect switches language without retry")
	remote.free()
	net.free()
	screen.free()
	await process_frame
	PlayerProfile.seats = {}
	L10n.set_locale("en")
	print("turn/piles localization: passed %d, failed %d" % [passed, failed])
	quit(1 if failed else 0)
