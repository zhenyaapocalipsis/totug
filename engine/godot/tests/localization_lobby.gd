extends SceneTree

const L10n := preload("res://scenes/localization.gd")
const NetworkText := preload("res://scenes/network_text.gd")
const Settings := preload("res://scenes/game_settings.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	Settings.path_override = "res://.godot/localization_lobby.cfg"
	Settings._cfg = null
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
	var net := NetSession.new()
	var lobby := LobbyScreen.new(net, "join_code")
	root.add_child(lobby)
	lobby.set_process(false) # Exercise messages without polling a real network peer.
	lobby._code_edit.text = "Q7RW"
	lobby._server_edit.text = "test.invalid"
	var code_id := lobby._code_edit.get_instance_id()
	lobby._on_queue_changed(1, 4)
	var since: int = lobby._searching_since
	check(lobby._status.text.contains("Looking for players: 1 of 4."), "English queue")
	L10n.set_locale("ru")
	check(lobby._status.text.contains("Поиск игроков: 1 из 4."), "Russian queue immediately")
	check(lobby._searching_since == since, "search timer unchanged")
	check(lobby._code_edit.get_instance_id() == code_id and lobby._code_edit.text == "Q7RW" and lobby._server_edit.text == "test.invalid", "inputs preserved")
	lobby._on_connection_lost("There is no room Q7RW")
	check(lobby._status.text == "Комната Q7RW не найдена.", "legacy refusal localized")
	L10n.set_locale("en")
	check(lobby._status.text == "There is no room Q7RW.", "refusal switches back")
	lobby._on_connection_lost("unrecognized diagnostic 42")
	L10n.set_locale("ru")
	check(lobby._status.text == "unrecognized diagnostic 42.", "unknown reason preserved")
	for source in ["Could not connect", "The connection to the game was lost", NetSession.NAME_TAKEN % "START", "Different game version (yours 3, server 4): update the game", "Port 7780 is open on your router.", "Router refused to open port 7780.", "Your provider gives no public address (10.0.0.1)."]:
		var message := NetworkText.message(source)
		check(message.l10n_key != "network.unknown", "known reason " + source)
		L10n.set_locale("en")
		check(L10n.text(message.l10n_key, message.get("parameters", {})) == source, "English reason preserved")
	L10n.set_locale("ru")
	net.seat = "red"
	net.profiles = {"blue": {"rating": 1000, "games": 12, "wins": 5}}
	lobby._on_lobby_changed(["red"], 2, "Q7RW", "red")
	check(lobby._code_label.text == "КОМНАТА  Q7RW", "room code preserved")
	check(lobby._status.text.contains("1 из 2"), "waiting room counts")
	lobby._on_lobby_changed(["red", "blue"], 2, "Q7RW", "red")
	check(lobby._status.text == "Все собрались — нажмите НАЧАТЬ.", "full room")
	check(not lobby._start_button.disabled, "start enablement preserved")
	var translated_badge := false
	for child in lobby._seats.get_children():
		if child is Control and child.tooltip_text.contains("Партий: 12, побед: 5"):
			translated_badge = true
	check(translated_badge, "rating tooltip localized")
	lobby._internet = Label.new()
	lobby._internet_note = Label.new()
	lobby.add_child(lobby._internet)
	lobby.add_child(lobby._internet_note)
	lobby._on_upnp_finished("203.0.113.1", "Port 7780 is open on your router.")
	check(lobby._internet.text == "203.0.113.1" and lobby._internet_note.text.contains("Порт 7780 открыт"), "address and UPnP translation")
	L10n.set_locale("en")
	check(lobby._internet.text == "203.0.113.1" and lobby._internet_note.text.contains("Port 7780 is open"), "UPnP language switch")
	lobby._on_friends({"friends": [{"name": "START", "status": "ONLINE"}]})
	var friend: Button = lobby._invites.get_child(0)
	L10n.set_locale("ru")
	check(friend.text == "START" and friend.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED, "friend name not translated")
	lobby._on_connection_lost("Could not connect")
	if DisplayServer.get_name() != "headless":
		lobby._internet.hide()
		lobby._internet_note.hide()
		for i in 18:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/localization_lobby_ru.png")
	var listeners := L10n.events.changed.get_connections().size()
	lobby.free()
	check(L10n.events.changed.get_connections().size() < listeners, "bindings freed with lobby")
	L10n.set_locale("en")
	net.free()
	print("lobby localization: passed %d, failed %d" % [passed, failed])
	quit(1 if failed else 0)
