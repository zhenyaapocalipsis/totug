class_name CollectionPage
extends VBoxContainer

## Вкладка COLLECTION профиля (решение владельца, 2026-09-30).
##
## Общая строка сверху — пыль, лутбоксы, OPEN BOX и шансы лутбокса. Под ней
## разделы:
##   CARDS — все карты по фракциям; выбранная карта целиком и MAKE FAVOURITE.
##     Здесь же будут альтернативные арты карт;
##   SHADERS — шейдеры (SkinCollection.SHADERS), все ступени ULTRA: список и
##     примерка на любимой карте и двух карточках колоды. Включённый шейдер
##     ложится в партии на всю колоду игрока, со стартовыми картами;
##   CARD BACKS — рубашка (одна на всех): карта, которую можно покрутить;
##   BACKGROUNDS — фон игры (UnderdarkBg), бесплатно.
## Открытый шейдер включается щелчком. Закрытый создаётся за пыль: первый
## щелчок показывает цену, второй создаёт (пыль зря не тратится). Наведение на
## строку списка примеряет шейдер.
##
## Всё сохраняется сразу (SkinCollection пишет в файл профиля); шейдер уйдёт в
## следующую онлайн-партию вместе с профилем.

const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")
const SECTIONS: Array[String] = ["CARDS", "SHADERS", "CARD BACKS", "BACKGROUNDS"]
## Фракции — полуколоды рынка в порядке книги правил; STARTING — стартовая
## колода и общие стопки (шейдер ложится и на них).
const FACTIONS: Array[String] = ["drow", "dragons", "demons", "elementals", "aberrations", "undead", "starting"]
const COLUMNS := 5
const ROWS := 4
const MINI := CardView.MINI_SIZE
const FULL := Vector2(176, 254)
const TAB_SIZE := Vector2(0, 16)
const LIST_BUTTON := Vector2(150, 18)
const ART_LIST_WIDTH := 112
## Примерка шейдера: стартовая карта и карта маркета рядом с любимой —
## видно, что шейдер ложится на всю колоду.
const SAMPLE_CARDS: Array[String] = ["48342", "48306"]
const DEFAULT_FAVOURITE := "48314"

var _dust_label: Label
var _boxes_label: Label
var _open_button: Button
var _note: Label
var _section := "CARDS"
var _section_buttons: Dictionary = {}
var _pages: Dictionary = {}
## CARDS: фракция, её кнопки, сетка, большая карта, «любимая карта».
var _faction := "drow"
var _faction_buttons: Dictionary = {}
var _grid: GridContainer
var _preview: CardView
## Карта -> {tile, card} — плитки текущей фракции.
var _tiles: Dictionary = {}
var _selected := ""
var _favourite_button: Button
## Арты выбранной карты: кнопки ("" — оригинал), просмотренный арт, что второй
## щелчок создаст за пыль, кнопка USE/CRAFT и подсказка.
var _art_list: VBoxContainer
var _art_buttons: Dictionary = {}
var _art_selected := ""
var _pending_art := ""
var _art_action: Button
var _art_hint: Label
## SHADERS: кнопки ("" — без шейдера), примерка, кнопка USE/CRAFT.
var _shader_buttons: Dictionary = {}
var _shader_views: Array[CardView] = []
var _shader_action: Button
var _shader_selected := ""
## Что второй щелчок создаст за пыль ("" — ничего).
var _pending_craft := ""
## CARD BACKS: карта, которую можно покрутить (рубашка и любимая карта).
var _back_preview: CardFlip
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
	top.add_child(_label("BOX: ART EPIC %d%% / LEGENDARY %d%%, SHADER ULTRA %d%%; REPEAT = DUST" % [SkinCollection.BOX_ODDS["epic"],
		SkinCollection.BOX_ODDS["legendary"], SkinCollection.BOX_ODDS[SkinCollection.SHADER_TIER]],
		PixelTheme.TEXT_DIM))

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
	_pages["SHADERS"] = _shaders_page()
	_pages["CARD BACKS"] = _backs_page()
	_pages["BACKGROUNDS"] = _backgrounds_page()
	for section in SECTIONS:
		add_child(_pages[section])
	add_child(_note)

	_shader_selected = SkinCollection.active_shader()
	var fav := PlayerProfile.favourite()
	show_faction(faction_of(fav) if fav != "" else "drow")
	if fav != "" and _tiles.has(fav):
		select(fav)
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


## Раздел по имени (SECTIONS). Разделы одного размера — большего.
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


