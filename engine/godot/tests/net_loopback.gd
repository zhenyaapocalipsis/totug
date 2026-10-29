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
##   pause   — общая пауза кнопкой, отказ в ходе на паузе; отключившийся не
##             вернулся — партия кончается по текущему счёту без рейтинга.
##   abuse   — защита сервера (этап Sec-2): подбор кода с одного IP, клиент,
##             не ушедший по отказу, лимиты новых учёток и заявок в друзья.
##
##   godot --headless --path . --script res://tests/net_loopback.gd
## Последняя строка: "сеть: пройдено N, провалено 0".

const LAN_PORT := 7790
const SERVER_PORT := 7791
## Отдельный порт для сценария на четверых (этап 8) — старый сервер к этому
## моменту уже закрыт «перезапуском», но проще не делить один порт.
const SERVER4_PORT := 7792
const MATCH_PORT := 7793
## Баны троих, что ищут стол на двоих.
const MATCH_BANS: Array[String] = ["drow", "dragons", "demons"]
const PAUSE_PORT := 7794
const ABUSE_PORT := 7795
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
var pings: Dictionary = {}
var lost: Dictionary = {}
## Кто получил player_rejoined и про какой цвет (этап 7).
var rejoined: Dictionary = {}
## Последнее «в очереди waiting из needed» у каждого (поиск игры).
var queue_seen: Dictionary = {}
var dealing_seen: Dictionary = {}   # NetSession -> true: пришёл экран DEALING THE CARDS
## Лобби банов (Ban-1): последнее состояние у каждого и что он забанил.
var bans_seen: Dictionary = {}
var banned_by: Dictionary = {}
## Последняя пауза от сервера у каждого (NetSession.pause_changed).
var pause_seen: Dictionary = {}
var server: NetSession
## Главное меню (NetSession.watch) и пришедшая ему таблица лидеров.
var _watcher: NetSession
var _board_data: Dictionary = {}
## Друзья: последний снимок и переписка у каждой связи.
var _friends: Dictionary = {}
var _threads: Dictionary = {}
## Зритель: от чьего лица, первый срез, дошёл ли конец партии.
var _watch_seat := ""
var _watch_view: Dictionary = {}
var _watch_over := false
## Шагов партии, дошедших до зрителя до её конца.
var _watch_steps := 0
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
## И своя папка реплеев (ReplayBook).
const REPLAYS_DIR := "user://replays_nettest/"
const RECORDS_DIR := "user://records_nettest/"

## Переподключение и восстановление после «перезапуска» сервера (этап 7).
var _reconnect_code := ""
var _reconnect_key := ""
var _reconnect_seat := ""
var _stock_seed := -1   # [server]: сид чертежа, что лежит в запасе сервера
var _restart_seat0 := ""
var _restart_seat1 := ""
## Сценарий pause: кто отключился и не вернулся.
var _absent_seat := ""
## Сценарий abuse (этап Sec-2): подбиравшие код, опоздавший и ответы друзей.
var _guessers: Array[NetSession] = []
var _late: NetSession
var _abuse_replies := 0
var _abuse_note := ""


