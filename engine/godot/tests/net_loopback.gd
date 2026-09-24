extends SceneTree

## Сетевой тест (этап 6): хост и клиент в одном процессе, настоящий ENet через
## 127.0.0.1. У каждого своя ветка дерева со своим SceneMultiplayer, поэтому
## относительный путь узла ("Net") у них совпадает — как у двух программ.
##
##   godot --headless --path . --script res://tests/net_loopback.gd
## Последняя строка: "сеть: пройдено N, провалено 0".

const PORT := 7790
const TIMEOUT := 20.0

var host: NetSession
var client: NetSession
var passed := 0
var failed := 0
var _elapsed := 0.0
var _step := "init"

var host_view: Dictionary = {}
var client_view: Dictionary = {}
var host_errors: Array = []
var client_errors: Array = []
var host_chat: Array = []
var client_chat: Array = []
var client_seat := ""
var _spoof_sent := false
var _answered_at := -1
var _turn_player := ""


func _setup() -> void:
	host = _branch("HostSide")
	client = _branch("ClientSide")
	host.game_started.connect(func(_s: String, _b: Dictionary, v: Dictionary): host_view = v)
	client.game_started.connect(func(s: String, b: Dictionary, v: Dictionary):
		client_seat = s
		client_view = v
		check(not (b.get("slots", {}) as Dictionary).is_empty(), "клиент получил геометрию доски"))
	host.result_received.connect(func(e: int, _ev: Array, v: Dictionary):
		host_errors.append(e)
		host_view = v)
	client.result_received.connect(func(e: int, _ev: Array, v: Dictionary):
		client_errors.append(e)
		client_view = v)
	host.chat_received.connect(func(w: String, t: String): host_chat.append([w, t]))
	client.chat_received.connect(func(w: String, t: String): client_chat.append([w, t]))

	check(host.host(PORT, 2, GameSetup.MODE_STANDARD) == OK, "хост открыл порт")
	check(client.join("127.0.0.1", PORT) == OK, "клиент начал подключение")


func _branch(branch_name: String) -> NetSession:
	var branch := Node.new()
	branch.name = branch_name
	root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	var net := NetSession.new()
	net.name = "Net"
	branch.add_child(net)
	return net


func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed > TIMEOUT:
		check(false, "шаг «%s» не завершился за %d с" % [_step, int(TIMEOUT)])
		return _finish()
	match _step:
		"init":
			_setup()
			_step = "connect"
		"connect":
			if host.is_full() and client.seat != "":
				check(client.seat != host.seat, "у клиента свой цвет (%s), не как у хоста" % client.seat)
				host.start_game(4242)
				_step = "started"
		"started":
			if not client_view.is_empty() and not host_view.is_empty():
				_check_hidden_hands()
				_step = "setup"
		"setup":
			# Стартовые локации: отвечает тот, кого спросили, первым вариантом.
			var pd: Dictionary = host_view.get("pending_decision", {})
			if pd.is_empty():
				_turn_player = String(host_view["current_player"])
				_step = "spoof"
			else:
				var chooser := String(pd["player_id"])
				var view := host_view if chooser == host.seat else client_view
				var mine: Dictionary = view["pending_decision"]
				# Один ответ на один вопрос: следующий — только когда хост
				# получил результат предыдущего.
				if _answered_at != host_errors.size() and String(mine.get("player_id", "")) == chooser \
						and not (mine["legal_options"] as Array).is_empty():
					_answered_at = host_errors.size()
					var who := host if chooser == host.seat else client
					who.send_intent(Intent.make_decision(chooser, (mine["legal_options"] as Array)[0]))
		"spoof":
			if not _spoof_sent:
				# Клиент пытается закончить ход за хоста — сервер подставит его
				# собственный цвет, а не тот, что указан в намерении.
				client_errors.clear()
				client.send_intent(Intent.end_turn(host.seat))
				_spoof_sent = true
			elif not client_errors.is_empty():
				if _turn_player == client_seat:
					check(String(client_view["current_player"]) != client_seat,
						"клиент закончил СВОЙ ход (цвет из рассадки, не из намерения)")
				else:
					check(int(client_errors[-1]) == GameServer.Error.NOT_YOUR_TURN,
						"клиенту нельзя ходить за хоста: %d" % int(client_errors[-1]))
					check(String(host_view["current_player"]) == host.seat, "ход хоста не тронут")
				client.send_chat("hello from client")
				_step = "chat"
		"chat":
			if not host_chat.is_empty() and not client_chat.is_empty():
				check(host_chat[0] == [client_seat, "hello from client"], "хост получил чат клиента")
				check(client_chat[0] == [client_seat, "hello from client"], "клиент получил свой чат обратно")
				return _finish()
	return false


func _check_hidden_hands() -> void:
	var host_players: Dictionary = host_view["players"]
	var client_players: Dictionary = client_view["players"]
	check((client_players[client_seat]["hand"] as Array).size() == 5, "клиент видит свои 5 карт")
	check(not (client_players[host.seat] as Dictionary).has("hand") \
		or (client_players[host.seat]["hand"] as Array).is_empty(), "клиент не видит руку хоста")
	check(not (host_players[client_seat] as Dictionary).has("hand") \
		or (host_players[client_seat]["hand"] as Array).is_empty(), "хост не видит руку клиента")


func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		print("  ПРОВАЛ: ", description)


func _finish() -> bool:
	host.close()
	client.close()
	print("сеть: пройдено %d, провалено %d" % [passed, failed])
	quit(1 if failed > 0 else 0)
	return true
