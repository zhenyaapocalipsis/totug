class_name BarracksBar
extends Control

## Левый верхний угол экрана: по прямоугольнику на каждого игрока в его цвете,
## внутри — только цифры: войска и шпионы в бараке, между ними вертикальная
## черта цвета игрока ("40|5"), всегда в одну строку (владелец, 2026-10-08).
## Полное пояснение ("Troops: 40, spies: 5") — во всплывающей подсказке
## прямоугольника (решение владельца, 2026-09-19).
##
## Прямоугольники стоят в порядке хода: слева тот, кто ходил первым.
##
## Полоса занимает всю отведённую ей ширину (ширину правой колонки,
## GameScreen.COL), а прямоугольники делят её поровну. Цифры с чертой —
## 2 + 1 знака и 5 пикселей черты с зазорами, 23 пикселя: влезают и вчетвером.

## Высота прямоугольника; ширину задаёт полоса.
const BOX_H := 20.0
const GAP := 2.0
## Зазор между цифрами и чертой.
const SEP_GAP := 2
## Высота черты: строка шрифта 5x7 и по пикселю сверху и снизу.
const SEP_H := 9.0
## Вспышка прямоугольника, когда из барака вылетает фишка.
const KICK_BRIGHT := 1.8
const KICK_TIME := 0.25
var _row: HBoxContainer
var _boxes: Dictionary = {}   # player_id -> {"style": StyleBoxFlat, "troops": Label, "spies": Label, "panel": PanelContainer}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", int(GAP))
	_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_row)


func _make_box(pid: String) -> Dictionary:
	var colour: Color = BoardPanel.PLAYER_COLORS.get(pid, Color(0.6, 0.6, 0.6))
	var style := PixelTheme.box(colour.darkened(0.7), colour, 1, 1, 1)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	# Ширину задаёт полоса, а не прямоугольник: все делят её поровну.
	panel.custom_minimum_size = Vector2(0, BOX_H)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # чтобы работала подсказка
	panel.clip_contents = true
	_row.add_child(panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", SEP_GAP)
	panel.add_child(row)
	var troops := _make_number()
	row.add_child(troops)
	var sep := ColorRect.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.color = colour
	sep.custom_minimum_size = Vector2(1, SEP_H)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sep)
	var spies := _make_number()
	row.add_child(spies)

	return {"panel": panel, "style": style, "troops": troops, "spies": spies}


func _make_number() -> Label:
	var value := Label.new()
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.size_flags_vertical = Control.SIZE_EXPAND_FILL
	value.add_theme_color_override("font_color", PixelTheme.TEXT)
	return value


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
		(box["troops"] as Label).text = str(troops)
		(box["spies"] as Label).text = str(spies)
		(box["panel"] as PanelContainer).tooltip_text = "%s\nTroops: %d, spies: %d" % [
			EventLogPanel.player_name(pid), troops, spies]


## Середина прямоугольника игрока pid в глобальных координатах — отсюда
## вылетают его войска и шпионы (см. GameScreen._launch_token). null, если
## такого игрока в полосе нет или полоса ещё не разложена.
func box_global_centre(pid: String) -> Variant:
	if not _boxes.has(pid):
		return null
	var panel: PanelContainer = _boxes[pid]["panel"]
	if panel.size.x < 1.0:
		return null
	return panel.get_global_rect().get_center()


## Из барака только что вылетела фишка: прямоугольник вспыхивает и гаснет.
## Без сдвига и масштаба — их раскладывает полоса, да и пиксели «кипят».
func kick(pid: String) -> void:
	if not _boxes.has(pid):
		return
	var panel: PanelContainer = _boxes[pid]["panel"]
	panel.modulate = Color(KICK_BRIGHT, KICK_BRIGHT, KICK_BRIGHT)
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate", Color.WHITE, KICK_TIME)
