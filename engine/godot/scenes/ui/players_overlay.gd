class_name PlayersOverlay
extends Control

## Полный расклад по всем игрокам. Висит поверх экрана, пока зажат Tab, и
## исчезает, как только клавишу отпустили (решение владельца, 2026-09-19):
## в обычной игре экран не занят таблицами, но всё открытое можно увидеть
## в любой момент.
##
## Прямоугольники — в цветах игроков и в порядке хода; у того, кто начинал
## партию, сверху плашка FIRST PLAYER. Содержимое у всех одинаковое, скрытых
## сведений здесь нет: рука и сброс противника показаны только числом карт
## (так их и отдаёт StateView).

const BOX_W := 150.0
const GAP := 4.0

## Строки прямоугольника: ключ в срезе игрока -> подпись.
const ROWS: Array[Array] = [
	["vp_tokens", "VP"],
	["power", "Power"],
	["influence", "Influence"],
	["troops_in_barracks", "Troops"],
	["spies_in_barracks", "Spies"],
	["hand_size", "Hand"],
	["deck_size", "Deck"],
	["discard_size", "Discard"],
	["inner_circle", "Inner circle"],
	["trophy_hall_count", "Trophies"],
	["white_trophy_count", "of them neutral"],
]

var _row: HBoxContainer
var _boxes: Dictionary = {}   # player_id -> Dictionary с узлами блока


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(PixelTheme.BG, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", int(GAP))
	_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_row)


func _make_box(pid: String, first_player: bool) -> Dictionary:
	var colour: Color = BoardPanel.PLAYER_COLORS.get(pid, Color(0.6, 0.6, 0.6))
	var style := PixelTheme.box(PixelTheme.PANEL, colour, 1, 3, 2)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(BOX_W, 0)
	# Ширина у всех одинаковая: без SHRINK прямоугольники растянулись бы на
	# весь экран, и на двоих каждый был бы вдвое шире нужного.
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(panel)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)

	var name_label := Label.new()
	name_label.text = EventLogPanel.player_name(pid).to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", colour)
	col.add_child(name_label)

	# Плашка первого игрока. У остальных на её месте пустая строка той же
	# высоты, иначе прямоугольники разъезжаются по вертикали.
	var plaque := Label.new()
	plaque.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if first_player:
		plaque.text = "FIRST PLAYER"
		plaque.add_theme_color_override("font_color", PixelTheme.BG)
		plaque.add_theme_stylebox_override("normal", PixelTheme.fill(PixelTheme.GOLD, 2, 0))
	col.add_child(plaque)

	var values: Dictionary = {}
	for row: Array in ROWS:
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(line)
		var caption := Label.new()
		caption.text = String(row[1])
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
		line.add_child(caption)
		var value := Label.new()
		value.add_theme_color_override("font_color", PixelTheme.TEXT)
		line.add_child(value)
		values[String(row[0])] = value

	return {"panel": panel, "style": style, "values": values, "colour": colour}


func update_from_view(view: Dictionary) -> void:
	var order: Array = view.get("turn_order", [])
	var current := String(view["current_player"])
	if _boxes.is_empty():
		for i in order.size():
			_boxes[String(order[i])] = _make_box(String(order[i]), i == 0)

	for pid: String in _boxes:
		var box: Dictionary = _boxes[pid]
		var p: Dictionary = (view["players"] as Dictionary).get(pid, {})
		if p.is_empty():
			continue
		var values: Dictionary = box["values"]
		for row: Array in ROWS:
			var key := String(row[0])
			var raw: Variant = p.get(key, 0)
			var shown: int = (raw as Array).size() if raw is Array else int(raw)
			(values[key] as Label).text = str(shown)
		# Зал трофеев отдаёт общее число и сколько из него нейтральных —
		# вторая строка уже про первую, поэтому её видно приглушённой.
		(box["style"] as StyleBoxFlat).bg_color = \
			PixelTheme.PANEL_HI if pid == current else PixelTheme.PANEL
