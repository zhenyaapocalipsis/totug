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
static func save(header: Dictionary, intents: Array, dir: String = DIR) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_unix_time(int(header.get("date", 0))).replace(":", "").replace("-", "").replace("T", "_")
	var tail := String(header.get("code", ""))
	var file := "%s_%s.json" % [stamp, tail if tail != "" else "local"]
	var f := FileAccess.open(dir + file, FileAccess.WRITE)
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


## Имена файлов реплеев, новые первыми.
static func list(dir: String = DIR) -> Array[String]:
	var names: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return names
	for name in d.get_files():
		if name.ends_with(".json"):
			names.append(name)
	names.sort()
	names.reverse()
	return names


## {} — файла нет или он повреждён.
static func load_replay(file: String, dir: String = DIR) -> Dictionary:
	var f := FileAccess.open(dir + file, FileAccess.READ)
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
	return int((replay.get("header", {}) as Dictionary).get("protocol", -1)) == NetSession.PROTOCOL


## Начало партии реплея: раздача тем же сидом, ни одного хода ещё.
static func start(replay: Dictionary) -> GameServer:
	var header: Dictionary = replay["header"]
	var ids: Array[String] = []
	for pid in (header.get("ids", []) as Array):
		ids.append(String(pid))
	var state := GameSetup.new_game(ids, int(header.get("seed", 0)), [], false, true, true,
		String(header.get("mode", GameSetup.MODE_STANDARD)))
	return GameServer.new(state, bool(header.get("mulligan", true)))


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
