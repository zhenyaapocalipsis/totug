class_name NetSession
extends Node

## Сетевая игра по ENet (этап 6). Три роли одного и того же узла:
##
##   - хост по IP (host): держит одну комнату и сам в ней играет;
##   - выделенный сервер (serve с dedicated=true, запуск `-- --server`):
##     держит много комнат с кодами, сам не играет;
##   - клиент (join / create_room / enter_room / find_match): только шлёт
##     намерения.
##
## Поиск игры (find_match): выделенный сервер держит очередь на каждое число
## игроков (2, 3, 4). Кто первым встал — тот первым и сядет, без подбора по
## рейтингу. Набралось сколько нужно — сервер сам заводит комнату RANDOM 4 и
## сразу раздаёт, кнопки START нет.
##
## Партию держит только тот, у кого комнаты (GameRoom -> GameServer). Клиент
## шлёт Intent словарём и получает свой срез (StateView) — чужую руку он не
## получает вовсе.
##
## Пауза (решение владельца, 2026-09-27): кто-то отключился посреди партии —
## партия встаёт у всех (ходы не принимаются, таймеры стоят), пока он не
## вернётся; не вернулся за abandon_seconds — партия кончается по текущему
## счёту, рейтинг не меняется. Общую паузу может поставить и любой игрок
## кнопкой; снять её может только он, а через pause_seconds она снимается сама.
## Клиент запоминает партию на диске (resume_path) — после перезапуска игры в
## главном меню есть RETURN TO GAME.
##
## Узел должен лежать по одному и тому же пути у всех (RPC адресуются путём
## узла) — /root/Net. Скрипт тоже должен совпадать: сервер со старой версией
## игры отвечает «обновите игру» (PROTOCOL).

signal lobby_changed(joined: Array, needed: int, code: String, owner_seat: String)
signal game_started(seat: String, board: Dictionary, view: Dictionary)
signal result_received(err: int, events: Array, view: Dictionary)
signal chat_received(seat: String, text: String)
## Пинг игрока (Tab): зона экрана и точка в ней (PING_ZONES).
signal ping_received(seat: String, zone: String, pos: Vector2)
signal player_left(seat: String)
## Кто-то, кто раньше отключился, вернулся под тем же профилем (этап 7).
signal player_rejoined(seat: String)
## Сервер пересчитал рейтинг после партии: место -> {rating, delta}.
signal rating_changed(result: Dictionary)
## Партия окончена, сервер прислал её реплей {header, intents} (ReplayBook) —
## экран партии строит по нему графики итогов.
signal replay_received(replay: Dictionary)
## Связь не установилась, оборвалась или сервер отказал (нет комнаты и т.п.).
signal connection_lost(reason: String)
## Хост: чем кончилась попытка открыть порт на роутере (UPnP). address — внешний
## адрес для друзей, "" если не вышло; note — пояснение для лобби.
signal upnp_finished(address: String, note: String)
## Поиск игры: в очереди стоят waiting человек из needed.
signal queue_changed(waiting: int, needed: int)
## Пауза партии изменилась: {absent: {цвет: секунд до конца партии}, by: кто
## поставил общую паузу, left: секунд до её конца} (GameRoom.pause_status).
signal pause_changed(status: Dictionary)

## Игра по IP (локальная сеть, Radmin VPN).
const DEFAULT_PORT := 7777
## Выделенный сервер с комнатами.
const SERVER_PORT := 7780
## Адрес сервера по умолчанию — наш VPS (Ubuntu, systemd-служба tyrants,
## см. server/README.md). Для проверки на одном компьютере — 127.0.0.1.
const DEFAULT_SERVER := "129.101.123.70"
## Меняется при любой несовместимой правке сети или правил: сервер и игроки
## должны играть одной версией.
const PROTOCOL := 17
## Режим партий, собранных поиском игры: зависит от размера стола
## (2 — STANDARD, 3 — RANDOM 3, 4 — RANDOM 4).
static func match_mode(player_count: int) -> String:
	match player_count:
		2:
			return GameSetup.MODE_STANDARD
		3:
			return GameSetup.MODE_RANDOM_3
	return GameSetup.MODE_RANDOM_4


const MAX_ROOMS := 64
const MAX_SERVER_PEERS := 128
## Без похожих друг на друга знаков (0/O, 1/I).
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
## Отказ, если имя уже занято другим игроком (RatingBook.claim_name). Лобби
## само ставит точку в конце.
const NAME_TAKEN := "The name %s is taken by another player. Go BACK and click your name to change it"
const CODE_LENGTH := 4
## Пинги и фразы чата: не больше RATE_COUNT за RATE_WINDOW_MS (решение
## владельца, 2026-09-29). Сервер считает окно чуть короче, чем игрок: так
## задержка сети не режет то, что игрок у себя уже пропустил.
const RATE_COUNT := 3
const RATE_WINDOW_MS := 5000
const SERVER_RATE_WINDOW_MS := 4500
const PING_ZONES := ["board", "market", "players", "barracks"]

## У этой программы есть комнаты (хост по IP или сервер).
var is_host := false
var dedicated := false
## Свой цвет за столом ("" — пока не рассадили) и код своей комнаты.
var seat := ""
var room_code := ""
var started := false
## Свой профиль {name, emblem} (PlayerProfile) — уходит в комнату при входе.
var profile: Dictionary = {}
## Ключ рейтинга; пустой — из профиля (PlayerProfile.key). Тест даёт свой.
var rating_key := ""
## Профили за столом: цвет -> {name, emblem}; приходят с лобби и стартом.
var profiles: Dictionary = {}

