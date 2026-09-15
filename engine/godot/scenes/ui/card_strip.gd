class_name CardStrip
extends Control

## Ряд мелких карт в одну линию: сыгранные карты игрока и противника. Карты
## не кликаются, их читают через увеличенную копию под курсором. Если карт
## больше, чем влезает, они ложатся внахлёст, а не уезжают за край.

const GAP := 6.0

## Ширина карты в долях её высоты.
var card_aspect := 1.0
var empty_text := ""

var _ids: Array = []
var _built_for := Vector2.ZERO
var _empty: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty = Label.new()
	_empty.add_theme_font_size_override("font_size", 12)
	_empty.add_theme_color_override("font_color", Color(0.45, 0.44, 0.52))
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_empty)


func set_cards(ids: Array) -> void:
	if ids == _ids and size == _built_for:
		return
	_ids = ids.duplicate()
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and size != _built_for:
		_rebuild()


func _rebuild() -> void:
	_built_for = size
	for child in get_children():
		if child is CardView:
			remove_child(child)
			child.queue_free()
	_empty.text = empty_text if _ids.is_empty() else ""
	if _ids.is_empty() or size.y < 10.0:
		return

	var h := size.y
	var w := roundf(h * card_aspect)
	var n := _ids.size()
	var step := w + GAP
	if n > 1 and w + step * (n - 1) > size.x:
		step = maxf((size.x - w) / (n - 1), 12.0)
	for i in range(n):
		var card := CardView.new(String(_ids[i]), int(w), int(h), -1 if h < 110 else 0)
		card.set_clickable(false, false)
		card.position = Vector2(step * i, 0)
		add_child(card)
