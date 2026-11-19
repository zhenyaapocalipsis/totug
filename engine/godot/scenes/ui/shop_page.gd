class_name ShopPage
extends VBoxContainer

const PageText := preload("res://scenes/page_text.gd")
const L10n := preload("res://scenes/localization.gd")
const PAGE_SIZE := 8

class Choices extends HFlowContainer:
	signal item_selected(index: int)
	var selected := 0
	var buttons: Array[Button] = []

	func configure(titles: Array[String]) -> void:
		alignment = FlowContainer.ALIGNMENT_BEGIN
		add_theme_constant_override("h_separation", 3)
		add_theme_constant_override("v_separation", 3)
		var group := ButtonGroup.new()
		for title in titles:
			var index := buttons.size()
			var button := Button.new()
			if title.begins_with("shop."):
				L10n.bind(button, title)
			else:
				PageText.bind(button, title)
			button.toggle_mode = true
			button.button_group = group
			button.custom_minimum_size.y = 16
			SetupScreen._style_button(button)
			button.pressed.connect(func():
				select(index)
				item_selected.emit(index))
			add_child(button)
			buttons.append(button)
		select(0)

	func _ready() -> void:
		_fit_width()
		L10n.events.changed.connect(func(): _fit_width.call_deferred())

	func _fit_width() -> void:
		if get_parent() is HBoxContainer:
			# Inherited game fonts are available now; default-font widths leave large empty gaps.
			var width := -3.0
			for button in buttons:
				width += button.get_combined_minimum_size().x + 3
			custom_minimum_size.x = width

	func select(index: int) -> void:
		selected = index
		for i in buttons.size():
			buttons[i].set_pressed_no_signal(i == index)

var _catalog: Array[Dictionary] = []
var _filtered_keys: Array[String] = []
var _selected := ""
var _dust: Label
var _count: Label
var _search: LineEdit
var _kind: Choices
var _faction: Choices
var _rarity: Choices
var _sort: Choices
var _affordable: CheckBox
var _hide_owned: CheckBox
var _grid: GridContainer
var _page := 0
var _page_label: Label
var _previous: Button
var _next: Button
var _preview: CardView
var _title: Label
var _price: Label
var _action: Button
var _note: Label
var _confirm: ConfirmationDialog
var _purchase_key := ""


