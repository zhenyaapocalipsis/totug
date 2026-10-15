class_name RadarChart
extends Control

## Многоугольник средних, как в профиле Dota 2 (владелец, 2026-10-15): шесть
## осей — средние VP за партию по статьям (PlayerProfile.VP_PARTS), первая ось
## смотрит вверх, дальше по часовой. Один или два игрока сразу (свой и чужой
## профиль — для сравнения), у каждого свой цвет. У подписи оси — числа
## игроков их цветами.
##
## Шкала одна на все оси — 0..SCALE VP (владелец, 2026-10-16): видно, откуда
## берутся очки. Если чьё-то среднее больше SCALE, шкала всех осей растёт до
## него — многоугольник не вылезает за сетку.

const AXES := PlayerProfile.VP_PARTS
const LABELS := {"sites": "SITES", "total_control": "CONTROL", "trophies": "TROPHIES",
	"deck": "DECK", "inner_circle": "INNER", "tokens": "TOKENS"}
const SCALE := 25.0
const RADIUS := 54.0
## Колец сетки (доли масштаба).
const RINGS := 3
## Подпись дальше вершины на столько пикселей.
const LABEL_GAP := 5.0
## Место под подписи вокруг многоугольника.
const MARGIN := Vector2(64, 28)

## [{values: ключ -> среднее, colour}]
var _series: Array = []


func _init() -> void:
	custom_minimum_size = (Vector2.ONE * RADIUS + MARGIN) * 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## values — PlayerProfile.averages(); первым — тот, кто рисуется снизу.
func add_series(values: Dictionary, colour: Color) -> void:
	_series.append({"values": values, "colour": colour})
	queue_redraw()


## Общая шкала всех осей: SCALE или самое большое среднее, если оно больше.
func _scale() -> float:
	var top := SCALE
	for s: Dictionary in _series:
		for key: String in AXES:
			top = maxf(top, float((s["values"] as Dictionary).get(key, 0.0)))
	return top


## Направление оси i: первая вверх, по часовой.
static func _dir(i: int) -> Vector2:
	var angle := -PI / 2.0 + TAU * i / AXES.size()
	return Vector2(cos(angle), sin(angle))


func _draw() -> void:
	var centre := (size / 2.0).floor()
	for ring in range(1, RINGS + 1):
		var points := PackedVector2Array()
		for i in AXES.size():
			points.append((centre + _dir(i) * RADIUS * ring / RINGS).round())
		points.append(points[0])
		draw_polyline(points, PixelTheme.BORDER if ring < RINGS else PixelTheme.BORDER_HI)
	for i in AXES.size():
		draw_line(centre, (centre + _dir(i) * RADIUS).round(), PixelTheme.BORDER)
	var full := _scale()
	for s: Dictionary in _series:
		var points := PackedVector2Array()
		for i in AXES.size():
			var key: String = AXES[i]
			var share := float((s["values"] as Dictionary).get(key, 0.0)) / full
			points.append((centre + _dir(i) * RADIUS * clampf(share, 0.0, 1.0)).round())
		var colour: Color = s["colour"]
		if _polygon_ok(points):
			draw_colored_polygon(points, Color(colour, 0.28))
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, colour)
		for p in points:
			draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)), colour)
	_draw_labels(centre)


## Нулевые оси схлопывают многоугольник — заливку тогда не рисуем.
static func _polygon_ok(points: PackedVector2Array) -> bool:
	return not Geometry2D.triangulate_polygon(points).is_empty()


## Подпись оси и под ней числа игроков их цветами ("18.2 12.0").
func _draw_labels(centre: Vector2) -> void:
	var font := get_theme_font("font", "Label")
	var font_size := get_theme_font_size("font_size", "Label")
	var line := float(PixelTheme.LINE_H)
	for i in AXES.size():
		var key: String = AXES[i]
		var dir := _dir(i)
		var anchor := centre + dir * (RADIUS + LABEL_GAP)
		var parts: Array = [[String(LABELS[key]), PixelTheme.TEXT_DIM]]
		var numbers: Array = []
		for s: Dictionary in _series:
			numbers.append(["%.1f" % float((s["values"] as Dictionary).get(key, 0.0)), s["colour"]])
		var block_h := line * 2.0
		var top := anchor.y - block_h / 2.0
		if dir.y < -0.9:
			top = anchor.y - block_h
		elif dir.y > 0.9:
			top = anchor.y
		_draw_row(font, font_size, parts, anchor.x, top, dir.x)
		_draw_row(font, font_size, numbers, anchor.x, top + line, dir.x)


## Строка из кусков [текст, цвет] через пробел; side — куда смотрит ось:
## вправо — строка от точки, влево — до точки, вверх/вниз — по центру.
func _draw_row(font: Font, font_size: int, parts: Array, x: float, top: float, side: float) -> void:
	var widths: Array[float] = []
	var total := 0.0
	var space := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	for part: Array in parts:
		var w := font.get_string_size(String(part[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		widths.append(w)
		total += w
	total += space * maxi(parts.size() - 1, 0)
	var start := x - total / 2.0
	if side > 0.3:
		start = x
	elif side < -0.3:
		start = x - total
	var baseline := top + font.get_ascent(font_size)
	for i in parts.size():
		draw_string(font, Vector2(roundf(start), roundf(baseline)), String(parts[i][0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, parts[i][1])
		start += widths[i] + space
