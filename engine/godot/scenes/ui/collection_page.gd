class_name CollectionPage
extends VBoxContainer

## Вкладка COLLECTION профиля (решение владельца, 2026-09-30).
##
## Общая строка сверху — пыль, лутбоксы, OPEN BOX и шансы лутбокса. Под ней
## три раздела:
##   CARDS — образы карт (SkinCollection), карты по фракциям: слева сетка
##     фракции (под картой три метки — какие ступени открыты), справа
##     выбранная карта целиком и кнопки PLAIN / EPIC / LEGENDARY / ULTRA;
##   CARD BACKS — рубашки (CardBack), ступень ULTRA: список и рубашка целиком;
##   BACKGROUNDS — фон игры (UnderdarkBg), бесплатно.
## Открытое включается щелчком. Закрытое создаётся за пыль: первый щелчок
## показывает цену, второй создаёт (пыль зря не тратится). Наведение на
## кнопку примеряет её на большой карте или рубашке.
##
## Всё сохраняется сразу (SkinCollection пишет в файл профиля); образы и
## рубашка уйдут в следующую онлайн-партию вместе с профилем.

const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")
const SECTIONS: Array[String] = ["CARDS", "CARD BACKS", "BACKGROUNDS"]
## Фракции — полуколоды рынка в порядке книги правил; SUPPLY — общие стопки.
const FACTIONS: Array[String] = ["drow", "dragons", "demons", "elementals", "aberrations", "undead", "supply"]
const COLUMNS := 5
const ROWS := 4
const MINI := Vector2(80, 76)
const FULL := Vector2(176, 254)
const MARK := Vector2(8, 3)
const MARK_OFF := Color("2a1f45")
const TAB_SIZE := Vector2(0, 16)
const TIER_BUTTON := Vector2(86, 16)
const LIST_BUTTON := Vector2(150, 18)
## Кнопки ступеней: "" — карта без образа.
const CHOICES: Array[String] = ["", "epic", "legendary", "ultra"]

var _dust_label: Label
var _boxes_label: Label
var _open_button: Button
var _note: Label
var _section := "CARDS"
var _section_buttons: Dictionary = {}
var _pages: Dictionary = {}
## CARDS: фракция, её кнопки, сетка, большая карта и кнопки ступеней.
var _faction := "drow"
var _faction_buttons: Dictionary = {}
var _grid: GridContainer
var _preview: CardView
var _tier_buttons: Dictionary = {}
## Карта -> {tile, card, marks} — плитки текущей фракции.
var _tiles: Dictionary = {}
var _selected := ""
## Что второй щелчок создаст за пыль: ступень карты или рубашка ("" — ничего).
var _pending_craft := ""
## CARD BACKS: кнопки рубашек, большая рубашка, кнопка USE/CRAFT.
var _back_buttons: Dictionary = {}
var _back_preview: TextureRect
var _back_action: Button
var _back_selected := CardBack.CLASSIC
## BACKGROUNDS: кнопки фонов.
var _bg_buttons: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	add_theme_constant_override("separation", 4)

	# Общая строка: пыль, лутбоксы, OPEN BOX и шансы.
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 10)
	top.tooltip_text = "FIND GAME: 1st place - a loot box, other places - dust."
	add_child(top)
	_dust_label = _label("", PixelTheme.TEXT)
	top.add_child(_dust_label)
	_boxes_label = _label("", PixelTheme.GOLD)
	top.add_child(_boxes_label)
	_open_button = _button("OPEN BOX", func(): open_box())
	_open_button.custom_minimum_size = Vector2(70, 16)
	top.add_child(_open_button)
	var odds: Array[String] = []
	for tier in SkinCollection.TIERS:
		odds.append("%s %d%%" % [SkinCollection.TIER_TITLES[tier], SkinCollection.BOX_ODDS[tier]])
	top.add_child(_label("%s (CARD BACKS ARE ULTRA)" % "  ".join(odds), PixelTheme.TEXT_DIM))

	var sections := HBoxContainer.new()
	sections.alignment = BoxContainer.ALIGNMENT_CENTER
	sections.add_theme_constant_override("separation", 4)
	add_child(sections)
	var group := ButtonGroup.new()
	for section in SECTIONS:
		var b := _button(section, show_section.bind(section))
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(80, 16)
		sections.add_child(b)
		_section_buttons[section] = b

	_note = _label("", PixelTheme.GOLD)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pages["CARDS"] = _cards_page()
	_pages["CARD BACKS"] = _backs_page()
	_pages["BACKGROUNDS"] = _backgrounds_page()
	for section in SECTIONS:
		add_child(_pages[section])
	add_child(_note)

	_back_selected = SkinCollection.active_back() if SkinCollection.active_back() != "" else CardBack.CLASSIC
	# Первой открыта фракция, где уже есть образ (или DROW).
	var start := "drow"
	for item in (SkinCollection.load_data()["owned"] as Array):
		var cid := String(item).get_slice(":", 0)
		if cid != SkinCollection.BACK_PREFIX:
			start = faction_of(cid)
			break
	show_faction(start)
	show_section("CARDS")


