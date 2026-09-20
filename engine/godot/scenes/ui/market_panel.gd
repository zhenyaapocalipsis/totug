class_name MarketPanel
extends PanelContainer

## Маркет: 6 открытых карт дисплея плюс общие стопки — House Guard и
## Priestess of Lolth (рулбук стр. 4 шаг 3 и стр. 13). Стопки лежат СВОИМИ
## местами, а не в слотах дисплея, и не пополняются из колоды маркета,
## поэтому показаны отдельным рядом с остатком стопки.
##
## Колонка узкая, карты мелкие и тянутся под доступное место; прочитать карту
## можно наведением (CardPreview). Прокрутки нет: она резала карты пополам.
##
## Слоты живут всю партию: панель не сносит карты и не строит их заново, а
## перекладывает в уже стоящий слот другую карту. Поэтому купленную карту
## видно — на её месте новая ВЪЕЗЖАЕТ со вспышкой (CardView.flash_arrival), а
## не бесшумно подменяется. Заодно щелчок больше не может уйти в узел, который
## уже помечен на удаление, но до конца кадра ещё лежит в дереве.

signal market_card_clicked(index: int)
signal supply_card_clicked(card_id: String)

## Слот карты маркета: ровно ширина мелкого лица карты (пиксель в пиксель),
## высота — наименьшая. Дальше слоты тянутся вверх по высоте колонки: пустого
## места под маркетом больше нет, и арта видно столько, сколько влезло
## (решение владельца, 2026-09-19).
const SLOT := Vector2i(80, 32)
## Отступ панели ровно в пиксель: два слота по 80 и зазор — вся ширина колонки.
const PAD := 1
## Слотов дисплея столько же, сколько карт в маркете; последний, седьмой —
## ghost, верхняя сожранная карта. Он скрыт, пока сожранных карт нет:
## невидимые узлы GridContainer пропускает, и ряды не разъезжаются.
const DISPLAY_SLOTS := 6

var _grid: GridContainer
var _supply_row: GridContainer
var _deck_label: Label
## По слоту на карту дисплея плюс ghost последним; по слоту на общую стопку.
var _cards: Array[CardView] = []
var _empties: Array[Control] = []
var _boxes: Array[Control] = []
var _supply_cards: Array[CardView] = []
var _supply_counts: Array[Label] = []


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

	for i in range(DISPLAY_SLOTS + 1):
		var box := _make_slot()
		_grid.add_child(box)
		_boxes.append(box)
		_cards.append(null)
		_empties.append(box.get_child(0))
	_boxes[DISPLAY_SLOTS].visible = false  # ghost — только когда он есть

	col.add_child(GameScreen.section_label("SUPPLY"))

	# Сетка, а не ряд: слоты те же, что у дисплея, и их может стать больше.
	_supply_row = GridContainer.new()
	_supply_row.columns = 2
	_supply_row.add_theme_constant_override("h_separation", 2)
	_supply_row.add_theme_constant_override("v_separation", 2)
	_supply_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_supply_row.size_flags_stretch_ratio = 1.0
	col.add_child(_supply_row)

	# Карты общих стопок не меняются всю партию — их слоты наполняются сразу.
	for cid: String in Supplies.PURCHASABLE:
		var box := _make_slot()
		box.get_child(0).visible = false
		var card := CardView.new(cid, SLOT.x, SLOT.y)
		card.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.refused.connect(func(_cid: String): card.shake_refusal())
		card.pressed.connect(func(clicked: String): supply_card_clicked.emit(clicked))
		box.add_child(card)
		_supply_cards.append(card)
		_supply_counts.append(_add_count_label(box))
		_supply_row.add_child(box)
		_boxes.append(box)

	# Стопку Insane Outcast в маркете не показываем вовсе (решение владельца,
	# 2026-09-19): её не вербуют, карты раздают её сами при розыгрыше.


