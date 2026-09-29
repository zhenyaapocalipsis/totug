class_name PileDialog
extends Control

## Список карт стопки поверх экрана: Внутренний круг или сброс зрителя.
## Открывается щелчком по PileZone, закрывается кнопкой, щелчком мимо панели
## или клавишей Escape. Карты внутри не кликаются — их читают увеличением
## по зажатому Alt.

const CARD_SIZE := Vector2(80, 76)   # мелкое лицо карты, пиксель в пиксель
const PANEL_MAX := Vector2(600, 330)

var _center: CenterContainer
var _title: Label
var _grid: GridContainer
var _scroll: ScrollContainer
var _body: PanelContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1000  # над рукой: её поднятая карта рисуется с z_index до 901
	visible = false

	var dim := ColorRect.new()
	dim.color = PixelTheme.DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	# Без фона и рамки — как окна выбора карт: заголовок по центру крупным
	# шрифтом с тенью, под картами надпись Close (решение владельца, 2026-09-27).
	_body = PanelContainer.new()
	_body.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_center.add_child(_body)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_body.add_child(col)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	_title.add_theme_color_override("font_shadow_color", PixelTheme.PANEL_LO)
	_title.add_theme_constant_override("shadow_offset_x", 1)
	_title.add_theme_constant_override("shadow_offset_y", 1)
	col.add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_pile)
	DecisionDialog.make_plain(close)
	col.add_child(close)


## owner — чья стопка: карты в его образах ("" — стопка ничья, как съеденные).
func open_pile(title: String, ids: Array, owner: String = "") -> void:
	_title.text = "%s — %d card%s" % [title, ids.size(), "" if ids.size() == 1 else "s"]
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	var area: Vector2 = get_viewport_rect().size
	var panel: Vector2 = PANEL_MAX.min(area - Vector2(16, 24))
	# Колонок не больше, чем карт: без рамки короткий ряд иначе прижат влево.
	var columns: int = clampi(int((panel.x - 8.0) / (CARD_SIZE.x + 2.0)), 1, maxi(ids.size(), 1))
	_grid.columns = columns
	var rows: int = ceili(float(maxi(ids.size(), 1)) / float(columns))
	var grid_h: float = float(rows) * (CARD_SIZE.y + 2.0)
	# 44 — крупный заголовок сверху и Close снизу
	_scroll.custom_minimum_size = Vector2(
		float(columns) * (CARD_SIZE.x + 2.0),
		minf(grid_h, panel.y - 44.0))

	for cid in ids:
		var card := CardView.new(String(cid), int(CARD_SIZE.x), int(CARD_SIZE.y))
		card.set_card_owner(owner)
		card.set_clickable(false, false)
		_grid.add_child(card)
	if ids.is_empty():
		var empty := Label.new()
		empty.text = "This pile is empty."
		empty.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
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
