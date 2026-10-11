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
## Занятые имена (решение владельца, 2026-09-26: имя в сети у каждого своё).
## Имя в нижнем регистре -> учётная запись. Отдельный файл рядом с рейтингами
## (ratings_names.json), чтобы не менять формат ratings.json.
var names: Dictionary = {}
var _path := PATH
var _names_path := ""
## Мировые рекорды (RecordBook) — свой файл рядом (ratings_records.json).
var records: RecordBook
## Друзья и почта (FriendBook) — тоже свой файл рядом (ratings_friends.json).
var friends: FriendBook


func _init(path: String = PATH) -> void:
	_path = path
	_names_path = path.get_basename() + "_names.json"
	accounts = _read(_path)
	names = _read(_names_path)
	records = RecordBook.new(path.get_basename() + "_records.json")
	friends = FriendBook.new(path.get_basename() + "_friends.json")


static func _read(file_path: String) -> Dictionary:
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func save() -> void:
	_write(_path, accounts)


static func _write(file_path: String, data: Dictionary) -> void:
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))


## Занять имя за учётной записью. false — имя уже занято другой записью.
## Прежнее имя этой записи освобождается: сменил имя — старое снова свободно.
## Регистр не важен (Vasya = VASYA). Пустое имя и игрок без ключа — не
## занимают ничего.
func claim_name(account: String, player_name: String) -> bool:
	var id := name_id(player_name)
	if id == "" or account == "":
		return true
	var owner := String(names.get(id, ""))
	if owner == account:
		return true
	if owner != "":
		return false
	for old: String in names.keys():
		if names[old] == account:
			names.erase(old)
	names[id] = account
	_write(_names_path, names)
	return true


## Кириллические буквы, которые выглядят как латинские (после to_lower).
const LOOKALIKES := {"а": "a", "в": "b", "е": "e", "ё": "e", "к": "k", "м": "m", "н": "h", "о": "o",
	"р": "p", "с": "c", "т": "t", "у": "y", "х": "x"}


## Ключ имени для занятости: без регистра, а русские буквы-двойники считаются
## латинскими — иначе «Вов» кириллицей выдавал бы себя за чужого «Bob».
static func name_id(player_name: String) -> String:
	var id := ""
	for ch in player_name.strip_edges().to_lower():
		id += String(LOOKALIKES.get(ch, ch))
	return id


## Номер учётной записи по ключу игрока ("" — ключа нет или он негодный).
static func account_of(key: String) -> String:
	if key.length() < 16:
		return ""
	return key.sha256_text()


## kind: "" — обычный рейтинг, TEAM ("2v2") — отдельный рейтинг командных партий
## (этап Team-5): поля rating_2v2, games_2v2, wins_2v2 той же учётной записи.
const TEAM := "2v2"


static func _field(name: String, kind: String) -> String:
	return name if kind == "" else "%s_%s" % [name, kind]


func rating_of(account: String, kind: String = "") -> int:
	return int((accounts.get(account, {}) as Dictionary).get(_field("rating", kind), START))


## Для карточки игрока: {rating, games, wins}. Новичок — START и нули.
func stats_of(account: String, kind: String = "") -> Dictionary:
	var entry: Dictionary = accounts.get(account, {})
	return {"rating": int(entry.get(_field("rating", kind), START)), "games": int(entry.get(_field("games", kind), 0)),
		"wins": int(entry.get(_field("wins", kind), 0))}


## Таблица лидеров (владелец, 2026-10-11): первые n по рейтингу (при равенстве —
## больше партий), registered — сколько тиранов сыграли хоть одну рейтинговую
## партию (только они и есть в accounts), mine — место account, если он там есть.
## team — та же таблица по рейтингу 2v2 (этап Team-5).
func leaderboard(n: int, account: String = "") -> Dictionary:
	var out := _table(n, account, "")
	out["registered"] = accounts.size()
	out["records"] = records.public_table()
	out["team"] = _table(n, account, TEAM)
	return out