func _init() -> void:
	theme = PixelTheme.theme()
	custom_minimum_size = Vector2(650, 410)
	var margins := MarginContainer.new()
	margins.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for edge in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + edge, 8)
	add_child(margins)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margins.add_child(content)
	var top := HBoxContainer.new()
	content.add_child(top)
	_kind = _options(top, ["shop.arts", "shop.shaders"])
	_dust = _label("", PixelTheme.GOLD)
	_dust.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dust.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_dust)
	var filters := HBoxContainer.new()
	content.add_child(filters)
	_search = LineEdit.new()
	_search.placeholder_text = "Search cards or shaders"
	_search.custom_minimum_size.x = 165
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_child(_search)
	_search.text_changed.connect(func(_text: String): _rebuild())
	var factions: Array[String] = []
	for faction in CollectionPage.FACTIONS:
		factions.append(String(SetupScreen.NEW_ERA_TITLES.get(faction, faction.to_upper())))
	_faction = _options(content, factions)
	content.move_child(_faction, 1)
	_rarity = _options(filters, ["shop.all_rarities", "shop.tier.epic", "shop.tier.legendary", "shop.tier.ultra"])
	var tools := HBoxContainer.new()
	content.add_child(tools)
	tools.add_theme_constant_override("separation", 8)
	_sort = _options(tools, ["shop.newest", "shop.name", "shop.price"])
	_affordable = CheckBox.new()
	L10n.bind(_affordable, "shop.can_afford")
	tools.add_child(_affordable)
	_affordable.toggled.connect(func(_on: bool): _rebuild())
	_hide_owned = CheckBox.new()
	L10n.bind(_hide_owned, "shop.hide_owned")
	tools.add_child(_hide_owned)
	_hide_owned.toggled.connect(func(_on: bool): _rebuild())
	_count = _label("", PixelTheme.TEXT_DIM)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tools.add_child(_count)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 16)
	content.add_child(heading)
	var heading_space := Control.new()
	heading_space.custom_minimum_size.x = 450
	heading_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(heading_space)
	_title = _label("", PixelTheme.TEXT)
	_title.custom_minimum_size = Vector2(176, 22)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(_title)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	content.add_child(body)
	var catalog := VBoxContainer.new()
	catalog.custom_minimum_size.x = 450
	catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog.add_theme_constant_override("separation", 8)
	body.add_child(catalog)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 18)
	_grid.custom_minimum_size = Vector2(450, 282)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog.add_child(_grid)
	var pages := HBoxContainer.new()
	pages.alignment = BoxContainer.ALIGNMENT_CENTER
	catalog.add_child(pages)
	_previous = _button("<", func(): _page -= 1; _rebuild())
	pages.add_child(_previous)
	_page_label = _label("", PixelTheme.TEXT_DIM)
	pages.add_child(_page_label)
	_next = _button(">", func(): _page += 1; _rebuild())
	pages.add_child(_next)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 176
	side.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	side.add_theme_constant_override("separation", 4)
	body.add_child(side)
	_preview = CardView.new("48342", 176, 254)
	_preview.hover_preview = false
	side.add_child(_preview)
	_price = _label("", PixelTheme.GOLD)
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(_price)
	_action = Button.new()
	SetupScreen._style_button(_action)
	_action.custom_minimum_size.y = 16
	_action.pressed.connect(press_selected)
	side.add_child(_action)
	_note = _label("", PixelTheme.TEXT_DIM)
	_note.custom_minimum_size.x = 176
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(_note)
	_confirm = ConfirmationDialog.new()
	_confirm.theme = PixelTheme.theme()
	_confirm.title = L10n.text("shop.confirm_title")
	L10n.bind(_confirm.get_ok_button(), "shop.confirm_buy")
	L10n.bind(_confirm.get_cancel_button(), "shop.cancel")
	SetupScreen._style_button(_confirm.get_ok_button())
	SetupScreen._style_button(_confirm.get_cancel_button())
	_confirm.confirmed.connect(_buy_confirmed)
	add_child(_confirm)
	var membership := {}
	for faction in CollectionPage.FACTIONS:
		for cid in CollectionPage.faction_cards(faction):
			for form in CollectionPage.card_forms(cid):
				if not membership.has(form):
					membership[form] = []
				if not membership[form].has(faction):
					membership[form].append(faction)
	for art: String in AltArts.TIER_OF:
		var cid := AltArts.card_of(art)
		_catalog.append({"key": SkinCollection.art_key(art), "id": art, "card": cid,
			"name": AltArts.title_of(art), "source_name": AltArts.title_of(art, "en"),
			"card_name": EventLogPanel.card_name(cid), "kind": "art", "tier": AltArts.tier_of(art),
			"cost": SkinCollection.art_cost(art), "factions": membership.get(cid, _legacy_factions(cid))})
	for shader in SkinCollection.SHADERS:
		_catalog.append({"key": SkinCollection.shader_key(shader), "id": shader, "card": "48342",
			"name": L10n.text("shop.shader." + shader), "source_name": SkinCollection.SHADER_TITLES[shader], "kind": "shader",
			"tier": SkinCollection.SHADER_TIER, "cost": SkinCollection.CRAFT_COST[SkinCollection.SHADER_TIER], "faction": ""})
	_rebuild()
	L10n.events.changed.connect(_refresh_language)


func _refresh_language() -> void:
	_confirm.title = L10n.text("shop.confirm_title")
	for item in _catalog:
		if item["kind"] == "art":
			item["name"] = AltArts.title_of(item["id"])
			item["card_name"] = EventLogPanel.card_name(item["card"])
		else:
			item["name"] = L10n.text("shop.shader." + str(item["id"]))
	_rebuild()
	if _confirm.visible and not _item(_purchase_key).is_empty():
		var item := _item(_purchase_key)
		_confirm.dialog_text = L10n.text("shop.confirm", {"name": item["name"], "cost": item["cost"]})


