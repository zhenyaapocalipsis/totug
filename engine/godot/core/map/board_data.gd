class_name BoardData
extends RefCounted

## Загрузка данных доски из data/board/*.json.
## Файлы порождаются tools/extract_board_data.py из Lua-скрипта мода TTS —
## руками их не правят, правят экстрактор.

const BASE_PATH := "res://data/board/"

static func _load_json(file_name: String) -> Variant:
	var path := BASE_PATH + file_name
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("не удалось прочитать " + path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("не удалось разобрать JSON: " + path)
	return parsed


static func load_all() -> Dictionary:
	return {
		"sites": _load_json("site_data.json"),
		"routes": _load_json("route_slots.json"),
		"edges": _load_json("hex_edges.json"),
		"layouts": _load_json("layouts.json"),
		"markers": _load_json("markers.json"),
		# Смежность внутри гексов размечена вручную по печатному арту —
		# геометрически и автоматически по картинке она не выводится,
		# см. claude/art-verification.md
		"manual": _load_json("manual_adjacency.json"),
	}


static func make_builder() -> BoardBuilder:
	var data := load_all()
	return BoardBuilder.new(data["sites"], data["routes"], data["edges"], data["layouts"],
		data["manual"] if data["manual"] != null else {})