## Рейтинги онлайн-партий — только у выделенного сервера (RatingBook).
var ratings: RatingBook
## Папка сохранений партий (GameJournal) — своя у сетевого теста, чтобы не
## трогать настоящие сохранения владельца.
var saves_dir := GameJournal.DIR
## Папка реплеев (ReplayBook) — тоже своя у сетевого теста.
var replays_dir := ReplayBook.DIR
## Клиент: файл реплея последней партии. Сервер шлёт реплей раньше итога
## рейтинга (_rating), и строка истории запоминает этот файл.
var last_replay := ""
var rooms: Dictionary = {}      # code -> GameRoom
var peer_room: Dictionary = {}  # peer id -> code
## Поиск игры: число игроков -> очередь peer id (по порядку прихода) и кто
## стоит в очереди: peer id -> {needed, name, emblem, key}.
var queues: Dictionary = {}
var queued: Dictionary = {}
## Когда игрок последний раз пинговал или писал: peer id -> [мс, ...] (rate_ok).
var _said: Dictionary = {}
var _lan_code := ""
## Что отправить серверу, как только связь установится (вход или создание).
var _on_connected: Callable
var _rng := RandomNumberGenerator.new()

## Этап 7: переподключение и сохранение партии.
## Клиент: параметры последнего join()/enter_room(), чтобы reconnect() мог
## повторить попытку тем же путём после обрыва связи.
var _last_address := ""
var _last_port := 0
var _last_code := ""
var _last_by_code := false

## Пауза (сервер): сколько ждать отключившегося, пока партия не кончится, и
## сколько длится общая пауза кнопкой. Тест ставит поменьше.
var abandon_seconds := 300.0
var pause_seconds := 300.0
## Клиент: последняя пауза от сервера (см. pause_changed) — экран партии,
## собранный после переподключения, берёт её отсюда.
var pause_status: Dictionary = {}
## Файл, где клиент помнит свою незаконченную онлайн-партию (RETURN TO GAME).
## Тест даёт свой, чтобы не трогать файл владельца.
static var resume_path := "user://online_game.cfg"
## Сейчас идёт возврат в запомненную партию (resume_saved): отказ сервера
## значит, что её уже нет, — запись стирается.
var _resuming := false
## Сервер: сколько ждать подтверждения пакетов, прежде чем счесть игрока
## отключившимся (мс; по умолчанию ENet ждёт до 30 с — пауза вставала поздно).
const PEER_TIMEOUT_MIN := 5000
const PEER_TIMEOUT_MAX := 15000


## Подписки на события связи — один раз: повторное подключение после ошибки
## не должно их удваивать.
func _ready() -> void:
	_rng.randomize()
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(func():
		if _on_connected.is_valid():
			_on_connected.call())
	multiplayer.connection_failed.connect(func(): _lost("Could not connect"))
	multiplayer.server_disconnected.connect(func(): _lost("The connection to the game was lost"))


func _lost(reason: String) -> void:
	multiplayer.multiplayer_peer = null
	connection_lost.emit(reason)


## Сервер: пропавшего игрока (завис, закрыли игру) замечаем за 5-15 с, а не
## за 30 — столько партия шла бы дальше без паузы.
func _on_peer_connected(id: int) -> void:
	if not is_host:
		return
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null:
		return
	var peer := enet.get_peer(id)
	if peer != null:
		peer.set_timeout(0, PEER_TIMEOUT_MIN, PEER_TIMEOUT_MAX)


## Сервер: время пауз во всех комнатах.
func _process(delta: float) -> void:
	if not is_host:
		return
	for room: GameRoom in rooms.values():
		# Настоящее время: скорость анимаций (Engine.time_scale) паузу не торопит.
		var real := delta / Engine.time_scale if Engine.time_scale > 0.0 else 0.0
		var what := room.tick_pause(real, abandon_seconds, pause_seconds)
		if what.has("abandon"):
			_abandon_room(room, String(what["abandon"]))
		elif what.has("resumed"):
			_broadcast_pause(room)


## Принимать подключения. dedicated — выделенный сервер: комнаты заводят
## сами игроки, сам сервер не играет.
func serve(port: int, is_dedicated: bool = false) -> int:
	close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_SERVER_PEERS if is_dedicated else GameRoom.MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	dedicated = is_dedicated
	if dedicated:
		if ratings == null:
			ratings = RatingBook.new()
		_load_saved_rooms()
	return OK


## Выделенный сервер при старте (в т.ч. после перезапуска — systemctl restart
## после каждого deploy.sh): поднять партии, прерванные перезапуском, из
## GameJournal. Игроки возвращаются в них через claim() (_enter), как и при
## обычном обрыве связи — самому серверу для этого рестарт не нужен.
func _load_saved_rooms() -> void:
	for code in GameJournal.list_codes(saves_dir):
		var saved := GameJournal.load_game(code, saves_dir)
		if saved.is_empty():
			continue
		var room := GameRoom.restore(saved["header"], saved["intents"])
		if room.server.state.game_over:
			GameJournal.erase(code, saves_dir)
			continue
		rooms[room.code] = room
		_log("room %s restored: %d moves replayed" % [room.code, (saved["intents"] as Array).size()])


## Хост по IP: одна комната, хост сидит за первым цветом.
func host(port: int, player_count: int, mode: String) -> int:
	var err := serve(port)
	if err != OK:
		return err
	var room := _new_room(player_count, mode)
	_lan_code = room.code
	_seat_peer.call_deferred(room, 1)
	return OK


## Клиент: к хосту по IP.
func join(address: String, port: int) -> int:
	_last_address = address
	_last_port = port
	_last_by_code = false
	return _connect(address, port, func(): _enter.rpc_id(1, PROTOCOL, "", _client_key()))


