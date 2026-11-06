extends RefCounted
## Owned UI captions only. Inputs, nicknames and chat are bound separately.
const L10n := preload("res://scenes/localization.gd")
const Cards := preload("res://scenes/card_text.gd")
const Terms := preload("res://scenes/term_text.gd")
static var _data: Dictionary = {}
static var _patterns: Array = []
static var _cards: Dictionary = {}
static var _keys: Dictionary = {}
static func _load() -> void:
 if not _data.is_empty(): return
 _data = JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/pages_ru.json"))
 _data.patterns.sort_custom(func(a, b): return String(a.source).replace("%s", "").replace("%d", "").length() > String(b.source).replace("%s", "").replace("%d", "").length())
 for item: Dictionary in _data.patterns:
  _patterns.append([RegEx.create_from_string(item.regex), item.target, item.get("translate", []).map(func(index): return int(index))])
 for cid: String in CardLibrary.all_ids():
  var source := String(CardLibrary.card_data(cid).name)
  _cards[source.to_upper()] = cid
 var en := L10n.catalog("en")
 for key: String in en:
  if not String(en[key]).contains("{") and not _keys.has(String(en[key])):
   _keys[String(en[key])] = key
static func text(source: String, depth: int = 0) -> String:
 if L10n.locale() != "ru" or source.is_empty() or depth > 6: return source
 _load()
 if _data.exact.has(source): return String(_data.exact[source])
 if _keys.has(source): return L10n.text(_keys[source])
 if source.begins_with(" "):
  return source.substr(0, source.length() - source.lstrip(" ").length()) + text(source.lstrip(" "), depth + 1)
 if source.ends_with("  ON"): return text(source.trim_suffix("  ON"), depth + 1) + "  ВКЛ"
 if source.contains("\n"):
  return "\n".join(Array(source.split("\n")).map(func(line): return text(line, depth + 1)))
 for item: Array in _patterns:
  var found: RegExMatch = item[0].search(source)
  if found == null: continue
  var values := {}
  for i in range(1, found.get_group_count() + 1):
   values["v%d" % (i - 1)] = text(found.get_string(i), depth + 1) if item[2].has(i - 1) else found.get_string(i)
  return String(item[1]).format(values)
 var price := RegEx.create_from_string("^(.+?)  ([0-9]+)$").search(source)
 if price != null: return text(price.get_string(1), depth + 1) + "  " + price.get_string(2)
 if _cards.has(source.to_upper()):
  var value := Cards.field(String(_cards[source.to_upper()]), "name")
  return value.to_upper() if source == source.to_upper() else value
 return Terms.name_of(source)
class BoundSource extends Node:
 var source := ""
 var property := "text"
 var literal_suffix := ""
 func refresh() -> void:
  if get_parent() != null:
   get_parent().set(property, load("res://scenes/page_text.gd").text(source) + literal_suffix)
static func bind(control: Control, source: String, property: String = "text", literal_suffix: String = "") -> void:
 var metadata := "_page_source_" + property
 var binding: BoundSource = control.get_meta(metadata) if control.has_meta(metadata) else null
 if binding == null:
  binding = BoundSource.new()
  control.add_child(binding)
  control.set_meta(metadata, binding)
  L10n.events.changed.connect(binding.refresh)
 elif binding.source == source and binding.property == property and binding.literal_suffix == literal_suffix:
  return
 binding.source = source
 binding.property = property
 binding.literal_suffix = literal_suffix
 if property == "text": control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
 binding.refresh()
