class_name MarketPanel
extends PanelContainer

## Маркет: 6 открытых карт дисплея плюс общие стопки — House Guard и
## Priestess of Lolth (рулбук стр. 4 шаг 3 и стр. 13). Стопки лежат СВОИМИ
## местами, а не в слотах дисплея, и не пополняются из колоды маркета,
## поэтому показаны отдельным рядом с остатком стопки.
##
## Колонка узкая, карты мелкие и тянутся под доступное место; прочитать карту
## можно наведением (CardPreview). Прокрутки нет: она резала карты пополам.

signal market_card_clicked(index: int)
signal supply_card_clicked(card_id: String)

var _grid: GridContainer
var _supply_row: GridContainer
var _deck_label: Label


## Слот карты маркета: ровно ширина мелкого лица карты (пиксель в пиксель),
## высота — наименьшая. Дальше слоты тянутся вверх по высоте колонки: пустого
## места под маркетом больше нет, и арта видно столько, сколько влезло
## (решение владельца, 2026-09-19).
const SLOT := Vector2i(80, 32)
## Отступ панели ровно в пиксель: два слота по 80 и зазор — вся ширина колонки.
const PAD := 1


func _init() -> void:
	add_theme_stylebox_override("panel", GameScreen.zone_style(PAD))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	add_child(col)

	var title_row := HBoxContainer.new()
	col.add_child(title_row)
	var title := GameScreen.section_label("MARKET")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_deck_label = GameScreen.section_label("")
	title_row.add_child(_deck_label)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	# Ряды дисплея (их три) и ряд снабжения (один) делят лишнюю высоту в
	# отношении 3:1 — тогда все карты маркета одной высоты.
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.size_flags_stretch_ratio = 3.0
	col.add_child(_grid)

	col.add_child(GameScreen.section_label("SUPPLY"))

	# Сетка, а не ряд: слоты те же, что у дисплея, и их может стать больше.
	_supply_row = GridContainer.new()
	_supply_row.columns = 2
	_supply_row.add_theme_constant_override("h_separation", 2)
	_supply_row.add_theme_constant_override("v_separation", 2)
	_supply_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_supply_row.size_flags_stretch_ratio = 1.0
	col.add_child(_supply_row)


func update_from_view(view: Dictionary) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for child in _supply_row.get_children():
		_supply_row.remove_child(child)
		child.queue_free()

	var market: Dictionary = view["market"]
	var display: Array = market["display"]
	var legal: Dictionary = view.get("legal", {})
	var affordable: Array = legal.get("recruit_market", [])
	_deck_label.text = "DECK %d" % int(market["deck_size"])

	for i in range(display.size()):
		var cid: String = display[i]
		if cid == "":
			_grid.add_child(_empty_slot())
			continue
		var slot := _market_slot(cid)
		var card: CardView = slot.get_child(0)
		card.set_clickable(affordable.has(i))
		var index := i
		card.pressed.connect(func(_cid: String): market_card_clicked.emit(index))
		_grid.add_child(slot)

	# Ghost: верхняя сожранная карта до конца хода считается картой маркета.
	var ghost_card: String = view.get("ghost_market_card", "")
	if ghost_card != "":
		var ghost := _market_slot(ghost_card)
		var ghost_card_view: CardView = ghost.get_child(0)
		ghost_card_view.set_clickable(affordable.has(Market.DEVOURED_TOP_INDEX))
		ghost_card_view.tooltip_text = "Top devoured card (Ghost)"
		ghost_card_view.pressed.connect(
			func(_cid: String): market_card_clicked.emit(Market.DEVOURED_TOP_INDEX))
		_grid.add_child(ghost)

	var supplies: Dictionary = view.get("supplies", {})
	var affordable_supply: Array = legal.get("recruit_supply", [])
	for card_id: String in Supplies.PURCHASABLE:
		var left: int = int(supplies.get(card_id, 0))
		var box := _supply_box(card_id, "×%d" % left, left > 0)
		var card: CardView = box.get_child(0)
		card.set_clickable(left > 0 and affordable_supply.has(card_id))
		card.pressed.connect(func(cid: String): supply_card_clicked.emit(cid))
		_supply_row.add_child(box)

	# Стопку Insane Outcast в маркете не показываем вовсе (решение владельца,
	# 2026-09-19): её не вербуют, карты раздают её сами при розыгрыше.


## Карта маркета в слоте: видно верх лица карты — имя и цену в правом верхнем
## углу. Плашки с ценой поверх слота больше нет, цена читается с самой карты.
## Возвращает контейнер; сама карта — первый ребёнок.
static func _market_slot(cid: String) -> Control:
	var box := Control.new()
	box.custom_minimum_size = SLOT
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := CardView.new(cid, SLOT.x, SLOT.y)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(card)
	return box


## Карта общей стопки: остаток написан прямо поверх карты — отдельной строки
## под неё в колонке нет.
static func _supply_box(cid: String, count_text: String, has_cards: bool) -> Control:
	var box := _market_slot(cid)
	var left_label := Label.new()
	left_label.text = count_text
	left_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left_label.offset_top = -11
	left_label.offset_left = 2
	left_label.add_theme_color_override("font_color",
		PixelTheme.TEXT if has_cards else PixelTheme.DANGER)
	left_label.add_theme_color_override("font_outline_color", PixelTheme.BG)
	left_label.add_theme_constant_override("outline_size", 2)
	box.add_child(left_label)
	return box


func _empty_slot() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = SLOT
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",
		PixelTheme.box(PixelTheme.PANEL_LO, PixelTheme.BORDER, 1, 1, 1))
	var label := Label.new()
	label.text = "empty"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", PixelTheme.TEXT_OFF)
	panel.add_child(label)
	return panel