func _label(text: String, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", colour)
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = TAB_SIZE
	SetupScreen._style_button(b)
	b.pressed.connect(action)
	return b


static func _tint(b: Button, colour: Color) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, colour)


## Раздел CARDS, CARD BACKS или BACKGROUNDS. Разделы одного размера — большего.
func show_section(section: String) -> void:
	_section = section
	_pending_craft = ""
	_set_note("")
	var need := Vector2.ZERO
	for p: Control in _pages.values():
		p.custom_minimum_size = Vector2.ZERO
	for p: Control in _pages.values():
		need = need.max(p.get_combined_minimum_size())
	for key: String in _pages:
		(_pages[key] as Control).custom_minimum_size = need
		(_pages[key] as Control).visible = key == section
	for key: String in _section_buttons:
		(_section_buttons[key] as Button).set_pressed_no_signal(key == section)
	refresh()


func section() -> String:
	return _section


func _set_note(text: String, colour: Color = PixelTheme.GOLD) -> void:
	_note.text = text
	_note.add_theme_color_override("font_color", colour)


# --- CARDS ---------------------------------------------------------------------

func _cards_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 4)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 3)
	page.add_child(tabs)
	var group := ButtonGroup.new()
	for faction in FACTIONS:
		var b := _button(faction.to_upper(), show_faction.bind(faction))
		b.toggle_mode = true
		b.button_group = group
		tabs.add_child(b)
		_faction_buttons[faction] = b

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(body)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	_grid.custom_minimum_size = Vector2(COLUMNS * (MINI.x + 2), ROWS * (MINI.y + MARK.y + 3))
	_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(_grid)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 2)
	body.add_child(side)
	var first := faction_cards("drow")[0]
	_preview = CardView.new(first, int(FULL.x), int(FULL.y))
	_preview.hover_preview = false
	side.add_child(_preview)
	var choices := GridContainer.new()
	choices.columns = 2
	choices.add_theme_constant_override("h_separation", 4)
	choices.add_theme_constant_override("v_separation", 2)
	side.add_child(choices)
	for tier in CHOICES:
		var b := _button("", press_tier.bind(tier))
		b.custom_minimum_size = TIER_BUTTON
		# Наведение примеряет ступень на большой карте.
		b.mouse_entered.connect(func(): _preview.set_skin(tier))
		b.mouse_exited.connect(func(): _preview.set_skin(_card_shown_tier()))
		choices.add_child(b)
		_tier_buttons[tier] = b
	return page


## Карты фракции (полуколоды или SUPPLY), по имени.
static func faction_cards(faction: String) -> Array[String]:
	var ids: Array[String] = []
	if faction == "supply":
		ids = [Supplies.PRIESTESS_OF_LOLTH, Supplies.HOUSE_GUARD]
	else:
		for cid in GameSetup.expand_half_deck(faction):
			if not ids.has(cid):
				ids.append(cid)
	ids = ids.filter(func(cid: String) -> bool: return SkinCollection.is_skinnable(cid))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return EventLogPanel.card_name(a) < EventLogPanel.card_name(b))
	return ids


static func faction_of(cid: String) -> String:
	for faction in FACTIONS:
		if faction_cards(faction).has(cid):
			return faction
	return "drow"


func show_faction(faction: String) -> void:
	_faction = faction
	for key: String in _faction_buttons:
		(_faction_buttons[key] as Button).set_pressed_no_signal(key == faction)
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_tiles.clear()
	var cards := faction_cards(faction)
	for cid in cards:
		_add_tile(cid)
	var owned: Array = SkinCollection.load_data()["owned"]
	var pick := cards[0]
	for cid in cards:
		for tier in SkinCollection.TIERS:
			if owned.has(SkinCollection.skin_key(cid, tier)):
				pick = cid
				break
		if pick != cards[0]:
			break
	select(pick)


