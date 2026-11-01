class_name BanPanel
extends Control

## Лобби банов поиска игры (этап Ban-1, владелец 2026-10-29; только RANDOM 4).
## Раскладка по макету владельца (2026-11-01):
##   1-4 — четыре полуколоды, миниатюры сеткой 5x4 (мелкое лицо целиком, в
##         половину: при игре x2 это пиксель в пиксель экрана);
##   5   — посередине полная карта под курсором (или выбранная) с подсказками
##         справа и жетонами слева, как у CardPreview с Alt;
##   6   — сверху ходы банов по порядку: кто, какую карту (или SKIP);
##   7   — снизу, кто сейчас банит, таймер, SKIP и BAN.
## Очередь «змейкой», в каждом круге в полуколоде одна карта (GameRoom.ban);
## занятая в этом круге полуколода гаснет. Состояние приходит с сервера
## (GameRoom.ban_view), экран шлёт только выбор (NetSession.ban_card).
##
## Вёрстка кодом по той же причине, что и в game_screen.gd.

const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")
## Миниатюра — мелкое лицо карты в половину (58x84 -> 29x42).
const THUMB := Vector2(29, 42)
## Лицо забаненной карты в зоне 6 — арт мелкого лица в половину.
const FACE := Vector2(26, 26)
const GRID_COLUMNS := 5
const SIDE_WIDTH := 172
const TOP_HEIGHT := 56
const BOTTOM_HEIGHT := 26
const GAP := 3
const BAN_COLOUR := Color(0.85, 0.12, 0.18)

var _net: NetSession
var _view: Dictionary = {}
var _left := 0.0
var _selected := ""
var _hovered := ""
var _deck_zones: Array[Control] = []
var _info: Control
var _info_shown := ""
var _slots: HBoxContainer
var _status: Label
var _clock: Label
var _skip: Button
var _ban: Button
## card_id -> {"thumb": Control, "deck": String, "face": TextureRect}
var _cells: Dictionary = {}
## Полуколода -> {"title": Label, "note": Label, "grid": GridContainer}
var _decks: Dictionary = {}


func _init(net: NetSession) -> void:
	_net = net
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = PixelTheme.theme()
	var bg := ColorRect.new()
	bg.color = PixelTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(UnderdarkBg.make())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, GAP + 1)
	add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", GAP)
	margin.add_child(rows)

	# 6: ходы банов.
	var top := _zone()
	top.custom_minimum_size.y = TOP_HEIGHT
	rows.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 4)
	top.add_child(top_row)
	var title := Label.new()
	title.text = "BANS"
	title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(title)
	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 2)
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_slots)

	# 1-2 | 5 | 3-4.
	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", GAP)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(middle)
	var left := _side_column()
	middle.add_child(left)
	var info_zone := _zone()
	info_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(info_zone)
	_info = Control.new()
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Размер зоны известен только после раскладки — тогда и перерисовать.
	_info.resized.connect(func():
		_info_shown = "?"
		_refresh_info())
	info_zone.add_child(_info)
	var right := _side_column()
	middle.add_child(right)
	for column: VBoxContainer in [left, right]:
		for i in 2:
			var zone := _zone()
			zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
			column.add_child(zone)
			_deck_zones.append(zone)

	# 7: кто банит, таймер, кнопки.
	var bottom := _zone()
	bottom.custom_minimum_size.y = BOTTOM_HEIGHT
	rows.add_child(bottom)
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 4)
	bottom.add_child(bottom_row)
	# Таймер отдельно: последние 10 секунд — красный.
	_clock = Label.new()
	_clock.custom_minimum_size.x = 30
	_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_row.add_child(_clock)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status.clip_text = true
	bottom_row.add_child(_status)
	_skip = Button.new()
	_skip.text = "SKIP"
	_skip.custom_minimum_size = Vector2(60, 16)
	_skip.pressed.connect(func(): _send(""))
	bottom_row.add_child(_skip)
	_ban = Button.new()
	_ban.text = "BAN"
	_ban.custom_minimum_size = Vector2(170, 16)
	_ban.pressed.connect(func(): _send(_selected))
	bottom_row.add_child(_ban)


func _zone() -> PanelContainer:
	var zone := PanelContainer.new()
	zone.add_theme_stylebox_override("panel", GameScreen.zone_style(4))
	return zone


func _side_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GAP)
	column.custom_minimum_size.x = SIDE_WIDTH
	return column


