class_name PileDialog
extends Control

## Список карт стопки поверх экрана: Внутренний круг или сброс зрителя.
## Открывается щелчком по PileZone, закрывается кнопкой, щелчком мимо панели
## или клавишей Escape. Карты внутри не кликаются — их читают увеличением
## по зажатому Alt.

const CARD_SIZE := Vector2(106, 153)
const PANEL_MAX := Vector2(880, 520)

var _center: CenterContainer
var _title: Label
var _grid: GridContainer
var _scroll: ScrollContainer
var _body: PanelContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	_body = PanelContainer.new()
	var style := GameScreen.zone_style(12)
	style.bg_color = Color(0.09, 0.087, 0.115)
	style.border_color = Color(0.42, 0.4, 0.5)
	style.set_border_width_all(2)
	_body.add_theme_stylebox_override("panel", style)
	_center.add_child(_body)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_body.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := Button.new()
	close.text = "Close"
	close.add_theme_font_size_override("font_size", 12)
	close.pressed.connect(close_pile)
	head.add_child(close)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)


func open_pile(title: String, ids: Array) -> void:
	_title.text = "%s — %d card%s" % [title, ids.size(), "" if ids.size() == 1 else "s"]
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	var area: Vector2 = get_viewport_rect().size
	var panel: Vector2 = PANEL_MAX.min(area - Vector2(80, 120))
	var columns: int = maxi(1, int((panel.x - 24.0) / (CARD_SIZE.x + 8.0)))
	_grid.columns = columns
	var rows: int = ceili(float(maxi(ids.size(), 1)) / float(columns))
	var grid_h: float = float(rows) * (CARD_SIZE.y + 8.0)
	_scroll.custom_minimum_size = Vector2(
		float(columns) * (CARD_SIZE.x + 8.0),
		minf(grid_h, panel.y - 60.0))

	for cid in ids:
		var card := CardView.new(String(cid), int(CARD_SIZE.x), int(CARD_SIZE.y))
		card.set_clickable(false, false)
		_grid.add_child(card)
	if ids.is_empty():
		var empty := Label.new()
		empty.text = "This pile is empty."
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.6, 0.58, 0.68))
		_grid.add_child(empty)
	visible = true


func close_pile() -> void:
	visible = false


## Щелчок мимо панели закрывает окно: попадание проверяем по самой панели,
## потому что затемнение растянуто на весь экран и мышь не ловит.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not _body.get_global_rect().has_point((event as InputEventMouseButton).global_position):
			close_pile()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		close_pile()
		accept_event()
