extends SceneTree

## Сетевой тест (этап 6): настоящий ENet через 127.0.0.1, все участники в
## одном процессе. У каждого своя ветка дерева со своим SceneMultiplayer,
## поэтому относительный путь узла ("Net") у них совпадает — как у разных
## программ.
##
## Сценарии подряд:
##   lan     — хост по IP играет сам, клиент входит по адресу;
##   server  — выделенный сервер, игрок A создаёт комнату, B входит по коду;
##             чужой код и чужая версия игры получают отказ; дальше (этап 7) —
##             B теряет связь и возвращается под тем же ключом профиля (а не
##             новой раздачей), потом сервер «перезапускается» на том же порту
##             и оба поднимаются из GameJournal.
##   server4 — тот же выделенный сервер, но комната на четверых (этап 8):
##             рассадка, срезы рук и стартовые сайты не завязаны на «ровно 2».
##   match   — поиск игры: очереди на 2 и на 3 игрока, стол RANDOM 4
##             собирается и раздаётся сервером сам, ушедший из очереди убран.
##
##   godot --headless --path . --script res://tests/net_loopback.gd
## Последняя строка: "сеть: пройдено N, провалено 0".

const LAN_PORT := 7790
const SERVER_PORT := 7791
## Отдельный порт для сценария на четверых (этап 8) — старый сервер к этому
## моменту уже закрыт «перезапуском», но проще не делить один порт.
const SERVER4_PORT := 7792
const MATCH_PORT := 7793
## "server" — самый длинный сценарий: раздача, чат, переподключение и
## «перезапуск» сервера (этап 7) в одном TIMEOUT-окне без сброса _elapsed.
const TIMEOUT := 30.0

var passed := 0
var failed := 0
var _elapsed := 0.0
var _scenario := ""
var _step := "init"
var _branches := 0
## Сколько игроков уже получили профиль: у каждого своё имя (на сервере имена
## уникальны, RatingBook.claim_name).
var _tracked := 0

## Кто играет (первый — создатель), их последние срезы, ошибки и чат.
var players: Array[NetSession] = []
var views: Dictionary = {}
var boards: Dictionary = {}
var errors: Dictionary = {}
var chats: Dictionary = {}
var lost: Dictionary = {}
## Кто получил player_rejoined и про какой цвет (этап 7).
var rejoined: Dictionary = {}
## Последнее «в очереди waiting из needed» у каждого (поиск игры).
var queue_seen: Dictionary = {}
var server: NetSession
var _answered_at := -1
var _spoof_sent := false
var _turn_player := ""
var _stranger: NetSession
var _old_version: NetSession
## Чужой ключ, но имя как у первого игрока (другим регистром) — сервер не пускает.
var _impostor: NetSession
var ratings: Dictionary = {}
const RATINGS_PATH := "user://ratings_nettest.json"
const RATINGS_NAMES_PATH := "user://ratings_nettest_names.json"
## Своя папка сохранений партий — не трогает настоящие user://saves/ владельца.
const SAVES_DIR := "user://saves_nettest/"

## Переподключение и восстановление после «перезапуска» сервера (этап 7).
var _reconnect_code := ""
var _reconnect_key := ""
var _reconnect_seat := ""
var _restart_seat0 := ""
var _restart_seat1 := ""