## Любимая карта игрока (или карта по умолчанию) — на ней примеряются шейдеры.
static func _showcase_card() -> String:
	var fav := PlayerProfile.favourite()
	return fav if fav != "" else DEFAULT_FAVOURITE


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
	_grid.custom_minimum_size = Vector2(COLUMNS * (MINI.x + 2), ROWS * (MINI.y + 2))
	_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(_grid)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 2)
	body.add_child(side)
	_preview = CardView.new(faction_cards("drow")[0], int(FULL.x), int(FULL.y))
	_preview.hover_preview = false
	side.add_child(_preview)
	# Любимая карта — видна в профиле и в карточке игрока у соперников.
	_favourite_button = _button("", func(): toggle_favourite())
	_favourite_button.custom_minimum_size = Vector2(FULL.x, 16)
	side.add_child(_favourite_button)

	# Арты выбранной карты: оригинал и альтернативные (AltArts), открытые
	# включаются, закрытые создаются за пыль.
	var arts := VBoxContainer.new()
	arts.add_theme_constant_override("separation", 3)
	arts.custom_minimum_size = Vector2(ART_LIST_WIDTH, 0)
	body.add_child(arts)
	arts.add_child(_label("ART", PixelTheme.TEXT_DIM))
	_art_list = VBoxContainer.new()
	_art_list.add_theme_constant_override("separation", 3)
	arts.add_child(_art_list)
	_art_action = _button("", press_art)
	_art_action.custom_minimum_size = Vector2(ART_LIST_WIDTH, 16)
	arts.add_child(_art_action)
	_art_hint = _label("", PixelTheme.TEXT_DIM)
	arts.add_child(_art_hint)
	return page


## Карту выбрали: её арты — оригинал и альтернативные. Выбран тот, что включён.
func _fill_art_list(cid: String) -> void:
	for child in _art_list.get_children():
		_art_list.remove_child(child)
		child.queue_free()
	_art_buttons.clear()
	var choices: Array[String] = [""]
	choices.append_array(AltArts.arts_of(cid))
	for art in choices:
		var b := _button("", select_art.bind(art))
		b.custom_minimum_size = Vector2(ART_LIST_WIDTH, 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_art_list.add_child(b)
		_art_buttons[art] = b
	_art_hint.text = "" if choices.size() > 1 else "No alternative\narts for this card."
	_art_selected = SkinCollection.art_of(cid)
	_pending_art = ""


## Просмотр арта выбранной карты ("" — оригинал).
func select_art(art: String) -> void:
	_art_selected = art
	_pending_art = ""
	_set_note("")
	refresh()


func selected_art() -> String:
	return _art_selected


## USE — включить открытый арт (или оригинал); закрытый создать за пыль: первый
## щелчок показывает цену, второй создаёт.
func press_art() -> void:
	var art := _art_selected
	if art == "" or SkinCollection.owns_art(art):
		_pending_art = ""
		SkinCollection.set_art(_selected, art)
		_set_note("")
		Sfx.play("click")
		refresh()
		return
	var tier := AltArts.tier_of(art)
	var cost := SkinCollection.art_cost(art)
	if int(SkinCollection.load_data()["dust"]) < cost:
		_pending_art = ""
		_set_note("Not enough dust: this %s art costs %d." % [SkinCollection.TIER_TITLES[tier], cost])
		Sfx.play("error")
		refresh()
		return
	if _pending_art != art:
		_pending_art = art
		_set_note("Craft this %s art for %d dust? Click again." % [SkinCollection.TIER_TITLES[tier], cost])
		refresh()
		return
	_pending_art = ""
	SkinCollection.craft_art(art)
	_set_note("Crafted: %s art." % SkinCollection.TIER_TITLES[tier])
	Sfx.play("coins")
	refresh()
	_preview.flash_arrival()


## Сделать выбранную карту любимой; она уже любимая — снять.
func toggle_favourite() -> void:
	PlayerProfile.save_favourite("" if PlayerProfile.favourite() == _selected else _selected)
	Sfx.play("click")
	refresh()


## Карты фракции (полуколоды или STARTING), по имени.
static func faction_cards(faction: String) -> Array[String]:
	var ids: Array[String] = []
	if faction == "starting":
		var pool: Array = []
		pool.append_array(GameSetup.starting_deck())
		pool.append_array([Supplies.PRIESTESS_OF_LOLTH, Supplies.HOUSE_GUARD, Supplies.INSANE_OUTCAST])
		for cid in pool:
			if not ids.has(String(cid)):
				ids.append(String(cid))
	else:
		for cid in GameSetup.expand_half_deck(faction):
			if not ids.has(cid):
				ids.append(cid)
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
	select(cards[0])


func _add_tile(cid: String) -> void:
	var card := CardView.new(cid, int(MINI.x), int(MINI.y))
	card.set_art(SkinCollection.art_of(cid))
	card.hover_preview = false
	card.highlight = false
	card.set_clickable(true)
	card.pressed.connect(func(_id: String): select(cid))
	_grid.add_child(card)
	_tiles[cid] = {"tile": card, "card": card}


## Выбрать карту: она справа целиком.
func select(cid: String) -> void:
	_selected = cid
	_set_note("")
	_fill_art_list(cid)
	refresh()


func selected() -> String:
	return _selected


# --- SHADERS -------------------------------------------------------------------

func _shaders_page() -> Control:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(list)
	var choices: Array[String] = [""]
	choices.append_array(SkinCollection.SHADERS)
	for shader in choices:
		var b := _button("", select_shader.bind(shader))
		b.custom_minimum_size = LIST_BUTTON
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_entered.connect(func(): _try_on(shader))
		b.mouse_exited.connect(func(): _try_on(_shader_shown()))
		list.add_child(b)
		_shader_buttons[shader] = b
	var hint := _label("The shader covers your whole\ndeck in a game, starting cards\ntoo. Market cards stay plain.",
		PixelTheme.TEXT_DIM)
	list.add_child(hint)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 3)
	body.add_child(side)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 6)
	side.add_child(cards)
	var big := CardView.new(_showcase_card(), int(FULL.x), int(FULL.y))
	big.hover_preview = false
	cards.add_child(big)
	_shader_views.append(big)
	var minis := VBoxContainer.new()
	minis.add_theme_constant_override("separation", 6)
	cards.add_child(minis)
	for cid in SAMPLE_CARDS:
		var mini := CardView.new(cid, int(MINI.x), int(MINI.y))
		mini.hover_preview = false
		minis.add_child(mini)
		_shader_views.append(mini)
	_shader_action = _button("", press_shader)
	_shader_action.custom_minimum_size = Vector2(FULL.x, 16)
	_shader_action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	side.add_child(_shader_action)
	return body