## Клиент: на сервере завести новую комнату.
func create_room(address: String, port: int, player_count: int, mode: String) -> int:
	_remember_server(address, port)
	return _connect(address, port, func(): _create.rpc_id(1, PROTOCOL, player_count, mode))


## Клиент: встать в очередь поиска игры на player_count человек. Профиль идёт
## прямо с просьбой: комнаты ещё нет, и _profile_up её бы не нашёл.
func find_match(address: String, port: int, player_count: int) -> int:
	_remember_server(address, port)
	return _connect(address, port, func():
		var p := PlayerProfile.clean(profile)
		_queue.rpc_id(1, PROTOCOL, player_count, p["name"], p["emblem"], p["back"], _client_key(), p["shader"], p["arts"], p["favourite"],
			p["colour"]))


## Комнату на сервере завели не по коду (CREATE ROOM, поиск игры) — её код
## придёт с лобби (_lobby), по нему reconnect() и вернёт в партию.
func _remember_server(address: String, port: int) -> void:
	_last_address = address
	_last_port = port
	_last_code = ""
	_last_by_code = true


## Клиент: на сервере войти в комнату по коду.
func enter_room(address: String, port: int, code: String) -> int:
	var clean := code.strip_edges().to_upper()
	_last_address = address
	_last_port = port
	_last_code = clean
	_last_by_code = true
	return _connect(address, port, func(): _enter.rpc_id(1, PROTOCOL, clean, _client_key()))


## Повторить последний join()/enter_room() тем же путём — после обрыва связи
## (этап 7). Сервер узнает игрока по ключу профиля и вернёт на его место, если
## партия ещё не закончилась (см. GameRoom.claim). ERR_UNCONFIGURED — ещё не
## подключались, звать нечего.
func reconnect() -> int:
	if _last_address == "":
		return ERR_UNCONFIGURED
	if _last_by_code:
		return enter_room(_last_address, _last_port, _last_code)
	return join(_last_address, _last_port)


## Клиент: запомнить на диске, куда вернуться в эту партию (RETURN TO GAME в
## главном меню) — на случай, если игру закроют или она упадёт. Хост по IP не
## пишет: его партия живёт в самой программе и с ней же пропадает.
func _remember_game() -> void:
	if is_host or _last_address == "":
		return
	var cfg := ConfigFile.new()
	cfg.set_value("game", "address", _last_address)
	cfg.set_value("game", "port", _last_port)
	cfg.set_value("game", "code", room_code)
	cfg.set_value("game", "by_code", _last_by_code)
	cfg.save(resume_path)


## Незаконченная онлайн-партия, в которую можно вернуться: {address, port,
## code, by_code}; {} — такой нет.
static func saved_game() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(resume_path) != OK:
		return {}
	var address := String(cfg.get_value("game", "address", ""))
	var code := String(cfg.get_value("game", "code", ""))
	var by_code := bool(cfg.get_value("game", "by_code", false))
	if address == "" or (by_code and code == ""):
		return {}
	return {"address": address, "port": int(cfg.get_value("game", "port", 0)), "code": code,
		"by_code": by_code}


static func forget_game() -> void:
	if FileAccess.file_exists(resume_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(resume_path))


## RETURN TO GAME: войти в запомненную партию тем же путём, что и в первый раз.
## Сервер узнает игрока по ключу профиля (GameRoom.claim).
func resume_saved() -> int:
	var game := saved_game()
	if game.is_empty():
		return ERR_UNCONFIGURED
	_resuming = true
	if bool(game["by_code"]):
		return enter_room(String(game["address"]), int(game["port"]), String(game["code"]))
	return join(String(game["address"]), int(game["port"]))


## Ключ, по которому сервер узнаёт этого игрока при переподключении (и, на
## выделенном сервере, для рейтинга) — тест даёт свой через rating_key.
func _client_key() -> String:
	return rating_key if rating_key != "" else PlayerProfile.key()


func _connect(address: String, port: int, then: Callable) -> int:
	close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	# Профиль идёт следом за входом: пакеты надёжные и по порядку, так что
	# комната к его приходу уже знает, за каким цветом этот игрок.
	_on_connected = func():
		then.call()
		var p := PlayerProfile.clean(profile)
		_profile_up.rpc_id(1, p["name"], p["emblem"], p["back"], _client_key(), p["colour"], p["shader"], p["arts"],
			p["favourite"])
	return OK


func close() -> void:
	_close_upnp()
	_on_connected = Callable()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_host = false
	dedicated = false
	# Фоновые снимки доски (_start_room) дожидаемся: бросить поток нельзя.
	for room: GameRoom in rooms.values():
		if room.board_task >= 0:
			WorkerThreadPool.wait_for_task_completion(room.board_task)
			room.board_task = -1
	rooms.clear()
	peer_room.clear()
	queues.clear()
	queued.clear()
	seat = ""
	room_code = ""
	started = false
	profiles = {}
	pause_status = {}


## Своя комната полна (для лобби хоста по IP).
func is_full() -> bool:
	var room: GameRoom = rooms.get(_lan_code)
	return room != null and room.is_full()


# --- UPnP: порт на роутере хоста ---------------------------------------------
#
# Чтобы друг из интернета достучался до хоста, роутер хоста должен пропускать
# порт внутрь. UPnP просит роутер сделать это самому, без настроек вручную.
# Поиск роутера занимает пару секунд, поэтому — в отдельном потоке.
# Не сработает, если UPnP в роутере выключен или провайдер не даёт «белый»
# адрес (тогда выручает Radmin VPN).

var _upnp: UPNP
var _upnp_thread: Thread
var _upnp_port := 0


func open_upnp(port: int) -> void:
	if _upnp_thread != null:
		return
	_upnp_port = port
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_work.bind(port))


