class_name EnemyInfoPanel
extends Control

## Зона информации о противниках: на каждого — свой вертикальный прямоугольник
## в цвет игрока. Только открытые сведения: VP, ресурсы хода, войска, размер
## руки, колода, сброс и Внутренний круг.
##
## Прямоугольники стоят в ряд и делят ширину зоны поровну, поэтому партия на
## 2 и на 4 человек выглядит одинаково — меняется только число блоков.

var _row: HBoxContainer
var _blocks: Dictionary = {}   # player_id -> Dictionary с узлами блока


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 2)
	_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_row)


## Один блок противника. Возвращает словарь узлов, чтобы потом менять только
## значения, а не пересобирать вёрстку на каждый ход.
func _make_block(pid: String) -> Dictionary:
	var colour: Color = BoardPanel.PLAYER_COLORS.get(pid, Color(0.6, 0.6, 0.6))
	var panel := PanelContainer.new()
	var style := GameScreen.zone_style(1)
	style.border_width_top = 2
	style.border_color = colour
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # чтобы работала подсказка
	_row.add_child(panel)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)

	# Плашка узкая (74 px) и низкая: в неё влезают две строки — имя с VP и
	# ресурсы. Всё остальное — во всплывающей подсказке.
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 2)
	col.add_child(head)
	var turn_mark := Label.new()
	turn_mark.text = ">"
	turn_mark.add_theme_color_override("font_color", PixelTheme.GOLD)
	head.add_child(turn_mark)
	var name_label := Label.new()
	name_label.text = EventLogPanel.player_name(pid).to_upper()
	name_label.add_theme_color_override("font_color", EventLogPanel.player_color(pid))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	head.add_child(name_label)
	var vp := Label.new()
	vp.add_theme_color_override("font_color", PlayerPanel.VP_COLOR)
	head.add_child(vp)

	var stats := Label.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	stats.clip_text = true
	col.add_child(stats)

	return {"panel": panel, "style": style, "turn": turn_mark, "vp": vp, "stats": stats}


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
		(block["style"] as StyleBoxFlat).bg_color = PixelTheme.PANEL if pid != current \
			else PixelTheme.PANEL_HI
		(block["vp"] as Label).text = "%dvp" % int(p["vp_tokens"])
		(block["stats"] as Label).text = "P%d I%d H%d" % [
			int(p["power"]), int(p["influence"]), int(p["hand_size"])]
		(block["panel"] as PanelContainer).tooltip_text = \
			"%s\nPower %d · Influence %d · Hand %d\nTroops/spies %d/%d\nDeck/discard %d/%d\nTrophies/circle %d/%d" % [
				EventLogPanel.player_name(pid), int(p["power"]), int(p["influence"]),
				int(p["hand_size"]), int(p["troops_in_barracks"]), int(p["spies_in_barracks"]),
				int(p["deck_size"]), int(p["discard_size"]), int(p["trophy_hall_count"]),
				(p.get("inner_circle", []) as Array).size()]
