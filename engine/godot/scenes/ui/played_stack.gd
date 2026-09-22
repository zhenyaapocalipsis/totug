class_name PlayedStack
extends Control

## Сыгранные в этот ход карты — во весь рост, лесенкой сверху вниз (решение
## владельца, 2026-09-22): последняя сыгранная карта видна целиком, у каждой
## предыдущей из-под следующей выглядывает полоска с названием. Карты не
## кликаются; любую из них можно увеличить наведением с зажатым Alt — под
## курсором всегда та карта, чью полоску видно.
##
## Если карт больше, чем помещается (на 960x540 это за восемь), лесенка
## уезжает вверх: самые ранние карты уходят за верхний край зоны, а последняя
## по-прежнему видна целиком. Шаг не ужимаем — ужатые полоски не читаются.

## Полоска с названием карты: рамка и строка имени пиксельного лица целиком.
const STEP := 22.0

var empty_text := ""

var _ids: Array = []
var _built_for := Vector2.ZERO
var _empty: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_empty = Label.new()
	_empty.add_theme_color_override("font_color", PixelTheme.TEXT_OFF)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.set_anchors_preset(Control.PRESET_TOP_WIDE)
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
	if _ids.is_empty() or size.y < 8.0:
		return

	var card_size := CardView.PIXEL_SIZE
	var n := _ids.size()
	var top := minf(0.0, floorf(size.y - card_size.y - STEP * float(n - 1)))
	var x := floorf((size.x - card_size.x) * 0.5)
	for i in range(n):
		var card := CardView.new(String(_ids[i]), int(card_size.x), int(card_size.y))
		card.set_clickable(false, false)
		card.position = Vector2(x, top + STEP * i)
		card.size = card_size
		add_child(card)
