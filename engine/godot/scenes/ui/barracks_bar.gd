class_name BarracksBar
extends Control

## Левый верхний угол экрана: по прямоугольнику на каждого игрока в его цвете,
## внутри — только цифры, войска и шпионы в бараке через дробь ("40/5").
## Полное пояснение ("Troops: 40, spies: 5") — во всплывающей подсказке
## прямоугольника (решение владельца, 2026-09-19).
##
## Прямоугольники стоят в порядке хода: слева тот, кто ходил первым.
##
## Полоса занимает всю отведённую ей ширину (ширину левой колонки,
## GameScreen.COL), а прямоугольники делят её поровну. На троих-четверых
## прямоугольник становится уже четырёх знаков, поэтому цифры там ложатся в
## две строки: сверху войска, снизу шпионы.

## Наименьший размер одного прямоугольника. Ширины хватает на четыре знака
## ("40/5"): шрифт 5x7 с шагом 6 пикселей плюс рамка и отступ.
const BOX := Vector2(30, 20)
const GAP := 2.0
## С этого числа игроков прямоугольники узкие и цифры идут в две строки.
const COMPACT_FROM := 3

var _row: HBoxContainer
var _compact := false
var _boxes: Dictionary = {}   # player_id -> {"style": StyleBoxFlat, "value": Label, "panel": PanelContainer}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", int(GAP))
	_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_row)


## Сколько места займёт полоса на count игроков, если её не растягивать.
static func width_for(count: int) -> float:
	return BOX.x * float(count) + GAP * float(maxi(count - 1, 0))


func _make_box(pid: String) -> Dictionary:
	var colour: Color = BoardPanel.PLAYER_COLORS.get(pid, Color(0.6, 0.6, 0.6))
	var style := PixelTheme.box(colour.darkened(0.7), colour, 1, 1, 1)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	# Ширину задаёт полоса, а не прямоугольник: все делят её поровну.
	panel.custom_minimum_size = Vector2(0, BOX.y)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # чтобы работала подсказка
	panel.clip_contents = true
	_row.add_child(panel)

	var value := Label.new()
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_color_override("font_color", PixelTheme.TEXT)
	if _compact:
		# Две строки вплотную: иначе они не влезают в 20 пикселей высоты.
		value.add_theme_constant_override("line_spacing", -3)
	panel.add_child(value)

	return {"panel": panel, "style": style, "value": value}


func update_from_view(view: Dictionary) -> void:
	var order: Array = view.get("turn_order", [])
	if _boxes.is_empty():
		_compact = order.size() >= COMPACT_FROM
		for pid in order:
			_boxes[String(pid)] = _make_box(String(pid))

	for pid: String in _boxes:
		var box: Dictionary = _boxes[pid]
		var p: Dictionary = (view["players"] as Dictionary).get(pid, {})
		if p.is_empty():
			continue
		var troops := int(p["troops_in_barracks"])
		var spies := int(p["spies_in_barracks"])
		(box["value"] as Label).text = ("%d\n%d" if _compact else "%d/%d") % [troops, spies]
		(box["panel"] as PanelContainer).tooltip_text = "%s\nTroops: %d, spies: %d" % [
			EventLogPanel.player_name(pid), troops, spies]