func _initialize() -> void:
	# Свой файл профиля: NetSession пишет в профиль рейтинг и ключ.
	PlayerProfile.path_override = "user://profile_nettest.cfg"
	# И свой файл запомненной партии (RETURN TO GAME).
	NetSession.resume_path = "user://online_game_nettest.cfg"
	NetSession.forget_game()


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
				check(players[0].seat == "purple", "[lan] хост сел за любимый purple (выбрал первым)")
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
				if _scenario == "server" and server.board_stock != null:
					var room: GameRoom = server.rooms.values()[0]
					check(_stock_seed >= 0 and room.game_seed == _stock_seed,
						"[server] партия взяла доску из запаса сервера")
					check(bool(boards[players[0]]["schematic"].get("grid", false)),
						"[server] доска из запаса легла в сетку")
					check(dealing_seen.is_empty(), "[server] доска из запаса — без экрана раздачи")
					# дальше запас не нужен: фоновые чертежи только мешали бы по времени
					server.board_stock.close()
					server.board_stock = null
				_check_hidden_hands()
				_check_profiles()
				_step = "setup"
		"setup":
			_answer_setup()
		"spoof":
			_spoof()
		"chat":
			if not chats[players[0]].is_empty() and not chats[players[1]].is_empty() \
					and not pings[players[0]].is_empty():
				var line: Array = [players[1].seat, "hello from %s" % _scenario]
				check(chats[players[0]][0] == line, "[%s] создатель получил чат второго" % _scenario)
				check(chats[players[1]][0] == line, "[%s] второй получил свой чат обратно" % _scenario)
				check(pings[players[0]][0] == [players[1].seat, "board", Vector2(12, -34)],
					"[%s] создатель увидел пинг второго" % _scenario)
				check(pings[players[1]].is_empty(), "[%s] свой пинг автору не возвращается" % _scenario)
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
				# Alt+F4: старое соединение не попрощалось, сервер ещё считает его
				# живым, а игрок уже входит заново тем же ключом.
				var b3 := _session()
				_track(b3)
				b3.rating_key = _reconnect_key
				var cfg := ConfigFile.new()
				cfg.set_value("game", "address", "127.0.0.1")
				cfg.set_value("game", "port", SERVER_PORT)
				cfg.set_value("game", "code", _reconnect_code)
				cfg.set_value("game", "by_code", true)
				cfg.save(NetSession.resume_path)
				b3.resume_saved()
				players[1] = b3
				_step = "stale_wait"
		"stale_wait":
			if not views[players[1]].is_empty():
				check(players[1].seat == _reconnect_seat,
					"[server] вход заново при живом старом соединении (Alt+F4) вернул тот же цвет")
				check(not NetSession.saved_game().is_empty(),
					"[server] после такого входа RETURN TO GAME не пропадает")
				var room: GameRoom = server.rooms.get(_reconnect_code)
				check(room != null and room.seats.values().count(_reconnect_seat) == 1,
					"[server] старое соединение снято с места, цвет занят один раз")
				NetSession.forget_game()
				_start_server_restart()
		"restarted_wait":
			if not views[players[0]].is_empty() and not views[players[1]].is_empty():
				check(players[0].seat == _restart_seat0 and players[1].seat == _restart_seat1,
					"[server] после «перезапуска» сервера оба вернулись на свои цвета")
				check(views[players[0]]["current_player"] == views[players[1]]["current_player"],
					"[server] восстановленная из журнала партия согласована у обоих")
				# Главное меню третьего игрока: связь без комнаты и таблица лидеров.
				server.ratings.accounts["zed"] = {"name": "Zed", "rating": 1200, "games": 3, "wins": 2}
				_watcher = _session()
				_watcher.rating_key = "%032d" % 7
				_watcher.profile = {"name": "Watcher Wu", "emblem": ""}
				_watcher.leaderboard_received.connect(func(d: Dictionary): _board_data = d)
				_watcher.watch("127.0.0.1", SERVER_PORT)
				_step = "leaderboard_wait"
		"leaderboard_wait":
			if not _board_data.is_empty():
				check(int(_board_data["online"]) == 3 and int(_board_data["in_game"]) == 2,
					"[leaderboard] на связи трое (двое в партии, один в меню)")
				var top: Array = _board_data["top"]
				check(int(_board_data["registered"]) == 1 and top.size() == 1 and top[0]["name"] == "Zed"
					and int(top[0]["rating"]) == 1200 and not _board_data.has("mine"),
					"[leaderboard] таблица: один тиран, своего места нет")
				server.ratings.accounts.clear()
				# Друзья: игрок из партии зовёт того, кто сидит в меню (ник — другим регистром).
				for p: NetSession in [players[0], _watcher]:
					_friends[p] = {}
					_threads[p] = []
					p.friends_received.connect(func(d: Dictionary):
						_friends[p] = d)
					p.thread_received.connect(func(_n: String, m: Array): _threads[p] = m)
				players[0].friends_action("add", ["watcher wu"])
				_step = "friends_request"
		"friends_request":
			if not (_watcher_friends().get("incoming", []) as Array).is_empty():
				check(_watcher_friends()["incoming"] == [players[0].profile["name"]],
					"[friends] заявка дошла до игрока в меню")
				check(String(_friends[players[0]].get("note", "")).contains("request sent"),
					"[friends] отправившему — «заявка ушла»: %s" % _friends[players[0]].get("note", ""))
				_watcher.friends_action("answer", [players[0].profile["name"], true])
				_step = "friends_accept"
		"friends_accept":
			var mine: Array = _friends[players[0]].get("friends", [])
			var theirs: Array = _watcher_friends().get("friends", [])
			if mine.size() == 1 and theirs.size() == 1:
				check(mine[0]["name"] == "Watcher Wu" and mine[0]["status"] == "ONLINE",
					"[friends] друг в списке, статус ONLINE")
				check(theirs[0]["status"] == "IN GAME" and theirs[0]["room"] == players[0].room_code,
					"[friends] второй видит: друг в партии, код комнаты для зрителя")
				players[0].friends_action("send", ["Watcher Wu", "gg wp"])
				_step = "friends_mail"
		"friends_mail":
			var theirs: Array = _watcher_friends().get("friends", [])
			if not theirs.is_empty() and int(theirs[0]["unread"]) == 1:
				check(_threads[players[0]].size() == 1 and _threads[players[0]][0]["mine"],
					"[friends] отправившему вернулась переписка")
				_watcher.friends_action("thread", [players[0].profile["name"]])
				_step = "friends_read"
		"friends_read":
			if not (_threads[_watcher] as Array).is_empty():
				check(_threads[_watcher][0]["text"] == "gg wp" and not _threads[_watcher][0]["mine"],
					"[friends] сообщение дошло")
				_friends[players[0]] = {}
				players[0].friends_action("invite", ["Watcher Wu"])
				_step = "friends_invite"
		"friends_invite":
			if not (_friends[players[0]] as Dictionary).is_empty():
				check(String(_friends[players[0]]["note"]).contains("lobby first"),
					"[friends] из начатой партии в лобби не позвать: %s" % _friends[players[0]]["note"])
				# Друг смотрит партию: от лица игрока, без чьих-либо рук.
				_watcher.watch_started.connect(func(s: String, _b: Dictionary, v: Dictionary):
					_watch_seat = s
					_watch_view = v)
				_watcher.result_received.connect(func(_e: int, _ev: Array, v: Dictionary):
					if bool(v.get("game_over", false)):
						_watch_over = true
					else:
						_watch_steps += 1)
				_watcher.friends_action("watch", [players[0].profile["name"]])
				_step = "watch_start"
		"watch_start":
			if _watch_seat != "":
				check(_watch_seat == players[0].seat and _watcher.seat == "", "[watch] зритель смотрит от лица друга")
				var hands := 0
				for pv: Dictionary in (_watch_view["players"] as Dictionary).values():
					hands += 1 if pv.has("hand") or pv.has("deck_cards") else 0
				check(hands == 0 and (_watch_view.get("legal", {}) as Dictionary).is_empty(),
					"[watch] зрителю не видно ни рук, ни колод, ходить нечем")
				check(server.rooms.values()[0].watchers.size() == 1, "[watch] сервер знает зрителя")
				# Обычный ход: ходящий завершает ход — зритель должен его увидеть.
				var current: String = server.rooms.values()[0].server.state.current_player()
				for p in players:
					if p.seat == current:
						p.send_intent(Intent.end_turn(current))
				_step = "watch_turn"
		"watch_turn":
			if _watch_steps > 0:
				check(true, "[watch] обычный ход дошёл до зрителя")
				_end_game()
		"rated":
			if ratings.has(players[0]) and ratings.has(players[1]) and _watch_over:
				check(true, "[watch] конец партии дошёл до зрителя")
				_watcher.close()
				var r: Dictionary = ratings[players[0]]
				check(r == ratings[players[1]], "[server] рейтинг пришёл обоим одинаковый")
				check(r.has(players[0].seat) and r.has(players[1].seat), "[server] рейтинг обоих мест")
				check(int(r[players[0].seat]["delta"]) == 0 and int(r[players[1].seat]["delta"]) == 0
					and r[players[0].seat].get("unrated", false),
					"[server] партия по коду комнаты (лобби) рейтинг не меняет")
				var mine: Dictionary = r[players[0].seat]
				check(int((mine.get("breakdown", {}) as Dictionary).get("total", -1)) == int(mine["vp"])
					and (mine.get("half_decks", []) as Array).size() > 0,
					"[server] с итогом пришли разбивка VP и полуколоды партии")
				check(server.ratings.accounts.is_empty(), "[server] партия из лобби не записана в рейтинги")
				check(PlayerProfile.history()[0].get("unrated", false), "[server] в истории партия помечена LOBBY")
				check(not mine.has("reward"), "[server] партия по коду комнаты — без награды")
				check(not (views[players[0]] as Dictionary).get("final_scores", {}).is_empty(),
					"[server] итоги партии пришли в срезе")
				# Партия пережила «перезапуск» сервера — реплей всё равно цельный.
				var file := String(PlayerProfile.history()[0].get("replay", ""))
				var replay := ReplayBook.load_replay(file, REPLAYS_DIR)
				check(file != "" and not replay.is_empty(), "[replay] строка истории знает свой реплей")
				# Рекорды считаются по такому же реплею (NetSession._check_records).
				var scores := {players[0].seat: int(mine["vp"]), players[1].seat: int(r[players[1].seat]["vp"])}
				var m := RecordBook.measure(ReplayStats.collect(replay), players[0].seat, scores)
				check(int(m["vp"]) == int(mine["vp"]) and int(m["rounds"]) >= 1 and m.size() == RecordBook.KINDS.size(),
					"[records] показатели рекордов по реплею партии: %s" % m)
				var records := ReplayBook.list(RECORDS_DIR)
				check(not records.is_empty(), "[server] сервер сохранил запись законченной партии")
				if not records.is_empty():
					var rec := ReplayBook.load_replay(records[records.size() - 1], RECORDS_DIR)
					check((rec.get("intents", []) as Array).size() == (replay.get("intents", []) as Array).size(),
						"[server] в записи сервера все ходы партии")
				# Конец партии тест вызвал в обход ходов (_end_game) — его реплей
				# не повторит; рынок и войска — от ходов, они должны сойтись.
				var live: GameState = (server.rooms.values()[0] as GameRoom).server.state
				var again := ReplayBook.rebuild(replay).state if not replay.is_empty() else null
				check(again != null and Array(again.market.display) == Array(live.market.display)
					and again.troops == live.troops,
					"[replay] реплей партии после перезапуска сервера пересобирается до той же доски")
				DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_PATH))
				DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_NAMES_PATH))
				for extra in ["_friends", "_records"]:
					DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_PATH.get_basename() + extra + ".json"))
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
				check(dealing_seen.size() == 4, "[server4] без запаса все четверо видели DEALING THE CARDS")
				check(bool(boards[players[0]]["schematic"].get("grid", false)),
					"[server4] без лимита времени доска легла в сетку")
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
				check(room.mode == GameSetup.MODE_STANDARD and room.needed == 2,
					"[match] стол на двоих, режим STANDARD (получено %d, %s)" % [room.needed, room.mode])
				check(seated[0].seat != seated[1].seat, "[match] у двоих разные цвета")
				check((seated[0].seat == "purple") != (seated[1].seat == "purple"),
					"[match] любимый purple достался одному из двоих")
				check(seated[0].room_code == room.code and seated[0]._last_code == room.code,
					"[match] код стола запомнен для переподключения")
				check(not (boards[seated[0]].get("schematic", {}) as Dictionary).is_empty(),
					"[match] чертёж доски пришёл")
				check(String((seated[1].profiles.get(seated[0].seat, {}) as Dictionary).get("name", "")) \
					== seated[0].profile["name"], "[match] имя соперника дошло")
				check(waiting.seat == "", "[match] третий ждёт дальше, за стол не сел")
				check(room.matched, "[match] стол поиска игры помечен — за него будет награда")
				check(bans_seen.has(seated[0]) and bans_seen.has(seated[1]), "[match] оба видели лобби банов")
				check(str(bans_seen[seated[0]]["decks"]) == str(room.server.state.half_decks),
					"[match] в лобби банов — полуколоды партии (%s)" % [bans_seen[seated[0]].get("decks")])
				check(room.card_bans.size() == 2 and room.card_bans.has(banned_by.get(seated[0], "x")) \
					and room.card_bans.has(banned_by.get(seated[1], "x")), "[match] по бану от каждого, вторые пропущены (%s)" % [room.card_bans])
				var market_all: Array = room.server.state.market.deck + room.server.state.market.display
				check(not market_all.any(func(c): return room.card_bans.has(String(c))),
					"[match] забаненных карт нет в рынке")
				check(room.ban_log.size() == 4, "[match] четыре хода банов (2 на каждого)")
				var bans: Array[String] = []
				for i in 3:
					if players[i] != waiting:
						bans.append(MATCH_BANS[i])
				check(room.banned.size() == 2 and room.banned.has(bans[0]) and room.banned.has(bans[1]),
					"[match] баны двоих за столом дошли до комнаты (%s)" % [room.banned])
				check(not room.server.state.half_decks.any(func(d: String) -> bool: return bans.has(d)),
					"[match] забаненных полуколод нет в рынке (%s)" % [room.server.state.half_decks])
				var odd_ban := "x"
				for q: Dictionary in server.queued.values():
					if int(q["needed"]) == 3:
						odd_ban = String(q.get("ban", "x"))
				check(odd_ban == "", "[match] неизвестный бан сервер отбросил")
				check(String((seated[1].profiles.get(seated[0].seat, {}) as Dictionary).get("shader", "")) == "gilded",
					"[match] шейдер соперника дошёл")
				check(String((seated[1].profiles.get(seated[0].seat, {}) as Dictionary).get("arts", "")) == "48310_1,48403_2",
					"[match] арты соперника дошли")
				check(String((seated[1].profiles.get(seated[0].seat, {}) as Dictionary).get("favourite", "")) == "48314",
					"[match] любимая карта соперника дошла")
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
				_start_pause()
		"pause_wait_code":
			if players[0].room_code != "":
				players[1].enter_room("127.0.0.1", PAUSE_PORT, players[0].room_code)
				_step = "pause_wait_join"
		"pause_wait_join":
			if players[1].seat != "":
				players[0].start_game(0)
				_step = "pause_dealt"
		"pause_dealt":
			if not views[players[0]].is_empty() and not views[players[1]].is_empty():
				_step = "pause_setup"
		"pause_setup":
			_answer_setup("pause_manual")
		"pause_manual":
			check_eq_str(String(NetSession.saved_game().get("code", "")), players[0].room_code,
				"[pause] партия запомнена для RETURN TO GAME")
			players[0].request_pause(true)
			_step = "pause_manual_wait"
		"pause_manual_wait":
			if String((pause_seen.get(players[1], {}) as Dictionary).get("by", "")) == players[0].seat:
				check(server.rooms.values()[0].is_paused(), "[pause] общая пауза поставлена, второй о ней узнал")
				players[1].request_pause(false)
				errors[_current_session()].clear()
				_current_session().send_intent(Intent.end_turn(_turn_player))
				_step = "pause_refused"
		"pause_refused":
			if not errors[_current_session()].is_empty():
				check(int(errors[_current_session()][-1]) == GameServer.Error.PAUSED,
					"[pause] на паузе ход не принимается: %d" % int(errors[_current_session()][-1]))
				check(server.rooms.values()[0].paused_by == players[0].seat, "[pause] чужую паузу снять нельзя")
				players[0].request_pause(false)
				_step = "pause_resume_wait"
		"pause_resume_wait":
			if (pause_seen.get(players[1], {}) as Dictionary).get("by", "?") == "":
				check(not server.rooms.values()[0].is_paused(), "[pause] поставивший снял паузу")
				_absent_seat = players[1].seat
				players[1].close()
				_step = "pause_absent_wait"
		"pause_absent_wait":
			if ((pause_seen.get(players[0], {}) as Dictionary).get("absent", {}) as Dictionary).has(_absent_seat):
				check(server.rooms.values()[0].is_paused(), "[pause] второй отключился — партия встала, первый знает")
				_step = "pause_abandon_wait"
		"pause_abandon_wait":
			if bool(views[players[0]].get("game_over", false)):
				var room: GameRoom = server.rooms.values()[0]
				check_eq_str(String(views[players[0]].get("abandoned_by", "")), _absent_seat,
					"[pause] не вернулся — партия окончена, виновник назван")
				check(views[players[0]].has("final_scores"), "[pause] очки посчитаны")
				check(room.rated and server.ratings.accounts.is_empty() and not ratings.has(players[0]),
					"[pause] рейтинг не менялся")
				check(GameJournal.load_game(room.code, SAVES_DIR).is_empty(), "[pause] сохранение партии стёрто")
				check(NetSession.saved_game().is_empty(), "[pause] запомненная партия забыта")
				check(((pause_seen[players[0]] as Dictionary)["absent"] as Dictionary).is_empty(),
					"[pause] после конца партии паузы нет")
				_step = "pause_replay_wait"
		"pause_replay_wait":
			# Реплей идёт следом за последним ходом.
			if not ReplayBook.list(REPLAYS_DIR).is_empty():
				var replay := ReplayBook.load_replay(ReplayBook.list(REPLAYS_DIR)[0], REPLAYS_DIR)
				var header: Dictionary = replay.get("header", {})
				check_eq_str(String(header.get("seat", "")), players[0].seat, "[replay] реплей пришёл оставшемуся, записан его глазами")
				check_eq_str(String(header.get("abandoned_by", "")), _absent_seat, "[replay] в реплее — кто бросил партию")
				check(ReplayBook.matches(replay, ReplayBook.rebuild(replay)), "[replay] реплей пересобирается до того же итога")
				_start_abuse()
		"abuse_room":
			if players[0].room_code != "":
				# Пятеро подбирают код; первый — «изменённый клиент», связь сам не рвёт.
				var wrong := "ZZZZ" if players[0].room_code != "ZZZZ" else "YYYY"
				for i in NetSession.ENTER_FAILS:
					var s := _session()
					_track(s)
					s.ignore_refusal = i == 0
					s.enter_room("127.0.0.1", ABUSE_PORT, wrong)
					_guessers.append(s)
				_step = "abuse_codes"
		"abuse_codes":
			var all_lost := true
			for s in _guessers:
				all_lost = all_lost and lost.has(s)
			var evil: NetSession = _guessers[0]
			if all_lost and String(lost[evil]).contains("connection to the game was lost") \
					and server.multiplayer.get_peers().size() == 1:
				check(String(lost[_guessers[1]]).contains("no room"), "[abuse] чужой код — отказ: %s" % lost[_guessers[1]])
				check(evil.multiplayer.multiplayer_peer == null,
					"[abuse] клиент, не ушедший по отказу, отключён сервером")
				check(server._dropping.is_empty(), "[abuse] отказанных подключений на сервере не осталось")
				_late = _session()
				_track(_late)
				_late.enter_room("127.0.0.1", ABUSE_PORT, players[0].room_code)
				_step = "abuse_locked"
		"abuse_locked":
			if lost.has(_late):
				check(String(lost[_late]).contains("Too many wrong room codes"),
					"[abuse] после %d неверных кодов с IP не пускает и с верным: %s" % [NetSession.ENTER_FAILS, lost[_late]])
				check((server.rooms[players[0].room_code] as GameRoom).seats.size() == 1, "[abuse] в комнату никто не сел")
				check(not server.ratings.knows(RatingBook.account_of(_guessers[1].rating_key)),
					"[abuse] отказанный по коду имя не занял")
				# Окно прошло: вход по коду снова открыт.
				server._bad_codes.clear()
				var b := _session()
				_track(b)
				b.enter_room("127.0.0.1", ABUSE_PORT, players[0].room_code)
				players.append(b)
				_step = "abuse_second"
		"abuse_second":
			if players[1].seat != "" and server.ratings.knows(RatingBook.account_of(players[1].rating_key)):
				check(true, "[abuse] окно прошло — вход по коду открыт, вторая новая учётка заняла имя")
				_late = _session()
				_track(_late)
				_late.create_room("127.0.0.1", ABUSE_PORT, 2, GameSetup.MODE_STANDARD)
				_step = "abuse_accounts"
		"abuse_accounts":
			if lost.has(_late):
				check(String(lost[_late]).contains("Too many new players"),
					"[abuse] третья новая учётка с IP за сутки — отказ: %s" % lost[_late])
				check(not server.ratings.knows(RatingBook.account_of(_late.rating_key)), "[abuse] имя третьей не занято")
				players[0].friends_received.connect(func(d: Dictionary):
					_abuse_replies += 1
					_abuse_note = String(d.get("note", "")))
				for i in NetSession.FRIEND_RATE_COUNT + 1:
					players[0].friends_action("add", [players[1].profile["name"]])
				_step = "abuse_friends"
		"abuse_friends":
			if _abuse_replies >= NetSession.FRIEND_RATE_COUNT + 1:
				check(_abuse_note.contains("Too many requests"),
					"[abuse] %d-я заявка подряд — «подождите»: %s" % [NetSession.FRIEND_RATE_COUNT + 1, _abuse_note])
				var b_account := RatingBook.account_of(players[1].rating_key)
				check(server.ratings.friends.incoming(b_account).size() == 1, "[abuse] заявка у второго одна")
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
	for extra in ["_friends", "_records"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_PATH.get_basename() + extra + ".json"))
	server.ratings = RatingBook.new(RATINGS_PATH)
	server.saves_dir = SAVES_DIR
	check(server.serve(MATCH_PORT, true) == OK, "[match] сервер открыл порт")
	var ps: Array[NetSession] = []
	for i in 4:
		ps.append(_session())
	players = ps
	for p in players:
		_track(p)
	# Предпочтительный бан: у каждого свой; чужое имя полуколоды сервер отбрасывает.
	for i in 3:
		players[i].find_match("127.0.0.1", MATCH_PORT, 2, false, MATCH_BANS[i])
	players[3].find_match("127.0.0.1", MATCH_PORT, 3, false, "no_such_deck")
	_step = "match_wait"


