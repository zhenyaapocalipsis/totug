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
## 2 на 2 (этап Team-3): red+green против blue+purple (GameSetup.team_map).
var teams := false
## Кто создал комнату (или сел первым, если создатель ушёл) — он жмёт START.
var owner_peer := 0
var seats: Dictionary = {}  # peer id -> player id
## Любимый цвет из профиля (PlayerProfile.clean_colour): peer id -> цвет.
var wants: Dictionary = {}
## Профили сидящих (PlayerProfile): player id -> {name, emblem}.
var profiles: Dictionary = {}
## Учётные записи рейтинга (RatingBook.account_of): player id -> account.
## Только на выделенном сервере; игрокам не рассылаются.
var accounts: Dictionary = {}
## Рейтинг по итогам этой партии уже пересчитан.
var rated := false
## Партию собрал поиск игры (NetSession._match): за неё дают награду
## (SkinCollection.reward_for_place), за комнаты по коду — нет.
var matched := false
## Предпочтительные баны игроков поиска игры — полуколоды, которых рынок по
## возможности избегает (GameSetup.pick_half_decks).
var banned: Array[String] = []
## Лобби банов поиска игры (этап Ban-1, владелец 2026-10-29; с 2026-10-30 —
## только RANDOM 4, has_bans): после того как стол собран, игроки по очереди
## банят до BANS_EACH карт выбранных полуколод (все копии уходят из рынка,
## рынок набирается из оставшихся).
## card_bans — итог, идёт в GameSetup.new_game и в журнал/реплей.
const BANS_EACH := 2
const BAN_SECONDS := 60.0
var card_bans: Array[String] = []
## Фаза банов: идёт (ban_phase), сид раздачи выбран заранее (ban_seed — от
## него зависят полуколоды), запас доски (stocked) уже взят под этот сид.
var ban_phase := false
var ban_seed := 0
var stocked: Dictionary = {}
var ban_decks: Array[String] = []
## Очередь банов — цвета по кругу BANS_EACH раз; ban_turn — чей сейчас.
var ban_order: Array[String] = []
var ban_turn := 0
var ban_left := 0.0
## Кто что забанил по порядку: [{"seat", "card"}], card "" — пропуск.
var ban_log: Array = []
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
## Имя файла записи окончившейся партии на сервере (records_dir) — по нему
## чужие профили отдают реплей (ProfileBook).
var record_file := ""

## Зрители (друзья игроков; владелец, 2026-10-11): peer id -> true. Видят только
## открытое (StateView для "") и с задержкой в ход: шаги идущего хода копятся
## в watch_buffer ([события, срез]) и уходят зрителям, когда ход сменился.
## watch_view — срез на последней такой отсечке (с него начинает новый зритель),
## watch_player — чей ход идёт за отсечкой.
var watchers: Dictionary = {}
var watch_buffer: Array = []
var watch_view: Dictionary = {}
var watch_player := ""

## Пауза: партия стоит, ходы не принимаются (NetSession._room_apply). Две
## причины. absent — кто отключился посреди партии: цвет -> сколько секунд
## его уже нет (не вернулся за NetSession.abandon_seconds — партия кончается).
## paused_by — кто поставил общую паузу кнопкой, pause_time — сколько она
## уже длится (через NetSession.pause_seconds снимается сама).
var absent: Dictionary = {}
var paused_by := ""
var pause_time := 0.0


func _init(room_code: String, player_count: int, game_mode: String, team_game: bool = false) -> void:
	code = room_code
	teams = team_game
	needed = MAX_PLAYERS if teams else clampi(player_count, MIN_PLAYERS, MAX_PLAYERS)
	mode = game_mode if GameSetup.is_mode(game_mode) else GameSetup.MODE_STANDARD


func is_full() -> bool:
	return seats.size() >= needed


## Цвета сидящих — в порядке рассадки, а не подключения.
func joined() -> Array:
	var ids: Array = []
	for pid: String in PLAYER_IDS:
		if seats.values().has(pid):
			ids.append(pid)
	return ids


## Посадить за первый свободный цвет, а если задан preferred — пересадить за
## него (prefer). Возвращает цвет ("" — мест нет).
func add(peer: int, preferred: String = "") -> String:
	if started or is_full():
		return ""
	for pid: String in PLAYER_IDS:
		if not seats.values().has(pid):
			seats[peer] = pid
			if owner_peer == 0:
				owner_peer = peer
			return prefer(peer, preferred) if preferred != "" else pid
	return ""


## Пересадить игрока за любимый цвет, пока партия не раздана. Цвет свободен —
## садится. Занят тем, кто его сам не выбирал, — меняются местами (профиль,
## ключ и учётная запись переезжают вместе с игроком). Занят тем, кто выбрал
## его раньше, — остаётся где был. Возвращает цвет игрока.
func prefer(peer: int, colour: String) -> String:
	if not seats.has(peer):
		return ""
	if PLAYER_IDS.has(colour):
		wants[peer] = colour
	else:
		wants.erase(peer)
	var old := String(seats[peer])
	if started or not PLAYER_IDS.has(colour) or old == colour:
		return old
	var holder = seats.find_key(colour)
	if holder != null and String(wants.get(holder, "")) == colour:
		return old
	for data: Dictionary in [profiles, accounts, keys]:
		_swap(data, old, colour)
	seats[peer] = colour
	if holder != null:
		seats[holder] = old
	return colour


