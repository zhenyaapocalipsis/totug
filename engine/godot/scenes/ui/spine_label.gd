class_name SpineLabel
extends Control

## «Корешок» колонки: полоса во всю высоту с надписью, повёрнутой на бок
## (читается снизу вверх), и линией-разделителем справа (решение владельца,
## 2026-09-28: MOVES у сводки ходов, DECKTRACKER у дектрекера). Надпись —
## у верхнего края полосы.

## Ширина полосы: поле, глиф высотой 7, поле и линия разделителя.
const WIDTH := 10
const GLYPH_H := 7
## Отступ надписи от верха полосы.
const TOP := 2

var text := ""


func _init(label: String = "") -> void:
	text = label
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_rect(Rect2(size.x - 1, 0, 1, size.y), PixelTheme.BORDER)
	var font := get_theme_font("font", "Label")
	var font_size := get_theme_font_size("font_size", "Label")
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# Повёрнутая строка идёт вверх от точки начала, а её базовая линия — это
	# вертикаль x = origin.x: заглавные (GLYPH_H над линией) ложатся левее неё,
	# в столбцы 1..GLYPH_H полосы.
	var origin := Vector2(1 + GLYPH_H, roundf(TOP + text_w))
	draw_set_transform(origin, -PI * 0.5)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		PixelTheme.TEXT_DIM)
	draw_set_transform(Vector2.ZERO)
