extends Control

## CARDS: библиотека всех карт игры (меню LIBRARY → CARDS).
##
## Вкладки: STARTING (стартовая колода и стопки запаса) и шесть полуколод
## рынка. Карты вкладки — сразу в полном формате 176x254, 1:1, по пять в ряд,
## с числом копий под каждой, по цене (решение владельца, 2026-09-26).
## Полуколода в экран не влезает — список прокручивается колесом мыши.
##
## Стрелки влево/вправо листают вкладки, вверх/вниз — ряды карт, Esc — назад
## в меню. Вёрстка кодом, как у остальных экранов меню.

signal closed

const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")

const STARTING := "starting"
## Порядок вкладок полуколод — как в half_decks.json (и в книге правил).
const HALF_DECKS := ["drow", "dragons", "demons", "elementals", "aberrations", "undead"]
const TAB_SIZE := Vector2(72, 16)
const BUTTON_SIZE := Vector2(70, 16)
const COLUMNS := 5
const GAP := 4
## Полная карта в родном размере (CardView.PIXEL_SIZE).
const CARD := Vector2(176, 254)
## Высота подписи с числом копий под картой.
const LABEL_H := 11
## Шаг прокрутки стрелками — ровно один ряд карт.
const ROW_STEP := 254 + 1 + LABEL_H + GAP
const MARGIN := 6

var _tab := 0
var _tabs: Array[Button] = []
var _note: Label
var _scroll: ScrollContainer
var _grid: GridContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()
	add_child(UnderdarkBg.make())

	# Окно во весь экран: чем больше места, тем больше полных карт видно.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", GameScreen.zone_style(6))
	margin.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	# Верхняя строка: BACK слева, вкладки по центру оставшегося места.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	col.add_child(top)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = BUTTON_SIZE
	SetupScreen._style_button(back)
	back.pressed.connect(func(): closed.emit())
	top.add_child(back)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("separation", 4)
	top.add_child(tabs)
	# Пустышка шириной с BACK — чтобы вкладки стояли ровно по центру окна.
	var spacer := Control.new()
	spacer.custom_minimum_size = BUTTON_SIZE
	top.add_child(spacer)
	var group := ButtonGroup.new()
	for i in tab_count():
		var b := Button.new()
		b.text = tab_key(i).to_upper()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = TAB_SIZE
		SetupScreen._style_button(b)
		b.pressed.connect(func(): show_tab(i))
		tabs.add_child(b)
		_tabs.append(b)

	_note = Label.new()
	_note.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_note)
	col.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.scroll_vertical_custom_step = ROW_STEP / 3.0
	# Полоса прокрутки темы без ширины невидима, а здесь она подсказывает,
	# что карт больше, чем видно.
	_scroll.get_v_scroll_bar().custom_minimum_size.x = 4
	col.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	_scroll.add_child(_grid)

	show_tab(0)


func tab_count() -> int:
	return HALF_DECKS.size() + 1


func tab_key(index: int) -> String:
	return STARTING if index == 0 else String(HALF_DECKS[index - 1])


func current_tab() -> int:
	return _tab


## Карты вкладки: [{id, copies, label}] по цене, затем по имени.
static func tab_cards(key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if key == STARTING:
		var start := _copies(GameSetup.starting_deck())
		for cid: String in _sorted(start.keys()):
			result.append({"id": cid, "copies": start[cid], "label": "x%d" % start[cid]})
		for cid: String in _sorted([Supplies.PRIESTESS_OF_LOLTH, Supplies.HOUSE_GUARD,
				Supplies.INSANE_OUTCAST]):
			result.append({"id": cid, "copies": 0, "label": "SUPPLY"})
		return result
	var copies := _copies(GameSetup.expand_half_deck(key))
	for cid: String in _sorted(copies.keys()):
		result.append({"id": cid, "copies": copies[cid], "label": "x%d" % copies[cid]})
	return result


func show_tab(index: int) -> void:
	_tab = clampi(index, 0, tab_count() - 1)
	_tabs[_tab].button_pressed = true
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var key := tab_key(_tab)
	var cards := tab_cards(key)
	if key == STARTING:
		_note.text = "Every player starts with these 10 cards. Supply cards are bought or gained."
	else:
		var total := 0
		for c: Dictionary in cards:
			total += int(c["copies"])
		_note.text = "%s: %d different cards, %d in all." % [
			key.capitalize() + " Half-Deck", cards.size(), total]
	_note.text += "   Mouse wheel scrolls, arrows switch tabs."
	_scroll.scroll_vertical = 0
	for c: Dictionary in cards:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 1)
		var view := CardView.new(String(c["id"]), int(CARD.x), int(CARD.y))
		# Карта и так полная — копия под курсором не нужна.
		view.hover_preview = false
		cell.add_child(view)
		var label := Label.new()
		label.text = String(c["label"])
		label.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(label)
		_grid.add_child(cell)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_RIGHT, KEY_D:
			show_tab((_tab + 1) % tab_count())
		KEY_LEFT, KEY_A:
			show_tab((_tab + tab_count() - 1) % tab_count())
		KEY_DOWN, KEY_S:
			_scroll.scroll_vertical += ROW_STEP
		KEY_UP, KEY_W:
			_scroll.scroll_vertical -= ROW_STEP
		KEY_ESCAPE:
			closed.emit()
		_:
			return
	get_viewport().set_input_as_handled()


static func _copies(ids: Array[String]) -> Dictionary:
	var result := {}
	for cid in ids:
		result[cid] = int(result.get(cid, 0)) + 1
	return result


static func _sorted(ids: Array) -> Array:
	var result := ids.duplicate()
	result.sort_custom(func(a: String, b: String) -> bool:
		var ca := CardLibrary.card_cost(a)
		var cb := CardLibrary.card_cost(b)
		if ca != cb:
			return ca < cb
		return String(CardLibrary.card_data(a).get("name", a)) < String(CardLibrary.card_data(b).get("name", b)))
	return result
