class_name EnemyInfoPanel
extends Control

## Зона информации о противниках: на каждого — свой вертикальный прямоугольник
## в цвет игрока. Только открытые сведения: VP, ресурсы хода, войска, размер
## руки, колода, сброс и Внутренний круг.
##
## Прямоугольники стоят в ряд и делят ширину зоны поровну, поэтому партия на
## 2 и на 4 человек выглядит одинаково — меняется только число блоков.

const ROW_FONT := 11
const SMALL_FONT := 10

var _row: HBoxContainer
var _blocks: Dictionary = {}   # player_id -> Dictionary с узлами блока


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 6)
	_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_row)


## Один блок противника. Возвращает словарь узлов, чтобы потом менять только
## значения, а не пересобирать вёрстку на каждый ход.
func _make_block(pid: String) -> Dictionary:
	var colour: Color = BoardPanel.PLAYER_COLORS.get(pid, Color(0.6, 0.6, 0.6))
	var panel := PanelContainer.new()
	var style := GameScreen.zone_style(4)
	style.border_width_top = 3
	style.border_color = colour
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(panel)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var name_label := Label.new()
	name_label.text = EventLogPanel.player_name(pid).to_upper()
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", EventLogPanel.player_color(pid))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	head.add_child(name_label)
	var turn_mark := Label.new()
	turn_mark.text = "◆"
	turn_mark.add_theme_font_size_override("font_size", 12)
	turn_mark.add_theme_color_override("font_color", Color(0.91, 0.85, 0.63))
	head.add_child(turn_mark)

	var vp := Label.new()
	vp.add_theme_font_size_override("font_size", 15)
	vp.add_theme_color_override("font_color", PlayerPanel.VP_COLOR)
	col.add_child(vp)

	var rows := {
		"power": _add_row(col, "Power", ROW_FONT, PlayerPanel.POWER_COLOR),
		"influence": _add_row(col, "Influence", ROW_FONT, PlayerPanel.INFLUENCE_COLOR),
		"hand": _add_row(col, "Hand", ROW_FONT),
		"troops": _add_row(col, "Troops / spies", SMALL_FONT),
		"deck": _add_row(col, "Deck / discard", SMALL_FONT),
		"trophies": _add_row(col, "Trophies / circle", SMALL_FONT),
	}
	return {"panel": panel, "style": style, "turn": turn_mark, "vp": vp, "rows": rows}


static func _add_row(parent: Control, caption: String, font_size: int,
		colour: Color = Color(0.88, 0.88, 0.92)) -> Label:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = caption
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", SMALL_FONT)
	name_label.add_theme_color_override("font_color", Color(0.62, 0.6, 0.7))
	name_label.clip_text = true
	row.add_child(name_label)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", font_size)
	value.add_theme_color_override("font_color", colour)
	row.add_child(value)
	return value


func update_from_view(view: Dictionary, viewer_id: String) -> void:
	var order: Array = view.get("turn_order", [])
	var current := String(view["current_player"])

	# Блоки собираются один раз на партию: состав игроков по ходу не меняется.
	if _blocks.is_empty():
		for pid in order:
			if String(pid) != viewer_id:
				_blocks[String(pid)] = _make_block(String(pid))

	for pid: String in _blocks:
		var block: Dictionary = _blocks[pid]
		var p: Dictionary = (view["players"] as Dictionary).get(pid, {})
		if p.is_empty():
			continue
		(block["turn"] as Label).visible = pid == current
		(block["style"] as StyleBoxFlat).bg_color = Color(0.105, 0.1, 0.135) if pid != current \
			else Color(0.16, 0.15, 0.2)
		(block["vp"] as Label).text = "%d VP" % int(p["vp_tokens"])
		var rows: Dictionary = block["rows"]
		(rows["power"] as Label).text = str(int(p["power"]))
		(rows["influence"] as Label).text = str(int(p["influence"]))
		(rows["hand"] as Label).text = str(int(p["hand_size"]))
		(rows["troops"] as Label).text = "%d / %d" % [int(p["troops_in_barracks"]), int(p["spies_in_barracks"])]
		(rows["deck"] as Label).text = "%d / %d" % [int(p["deck_size"]), int(p["discard_size"])]
		(rows["trophies"] as Label).text = "%d / %d" % [int(p["trophy_hall_count"]),
			(p.get("inner_circle", []) as Array).size()]