## Новое состояние с сервера.
func show_view(view: Dictionary) -> void:
	var decks: Array = view.get("decks", [])
	if decks != _view.get("decks", []):
		_build(decks)
	_view = view
	_left = float(view.get("left", 0.0))
	if not can_ban(_selected):
		_selected = ""
	var banned := banned_cards()
	var locked: Array = view.get("locked", [])
	for deck: String in _decks:
		var parts: Dictionary = _decks[deck]
		var shut := locked.has(deck)
		(parts["note"] as Label).text = "banned this round" if shut else ""
	# Гаснут только лица карт закрытой полуколоды: крест бана остаётся ярким.
	for cid: String in _cells:
		var thumb: Control = _cells[cid]["thumb"]
		(_cells[cid]["face"] as Control).modulate = Color(1, 1, 1, 0.4) \
			if locked.has(String(_cells[cid]["deck"])) else Color.WHITE
		thumb.set_meta("banned_by", String(banned.get(cid, "")))
		thumb.queue_redraw()
	_build_slots()
	_refresh()


## Забаненные карты: card_id -> кто забанил.
func banned_cards() -> Dictionary:
	var out := {}
	for b: Dictionary in _view.get("bans", []):
		if String(b.get("card", "")) != "":
			out[String(b["card"])] = String(b["seat"])
	return out


func my_turn() -> bool:
	return _net.seat != "" and String(_view.get("turn", "")) == _net.seat


## Можно ли мне сейчас забанить эту карту (сервер проверяет то же самое).
func can_ban(cid: String) -> bool:
	return my_turn() and _cells.has(cid) and not banned_cards().has(cid) \
		and not (_view.get("locked", []) as Array).has(String(_cells[cid]["deck"]))


## Для проверок: какие карты показаны и какая сейчас в зоне информации.
func shown_cards() -> Array:
	return _cells.keys()


func info_card() -> String:
	return _info_shown


## Щелчок по карте в свой ход — выбрать её (BAN подтверждает).
func select(cid: String) -> void:
	if not can_ban(cid):
		return
	_selected = cid
	Sfx.play("click")
	_refresh()


func _send(card: String) -> void:
	if not my_turn():
		return
	_net.ban_card(card)
	# Пока сервер не ответил, второй раз не жмём.
	_skip.disabled = true
	_ban.disabled = true


func _build(decks: Array) -> void:
	for zone in _deck_zones:
		for child in zone.get_children():
			child.queue_free()
	_cells.clear()
	_decks.clear()
	for i in mini(decks.size(), _deck_zones.size()):
		var deck := String(decks[i])
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		_deck_zones[i].add_child(col)
		var head := HBoxContainer.new()
		col.add_child(head)
		var title := Label.new()
		title.text = SetupScreen.deck_title(deck)
		title.add_theme_color_override("font_color", PixelTheme.GOLD)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var note := Label.new()
		note.add_theme_color_override("font_color", BAN_COLOUR.lightened(0.15))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(note)
		var grid := GridContainer.new()
		grid.columns = GRID_COLUMNS
		grid.add_theme_constant_override("h_separation", 2)
		grid.add_theme_constant_override("v_separation", 2)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		# Сетка по центру зоны: зона выше четырёх рядов миниатюр.
		grid.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
		col.add_child(grid)
		_decks[deck] = {"title": title, "note": note, "grid": grid}
		var copies := GameSetup.half_deck_copies(deck)
		var ids: Array = copies.keys()
		ids.sort_custom(func(a, b):
			var ca := CollectionPage.card_cost(a)
			var cb := CollectionPage.card_cost(b)
			return ca < cb if ca != cb else String(a) < String(b))
		for cid: String in ids:
			if not _cells.has(cid):
				grid.add_child(_make_thumb(cid, deck))


## Миниатюра: мелкое лицо целиком в половину, рамка — выбор (золото) или бан
## (красный крест и рамка цвета того, кто забанил).
func _make_thumb(cid: String, deck: String) -> Control:
	var thumb := Control.new()
	thumb.custom_minimum_size = THUMB + Vector2(2, 2)
	thumb.mouse_filter = Control.MOUSE_FILTER_STOP
	thumb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	thumb.set_meta("banned_by", "")
	var face := TextureRect.new()
	face.texture = CardView.mini_texture(cid)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.position = Vector2(1, 1)
	face.size = THUMB
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.add_child(face)
	# Крест и рамки рисуются поверх лица отдельным узлом.
	var over := Control.new()
	over.set_anchors_preset(Control.PRESET_FULL_RECT)
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.draw.connect(func(): _draw_thumb(over, thumb, cid))
	thumb.add_child(over)
	thumb.draw.connect(func(): over.queue_redraw())
	thumb.mouse_entered.connect(func():
		_hovered = cid
		_refresh_info())
	thumb.mouse_exited.connect(func():
		if _hovered == cid:
			_hovered = ""
			_refresh_info())
	thumb.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			select(cid))
	_cells[cid] = {"thumb": thumb, "deck": deck, "face": face}
	return thumb


