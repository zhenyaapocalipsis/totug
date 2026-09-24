class_name NetSession
extends Node

## Сетевая партия по ENet (этап 6): один игрок хостит, остальные входят по IP.
##
## Хост — единственный, у кого есть GameState и GameServer. Клиенты шлют ему
## только Intent (словарём), он применяет его и рассылает каждому ЕГО срез
## (StateView) — чужую руку клиент не получает вовсе. Хост играет тем же путём,
## только без пересылки по сети.
##
## Узел должен лежать по одному и тому же пути у всех (RPC адресуются путём
## узла) — game_scene.gd кладёт его в /root/Net.

signal lobby_changed(joined: Array, needed: int)
signal game_started(seat: String, board: Dictionary, view: Dictionary)
signal result_received(err: int, events: Array, view: Dictionary)
signal chat_received(seat: String, text: String)
signal player_left(seat: String)
## Связь не установилась или оборвалась (для клиента — хост пропал).
signal connection_lost(reason: String)

const DEFAULT_PORT := 7777

var is_host := false
## Свой цвет за столом ("" — пока хост не рассадил).
var seat := ""
var started := false
## Только у хоста: кто за каким цветом (peer id -> player id) и сама партия.
var seats: Dictionary = {}
var server: GameServer
var _needed := 2
var _mode := GameSetup.MODE_STANDARD


## Открыть игру на порту. Хост сразу садится за первый цвет.
func host(port: int, player_count: int, mode: String) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, GameScreen.MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	_needed = clampi(player_count, GameScreen.MIN_PLAYERS, GameScreen.MAX_PLAYERS)
	_mode = mode
	seats = {1: GameScreen.ALL_PLAYER_IDS[0]}
	seat = seats[1]
	_broadcast_lobby.call_deferred()
	return OK


func join(address: String, port: int) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	return OK


## Подписки на события связи — один раз: повторный CONNECT после ошибки не
## должен их удваивать.
func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(func(): _lost("Could not connect to the host"))
	multiplayer.server_disconnected.connect(func(): _lost("The host has left the game"))


func _lost(reason: String) -> void:
	multiplayer.multiplayer_peer = null
	connection_lost.emit(reason)


func close() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null


func is_full() -> bool:
	return seats.size() >= _needed


# --- лобби (хост) ------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	# У клиента это событие приходит и про других клиентов — рассаживает хост.
	if not is_host:
		return
	if started or is_full():
		# Мест нет — вежливо отказываем: клиент увидит обрыв связи.
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	for pid: String in GameScreen.ALL_PLAYER_IDS:
		if not seats.values().has(pid):
			seats[id] = pid
			break
	_broadcast_lobby()


func _on_peer_disconnected(id: int) -> void:
	if not is_host or not seats.has(id):
		return
	var gone := String(seats[id])
	if started:
		# Место оставляем за ним: переподключение — следующий этап.
		_left.rpc(gone)
		player_left.emit(gone)
		return
	seats.erase(id)
	_broadcast_lobby()


func _joined() -> Array:
	var ids: Array = []
	for pid: String in GameScreen.ALL_PLAYER_IDS:
		if seats.values().has(pid):
			ids.append(pid)
	return ids


func _broadcast_lobby() -> void:
	var joined := _joined()
	for id: int in seats:
		if id != 1:
			_lobby.rpc_id(id, seats[id], joined, _needed)
	lobby_changed.emit(joined, _needed)


@rpc("authority", "call_remote", "reliable")
func _lobby(your_seat: String, joined: Array, needed: int) -> void:
	seat = your_seat
	lobby_changed.emit(joined, needed)


## Все на местах — хост раздаёт партию. Колоды тасует только он.
func start_game(game_seed: int) -> void:
	if not is_host or started or not is_full():
		return
	started = true
	var ids: Array[String] = []
	for pid in _joined():
		ids.append(String(pid))
	var state := GameSetup.new_game(ids, game_seed, [], false, true, true, _mode)
	server = GameServer.new(state)
	var board := StateView.board_snapshot(state)
	var views: Dictionary = _views()
	for id: int in seats:
		if id != 1:
			_start.rpc_id(id, board, views[seats[id]])
	game_started.emit(seat, board, views[seat])


@rpc("authority", "call_remote", "reliable")
func _start(board: Dictionary, view: Dictionary) -> void:
	started = true
	game_started.emit(seat, board, view)


func _views() -> Dictionary:
	var views: Dictionary = {}
	for pid: String in server.state.players.keys():
		views[pid] = StateView.for_player_with_pending(server.state, pid, server.resolver.pending)
	return views


# --- ходы --------------------------------------------------------------------

func send_intent(intent: Intent) -> void:
	if is_host:
		_host_apply(1, intent.to_dict())
	else:
		_intent.rpc_id(1, intent.to_dict())


@rpc("any_peer", "call_remote", "reliable")
func _intent(d: Dictionary) -> void:
	if is_host:
		_host_apply(multiplayer.get_remote_sender_id(), d)


## Ход применяет только хост. Цвет берём из рассадки, а не из намерения:
## клиент не может сходить за другого.
func _host_apply(sender: int, d: Dictionary) -> void:
	if not started or not seats.has(sender):
		return
	var intent := Intent.from_dict(d)
	intent.player_id = String(seats[sender])
	var result: Dictionary = server.apply_intent(intent)
	var err := int(result["error"])
	var events: Array = result["events"]
	var views: Dictionary = result["views"]
	for id: int in seats:
		# Отказ касается только того, кто ошибся: остальным слать нечего.
		if err != GameServer.Error.OK and id != sender:
			continue
		var own_err := err if id == sender else GameServer.Error.OK
		var view: Dictionary = views[seats[id]]
		if id == 1:
			result_received.emit(own_err, events, view)
		else:
			_result.rpc_id(id, own_err, events, view)


@rpc("authority", "call_remote", "reliable")
func _result(err: int, events: Array, view: Dictionary) -> void:
	result_received.emit(err, events, view)


@rpc("authority", "call_remote", "reliable")
func _left(gone: String) -> void:
	player_left.emit(gone)


# --- чат ---------------------------------------------------------------------

func send_chat(text: String) -> void:
	if is_host:
		_host_chat(1, text)
	else:
		_chat_up.rpc_id(1, text)


@rpc("any_peer", "call_remote", "reliable")
func _chat_up(text: String) -> void:
	if is_host:
		_host_chat(multiplayer.get_remote_sender_id(), text)


func _host_chat(sender: int, text: String) -> void:
	if not seats.has(sender):
		return
	var who := String(seats[sender])
	var clean := text.strip_edges().left(300)
	_chat_down.rpc(who, clean)
	chat_received.emit(who, clean)


@rpc("authority", "call_remote", "reliable")
func _chat_down(who: String, text: String) -> void:
	chat_received.emit(who, text)
