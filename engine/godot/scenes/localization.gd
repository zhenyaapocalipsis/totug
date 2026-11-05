extends RefCounted

## Client presentation only. Stable keys never replace IDs in game state.
## Panels listen to events.changed and update text in place, preserving input.
class ChangeEvents extends RefCounted:
	signal changed

const SUPPORTED: Array[String] = ["en", "ru"]
static var events := ChangeEvents.new()
static var _locale := "en"
static var _catalogs: Dictionary = {}
static var _native_ready := false


static func locale() -> String:
	return _locale


static func normalize(value: String) -> String:
	return value if SUPPORTED.has(value) else "en"


static func set_locale(value: String) -> void:
	_register_captions()
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
	var resolved := {}
	for name: String in parameters:
		var value: Variant = parameters[name]
		resolved[name] = text(value.l10n_key, value.get("parameters", {})) if value is Dictionary and value.has("l10n_key") else value
	return translated.format(resolved) if not resolved.is_empty() else translated


static func language_name() -> String:
	return "Русский" if _locale == "ru" else "English"


## Godot renders these captions without changing Control.text, IDs, callbacks,
## typed addresses, or selection state. Formatted server messages are handled separately.
static func _register_captions() -> void:
	if _native_ready:
		return
	_native_ready = true
	var english := catalog("en")
	for language: String in SUPPORTED:
		var translation := Translation.new()
		translation.locale = language
		var translated := catalog(language)
		for key: String in english:
			if key.begins_with("setup.") or key.begins_with("profile.") or key.begins_with("lobby.caption."):
				translation.add_message(StringName(english[key]), StringName(translated.get(key, english[key])))
		TranslationServer.get_or_add_domain(&"ui_captions").add_translation(translation)


static func scope(control: Node) -> void:
	control.set_translation_domain(&"ui_captions")


class BoundText extends Node:
	var key := ""
	var parameters: Dictionary = {}
	var property := "text"
	var render: Callable
	func refresh() -> void:
		if get_parent() != null and render.is_valid():
			get_parent().set(property, render.call())


static func bind(control: Control, key: String, parameters: Dictionary = {}, property: String = "text") -> void:
	var metadata := "_localized_" + property
	var binding: BoundText = control.get_meta(metadata) if control.has_meta(metadata) else null
	if binding == null:
		binding = BoundText.new()
		control.add_child(binding)
		events.changed.connect(binding.refresh)
		control.set_meta(metadata, binding)
	binding.key = key
	binding.parameters = parameters.duplicate(true)
	binding.property = property
	binding.render = text.bind(key, binding.parameters)
	if property == "text":
		control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	binding.refresh()
