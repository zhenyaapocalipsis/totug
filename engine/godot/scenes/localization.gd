extends RefCounted

## Client presentation only. Stable keys never replace IDs in game state.
## Panels listen to events.changed and update text in place, preserving input.
class ChangeEvents extends RefCounted:
	signal changed

const SUPPORTED: Array[String] = ["en", "ru"]
static var events := ChangeEvents.new()
static var _locale := "en"
static var _catalogs: Dictionary = {}


static func locale() -> String:
	return _locale


static func normalize(value: String) -> String:
	return value if SUPPORTED.has(value) else "en"


static func set_locale(value: String) -> void:
	var next := normalize(value)
	var changed := next != _locale
	_locale = next
	TranslationServer.set_locale(next)
	if changed:
		events.changed.emit()


static func catalog(language: String) -> Dictionary:
	var code := normalize(language)
	if not _catalogs.has(code):
		var file := FileAccess.open("res://data/localization/%s.json" % code, FileAccess.READ)
		var data: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		if not data is Dictionary:
			push_error("Localization: invalid catalog %s" % code)
			data = {}
		_catalogs[code] = data
	return _catalogs[code]


static func text(key: String, parameters: Dictionary = {}) -> String:
	var english := catalog("en")
	var translated := String(catalog(_locale).get(key, english.get(key, key)))
	return translated.format(parameters) if not parameters.is_empty() else translated


static func language_name() -> String:
	return "Русский" if _locale == "ru" else "English"
