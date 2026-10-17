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
## Сервер начал раздачу и строит доску (этап Stock-2): лобби — экран DEALING THE CARDS.
signal dealing_started
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
## Главное меню: пришла таблица лидеров (RatingBook.leaderboard + online, in_game).
signal leaderboard_received(data: Dictionary)
## Друзья (FriendBook): снимок списка {friends, incoming, outgoing, note}.
signal friends_received(data: Dictionary)
## Переписка с другом: [{mine, text, time}].
signal thread_received(friend_name: String, messages: Array)
## Друг зовёт в своё лобби (код комнаты).
signal invite_received(from_name: String, code: String)
## Смотрим партию друга: экран партии от его лица (friend_seat), без руки.
signal watch_started(friend_seat: String, board: Dictionary, view: Dictionary)
## Чужой профиль (player_data): {name, emblem, favourite, rating?, games?,
## wins?, totals, history} или {name, missing}.
signal player_received(data: Dictionary)
## Запись партии с сервера (header пустой — не отдали).
signal record_received(file: String, header: Dictionary, intents: Array)

## Игра по IP (локальная сеть, Radmin VPN).
const DEFAULT_PORT := 7777
## Выделенный сервер с комнатами.
const SERVER_PORT := 7780
## Адрес сервера по умолчанию — наш VPS (Ubuntu, systemd-служба tyrants,
## см. server/README.md). Для проверки на одном компьютере — 127.0.0.1.
const DEFAULT_SERVER := "129.101.123.70"
## Меняется при любой несовместимой правке сети или правил: сервер и игроки
## должны играть одной версией.
const PROTOCOL := 35
## Режим партий, собранных поиском игры: зависит от размера стола
## (2 — STANDARD, 3 — RANDOM 3, 4 — RANDOM 4).
static func match_mode(player_count: int) -> String:
	match player_count:
		2:
			return GameSetup.MODE_STANDARD
		3:
			return GameSetup.MODE_RANDOM_3
	return GameSetup.MODE_RANDOM_4


## Очередь поиска 2 на 2 (этап Team-5) отдельно от обычной на четверых: ключ
## очереди = размер стола + TEAM_QUEUE (размер — остаток от деления).
const TEAM_QUEUE := 10


static func queue_key(player_count: int, teams: bool) -> int:
	var size := clampi(player_count, GameRoom.MIN_PLAYERS, GameRoom.MAX_PLAYERS)
	return size + (TEAM_QUEUE if teams else 0)


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

## Защита выделенного сервера (этап Sec-2).
## Отказанного (_refuse) клиент обычно отключает сам; изменённый — нет: через
## REFUSE_GRACE_MS сервер рвёт связь сам.
const REFUSE_GRACE_MS := 1000
## Подбор кода комнаты: ENTER_FAILS неверных кодов с одного IP за
## ENTER_WINDOW_MS — дальше вход по коду с этого IP закрыт, пока окно не сдвинется.
const ENTER_FAILS := 5
const ENTER_WINDOW_MS := 5 * 60 * 1000
const TOO_MANY_CODES := "Too many wrong room codes. Wait a few minutes and try again"
## Друзья: заявка, ответ, удаление, приглашение, просмотр — не больше
## FRIEND_RATE_COUNT за FRIEND_RATE_WINDOW_MS на учётную запись.
const FRIEND_RATE_COUNT := 5
const FRIEND_RATE_WINDOW_MS := 10000
## Новые учётные записи (первое занятое имя) — не больше NEW_ACCOUNTS_PER_IP с
## одного IP за сутки. Счёт в памяти: перезапуск сервера его обнуляет.
const NEW_ACCOUNTS_PER_IP := 5
const NEW_ACCOUNT_WINDOW_MS := 24 * 60 * 60 * 1000
const TOO_MANY_ACCOUNTS := "Too many new players from your network today. Try again tomorrow"
## Записи партий на сервере (records_dir): не больше RECORDS_MAX файлов и не
## старше RECORDS_DAYS дней — лишние стираются при каждой новой записи.
const RECORDS_MAX := 5000
const RECORDS_DAYS := 90
## Как часто выметать из памяти старые счётчики (IP и учётные записи).
const SWEEP_MS := 60000