## Итог потока. Лежит в полях, а не в аргументах отложенного вызова: если
## лобби закроют раньше, _close_upnp всё равно узнает про открытый порт.
var _found_upnp: UPNP
var _found_address := ""
var _found_note := ""


func _upnp_work(port: int) -> void:
	# Роутер ищем через каждую сетевую карту по очереди: без явного выбора
	# поиск уходил в туннель VPN-программы (так было у владельца — happ-xray)
	# и роутер «не отвечал».
	var upnp: UPNP = null
	var saw_router := false
	# Домашние сети (192.168.*, 10.*) — первыми, выбор системы ("") — последним.
	var cards: Array[String] = []
	for address: String in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("26."):
			continue
		if address.begins_with("192.168.") or address.begins_with("10."):
			cards.push_front(address)
		else:
			cards.append(address)
	cards.append("")
	for card in cards:
		var probe := UPNP.new()
		probe.discover_multicast_if = card
		if probe.discover(2000, 2, "InternetGatewayDevice") != UPNP.UPNP_RESULT_SUCCESS \
				or probe.get_device_count() == 0:
			continue
		# Роутер ответил — дальше не ищем, ответ другой карты будет тем же.
		saw_router = true
		if probe.get_gateway() != null and probe.get_gateway().is_valid_gateway():
			upnp = probe
		break
	if upnp == null:
		# Роутер ответил, но годным не назвался — чаще всего у него самого
		# нет «белого» адреса: провайдер делит один адрес на многих.
		_found_note = "Your router has no public internet address (provider NAT)." if saw_router \
			else "Router did not answer (UPnP is off or unsupported)."
	else:
		var external := upnp.query_external_address()
		if not is_public_ipv4(external):
			_found_note = "Your provider gives no public address (%s)." % (
				external if external != "" else "unknown")
		elif upnp.add_port_mapping(port, port, "Tyrants of the Underdark", "UDP", 0) != UPNP.UPNP_RESULT_SUCCESS:
			_found_note = "Router refused to open port %d." % port
		else:
			_found_upnp = upnp
			_found_address = external
			_found_note = "Port %d is open on your router." % port
	_upnp_done.call_deferred()


func _upnp_done() -> void:
	if _upnp_thread == null:
		return  # уже закрыли
	_upnp_thread.wait_to_finish()
	_upnp_thread = null
	_upnp = _found_upnp
	upnp_finished.emit(_found_address, _found_note)


## Закрыть порт на роутере за собой. Поток поиска дожидаемся: бросить его
## посреди работы нельзя.
func _close_upnp() -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
		_upnp = _found_upnp
	_found_upnp = null
	if _upnp != null:
		_upnp.delete_port_mapping(_upnp_port, "UDP")
		_upnp = null


func _exit_tree() -> void:
	close()


## «Белый» ли адрес: частные сети (10.*, 172.16-31.*, 192.168.*) и адреса
## провайдерского NAT (100.64-127.*) из интернета недоступны.
static func is_public_ipv4(address: String) -> bool:
	var parts := address.split(".")
	if parts.size() != 4:
		return false
	for p in parts:
		if not p.is_valid_int() or int(p) < 0 or int(p) > 255:
			return false
	var a := int(parts[0])
	var b := int(parts[1])
	if a == 10 or a == 127 or a == 0 or a >= 224:
		return false
	if a == 172 and b >= 16 and b <= 31:
		return false
	if a == 192 and b == 168:
		return false
	if a == 100 and b >= 64 and b <= 127:
		return false
	if a == 169 and b == 254:
		return false
	return true


# --- комнаты (хост / сервер) -------------------------------------------------

func _new_room(player_count: int, mode: String) -> GameRoom:
	var code := ""
	while code == "" or rooms.has(code):
		code = ""
		for i in CODE_LENGTH:
			code += CODE_CHARS[_rng.randi_range(0, CODE_CHARS.length() - 1)]
	var room := GameRoom.new(code, player_count, mode)
	rooms[code] = room
	return room


func _room_of(peer: int) -> GameRoom:
	return rooms.get(peer_room.get(peer, ""))


func _seat_peer(room: GameRoom, peer: int) -> void:
	# Хост по IP сам сидит в своей комнате: его профиль не нужно слать по сети.
	var own := peer == 1 and is_host and not dedicated
	var p := PlayerProfile.clean(profile)
	var pid := room.add(peer, String(p["colour"]) if own else "")
	if pid == "":
		return
	peer_room[peer] = room.code
	if own:
		room.profiles[pid] = p
	_broadcast_lobby(room)


@rpc("any_peer", "call_remote", "reliable")
func _profile_up(player_name: String, emblem: String, back: String, key: String, colour: String,
		shader: String, arts: String, favourite: String) -> void:
	if not is_host:
		return
	var peer := multiplayer.get_remote_sender_id()
	var room := _room_of(peer)
	if room == null or room.started or not room.seats.has(peer):
		return
	# Место освободится само, когда клиент по отказу закроет связь.
	if not _name_free(peer, player_name, key):
		return
	var pid := room.prefer(peer, PlayerProfile.clean_colour(colour))
	_set_profile(room, pid, player_name, emblem, back, key, shader, arts, favourite)
	_broadcast_lobby(room)


## Имя на выделенном сервере у каждого своё (RatingBook.claim_name): занятое
## другим игроком — отказ. Игра по IP (без книги рейтингов) имена не проверяет.
func _name_free(peer: int, player_name: String, key: String) -> bool:
	if ratings == null:
		return true
	var clean_name := PlayerProfile.clean_name(player_name)
	if ratings.claim_name(RatingBook.account_of(key), clean_name):
		return true
	_refuse(peer, NAME_TAKEN % clean_name)
	return false


