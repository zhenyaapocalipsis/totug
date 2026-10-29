class_name ReplayBook
extends RefCounted

## Реплеи сыгранных партий (этап Replay-1, решение владельца 2026-10-08:
## «как в Dota» — ходы + сид, просмотр в игре, до 4 игроков).
##
## Реплей — тот же журнал, что GameJournal (сид, состав, режим и все принятые
## Intent'ы по порядку), плюс итог партии для списка в меню: дата, очки,
## победители. Просмотр = GameSetup.new_game() с тем же сидом + apply_intent()
## каждой строки (rebuild) — RNG партии детерминирован, поэтому повторный
## розыгрыш собирает бит-в-бит ту же партию.
##
## Реплей привязан к версии правил: после правки карт старые ходы могут лечь
## не на те вопросы. Поэтому в заголовке — PROTOCOL сети (он меняется при
## любой несовместимой правке правил); matches() сверяет пересобранный итог
## с записанным.
##
## Смотрят реплей из истории онлайн-партий в профиле (решение владельца,
## 2026-10-08: без отдельной вкладки) — строка истории помнит имя файла
## (PlayerProfile.history_entry, поле "replay"). Реплей живёт, пока жива его
## строка: keep_only() стирает остальные.
##
## Один файл на партию в DIR. dir — параметр, чтобы тест не трогал реплеи
## владельца (тот же приём, что у GameJournal).

const DIR := "user://replays/"
const FORMAT := 1
## Файл реплея — JSON, сжатый gzip (в ~25 раз меньше: партия на четверых
## ~5 КБ вместо ~100 КБ). Первые реплеи (Replay-1) — несжатые .json, читаются тоже.
const EXT := ".replay"


## Заголовок реплея из окончившейся партии. seat — чьими глазами партия
## записана ("" — хотсит, за экраном все); code — код комнаты ("" — хотсит).
static func header_for(state: GameState, ids: Array[String], game_seed: int, mode: String,
		mulligan: bool, profiles: Dictionary, seat: String, code: String, intents: Array) -> Dictionary:
	var scores := {}
	for pid: String in state.turn_order:
		scores[pid] = int(Scoring.breakdown(state, pid)["total"])
	var vp := Scoring.library_card_vp(state)
	var turns := 0
	for d in intents:
		if int((d as Dictionary).get("type", -1)) == Intent.Type.END_TURN:
			turns += 1
	var names := {}
	for pid: String in ids:
		names[pid] = {"name": String((profiles.get(pid, {}) as Dictionary).get("name", "")),
			"emblem": String((profiles.get(pid, {}) as Dictionary).get("emblem", ""))}
	return {
		"format": FORMAT,
		"protocol": NetSession.PROTOCOL,
		"date": int(Time.get_unix_time_from_system()),
		"code": code,
		"seat": seat,
		"ids": ids,
		"mode": mode,
		"teams": state.is_team_game(),
		"seed": game_seed,
		"mulligan": mulligan,
		"profiles": names,
		"half_decks": Array(state.half_decks),
		"scores": scores,
		"winners": Array(Scoring.winners(state, vp[0], vp[1])),
		"abandoned_by": state.abandoned_by,
		"turns": turns,
	}