## Цвета мест команды team в комнате 2 на 2: red -> red, green; blue -> blue, purple.
static func team_seats(team: String) -> Array[String]:
	var team_of := GameSetup.team_map(PLAYER_IDS)
	var out: Array[String] = []
	for pid: String in PLAYER_IDS:
		if team_of[pid] == team:
			out.append(pid)
	return out


## Лобби 2 на 2: пересесть на свободное место команды team. Место запоминается
## как выбранное (wants) — любимый цвет опоздавшего его не отнимет. Мест в
## команде нет или игрок уже в ней — остаётся где был. Возвращает цвет игрока.
func choose_team(peer: int, team: String) -> String:
	if not seats.has(peer):
		return ""
	var old := String(seats[peer])
	var seats_of := team_seats(team)
	if started or not teams or seats_of.is_empty() or seats_of.has(old):
		return old
	for colour: String in seats_of:
		if not seats.values().has(colour):
			for data: Dictionary in [profiles, accounts, keys]:
				_swap(data, old, colour)
			seats[peer] = colour
			wants[peer] = colour
			return colour
	return old


static func _swap(data: Dictionary, a: String, b: String) -> void:
	var had_a := data.has(a)
	var had_b := data.has(b)
	var value_a = data.get(a)
	var value_b = data.get(b)
	data.erase(a)
	data.erase(b)
	if had_a:
		data[b] = value_a
	if had_b:
		data[a] = value_b


func remove(peer: int) -> void:
	if not started:
		var pid := String(seats.get(peer, ""))
		profiles.erase(pid)
		accounts.erase(pid)
		keys.erase(pid)
	seats.erase(peer)
	wants.erase(peer)
	if owner_peer == peer:
		owner_peer = int(seats.keys()[0]) if not seats.is_empty() else 0


## Банят только за столами RANDOM 4 (владелец, 2026-10-30).
static func has_bans(room_mode: String) -> bool:
	return room_mode == GameSetup.MODE_RANDOM_4


## Начать фазу банов. Полуколоды — те, что выберет раздача этим сидом: баны
## карт на выбор полуколод не влияют (GameSetup.new_game). Очередь — цвета в
## порядке рассадки, по кругу BANS_EACH раз.
func begin_bans(seed_value: int) -> void:
	ban_phase = true
	ban_seed = seed_value
	card_bans = []
	ban_log = []
	var order: Array[String] = []
	for pid in joined():
		order.append(String(pid))
	var preview := GameSetup.new_game(order, seed_value, [], false, true, true, mode, teams, banned)
	ban_decks = preview.half_decks.duplicate()
	ban_order = []
	for i in BANS_EACH:
		ban_order.append_array(order)
	ban_turn = 0
	ban_left = BAN_SECONDS


## Чей сейчас бан ("" — фаза не идёт).
func ban_seat() -> String:
	return ban_order[ban_turn] if ban_phase and ban_turn < ban_order.size() else ""


## Карты, которые можно банить: уникальные карты выбранных полуколод.
func ban_pool() -> Array[String]:
	var pool: Array[String] = []
	for deck: String in ban_decks:
		for cid: String in GameSetup.half_deck_copies(deck).keys():
			if not pool.has(cid):
				pool.append(cid)
	return pool


## Бан игрока pid; card "" — пропуск. false — не его очередь или карту
## банить нельзя (уже забанена, не из этих полуколод).
func ban(pid: String, card: String) -> bool:
	if pid == "" or pid != ban_seat():
		return false
	if card != "" and (card_bans.has(card) or not ban_pool().has(card)):
		return false
	if card != "":
		card_bans.append(card)
	ban_log.append({"seat": pid, "card": card})
	ban_turn += 1
	ban_left = BAN_SECONDS
	if ban_turn >= ban_order.size():
		ban_phase = false
	return true


## Таймер бана: время вышло — бан пропущен. true — очередь сдвинулась.
func tick_bans(delta: float) -> bool:
	if not ban_phase:
		return false
	ban_left -= delta
	return ban_left <= 0.0 and ban(ban_seat(), "")


## Что видят игроки в лобби банов.
func ban_view() -> Dictionary:
	return {"decks": ban_decks, "mode": mode, "bans": ban_log.duplicate(true), "turn": ban_seat(),
		"order": ban_order, "left": maxf(0.0, ban_left), "each": BANS_EACH}


## Партия идёт (раздана и не окончена) — только в ней бывает пауза.
func in_play() -> bool:
	return started and server != null and not server.state.game_over


func is_paused() -> bool:
	return in_play() and (not absent.is_empty() or paused_by != "")