## У этой программы есть комнаты (хост по IP или сервер).
var is_host := false
var dedicated := false
## Свой цвет за столом ("" — пока не рассадили) и код своей комнаты.
var seat := ""
var room_code := ""
## Комната 2 на 2 (этап Team-3): красные (1+3) против синих (2+4).
var room_teams := false
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
## Выделенный сервер: запись каждой законченной партии (реплей с полным
## итогом) — для статистики баланса и обучения ботов на партиях людей.
var records_dir := "user://game_records/"
## Клиент: файл реплея последней партии. Сервер шлёт реплей раньше итога
## рейтинга (_rating), и строка истории запоминает этот файл.
var last_replay := ""
## Клиент: последний снимок друзей с сервера (friends_data) — по нему карточка
## игрока знает, друг ли он уже (владелец, 2026-10-15).
var friends_cache: Dictionary = {}
var rooms: Dictionary = {}      # code -> GameRoom
## Выделенный сервер: запас готовых чертежей доски (ставит launcher; в тестах
## по желанию). close() его дожидается и убирает.
var board_stock: BoardStock = null
var peer_room: Dictionary = {}  # peer id -> code
## Поиск игры: число игроков -> очередь peer id (по порядку прихода) и кто
## стоит в очереди: peer id -> {needed, name, emblem, key}.
var queues: Dictionary = {}
var queued: Dictionary = {}
## Когда игрок последний раз пинговал или писал: peer id -> [мс, ...] (rate_ok).
var _said: Dictionary = {}
## Этап Sec-2. Отказанные подключения: peer id -> когда рвать связь (мс; -1 —
## уже рвём). Их запросы сервер больше не слушает.
var _dropping: Dictionary = {}
## IP -> [мс неверных кодов комнаты]; IP -> [мс новых учётных записей];
## учётная запись -> [мс действий с друзьями].
var _bad_codes: Dictionary = {}
var _new_accounts: Dictionary = {}
var _acted: Dictionary = {}
## Сколько новых учётных записей с одного IP за сутки (тест ставит меньше).
var accounts_per_ip := NEW_ACCOUNTS_PER_IP
var _next_sweep := 0
## Тест: «изменённый клиент» — по отказу связь сам не закрывает.
var ignore_refusal := false
## Выделенный сервер: чья учётная запись за каким подключением (друзья: кто
## в сети, кому доставить заявку, сообщение, приглашение).
var peer_account: Dictionary = {}
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
		_tick_watch(delta)
		return
	if board_stock != null and dedicated:
		board_stock.tick()
	if not _dropping.is_empty():
		_drop_refused()
	if Time.get_ticks_msec() >= _next_sweep:
		_sweep()
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
func host(port: int, player_count: int, mode: String, teams: bool = false) -> int:
	var err := serve(port)
	if err != OK:
		return err
	var room := _new_room(player_count, mode, teams)
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
func create_room(address: String, port: int, player_count: int, mode: String, teams: bool = false) -> int:
	_remember_server(address, port)
	return _connect(address, port, func(): _create.rpc_id(1, PROTOCOL, player_count, mode, teams))


## Клиент: встать в очередь поиска игры на player_count человек. Профиль идёт
## прямо с просьбой: комнаты ещё нет, и _profile_up её бы не нашёл.
## ban — полуколода, которую игрок не хочет видеть в рынке ("" — без бана).
func find_match(address: String, port: int, player_count: int, teams: bool = false, ban: String = "") -> int:
	_remember_server(address, port)
	return _connect(address, port, func():
		var p := PlayerProfile.clean(profile)
		_queue.rpc_id(1, PROTOCOL, player_count, p["name"], p["emblem"], p["back"], _client_key(), p["shader"], p["arts"], p["favourite"],
			p["colour"], teams, ban))


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
	if board_stock != null:
		board_stock.close()
		board_stock = null
	# Фоновые снимки доски (_start_room) дожидаемся: бросить поток нельзя.
	for room: GameRoom in rooms.values():
		if room.board_task >= 0:
			WorkerThreadPool.wait_for_task_completion(room.board_task)
			room.board_task = -1
	rooms.clear()
	peer_room.clear()
	queues.clear()
	queued.clear()
	_dropping.clear()
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

func _new_room(player_count: int, mode: String, teams: bool = false) -> GameRoom:
	var code := ""
	while code == "" or rooms.has(code):
		code = ""
		for i in CODE_LENGTH:
			code += CODE_CHARS[_rng.randi_range(0, CODE_CHARS.length() - 1)]
	var room := GameRoom.new(code, player_count, mode, teams)
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
	if _dropping.has(peer):
		return
	_note_presence(peer, player_name, emblem, key, favourite)
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
	var why := _claim(peer, RatingBook.account_of(key), clean_name)
	if why == "":
		return true
	_refuse(peer, NAME_TAKEN % clean_name if why == "taken" else TOO_MANY_ACCOUNTS)
	return false


## Занять имя (RatingBook.claim_name), но новых учётных записей с одного IP —
## не больше accounts_per_ip за сутки (этап Sec-2: иначе любой случайный ключ
## бесплатно занимает ник). "" — занято (или занимать нечего), "taken" — имя
## чужое, "limit" — новых записей с этого IP на сегодня хватит.
func _claim(peer: int, account: String, clean_name: String) -> String:
	if account == "" or RatingBook.name_id(clean_name) == "":
		return ""
	var owner := String(ratings.names.get(RatingBook.name_id(clean_name), ""))
	if owner != "" and owner != account:
		return "taken"
	var fresh := not ratings.knows(account)
	var ip := _ip_of(peer)
	var now := Time.get_ticks_msec()
	var times: Array = _new_accounts.get(ip, [])
	if fresh and recent(times, now, NEW_ACCOUNT_WINDOW_MS) >= accounts_per_ip:
		return "limit"
	if not ratings.claim_name(account, clean_name):
		return "taken"
	if fresh:
		times.append(now)
		_new_accounts[ip] = times
	return ""