func _label(value: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", colour)
	return label


func _legacy_factions(cid: String) -> Array[String]:
	# These older card slots remain in the art collection after deck revisions.
	if cid == "49203":
		return ["piltover"]
	if cid == "49700":
		return ["shurima"]
	if cid in ["49008", "49011"]:
		return ["celestial"]
	return [CollectionPage.faction_of(cid)]


func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(30, 16)
	SetupScreen._style_button(button)
	button.pressed.connect(action)
	return button


func _options(parent: Control, titles: Array[String]) -> Choices:
	var choices := Choices.new()
	choices.configure(titles)
	if parent is HBoxContainer:
		choices.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(choices)
	choices.item_selected.connect(func(_index: int): _page = 0; _rebuild())
	return choices


func items() -> Array[Dictionary]:
	return _catalog.duplicate(true)


func show_item(key: String) -> void:
	var item := _item(key)
	if item.is_empty():
		return
	_selected = key
	if not _filtered_keys.has(key):
		_kind.select(0 if item["kind"] == "art" else 1)
		if item["kind"] == "art":
			_faction.select(CollectionPage.FACTIONS.find(item["factions"][0]))
		_search.text = ""
		_rarity.select(0)
		_affordable.set_pressed_no_signal(false)
		_hide_owned.set_pressed_no_signal(false)
		_page = 0
		_selected = key
		_rebuild()
	var position := _filtered_keys.find(key)
	if position >= 0:
		var target_page := position / PAGE_SIZE
		if target_page != _page:
			_page = target_page
			_rebuild()
	_select_preview()


func refresh() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_instance_valid(_grid):
		return
	var data := SkinCollection.load_data()
	_dust.text = L10n.text("shop.dust", {"amount": int(data["dust"])})
	var owned: Array = data["owned"]
	var arts := _kind.selected == 0
	_faction.visible = arts
	_rarity.visible = arts
	_search.placeholder_text = L10n.text("shop.search_arts" if arts else "shop.search_shaders")
	var filtered: Array[Dictionary] = []
	for item in _catalog:
		if item["kind"] != ("art" if arts else "shader"):
			continue
		if arts and not item["factions"].has(CollectionPage.FACTIONS[_faction.selected]):
			continue
		if arts and _rarity.selected > 0 and item["tier"] != SkinCollection.TIERS[_rarity.selected - 1]:
			continue
		if _affordable.button_pressed and (int(item["cost"]) > int(data["dust"]) or owned.has(item["key"])):
			continue
		if _hide_owned.button_pressed and owned.has(item["key"]):
			continue
		var query := _search.text.strip_edges().to_lower()
		if query != "" and not (str(item["name"]) + " " + str(item["source_name"]) + " " + str(item.get("card_name", "")) + " " + str(item["id"])).to_lower().contains(query):
			continue
		filtered.append(item)
	if _sort.selected == 0:
		filtered.reverse()
	else:
		filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if _sort.selected == 2 and a["cost"] != b["cost"]:
				return a["cost"] < b["cost"]
			return str(a["name"]) + str(a["id"]) < str(b["name"]) + str(b["id"]))
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_count.text = L10n.text("shop.count", {"count": filtered.size()})
	_filtered_keys.clear()
	for item in filtered:
		_filtered_keys.append(item["key"])
	if not _filtered_keys.has(_selected):
		_selected = _filtered_keys[0] if not _filtered_keys.is_empty() else ""
	var pages := maxi(1, ceili(filtered.size() / float(PAGE_SIZE)))
	_page = clampi(_page, 0, pages - 1)
	_page_label.text = " %d / %d " % [_page + 1, pages]
	_previous.disabled = _page == 0
	_next.disabled = _page == pages - 1
	for item in filtered.slice(_page * PAGE_SIZE, (_page + 1) * PAGE_SIZE):
		var tile := VBoxContainer.new()
		tile.custom_minimum_size.x = 108
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_constant_override("separation", 4)
		_grid.add_child(tile)
		var frame := CenterContainer.new()
		frame.custom_minimum_size = Vector2(108, 84)
		tile.add_child(frame)
		var view := CardView.new(item["card"], int(CollectionPage.MINI.x), int(CollectionPage.MINI.y))
		view.hover_preview = false
		view.set_art(item["id"] if item["kind"] == "art" else "")
		view.set_skin(item["id"] if item["kind"] == "shader" else "")
		view.set_clickable(true)
		view.pressed.connect(func(_cid: String): show_item(item["key"]))
		frame.add_child(view)
		tile.set_meta("shop_key", item["key"])
		tile.set_meta("shop_view", view)
		view.tooltip_text = str(item["name"])
		var name_label := _label(str(item["name"]), PixelTheme.TEXT)
		name_label.custom_minimum_size = Vector2(108, 44)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.tooltip_text = str(item["name"])
		tile.add_child(name_label)
	if filtered.is_empty():
		_grid.add_child(_label(L10n.text("shop.empty"), PixelTheme.TEXT_DIM))
	_select_preview()


