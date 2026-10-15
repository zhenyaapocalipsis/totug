class_name ProfileBook
extends RefCounted

## Профили игроков на сервере (владелец, 2026-10-15): чтобы смотреть чужой
## профиль — средние VP по статьям (многоугольник) и партии с реплеями.
## Свой профиль игрок по-прежнему ведёт у себя (PlayerProfile); здесь та же
## строка истории (PlayerProfile.history_entry) и те же суммы
## (PlayerProfile.merge_totals), только для каждой учётной записи.
## Хранятся все партии (владелец, 2026-10-16: игроков немного); партии до
## выкладки профилей досчитываются из записей партий сервера (backfill).
##
## Файл рядом с рейтингами (ratings_profiles.json):
## учётная запись -> {totals: {...}, games: [строки истории, новые первыми]}.

var accounts: Dictionary = {}
var _path := ""


func _init(path: String) -> void:
	_path = path
	accounts = RatingBook._read(path)


func save() -> void:
	RatingBook._write(_path, accounts)


## Партия окончена: строка истории игрока (entry["replay"] — запись партии на
## сервере). Сохранять — save() после всех игроков партии.
func add(account: String, entry: Dictionary) -> void:
	if account == "":
		return
	var person: Dictionary = accounts.get(account, {})
	var games: Array = person.get("games", [])
	games.push_front(entry)
	person["games"] = games
	person["totals"] = PlayerProfile.merge_totals(person.get("totals", {}), entry)
	accounts[account] = person


func totals_of(account: String) -> Dictionary:
	return PlayerProfile.clean_totals((accounts.get(account, {}) as Dictionary).get("totals", {}))


func history_of(account: String) -> Array:
	return ((accounts.get(account, {}) as Dictionary).get("games", []) as Array).duplicate(true)


## Запись партии file есть в чьей-то истории — её можно отдать клиенту.
func knows_replay(file: String) -> bool:
	if file == "":
		return false
	for person: Dictionary in accounts.values():
		for game: Dictionary in person.get("games", []):
			if String(game.get("replay", "")) == file:
				return true
	return false


## Досчитать партии из записей сервера (dir), которых ещё нет ни в одной
## истории — те, что сыграны до выкладки профилей (2026-10-15). Берутся, как и
## живые: доигранные до конца, все места — учётные записи (names: ник ->
## учётная запись, RatingBook.names). Разбивка VP — из пересобранной партии;
## не сошлась с записью (правила с тех пор менялись) — партия только в
## истории, без многоугольника. Рейтинга тех партий нет (строка "old").
## Возвращает, сколько партий добавлено; сохранять — save().
func backfill(dir: String, names: Dictionary) -> int:
	var known := {}
	for person: Dictionary in accounts.values():
		for game: Dictionary in person.get("games", []):
			known[String(game.get("replay", ""))] = true
	var added := 0
	var touched := {}
	for file in ReplayBook.list(dir):
		if known.has(file):
			continue
		var replay := ReplayBook.load_replay(file, dir)
		var header: Dictionary = replay.get("header", {})
		if header.is_empty() or String(header.get("abandoned_by", "")) != "":
			continue
		var profiles: Dictionary = header.get("profiles", {})
		var account_of := {}
		for pid in header.get("ids", []):
			var account := String(names.get(RatingBook.name_id(
				String((profiles.get(pid, {}) as Dictionary).get("name", ""))), ""))
			if account == "" or account_of.values().has(account):
				account_of = {}
				break
			account_of[String(pid)] = account
		if account_of.is_empty():
			continue
		var result := result_of(replay)
		for pid: String in result:
			var entry := PlayerProfile.history_entry(pid, result, profiles)
			entry["time"] = int(header.get("date", 0))
			entry["replay"] = file
			entry["protocol"] = int(header.get("protocol", 0))
			entry["mode"] = String(header.get("mode", ""))
			entry["teams"] = bool(header.get("teams", false))
			entry["old"] = true
			var person: Dictionary = accounts.get(account_of[pid], {})
			var games: Array = person.get("games", [])
			games.append(entry)
			person["games"] = games
			accounts[account_of[pid]] = person
			touched[account_of[pid]] = true
		added += 1
	# Новые первыми; суммы — заново по всей истории.
	for account: String in touched:
		var person: Dictionary = accounts[account]
		var games: Array = person["games"]
		games.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("time", 0)) > int(b.get("time", 0)))
		var totals := {}
		for game: Dictionary in games:
			totals = PlayerProfile.merge_totals(totals, game)
		person["totals"] = totals
	return added


## Итог партии из её записи в том виде, что ждёт PlayerProfile.history_entry.
static func result_of(replay: Dictionary) -> Dictionary:
	var header: Dictionary = replay["header"]
	var scores: Dictionary = header.get("scores", {})
	var winners: Array = header.get("winners", [])
	var server := ReplayBook.rebuild(replay)
	var same := ReplayBook.matches(replay, server)
	var out := {}
	for pid in header.get("ids", []):
		var r := {"vp": int(scores.get(pid, 0)), "won": winners.has(pid), "rating": 0, "delta": 0,
			"half_decks": (header.get("half_decks", []) as Array).duplicate()}
		if bool(header.get("teams", false)):
			r["kind"] = RatingBook.TEAM
		if same:
			r["breakdown"] = Scoring.breakdown(server.state, pid)
			r["ic_cards"] = (server.state.players[pid] as PlayerState).deck.inner_circle.size()
		out[String(pid)] = r
	return out