## IP подключения ("" — не ENet или подключения уже нет).
func _ip_of(peer: int) -> String:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet == null or not multiplayer.get_peers().has(peer):
		return ""
	var packet_peer := enet.get_peer(peer)
	return packet_peer.get_remote_address() if packet_peer != null else ""


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
func _create(version: int, player_count: int, mode: String, teams: bool) -> void:
	# Заводить комнаты по сети можно только на выделенном сервере.
	if not dedicated:
		return
	var peer := multiplayer.get_remote_sender_id()
	if not _check_newcomer(peer, version):
		return
	if rooms.size() >= MAX_ROOMS:
		_refuse(peer, "The server is full, try again later")
		return
	var room := _new_room(player_count, mode, teams)
	_seat_peer(room, peer)
	_log("room %s created: %d players, %s%s" % [room.code, room.needed, room.mode, " 2v2" if room.teams else ""])


## Поиск игры: встать в очередь на player_count человек (только выделенный сервер).
@rpc("any_peer", "call_remote", "reliable")
func _queue(version: int, player_count: int, player_name: String, emblem: String, back: String,
		key: String, shader: String, arts: String, favourite: String, colour: String, teams: bool, ban: String) -> void:
	if not dedicated:
		return
	var peer := multiplayer.get_remote_sender_id()
	if not _check_newcomer(peer, version):
		return
	if not _name_free(peer, player_name, key):
		return
	# Очередь: ключ — размер стола, у 2 на 2 своя (queue_key).
	var needed := queue_key(GameRoom.MAX_PLAYERS if teams else player_count, teams)
	var line: Array = queues.get(needed, [])
	line.append(peer)
	queues[needed] = line
	queued[peer] = {"needed": needed, "name": player_name, "emblem": emblem, "back": back, "key": key, "shader": shader, "arts": arts,
		"favourite": favourite,
		"colour": PlayerProfile.clean_colour(colour),
		"ban": ban if GameSetup.available_half_decks().has(ban) else ""}
	_log("queue %d: %d waiting" % [needed, line.size()])
	# Сервер забит комнатами — стоят дальше; следующий пришедший проверит снова.
	if line.size() >= needed % TEAM_QUEUE and rooms.size() < MAX_ROOMS:
		_match(needed)
	_broadcast_queue(needed)


## Первые needed из очереди садятся за новый стол, и партия сразу раздаётся.
func _match(needed: int) -> void:
	var teams := needed >= TEAM_QUEUE
	var size := needed % TEAM_QUEUE
	var line: Array = queues[needed]
	var room := _new_room(size, match_mode(size), teams)
	room.matched = true
	# Сначала рассадка по любимым цветам (кто раньше встал в очередь, тому и
	# цвет), профили — когда места уже окончательные.
	var batch: Array = line.slice(0, size)
	for peer: int in batch:
		room.add(peer, String(queued[peer].get("colour", "")))
		peer_room[peer] = room.code
	for peer: int in batch:
		var q: Dictionary = queued[peer]
		queued.erase(peer)
		var ban := String(q.get("ban", ""))
		if ban != "" and not room.banned.has(ban):
			room.banned.append(ban)
		_set_profile(room, String(room.seats[peer]), String(q["name"]), String(q["emblem"]), String(q["back"]),
			String(q["key"]), String(q.get("shader", "")), String(q.get("arts", "")), String(q.get("favourite", "")))
	queues[needed] = line.slice(size)
	_log("room %s matched: %d players, %s, bans %s" % [room.code, room.needed, room.mode, room.banned])
	_broadcast_lobby(room)
	_start_room(room, _rng.randi())


func _broadcast_queue(needed: int) -> void:
	var line: Array = queues.get(needed, [])
	for peer: int in line:
		_send(peer, "_queue_status", [line.size(), needed % TEAM_QUEUE])


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
	# Подбор кода (этап Sec-2): после ENTER_FAILS неверных кодов с этого IP
	# вход по коду закрыт на время — даже с верным кодом.
	var ip := _ip_of(peer) if dedicated else ""
	var fails: Array = _bad_codes.get(ip, [])
	var now := Time.get_ticks_msec()
	if dedicated and recent(fails, now, ENTER_WINDOW_MS) >= ENTER_FAILS:
		_refuse(peer, TOO_MANY_CODES)
		return
	var room_key := _lan_code if not dedicated else code
	var room: GameRoom = rooms.get(room_key)
	if room == null:
		if dedicated:
			fails.append(now)
			_bad_codes[ip] = fails
			if fails.size() >= ENTER_FAILS:
				_log("wrong room codes from %s: entry closed for a while" % ip)
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
	if _dropping.has(peer):
		return false
	if version != PROTOCOL:
		_refuse(peer, "Different game version (yours %d, server %d): update the game" % [version, PROTOCOL])
		return false
	return not peer_room.has(peer) and not queued.has(peer)


