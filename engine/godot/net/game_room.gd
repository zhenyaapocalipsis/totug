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

## Этап 7: сохранение и переподключение.
## Цвета в игре, в порядке, которым они попали в GameSetup.new_game (нужен
## для восстановления партии тем же сидом — см. restore()).
var ids: Array[String] = []
var game_seed: int = 0
## Ключ профиля (PlayerProfile.key(), приходит с _profile_up) для каждого
## цвета — по нему переподключившийся игрок находит своё старое место
## (см. claim()). Хранится независимо от рейтинга: host-по-IP не считает
## рейтинг, но переподключение там всё равно нужно.
var keys: Dictionary = {}
## Снимок доски (геометрия, статична за партию) — считается один раз при
## раздаче и отдаётся заново при переподключении без пересчёта.
var cached_board: Dictionary = {}
## Принятые Intent'ы по порядку (Dictionary, как ушли по сети) — журнал для
## GameJournal.save() и для restore() после перезапуска сервера.
var log: Array = []


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
		var pid := String(seats.get(peer, ""))
		profiles.erase(pid)
		accounts.erase(pid)
		keys.erase(pid)
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
func deal(seed_value: int) -> Dictionary:
	started = true
	game_seed = seed_value
	ids = []
	for pid in joined():
		ids.append(String(pid))
	var state := GameSetup.new_game(ids, game_seed, [], false, true, true, mode)
	server = GameServer.new(state)
	var views: Dictionary = {}
	for pid: String in ids:
		views[pid] = StateView.for_player_with_pending(state, pid, server.resolver.pending)
	return views


## Применить ход игрока. Цвет берём из рассадки, а не из намерения: сходить
## за другого нельзя. Возвращает то же, что GameServer.apply_intent, плюс
## intent — что реально применилось (для журнала, см. NetSession._save_room).
func apply(peer: int, d: Dictionary) -> Dictionary:
	var intent := Intent.from_dict(d)
	intent.player_id = String(seats[peer])
	var result := server.apply_intent(intent)
	if int(result["error"]) == GameServer.Error.OK:
		log.append(intent.to_dict())
	result["intent"] = intent.to_dict()
	return result


## Переподключение (этап 7): тот же ключ профиля, что раньше сидел за каким-то
## цветом в этой партии, и цвет сейчас никем не занят. Возвращает цвет
## ("" — не нашли: чужой ключ, или место уже занято тем, кто не отключался).
func claim(peer: int, key: String) -> String:
	if not started or key == "":
		return ""
	for pid: String in keys.keys():
		if String(keys[pid]) == key and not seats.values().has(pid):
			seats[peer] = pid
			if owner_peer == 0:
				owner_peer = peer
			return pid
	return ""


## Восстановить комнату из журнала (GameJournal) после перезапуска сервера:
## та же раздача тем же сидом, потом по порядку — все принятые Intent'ы.
## Никто пока не подключён (seats пуст) — переподключаются через claim().
static func restore(header: Dictionary, intents: Array) -> GameRoom:
	var room_ids: Array[String] = []
	for pid in (header.get("ids", []) as Array):
		room_ids.append(String(pid))
	var room := GameRoom.new(String(header.get("code", "")), room_ids.size(),
		String(header.get("mode", GameSetup.MODE_STANDARD)))
	room.ids = room_ids
	room.game_seed = int(header.get("seed", 0))
	room.profiles = (header.get("profiles", {}) as Dictionary).duplicate(true)
	room.accounts = (header.get("accounts", {}) as Dictionary).duplicate(true)
	room.keys = (header.get("keys", {}) as Dictionary).duplicate(true)
	var state := GameSetup.new_game(room.ids, room.game_seed, [], false, true, true, room.mode)
	room.server = GameServer.new(state)
	room.started = true
	for d in intents:
		room.server.apply_intent(Intent.from_dict(d as Dictionary))
		room.log.append(d)
	room.cached_board = StateView.board_snapshot(state)
	return room