func _try_on(shader: String) -> void:
	for view in _shader_views:
		view.set_skin(shader)


func _shader_shown() -> String:
	return _pending_craft if _pending_craft != "" else _shader_selected


func select_shader(shader: String) -> void:
	_shader_selected = shader
	_pending_craft = ""
	_set_note("")
	refresh()


func selected_shader() -> String:
	return _shader_selected


## USE — включить открытый шейдер (или снять — PLAIN); закрытый — создать за
## пыль: первый щелчок показывает цену, второй создаёт.
func press_shader() -> void:
	var shader := _shader_selected
	if shader == "" or SkinCollection.owns_shader(shader):
		_pending_craft = ""
		SkinCollection.set_shader(shader)
		_set_note("")
		Sfx.play("click")
		refresh()
		return
	var title := String(SkinCollection.SHADER_TITLES[shader])
	var cost := int(SkinCollection.CRAFT_COST[SkinCollection.SHADER_TIER])
	if int(SkinCollection.load_data()["dust"]) < cost:
		_pending_craft = ""
		_set_note("Not enough dust: %s costs %d." % [title, cost])
		Sfx.play("error")
		refresh()
		return
	if _pending_craft != shader:
		_pending_craft = shader
		_set_note("Craft %s for %d dust? Click again." % [title, cost])
		refresh()
		return
	_pending_craft = ""
	SkinCollection.craft_shader(shader)
	_set_note("Crafted: %s." % title)
	Sfx.play("coins")
	refresh()
	for view in _shader_views:
		view.flash_arrival()


# --- CARD BACKS ----------------------------------------------------------------