## Отказ. Честный клиент по нему закрывает связь сам (_refused), а изменённый
## мог бы остаться: через REFUSE_GRACE_MS сервер рвёт связь сам (из _process —
## не внутри приёма пакета), а до тех пор не слушает его запросов.
func _refuse(peer: int, reason: String) -> void:
	_refused.rpc_id(peer, reason)
	if peer != multiplayer.get_unique_id() and not _dropping.has(peer):
		_dropping[peer] = Time.get_ticks_msec() + REFUSE_GRACE_MS


func _drop_refused() -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var alive := multiplayer.get_peers()
	var now := Time.get_ticks_msec()
	for peer: int in _dropping.keys():
		if not alive.has(peer):
			_dropping.erase(peer)
		elif int(_dropping[peer]) >= 0 and now >= int(_dropping[peer]) and enet != null:
			# Уходит штатно (peer_disconnected), а не молчком: место, очередь и
			# прочее подчистит _on_peer_disconnected.
			_dropping[peer] = -1
			enet.disconnect_peer(peer)
			_log("refused peer %d did not leave: disconnected" % peer)


## Выкинуть из памяти счётчики, у которых все отметки старше своего окна.
func _sweep() -> void:
	var now := Time.get_ticks_msec()
	_next_sweep = now + SWEEP_MS
	for pair: Array in [[_bad_codes, ENTER_WINDOW_MS], [_new_accounts, NEW_ACCOUNT_WINDOW_MS],
			[_acted, FRIEND_RATE_WINDOW_MS], [_said, SERVER_RATE_WINDOW_MS]]:
		var store: Dictionary = pair[0]
		for k in store.keys():
			if recent(store[k], now, int(pair[1])) == 0:
				store.erase(k)


@rpc("authority", "call_remote", "reliable")
func _refused(reason: String) -> void:
	if ignore_refusal:
		connection_lost.emit(reason)
		return
	# Запомненной партии на сервере больше нет (или место в ней не наше).
	if _resuming:
		_resuming = false
		forget_game()
	# Связь рвём не сразу: закрывать её прямо внутри приёма пакета нельзя.
	close.call_deferred()
	connection_lost.emit(reason)


func _on_peer_disconnected(id: int) -> void:
	_said.erase(id)
	_dropping.erase(id)
	peer_account.erase(id)
	for room: GameRoom in rooms.values():
		room.watchers.erase(id)
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
			room.teams,
			room.profiles])


@rpc("authority", "call_remote", "reliable")
func _lobby(your_seat: String, joined: Array, needed: int, code: String, owner_seat: String, teams: bool,
		seat_profiles: Dictionary) -> void:
	seat = your_seat
	room_code = code
	room_teams = teams
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


## Лобби 2 на 2: пересесть в команду team ("red" / "blue"), если там есть
## свободное место. У хоста по IP — сразу, у клиента — просьба серверу.
func choose_team(team: String) -> void:
	if is_host and not dedicated:
		_room_team(1, team)
	elif not is_host:
		_team_up.rpc_id(1, team)


@rpc("any_peer", "call_remote", "reliable")
func _team_up(team: String) -> void:
	_room_team(multiplayer.get_remote_sender_id(), team)


func _room_team(peer: int, team: String) -> void:
	var room := _room_of(peer)
	if room == null or room.started or not room.teams:
		return
	room.choose_team(peer, team)
	_broadcast_lobby(room)


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
	# Есть готовый чертёж в запасе (BoardStock) — партия берёт его сид и
	# стартует сразу.
	var stocked: Dictionary = board_stock.take(room.needed) if board_stock != null else {}
	if not stocked.is_empty():
		game_seed = int(stocked["seed"])
	var views := room.deal(game_seed)
	var state := room.server.state
	if not stocked.is_empty() and BoardStock.same_layout(stocked, state):
		_log("room %s dealing (board from stock)" % room.code)
		_deliver(room, StateView.board_snapshot(state, stocked["schematic"]), views)
		return
	# Запаса нет — доска строится без лимита времени (владелец, 2026-10-12:
	# всегда в сетке), а игроки пока видят DEALING THE CARDS.
	for peer: int in room.seats:
		_send(peer, "_dealing", [])
	BoardSchematic.warm_up(state)
	room.board_task = WorkerThreadPool.add_task(func():
		_board_ready.call_deferred(room, StateView.board_snapshot(state, {}, BoardSchematic.NO_BUDGET), views))
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
	room.watch_view = _public_view(room)
	room.watch_player = room.server.state.current_player()
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
		"teams": room.teams,
		"seed": room.game_seed,
		"profiles": room.profiles,
		"accounts": room.accounts,
		"keys": room.keys,
		"matched": room.matched,
		"banned": room.banned,
		"mulligan": room.server.with_mulligan,
	}, room.log, saves_dir)


