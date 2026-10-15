class_name ProfileBook
extends RefCounted

## Профили игроков на сервере (владелец, 2026-10-15): чтобы смотреть чужой
## профиль — средние VP по статьям (многоугольник) и последние партии с
## реплеями. Свой профиль игрок по-прежнему ведёт у себя (PlayerProfile);
## здесь та же строка истории (PlayerProfile.history_entry) и те же суммы
## (PlayerProfile.merge_totals), только для каждой учётной записи.
## Копится с выкладки сервера, старые партии сюда не попадают.
##
## Файл рядом с рейтингами (ratings_profiles.json):
## учётная запись -> {totals: {...}, games: [строки истории, новые первыми]}.

## Сколько последних партий сервер помнит за игроком.
const HISTORY_MAX := 30

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
	person["games"] = games.slice(0, HISTORY_MAX)
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
