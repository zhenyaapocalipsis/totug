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

	# По решению владельца в плашке только две вещи: сколько войск осталось в
	# бараке и что лежит в зале трофеев — отдельно нейтральные (белые) войска
	# и войска игроков. Остальное открытое (VP, рука, колода) — в подсказке.
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
	var troops := Label.new()
	troops.add_theme_color_override("font_color", PixelTheme.TEXT)
	head.add_child(troops)

	var hall := Label.new()
	hall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hall.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	hall.clip_text = true
	col.add_child(hall)

	return {"panel": panel, "style": style, "turn": turn_mark, "troops": troops, "hall": hall}


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
		var white := int(p.get("white_trophy_count", 0))
		var taken := int(p["trophy_hall_count"]) - white
		(block["troops"] as Label).text = "T%d" % int(p["troops_in_barracks"])
		(block["hall"] as Label).text = "hall %dp %dn" % [taken, white]
		(block["panel"] as PanelContainer).tooltip_text = \
			("%s\nTroops in barracks %d, spies %d\nTrophy hall: %d player troops, %d neutral\n"
			+ "VP %d · Power %d · Influence %d · Hand %d · Deck/discard %d/%d") % [
				EventLogPanel.player_name(pid), int(p["troops_in_barracks"]),
				int(p["spies_in_barracks"]), taken, white, int(p["vp_tokens"]),
				int(p["power"]), int(p["influence"]), int(p["hand_size"]),
				int(p["deck_size"]), int(p["discard_size"])]