## Первые n по рейтингу вида kind (только сыгравшие в нём хоть одну партию)
## и место account: {top, mine?}.
func _table(n: int, account: String, kind: String) -> Dictionary:
	var games := _field("games", kind)
	var order: Array = accounts.keys().filter(func(a): return int(accounts[a].get(games, 0)) > 0)
	order.sort_custom(func(a: String, b: String) -> bool:
		var ra := rating_of(a, kind)
		var rb := rating_of(b, kind)
		if ra != rb:
			return ra > rb
		return int(accounts[a].get(games, 0)) > int(accounts[b].get(games, 0)))
	var top := []
	for i in mini(n, order.size()):
		var row := stats_of(order[i], kind)
		row["name"] = String((accounts[order[i]] as Dictionary).get("name", ""))
		row["me"] = order[i] == account
		top.append(row)
	var out := {"top": top}
	var rank := order.find(account)
	if rank >= 0:
		out["mine"] = stats_of(account, kind)
		out["mine"]["rank"] = rank + 1
	return out


## 2 на 2 (этап Team-5): Эло команда на команду — рейтинг команды = среднее её
## игроков, оба союзника получают одно и то же изменение (K за партию, как
## один на один). teams — место -> команда, scores у союзников одинаковые.
static func team_elo_deltas(ratings: Dictionary, scores: Dictionary, teams: Dictionary) -> Dictionary:
	var sum := {}
	var count := {}
	var score := {}
	for seat in ratings:
		var t := String(teams[seat])
		sum[t] = float(sum.get(t, 0.0)) + float(ratings[seat])
		count[t] = int(count.get(t, 0)) + 1
		score[t] = int(scores[seat])
	var change := {}
	for t: String in sum:
		var mine := float(sum[t]) / float(count[t])
		var d := 0.0
		for o: String in sum:
			if o == t:
				continue
			var theirs := float(sum[o]) / float(count[o])
			var expected := 1.0 / (1.0 + pow(10.0, (theirs - mine) / 400.0))
			var actual := 0.5 if int(score[t]) == int(score[o]) else (1.0 if int(score[t]) > int(score[o]) else 0.0)
			d += K * (actual - expected)
		change[t] = roundi(d)
	var out := {}
	for seat in ratings:
		out[seat] = change[String(teams[seat])]
	return out


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
## winners — места победителей. Возвращает место -> {rating, delta, games,
## wins}. Партия не
## идёт в рейтинг ({}), если у кого-то нет учётной записи или один человек
## сидит за двумя цветами (два окна на одном компьютере).
## rated = false — партия из лобби (владелец, 2026-10-11): рейтинг, партии и
## победы не меняются, файл не трогается; итог несёт delta 0 и unrated.
func record(players: Dictionary, scores: Dictionary, winners: Array, rated := true,
		teams: Dictionary = {}) -> Dictionary:
	# 2 на 2 (этап Team-5): teams — место -> команда; свой рейтинг 2v2.
	var kind := TEAM if not teams.is_empty() else ""
	var seen := {}
	var ratings := {}
	for seat in players:
		var account := String(players[seat]["account"])
		if account == "" or seen.has(account):
			return {}
		seen[account] = true
		ratings[seat] = rating_of(account, kind)
	if not rated:
		var same := {}
		for seat in players:
			same[seat] = stats_of(String(players[seat]["account"]), kind)
			same[seat]["delta"] = 0
			same[seat]["unrated"] = true
			if kind != "":
				same[seat]["kind"] = kind
		return same
	var deltas := team_elo_deltas(ratings, scores, teams) if kind == TEAM else elo_deltas(ratings, scores)
	var out := {}
	for seat in players:
		var account := String(players[seat]["account"])
		var entry: Dictionary = accounts.get(account, {"rating": START, "games": 0, "wins": 0})
		entry["name"] = String(players[seat]["name"])
		entry[_field("rating", kind)] = int(ratings[seat]) + int(deltas[seat])
		entry[_field("games", kind)] = int(entry.get(_field("games", kind), 0)) + 1
		entry[_field("wins", kind)] = int(entry.get(_field("wins", kind), 0)) + (1 if winners.has(seat) else 0)
		accounts[account] = entry
		out[seat] = stats_of(account, kind)
		out[seat]["delta"] = deltas[seat]
		if kind != "":
			out[seat]["kind"] = kind
	save()
	return out