## Сервер раздаёт и строит доску (без лимита времени, может занять секунды) —
## лобби показывает экран DEALING THE CARDS до _start.
@rpc("authority", "call_remote", "reliable")
func _dealing() -> void:
	dealing_started.emit()


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
	_feed_watchers(room, result["events"])
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
	_feed_watchers(room, result["events"])
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
	header["banned"] = room.banned
	if dedicated:
		var file := ReplayBook.save(header, room.log, records_dir)
		room.record_file = file
		_log("room %s: game record %s" % [room.code, file if file != "" else "NOT SAVED"])
		var pruned := ReplayBook.prune(records_dir, RECORDS_MAX, RECORDS_DAYS, int(Time.get_unix_time_from_system()))
		if pruned > 0:
			_log("old game records removed: %d" % pruned)
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
	# Зрителю тоже: иначе при отключившемся игроке он видит застывшую доску
	# без объяснений.
	for peer: int in room.watchers:
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
	# Рейтинг меняют только партии поиска игры; лобби — без рейтинга.
	# 2 на 2 (этап Team-5): свой рейтинг 2v2, Эло команда на команду.
	var team_of: Dictionary = state.teams.duplicate()
	var result := ratings.record(players, scores, winners, room.matched, team_of)
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
		_check_records(room, players, scores, winners, result)
	# Строка истории каждого — и в его профиль на сервере (чужие профили).
	for pid: String in result:
		var entry := PlayerProfile.history_entry(pid, result, room.profiles)
		entry["replay"] = room.record_file
		entry["protocol"] = PROTOCOL
		entry["mode"] = room.mode
		entry["teams"] = room.teams
		ratings.profiles.add(String(players[pid]["account"]), entry)
	ratings.profiles.save()
	_log("room %s: rated %s" % [room.code, JSON.stringify(result)])
	for peer: int in room.seats:
		_send(peer, "_rating", [result])


## Мировые рекорды (RecordBook): победитель рейтинговой партии сверяется с
## таблицей своего размера стола; побитые попадают в итог — result[seat]["records"].
func _check_records(room: GameRoom, players: Dictionary, scores: Dictionary, winners: Array,
		result: Dictionary) -> void:
	var header := ReplayBook.header_for(room.server.state, room.ids, room.game_seed, room.mode,
		room.server.with_mulligan, room.profiles, "", room.code, room.log)
	header["banned"] = room.banned
	var stats := ReplayStats.collect({"header": header, "intents": room.log})
	for pid: String in winners:
		# 2 на 2: перевес — над командой соперников (у союзника тот же счёт).
		var rivals := scores.duplicate()
		for other in scores:
			if other != pid and room.server.state.is_ally(pid, other):
				rivals.erase(other)
		var values := RecordBook.measure(stats, pid, rivals)
		var table := RatingBook.TEAM if room.teams else str(players.size())
		var broken := ratings.records.submit(table, String(players[pid]["account"]),
			String(players[pid]["name"]), values)
		if not broken.is_empty():
			result[pid]["records"] = broken
			_log("room %s: world records %s by %s" % [room.code, broken, players[pid]["name"]])


@rpc("authority", "call_remote", "reliable")
func _rating(result: Dictionary) -> void:
	if result.has(seat):
		# Рейтинг 2v2 — отдельный: обычный в профиле он не трогает.
		if String(result[seat].get("kind", "")) == "":
			PlayerProfile.cache_stats(result[seat])
		var entry := PlayerProfile.history_entry(seat, result, profiles)
		entry["replay"] = last_replay
		if last_replay != "":
			entry["protocol"] = PROTOCOL
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
## count — сколько раз можно за окно (по умолчанию — пинги и чат).
static func rate_ok(times: Array, now: int, window: int = RATE_WINDOW_MS, count: int = RATE_COUNT) -> bool:
	if recent(times, now, window) >= count:
		return false
	times.append(now)
	return true


## Сколько отметок в times моложе окна; старшие выкидываются.
static func recent(times: Array, now: int, window: int) -> int:
	while not times.is_empty() and now - int(times[0]) >= window:
		times.pop_front()
	return times.size()


# --- главное меню: онлайн и таблица лидеров ---------------------------------

## Сколько строк в таблице лидеров.
const LEADERBOARD_SIZE := 100


## Клиент в главном меню держит лёгкую связь с сервером (владелец, 2026-10-11):
## сервер считает его онлайн, по ней же приходит таблица лидеров. Ни в комнату,
## ни в очередь он не встаёт; профиль после входа сервер без комнаты пропускает.
func watch(address: String, port: int) -> int:
	return _connect(address, port, request_leaderboard)


func is_connected_to_server() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not is_host \
		and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func request_leaderboard() -> void:
	if is_connected_to_server():
		_leaderboard_up.rpc_id(1, PROTOCOL, _client_key())


