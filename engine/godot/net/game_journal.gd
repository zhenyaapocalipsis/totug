class_name GameJournal
extends RefCounted

## Сохранение партии на диске для переподключения и перезапуска сервера
## (этап 7). Полный GameState не сериализуем (это дерево GDScript-объектов,
## а не Dictionary) — вместо этого храним заголовок партии (сид, состав,
## режим, профили) и список принятых Intent'ов по порядку. Восстановление =
## GameSetup.new_game() с тем же сидом + apply_intent() каждой строки подряд:
## RNG партии детерминирован (state.rng), поэтому повторный розыгрыш собирает
## бит-в-бит то же состояние, что было (см. GameRoom.restore).
##
## Один файл на комнату, целиком перезаписывается после каждого хода — как
## RatingBook.save(). Партии на 4 игроков редко длиннее пары сотен ходов,
## так что файл всегда маленький и перезапись не заметна.
##
## dir — папка с сохранениями; параметр, а не только константа DIR, чтобы
## сетевой тест мог подставить свою и не трогать настоящие сохранения
## владельца (см. NetSession.saves_dir, RatingBook — тот же приём для рейтинга).

const DIR := "user://saves/"


static func path_for(code: String, dir: String = DIR) -> String:
	return dir + code + ".json"


static func save(code: String, header: Dictionary, intents: Array, dir: String = DIR) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path_for(code, dir), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"header": header, "intents": intents}))


## {} — файла нет или он повреждён.
static func load_game(code: String, dir: String = DIR) -> Dictionary:
	var f := FileAccess.open(path_for(code, dir), FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("header") or not parsed.has("intents"):
		return {}
	return parsed


static func erase(code: String, dir: String = DIR) -> void:
	var p := path_for(code, dir)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)


## Коды всех сохранённых партий (для восстановления на старте выделенного
## сервера).
static func list_codes(dir: String = DIR) -> Array[String]:
	var codes: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return codes
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.ends_with(".json"):
			codes.append(name.get_basename())
		name = d.get_next()
	d.list_dir_end()
	return codes