func _initialize() -> void:
	# Свой файл профиля: NetSession пишет в профиль рейтинг и ключ.
	PlayerProfile.path_override = "user://profile_nettest.cfg"


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
					func(): _old_version._enter.rpc_id(1, NetSession.PROTOCOL + 99, players[0].room_code, ""))
				_impostor.profile = {"name": String(players[0].profile["name"]).to_upper(), "emblem": ""}
				_impostor.create_room("127.0.0.1", SERVER_PORT, 2, GameSetup.MODE_STANDARD)
				_step = "server_wait_join"
		"server_wait_join":
			if players[1].seat != "" and lost.has(_stranger) and lost.has(_old_version) \
					and lost.has(_impostor) and server.rooms.size() == 1:
				check(String(lost[_stranger]).contains("no room"), "[server] чужой код — отказ: %s" % lost[_stranger])
				check(String(lost[_old_version]).contains("version"), "[server] чужая версия — отказ: %s" % lost[_old_version])
				check(String(lost[_impostor]).contains("is taken"), "[server] занятое имя — отказ: %s" % lost[_impostor])
				check(server.rooms.size() == 1, "[server] на сервере одна комната")
				# START может только создатель: просьба второго ничего не даёт.
				players[1].start_game(0)
				players[0].start_game(0)
				_step = "started"
		"started":
			if not views[players[0]].is_empty() and not views[players[1]].is_empty():
				check(not (boards[players[0]].get("schematic", {}) as Dictionary).is_empty(),
					"[%s] чертёж доски пришёл" % _scenario)
				_check_hidden_hands()
				_check_profiles()
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
					_start_reconnect_test()
		"reconnect_disconnect_wait":
			var room: GameRoom = server.rooms.get(_reconnect_code)
			if room != null and not room.seats.values().has(_reconnect_seat):
				var b2 := _session()
				_track(b2)
				b2.rating_key = _reconnect_key
				b2.enter_room("127.0.0.1", SERVER_PORT, _reconnect_code)
				players[1] = b2
				_step = "reconnect_wait"
		"reconnect_wait":
			if not views[players[1]].is_empty():
				check(players[1].seat == _reconnect_seat, "[server] переподключение вернуло тот же цвет")
				check(views[players[1]]["current_player"] == views[players[0]]["current_player"],
					"[server] переподключившийся видит тот же ход партии, а не новую раздачу")
				check(rejoined.get(players[0], "") == _reconnect_seat,
					"[server] первый игрок узнал, что второй вернулся")
				check(server.rooms.size() == 1, "[server] после переподключения комната всё ещё одна")
				_start_server_restart()
		"restarted_wait":
			if not views[players[0]].is_empty() and not views[players[1]].is_empty():
				check(players[0].seat == _restart_seat0 and players[1].seat == _restart_seat1,
					"[server] после «перезапуска» сервера оба вернулись на свои цвета")
				check(views[players[0]]["current_player"] == views[players[1]]["current_player"],
					"[server] восстановленная из журнала партия согласована у обоих")
				_end_game()
		"rated":
			if ratings.has(players[0]) and ratings.has(players[1]):
				var r: Dictionary = ratings[players[0]]
				check(r == ratings[players[1]], "[server] рейтинг пришёл обоим одинаковый")
				check(r.has(players[0].seat) and r.has(players[1].seat), "[server] рейтинг обоих мест")
				check(int(r[players[0].seat]["delta"]) + int(r[players[1].seat]["delta"]) == 0,
					"[server] рейтинг: сколько один получил, столько другой потерял")
				check(server.ratings.accounts.size() == 2, "[server] на сервере две учётные записи")
				check(not (views[players[0]] as Dictionary).get("final_scores", {}).is_empty(),
					"[server] итоги партии пришли в срезе")
				DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_PATH))
				DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_NAMES_PATH))
				_start_server_four()
		"server4_wait_code":
			if players[0].room_code != "":
				check(players[0].room_code.length() == NetSession.CODE_LENGTH, "[server4] код комнаты из 4 знаков")
				for i in range(1, players.size()):
					players[i].enter_room("127.0.0.1", SERVER4_PORT, players[0].room_code)
				_step = "server4_wait_join"
		"server4_wait_join":
			var all_seated := true
			for p in players:
				if p.seat == "":
					all_seated = false
			if all_seated:
				var distinct_seats := {}
				for p in players:
					distinct_seats[p.seat] = true
				check(distinct_seats.size() == 4, "[server4] все четверо получили разные цвета")
				var room: GameRoom = server.rooms.values()[0]
				check(room.needed == 4, "[server4] в комнате четверо")
				players[0].start_game(0)
				_step = "server4_started"
		"server4_started":
			var all_dealt := true
			for p in players:
				if views[p].is_empty():
					all_dealt = false
			if all_dealt:
				check(not (boards[players[0]].get("schematic", {}) as Dictionary).is_empty(),
					"[server4] чертёж доски на четверых пришёл")
				_check_hidden_hands_n()
				_step = "server4_setup"
		"server4_setup":
			_answer_setup("server4_ready")
		"server4_ready":
			var current := String(views[players[0]]["current_player"])
			var current_seats := 0
			for p in players:
				if p.seat == current:
					current_seats += 1
				check(views[p]["current_player"] == current, "[server4] все видят один и тот же текущий ход")
			check(current_seats == 1, "[server4] ходящий — ровно один из четверых (получено %d)" % current_seats)
			_start_match()
		"match_wait":
			# Кто из троих пришёл первым, заранее не известно — смотрим, кто сел.
			var seated: Array[NetSession] = []
			var waiting: NetSession = null
			for i in 3:
				if not views[players[i]].is_empty():
					seated.append(players[i])
				else:
					waiting = players[i]
			if seated.size() == 2 and queue_seen.get(waiting, []) == [1, 2] \
					and queue_seen.get(players[3], []) == [1, 3]:
				var room: GameRoom = server.rooms.values()[0]
				check(server.rooms.size() == 1, "[match] из очереди собран ровно один стол")
				check(room.mode == NetSession.MATCH_MODE and room.needed == 2,
					"[match] стол на двоих, режим RANDOM 4 (получено %d, %s)" % [room.needed, room.mode])
				check(seated[0].seat != seated[1].seat, "[match] у двоих разные цвета")
				check(seated[0].room_code == room.code and seated[0]._last_code == room.code,
					"[match] код стола запомнен для переподключения")
				check(not (boards[seated[0]].get("schematic", {}) as Dictionary).is_empty(),
					"[match] чертёж доски пришёл")
				check(String((seated[1].profiles.get(seated[0].seat, {}) as Dictionary).get("name", "")) \
					== seated[0].profile["name"], "[match] имя соперника дошло")
				check(waiting.seat == "", "[match] третий ждёт дальше, за стол не сел")
				waiting.close()
				# Имена проверяются и в очереди: чужой ключ с именем первого — отказ.
				_impostor = _session()
				_track(_impostor)
				_impostor.profile = {"name": String(players[0].profile["name"]).to_upper(), "emblem": ""}
				_impostor.find_match("127.0.0.1", MATCH_PORT, 4)
				_step = "match_leave"
		"match_leave":
			if server.queued.size() == 1 and (server.queues[2] as Array).is_empty() and lost.has(_impostor):
				check(String(lost[_impostor]).contains("is taken"), "[match] занятое имя в очереди — отказ: %s" % lost[_impostor])
				check(server.queued.has(server.queues[3][0]), "[match] ушедший убран из очереди, ждущий троих остался")
				return _finish()
	return false


