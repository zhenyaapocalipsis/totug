extends PanelContainer

## Баннер «YOUR TURN» / «BLUE'S TURN» по центру доски на секунду с небольшим
## (решение владельца, 2026-09-27: игроки не замечали, что начался их ход).
## Полоса в цвет игрока выезжает слева, стоит и гаснет. Мышь не ловит — под
## ним можно сразу щёлкать по доске.
##
## Надпись — шрифтом вчетверо (целый масштаб, пиксели не мылятся). Сдвиг при
## выезде округляется до целых пикселей.

const L10n := preload("res://scenes/localization.gd")

const FONT_SIZE := PixelTheme.SIZE * 4
const SLIDE := 24.0
const IN_TIME := 0.15
const HOLD_TIME := 0.9
const OUT_TIME := 0.35

var _message: Dictionary = {}
var _area := Rect2()
var _slide_t := 0.0
var _label: Label
var _style: StyleBoxFlat
var _tween: Tween
var _home := Vector2.ZERO


func _init() -> void:
	L10n.events.changed.connect(_refresh_language)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Над витриной чужих покупок (950), под диалогами (999+).
	z_index = 960
	_style = PixelTheme.box(PixelTheme.PANEL, PixelTheme.GOLD, 2, 16, 4)
	add_theme_stylebox_override("panel", _style)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_outline_color", PixelTheme.BG)
	add_child(_label)


## Показать надпись по центру прямоугольника area (в координатах родителя).
func show_turn(text: String, colour: Color, area: Rect2) -> void:
	_message = {}
	_show_text(text, colour, area)


func show_message(message: Dictionary, colour: Color, area: Rect2) -> void:
	_message = message.duplicate(true)
	_show_text(L10n.text(message.l10n_key, message.get("parameters", {})), colour, area)


func _show_text(text: String, colour: Color, area: Rect2) -> void:
	_area = area
	_set_caption(text)
	_label.add_theme_color_override("font_color", colour)
	_style.border_color = colour
	size = Vector2.ZERO  # ужаться под новую надпись
	var box := get_combined_minimum_size()
	_home = (area.position + (area.size - box) * 0.5).round()
	if _tween != null:
		_tween.kill()
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_method(_step_in, 0.0, 1.0, IN_TIME)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, OUT_TIME)
	_tween.tween_callback(func(): visible = false)


func _step_in(t: float) -> void:
	_slide_t = t
	modulate.a = t
	position = (_home - Vector2(SLIDE * (1.0 - t), 0)).round()


func _set_caption(text: String) -> void:
	var font := _label.get_theme_font("font")
	var room := maxf(_area.size.x - 36.0, 80.0)
	var lines: Array[String] = []
	var line := ""
	for word in text.split(" ", false):
		var next := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x > room:
			lines.append(line)
			line = word
		else:
			line = next
	lines.append(line)
	_label.text = "\n".join(lines)


func _refresh_language() -> void:
	if _message.is_empty():
		return
	_set_caption(L10n.text(_message.l10n_key, _message.get("parameters", {})))
	_recenter.call_deferred()


func _recenter() -> void:
	if not visible:
		return
	size = Vector2.ZERO
	_home = (_area.position + (_area.size - get_combined_minimum_size()) * 0.5).round()
	position = (_home - Vector2(SLIDE * (1.0 - _slide_t), 0)).round()