## Пауза (решение владельца, 2026-09-27): первый ставит общую паузу — ход не
## принимается, второй её снять не может; первый снимает. Потом второй
## отключается — партия встаёт, а когда он не возвращается (здесь 1.5 с вместо
## 5 минут), партия кончается по текущему счёту без рейтинга.
func _start_pause() -> void:
	for p in players:
		p.close()
	if server != null:
		server.close()
	_scenario = "pause"
	_reset()
	_clear_saves_dir()
	server = _session()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_NAMES_PATH))
	for extra in ["_friends", "_records"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_PATH.get_basename() + extra + ".json"))
	server.ratings = RatingBook.new(RATINGS_PATH)
	server.saves_dir = SAVES_DIR
	server.abandon_seconds = 1.5
	check(server.serve(PAUSE_PORT, true) == OK, "[pause] сервер открыл порт")
	var a := _session()
	var b := _session()
	players = [a, b]
	for p in players:
		_track(p)
	a.create_room("127.0.0.1", PAUSE_PORT, 2, GameSetup.MODE_STANDARD)
	_step = "pause_wait_code"


## Защита сервера (этап Sec-2): подбор кода комнаты с одного IP, отказанный
## клиент, что не уходит сам, лимит новых учётных записей с IP (здесь 2) и
## заявок в друзья подряд.
func _start_abuse() -> void:
	for p in players:
		p.close()
	if server != null:
		server.close()
	_scenario = "abuse"
	_reset()
	_clear_saves_dir()
	server = _session()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_NAMES_PATH))
	for extra in ["_friends", "_records"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_PATH.get_basename() + extra + ".json"))
	server.ratings = RatingBook.new(RATINGS_PATH)
	server.saves_dir = SAVES_DIR
	server.accounts_per_ip = 2
	check(server.serve(ABUSE_PORT, true) == OK, "[abuse] сервер открыл порт")
	var a := _session()
	_track(a)
	players = [a]
	a.create_room("127.0.0.1", ABUSE_PORT, 2, GameSetup.MODE_STANDARD)
	_step = "abuse_room"


