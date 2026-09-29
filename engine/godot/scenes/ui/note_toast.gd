class_name NoteToast
extends PanelContainer

## Подсказка внизу доски, над счётчиками Power/Influence: «не та цель»,
## «время вышло», «игрок отключился».
## Раньше такие строки писались в журнал, но журнал убран (решение владельца,
## 2026-09-27) — теперь строка всплывает на пару секунд и гаснет. Новая
## подсказка сразу заменяет старую. Мышь не ловит.

const HOLD_TIME := 2.6
const OUT_TIME := 0.4
## Зазор до плашки счётчиков.
const GAP := 2.0

## Зона доски (ширина и центр) и плашка счётчиков: подсказка встаёт над ней.
var area: Control
var above: Control

var _label: Label
var _tween: Tween
var _text := ""


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Над баннером хода (960), под диалогами (999+).
	z_index = 970
	add_theme_stylebox_override("panel", PixelTheme.box(PixelTheme.PANEL, PixelTheme.GOLD, 1, 6, 3))
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", PixelTheme.TEXT)
	add_child(_label)


func show_note(text: String) -> void:
	_text = text
	_label.text = text
	if _tween != null:
		_tween.kill()
	# Место считаем кадром позже: в первый кадр партии доска ещё не
	# разложена. До того подсказка не видна.
	_place.call_deferred()
	_tween = create_tween()
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, OUT_TIME)
	_tween.tween_callback(func(): visible = false)


## Одна строка, если влезает в ширину доски; длинная переносится.
## Переносим сами, по словам: автоперенос Label в скрытой плашке считал строки
## по старой узкой ширине — по слову на строку, и плашка вырастала на весь экран.
func _place() -> void:
	if area == null:
		return
	var rect := Rect2(area.position, area.size)
	var room := maxf(rect.size.x - 24.0, 120.0)
	_label.text = _wrap(_text.replace("\n", " "), room)
	_label.size = Vector2.ZERO
	size = Vector2.ZERO  # ужаться под новую надпись
	var box := get_combined_minimum_size()
	var bottom := above.position.y if above != null else rect.end.y
	position = Vector2(rect.position.x + (rect.size.x - box.x) * 0.5, bottom - GAP - box.y).round()
	modulate.a = 1.0
	visible = true


## Разбивает текст на строки не шире room (слово длиннее строки — отдельной строкой).
func _wrap(text: String, room: float) -> String:
	var font := _label.get_theme_font("font")
	var fs := _label.get_theme_font_size("font_size")
	var lines: PackedStringArray = []
	var line := ""
	for word in text.split(" ", false):
		var probe := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 1.0 > room:
			lines.append(line)
			line = word
		else:
			line = probe
	if line != "":
		lines.append(line)
	return "\n".join(lines)


## Для проверок: текст последней подсказки (без переносов строк).
func last_text() -> String:
	return _text