func _backs_page() -> Control:
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 3)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	_back_preview = CardFlip.new()
	_back_preview.set_back(CardBack.CLASSIC)
	_back_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	side.add_child(_back_preview)
	var hint := _label("Drag the card to turn it over.\nOpponents see the back when you\ntake a card unseen.",
		PixelTheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(hint)
	return side


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

## Пыль, лутбоксы и надписи кнопок — по файлу профиля.
func refresh() -> void:
	var data := SkinCollection.load_data()
	_dust_label.text = "DUST %d" % int(data["dust"])
	_boxes_label.text = "LOOT BOXES %d" % int(data["boxes"])
	_open_button.disabled = int(data["boxes"]) <= 0
	var worn := String(data["shader"])

	for cid: String in _tiles:
		var card: CardView = _tiles[cid]["card"]
		card.highlight = cid == _selected
		card.queue_redraw()
	var is_favourite := PlayerProfile.favourite() == _selected
	_favourite_button.text = "YOUR FAVOURITE CARD" if is_favourite else "MAKE FAVOURITE"
	_tint(_favourite_button, PixelTheme.GOLD if is_favourite else PixelTheme.TEXT)

	# Арты выбранной карты: большая карта показывает просматриваемый, мини в
	# сетке — включённые.
	var worn_art := SkinCollection.art_of(_selected)
	_preview.set_card(_selected)
	_preview.set_art(_art_selected)
	for cid: String in _tiles:
		(_tiles[cid]["card"] as CardView).set_art(SkinCollection.art_of(cid))
	for art: String in _art_buttons:
		var b: Button = _art_buttons[art]
		var has := art == "" or SkinCollection.owns_art(art)
		var tier := AltArts.tier_of(art)
		var title := "ORIGINAL" if art == "" else "%s %s" % [SkinCollection.TIER_TITLES[tier], art.get_slice("_", 1)]
		var state := "  ON" if art == worn_art else ("" if has else "  %d" % SkinCollection.art_cost(art))
		b.text = " %s%s" % [title, state]
		var tint := PixelTheme.TEXT if art == "" else Color(SkinCollection.TIER_COLOURS[tier])
		_tint(b, PixelTheme.GOLD if art == worn_art else (tint if has else tint.darkened(0.45)))
		b.set_pressed_no_signal(art == _art_selected)
	_art_action.visible = _art_buttons.size() > 1
	if _art_selected == worn_art:
		_art_action.text = "IN USE"
	elif _art_selected == "" or SkinCollection.owns_art(_art_selected):
		_art_action.text = "USE"
	else:
		_art_action.text = "CRAFT %d" % SkinCollection.art_cost(_art_selected)
	_art_action.disabled = _art_selected == worn_art

	var ultra := Color(SkinCollection.TIER_COLOURS[SkinCollection.SHADER_TIER])
	var cost := int(SkinCollection.CRAFT_COST[SkinCollection.SHADER_TIER])
	for shader: String in _shader_buttons:
		var b: Button = _shader_buttons[shader]
		var has := shader == "" or SkinCollection.owns_shader(shader)
		var title := "PLAIN" if shader == "" else String(SkinCollection.SHADER_TITLES[shader])
		var state := "  ON" if shader == worn else ("" if has else "  %d" % cost)
		b.text = " %s%s" % [title, state]
		var colour := PixelTheme.TEXT if shader == "" else Color(SkinCollection.SHADER_COLOURS[shader])
		_tint(b, PixelTheme.GOLD if shader == worn else (colour if has else ultra.darkened(0.45)))
		b.set_pressed_no_signal(shader == _shader_selected)
	_shader_views[0].set_card(_showcase_card())
	_try_on(_shader_shown())
	if _shader_selected == worn:
		_shader_action.text = "IN USE"
	elif _shader_selected == "" or SkinCollection.owns_shader(_shader_selected):
		_shader_action.text = "USE"
	else:
		_shader_action.text = "CRAFT ULTRA %d" % cost
	_shader_action.disabled = _shader_selected == worn

	_back_preview.set_face(_showcase_card(), worn)

	for style: String in _bg_buttons:
		var b: Button = _bg_buttons[style]
		b.text = String(UnderdarkBg.STYLE_NAMES[style]) + ("  ON" if style == UnderdarkBg.style() else "")
		_tint(b, PixelTheme.GOLD if style == UnderdarkBg.style() else PixelTheme.TEXT)


## Открыть лутбокс: выпавший шейдер открывается в разделе SHADERS, пыль —
## просто строкой снизу.
func open_box() -> Dictionary:
	var got := SkinCollection.open_box(_rng)
	if got.is_empty():
		return got
	var tier := String(got["tier"])
	var colour := Color(SkinCollection.TIER_COLOURS[tier])
	var shader := String(got["shader"])
	var art := String(got["art"])
	if art != "" and not got["duplicate"]:
		var cid := AltArts.card_of(art)
		show_section("CARDS")
		show_faction(faction_of(cid))
		select(cid)
		select_art(art)
		_set_note("New %s art: %s!" % [SkinCollection.TIER_TITLES[tier], EventLogPanel.card_name(cid)], colour)
		Sfx.play("victory")
		_preview.flash_arrival()
		return got
	if shader == "":
		refresh()
		_set_note("%s: +%d dust." % [SkinCollection.TIER_TITLES[tier], int(got["dust"])], colour)
		Sfx.play("coins")
		return got
	show_section("SHADERS")
	select_shader(shader)
	var title := String(SkinCollection.SHADER_TITLES[shader])
	if got["duplicate"]:
		_set_note("Already had the %s shader: +%d dust." % [title, int(got["dust"])], colour)
		Sfx.play("coins")
	else:
		_set_note("New shader: %s!" % title, colour)
		Sfx.play("victory")
		for view in _shader_views:
			view.flash_arrival()
	return got