func _set_profile(room: GameRoom, pid: String, player_name: String, emblem: String, back: String, key: String,
		shader: String = "", arts: String = "", favourite: String = "") -> void:
	# Ключ хранится всегда (не только на выделенном сервере): по нему находит
	# своё место переподключившийся игрок, а host-по-IP тоже даёт переподключение,
	# хоть рейтинг там и не считается.
	room.keys[pid] = key
	var p := PlayerProfile.clean({"name": player_name, "emblem": emblem, "back": back, "shader": shader, "arts": arts,
		"favourite": favourite})
	# Рейтинг видят все за столом; сам ключ дальше сервера не уходит.
	if ratings != null:
		var account := RatingBook.account_of(key)
		room.accounts[pid] = account
		if account != "":
			p.merge(ratings.stats_of(account))
	room.profiles[pid] = p


@rpc("any_peer", "call_remote", "reliable")
func _create(version: int, player_count: int, mode: String) -> void:
	# Заводить комнаты по сети можно только на выделенном сервере.
	if not dedicated:
		return
	var peer := multiplayer.get_remote_sender_id()
	if not _check_newcomer(peer, version):
		return
	if rooms.size() >= MAX_ROOMS:
		_refuse(peer, "The server is full, try again later")
		return
	var room := _new_room(player_count, mode)
	_seat_peer(room, peer)
	_log("room %s created: %d players, %s" % [room.code, room.needed, room.mode])


## Поиск игры: встать в очередь на player_count человек (только выделенный сервер).
@rpc("any_peer", "call_remote", "reliable")
func _queue(version: int, player_count: int, player_name: String, emblem: String, back: String,
		key: String, shader: String, arts: String, favourite: String, colour: String) -> void:
	if not dedicated:
		return
	var peer := multiplayer.get_remote_sender_id()
	if not _check_newcomer(peer, version):
		return
	if not _name_free(peer, player_name, key):
		return
	var needed := clampi(player_count, GameRoom.MIN_PLAYERS, GameRoom.MAX_PLAYERS)
	var line: Array = queues.get(needed, [])
	line.append(peer)
	queues[needed] = line
	queued[peer] = {"needed": needed, "name": player_name, "emblem": emblem, "back": back, "key": key, "shader": shader, "arts": arts,
		"favourite": favourite,
		"colour": PlayerProfile.clean_colour(colour)}
	_log("queue %d: %d waiting" % [needed, line.size()])
	# Сервер забит комнатами — стоят дальше; следующий пришедший проверит снова.
	if line.size() >= needed and rooms.size() < MAX_ROOMS:
		_match(needed)
	_broadcast_queue(needed)


## Первые needed из очереди садятся за новый стол, и партия сразу раздаётся.
func _match(needed: int) -> void:
	var line: Array = queues[needed]
	var room := _new_room(needed, match_mode(needed))
	room.matched = true
	# Сначала рассадка по любимым цветам (кто раньше встал в очередь, тому и
	# цвет), профили — когда места уже окончательные.
	var batch: Array = line.slice(0, needed)
	for peer: int in batch:
		room.add(peer, String(queued[peer].get("colour", "")))
		peer_room[peer] = room.code
	for peer: int in batch:
		var q: Dictionary = queued[peer]
		queued.erase(peer)
		_set_profile(room, String(room.seats[peer]), String(q["name"]), String(q["emblem"]), String(q["back"]),
			String(q["key"]), String(q.get("shader", "")), String(q.get("arts", "")), String(q.get("favourite", "")))
	queues[needed] = line.slice(needed)
	_log("room %s matched: %d players, %s" % [room.code, room.needed, room.mode])
	_broadcast_lobby(room)
	_start_room(room, _rng.randi())


func _broadcast_queue(needed: int) -> void:
	var line: Array = queues.get(needed, [])
	for peer: int in line:
		_send(peer, "_queue_status", [line.size(), needed])


## Ушёл из очереди (закрыл поиск или пропала связь).
func _leave_queue(peer: int) -> void:
	var needed := int(queued[peer]["needed"])
	queued.erase(peer)
	(queues[needed] as Array).erase(peer)
	_broadcast_queue(needed)


@rpc("authority", "call_remote", "reliable")
func _queue_status(waiting: int, needed: int) -> void:
	queue_changed.emit(waiting, needed)


@rpc("any_peer", "call_remote", "reliable")
func _enter(version: int, code: String, key: String) -> void:
	if not is_host:
		return
	var peer := multiplayer.get_remote_sender_id()
	if not _check_newcomer(peer, version):
		return
	var room_key := _lan_code if not dedicated else code
	var room: GameRoom = rooms.get(room_key)
	if room == null:
		_refuse(peer, "There is no room %s" % code)
		return
	if room.started:
		# Тот же игрок (тот же ключ) пришёл заново, а старое соединение ещё не
		# отвалилось (Alt+F4): оно мёртвое — отключаем его и отдаём место новому.
		# Раньше тут был отказ "already started", клиент стирал запись о партии,
		# и кнопка RETURN TO GAME пропадала насовсем.
		var stale := room.peer_with_key(key)
		if stale != 0 and stale != peer and not (stale == 1 and not dedicated):
			peer_room.erase(stale)
			room.remove(stale)
			var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
			if enet != null:
				enet.disconnect_peer(stale, true)
			_log("room %s: stale connection of a returning player dropped" % room.code)
		var pid := room.claim(peer, key)
		if pid == "":
			_refuse(peer, "This game has already started")
			return
		peer_room[peer] = room.code
		_deliver_reconnect(room, peer, pid)
		# Вернулся — пауза снята (или стоит дальше, если ждут ещё кого-то).
		_broadcast_pause(room)
		_log("room %s: %s reconnected" % [room.code, pid])
		return
	if room.is_full():
		_refuse(peer, "This game is full")
		return
	_seat_peer(room, peer)
	_log("room %s: %d of %d" % [room.code, room.seats.size(), room.needed])


