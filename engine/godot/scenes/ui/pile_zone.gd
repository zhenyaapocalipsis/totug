class_name PileZone
extends PanelContainer

## Стопка карт зрителя рядом с кнопкой End turn: Внутренний круг и сброс.
## Видна верхняя карта и число карт; по щелчку открывается весь список
## (PileDialog). Наведение с зажатым Alt увеличивает верхнюю карту.

signal clicked

## Сколько карт рисуем «слоями», чтобы стопка выглядела стопкой.
const LAYERS := 3
const LAYER_OFFSET := 3.0

var _caption: Label
var _count: Label
var _slot: Control
var _empty: Label
var _ids: Array = []
var _built_for := Vector2.ZERO


func _init(caption: String = "") -> void:
	add_theme_stylebox_override("panel", GameScreen.zone_style(5))
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Click to see every card in this pile"

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	add_child(col)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 4)
	col.add_child(head)
	_caption = GameScreen.section_label(caption)
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.clip_text = true
	head.add_child(_caption)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 12)
	_count.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	head.add_child(_count)

	_slot = Control.new()
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.clip_contents = true
	_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot.resized.connect(_rebuild)
	col.add_child(_slot)

	_empty = Label.new()
	_empty.text = "empty"
	_empty.add_theme_font_size_override("font_size", 11)
	_empty.add_theme_color_override("font_color", Color(0.45, 0.44, 0.52))
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.add_child(_empty)


func set_cards(ids: Array) -> void:
	_count.text = str(ids.size())
	if ids == _ids and _slot.size == _built_for:
		return
	_ids = ids.duplicate()
	_rebuild()


## Верхняя карта стопки — последняя положенная.
func _rebuild() -> void:
	_built_for = _slot.size
	for child in _slot.get_children():
		if child is CardView:
			_slot.remove_child(child)
			child.queue_free()
	_empty.visible = _ids.is_empty()
	if _ids.is_empty() or _slot.size.y < 12.0:
		return

	var shown: int = mini(LAYERS, _ids.size())
	var shift := LAYER_OFFSET * float(shown - 1)
	var w := _slot.size.x - shift
	var h := _slot.size.y - shift
	for i in range(shown):
		# снизу — нижние слои стопки, последним кладём верхнюю карту
		var cid := String(_ids[_ids.size() - shown + i])
		var card := CardView.new(cid, int(w), int(h))
		card.set_clickable(false, false)
		# PASS: карта ловит наведение (Alt-увеличение), но щелчок уходит зоне.
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.position = Vector2(shift - LAYER_OFFSET * float(i), LAYER_OFFSET * float(i))
		card.modulate = Color(1, 1, 1) if i == shown - 1 else Color(0.5, 0.5, 0.55)
		_slot.add_child(card)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit()
		accept_event()
