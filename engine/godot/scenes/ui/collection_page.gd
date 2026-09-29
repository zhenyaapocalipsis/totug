class_name CollectionPage
extends VBoxContainer

## Вкладка COLLECTION профиля: образы карт (SkinCollection).
##
## Сверху — пыль, лутбоксы и OPEN BOX. Слева — все карты, у которых бывают
## образы (мелкие лица; под каждой три метки: какие ступени открыты). Справа —
## выбранная карта целиком и четыре кнопки: PLAIN (без образа) и ступени.
## Открытая ступень включается щелчком. Закрытую можно создать за пыль:
## первый щелчок показывает цену, второй — создаёт (пыль зря не тратится).
## Наведение на кнопку ступени примеряет её на большой карте.
##
## Всё сохраняется сразу (SkinCollection пишет в файл профиля); включённые
## образы уйдут в следующую онлайн-партию вместе с профилем.

const COLUMNS := 4
const MINI := Vector2(80, 76)
const FULL := Vector2(176, 254)
const MARK := Vector2(8, 3)
const MARK_OFF := Color("2a1f45")
const TIER_BUTTON := Vector2(86, 16)
## Кнопки ступеней: "" — карта без образа.
const CHOICES: Array[String] = ["", "epic", "legendary", "ultra"]

var _dust_label: Label
var _boxes_label: Label
var _open_button: Button
var _note: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _preview: CardView
var _tier_buttons: Dictionary = {}
## Карта -> {tile, card, marks}.
var _tiles: Dictionary = {}
var _selected := ""
## Ступень, которую второй щелчок создаст за пыль ("" — ничего не ждём).
var _pending_craft := ""
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	add_theme_constant_override("separation", 4)

	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	_dust_label = _label("", PixelTheme.TEXT)
	top.add_child(_dust_label)
	_boxes_label = _label("", PixelTheme.GOLD)
	top.add_child(_boxes_label)
	_open_button = Button.new()
	_open_button.text = "OPEN BOX"
	_open_button.custom_minimum_size = Vector2(70, 16)
	SetupScreen._style_button(_open_button)
	_open_button.pressed.connect(func(): open_box())
	top.add_child(_open_button)

	var odds: Array[String] = []
	for tier in SkinCollection.TIERS:
		odds.append("%s %d%%" % [SkinCollection.TIER_TITLES[tier], SkinCollection.BOX_ODDS[tier]])
	var hint := _label("FIND GAME: 1st place - a loot box, other places - dust.\nA box holds a random skin: %s."
		% ", ".join(odds), PixelTheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(body)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(COLUMNS * (MINI.x + 2) + 10, FULL.y + 2 * TIER_BUTTON.y + 20)
	body.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 3)
	_scroll.add_child(_grid)
	var cards := SkinCollection.skinnable_cards()
	cards.sort_custom(func(a: String, b: String) -> bool:
		return EventLogPanel.card_name(a) < EventLogPanel.card_name(b))
	for cid in cards:
		_add_tile(cid)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 2)
	body.add_child(side)
	var owned: Array = SkinCollection.load_data()["owned"]
	var first := String(owned[0]).get_slice(":", 0) if not owned.is_empty() else cards[0]
	_preview = CardView.new(first, int(FULL.x), int(FULL.y))
	_preview.hover_preview = false
	side.add_child(_preview)
	var choices := GridContainer.new()
	choices.columns = 2
	choices.add_theme_constant_override("h_separation", 4)
	choices.add_theme_constant_override("v_separation", 2)
	side.add_child(choices)
	for tier in CHOICES:
		var b := Button.new()
		b.custom_minimum_size = TIER_BUTTON
		SetupScreen._style_button(b)
		b.pressed.connect(func(): press_tier(tier))
		# Наведение примеряет ступень на большой карте.
		b.mouse_entered.connect(func(): _try_on(tier))
		b.mouse_exited.connect(func(): _try_on(_active_tier()))
		choices.add_child(b)
		_tier_buttons[tier] = b

	_note = _label("", PixelTheme.GOLD)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_note)

	select(first)


