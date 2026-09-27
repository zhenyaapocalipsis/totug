class_name PlayersPanel
extends PanelContainer

## Расклад по игрокам в правой колонке под бараками (решение владельца,
## 2026-09-27: переехал сюда из меню по Tab на место зоны сыгранных карт —
## сыгранные карты и так видны в сводке ходов слева).
##
## Таблица: строка на игрока в порядке хода, у ходящего перед именем «>».
## Скрытых сведений нет: рука и сброс противника — только числом карт (так их
## и отдаёт StateView). Под таблицей — кто ходил первым, а во время стартовой
## расстановки ещё и сам вопрос «выбери стартовую локацию».

## Столбцы: ключ в срезе игрока, заголовок, подсказка к заголовку.
const COLUMNS: Array[Array] = [
	["vp_tokens", "VP", "Victory point tokens"],
	["hand_size", "HND", "Cards in hand"],
	["deck_size", "DCK", "Cards in deck"],
	["discard_size", "DIS", "Cards in discard pile"],
	["inner_circle", "INN", "Cards in Inner Circle"],
	["trophies", "TRO", "Trophies (killed troops)"],
]
## Ширина столбца имени (6 знаков шрифта по 6 пикселей) и числового (3 знака).
const NAME_W := 36.0
const NUM_W := 18.0
const COL_GAP := 2

var _grid: GridContainer
var _rows: Dictionary = {}   # player_id -> {"name": Label, "values": {key: Label}}
var _first_label: Label
## Вопрос стартовой расстановки — показывает game_screen.
var setup_label: Label


func _init() -> void:
	add_theme_stylebox_override("panel", GameScreen.zone_style(2))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	add_child(col)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS.size() + 1
	_grid.add_theme_constant_override("h_separation", COL_GAP)
	_grid.add_theme_constant_override("v_separation", 0)
	col.add_child(_grid)
	_grid.add_child(_cell("", NAME_W, PixelTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	for column: Array in COLUMNS:
		var head := _cell(String(column[1]), NUM_W, PixelTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		head.tooltip_text = String(column[2])
		head.mouse_filter = Control.MOUSE_FILTER_STOP  # чтобы работала подсказка
		_grid.add_child(head)

	_first_label = Label.new()
	_first_label.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	col.add_child(_first_label)

	setup_label = Label.new()
	setup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	setup_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	setup_label.visible = false
	col.add_child(setup_label)


static func _cell(text: String, width: float, colour: Color,
		align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 0)
	label.horizontal_alignment = align
	label.clip_text = true
	label.add_theme_color_override("font_color", colour)
	return label


func _add_row(pid: String) -> void:
	var colour: Color = BoardPanel.PLAYER_COLORS.get(pid, PixelTheme.TEXT)
	var name_label := _cell("", NAME_W, colour, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP  # подсказка — полное имя
	_grid.add_child(name_label)
	var values: Dictionary = {}
	for column: Array in COLUMNS:
		var value := _cell("0", NUM_W, PixelTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		_grid.add_child(value)
		values[String(column[0])] = value
	# У трофеев подсказка — сколько чьих войск убито.
	(values["trophies"] as Label).mouse_filter = Control.MOUSE_FILTER_STOP
	_rows[pid] = {"name": name_label, "values": values}


## Трофеи по цветам одной строкой для подсказки: «white 2, blue 1».
static func _trophy_breakdown(trophies: Dictionary, order: Array) -> String:
	var parts: Array[String] = []
	var colours: Array = ["white"]
	colours.append_array(order)
	for colour_id in colours:
		var count := int(trophies.get(String(colour_id), 0))
		if count > 0:
			var who := "neutral" if colour_id == "white" else EventLogPanel.player_name(String(colour_id))
			parts.append("%s %d" % [who, count])
	return "Trophies: " + (", ".join(parts) if not parts.is_empty() else "none")


func update_from_view(view: Dictionary) -> void:
	var order: Array = view.get("turn_order", [])
	var current := String(view["current_player"])
	if _rows.is_empty():
		for pid in order:
			_add_row(String(pid))
		if not order.is_empty():
			_first_label.text = "First: %s" % EventLogPanel.player_name(String(order[0]))
	for pid: String in _rows:
		var p: Dictionary = (view["players"] as Dictionary).get(pid, {})
		if p.is_empty():
			continue
		var row: Dictionary = _rows[pid]
		var name_text := EventLogPanel.player_name(pid).to_upper()
		(row["name"] as Label).text = (">" + name_text) if pid == current else name_text
		(row["name"] as Label).tooltip_text = EventLogPanel.player_name(pid)
		var values: Dictionary = row["values"]
		for column: Array in COLUMNS:
			var key := String(column[0])
			var raw: Variant = p.get(key, 0)
			var shown := 0
			if raw is Array:
				shown = (raw as Array).size()
			elif raw is Dictionary:
				for count in (raw as Dictionary).values():
					shown += int(count)
			else:
				shown = int(raw)
			(values[key] as Label).text = str(shown)
		(values["trophies"] as Label).tooltip_text = \
			_trophy_breakdown(p.get("trophies", {}), order)
