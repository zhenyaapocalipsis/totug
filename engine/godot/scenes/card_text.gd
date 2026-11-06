extends RefCounted

## Presentation overlay. Never return translated data to CardLibrary/rules.
const L10n := preload("res://scenes/localization.gd")
static var _ru: Dictionary = {}
static var _loaded := false
const KEYWORDS := {"ПОГЛОТИТЬ":"DEVOUR", "ЗАМЕНИТЬ":"SUPPLANT", "РАЗМЕСТИТЬ":"DEPLOY",
	"УНИЧТОЖИТЬ":"ASSASSINATE", "ВЕРНУТЬ":"RETURN", "ВОЗВЫСИТЬ":"PROMOTE",
	"НАНЯТЬ":"RECRUIT", "ПЕРЕМЕСТИТЬ":"MOVE", "ПОГЛОТИТЕ":"DEVOUR", "ЗАМЕНИТЕ":"SUPPLANT", "РАЗМЕСТИТЕ":"DEPLOY",
	"УНИЧТОЖЬТЕ":"ASSASSINATE", "ВЕРНИТЕ":"RETURN", "ВОЗВЫСЬТЕ":"PROMOTE",
	"НАЙМИТЕ":"RECRUIT", "НАНИМАЕТ":"RECRUITS", "НАНИМАЮТ":"RECRUITS", "КОНЦЕНТРАЦИЯ":"FOCUS", "КОНЦЕНТРАЦИИ":"FOCUS", "КОНЦЕНТРАЦИЕЙ":"FOCUS", "РВЕНИЕ":"DEVOTION", "РВЕНИЯ":"DEVOTION", "РВЕНИИ":"DEVOTION", "ЧАРЫ":"GLAMOUR",
	"ПРЕВРАЩЕНИЕ":"TRANSFORM", "ПРЕВРАТИТЕ":"TRANSFORM", "ПРЕВРАТИТЬ":"TRANSFORM",
	"ПЕРЕМЕСТИТЕ":"MOVE", "ПОДКУП":"BRIBE", "УКРАДИТЕ":"STEAL",
	"ПРЕДВИДЕНИЕ":"SCRY", "ПРЕДВИДЕНИЕМ":"SCRY", "МОЩЬ":"MIGHT", "МОЩИ":"MIGHT", "ОБМОРОЖЕНИЕ":"FROSTBITE", "ОБМОРОЖЕНИЯ":"FROSTBITE", "ОБМОРОЖЕНИИ":"FROSTBITE",
	"РАЗЛИЧНЫЙ":"DISTINCT", "РАЗЛИЧНЫЕ":"DISTINCT", "РАЗЛИЧНЫХ":"DISTINCT", "УДЕРЖИТЕ":"RETAIN", "УДЕРЖАТЬ":"RETAIN",
	"УДЕРЖАНО":"RETAINED", "УДЕРЖАННУЮ":"RETAINED", "УДЕРЖАНИЕ":"RETAIN", "УДЕРЖАНИИ":"RETAIN", "УДЕРЖАНИЯ":"RETAIN", "ИССЛЕДОВАНИЕ":"EXPLORE", "ИССЛЕДУЙТЕ":"EXPLORE"}


static func translations() -> Dictionary:
	if not _loaded:
		var file := FileAccess.open("res://data/localization/cards_ru.json", FileAccess.READ)
		var data: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		_ru = data if data is Dictionary else {}
		_loaded = true
	return _ru


static func translated(cid: String) -> bool:
	return L10n.locale() == "ru" and translations().has(cid)


static func field(cid: String, key: String) -> String:
	if translated(cid) and translations()[cid].has(key):
		return String(translations()[cid][key])
	return String(CardLibrary.card_data(cid).get(key, ""))


static func ability(cid: String, markers: bool = false) -> String:
	var raw := field(cid, "ability_text")
	return raw if markers else RegEx.create_from_string("\\{LIVE:[^}]+\\}").sub(raw, "", true)


static func source_notes(cid: String, original: Array) -> Array:
	var result := original.duplicate(true)
	for note: Dictionary in result:
		# Older peers use a phrase; newer records may contain only the stable ID.
		for rule: Array in CardLive.RULES.get(cid, []):
			var id := CardLive.hint_id(cid, rule)
			if not note.has("id") and note.get("phrase", "") == rule[0]:
				note["id"] = id
			if not note.has("phrase") and note.get("id", "") == id:
				note["phrase"] = rule[0]
	return result


static func notes(cid: String, original: Array) -> Array:
	var result := source_notes(cid, original)
	for note: Dictionary in result:
		if translated(cid) and ["(YES)", "(NO)"].has(note.get("text", "")):
			note["text"] = "(ДА)" if note["ok"] else "(НЕТ)"
	return result


static func keyword(word: String) -> String:
	var bare := word.to_upper().rstrip(".,:;")
	return String(KEYWORDS.get(bare, bare))


const OPTION_IDS := {"+1 Influence": "gain_influence_1", "Promote another card in your hand": "promote_other_in_hand",
	"+2 Influence": "gain_influence_2",
	"At end of turn, promote another card played this turn": "promote_other_at_end",
	"Place a spy": "place_spy",
	"Return one of your spies -> Recruit up to 2 cards that cost 3 or less": "return_spy_recruit_2_max3"}
static var _options: Dictionary = {}
static var _english_options: Dictionary = {}


static func option_id(source: String) -> String:
	return String(OPTION_IDS.get(source, "option_" + source.sha256_text().substr(0, 12)))


static func option_field(source: String, key: String, fallback: String) -> String:
	if L10n.locale() != "ru":
		if _english_options.is_empty():
			var file := FileAccess.open("res://data/localization/options_en.json", FileAccess.READ)
			var data: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
			_english_options = data if data is Dictionary else {}
		return String(_english_options.get(option_id(source), {}).get(key, fallback))
	if _options.is_empty():
		var file := FileAccess.open("res://data/localization/options_ru.json", FileAccess.READ)
		var data: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		_options = data if data is Dictionary else {}
	return String(_options.get(option_id(source), {}).get(key, fallback))


static var _copies: Dictionary = {}


static func copy_count(cid: String) -> int:
	if _copies.is_empty():
		var file := FileAccess.open("res://data/cards/half_decks.json", FileAccess.READ)
		var data: Dictionary = JSON.parse_string(file.get_as_text())
		for deck: Dictionary in data.half_decks.values():
			for id: String in deck.copies:
				_copies[id] = int(deck.copies[id])
	return int(_copies.get(cid, 0))


static func copy_label(count: int) -> String:
	var ending := "КОПИЙ"
	if count % 100 < 11 or count % 100 > 14:
		if count % 10 == 1:
			ending = "КОПИЯ"
		elif count % 10 >= 2 and count % 10 <= 4:
			ending = "КОПИИ"
	return "%d %s" % [count, ending]
