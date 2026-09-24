extends SceneTree

## Сетевой тест (этап 6): настоящий ENet через 127.0.0.1, все участники в
## одном процессе. У каждого своя ветка дерева со своим SceneMultiplayer,
## поэтому относительный путь узла ("Net") у них совпадает — как у разных
## программ.
##
## Два сценария подряд:
##   lan    — хост по IP играет сам, клиент входит по адресу;
##   server — выделенный сервер, игрок A создаёт комнату, B входит по коду;
##            чужой код и чужая версия игры получают отказ.
##
##   godot --headless --path . --script res://tests/net_loopback.gd
## Последняя строка: "сеть: пройдено N, провалено 0".

const LAN_PORT := 7790
const SERVER_PORT := 7791
const TIMEOUT := 20.0

var passed := 0
var failed := 0
var _elapsed := 0.0
var _scenario := ""
var _step := "init"
var _branches := 0

## Кто играет (первый — создатель), их последние срезы, ошибки и чат.
var players: Array[NetSession] = []
var views: Dictionary = {}
var errors: Dictionary = {}
var chats: Dictionary = {}
var lost: Dictionary = {}
var server: NetSession
var _answered_at := -1
var _spoof_sent := false
var _turn_player := ""
var _stranger: NetSession
var _old_version: NetSession


func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed > TIMEOUT:
		check(false, "[%s] шаг «%s» не завершился за %d с" % [_scenario, _step, int(TIMEOUT)])
		return _finish()
	match _step:
		"init":
			_start_lan()
		"lan_wait":
			if players[0].is_full() and players[1].seat != "":
				check(players[1].seat != players[0].seat, "[lan] у клиента свой цвет")
				players[0].start_game(4242)
				_step = "started"
		"server_wait_code":
			if players[0].room_code != "":
				check(players[0].room_code.length() == NetSession.CODE_LENGTH, "[server] код комнаты из 4 знаков")
				players[1].enter_room("127.0.0.1", SERVER_PORT, players[0].room_code.to_lower())
				_stranger.enter_room("127.0.0.1", SERVER_PORT, "ZZZZ" if players[0].room_code != "ZZZZ" else "YYYY")
				_old_version._connect("127.0.0.1", SERVER_PORT,
					func(): _old_version._enter.rpc_id(1, NetSession.PROTOCOL + 99, players[0].room_code))
				_step = "server_wait_join"
		"server_wait_join":
			if players[1].seat != "" and lost.has(_stranger) and lost.has(_old_version):
				check(String(lost[_stranger]).contains("no room"), "[server] чужой код — отказ: %s" % lost[_stranger])
				check(String(lost[_old_version]).contains("version"), "[server] чужая версия — отказ: %s" % lost[_old_version])
				check(server.rooms.size() == 1, "[server] на сервере одна комната")
				# START может только создатель: просьба второго ничего не даёт.
				players[1].start_game(0)
				players[0].start_game(0)
				_step = "started"
		"started":
			if not views[players[0]].is_empty() and not views[players[1]].is_empty():
				_check_hidden_hands()
				_step = "setup"
		"setup":
			_answer_setup()
		"spoof":
			_spoof()
		"chat":
			if not chats[players[0]].is_empty() and not chats[players[1]].is_empty():
				var line: Array = [players[1].seat, "hello from %s" % _scenario]
				check(chats[players[0]][0] == line, "[%s] создатель получил чат второго" % _scenario)
				check(chats[players[1]][0] == line, "[%s] второй получил свой чат обратно" % _scenario)
				if _scenario == "lan":
					_start_server()
				else:
					return _finish()
	return false


# --- сценарии ----------------------------------------------------------------

func _start_lan() -> void:
	_scenario = "lan"
	_reset()
	var host := _session()
	var client := _session()
	players = [host, client]
	for p in players:
		_track(p)
	check(host.host(LAN_PORT, 2, GameSetup.MODE_STANDARD) == OK, "[lan] хост открыл порт")
	check(client.join("127.0.0.1", LAN_PORT) == OK, "[lan] клиент начал подключение")
	_step = "lan_wait"