func _item(key: String) -> Dictionary:
	for item in _catalog:
		if item["key"] == key:
			return item
	return {}


func _select_preview() -> void:
	for tile in _grid.get_children():
		if tile.has_meta("shop_view"):
			var view: CardView = tile.get_meta("shop_view")
			view.highlight = tile.get_meta("shop_key") == _selected
			view.queue_redraw()
	var item := _item(_selected)
	_preview.visible = not item.is_empty()
	_action.visible = not item.is_empty()
	_title.visible = not item.is_empty()
	_price.visible = not item.is_empty()
	_note.visible = not item.is_empty()
	if item.is_empty():
		return
	_preview.set_card(item["card"])
	_preview.set_art(item["id"] if item["kind"] == "art" else "")
	_preview.set_skin(item["id"] if item["kind"] == "shader" else "")
	_title.text = str(item["name"])
	var data := SkinCollection.load_data()
	var owned: bool = (data["owned"] as Array).has(item["key"])
	var in_use: bool = str(data["shader"]) == item["id"] if item["kind"] == "shader" else SkinCollection.art_of(item["card"]) == item["id"]
	_price.text = L10n.text("shop.tier." + str(item["tier"])) + (" · " + L10n.text("shop.owned") if owned else "")
	_action.text = L10n.text("shop.in_use" if in_use else "shop.apply") if owned else L10n.text("shop.buy", {"cost": item["cost"]})
	_action.disabled = in_use or (not owned and int(data["dust"]) < int(item["cost"]))
	_note.text = ""
	if not owned and int(data["dust"]) < int(item["cost"]):
		_note.text = L10n.text("shop.need_dust", {"amount": int(item["cost"]) - int(data["dust"])})
	elif item["kind"] == "shader":
		_note.text = L10n.text("shop.whole_deck")


func press_selected() -> void:
	var item := _item(_selected)
	if item.is_empty():
		return
	if (SkinCollection.load_data()["owned"] as Array).has(item["key"]):
		if item["kind"] == "art":
			SkinCollection.set_art(item["card"], item["id"])
		else:
			SkinCollection.set_shader(item["id"])
		_select_preview()
		return
	_purchase_key = _selected
	_confirm.dialog_text = L10n.text("shop.confirm", {"name": item["name"], "cost": item["cost"]})
	_confirm.popup_centered()


func _buy_confirmed() -> void:
	var item := _item(_purchase_key)
	_purchase_key = ""
	if item.is_empty():
		return
	var success := SkinCollection.purchase_art(item["id"]) if item["kind"] == "art" else SkinCollection.purchase_shader(item["id"])
	if success:
		Sfx.play("coins")
	_rebuild()
	if success:
		_note.text = L10n.text("shop.purchased")
