class_name GameOverPanel
extends Control

## Итоги партии: счёт каждого игрока по статьям финального подсчёта (рулбук,
## стр. 14) и победитель. Появляется сам, когда партия окончена. VIEW BOARD
## прячет итоги, чтобы посмотреть доску; Esc показывает их снова.

signal main_menu_requested

const BUTTON_SIZE := Vector2(90, 16)
const COL_W := 34
## Статьи подсчёта: ключ в view["final_scores"][игрок] и подпись столбца.
const COLUMNS := [
	["sites", "SITES"],
	["total_control", "CTRL"],
	["trophies", "TROPH"],
	["deck", "DECK"],
	["inner_circle", "INNER"],
	["tokens", "VP"],
]

var _title: Label
var _grid: GridContainer
var _shown_once := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Над экраном партии и меню по Tab, но под меню паузы (1100).
	z_index = 1050
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(PixelTheme.BG, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", GameScreen.zone_style(6))
	centre.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var head := Label.new()
	head.text = "GAME OVER"
	head.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	_title.add_theme_color_override("font_color", PixelTheme.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS.size() + 2
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 3)
	col.add_child(_grid)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 6)
	col.add_child(buttons)
	buttons.add_child(_button("VIEW BOARD", func(): visible = false))
	buttons.add_child(_button("MAIN MENU", func(): main_menu_requested.emit()))


## Заполняет таблицу из среза состояния. Первый раз после конца партии
## открывается сам; дальше видимостью управляет игрок.
func update_from_view(view: Dictionary) -> void:
	if not bool(view.get("game_over", false)) or not view.has("final_scores"):
		return
	var scores: Dictionary = view["final_scores"]
	var winners: Array = view.get("winners", [])

	var names: Array[String] = []
	for pid in winners:
		names.append(EventLogPanel.player_name(String(pid)).to_upper())
	if winners.size() == 1:
		_title.text = "%s WINS" % names[0]
		_title.add_theme_color_override("font_color", EventLogPanel.player_color(String(winners[0])))
	else:
		_title.text = "TIE: %s" % ", ".join(names)
		_title.add_theme_color_override("font_color", PixelTheme.GOLD)

	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_grid.add_child(_cell("", PixelTheme.TEXT_DIM, 0))
	for c in COLUMNS:
		_grid.add_child(_cell(c[1], PixelTheme.TEXT_DIM, COL_W))
	_grid.add_child(_cell("SUM", PixelTheme.GOLD, COL_W))

	# Строки — по убыванию счёта, при равенстве в порядке хода.
	var order: Array = view["turn_order"].duplicate()
	order.sort_custom(func(a, b):
		return int(scores[a]["total"]) > int(scores[b]["total"]))
	for pid in order:
		var s: Dictionary = scores[pid]
		var colour := EventLogPanel.player_color(String(pid))
		_grid.add_child(_cell(EventLogPanel.player_name(String(pid)).to_upper(), colour, 0,
				HORIZONTAL_ALIGNMENT_LEFT))
		for c in COLUMNS:
			_grid.add_child(_cell(str(int(s[c[0]])), PixelTheme.TEXT, COL_W))
		_grid.add_child(_cell(str(int(s["total"])),
				PixelTheme.GOLD if winners.has(pid) else PixelTheme.TEXT, COL_W))

	if not _shown_once:
		_shown_once = true
		visible = true


func _cell(text: String, colour: Color, width: int,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.custom_minimum_size.x = width
	label.add_theme_color_override("font_color", colour)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	SetupScreen._style_button(button)
	button.pressed.connect(action)
	return button