func _draw_thumb(over: Control, thumb: Control, cid: String) -> void:
	var r := Rect2(Vector2.ZERO, thumb.size)
	var by := String(thumb.get_meta("banned_by", ""))
	if by != "":
		over.draw_rect(Rect2(Vector2(1, 1), THUMB), Color(PixelTheme.BG, 0.55))
		var a := Vector2(4, 6)
		var b := r.size - Vector2(4, 6)
		over.draw_line(a, b, BAN_COLOUR, 2.0)
		over.draw_line(Vector2(b.x, a.y), Vector2(a.x, b.y), BAN_COLOUR, 2.0)
		over.draw_rect(r.grow(-0.5), BoardPanel.colour(by, BAN_COLOUR), false, 1.0)
	elif cid == _selected:
		over.draw_rect(r.grow(-0.5), PixelTheme.GOLD, false, 1.0)
	elif cid == _hovered:
		over.draw_rect(r.grow(-0.5), PixelTheme.TEXT_DIM, false, 1.0)


## Зона 6: ячейка на каждый ход банов по порядку — рамка цвета того, чей ход;
## внутри лицо забаненной карты (арт мелкого лица в половину), её имя в две
## строки, SKIP или пусто (ход ещё впереди). Над половинами — ROUND 1 / 2.
func _build_slots() -> void:
	for child in _slots.get_children():
		child.queue_free()
	var order: Array = _view.get("order", [])
	var bans: Array = _view.get("bans", [])
	var turn_index := bans.size()
	var lap := maxi(1, order.size() / maxi(1, int(_view.get("each", GameRoom.BANS_EACH))))
	var lap_box: HBoxContainer
	for i in order.size():
		if i % lap == 0:
			var lap_col := VBoxContainer.new()
			lap_col.add_theme_constant_override("separation", 1)
			lap_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_slots.add_child(lap_col)
			var head := Label.new()
			head.text = "ROUND %d  %s" % [i / lap + 1, "->" if (i / lap) % 2 == 0 else "<-"]
			head.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
			head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lap_col.add_child(head)
			lap_box = HBoxContainer.new()
			lap_box.add_theme_constant_override("separation", 2)
			lap_col.add_child(lap_box)
		var who := String(order[i])
		var colour := BoardPanel.colour(who, PixelTheme.TEXT)
		var now := i == turn_index and String(_view.get("turn", "")) != ""
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", PixelTheme.box(PixelTheme.PANEL_LO if not now else colour.darkened(0.6),
			colour if i <= turn_index else colour.darkened(0.55), 1, 2, 1))
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lap_box.add_child(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		slot.add_child(row)
		var card := String((bans[i] as Dictionary).get("card", "")) if i < bans.size() else ""
		var pic := TextureRect.new()
		pic.custom_minimum_size = FACE
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if card != "" and CardView.mini_texture(card) != null:
			var face := AtlasTexture.new()
			face.atlas = CardView.mini_texture(card)
			face.region = Rect2(CardView.MINI_ART.x, CardView.MINI_ART.y,
				CardView.MINI_ART.z - CardView.MINI_ART.x, CardView.MINI_ART.w - CardView.MINI_ART.y)
			pic.texture = face
		row.add_child(pic)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		# Текущая ячейка залита цветом игрока — текст на ней светлый.
		var name_label := Label.new()
		name_label.text = EventLogPanel.player_name(who)
		name_label.add_theme_color_override("font_color", PixelTheme.TEXT if now else colour)
		name_label.clip_text = true
		name_label.custom_minimum_size.x = 30
		text.add_child(name_label)
		var what := Label.new()
		what.custom_minimum_size.x = 30
		if i < bans.size():
			what.text = String(CardLibrary.card_data(card).get("name", "")).to_upper() if card != "" else "SKIP"
			what.add_theme_color_override("font_color", PixelTheme.TEXT if card != "" else PixelTheme.TEXT_DIM)
			what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		else:
			what.text = "NOW" if now else "-"
			what.add_theme_color_override("font_color", PixelTheme.GOLD if now else PixelTheme.TEXT_DIM)
		text.add_child(what)


## Зона 5: полная карта под курсором, иначе выбранная; подсказки справа,
## жетоны слева (CardPreview.tips_column / token_cards / place_extras).
func _refresh_info() -> void:
	var cid := _hovered if _hovered != "" else _selected
	for cell: Dictionary in _cells.values():
		(cell["thumb"] as Control).queue_redraw()
	if cid == _info_shown:
		return
	_info_shown = cid
	for child in _info.get_children():
		child.queue_free()
	if cid == "":
		var hint := Label.new()
		hint.text = "Hover a card to see it in full.\nAlt over any card also shows its notes."
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
		hint.position = Vector2(0, 120)
		hint.size = Vector2(_info.size.x, 30)
		_info.add_child(hint)
		return
	var card := CardView.new(cid, int(CardView.PIXEL_SIZE.x), int(CardView.PIXEL_SIZE.y))
	card.hover_preview = false
	CardView._ignore_mouse(card)
	_info.add_child(card)
	card.size = CardView.PIXEL_SIZE
	# Главная карта стоит на месте при любом наведении (критик UI): справа
	# ровно место под подсказки, слева — под жетоны (их больше одного — внахлёст).
	card.position = Vector2(maxf(0.0, floorf(_info.size.x - card.size.x * 2 - CardPreview.MARGIN * 2)), 24)
	# Подпись — только состояние карты: полуколода и копии уже в подвале карты.
	var deck := String(_cells[cid]["deck"]) if _cells.has(cid) else ""
	var caption := Label.new()
	var by := String(banned_cards().get(cid, ""))
	var colour := PixelTheme.TEXT_DIM
	if by != "":
		caption.text = "BANNED by %s" % EventLogPanel.player_name(by)
		colour = BAN_COLOUR
	elif (_view.get("locked", []) as Array).has(deck):
		caption.text = "%s already has a ban this round" % SetupScreen.deck_title(deck)
	caption.add_theme_color_override("font_color", colour)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(0, 0)
	caption.size = Vector2(_info.size.x, 12)
	_info.add_child(caption)
	var tips := CardPreview.tips_column(card, card.size.x)
	if tips != null:
		_info.add_child(tips)
	var tokens := CardPreview.token_cards(cid, card.size)
	for t: CardView in tokens:
		_info.add_child(t)
	CardPreview.place_extras(card, tokens, tips, _info.get_global_rect())


func _refresh() -> void:
	_refresh_info()
	var mine := my_turn()
	var turn := String(_view.get("turn", ""))
	var colour := BoardPanel.colour(turn, PixelTheme.TEXT)
	_skip.disabled = not mine
	_ban.disabled = not can_ban(_selected)
	_ban.text = "BAN %s" % String(CardLibrary.card_data(_selected).get("name", "")).to_upper() if _selected != "" else "BAN"
	# BAN — главная кнопка: залита цветом банящего (критик UI); SKIP — обычная.
	var fill := PixelTheme.box(colour.darkened(0.45), colour.lightened(0.2), 1, 3, 2)
	for state in ["normal", "hover", "pressed"]:
		_ban.add_theme_stylebox_override(state, fill)
	var seconds := ceili(_left)
	_clock.text = "%d:%02d" % [seconds / 60, seconds % 60] if turn != "" else ""
	_clock.add_theme_color_override("font_color", BAN_COLOUR.lightened(0.2) if seconds <= 10 else PixelTheme.TEXT)
	if turn == "":
		_status.text = "Bans are done. Dealing the cards..."
	elif mine and _selected != "":
		_status.text = "YOUR BAN: ban %s (%s)?" % [String(CardLibrary.card_data(_selected).get("name", "")).to_upper(),
			SetupScreen.deck_title(String(_cells[_selected]["deck"]))]
	elif mine:
		_status.text = "YOUR BAN: pick a card in a half-deck without a ban this round, then BAN - or SKIP."
	else:
		_status.text = "%s is banning..." % EventLogPanel.player_name(turn).to_upper()
	_status.add_theme_color_override("font_color", PixelTheme.GOLD if mine else colour)


func _process(delta: float) -> void:
	if String(_view.get("turn", "")) == "" or _left <= 0.0:
		return
	var before := ceili(_left)
	_left = maxf(0.0, _left - delta)
	if ceili(_left) != before:
		_refresh()