@rpc("any_peer", "call_remote", "reliable")
func _leaderboard_up(version: int, key: String) -> void:
	if not dedicated:
		return
	var peer := multiplayer.get_remote_sender_id()
	if not _check_newcomer(peer, version):
		return
	_send(peer, "_leaderboard_down", [leaderboard(RatingBook.account_of(key))])


## Сервер: таблица лидеров, сколько всего на связи (меню, поиск, лобби, партии)
## и сколько сидят в идущих партиях.
func leaderboard(account: String = "") -> Dictionary:
	var data := ratings.leaderboard(LEADERBOARD_SIZE, account)
	var in_game := 0
	for room: GameRoom in rooms.values():
		if room.started and room.server != null and not room.server.state.game_over:
			in_game += room.seats.size()
	data["online"] = multiplayer.get_peers().size()
	data["in_game"] = in_game
	return data


@rpc("authority", "call_remote", "reliable")
func _leaderboard_down(data: Dictionary) -> void:
	leaderboard_received.emit(data)


# --- чужие профили (ProfileBook, владелец 2026-10-15) -----------------------

## Клиент: профиль игрока по нику. Ответ — player_received.
func request_player(player_name: String) -> void:
	if is_connected_to_server():
		_player_up.rpc_id(1, PROTOCOL, player_name)


@rpc("any_peer", "call_remote", "reliable")
func _player_up(version: int, player_name: String) -> void:
	if not dedicated or ratings == null or version != PROTOCOL:
		return
	_send(multiplayer.get_remote_sender_id(), "_player_down", [player_data(player_name)])


## Сервер: всё, что показывает чужой профиль: карточка (имя, герб, любимая
## карта, рейтинг), суммы для многоугольника и последние партии.
func player_data(player_name: String) -> Dictionary:
	var account := String(ratings.names.get(RatingBook.name_id(player_name), ""))
	if account == "":
		return {"name": PlayerProfile.clean_name(player_name), "missing": true}
	var person: Dictionary = ratings.friends.people.get(account, {})
	var data := {"name": String(person.get("name", player_name)), "emblem": String(person.get("emblem", "")),
		"favourite": String(person.get("favourite", "")),
		"totals": ratings.profiles.totals_of(account), "history": ratings.profiles.history_of(account)}
	if ratings.accounts.has(account):
		data.merge(ratings.stats_of(account))
	return data


@rpc("authority", "call_remote", "reliable")
func _player_down(data: Dictionary) -> void:
	player_received.emit(data)


## Клиент: запись партии с сервера (из чужой истории). Ответ — record_received.
func request_record(file: String) -> void:
	if is_connected_to_server():
		_record_up.rpc_id(1, PROTOCOL, file)


@rpc("any_peer", "call_remote", "reliable")
func _record_up(version: int, file: String) -> void:
	if not dedicated or ratings == null or version != PROTOCOL:
		return
	var peer := multiplayer.get_remote_sender_id()
	# Только записи из чьей-то истории и не чаще, чем фразы чата.
	if not _may_speak(peer) or not ratings.profiles.knows_replay(file):
		_send(peer, "_record_down", [file, {}, []])
		return
	var replay := ReplayBook.load_replay(file, records_dir)
	_send(peer, "_record_down", [file, replay.get("header", {}), replay.get("intents", [])])


@rpc("authority", "call_remote", "reliable")
func _record_down(file: String, header: Dictionary, intents: Array) -> void:
	record_received.emit(file, header, intents)


# --- друзья (FriendBook, владелец 2026-10-11) -------------------------------

## Сервер: кто за этим подключением. Имя занимается и из меню (иначе игрока,
## который пока только сидел в меню, не найти по нику); занятое чужим — не
## записываем, отказ даст вход в комнату или очередь, как и раньше.
func _note_presence(peer: int, player_name: String, emblem: String, key: String, favourite: String) -> void:
	if ratings == null:
		return
	var account := RatingBook.account_of(key)
	if account == "":
		return
	peer_account[peer] = account
	var clean_name := PlayerProfile.clean_name(player_name)
	if _claim(peer, account, clean_name) == "":
		ratings.friends.note_person(account, clean_name, PlayerProfile.clean_emblem(emblem),
			PlayerProfile.clean_favourite(favourite))


## Клиент: действие с друзьями. action: "list"; "add" [ник]; "answer" [ник,
## принять?]; "remove" [ник]; "send" [ник, текст]; "thread" [ник];
## "invite" [ник] — позвать в своё лобби (связь — комнатная, комната не начата).
## Ответ — friends_received (и thread_received для "send"/"thread").
func friends_action(action: String, args: Array = []) -> void:
	if is_connected_to_server():
		_friends_up.rpc_id(1, PROTOCOL, _client_key(), action, args)


