extends RefCounted

## Display overlay only: BoardSchematic.site_box and rules retain English names.
const L10n := preload("res://scenes/localization.gd")
static var _ru: Dictionary = {}

static func translations() -> Dictionary:
	if _ru.is_empty():
		var file := FileAccess.open("res://data/localization/sites_ru.json", FileAccess.READ)
		_ru = JSON.parse_string(file.get_as_text())
	return _ru

static func name_of(original: String) -> String:
	return String(translations().get(original, {}).get("name", original)) if L10n.locale() == "ru" else original

static func short_name(original: String) -> String:
	return String(translations().get(original, {}).get("short_name", BoardSchematic.short_name(original))) if L10n.locale() == "ru" else BoardSchematic.short_name(original)

static func heading(original: String) -> String:
	return "%s (%s)" % [name_of(original).to_upper(), original] if L10n.locale() == "ru" else original.to_upper()