## Чей сейчас ход (по _turn_player, его ставит _answer_setup).
func _current_session() -> NetSession:
	return players[0] if players[0].seat == _turn_player else players[1]


func check_eq_str(got: String, expected: String, description: String) -> void:
	check(got == expected, "%s (получено «%s», ждали «%s»)" % [description, got, expected])


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
	for extra in ["_friends", "_records"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_PATH.get_basename() + extra + ".json"))
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
	for extra in ["_friends", "_records"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RATINGS_PATH.get_basename() + extra + ".json"))
	server.ratings = RatingBook.new(RATINGS_PATH)
	server.saves_dir = SAVES_DIR
	check(server.serve(SERVER_PORT, true) == OK, "[server] сервер открыл порт")
	# запас досок: один чертёж на двоих готов заранее — партия должна взять его
	var stock := BoardStock.new()
	var waited := Time.get_ticks_msec()
	while stock.count(2) < 1 and Time.get_ticks_msec() - waited < 60000:
		stock.tick()
		OS.delay_msec(5)
	stock.close()
	var ready_stock: Array = stock._ready[2]
	_stock_seed = int(ready_stock[0]["seed"]) if not ready_stock.is_empty() else -1
	server.board_stock = stock
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
	pings.clear()
	lost.clear()
	rejoined.clear()
	queue_seen.clear()
	dealing_seen.clear()
	bans_seen.clear()
	banned_by.clear()
	pause_seen.clear()


