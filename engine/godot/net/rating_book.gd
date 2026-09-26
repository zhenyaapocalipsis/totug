class_name RatingBook
extends RefCounted

## Рейтинг Эло онлайн-партий (решение владельца, 2026-09-26): его ведёт только
## выделенный сервер. Игрока узнаём по секретному ключу из его профиля
## (PlayerProfile.key) — чужое имя взять можно, чужой рейтинг нет. Сервер
## хранит не сам ключ, а его хеш: это и есть номер учётной записи.
##
## Партия на 3–4 игроков считается как все пары сразу: в каждой паре выше тот,
## у кого больше итоговых VP, равный счёт — ничья. Изменение в паре делится
## на (игроков - 1), так что партия на четверых весит столько же, сколько 1v1.

const START := 1000
const K := 32.0
const PATH := "user://ratings.json"

## Учётная запись -> {name, rating, games, wins}.
var accounts: Dictionary = {}
var _path := PATH


func _init(path: String = PATH) -> void:
	_path = path
	var f := FileAccess.open(_path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		accounts = parsed


func save() -> void:
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(accounts, "\t"))


## Номер учётной записи по ключу игрока ("" — ключа нет или он негодный).
static func account_of(key: String) -> String:
	if key.length() < 16:
		return ""
	return key.sha256_text()


func rating_of(account: String) -> int:
	return int((accounts.get(account, {}) as Dictionary).get("rating", START))


## Изменения рейтинга по итогам партии: ratings и scores — место -> число.
static func elo_deltas(ratings: Dictionary, scores: Dictionary) -> Dictionary:
	var seats: Array = ratings.keys()
	var weight := K / float(maxi(1, seats.size() - 1))
	var out := {}
	for a in seats:
		var change := 0.0
		for b in seats:
			if a == b:
				continue
			var expected := 1.0 / (1.0 + pow(10.0, (float(ratings[b]) - float(ratings[a])) / 400.0))
			var actual := 0.5
			if int(scores[a]) != int(scores[b]):
				actual = 1.0 if int(scores[a]) > int(scores[b]) else 0.0
			change += weight * (actual - expected)
		out[a] = roundi(change)
	return out


## Записать партию. players: место -> {account, name}; scores: место -> VP;
## winners — места победителей. Возвращает место -> {rating, delta}. Партия не
## идёт в рейтинг ({}), если у кого-то нет учётной записи или один человек
## сидит за двумя цветами (два окна на одном компьютере).
func record(players: Dictionary, scores: Dictionary, winners: Array) -> Dictionary:
	var seen := {}
	var ratings := {}
	for seat in players:
		var account := String(players[seat]["account"])
		if account == "" or seen.has(account):
			return {}
		seen[account] = true
		ratings[seat] = rating_of(account)
	var deltas := elo_deltas(ratings, scores)
	var out := {}
	for seat in players:
		var account := String(players[seat]["account"])
		var entry: Dictionary = accounts.get(account, {"rating": START, "games": 0, "wins": 0})
		entry["name"] = String(players[seat]["name"])
		entry["rating"] = int(ratings[seat]) + int(deltas[seat])
		entry["games"] = int(entry.get("games", 0)) + 1
		entry["wins"] = int(entry.get("wins", 0)) + (1 if winners.has(seat) else 0)
		accounts[account] = entry
		out[seat] = {"rating": entry["rating"], "delta": deltas[seat]}
	save()
	return out
