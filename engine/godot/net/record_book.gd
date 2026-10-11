class_name RecordBook
extends RefCounted

## Мировые рекорды (владелец, 2026-10-11). Рекорд держит тот, кто ПЕРВЫМ
## поставил значение: повтор его не отбирает, побить можно только строго
## лучшим. Засчитывается только партия поиска игры (рейтинговая), и только
## тому, кто в ней победил. Отдельные таблицы для 2, 3 и 4 игроков.
## Ведёт выделенный сервер, файл рядом с рейтингами (RatingBook).

## [ключ, подпись, меньше — лучше].
const KINDS := [
	["vp", "MOST VP", false],
	["best_turn", "BEST TURN, VP", false],
	["kills", "ASSASSINATIONS", false],
	["supplants", "SUPPLANTS", false],
	["spies", "SPIES PLACED", false],
	["bought", "CARDS BOUGHT", false],
	["devoured", "CARDS DEVOURED", false],
	["promoted", "CARDS PROMOTED", false],
	["rounds", "FASTEST WIN, ROUNDS", true],
	["margin", "BIGGEST LEAD, VP", false],
]

## "2"/"3"/"4" (и "2v2" — этап Team-5) -> ключ -> {value, name, account, date}.
var table: Dictionary = {}
var _path := ""


func _init(path: String) -> void:
	_path = path
	table = RatingBook._read(path)


func save() -> void:
	RatingBook._write(_path, table)


## Показатели игрока seat в партии: stats — ReplayStats.collect, scores —
## место -> итоговые VP.
static func measure(stats: Dictionary, seat: String, scores: Dictionary) -> Dictionary:
	var counts: Dictionary = stats["counts"][seat]
	var supplants := int((stats.get("supplants", {}) as Dictionary).get(seat, 0))
	var turns: Array = stats["turns"]
	var best := 0
	for t in range(1, turns.size()):
		if String(turns[t]["player"]) == seat:
			best = maxi(best, int(turns[t]["vp"].get(seat, 0)) - int(turns[t - 1]["vp"].get(seat, 0)))
	var second := -1000000
	for pid in scores:
		if pid != seat:
			second = maxi(second, int(scores[pid]))
	return {
		"vp": int(scores[seat]),
		"best_turn": best,
		"kills": int(counts.get("kills", 0)) - supplants,
		"supplants": supplants,
		"spies": int(counts.get("spies", 0)),
		"bought": int(counts.get("bought", 0)),
		"devoured": int(counts.get("devoured", 0)),
		"promoted": int(counts.get("promoted", 0)),
		"rounds": int(turns.back()["round"]) if not turns.is_empty() else 0,
		"margin": int(scores[seat]) - second if scores.size() > 1 else 0,
	}


## Сверить показатели победителя с таблицей; вернуть ключи побитых рекордов.
## Нули рекордом не считаются (0 убийств — не достижение, 0 раундов не бывает).
func submit(players: Variant, account: String, player_name: String, values: Dictionary) -> Array[String]:
	var key := str(players)
	var row: Dictionary = table.get(key, {})
	var broken: Array[String] = []
	for kind: Array in KINDS:
		var id := String(kind[0])
		var value := int(values.get(id, 0))
		if value <= 0:
			continue
		if row.has(id):
			var old := int(row[id]["value"])
			if (value >= old) if bool(kind[2]) else (value <= old):
				continue
		row[id] = {"value": value, "name": player_name, "account": account,
			"date": Time.get_date_string_from_system()}
		broken.append(id)
	if not broken.is_empty():
		table[key] = row
		save()
	return broken


## Таблица для клиентов — без учётных записей.
func public_table() -> Dictionary:
	var out := {}
	for key: String in table:
		var row := {}
		for id: String in table[key]:
			var r: Dictionary = table[key][id]
			row[id] = {"value": int(r["value"]), "name": String(r["name"]), "date": String(r["date"])}
		out[key] = row
	return out


## Сколько рекордов (по всем столам) сейчас держит учётная запись.
func held_by(account: String) -> int:
	var n := 0
	for key: String in table:
		for id: String in table[key]:
			if String(table[key][id].get("account", "")) == account:
				n += 1
	return n


static func label_of(id: String) -> String:
	for kind: Array in KINDS:
		if kind[0] == id:
			return String(kind[1])
	return id