func _label(text: String, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", colour)
	return l


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
	_note.text = ""
	_note.add_theme_color_override("font_color", PixelTheme.GOLD)
	_preview.set_card(cid)
	scroll_to_selected()
	refresh()


## Прокрутить сетку к выбранной карте (на кадр позже: сетка должна быть
## уже разложена).
func scroll_to_selected() -> void:
	if _scroll.is_inside_tree():
		_scroll.ensure_control_visible.call_deferred(_tiles[_selected]["tile"])


func selected() -> String:
	return _selected


func _active_tier() -> String:
	return String(SkinCollection.active().get(_selected, ""))


func _try_on(tier: String) -> void:
	_preview.set_skin(tier)


## Пыль, лутбоксы, метки под картами и надписи кнопок — по файлу профиля.
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
	_preview.set_skin(_pending_craft if _pending_craft != "" else on)
	for tier: String in _tier_buttons:
		var b: Button = _tier_buttons[tier]
		var colour := PixelTheme.TEXT if tier == "" else Color(SkinCollection.TIER_COLOURS[tier])
		var title := "PLAIN" if tier == "" else String(SkinCollection.TIER_TITLES[tier])
		if tier == "" or owned.has(SkinCollection.skin_key(_selected, tier)):
			b.text = title + (" ON" if tier == on else "")
		else:
			b.text = "%s %d" % [title, SkinCollection.CRAFT_COST[tier]]
			b.tooltip_text = "Craft for %d dust." % SkinCollection.CRAFT_COST[tier]
			colour = colour.darkened(0.35)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(state, PixelTheme.GOLD if tier == on else colour)


## Кнопка ступени: открытая — включить; закрытая — первый щелчок показывает
## цену и примеряет, второй создаёт за пыль.
func press_tier(tier: String) -> void:
	if tier == "" or SkinCollection.owns(_selected, tier):
		_pending_craft = ""
		SkinCollection.set_active(_selected, tier)
		_note.text = ""
		Sfx.play("click")
		refresh()
		return
	var cost := int(SkinCollection.CRAFT_COST[tier])
	if int(SkinCollection.load_data()["dust"]) < cost:
		_pending_craft = ""
		_note.text = "Not enough dust: %s costs %d." % [SkinCollection.TIER_TITLES[tier], cost]
		Sfx.play("error")
		refresh()
		return
	if _pending_craft != tier:
		_pending_craft = tier
		_note.text = "Craft %s for %d dust? Click again." % [SkinCollection.TIER_TITLES[tier], cost]
		refresh()
		return
	_pending_craft = ""
	SkinCollection.craft(_selected, tier)
	_note.text = "Crafted: %s %s." % [SkinCollection.TIER_TITLES[tier], EventLogPanel.card_name(_selected)]
	Sfx.play("coins")
	refresh()
	_preview.flash_arrival()


## Открыть лутбокс: выпавшая карта выбирается и вспыхивает справа.
func open_box() -> Dictionary:
	var got := SkinCollection.open_box(_rng)
	if got.is_empty():
		return got
	var cid := String(got["card"])
	var tier := String(got["tier"])
	select(cid)
	var title := "%s %s" % [SkinCollection.TIER_TITLES[tier], EventLogPanel.card_name(cid)]
	if got["duplicate"]:
		_note.text = "Already had %s: +%d dust." % [title, int(got["dust"])]
		_preview.set_skin(tier)
		Sfx.play("coins")
	else:
		_note.text = "New skin: %s!" % title
		Sfx.play("victory" if tier != "epic" else "card")
	_note.add_theme_color_override("font_color", Color(SkinCollection.TIER_COLOURS[tier]))
	_preview.flash_arrival()
	refresh()
	if got["duplicate"]:
		_preview.set_skin(tier)
	return got