## Переподключение (этап 7): игрок уже сидел за pid, но потерял связь. Отдаём
## ему тот же board_snapshot, что и при старте (кэширован в room.cached_board,
## пересчитывать не нужно — геометрия доски за партию не меняется), и свежий
## StateView с тем же pending, что видят остальные.
func _deliver_reconnect(room: GameRoom, peer: int, pid: String) -> void:
	var view := StateView.for_player_with_pending(room.server.state, pid, room.server.resolver.pending)
	_send(peer, "_reconnected", [pid, room.cached_board, view, room.profiles])
	for other: int in room.seats:
		if other != peer:
			_send(other, "_rejoined", [pid])


func _check_newcomer(peer: int, version: int) -> bool:
	if version != PROTOCOL:
		_refuse(peer, "Different game version (yours %d, server %d): update the game" % [version, PROTOCOL])
		return false
	return not peer_room.has(peer) and not queued.has(peer)


func _refuse(peer: int, reason: String) -> void:
	_refused.rpc_id(peer, reason)


@rpc("authority", "call_remote", "reliable")
func _refused(reason: String) -> void:
	# Запомненной партии на сервере больше нет (или место в ней не наше).
	if _resuming:
		_resuming = false
		forget_game()
	# Связь рвём не сразу: закрывать её прямо внутри приёма пакета нельзя.
	close.call_deferred()
	connection_lost.emit(reason)


func _on_peer_disconnected(id: int) -> void:
	_said.erase(id)
	if queued.has(id):
		_leave_queue(id)
		return
	var room := _room_of(id)
	peer_room.erase(id)
	if room == null:
		return
	var gone := String(room.seats.get(id, ""))
	room.remove(id)
	if room.started:
		# Место не освобождается: игрок возвращается на него через claim()
		# (см. _enter), даже если отвалились все — комнату и сохранение не
		# трогаем. Убираем только партию, которая уже закончилась: досматривать
		# нечего, а претендовать на место в ней больше некому.
		room.mark_absent(gone)
		for peer: int in room.seats:
			_send(peer, "_left", [gone])
		_broadcast_pause(room)
		if room.seats.is_empty() and room.server.state.game_over:
			rooms.erase(room.code)
			GameJournal.erase(room.code, saves_dir)
			_log("room %s closed (finished)" % room.code)
		return
	if room.seats.is_empty() or (not dedicated and id == 1):
		rooms.erase(room.code)
		GameJournal.erase(room.code, saves_dir)
		_log("room %s closed" % room.code)
		return
	_broadcast_lobby(room)


func _broadcast_lobby(room: GameRoom) -> void:
	for peer: int in room.seats:
		_send(peer, "_lobby", [room.seats[peer], room.joined(), room.needed, room.code, room.owner_seat(),
			room.profiles])


@rpc("authority", "call_remote", "reliable")
func _lobby(your_seat: String, joined: Array, needed: int, code: String, owner_seat: String,
		seat_profiles: Dictionary) -> void:
	seat = your_seat
	room_code = code
	if _last_by_code:
		_last_code = code
	profiles = seat_profiles.duplicate(true)
	var own: Dictionary = profiles.get(seat, {})
	if own.has("rating"):
		PlayerProfile.cache_stats(own)
	lobby_changed.emit(joined, needed, code, owner_seat)


## START. У хоста по IP — сразу, у клиента — просьба серверу: начать может
## только создатель комнаты, и только когда все на местах.
func start_game(game_seed: int) -> void:
	if is_host and not dedicated:
		var room: GameRoom = rooms.get(_lan_code)
		if room != null and room.owner_peer == 1:
			_start_room(room, game_seed)
	elif not is_host:
		_start_request.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _start_request() -> void:
	var peer := multiplayer.get_remote_sender_id()
	var room := _room_of(peer)
	if room != null and room.owner_peer == peer:
		_start_room(room, _rng.randi())


func _start_room(room: GameRoom, game_seed: int) -> void:
	if room.started or not room.is_full():
		return
	if not dedicated:
		var dealt: Dictionary = room.start(game_seed)
		_deliver(room, dealt["board"], dealt["views"])
		return
	# Выделенный сервер: снимок доски (чертёж BoardSchematic) на одном ядре VPS
	# считается секунды, и всё это время молчали бы все комнаты. Поэтому он
	# считается в фоне; раздача (колоды, первый ход) — здесь: она быстрая и
	# трогает общие статические поля правил. Снимку нужны только данные этой
	# партии и таблицы, которые читаются, но не пишутся (прогреваем их здесь).
	var views := room.deal(game_seed)
	var state := room.server.state
	BoardSchematic.warm_up(state)
	room.board_task = WorkerThreadPool.add_task(func():
		_board_ready.call_deferred(room, StateView.board_snapshot(state), views))
	_log("room %s dealing" % room.code)


func _board_ready(room: GameRoom, board: Dictionary, views: Dictionary) -> void:
	if room.board_task < 0:
		return  # сессию закрыли, задачу уже дождался close()
	WorkerThreadPool.wait_for_task_completion(room.board_task)
	room.board_task = -1
	if rooms.get(room.code) != room:
		return  # пока считали, комната опустела
	_deliver(room, board, views)


func _deliver(room: GameRoom, board: Dictionary, views: Dictionary) -> void:
	room.cached_board = board
	_save_room(room)
	for peer: int in room.seats:
		_send(peer, "_start", [board, views[room.seats[peer]], room.profiles])
	_log("room %s started" % room.code)


