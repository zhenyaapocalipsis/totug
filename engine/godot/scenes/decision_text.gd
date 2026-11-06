extends RefCounted

## Translate legacy decision captions at the presentation edge only.
## Source prompts, answers and replay/network payloads stay unchanged.
const L10n := preload("res://scenes/localization.gd")
const Terms := preload("res://scenes/term_text.gd")
const Cards := preload("res://scenes/card_text.gd")
const Sites := preload("res://scenes/site_text.gd")
const Players := preload("res://scenes/game_text.gd")
static var _data: Dictionary = {}
static var _patterns: Array = []
static var _names: Dictionary = {}
static var _english: Dictionary = {}

static func _load() -> void:
	if not _data.is_empty():
		return
	var file := FileAccess.open("res://data/localization/decisions_ru.json", FileAccess.READ)
	_data = JSON.parse_string(file.get_as_text())
	# Prefer a known literal prefix over a generic leading placeholder.
	_data.patterns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ap := not String(a.source).begins_with("%")
		var bp := not String(b.source).begins_with("%")
		if ap != bp: return ap
		return String(a.source).replace("%s", "").replace("%d", "").length() > String(b.source).replace("%s", "").replace("%d", "").length())
	for entry: Dictionary in _data.patterns:
		_patterns.append([RegEx.create_from_string(entry.regex), entry.target])
	for cid: String in CardLibrary.all_ids():
		_names[String(CardLibrary.card_data(cid).get("name", ""))] = cid

static func text(source: String, depth: int = 0) -> String:
	if source == "" or depth > 6:
		return source
	if L10n.locale() != "ru":
		if _english.is_empty():
			_english = JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/decisions_en.json"))
		return Cards.option_field(source, "text", String(_english.get(source, source)))
	_load()
	# A custom nickname is literal, even when it matches a game word.
	for pid: String in ["red", "blue", "green", "orange", "purple", "yellow", "white"]:
		var own := PlayerProfile.name_of(pid)
		if depth > 0 and own != "" and (source == own or source == own.to_upper()):
			return source
	if _data.exact.has(source):
		return String(_data.exact[source])
	var option := Cards.option_field(source, "text", source)
	if option != source:
		return option
	if Sites.translations().has(source):
		return Sites.name_of(source)
	if _names.has(source):
		return Cards.field(String(_names[source]), "name")
	var term := Terms.name_of(source)
	if term != source:
		return term
	for pid: String in ["red", "blue", "green", "orange", "purple", "yellow", "white"]:
		if source == EventLogPanel.player_name(pid):
			return Players.player_name(pid)
		if source == EventLogPanel.player_name(pid).to_upper():
			var message := Players.player_message(pid, true)
			return L10n.text(message.l10n_key, message.get("parameters", {}))
	for entry: Array in _patterns:
		var found: RegExMatch = entry[0].search(source)
		if found == null:
			continue
		var values := {}
		for i in range(1, found.get_group_count() + 1):
			values["v%d" % (i - 1)] = text(found.get_string(i), depth + 1)
		return String(entry[1]).format(values)
	if source.contains(" — "):
		var parts := source.split(" — ")
		for i in parts.size():
			parts[i] = text(parts[i], depth + 1)
		return " — ".join(parts)
	return source

class BoundText extends Node:
	var source := ""
	var property := "text"
	func refresh() -> void:
		if get_parent() != null:
			get_parent().set(property, load("res://scenes/decision_text.gd").text(source))

static func bind(control: Control, source: String, property: String = "text") -> void:
	var metadata := "_decision_source_" + property
	var binding: BoundText = control.get_meta(metadata) if control.has_meta(metadata) else null
	if binding == null:
		binding = BoundText.new()
		control.add_child(binding)
		L10n.events.changed.connect(binding.refresh)
		control.set_meta(metadata, binding)
	binding.source = source
	binding.property = property
	if property == "text":
		control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	binding.refresh()
