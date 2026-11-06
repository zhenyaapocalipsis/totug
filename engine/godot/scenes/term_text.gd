extends RefCounted
## System metadata only. Never apply to user names, chat or saved answers.
const L10n := preload("res://scenes/localization.gd")
static var _ru: Dictionary = {}
static var _races: Dictionary = {}
static var _regions: Dictionary = {}
static func catalog() -> Dictionary:
 if _ru.is_empty():
  _ru = JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/terms_ru.json"))
 return _ru
static func name_of(source: String, language: String = "", kind: String = "") -> String:
 if (L10n.locale() if language.is_empty() else language) != "ru":
  return source
 var key := source.to_upper()
 var entries := catalog()
 if kind == "race":
  if _races.is_empty(): _races = JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/races_ru.json"))
  entries = _races
 elif kind == "region":
  if _regions.is_empty(): _regions = JSON.parse_string(FileAccess.get_file_as_string("res://data/localization/regions_ru.json"))
  entries = _regions
 var value := String(entries.get(key, source))
 if value == source:
  return source
 if source == source.to_upper(): return value.to_upper()
 if source == source.to_lower(): return value.to_lower()
 return value
static func search_text(source: String, kind: String = "") -> String:
 return source + " " + name_of(source, "ru", kind)