## Записать журнал комнаты на диск (этап 7) — сразу после раздачи и после
## каждого успешного хода. Файл маленький (сид + список Intent'ов), поэтому
## целиком перезаписывается, как RatingBook.save().
func _save_room(room: GameRoom) -> void:
	GameJournal.save(room.code, {
		"code": room.code,
		"ids": room.ids,
		"mode": room.mode,
		"seed": room.game_seed,
		"profiles": room.profiles,
		"accounts": room.accounts,
		"keys": room.keys,
		"matched": room.matched,
		"mulligan": room.server.with_mulligan,
	}, room.log, saves_dir)


@rpc("authority", "call_remote", "reliable")
func _start(board: Dictionary, view: Dictionary, seat_profiles: Dictionary) -> void:
	started = true
	profiles = seat_profiles.duplicate(true)
	pause_status = {}
	_remember_game()
	game_started.emit(seat, board, view)


## Переподключение приняли — тот же сигнал, что и настоящий старт: экран
## партии всё равно надо собрать заново с нуля (см. game_scene._start_net_game).
@rpc("authority", "call_remote", "reliable")
func _reconnected(your_seat: String, board: Dictionary, view: Dictionary, seat_profiles: Dictionary) -> void:
	seat = your_seat
	started = true
	profiles = seat_profiles.duplicate(true)
	_resuming = false
	# Код комнаты с лобби при возврате не приходит — берём тот, по которому вошли.
	if room_code == "":
		room_code = _last_code
	_remember_game()
	_forget_if_over(view)
	game_started.emit(seat, board, view)


## Партия кончилась — возвращаться больше некуда.
func _forget_if_over(view: Dictionary) -> void:
	if not is_host and bool(view.get("game_over", false)):
		forget_game()


@rpc("authority", "call_remote", "reliable")
func _rejoined(who: String) -> void:
	player_rejoined.emit(who)


## Отправить игроку: себе (хост по IP играет сам) — вызовом, другим — по сети.
func _send(peer: int, method: String, args: Array) -> void:
	if peer == 1 and is_host and not dedicated:
		callv(method, args)
	else:
		var call_args: Array = [peer, method]
		call_args.append_array(args)
		callv("rpc_id", call_args)


# --- ходы --------------------------------------------------------------------

func send_intent(intent: Intent) -> void:
	if is_host:
		_room_apply(1, intent.to_dict())
	else:
		_intent.rpc_id(1, intent.to_dict())


@rpc("any_peer", "call_remote", "reliable")
func _intent(d: Dictionary) -> void:
	if is_host:
		_room_apply(multiplayer.get_remote_sender_id(), d)


func _room_apply(sender: int, d: Dictionary) -> void:
	var room := _room_of(sender)
	if room == null or not room.started or room.board_task >= 0:
		return
	if room.is_paused():
		var pid := String(room.seats[sender])
		_send(sender, "_result", [GameServer.Error.PAUSED, [],
			StateView.for_player_with_pending(room.server.state, pid, room.server.resolver.pending)])
		return
	var result: Dictionary = room.apply(sender, d)
	var err := int(result["error"])
	var views: Dictionary = result["views"]
	for peer: int in room.seats:
		# Отказ касается только того, кто ошибся: остальным слать нечего.
		if err != GameServer.Error.OK and peer != sender:
			continue
		var own_err := err if peer == sender else GameServer.Error.OK
		_send(peer, "_result", [own_err, result["events"], views[room.seats[peer]]])
	if err != GameServer.Error.OK:
		return
	if room.server.state.game_over:
		GameJournal.erase(room.code, saves_dir)
		_send_replay(room)
		if not room.rated:
			_rate_room(room)
	else:
		_save_room(room)


## Отсутствующий не вернулся вовремя: партия кончается по текущему счёту,
## рейтинг не меняется (решение владельца, 2026-09-27).
func _abandon_room(room: GameRoom, pid: String) -> void:
	var result := room.abandon(pid)
	GameJournal.erase(room.code, saves_dir)
	var views: Dictionary = result["views"]
	for peer: int in room.seats:
		_send(peer, "_result", [GameServer.Error.OK, result["events"], views[room.seats[peer]]])
	_broadcast_pause(room)
	_send_replay(room)
	_log("room %s: %s did not return, game over (not rated)" % [room.code, pid])


## Партия окончена — каждому за столом её реплей (ReplayBook). Прятать уже
## нечего: в реплее видны все руки и колоды. Кто в этот миг не за столом,
## реплея не получит.
func _send_replay(room: GameRoom) -> void:
	var state := room.server.state
	var header := ReplayBook.header_for(state, room.ids, room.game_seed, room.mode,
		room.server.with_mulligan, room.profiles, "", room.code, room.log)
	for peer: int in room.seats:
		_send(peer, "_replay", [header, room.log])


@rpc("authority", "call_remote", "reliable")
func _replay(header: Dictionary, intents: Array) -> void:
	var own := header.duplicate(true)
	own["seat"] = seat
	last_replay = ReplayBook.save(own, intents, replays_dir)
	replay_received.emit({"header": own, "intents": intents})


func _broadcast_pause(room: GameRoom) -> void:
	var status := room.pause_status(abandon_seconds, pause_seconds)
	for peer: int in room.seats:
		_send(peer, "_pause", [status])


@rpc("authority", "call_remote", "reliable")
func _pause(status: Dictionary) -> void:
	pause_status = status
	pause_changed.emit(status)


## Общая пауза кнопкой (on) или её снятие (снять может только поставивший).
func request_pause(on: bool) -> void:
	if is_host:
		_room_pause(1, on)
	else:
		_pause_up.rpc_id(1, on)


@rpc("any_peer", "call_remote", "reliable")
func _pause_up(on: bool) -> void:
	if is_host:
		_room_pause(multiplayer.get_remote_sender_id(), on)