func _add_tile(cid: String) -> void:
	var tile := VBoxContainer.new()
	tile.add_theme_constant_override("separation", 1)
	var card := CardView.new(cid, int(MINI.x), int(MINI.y))
	card.hover_preview = false
	card.highlight = false
	card.set_clickable(true)
	card.pressed.connect(func(_id: String): select(cid))
	tile.add_child(card)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	var marks: Array[ColorRect] = []
	for tier in SkinCollection.TIERS:
		var mark := ColorRect.new()
		mark.custom_minimum_size = MARK
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)
		marks.append(mark)
	tile.add_child(row)
	_grid.add_child(tile)
	_tiles[cid] = {"tile": tile, "card": card, "marks": marks}


## Выбрать карту: она справа целиком, кнопки — про её ступени.
func select(cid: String) -> void:
	_selected = cid
	_pending_craft = ""
	_set_note("")
	_preview.set_card(cid)
	refresh()


func selected() -> String:
	return _selected


func _card_shown_tier() -> String:
	if _pending_craft != "" and SkinCollection.TIERS.has(_pending_craft):
		return _pending_craft
	return String(SkinCollection.active().get(_selected, ""))


## Кнопка ступени: открытая — включить; закрытая — первый щелчок показывает
## цену и примеряет, второй создаёт за пыль.
func press_tier(tier: String) -> void:
	if tier == "" or SkinCollection.owns(_selected, tier):
		_pending_craft = ""
		SkinCollection.set_active(_selected, tier)
		_set_note("")
		Sfx.play("click")
		refresh()
		return
	if not _can_pay(tier, SkinCollection.TIER_TITLES[tier]):
		return
	if _pending_craft != tier:
		_ask_craft(tier, SkinCollection.TIER_TITLES[tier])
		return
	_pending_craft = ""
	SkinCollection.craft(_selected, tier)
	_crafted("%s %s" % [SkinCollection.TIER_TITLES[tier], EventLogPanel.card_name(_selected)])
	_preview.flash_arrival()


func _can_pay(tier: String, title: String) -> bool:
	var cost := int(SkinCollection.CRAFT_COST[tier])
	if int(SkinCollection.load_data()["dust"]) >= cost:
		return true
	_pending_craft = ""
	_set_note("Not enough dust: %s costs %d." % [title, cost])
	Sfx.play("error")
	refresh()
	return false


func _ask_craft(what: String, title: String) -> void:
	_pending_craft = what
	var tier: String = what if SkinCollection.TIERS.has(what) else SkinCollection.BACK_TIER
	_set_note("Craft %s for %d dust? Click again." % [title, SkinCollection.CRAFT_COST[tier]])
	refresh()


func _crafted(title: String) -> void:
	_set_note("Crafted: %s." % title)
	Sfx.play("coins")
	refresh()


# --- CARD BACKS ----------------------------------------------------------------