## Отключился посреди партии: партия встаёт, пока он не вернётся. Его общая
## пауза, если была, снимается — теперь партию держит его отсутствие.
func mark_absent(pid: String) -> void:
	if not in_play() or pid == "":
		return
	absent[pid] = 0.0
	if paused_by == pid:
		paused_by = ""


## Пауза для игроков: {absent: {цвет: секунд до конца партии}, by: кто
## поставил общую паузу ("" — никто), left: секунд до её конца}.
func pause_status(abandon_seconds: float, pause_seconds: float) -> Dictionary:
	var gone := {}
	if in_play():
		for pid: String in absent:
			gone[pid] = maxf(0.0, abandon_seconds - float(absent[pid]))
	var by := paused_by if in_play() else ""
	return {"absent": gone, "by": by, "left": maxf(0.0, pause_seconds - pause_time) if by != "" else 0.0}


## Время паузы идёт. Считаем, только пока за столом кто-то есть: после
## перезапуска сервера отсутствуют все, и ждать им некого. Возвращает, что
## случилось: {abandon: цвет} — кто-то не вернулся вовремя, партию пора
## кончать; {resumed: true} — общая пауза кончилась сама; {} — ничего.
func tick_pause(delta: float, abandon_seconds: float, pause_seconds: float) -> Dictionary:
	if not is_paused() or seats.is_empty():
		return {}
	for pid: String in absent.keys():
		absent[pid] = float(absent[pid]) + delta
		if float(absent[pid]) >= abandon_seconds:
			return {"abandon": pid}
	if paused_by != "":
		pause_time += delta
		if pause_time >= pause_seconds:
			paused_by = ""
			return {"resumed": true}
	return {}


## Общая пауза кнопкой: поставить может любой (если её ещё нет), снять —
## только тот, кто поставил. Возвращает true, если пауза изменилась.
func set_manual_pause(pid: String, on: bool) -> bool:
	if not in_play() or pid == "":
		return false
	if on and paused_by == "":
		paused_by = pid
		pause_time = 0.0
		return true
	if not on and paused_by == pid:
		paused_by = ""
		return true
	return false


## Партия кончилась досрочно: отсутствующий не вернулся. Рейтинг не меняется
## (rated — будто уже посчитан). Возвращает то же, что GameServer.apply_intent.
func abandon(pid: String) -> Dictionary:
	absent.clear()
	paused_by = ""
	rated = true
	return server.abandon(pid)


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
	var state := GameSetup.new_game(ids, game_seed, [], false, true, true, mode, teams, banned, card_bans)
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
			absent.erase(pid)
			if owner_peer == 0:
				owner_peer = peer
			return pid
	return ""


## Соединение, которое сидит за цветом с ключом key (0 — такого нет). Игра,
## закрытая Alt+F4, не прощается с сервером: он ещё 5-15 с считает старое
## соединение живым, и вернувшийся быстрее игрок натыкался на "занятое" место.
func peer_with_key(key: String) -> int:
	if key == "":
		return 0
	for peer: int in seats:
		if String(keys.get(String(seats[peer]), "")) == key:
			return peer
	return 0


## Восстановить комнату из журнала (GameJournal) после перезапуска сервера:
## та же раздача тем же сидом, потом по порядку — все принятые Intent'ы.
## Никто пока не подключён (seats пуст) — переподключаются через claim().
static func restore(header: Dictionary, intents: Array) -> GameRoom:
	var room_ids: Array[String] = []
	for pid in (header.get("ids", []) as Array):
		room_ids.append(String(pid))
	var room := GameRoom.new(String(header.get("code", "")), room_ids.size(),
		String(header.get("mode", GameSetup.MODE_STANDARD)), bool(header.get("teams", false)))
	room.ids = room_ids
	room.game_seed = int(header.get("seed", 0))
	room.profiles = (header.get("profiles", {}) as Dictionary).duplicate(true)
	room.accounts = (header.get("accounts", {}) as Dictionary).duplicate(true)
	room.keys = (header.get("keys", {}) as Dictionary).duplicate(true)
	room.matched = bool(header.get("matched", false))
	for deck in (header.get("banned", []) as Array):
		room.banned.append(String(deck))
	for cid in (header.get("card_bans", []) as Array):
		room.card_bans.append(String(cid))
	var state := GameSetup.new_game(room.ids, room.game_seed, [], false, true, true, room.mode, room.teams, room.banned,
		room.card_bans)
	# Партии, начатые до муллигана рынка (в заголовке нет "mulligan"),
	# переигрываются без него — иначе их ходы лягут не на те вопросы.
	room.server = GameServer.new(state, bool(header.get("mulligan", false)))
	room.started = true
	for d in intents:
		room.server.apply_intent(Intent.from_dict(d as Dictionary))
		room.log.append(d)
	# только выделенный сервер: доска без лимита времени — та же, что до перезапуска
	room.cached_board = StateView.board_snapshot(state, {}, BoardSchematic.NO_BUDGET)
	# Никто ещё не вернулся: партия стоит, пока не соберутся все (время
	# отсутствия пойдёт, когда за столом появится первый — tick_pause).
	for pid: String in room.ids:
		room.mark_absent(pid)
	return room
