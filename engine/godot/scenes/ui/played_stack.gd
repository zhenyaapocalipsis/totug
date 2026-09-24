class_name PlayedStack
extends Control

## Сыгранные в этот ход карты — мелкими лицами, лесенкой по диагонали (макет
## владельца, 2026-09-24): каждая следующая лежит правее и ниже предыдущей и
## поверх неё, последняя сыгранная видна целиком, у предыдущих выглядывает
## левый верхний угол с началом названия. Карты не кликаются; любую из них
## можно увеличить наведением с зажатым Alt.
##
## Если карт много, шаг лесенки ужимается, чтобы вся лесенка влезла в зону.

## Шаг лесенки, пока место есть: по вертикали — строка названия мелкого лица,
## по горизонтали — сколько нужно, чтобы уголки не сливались.
const STEP := Vector2(20, 14)
## Меньше этого шаг не ужимаем — дальше карты сольются в одну.
const MIN_STEP := Vector2(3, 2)

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

	var card_size := CardView.MINI_SIZE
	var n := _ids.size()
	var step := STEP
	if n > 1:
		# Шаг только целый: на дробном пиксели карт разъезжаются.
		var fit := ((size - card_size) / float(n - 1)).floor()
		step = step.min(fit).max(MIN_STEP)
	var span := card_size + step * float(n - 1)
	# Лесенка стоит посередине зоны; не влезла даже ужатая — прижата к низу
	# справа, чтобы последняя карта оставалась видна целиком.
	var origin := ((size - span) * 0.5).floor()
	origin = origin.min(size - span)
	for i in range(n):
		var card := CardView.new(String(_ids[i]), int(card_size.x), int(card_size.y))
		card.set_clickable(false, false)
		card.position = origin + step * float(i)
		card.size = card_size
		add_child(card)