## Поиск игры: трое ищут стол на двоих, один — на троих. Первые двое садятся
## за стол RANDOM 4 и сразу получают раздачу, третий видит «1 из 2», четвёртый
## — «1 из 3». Третий закрывает поиск — сервер убирает его из очереди.
func _start_match() -> void:
	for p in players:
		p.close()
	if server != null:
		server.close()
	_scenario = "match"
	_reset()
	# Недоигранная партия server4 лежит в журнале — новый сервер поднял бы её.
	_clear_saves_dir()
	server = _session()
	# Своя книга рейтингов и имён, как у server4 (имена проверяются и в очереди).
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_NAMES_PATH))
	server.ratings = RatingBook.new(RATINGS_PATH)
	server.saves_dir = SAVES_DIR
	check(server.serve(MATCH_PORT, true) == OK, "[match] сервер открыл порт")
	var ps: Array[NetSession] = []
	for i in 4:
		ps.append(_session())
	players = ps
	for p in players:
		_track(p)
	for i in 3:
		players[i].find_match("127.0.0.1", MATCH_PORT, 2)
	players[3].find_match("127.0.0.1", MATCH_PORT, 3)
	_step = "match_wait"


## Второй игрок теряет связь и возвращается под тем же ключом профиля
## (PlayerProfile.key, здесь — NetSession.rating_key) — сервер должен посадить
## его на то же место и прислать ТЕКУЩЕЕ состояние партии, а не новую раздачу
## (этап 7, GameRoom.claim). Первый игрок должен узнать об этом.
func _start_reconnect_test() -> void:
	var b: NetSession = players[1]
	_reconnect_code = b.room_code
	_reconnect_key = b.rating_key
	_reconnect_seat = b.seat
	b.close()
	_step = "reconnect_disconnect_wait"