## Сохранить реплей. Возвращает имя файла ("" — не вышло).
## name — своё имя файла (чужой реплей с сервера), "" — по дате и коду.
static func save(header: Dictionary, intents: Array, dir: String = DIR, name: String = "") -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_unix_time(int(header.get("date", 0))).replace(":", "").replace("-", "").replace("T", "_")
	var tail := String(header.get("code", ""))
	var file := name if name != "" else "%s_%s%s" % [stamp, tail if tail != "" else "local", EXT]
	var f := FileAccess.open_compressed(dir + file, FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
	if f == null:
		return ""
	f.store_string(JSON.stringify({"header": header, "intents": intents}))
	f.close()
	return file


## Стереть все реплеи, кроме files (те, на которые ссылается история).
static func keep_only(files: Array, dir: String = DIR) -> void:
	for name in list(dir):
		if not files.has(name):
			erase(name, dir)


## Выделенный сервер (этап Sec-2): записей партий не больше max_files и не
## старше max_days дней (по дате в имени файла, now — unix-время); лишние
## стираются, старые первыми. Ссылка на стёртую запись в чужой истории не
## ломается: сервер отдаёт пустой реплей, клиент пишет «not available».
## Возвращает, сколько файлов стёрто.
static func prune(dir: String, max_files: int, max_days: int, now: int) -> int:
	var oldest := now - max_days * 86400
	var removed := 0
	var names := list(dir)
	for i in names.size():
		var when := date_of(names[i])
		if i >= max_files or (when > 0 and when < oldest):
			erase(names[i], dir)
			removed += 1
	return removed


## Дата партии (unix) из имени файла, как его даёт save(): ГГГГММДД_ЧЧММСС_...;
## 0 — имя не такое.
static func date_of(file: String) -> int:
	if file.length() < 15 or file[8] != "_" or not file.substr(0, 8).is_valid_int() \
			or not file.substr(9, 6).is_valid_int():
		return 0
	return Time.get_unix_time_from_datetime_string("%s-%s-%sT%s:%s:%s" % [file.substr(0, 4), file.substr(4, 2),
		file.substr(6, 2), file.substr(9, 2), file.substr(11, 2), file.substr(13, 2)])


## Имена файлов реплеев, новые первыми.
static func list(dir: String = DIR) -> Array[String]:
	var names: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return names
	for name in d.get_files():
		if name.ends_with(EXT) or name.ends_with(".json"):
			names.append(name)
	names.sort()
	names.reverse()
	return names


## {} — файла нет или он повреждён.
static func load_replay(file: String, dir: String = DIR) -> Dictionary:
	var f := FileAccess.open(dir + file, FileAccess.READ) if file.ends_with(".json") \
		else FileAccess.open_compressed(dir + file, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("header") or not parsed.has("intents"):
		return {}
	return parsed


static func erase(file: String, dir: String = DIR) -> void:
	if FileAccess.file_exists(dir + file):
		DirAccess.remove_absolute(dir + file)


## Реплей записан той же версией правил, что сейчас в игре.
static func same_version(replay: Dictionary) -> bool:
	var header: Dictionary = replay.get("header", {})
	return same_rules(int(header.get("protocol", -1)), bool(header.get("teams", false)),
		String(header.get("mode", "")))


## Версии сети, после которых правила не менялись (менялась только связь),
## — их реплеи ложатся на нынешние карты так же (17: до LEADERBOARD; 19: до
## режима 2 на 2 — обычные партии он не меняет, проверено пересборкой реплеев 11.10;
## 20: до экрана DEALING THE CARDS; 21: до правки Gibbering Mouther — реплей с ним
## может разойтись, остальные ложатся так же; 22: до общих бараков 2v2;
## 27: до бана полуколоды в поиске — без бана раздача та же;
## 28: до нового маркета RANDOM — STANDARD/DOUBLE/New Era не менялись;
## 29: до чужих профилей на сервере — правила те же).
const SAME_RULES := [17, 19, 20, 21, 22, 27, 28, 29]
## С этой версии в 2v2 общие бараки, трофеи и внутренний круг (этап Team-6):
## реплеи 2v2 раньше неё — OLD, обычные партии она не меняет.
const TEAM_STOCK := 23
## С этой версии маркет RANDOM 3/4/6 собирается по-новому (этап Market-1):
## реплеи RANDOM раньше неё — OLD, остальные режимы она не меняет.
const RANDOM_MARKET := 29


## mode — режим из заголовка реплея ("" — неизвестен, считаем не RANDOM).
static func same_rules(protocol: int, teams: bool = false, mode: String = "") -> bool:
	if teams and protocol < TEAM_STOCK:
		return false
	if protocol < RANDOM_MARKET and is_random_mode(mode):
		return false
	return protocol == NetSession.PROTOCOL or SAME_RULES.has(protocol)


static func is_random_mode(mode: String) -> bool:
	return mode in [GameSetup.MODE_RANDOM_3, GameSetup.MODE_RANDOM_4, GameSetup.MODE_RANDOM_6]


## Начало партии реплея: раздача тем же сидом, ни одного хода ещё.
static func start(replay: Dictionary) -> GameServer:
	var header: Dictionary = replay["header"]
	var ids: Array[String] = []
	for pid in (header.get("ids", []) as Array):
		ids.append(String(pid))
	var state := GameSetup.new_game(ids, int(header.get("seed", 0)), [], false, true, true,
		String(header.get("mode", GameSetup.MODE_STANDARD)), bool(header.get("teams", false)),
		header.get("banned", []) as Array, header.get("card_bans", []) as Array)
	var server := GameServer.new(state, bool(header.get("mulligan", true)), true, false)
	# Срезы собирает тот, кто смотрит (StateView), и только для своего зрителя.
	server.build_views = false
	return server


## Партия после первых position ходов реплея (0 — раздача). Назад реплей не
## отматывается — перемотка назад собирает партию заново с начала.
static func seek(replay: Dictionary, position: int) -> GameServer:
	var server := start(replay)
	for i in clampi(position, 0, (replay["intents"] as Array).size()):
		step(server, replay, i)
	return server


## Где начинаются ходы игроков: позиции (сколько ходов реплея применено) —
## 0 (раздача: муллиган и стартовые локации, одни ответы на вопросы), первое
## действие первого игрока и каждая сразу после END_TURN. Последняя — конец
## реплея.
static func turn_starts(replay: Dictionary) -> Array[int]:
	var starts: Array[int] = [0]
	var intents: Array = replay["intents"]
	var first := 0
	while first < intents.size() and int((intents[first] as Dictionary).get("type", -1)) == Intent.Type.MAKE_DECISION:
		first += 1
	if first > 0 and first < intents.size():
		starts.append(first)
	for i in intents.size():
		var d: Dictionary = intents[i]
		if int(d.get("type", -1)) != Intent.Type.END_TURN:
			continue
		# Вопросы конца хода (promote и т. п.) — ещё ход того же игрока.
		var next := i + 1
		while next < intents.size() and int((intents[next] as Dictionary).get("type", -1)) == Intent.Type.MAKE_DECISION \
				and String((intents[next] as Dictionary).get("player_id", "")) == String(d.get("player_id", "")):
			next += 1
		if next < intents.size():
			starts.append(next)
	starts.append(intents.size())
	return starts


## Применить ход номер index реплея к партии. За последним ходом досрочно
## кончившейся партии — её конец (abandon). Возвращает то же, что
## GameServer.apply_intent.
static func step(server: GameServer, replay: Dictionary, index: int) -> Dictionary:
	var intents: Array = replay["intents"]
	var result := server.apply_intent(Intent.from_dict(intents[index] as Dictionary))
	var gone := String((replay["header"] as Dictionary).get("abandoned_by", ""))
	if index == intents.size() - 1 and gone != "" and not server.state.game_over:
		return server.abandon(gone)
	return result


## Вся партия реплея целиком, до конца.
static func rebuild(replay: Dictionary) -> GameServer:
	var server := start(replay)
	for i in (replay["intents"] as Array).size():
		step(server, replay, i)
	# Бросили ещё до первого хода — step() до abandon не дошёл.
	var gone := String((replay["header"] as Dictionary).get("abandoned_by", ""))
	if gone != "" and not server.state.game_over:
		server.abandon(gone)
	return server


## Пересобранная партия сошлась с записанной: окончена, очки те же.
static func matches(replay: Dictionary, server: GameServer) -> bool:
	if not server.state.game_over:
		return false
	var scores: Dictionary = (replay["header"] as Dictionary).get("scores", {})
	for pid: String in server.state.turn_order:
		if int(scores.get(pid, -1)) != int(Scoring.breakdown(server.state, pid)["total"]):
			return false
	return true