func _backs_page() -> Control:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(list)
	for design in CardBack.DESIGNS:
		var b := _button("", select_back.bind(design))
		b.custom_minimum_size = LIST_BUTTON
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_entered.connect(func(): _back_preview.texture = CardBack.texture(design))
		b.mouse_exited.connect(func(): _back_preview.texture = CardBack.texture(_back_selected))
		list.add_child(b)
		_back_buttons[design] = b
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 3)
	body.add_child(side)
	_back_preview = TextureRect.new()
	_back_preview.custom_minimum_size = FULL
	_back_preview.stretch_mode = TextureRect.STRETCH_KEEP
	_back_preview.texture = CardBack.texture(CardBack.CLASSIC)
	side.add_child(_back_preview)
	_back_action = _button("", press_back)
	_back_action.custom_minimum_size = Vector2(FULL.x, 16)
	side.add_child(_back_action)
	var hint := _label("Opponents see it when you\ntake a card unseen.", PixelTheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(hint)
	return body


func select_back(design: String) -> void:
	_back_selected = design
	_pending_craft = ""
	_set_note("")
	refresh()


func selected_back() -> String:
	return _back_selected


## USE — надеть открытую рубашку; закрытую — создать за пыль (два щелчка).
func press_back() -> void:
	var design := _back_selected
	var title := String(CardBack.NAMES[design])
	if SkinCollection.owns_back(design):
		_pending_craft = ""
		SkinCollection.set_back(design)
		_set_note("")
		Sfx.play("click")
		refresh()
		return
	if not _can_pay(SkinCollection.BACK_TIER, title):
		return
	if _pending_craft != design:
		_ask_craft(design, title)
		return
	_pending_craft = ""
	SkinCollection.craft_back(design)
	_crafted(title)


# --- BACKGROUNDS ---------------------------------------------------------------

func _backgrounds_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 4)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	var hint := _label("The background of the menus and of the game. Free for everyone.", PixelTheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(hint)
	for style in UnderdarkBg.STYLES:
		var b := _button(String(UnderdarkBg.STYLE_NAMES[style]), func():
			UnderdarkBg.set_style(style)
			Sfx.play("click")
			refresh())
		b.custom_minimum_size = LIST_BUTTON
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		page.add_child(b)
		_bg_buttons[style] = b
	return page


# --- общее ---------------------------------------------------------------------

## Пыль, лутбоксы, метки и надписи кнопок — по файлу профиля.
func refresh() -> void:
	var data := SkinCollection.load_data()
	_dust_label.text = "DUST %d" % int(data["dust"])
	_boxes_label.text = "LOOT BOXES %d" % int(data["boxes"])
	_open_button.disabled = int(data["boxes"]) <= 0
	var owned: Array = data["owned"]
	var active: Dictionary = data["active"]

	for cid: String in _tiles:
		var t: Dictionary = _tiles[cid]
		(t["card"] as CardView).set_skin(String(active.get(cid, "")))
		(t["card"] as CardView).highlight = cid == _selected
		(t["card"] as CardView).queue_redraw()
		for i in SkinCollection.TIERS.size():
			var tier := SkinCollection.TIERS[i]
			(t["marks"][i] as ColorRect).color = Color(SkinCollection.TIER_COLOURS[tier]) \
				if owned.has(SkinCollection.skin_key(cid, tier)) else MARK_OFF
	var on := String(active.get(_selected, ""))
	_preview.set_skin(_card_shown_tier())
	for tier: String in _tier_buttons:
		var b: Button = _tier_buttons[tier]
		var colour := PixelTheme.TEXT if tier == "" else Color(SkinCollection.TIER_COLOURS[tier])
		var title := "PLAIN" if tier == "" else String(SkinCollection.TIER_TITLES[tier])
		if tier == "" or owned.has(SkinCollection.skin_key(_selected, tier)):
			b.text = title + (" ON" if tier == on else "")
		else:
			b.text = "%s %d" % [title, SkinCollection.CRAFT_COST[tier]]
			colour = colour.darkened(0.35)
		_tint(b, PixelTheme.GOLD if tier == on else colour)

	var worn := SkinCollection.active_back()
	worn = worn if worn != "" else CardBack.CLASSIC
	var ultra := Color(SkinCollection.TIER_COLOURS[SkinCollection.BACK_TIER])
	for design: String in _back_buttons:
		var b: Button = _back_buttons[design]
		var has := SkinCollection.owns_back(design)
		var state := "  ON" if design == worn else ("" if has else "  %d" % SkinCollection.CRAFT_COST[SkinCollection.BACK_TIER])
		b.text = " %s%s" % [CardBack.NAMES[design], state]
		_tint(b, PixelTheme.GOLD if design == worn else (ultra if has else ultra.darkened(0.45)))
		b.set_pressed_no_signal(design == _back_selected)
	_back_preview.texture = CardBack.texture(_back_selected)
	if _back_selected == worn:
		_back_action.text = "IN USE"
	elif SkinCollection.owns_back(_back_selected):
		_back_action.text = "USE"
	else:
		_back_action.text = "CRAFT ULTRA %d" % SkinCollection.CRAFT_COST[SkinCollection.BACK_TIER]
	_back_action.disabled = _back_selected == worn

	for style: String in _bg_buttons:
		var b: Button = _bg_buttons[style]
		b.text = String(UnderdarkBg.STYLE_NAMES[style]) + ("  ON" if style == UnderdarkBg.style() else "")
		_tint(b, PixelTheme.GOLD if style == UnderdarkBg.style() else PixelTheme.TEXT)


## Открыть лутбокс: выпавшая карта или рубашка открывается в своём разделе.
func open_box() -> Dictionary:
	var got := SkinCollection.open_box(_rng)
	if got.is_empty():
		return got
	var tier := String(got["tier"])
	var title := ""
	if got.has("back"):
		show_section("CARD BACKS")
		select_back(String(got["back"]))
		title = "card back %s" % CardBack.NAMES[got["back"]]
	else:
		var cid := String(got["card"])
		show_section("CARDS")
		show_faction(faction_of(cid))
		select(cid)
		title = "%s %s" % [SkinCollection.TIER_TITLES[tier], EventLogPanel.card_name(cid)]
		_preview.set_skin(tier)
		_preview.flash_arrival()
	var colour := Color(SkinCollection.TIER_COLOURS[tier])
	if got["duplicate"]:
		_set_note("Already had %s: +%d dust." % [title, int(got["dust"])], colour)
		Sfx.play("coins")
	else:
		_set_note("New: %s!" % title, colour)
		Sfx.play("victory" if tier != "epic" else "card")
	return got