func _session() -> NetSession:
	_branches += 1
	var branch := Node.new()
	branch.name = "Side%d" % _branches
	root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	var net := NetSession.new()
	net.name = "Net"
	net.replays_dir = REPLAYS_DIR
	net.records_dir = RECORDS_DIR
	branch.add_child(net)
	return net


func _track(p: NetSession) -> void:
	_tracked += 1
	# Все хотят purple: за столом он достаётся одному, остальные — другие цвета.
	p.profile = {"name": "Player %d" % _tracked, "emblem": _emblem_for(_branches), "back": _back_for(_tracked),
		"colour": "purple", "shader": "gilded", "arts": "48310_1,48403_2", "favourite": "48314"}
	p.rating_key = "%032d" % p.get_instance_id()
	p.rating_changed.connect(func(r: Dictionary): ratings[p] = r)
	p.dealing_started.connect(func(): dealing_seen[p] = true)
	# Лобби банов: свой первый бан — первая незабаненная карта первой
	# полуколоды, второй — SKIP.
	p.bans_changed.connect(func(v: Dictionary):
		bans_seen[p] = v
		if String(v.get("turn", "")) != p.seat or p.seat == "":
			return
		if banned_by.has(p):
			p.ban_card("")
			return
		var taken: Array = (v["bans"] as Array).map(func(b): return String(b["card"]))
		var ids: Array = GameSetup.half_deck_copies(String((v["decks"] as Array)[0])).keys()
		ids.sort()
		for cid in ids:
			if not taken.has(cid):
				banned_by[p] = String(cid)
				p.ban_card(String(cid))
				return)
	views[p] = {}
	errors[p] = []
	chats[p] = []
	pings[p] = []
	p.game_started.connect(func(_s: String, b: Dictionary, v: Dictionary):
		boards[p] = b
		views[p] = v)
	p.result_received.connect(func(e: int, _ev: Array, v: Dictionary):
		errors[p].append(e)
		views[p] = v)
	p.chat_received.connect(func(w: String, t: String): chats[p].append([w, t]))
	p.ping_received.connect(func(w: String, z: String, at: Vector2): pings[p].append([w, z, at]))
	p.connection_lost.connect(func(reason: String): lost[p] = reason)
	p.player_rejoined.connect(func(who: String): rejoined[p] = who)
	p.queue_changed.connect(func(w: int, n: int): queue_seen[p] = [w, n])
	p.pause_changed.connect(func(s: Dictionary): pause_seen[p] = s)


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
	b.send_ping("board", Vector2(12, -34))
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
	for name in ReplayBook.list(REPLAYS_DIR):
		ReplayBook.erase(name, REPLAYS_DIR)
	for name in ReplayBook.list(RECORDS_DIR):
		ReplayBook.erase(name, RECORDS_DIR)
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


## Рубашка у всех одна (CardBack.CLASSIC) — в профиле это "".
func _back_for(_n: int) -> String:
	return ""


func _watcher_friends() -> Dictionary:
	return _friends.get(_watcher, {})
