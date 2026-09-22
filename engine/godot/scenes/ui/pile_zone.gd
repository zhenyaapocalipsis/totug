class_name PileZone
extends PanelContainer

## Стопка карт — горизонтальная кнопка в левом нижнем углу экрана: подпись
## слева, число карт справа (решение владельца, 2026-09-22: Discard, Inner
## и Devoured просто кнопками одна под другой). По щелчку открывается весь
## список карт стопки (PileDialog).

signal clicked

var _caption: Label
var _count: Label
var _style: StyleBoxFlat
var _hover_style: StyleBoxFlat


func _init(caption: String = "") -> void:
	_style = GameScreen.zone_style(3)
	_hover_style = GameScreen.zone_style(3)
	_hover_style.bg_color = PixelTheme.PANEL_HI
	add_theme_stylebox_override("panel", _style)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Click to see every card in this pile"
	mouse_entered.connect(func(): add_theme_stylebox_override("panel", _hover_style))
	mouse_exited.connect(func(): add_theme_stylebox_override("panel", _style))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	add_child(row)
	_caption = Label.new()
	_caption.text = caption
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.clip_text = true
	row.add_child(_caption)
	_count = Label.new()
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.add_theme_color_override("font_color", PixelTheme.GOLD)
	row.add_child(_count)


func set_cards(ids: Array) -> void:
	_count.text = str(ids.size())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit()
		accept_event()