func _room_pause(sender: int, on: bool) -> void:
	var room := _room_of(sender)
	if room == null or not room.set_manual_pause(String(room.seats.get(sender, "")), on):
		return
	_broadcast_pause(room)
	_log("room %s: pause %s by %s" % [room.code, "on" if on else "off", room.seats[sender]])


## Партия в комнате окончена — пересчитать рейтинг (только выделенный сервер).
func _rate_room(room: GameRoom) -> void:
	room.rated = true
	if ratings == null:
		return
	var state := room.server.state
	var players := {}
	var scores := {}
	var breakdowns := {}
	for pid: String in state.turn_order:
		players[pid] = {"account": String(room.accounts.get(pid, "")),
			"name": String((room.profiles.get(pid, {}) as Dictionary).get("name", ""))}
		breakdowns[pid] = Scoring.breakdown(state, pid)
		scores[pid] = int(breakdowns[pid]["total"])
	var vp := Scoring.library_card_vp(state)
	var winners := Array(Scoring.winners(state, vp[0], vp[1]))
	var result := ratings.record(players, scores, winners)
	if result.is_empty():
		_log("room %s: game over, not rated" % room.code)
		return
	# VP, победа, разбивка VP, полуколоды и Inner Circle — для истории и
	# статистики в профиле у каждого игрока (PlayerProfile.add_totals).
	for pid: String in result:
		result[pid]["vp"] = scores[pid]
		result[pid]["won"] = winners.has(pid)
		result[pid]["breakdown"] = breakdowns[pid]
		result[pid]["half_decks"] = Array(state.half_decks)
		result[pid]["ic_cards"] = (state.players[pid] as PlayerState).deck.inner_circle.size()
	# Награда за место — только партиям поиска игры (SkinCollection).
	if room.matched:
		for pid: String in result:
			result[pid]["reward"] = SkinCollection.reward_for_place(PlayerProfile.place_of(pid, result))
	_log("room %s: rated %s" % [room.code, JSON.stringify(result)])
	for peer: int in room.seats:
		_send(peer, "_rating", [result])


@rpc("authority", "call_remote", "reliable")
func _rating(result: Dictionary) -> void:
	if result.has(seat):
		PlayerProfile.cache_stats(result[seat])
		var entry := PlayerProfile.history_entry(seat, result, profiles)
		entry["replay"] = last_replay
		last_replay = ""
		PlayerProfile.add_history(entry)
		var kept := []
		for game: Dictionary in PlayerProfile.history():
			kept.append(String(game.get("replay", "")))
		ReplayBook.keep_only(kept, replays_dir)
		PlayerProfile.add_totals(entry)
		SkinCollection.grant(result[seat].get("reward", {}))
	rating_changed.emit(result)


@rpc("authority", "call_remote", "reliable")
func _result(err: int, events: Array, view: Dictionary) -> void:
	_forget_if_over(view)
	result_received.emit(err, events, view)


@rpc("authority", "call_remote", "reliable")
func _left(gone: String) -> void:
	player_left.emit(gone)


# --- чат ---------------------------------------------------------------------

func send_chat(text: String) -> void:
	if is_host:
		_room_chat(1, text)
	else:
		_chat_up.rpc_id(1, text)


@rpc("any_peer", "call_remote", "reliable")
func _chat_up(text: String) -> void:
	if is_host:
		_room_chat(multiplayer.get_remote_sender_id(), text)


func _room_chat(sender: int, text: String) -> void:
	var room := _room_of(sender)
	if room == null or not _may_speak(sender):
		return
	var who := String(room.seats[sender])
	var clean := text.strip_edges().left(300)
	for peer: int in room.seats:
		_send(peer, "_chat_down", [who, clean])


@rpc("authority", "call_remote", "reliable")
func _chat_down(who: String, text: String) -> void:
	chat_received.emit(who, text)


## Пинг уходит всем за столом, кроме автора: у себя он рисуется сразу.
func send_ping(zone: String, pos: Vector2) -> void:
	if is_host:
		_room_ping(1, zone, pos)
	else:
		_ping_up.rpc_id(1, zone, pos)


@rpc("any_peer", "call_remote", "reliable")
func _ping_up(zone: String, pos: Vector2) -> void:
	if is_host:
		_room_ping(multiplayer.get_remote_sender_id(), zone, pos)


func _room_ping(sender: int, zone: String, pos: Vector2) -> void:
	var room := _room_of(sender)
	if room == null or not room.seats.has(sender) or not zone in PING_ZONES:
		return
	if not pos.is_finite() or absf(pos.x) > 10000.0 or absf(pos.y) > 10000.0:
		return
	if not _may_speak(sender):
		return
	var who := String(room.seats[sender])
	for peer: int in room.seats:
		if peer != sender:
			_send(peer, "_ping_down", [who, zone, pos])


@rpc("authority", "call_remote", "reliable")
func _ping_down(who: String, zone: String, pos: Vector2) -> void:
	ping_received.emit(who, zone, pos)


func _may_speak(sender: int) -> bool:
	if not _said.has(sender):
		_said[sender] = []
	return rate_ok(_said[sender], Time.get_ticks_msec(), SERVER_RATE_WINDOW_MS)


## Можно ли ещё раз пингнуть/сказать: в times — моменты прошлых раз (мс),
## старше окна выкидываются. Да — момент now записывается.
static func rate_ok(times: Array, now: int, window: int = RATE_WINDOW_MS) -> bool:
	while not times.is_empty() and now - int(times[0]) >= window:
		times.pop_front()
	if times.size() >= RATE_COUNT:
		return false
	times.append(now)
	return true


func _log(text: String) -> void:
	if dedicated:
		print("[%s] %s" % [Time.get_datetime_string_from_system(), text])
