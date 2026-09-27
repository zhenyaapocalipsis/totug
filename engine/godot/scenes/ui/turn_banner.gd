extends PanelContainer

## Баннер «YOUR TURN» / «BLUE'S TURN» по центру доски на секунду с небольшим
## (решение владельца, 2026-09-27: игроки не замечали, что начался их ход).
## Полоса в цвет игрока выезжает слева, стоит и гаснет. Мышь не ловит — под
## ним можно сразу щёлкать по доске.
##
## Надпись — шрифтом вчетверо (целый масштаб, пиксели не мылятся). Сдвиг при
## выезде округляется до целых пикселей.

const FONT_SIZE := PixelTheme.SIZE * 4
const SLIDE := 24.0
const IN_TIME := 0.15
const HOLD_TIME := 0.9
const OUT_TIME := 0.35

var _label: Label
var _style: StyleBoxFlat
var _tween: Tween
var _home := Vector2.ZERO


func _init() -> void:
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
	_label.text = text
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
	modulate.a = t
	position = (_home - Vector2(SLIDE * (1.0 - t), 0)).round()
