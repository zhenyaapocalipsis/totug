extends Control

## CARDS: библиотека всех карт игры (меню LIBRARY → CARDS).
##
## Вкладки: STARTING (стартовая колода и стопки запаса) и шесть полуколод
## рынка. Карты вкладки — мелкими лицами (как на полосах в партии) с числом
## копий под каждой, по цене. Наведение показывает полную карту по центру,
## Alt — крупнее: тот же CardPreview, что и в партии.
##
## Стрелки листают вкладки, Esc — назад в меню. Вёрстка кодом, как у
## остальных экранов меню.

signal closed

const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")

const STARTING := "starting"
## Порядок вкладок полуколод — как в half_decks.json (и в книге правил).
const HALF_DECKS := ["drow", "dragons", "demons", "elementals", "aberrations", "undead"]
const TAB_SIZE := Vector2(72, 16)
const BUTTON_SIZE := Vector2(70, 16)
const COLUMNS := 10
## Размер мелкого лица карты (CardView.MINI_SIZE).
const CARD := Vector2(80, 76)
## Высота места под сеткой: две строки по 10 карт с подписями — полуколода
## целиком, окно не прыгает при смене вкладки.
const GRID_H := 2 * (76 + 12) + 4

var _tab := 0
var _tabs: Array[Button] = []
var _note: Label
var _grid: GridContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()
	add_child(UnderdarkBg.make())

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", GameScreen.zone_style(6))
	centre.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var head := Label.new()
	head.text = "CARDS"
	head.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	head.add_theme_color_override("font_color", PixelTheme.GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 4)
	col.add_child(tabs)
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

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_grid.custom_minimum_size.y = GRID_H
	col.add_child(_grid)

	col.add_child(HSeparator.new())
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = BUTTON_SIZE
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	SetupScreen._style_button(back)
	back.pressed.connect(func(): closed.emit())
	col.add_child(back)

	var hint := Label.new()
	hint.text = "Point at a card to see it in full, hold Alt for bigger. Arrows switch tabs."
	hint.add_theme_color_override("font_color", PixelTheme.TEXT_OFF)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

	# Полная карта под курсором — поверх всего экрана, как в партии.
	var preview := CardPreview.new()
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(preview)

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
	for c: Dictionary in cards:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 1)
		var view := CardView.new(String(c["id"]), int(CARD.x), int(CARD.y), -1)
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