func _start_server() -> void:
	for p in players:
		p.close()
	_scenario = "server"
	_reset()
	server = _session()
	check(server.serve(SERVER_PORT, true) == OK, "[server] сервер открыл порт")
	var a := _session()
	var b := _session()
	players = [a, b]
	_stranger = _session()
	_old_version = _session()
	for p in [a, b, _stranger, _old_version]:
		_track(p)
	a.create_room("127.0.0.1", SERVER_PORT, 2, GameSetup.MODE_STANDARD)
	_step = "server_wait_code"


func _reset() -> void:
	_elapsed = 0.0
	_answered_at = -1
	_spoof_sent = false
	views.clear()
	errors.clear()
	chats.clear()
	lost.clear()


func _session() -> NetSession:
	_branches += 1
	var branch := Node.new()
	branch.name = "Side%d" % _branches
	root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	var net := NetSession.new()
	net.name = "Net"
	branch.add_child(net)
	return net


func _track(p: NetSession) -> void:
	views[p] = {}
	errors[p] = []
	chats[p] = []
	p.game_started.connect(func(_s: String, _b: Dictionary, v: Dictionary): views[p] = v)
	p.result_received.connect(func(e: int, _ev: Array, v: Dictionary):
		errors[p].append(e)
		views[p] = v)
	p.chat_received.connect(func(w: String, t: String): chats[p].append([w, t]))
	p.connection_lost.connect(func(reason: String): lost[p] = reason)


# --- общие шаги партии -------------------------------------------------------

func _check_hidden_hands() -> void:
	var a: NetSession = players[0]
	var b: NetSession = players[1]
	var seen_by_b: Dictionary = views[b]["players"]
	var seen_by_a: Dictionary = views[a]["players"]
	check((seen_by_b[b.seat]["hand"] as Array).size() == 5, "[%s] второй видит свои 5 карт" % _scenario)
	check(not (seen_by_b[a.seat] as Dictionary).has("hand"), "[%s] второй не видит руку первого" % _scenario)
	check(not (seen_by_a[b.seat] as Dictionary).has("hand"), "[%s] первый не видит руку второго" % _scenario)


## Стартовые локации: отвечает тот, кого спросили, первым вариантом. Один
## ответ на один вопрос — следующий, когда первый игрок увидел результат.
func _answer_setup() -> void:
	var pd: Dictionary = views[players[0]].get("pending_decision", {})
	if pd.is_empty():
		_turn_player = String(views[players[0]]["current_player"])
		_step = "spoof"
		return
	var chooser := String(pd["player_id"])
	for p in players:
		if p.seat != chooser:
			continue
		var mine: Dictionary = views[p]["pending_decision"]
		var seen: int = errors[players[0]].size()
		if _answered_at != seen and String(mine.get("player_id", "")) == chooser \
				and not (mine["legal_options"] as Array).is_empty():
			_answered_at = seen
			p.send_intent(Intent.make_decision(chooser, (mine["legal_options"] as Array)[0]))


## Второй игрок пытается закончить ход за первого — цвет берётся из рассадки.
func _spoof() -> void:
	var a: NetSession = players[0]
	var b: NetSession = players[1]
	if not _spoof_sent:
		errors[b].clear()
		b.send_intent(Intent.end_turn(a.seat))
		_spoof_sent = true
		return
	if errors[b].is_empty():
		return
	if _turn_player == b.seat:
		check(String(views[b]["current_player"]) != b.seat,
			"[%s] второй закончил СВОЙ ход (цвет из рассадки)" % _scenario)
	else:
		check(int(errors[b][-1]) == GameServer.Error.NOT_YOUR_TURN,
			"[%s] за чужой цвет ходить нельзя: %d" % [_scenario, int(errors[b][-1])])
	b.send_chat("hello from %s" % _scenario)
	_step = "chat"


func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		print("  ПРОВАЛ: ", description)


func _finish() -> bool:
	for p in players:
		p.close()
	if server != null:
		server.close()
	print("сеть: пройдено %d, провалено %d" % [passed, failed])
	quit(1 if failed > 0 else 0)
	return true
