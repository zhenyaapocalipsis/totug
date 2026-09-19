class_name BarracksBar
extends Control

## Левый верхний угол экрана: по прямоугольнику на каждого игрока в его цвете,
## внутри — только цифры, войска и шпионы в бараке через дробь ("40/5").
## Полное пояснение ("Troops: 40, spies: 5") — во всплывающей подсказке
## прямоугольника (решение владельца, 2026-09-19).
##
## Прямоугольники стоят в порядке хода: слева тот, кто ходил первым.

## Размер одного прямоугольника. Ширины хватает на четыре знака ("40/5"):
## шрифт 5x7 с шагом 6 пикселей плюс рамка и отступ.
const BOX := Vector2(30, 20)
const GAP := 2.0

var _row: HBoxContainer
var _boxes: Dictionary = {}   # player_id -> {"style": StyleBoxFlat, "value": Label, "panel": PanelContainer}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", int(GAP))
	_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_row)


## Сколько места займёт полоса на count игроков — нужно раскладке экрана.
static func width_for(count: int) -> float:
	return BOX.x * float(count) + GAP * float(maxi(count - 1, 0))


func _make_box(pid: String) -> Dictionary:
	var colour: Color = BoardPanel.PLAYER_COLORS.get(pid, Color(0.6, 0.6, 0.6))
	var style := PixelTheme.box(colour.darkened(0.7), colour, 1, 1, 1)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = BOX
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # чтобы работала подсказка
	_row.add_child(panel)

	var value := Label.new()
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_color_override("font_color", PixelTheme.TEXT)
	panel.add_child(value)

	return {"panel": panel, "style": style, "value": value}


func update_from_view(view: Dictionary) -> void:
	var order: Array = view.get("turn_order", [])
	if _boxes.is_empty():
		for pid in order:
			_boxes[String(pid)] = _make_box(String(pid))

	for pid: String in _boxes:
		var box: Dictionary = _boxes[pid]
		var p: Dictionary = (view["players"] as Dictionary).get(pid, {})
		if p.is_empty():
			continue
		var troops := int(p["troops_in_barracks"])
		var spies := int(p["spies_in_barracks"])
		(box["value"] as Label).text = "%d/%d" % [troops, spies]
		(box["panel"] as PanelContainer).tooltip_text = "%s\nTroops: %d, spies: %d" % [
			EventLogPanel.player_name(pid), troops, spies]