@rpc("any_peer", "call_remote", "reliable")
func _friends_up(version: int, key: String, action: String, args: Array) -> void:
	if not dedicated or ratings == null or version != PROTOCOL:
		return
	var peer := multiplayer.get_remote_sender_id()
	var me := RatingBook.account_of(key)
	if me == "" or _dropping.has(peer):
		return
	peer_account[peer] = me
	var book := ratings.friends
	var other_name := String(args[0]) if not args.is_empty() else ""
	var other := String(ratings.names.get(RatingBook.name_id(other_name), ""))
	var shown := book.name_of(other) if other != "" and book.name_of(other) != "" else other_name
	var note := ""
	if action != "list" and other == "":
		note = "No player named %s." % PlayerProfile.clean_name(other_name)
		action = "list"
	# Этап Sec-2: заявки и приглашения — только от игрока с именем на сервере
	# (новых имён с одного IP немного, _claim), и всё, что пишет в книгу друзей
	# или дёргает других, — не чаще FRIEND_RATE_COUNT за окно.
	if action in ["add", "invite"] and book.name_of(me) == "":
		note = "Your name is taken or not set. Change it in your profile first."
		action = "list"
	if action in ["add", "answer", "remove", "invite", "watch"]:
		if not _acted.has(me):
			_acted[me] = []
		if not rate_ok(_acted[me], Time.get_ticks_msec(), FRIEND_RATE_WINDOW_MS, FRIEND_RATE_COUNT):
			note = "Too many requests. Wait a moment."
			action = "list"
	match action:
		"add":
			match book.request(me, other):
				"sent":
					note = "Friend request sent to %s." % shown
				"friends":
					note = "%s is now your friend." % shown
				"already":
					note = "%s is already your friend or has your request." % shown
				"self":
					note = "That is you."
			_push_friends(other)
		"answer":
			if book.answer(me, other, args.size() > 1 and bool(args[1])):
				_push_friends(other)
		"remove":
			book.remove(me, other)
			_push_friends(other)
		"send":
			if not _may_speak(peer):
				note = "Too many messages. Wait a moment."
			elif book.send(me, other, String(args[1]) if args.size() > 1 else "", int(Time.get_unix_time_from_system())):
				_push_friends(other)
			_send(peer, "_thread_down", [shown, book.read_thread(me, other)])
		"thread":
			_send(peer, "_thread_down", [shown, book.read_thread(me, other)])
		"invite":
			note = _invite(peer, me, other, shown)
		"watch":
			note = _start_watching(peer, me, other, shown)
			if note == "":
				return
	_send(peer, "_friends_down", [friends_data(me, note)])


# --- зрители (владелец, 2026-10-11) -----------------------------------------

## Срез партии для зрителя: только открытое (ничьих рук, сбросов, колод).
func _public_view(room: GameRoom) -> Dictionary:
	return StateView.for_player_with_pending(room.server.state, "", room.server.resolver.pending)


## Смотреть партию друга. "" — пошла партия зрителю, иначе — почему нет.
func _start_watching(peer: int, me: String, other: String, shown: String) -> String:
	if not ratings.friends.are_friends(me, other):
		return "%s is not your friend." % shown
	if _room_of(peer) != null:
		return "Leave your lobby first."
	var status := status_of(other)
	var room: GameRoom = rooms.get(String(status[1]))
	if status[0] != "IN GAME" or room == null:
		return "%s is not in a game now." % shown
	var friend_seat := ""
	for pid: String in room.accounts:
		if room.accounts[pid] == other:
			friend_seat = pid
	if room.watch_view.is_empty():
		room.watch_view = _public_view(room)
		room.watch_player = room.server.state.current_player()
	room.watchers[peer] = true
	_send(peer, "_watch_start", [friend_seat, room.cached_board, room.watch_view, room.profiles])
	_send(peer, "_pause", [room.pause_status(abandon_seconds, pause_seconds)])
	_log("room %s: %s watches" % [room.code, ratings.friends.name_of(me)])
	return ""


## После каждого принятого хода: шаг — в копилку; ход сменился (или партия
## кончилась) — всё накопленное уходит зрителям, отсечка сдвигается.
func _feed_watchers(room: GameRoom, events: Array) -> void:
	var state := room.server.state
	room.watch_buffer.append([events, _public_view(room)])
	var now := state.current_player()
	if not state.game_over and now == room.watch_player:
		return
	for peer: int in room.watchers:
		_send(peer, "_watch_feed", [room.watch_buffer])
	room.watch_view = (room.watch_buffer.back() as Array)[1]
	room.watch_buffer = []
	room.watch_player = now


## Клиент-зритель: шаги, пришедшие пачкой за ход, — показываем по одному.
var _watch_queue: Array = []
var _watch_wait := 0.0
const WATCH_STEP := 0.9
const WATCH_STEP_FAST := 0.35


@rpc("authority", "call_remote", "reliable")
func _watch_start(friend_seat: String, board: Dictionary, view: Dictionary, seat_profiles: Dictionary) -> void:
	seat = ""
	started = true
	profiles = seat_profiles.duplicate(true)
	pause_status = {}
	_watch_queue.clear()
	watch_started.emit(friend_seat, board, view)


