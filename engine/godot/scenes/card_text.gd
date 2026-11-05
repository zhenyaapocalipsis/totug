extends RefCounted

## Presentation overlay. Never return translated data to CardLibrary/rules.
const L10n := preload("res://scenes/localization.gd")
static var _ru: Dictionary = {}
static var _loaded := false
const KEYWORDS := {"ПОГЛОТИТЕ":"DEVOUR", "ЗАМЕНИТЕ":"SUPPLANT", "РАЗМЕСТИТЕ":"DEPLOY",
	"УНИЧТОЖЬТЕ":"ASSASSINATE", "ВЕРНИТЕ":"RETURN", "ВОЗВЫСЬТЕ":"PROMOTE",
	"НАЙМИТЕ":"RECRUIT", "КОНЦЕНТРАЦИЯ":"FOCUS", "РВЕНИЕ":"DEVOTION", "ЧАРЫ":"GLAMOUR",
	"ПРЕВРАЩЕНИЕ":"TRANSFORM"}


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


static func notes(cid: String, original: Array) -> Array:
	var result := original.duplicate(true)
	for note: Dictionary in result:
		# Older peers/replays supply phrase only. Upgrade at the presentation edge.
		if not note.has("id"):
			for rule: Array in CardLive.RULES.get(cid, []):
				if note.get("phrase", "") == rule[0]:
					note["id"] = CardLive.hint_id(cid, rule)
					break
		if translated(cid) and ["(YES)", "(NO)"].has(note.get("text", "")):
			note["text"] = "(ДА)" if note["ok"] else "(НЕТ)"
	return result


static func keyword(word: String) -> String:
	var bare := word.to_upper().rstrip(".,:;")
	return String(KEYWORDS.get(bare, bare))


const OPTION_IDS := {"+2 Influence": "gain_influence_2",
	"At end of turn, promote another card played this turn": "promote_other_at_end",
	"Place a spy": "place_spy",
	"Return one of your spies -> Recruit up to 2 cards that cost 3 or less": "return_spy_recruit_2_max3"}
static var _options: Dictionary = {}


static func option_id(source: String) -> String:
	return String(OPTION_IDS.get(source, source))


static func option_field(source: String, key: String, fallback: String) -> String:
	if L10n.locale() != "ru":
		return fallback
	if _options.is_empty():
		var file := FileAccess.open("res://data/localization/options_ru.json", FileAccess.READ)
		var data: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		_options = data if data is Dictionary else {}
	return String(_options.get(option_id(source), {}).get(key, fallback))
