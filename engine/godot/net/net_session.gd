class_name NetSession
extends Node

## Сетевая игра по ENet (этап 6). Три роли одного и того же узла:
##
##   - хост по IP (host): держит одну комнату и сам в ней играет;
##   - выделенный сервер (serve с dedicated=true, запуск `-- --server`):
##     держит много комнат с кодами, сам не играет;
##   - клиент (join / create_room / enter_room): только шлёт намерения.
##
## Партию держит только тот, у кого комнаты (GameRoom -> GameServer). Клиент
## шлёт Intent словарём и получает свой срез (StateView) — чужую руку он не
## получает вовсе.
##
## Узел должен лежать по одному и тому же пути у всех (RPC адресуются путём
## узла) — /root/Net. Скрипт тоже должен совпадать: сервер со старой версией
## игры отвечает «обновите игру» (PROTOCOL).

signal lobby_changed(joined: Array, needed: int, code: String, owner_seat: String)
signal game_started(seat: String, board: Dictionary, view: Dictionary)
signal result_received(err: int, events: Array, view: Dictionary)
signal chat_received(seat: String, text: String)
signal player_left(seat: String)
## Связь не установилась, оборвалась или сервер отказал (нет комнаты и т.п.).
signal connection_lost(reason: String)
## Хост: чем кончилась попытка открыть порт на роутере (UPnP). address — внешний
## адрес для друзей, "" если не вышло; note — пояснение для лобби.
signal upnp_finished(address: String, note: String)

## Игра по IP (локальная сеть, Radmin VPN).
const DEFAULT_PORT := 7777
## Выделенный сервер с комнатами.
const SERVER_PORT := 7780
## Адрес сервера по умолчанию — наш VPS (Ubuntu, systemd-служба tyrants,
## см. server/README.md). Для проверки на одном компьютере — 127.0.0.1.
const DEFAULT_SERVER := "129.101.123.70"
## Меняется при любой несовместимой правке сети или правил: сервер и игроки
## должны играть одной версией.
const PROTOCOL := 1
const MAX_ROOMS := 64
const MAX_SERVER_PEERS := 128
## Без похожих друг на друга знаков (0/O, 1/I).
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 4

## У этой программы есть комнаты (хост по IP или сервер).
var is_host := false
var dedicated := false
## Свой цвет за столом ("" — пока не рассадили) и код своей комнаты.
var seat := ""
var room_code := ""
var started := false

var rooms: Dictionary = {}      # code -> GameRoom
var peer_room: Dictionary = {}  # peer id -> code
var _lan_code := ""
## Что отправить серверу, как только связь установится (вход или создание).
var _on_connected: Callable
var _rng := RandomNumberGenerator.new()


## Подписки на события связи — один раз: повторное подключение после ошибки
## не должно их удваивать.
func _ready() -> void:
	_rng.randomize()
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func():
		if _on_connected.is_valid():
			_on_connected.call())
	multiplayer.connection_failed.connect(func(): _lost("Could not connect"))
	multiplayer.server_disconnected.connect(func(): _lost("The connection to the game was lost"))


func _lost(reason: String) -> void:
	multiplayer.multiplayer_peer = null
	connection_lost.emit(reason)


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
	return OK


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
	return _connect(address, port, func(): _enter.rpc_id(1, PROTOCOL, ""))


## Клиент: на сервере завести новую комнату.
func create_room(address: String, port: int, player_count: int, mode: String) -> int:
	return _connect(address, port, func(): _create.rpc_id(1, PROTOCOL, player_count, mode))


## Клиент: на сервере войти в комнату по коду.
func enter_room(address: String, port: int, code: String) -> int:
	var clean := code.strip_edges().to_upper()
	return _connect(address, port, func(): _enter.rpc_id(1, PROTOCOL, clean))


func _connect(address: String, port: int, then: Callable) -> int:
	close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_on_connected = then
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
	seat = ""
	room_code = ""
	started = false


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
	if room.add(peer) == "":
		return
	peer_room[peer] = room.code
	_broadcast_lobby(room)


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


@rpc("any_peer", "call_remote", "reliable")
func _enter(version: int, code: String) -> void:
	if not is_host:
		return
	var peer := multiplayer.get_remote_sender_id()
	if not _check_newcomer(peer, version):
		return
	var key := _lan_code if not dedicated else code
	var room: GameRoom = rooms.get(key)
	if room == null:
		_refuse(peer, "There is no room %s" % code)
	elif room.started:
		_refuse(peer, "This game has already started")
	elif room.is_full():
		_refuse(peer, "This game is full")
	else:
		_seat_peer(room, peer)
		_log("room %s: %d of %d" % [room.code, room.seats.size(), room.needed])


func _check_newcomer(peer: int, version: int) -> bool:
	if version != PROTOCOL:
		_refuse(peer, "Different game version (yours %d, server %d): update the game" % [version, PROTOCOL])
		return false
	return not peer_room.has(peer)


func _refuse(peer: int, reason: String) -> void:
	_refused.rpc_id(peer, reason)


@rpc("authority", "call_remote", "reliable")
func _refused(reason: String) -> void:
	# Связь рвём не сразу: закрывать её прямо внутри приёма пакета нельзя.
	close.call_deferred()
	connection_lost.emit(reason)


func _on_peer_disconnected(id: int) -> void:
	var room := _room_of(id)
	peer_room.erase(id)
	if room == null:
		return
	var gone := String(room.seats.get(id, ""))
	room.remove(id)
	if room.seats.is_empty() or (not dedicated and id == 1):
		rooms.erase(room.code)
		_log("room %s closed" % room.code)
		return
	if room.started:
		# Место не освобождается: переподключение — следующий этап.
		for peer: int in room.seats:
			_send(peer, "_left", [gone])
	else:
		_broadcast_lobby(room)


func _broadcast_lobby(room: GameRoom) -> void:
	for peer: int in room.seats:
		_send(peer, "_lobby", [room.seats[peer], room.joined(), room.needed, room.code, room.owner_seat()])


@rpc("authority", "call_remote", "reliable")
func _lobby(your_seat: String, joined: Array, needed: int, code: String, owner_seat: String) -> void:
	seat = your_seat
	room_code = code
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
	for peer: int in room.seats:
		_send(peer, "_start", [board, views[room.seats[peer]]])
	_log("room %s started" % room.code)


@rpc("authority", "call_remote", "reliable")
func _start(board: Dictionary, view: Dictionary) -> void:
	started = true
	game_started.emit(seat, board, view)


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
	var result: Dictionary = room.apply(sender, d)
	var err := int(result["error"])
	var views: Dictionary = result["views"]
	for peer: int in room.seats:
		# Отказ касается только того, кто ошибся: остальным слать нечего.
		if err != GameServer.Error.OK and peer != sender:
			continue
		var own_err := err if peer == sender else GameServer.Error.OK
		_send(peer, "_result", [own_err, result["events"], views[room.seats[peer]]])


@rpc("authority", "call_remote", "reliable")
func _result(err: int, events: Array, view: Dictionary) -> void:
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
	if room == null:
		return
	var who := String(room.seats[sender])
	var clean := text.strip_edges().left(300)
	for peer: int in room.seats:
		_send(peer, "_chat_down", [who, clean])


@rpc("authority", "call_remote", "reliable")
func _chat_down(who: String, text: String) -> void:
	chat_received.emit(who, text)


func _log(text: String) -> void:
	if dedicated:
		print("[%s] %s" % [Time.get_datetime_string_from_system(), text])
