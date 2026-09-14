class_name MarketPanel
extends PanelContainer

## Маркет: 6 открытых карт дисплея плюс две общие стопки — House Guard и
## Priestess of Lolth (рулбук стр. 4 шаг 3 и стр. 13). Стопки лежат СВОИМИ
## местами, а не в слотах дисплея, и не пополняются из колоды маркета,
## поэтому показаны отдельным рядом с остатком стопки.

signal market_card_clicked(index: int)
signal supply_card_clicked(card_id: String)

var _grid: GridContainer
var _supply_row: HBoxContainer
var _title: Label


func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.14)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	# Маркет с шестью картами и двумя стопками выше, чем экран может ему
	# выделить, поэтому содержимое лежит в прокрутке: иначе панель распирает
	# колонку и выдавливает руку игрока за нижний край (так и было в первой
	# версии — увидели на снимке).
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 13)
	_title.modulate = Color(0.8, 0.8, 0.85)
	col.add_child(_title)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	col.add_child(_grid)

	var supply_title := Label.new()
	supply_title.text = "Supply stacks"
	supply_title.add_theme_font_size_override("font_size", 12)
	supply_title.modulate = Color(0.7, 0.7, 0.75)
	col.add_child(supply_title)

	_supply_row = HBoxContainer.new()
	_supply_row.add_theme_constant_override("separation", 8)
	col.add_child(_supply_row)


func update_from_view(view: Dictionary) -> void:
	for child in _grid.get_children():
		child.queue_free()
	for child in _supply_row.get_children():
		child.queue_free()

	var market: Dictionary = view["market"]
	var display: Array = market["display"]
	var legal: Dictionary = view.get("legal", {})
	var affordable: Array = legal.get("recruit_market", [])
	_title.text = "Market — %d cards left in the deck" % int(market["deck_size"])

	for i in range(display.size()):
		var cid: String = display[i]
		if cid == "":
			_grid.add_child(_empty_slot())
			continue
		var card := CardView.new(cid, 140, 150, 5)
		card.set_clickable(affordable.has(i))
		var index := i
		card.pressed.connect(func(_cid: String): market_card_clicked.emit(index))
		_grid.add_child(card)

	# Ghost: верхняя сожранная карта до конца хода считается картой маркета.
	var ghost_card: String = view.get("ghost_market_card", "")
	if ghost_card != "":
		var ghost := CardView.new(ghost_card, 140, 150, 5)
		ghost.set_clickable(affordable.has(Market.DEVOURED_TOP_INDEX))
		ghost.tooltip_text = "Top devoured card (Ghost)"
		ghost.pressed.connect(func(_cid: String): market_card_clicked.emit(Market.DEVOURED_TOP_INDEX))
		_grid.add_child(ghost)

	var supplies: Dictionary = view.get("supplies", {})
	var affordable_supply: Array = legal.get("recruit_supply", [])
	for card_id: String in Supplies.PURCHASABLE:
		var left: int = int(supplies.get(card_id, 0))
		var box := VBoxContainer.new()
		var card := CardView.new(card_id, 140, 104, 2)
		card.set_clickable(left > 0 and affordable_supply.has(card_id))
		card.pressed.connect(func(cid: String): supply_card_clicked.emit(cid))
		box.add_child(card)
		var left_label := Label.new()
		left_label.text = "%d left" % left
		left_label.add_theme_font_size_override("font_size", 11)
		left_label.modulate = Color(0.7, 0.7, 0.75) if left > 0 else Color(0.6, 0.35, 0.35)
		box.add_child(left_label)
		_supply_row.add_child(box)

	# Стопка Insane Outcast выкладывается только с полуколодой Demons —
	# если её в игре нет, ряд про неё не показываем вовсе.
	if supplies.has(Supplies.INSANE_OUTCAST):
		var io := VBoxContainer.new()
		var io_card := CardView.new(Supplies.INSANE_OUTCAST, 140, 104, 2)
		io_card.set_clickable(false)  # его не покупают, только раздают эффектами карт
		io.add_child(io_card)
		var io_label := Label.new()
		io_label.text = "%d left (not for sale)" % int(supplies[Supplies.INSANE_OUTCAST])
		io_label.add_theme_font_size_override("font_size", 11)
		io_label.modulate = Color(0.7, 0.7, 0.75)
		io.add_child(io_label)
		_supply_row.add_child(io)


func _empty_slot() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(140, 150)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.10)
	style.border_color = Color(0.2, 0.2, 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "market\ndeck\nempty"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = Color(0.5, 0.5, 0.55)
	panel.add_child(label)
	return panel