func update_from_view(view: Dictionary) -> void:
	var market: Dictionary = view["market"]
	var display: Array = market["display"]
	var legal: Dictionary = view.get("legal", {})
	var affordable: Array = legal.get("recruit_market", [])
	_deck_label.text = "DECK %d" % int(market["deck_size"])

	for i in range(DISPLAY_SLOTS):
		var cid: String = String(display[i]) if i < display.size() else ""
		_fill_slot(i, cid, affordable.has(i))

	# Ghost: верхняя сожранная карта до конца хода считается картой маркета.
	var ghost_card: String = view.get("ghost_market_card", "")
	_boxes[DISPLAY_SLOTS].visible = ghost_card != ""
	if ghost_card != "":
		_fill_slot(DISPLAY_SLOTS, ghost_card,
			affordable.has(Market.DEVOURED_TOP_INDEX))
		_cards[DISPLAY_SLOTS].tooltip_text = "Top devoured card (Ghost)"

	var supplies: Dictionary = view.get("supplies", {})
	var affordable_supply: Array = legal.get("recruit_supply", [])
	for k in range(Supplies.PURCHASABLE.size()):
		var sid: String = Supplies.PURCHASABLE[k]
		var left: int = int(supplies.get(sid, 0))
		_supply_counts[k].text = "×%d" % left
		_supply_counts[k].add_theme_color_override("font_color",
			PixelTheme.TEXT if left > 0 else PixelTheme.DANGER)
		_supply_cards[k].set_clickable(left > 0 and affordable_supply.has(sid))


## Кладёт в слот карту cid (пустая строка — слот пуст). Если карта в слоте
## сменилась, новая въезжает со вспышкой.
func _fill_slot(i: int, cid: String, can_buy: bool) -> void:
	if cid == "":
		_empties[i].visible = true
		if _cards[i] != null:
			_cards[i].visible = false
		return
	_empties[i].visible = false
	var card := _ensure_card(i, cid)
	card.visible = true
	if card.card_id != cid:
		card.set_card(cid)
		card.flash_arrival()
	card.set_clickable(can_buy)


## Карта слота, созданная при первой надобности. Пересоздаётся, только если у
## новой карты лицо другого рода (пиксельное против запасной вёрстки из
## надписей) — переложить такое в уже готовый узел нельзя.
func _ensure_card(i: int, cid: String) -> CardView:
	var card: CardView = _cards[i]
	if card != null and card.is_pixel() != (CardView.mini_texture(cid) != null):
		_boxes[i].remove_child(card)
		card.queue_free()
		card = null
	if card == null:
		card = CardView.new(cid, SLOT.x, SLOT.y)
		card.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Не хватает Influence — карта дёргается и краснеет, вместо того чтобы
		# молча ничего не сделать.
		card.refused.connect(func(_cid: String): card.shake_refusal())
		var index := i if i < DISPLAY_SLOTS else Market.DEVOURED_TOP_INDEX
		card.pressed.connect(func(_cid: String): market_card_clicked.emit(index))
		_boxes[i].add_child(card)
		_cards[i] = card
		card.flash_arrival()
	return card


## Пустой слот: подложка с надписью «empty». Карта кладётся поверх неё.
static func _make_slot() -> Control:
	var box := Control.new()
	box.custom_minimum_size = SLOT
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var empty := PanelContainer.new()
	empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty.add_theme_stylebox_override("panel",
		PixelTheme.box(PixelTheme.PANEL_LO, PixelTheme.BORDER, 1, 1, 1))
	var label := Label.new()
	label.text = "empty"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", PixelTheme.TEXT_OFF)
	empty.add_child(label)
	box.add_child(empty)
	return box


## Остаток общей стопки написан прямо поверх карты — отдельной строки под неё
## в колонке нет.
static func _add_count_label(box: Control) -> Label:
	var left_label := Label.new()
	left_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left_label.offset_top = -11
	left_label.offset_left = 2
	left_label.add_theme_color_override("font_outline_color", PixelTheme.BG)
	left_label.add_theme_constant_override("outline_size", 2)
	box.add_child(left_label)
	return left_label
