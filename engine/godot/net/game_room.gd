class_name GameRoom
extends RefCounted

## Одна комната сетевой игры: кто за каким цветом и сама партия (этап 6).
##
## Комнаты держит NetSession той программы, что раздаёт партии: хоста по IP
## (одна комната) или выделенного сервера (много комнат, у каждой свой код).
## Сама комната сети не знает — ей дают номер подключения (peer id), она
## отвечает цветом и результатом хода; рассылает NetSession.

const PLAYER_IDS: Array[String] = ["red", "blue", "green", "purple"]
const MIN_PLAYERS := 2
const MAX_PLAYERS := 4

var code: String
var needed: int
var mode: String
## Кто создал комнату (или сел первым, если создатель ушёл) — он жмёт START.
var owner_peer := 0
var seats: Dictionary = {}  # peer id -> player id
## Профили сидящих (PlayerProfile): player id -> {name, emblem}.
var profiles: Dictionary = {}
## Учётные записи рейтинга (RatingBook.account_of): player id -> account.
## Только на выделенном сервере; игрокам не рассылаются.
var accounts: Dictionary = {}
## Рейтинг по итогам этой партии уже пересчитан.
var rated := false
var started := false
var server: GameServer
## Задача WorkerThreadPool, что считает снимок доски на выделенном сервере;
## -1 — не считается. Пока считается, ходы комнаты не принимаются.
var board_task := -1


func _init(room_code: String, player_count: int, game_mode: String) -> void:
	code = room_code
	needed = clampi(player_count, MIN_PLAYERS, MAX_PLAYERS)
	mode = game_mode if GameSetup.MODES.has(game_mode) else GameSetup.MODE_STANDARD


func is_full() -> bool:
	return seats.size() >= needed


## Цвета сидящих — в порядке рассадки, а не подключения.
func joined() -> Array:
	var ids: Array = []
	for pid: String in PLAYER_IDS:
		if seats.values().has(pid):
			ids.append(pid)
	return ids


## Посадить за первый свободный цвет. Возвращает цвет ("" — мест нет).
func add(peer: int) -> String:
	if started or is_full():
		return ""
	for pid: String in PLAYER_IDS:
		if not seats.values().has(pid):
			seats[peer] = pid
			if owner_peer == 0:
				owner_peer = peer
			return pid
	return ""


func remove(peer: int) -> void:
	if not started:
		profiles.erase(String(seats.get(peer, "")))
		accounts.erase(String(seats.get(peer, "")))
	seats.erase(peer)
	if owner_peer == peer:
		owner_peer = int(seats.keys()[0]) if not seats.is_empty() else 0


func owner_seat() -> String:
	return String(seats.get(owner_peer, ""))


## Раздать партию. Колоды тасует только тот, у кого комната.
## Возвращает {board, views}.
func start(game_seed: int) -> Dictionary:
	var views := deal(game_seed)
	return {"board": StateView.board_snapshot(server.state), "views": views}


## Раздача без снимка доски: снимок (чертёж доски, BoardSchematic) считается
## дольше всего, и выделенный сервер делает его в фоне (NetSession._start_room),
## чтобы другие комнаты не ждали. Возвращает срезы игроков: цвет -> view.
func deal(game_seed: int) -> Dictionary:
	started = true
	var ids: Array[String] = []
	for pid in joined():
		ids.append(String(pid))
	var state := GameSetup.new_game(ids, game_seed, [], false, true, true, mode)
	server = GameServer.new(state)
	var views: Dictionary = {}
	for pid: String in ids:
		views[pid] = StateView.for_player_with_pending(state, pid, server.resolver.pending)
	return views


## Применить ход игрока. Цвет берём из рассадки, а не из намерения: сходить
## за другого нельзя. Возвращает то же, что GameServer.apply_intent.
func apply(peer: int, d: Dictionary) -> Dictionary:
	var intent := Intent.from_dict(d)
	intent.player_id = String(seats[peer])
	return server.apply_intent(intent)