## «Перезапуск» сервера: закрываем ENet-порт и открываем заново на том же
## порту новым NetSession — как systemd после deploy.sh. Партия должна
## подняться из GameJournal (той же папки user://saves/), и оба игрока
## возвращаются под своими ключами (этап 7).
func _start_server_restart() -> void:
	var code := players[0].room_code
	_restart_seat0 = players[0].seat
	_restart_seat1 = players[1].seat
	var key0 := players[0].rating_key
	var key1 := players[1].rating_key
	server.close()
	players[0].close()
	players[1].close()
	server = _session()
	server.ratings = RatingBook.new(RATINGS_PATH)
	server.saves_dir = SAVES_DIR
	check(server.serve(SERVER_PORT, true) == OK, "[server] сервер «перезапущен» на том же порту")
	check(server.rooms.has(code), "[server] партия восстановлена из сохранения после «перезапуска»")
	var a2 := _session()
	var b3 := _session()
	_track(a2)
	_track(b3)
	a2.rating_key = key0
	b3.rating_key = key1
	a2.enter_room("127.0.0.1", SERVER_PORT, code)
	b3.enter_room("127.0.0.1", SERVER_PORT, code)
	players = [a2, b3]
	_step = "restarted_wait"


## Этап 8: четверо на выделенном сервере — комната на 4 цвета, у каждого своя
## рука, стартовые сайты по очереди хода на четверых (через _answer_setup,
## которая уже написана без привязки к числу игроков). До реальных ходов и
## рейтинга не доводим — это уже проверено на двоих, здесь смысл только в
## том, что рассадка/раздача/срезы не завязаны на «ровно 2».
func _start_server_four() -> void:
	for p in players:
		p.close()
	if server != null:
		server.close()
	_scenario = "server4"
	_reset()
	server = _session()
	# Своя книга рейтингов и имён — не user://ratings.json владельца (сервер без
	# книги завёл бы её там, и имена «Player N» копились бы между прогонами).
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_NAMES_PATH))
	server.ratings = RatingBook.new(RATINGS_PATH)
	server.saves_dir = SAVES_DIR
	check(server.serve(SERVER4_PORT, true) == OK, "[server4] сервер открыл порт")
	var ps: Array[NetSession] = []
	for i in 4:
		ps.append(_session())
	players = ps
	for p in players:
		_track(p)
	players[0].create_room("127.0.0.1", SERVER4_PORT, 4, GameSetup.MODE_STANDARD)
	_step = "server4_wait_code"


## Скрытая информация у ЛЮБОГО числа игроков: своя рука видна, чужие — только
## размером (обобщение _check_hidden_hands на players.size() участников).
func _check_hidden_hands_n() -> void:
	for viewer in players:
		var seen: Dictionary = views[viewer]["players"]
		check((seen[viewer.seat]["hand"] as Array).size() == 5, "[%s] %s видит свои 5 карт" % [_scenario, viewer.seat])
		for other in players:
			if other == viewer:
				continue
			check(not (seen[other.seat] as Dictionary).has("hand"),
				"[%s] %s не видит руку %s" % [_scenario, viewer.seat, other.seat])


