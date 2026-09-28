class_name ChatWheel
extends Control

## Колесо чата (Tab зажат, решение владельца, 2026-09-29): четыре фразы из
## профиля (PlayerProfile.load_phrases) крестом вокруг точки, где нажали Tab —
## вверх, вправо, вниз, влево. Сторона выбирается направлением мыши от центра;
## отпустили Tab — выбранная фраза уходит в чат. Мышь у центра — ничего.

## Расстояние от центра до ближнего края плашки фразы.
const REACH := 18.0
## Мышь ближе к центру — ни одна фраза не выбрана.
const DEAD := 8.0
const MARGIN := 4.0

var _centre := Vector2.ZERO
var _colour := PixelTheme.TEXT
var _boxes: Array[PanelContainer] = []
var _labels: Array[Label] = []
var _selected := -1
var _plain: StyleBoxFlat
var _lit: StyleBoxFlat


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_plain = GameScreen.zone_style(3)
	_lit = _plain.duplicate()
	_lit.border_color = PixelTheme.GOLD
	_lit.bg_color = PixelTheme.PANEL_HI
	for i in PlayerProfile.PHRASE_COUNT:
		var box := PanelContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_stylebox_override("panel", _plain)
		add_child(box)
		var label := Label.new()
		box.add_child(label)
		_boxes.append(box)
		_labels.append(label)


## centre — точка этого слоя; colour — цвет игрока (центр колеса).
func open(centre: Vector2, phrases: Array[String], colour: Color) -> void:
	_colour = colour
	for i in _labels.size():
		_labels[i].text = phrases[i] if i < phrases.size() else ""
		_boxes[i].reset_size()
	var box_size: Array[Vector2] = []
	for box in _boxes:
		box_size.append(box.get_combined_minimum_size())
	# Центр сдвигается от краёв экрана так, чтобы все четыре плашки влезли.
	var lo := Vector2(REACH + box_size[3].x, REACH + box_size[0].y) + Vector2.ONE * MARGIN
	var hi := size - Vector2(REACH + box_size[1].x, REACH + box_size[2].y) - Vector2.ONE * MARGIN
	_centre = centre.clamp(lo, hi.max(lo)).round()
	var offsets := [
		Vector2(-box_size[0].x * 0.5, -REACH - box_size[0].y),
		Vector2(REACH, -box_size[1].y * 0.5),
		Vector2(-box_size[2].x * 0.5, REACH),
		Vector2(-REACH - box_size[3].x, -box_size[3].y * 0.5),
	]
	for i in _boxes.size():
		_boxes[i].position = (_centre + offsets[i]).round()
		_boxes[i].size = box_size[i]
	_selected = -1
	visible = true
	if is_inside_tree():
		_update_selection(get_local_mouse_position())


## Закрыть; вернуть выбранную фразу ("" — не выбрано ничего).
func close() -> String:
	var text := ""
	if visible and _selected >= 0:
		text = _labels[_selected].text
	visible = false
	_selected = -1
	return text


func selected() -> int:
	return _selected


func centre() -> Vector2:
	return _centre


## Какая сторона под точкой: 0 вверх, 1 вправо, 2 вниз, 3 влево, -1 — у центра.
static func side_of(offset: Vector2) -> int:
	if offset.length() < DEAD:
		return -1
	if absf(offset.x) > absf(offset.y):
		return 1 if offset.x > 0.0 else 3
	return 2 if offset.y > 0.0 else 0


func _process(_delta: float) -> void:
	if visible:
		_update_selection(get_local_mouse_position())


## Выбор стороны мышью в точке этого слоя.
func point_at(mouse: Vector2) -> void:
	_update_selection(mouse)


func _update_selection(mouse: Vector2) -> void:
	var side := side_of(mouse - _centre)
	if side == _selected:
		return
	_selected = side
	for i in _boxes.size():
		_boxes[i].add_theme_stylebox_override("panel", _lit if i == side else _plain)
		_labels[i].add_theme_color_override("font_color", PixelTheme.GOLD if i == side else PixelTheme.TEXT)
	queue_redraw()


func _draw() -> void:
	# Тёмный круг под центром — чтобы подписи доски не лезли в колесо; в
	# центре кружок цвета игрока, от него черта к выбранной фразе.
	draw_circle(_centre, REACH, Color(PixelTheme.BG, 0.9), true, -1.0, false)
	draw_arc(_centre, REACH, 0.0, TAU, 48, PixelTheme.BORDER, 1.0, false)
	if _selected >= 0:
		var dir: Vector2 = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][_selected]
		draw_line(_centre + dir * 4.0, _centre + dir * (REACH - 1.0), PixelTheme.GOLD, 1.0)
	draw_circle(_centre, 4.0, PixelTheme.BG, true, -1.0, false)
	draw_circle(_centre, 3.0, _colour, true, -1.0, false)
