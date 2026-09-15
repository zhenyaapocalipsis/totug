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
var _supply_row: HBoxContainer
var _deck_label: Label


func _init() -> void:
	add_theme_stylebox_override("panel", GameScreen.zone_style())

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
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
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	col.add_child(_grid)

	col.add_child(GameScreen.section_label("SUPPLY"))

	_supply_row = HBoxContainer.new()
	_supply_row.add_theme_constant_override("separation", 6)
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
		var card := _market_card(cid)
		card.set_clickable(affordable.has(i))
		var index := i
		card.pressed.connect(func(_cid: String): market_card_clicked.emit(index))
		_grid.add_child(card)

	# Ghost: верхняя сожранная карта до конца хода считается картой маркета.
	var ghost_card: String = view.get("ghost_market_card", "")
	if ghost_card != "":
		var ghost := _market_card(ghost_card)
		ghost.set_clickable(affordable.has(Market.DEVOURED_TOP_INDEX))
		ghost.tooltip_text = "Top devoured card (Ghost)"
		ghost.pressed.connect(func(_cid: String): market_card_clicked.emit(Market.DEVOURED_TOP_INDEX))
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

	# Стопка Insane Outcast выкладывается только с полуколодой Demons —
	# если её в игре нет, карточку про неё не показываем вовсе.
	if supplies.has(Supplies.INSANE_OUTCAST):
		var io := _supply_box(Supplies.INSANE_OUTCAST, "×%d" % int(supplies[Supplies.INSANE_OUTCAST]), true)
		var io_card: CardView = io.get_child(0)
		io_card.set_clickable(false, false)  # его не покупают, только раздают эффектами карт
		io_card.tooltip_text = "Not for sale: given by card effects"
		_supply_row.add_child(io)


static func _market_card(cid: String) -> CardView:
	var card := CardView.new(cid, 118, 72)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return card


static func _supply_box(cid: String, count_text: String, has_cards: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 1)
	var card := CardView.new(cid, 74, 62, -1)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(card)
	var left_label := Label.new()
	left_label.text = count_text
	left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_label.add_theme_font_size_override("font_size", 11)
	left_label.add_theme_color_override("font_color",
		Color(0.7, 0.7, 0.75) if has_cards else Color(0.75, 0.4, 0.4))
	box.add_child(left_label)
	return box


func _empty_slot() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(118, 72)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.10)
	style.border_color = Color(0.2, 0.2, 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "deck empty"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color(0.5, 0.5, 0.55)
	panel.add_child(label)
	return panel