## Конец партии: на сервере объявлен последний круг, который кончается на
## текущем игроке; он жмёт End turn — сервер считает рейтинг и рассылает его.
func _end_game() -> void:
	var room: GameRoom = server.rooms.values()[0]
	var state := room.server.state
	GameEnd.trigger(state, "market_empty")
	state.final_round_ends_after_index = state.current_player_index
	var current := state.current_player()
	for p in players:
		if p.seat == current:
			p.send_intent(Intent.end_turn(current))
	_step = "rated"


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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_NAMES_PATH))
	server.ratings = RatingBook.new(RATINGS_PATH)
	server.saves_dir = SAVES_DIR
	check(server.serve(SERVER_PORT, true) == OK, "[server] сервер открыл порт")
	var a := _session()
	var b := _session()
	players = [a, b]
	_stranger = _session()
	_old_version = _session()
	_impostor = _session()
	for p in [a, b, _stranger, _old_version, _impostor]:
		_track(p)
	a.create_room("127.0.0.1", SERVER_PORT, 2, GameSetup.MODE_STANDARD)
	_step = "server_wait_code"


func _reset() -> void:
	_elapsed = 0.0
	_answered_at = -1
	_spoof_sent = false
	views.clear()
	boards.clear()
	errors.clear()
	chats.clear()
	lost.clear()
	rejoined.clear()
	queue_seen.clear()


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
	_tracked += 1
	p.profile = {"name": "Player %d" % _tracked, "emblem": _emblem_for(_branches), "back": _back_for(_tracked)}
	p.rating_key = "%032d" % p.get_instance_id()
	p.rating_changed.connect(func(r: Dictionary): ratings[p] = r)
	views[p] = {}
	errors[p] = []
	chats[p] = []
	p.game_started.connect(func(_s: String, b: Dictionary, v: Dictionary):
		boards[p] = b
		views[p] = v)
	p.result_received.connect(func(e: int, _ev: Array, v: Dictionary):
		errors[p].append(e)
		views[p] = v)
	p.chat_received.connect(func(w: String, t: String): chats[p].append([w, t]))
	p.connection_lost.connect(func(reason: String): lost[p] = reason)
	p.player_rejoined.connect(func(who: String): rejoined[p] = who)
	p.queue_changed.connect(func(w: int, n: int): queue_seen[p] = [w, n])


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
## Не завязана на число игроков за столом — годится и на четверых (этап 8).
func _answer_setup(next_step: String = "spoof") -> void:
	var pd: Dictionary = views[players[0]].get("pending_decision", {})
	if pd.is_empty():
		_turn_player = String(views[players[0]]["current_player"])
		_step = next_step
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
	_clear_saves_dir()
	print("сеть: пройдено %d, провалено %d" % [passed, failed])
	quit(1 if failed > 0 else 0)
	return true


## Тестовые сохранения (SAVES_DIR) обычно и так пустеют сами: игра завершается
## и GameJournal.erase() убирает файл. Здесь — на случай отказа/таймаута.
func _clear_saves_dir() -> void:
	var dir := DirAccess.open(SAVES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir():
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()


## Герб-метка: один пиксель в центре, цвет зависит от номера игрока.
func _emblem_for(n: int) -> String:
	var pixels: Array[Color] = []
	pixels.resize(PlayerProfile.SIZE * PlayerProfile.SIZE)
	pixels.fill(Color(0, 0, 0, 0))
	pixels[40] = Color8(n * 20, 200, 10)
	return PlayerProfile.emblem_from_pixels(pixels)


## Имя, герб и рубашка каждого дошли до всех, и каждый у своего цвета.
func _check_profiles() -> void:
	for owner_p in players:
		for other in players:
			var got: Dictionary = other.profiles.get(owner_p.seat, {})
			check(got.get("name", "") == owner_p.profile["name"] and got.get("emblem", "") == owner_p.profile["emblem"]
				and got.get("back", "") == owner_p.profile["back"],
				"[%s] профиль %s дошёл до %s" % [_scenario, owner_p.seat, other.seat])


## Рубашка-метка: один пиксель в углу рисунка, цвет зависит от номера игрока.
func _back_for(n: int) -> String:
	var pixels: Array[Color] = []
	pixels.resize(PlayerProfile.BACK_SIZE * PlayerProfile.BACK_SIZE)
	pixels.fill(Color(0, 0, 0, 0))
	pixels[0] = Color8(n * 20, 10, 200)
	return PlayerProfile.back_from_pixels(pixels)