@rpc("authority", "call_remote", "reliable")
func _watch_feed(steps: Array) -> void:
	_watch_queue.append_array(steps)


## Клиент-зритель: следующий шаг из очереди. Отстали больше чем на десяток
## шагов — играем быстрее, чтобы не уползать от партии.
func _tick_watch(delta: float) -> void:
	if _watch_queue.is_empty():
		return
	_watch_wait -= delta
	if _watch_wait > 0.0:
		return
	_watch_wait = WATCH_STEP_FAST if _watch_queue.size() > 10 else WATCH_STEP
	var step: Array = _watch_queue.pop_front()
	result_received.emit(GameServer.Error.OK, step[0], step[1])


## Позвать друга в свою комнату (её лобби ещё не началось).
func _invite(peer: int, me: String, other: String, shown: String) -> String:
	var room := _room_of(peer)
	if room == null or room.started:
		return "Create a lobby first (PLAY > LOBBY), then invite."
	if not ratings.friends.are_friends(me, other):
		return "%s is not your friend." % shown
	var status := status_of(other)
	if status[0] == "OFFLINE":
		return "%s is offline." % shown
	if status[0] == "IN GAME":
		return "%s is in a game." % shown
	for p: int in _peers_of(other):
		_send(p, "_invite_down", [ratings.friends.name_of(me), room.code])
	return "Invitation sent to %s." % shown


func _peers_of(account: String) -> Array[int]:
	var out: Array[int] = []
	for p: int in peer_account:
		if peer_account[p] == account:
			out.append(p)
	return out


## Снимок друзей заново всем подключениям учётной записи (ей пришла заявка,
## сообщение, ответ).
func _push_friends(account: String) -> void:
	if account == "":
		return
	var peers := _peers_of(account)
	if peers.is_empty():
		return
	var data := friends_data(account, "")
	for p: int in peers:
		_send(p, "_friends_down", [data])


## Где игрок: ["IN GAME", код комнаты] / ["IN LOBBY", ""] / ["ONLINE", ""] /
## ["OFFLINE", ""].
func status_of(account: String) -> Array:
	for room: GameRoom in rooms.values():
		for peer: int in room.seats:
			if room.accounts.get(room.seats[peer], "") != account:
				continue
			if room.started and room.server != null and not room.server.state.game_over:
				return ["IN GAME", room.code]
			if not room.started:
				return ["IN LOBBY", ""]
	if peer_account.values().has(account):
		return ["ONLINE", ""]
	return ["OFFLINE", ""]


const STATUS_ORDER := ["IN GAME", "IN LOBBY", "ONLINE", "OFFLINE"]


## Сервер: друзья учётной записи для клиента — по имени, без учётных записей.
func friends_data(account: String, note: String) -> Dictionary:
	var book := ratings.friends
	var list := []
	for acc: String in book.friends_of(account):
		var status := status_of(acc)
		var person: Dictionary = book.people.get(acc, {})
		var row := ratings.stats_of(acc)
		row.merge({"name": String(person.get("name", "?")), "emblem": String(person.get("emblem", "")),
			"favourite": String(person.get("favourite", "")), "status": status[0], "room": status[1],
			"unread": book.unread_from(account, acc), "records": ratings.records.held_by(acc),
			"rated": ratings.accounts.has(acc)})
		list.append(row)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := STATUS_ORDER.find(a["status"])
		var sb := STATUS_ORDER.find(b["status"])
		return sa < sb if sa != sb else String(a["name"]).nocasecmp_to(String(b["name"])) < 0)
	var names_in := []
	for acc: String in book.incoming(account):
		names_in.append(book.name_of(acc))
	var names_out := []
	for acc: String in book.outgoing(account):
		names_out.append(book.name_of(acc))
	return {"friends": list, "incoming": names_in, "outgoing": names_out, "note": note}


@rpc("authority", "call_remote", "reliable")
func _friends_down(data: Dictionary) -> void:
	friends_cache = data
	friends_received.emit(data)


## Клиент: кем приходится игрок с ником player_name по последнему снимку:
## "friend", "outgoing" (наша заявка), "incoming" (его заявка) или "".
func friend_status(player_name: String) -> String:
	var id := RatingBook.name_id(player_name)
	for f: Dictionary in friends_cache.get("friends", []):
		if RatingBook.name_id(String(f.get("name", ""))) == id:
			return "friend"
	for key in ["outgoing", "incoming"]:
		for other in friends_cache.get(key, []):
			if RatingBook.name_id(String(other)) == id:
				return key
	return ""


@rpc("authority", "call_remote", "reliable")
func _thread_down(friend_name: String, messages: Array) -> void:
	thread_received.emit(friend_name, messages)


@rpc("authority", "call_remote", "reliable")
func _invite_down(from_name: String, code: String) -> void:
	invite_received.emit(from_name, code)


func _log(text: String) -> void:
	if dedicated:
		print("[%s] %s" % [Time.get_datetime_string_from_system(), text])
