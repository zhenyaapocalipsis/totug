extends RefCounted

## Патчноуты для вкладки NEWS главного меню — заголовки коммитов git по
## дням, свежие сверху (владелец, 2026-10-06).
##
## В собранной игре git нет, поэтому список лежит файлом FILE (.json — такие
## файлы попадают в сборку сами). Игра, запущенная из исходников (редактор,
## тесты), спрашивает git и переписывает файл, если в нём что-то поменялось.

const FILE := "res://data/patch_notes.json"

## Один раз за запуск: git отвечает не мгновенно.
static var _cache: Array = []


## [{"date": "2026-10-05", "text": "..."}, ...], свежие сверху.
static func entries() -> Array:
	if not _cache.is_empty():
		return _cache
	if not OS.has_feature("template"):
		_cache = from_git()
		if not _cache.is_empty():
			_save(_cache)
			return _cache
	_cache = _load()
	return _cache


static func from_git() -> Array:
	var out: Array = []
	var dir := ProjectSettings.globalize_path("res://")
	var code := OS.execute("git", ["-C", dir, "log", "--no-merges", "--date=short",
		"--pretty=format:%ad%x09%s"], out)
	if code != 0 or out.is_empty():
		return []
	return parse(String(out[0]))


## Строки «дата<Tab>заголовок» в записи.
static func parse(text: String) -> Array:
	var list: Array = []
	for line in text.split("\n", false):
		var parts := line.strip_edges().split("\t", true, 1)
		if parts.size() == 2 and parts[1] != "":
			list.append({"date": parts[0], "text": parts[1]})
	return list


## Текст для RichTextLabel: дата золотом, под ней коммиты этого дня.
static func bbcode(list: Array) -> String:
	var out := PackedStringArray()
	var day := ""
	for entry: Dictionary in list:
		if String(entry["date"]) != day:
			day = String(entry["date"])
			if not out.is_empty():
				out.append("")
			out.append("[color=#%s]%s[/color]" % [PixelTheme.GOLD.to_html(false), day])
		out.append("- " + String(entry["text"]).replace("[", "[lb]"))
	return "\n".join(out)


static func _load() -> Array:
	if not FileAccess.file_exists(FILE):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return data if data is Array else []


static func _save(list: Array) -> void:
	var text := JSON.stringify(list, "\t")
	if FileAccess.file_exists(FILE) and FileAccess.get_file_as_string(FILE) == text:
		return
	var file := FileAccess.open(FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
