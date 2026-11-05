class_name BanPanel
extends Control

## Лобби банов поиска игры (этап Ban-1, владелец 2026-10-29; только RANDOM 4).
## Раскладка (владелец, 2026-11-01, после двух проб):
##   сверху — ходы банов по порядку (R1, R2): кто, какую карту (миниатюра
##            целиком в полный размер) или SKIP;
##   слева  — четыре полуколоды вкладками, сетка 5x4 миниатюр в полный размер;
##   справа — полная карта под курсором (или выбранная): жетон слева от неё,
##            подсказки справа, как у Alt; ниже — чат стола;
##   снизу  — кто сейчас банит, таймер, SKIP и BAN.
## Очередь «змейкой», в каждом круге в полуколоде одна карта (GameRoom.ban);
## занятая в этом круге полуколода гаснет. Состояние приходит с сервера
## (GameRoom.ban_view), экран шлёт только выбор (NetSession.ban_card).
##
## Вёрстка кодом по той же причине, что и в game_screen.gd.

const L10n := preload("res://scenes/localization.gd")
const CardText := preload("res://scenes/card_text.gd")

const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")
## Миниатюра — мелкое лицо карты целиком в родном размере, и в сетке, и в
## полосе банов (владелец, 2026-11-01: не уменьшать).
const THUMB := CardView.MINI_SIZE
const GRID_COLUMNS := 5
## Колонка полуколод: 5 миниатюр, 4 зазора по 2, поля зоны.
const SIDE_WIDTH := 304
const BOTTOM_HEIGHT := 26
const GAP := 3
const BAN_COLOUR := Color(0.85, 0.12, 0.18)
## Высота места под полную карту (подписи жетонов + карта); ниже — чат.
const INFO_HEIGHT := 268
## Предложение забанить карту уходит в чат строкой с этим началом и id карты —
## у всех она рисуется именем карты, по щелчку карта выбирается.
const SUGGEST_PREFIX := "ban?"
const GameSettings := preload("res://scenes/game_settings.gd")

var _messages: Array[Dictionary] = []
var _net: NetSession
var _view: Dictionary = {}
var _left := 0.0
var _selected := ""
var _hovered := ""
var _deck_zones: Array[Control] = []
## По колонке: ряд вкладок полуколод и место под их сетки.
var _tab_rows: Array[HBoxContainer] = []
var _stacks: Array[Control] = []
var _info: Control
var _chat_log: RichTextLabel
var _chat_scroll: ScrollContainer
var _chat_edit: LineEdit
var _info_shown := ""
## Жетоны, что сменяют друг друга на одном месте (все рядом не влезли).
var _token_cycle: Array[CardView] = []
var _token_time := 0.0
var _token_hold := false
const TOKEN_SECONDS := 2.0
var _slots: HBoxContainer
var _status: Label
var _clock: Label
var _skip: Button
var _ban: Button
## card_id -> {"thumb": Control, "deck": String, "face": TextureRect}
var _cells: Dictionary = {}
## Полуколода -> {"tab": Button, "grid": GridContainer, "column": int}
var _decks: Dictionary = {}


func _init(net: NetSession) -> void:
	_net = net
	L10n.events.changed.connect(_locale_changed)
	net.chat_received.connect(_on_chat)
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
	rows.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 4)
	top.add_child(top_row)
	# Крупного заголовка BANS нет: восемь ячеек с миниатюрами в полный размер
	# занимают всю ширину (владелец, 2026-11-01: миниатюры не уменьшать).
	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 2)
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_slots)

	# Слева полуколоды (4 вкладки), справа всё остальное (владелец, 2026-11-01).
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
	# Сверху карта с жетонами и подсказками, под ней — чат стола (владелец,
	# 2026-11-01): Tab над картой предлагает её забанить.
	var info_col := VBoxContainer.new()
	info_col.add_theme_constant_override("separation", GAP)
	info_zone.add_child(info_col)
	_info.custom_minimum_size.y = INFO_HEIGHT
	info_col.add_child(_info)
	info_col.add_child(_make_chat())
	# Одна зона: вкладки четырёх полуколод и сетка выбранной (5x4 в полный
	# размер — по высоте почти впритык, поля зоны узкие).
	for column: VBoxContainer in [left]:
		var zone := PanelContainer.new()
		zone.add_theme_stylebox_override("panel", GameScreen.zone_style(2))
		zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(zone)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		zone.add_child(col)
		var tabs := HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 2)
		col.add_child(tabs)
		var stack := Control.new()
		stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(stack)
		_deck_zones.append(col)
		_tab_rows.append(tabs)
		_stacks.append(stack)

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
	L10n.bind(_skip, "ban.skip")
	_skip.custom_minimum_size = Vector2(60, 16)
	_skip.pressed.connect(func(): _send(""))
	bottom_row.add_child(_skip)
	_ban = Button.new()
	_ban.text = L10n.text("ban.ban")
	_ban.custom_minimum_size = Vector2(170, 16)
	_ban.pressed.connect(func(): _send(_selected))
	bottom_row.add_child(_ban)


## Чат стола под картой: лента сообщений и строка ввода (Enter — отправить).
func _make_chat() -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", PixelTheme.box(PixelTheme.PANEL_LO, PixelTheme.BORDER, 1, 4, 3))
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	box.add_child(col)
	var head_row := HBoxContainer.new()
	col.add_child(head_row)
	var head := Label.new()
	L10n.bind(head, "ban.chat")
	head.add_theme_color_override("font_color", PixelTheme.GOLD)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(head)
	var hint := Label.new()
	L10n.bind(hint, "ban.suggest_hint")
	hint.add_theme_color_override("font_color", PixelTheme.TEXT_DIM.darkened(0.25))
	head_row.add_child(hint)
	# Сообщения прижаты к строке ввода (критик UI): пустое место — над ними,
	# длинная лента прокручивается, новое сообщение всегда видно.
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_chat_scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.add_child(stack)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(spacer)
	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.fit_content = true
	_chat_log.scroll_active = false
	_chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Щелчок по карте в предложении — открыть её полуколоду и выбрать.
	_chat_log.meta_clicked.connect(func(meta):
		if _cells.has(String(meta)):
			show_deck(String(_cells[String(meta)]["deck"]))
			select(String(meta)))
	stack.add_child(_chat_log)
	_chat_edit = LineEdit.new()
	L10n.bind(_chat_edit, "ban.placeholder", {}, "placeholder_text")
	_chat_edit.max_length = 300
	_chat_edit.text_submitted.connect(func(text: String):
		if text.strip_edges() != "":
			_net.send_chat(text)
		_chat_edit.clear())
	col.add_child(_chat_edit)
	return box


## Новое сообщение — ленту в самый низ (когда раскладка уже пересчитана).
func _scroll_chat_down() -> void:
	_apply_chat_scroll.call_deferred()


func _apply_chat_scroll() -> void:
	if is_instance_valid(_chat_scroll):
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)


## Сообщение стола. Предложение бана (SUGGEST_PREFIX + id) — именем карты и
## её полуколодой, имя кликается: в свой ход карта выбирается.
func _on_chat(seat: String, text: String) -> void:
	if text.begins_with(SUGGEST_PREFIX) and not _cells.has(text.substr(SUGGEST_PREFIX.length())):
		return
	var deck := String(_cells[text.substr(SUGGEST_PREFIX.length())]["deck"]) if text.begins_with(SUGGEST_PREFIX) else ""
	_messages.append({"seat": seat, "text": text, "deck": deck})
	_append_chat(seat, text, deck)
	_scroll_chat_down()


func _append_chat(seat: String, text: String, deck: String) -> void:
	# User text is literal, including BBCode-like names and messages.
	_chat_log.push_color(BoardPanel.colour(seat, PixelTheme.TEXT))
	_chat_log.add_text(EventLogPanel.player_name(seat))
	_chat_log.pop()
	if text.begins_with(SUGGEST_PREFIX):
		var cid := text.substr(SUGGEST_PREFIX.length())
		var link := "[url=%s][color=#%s]%s[/color][/url]" % [cid, PixelTheme.GOLD.to_html(false), CardText.field(cid, "name").to_upper()]
		# Name was rendered literally above; only our own template contains markup.
		_chat_log.append_text(L10n.text("ban.suggest", {"who": "", "card": link, "deck": _deck_title(deck)}))
	else:
		_chat_log.add_text(": " + text)
	_chat_log.newline()


## Tab (клавиша пинга) над миниатюрой — в чат предложение забанить её.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not GameSettings.is_key(key, "ping"):
		return
	if _hovered != "":
		_net.send_chat(SUGGEST_PREFIX + _hovered)
	get_viewport().set_input_as_handled()


## Для проверок: текст ленты чата.
func chat_text() -> String:
	return _chat_log.get_parsed_text()


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
	# Закрытая в этом круге полуколода: вкладка залита тёмно-красным; открытая
	# сейчас вкладка — золотой рамкой, а не заливкой (критик UI: два состояния
	# не должны путаться).
	for deck: String in _decks:
		var tab: Button = _decks[deck]["tab"]
		var shut := locked.has(deck)
		# Критик UI: закрытая — приглушённая, с крестиком; доступная — яркая.
		var bg := BAN_COLOUR.darkened(0.75) if shut else PixelTheme.PANEL_HI
		var text := PixelTheme.TEXT_OFF if shut else PixelTheme.TEXT
		tab.text = ("x " if shut else "") + _deck_title(deck)
		tab.add_theme_stylebox_override("normal", PixelTheme.button_box(bg, PixelTheme.BORDER))
		tab.add_theme_stylebox_override("hover", PixelTheme.button_box(bg.lightened(0.08), PixelTheme.BORDER_HI))
		for state in ["pressed", "hover_pressed"]:
			tab.add_theme_stylebox_override(state, PixelTheme.button_box(bg, PixelTheme.GOLD))
		for state in ["font_color", "font_hover_color"]:
			tab.add_theme_color_override(state, text)
		for state in ["font_pressed_color", "font_hover_pressed_color"]:
			tab.add_theme_color_override(state, text if shut else PixelTheme.GOLD)
		tab.tooltip_text = _deck_tip(deck, shut)
	# Свой ход, а в колонке открыта закрытая полуколода — открыть соседнюю.
	if my_turn():
		for deck: String in _decks:
			if locked.has(deck) and deck_shown(deck):
				for other: String in _decks:
					if other != deck and int(_decks[other]["column"]) == int(_decks[deck]["column"]) and not locked.has(other):
						show_deck(other)
						break
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
	show_deck(String(_cells[cid]["deck"]))
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
	for row in _tab_rows:
		for child in row.get_children():
			child.queue_free()
	for stack in _stacks:
		for child in stack.get_children():
			child.queue_free()
	_cells.clear()
	_decks.clear()
	# Полуколоды 1-2 — во вкладках левой колонки, 3-4 — правой.
	for i in decks.size():
		var deck := String(decks[i])
		var column := 0
		var tab := Button.new()
		tab.text = _deck_title(deck)
		tab.clip_text = true
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size.y = 13
		tab.pressed.connect(func(): show_deck(deck))
		_tab_rows[column].add_child(tab)
		var grid := GridContainer.new()
		grid.columns = GRID_COLUMNS
		grid.add_theme_constant_override("h_separation", 2)
		grid.add_theme_constant_override("v_separation", 1)
		_stacks[column].add_child(grid)
		_decks[deck] = {"tab": tab, "grid": grid, "column": column}
		var copies := GameSetup.half_deck_copies(deck)
		var ids: Array = copies.keys()
		ids.sort_custom(func(a, b):
			var ca := CollectionPage.card_cost(a)
			var cb := CollectionPage.card_cost(b)
			return ca < cb if ca != cb else String(a) < String(b))
		for cid: String in ids:
			if not _cells.has(cid):
				grid.add_child(_make_thumb(cid, deck))
	if not decks.is_empty():
		show_deck(String(decks[0]))


## Показать сетку полуколоды в её колонке (вкладка нажата).
func show_deck(deck: String) -> void:
	if not _decks.has(deck):
		return
	var column := int(_decks[deck]["column"])
	for other: String in _decks:
		if int(_decks[other]["column"]) == column:
			(_decks[other]["grid"] as Control).visible = other == deck
			(_decks[other]["tab"] as Button).set_pressed_no_signal(other == deck)


## Для проверок: открыта ли сетка полуколоды.
func deck_shown(deck: String) -> bool:
	return _decks.has(deck) and (_decks[deck]["grid"] as Control).visible


## Миниатюра: мелкое лицо целиком в родном размере, рамка поверх его края —
## выбор (золото) или бан (красный крест и рамка цвета того, кто забанил).
func _make_thumb(cid: String, deck: String) -> Control:
	var thumb := Control.new()
	thumb.custom_minimum_size = THUMB
	thumb.mouse_filter = Control.MOUSE_FILTER_STOP
	thumb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	thumb.set_meta("banned_by", "")
	var face := TextureRect.new()
	face.texture = CardView.mini_texture(cid)
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
		over.draw_rect(r, Color(PixelTheme.BG, 0.55))
		var a := Vector2(8, 12)
		var b := r.size - Vector2(8, 12)
		over.draw_line(a, b, BAN_COLOUR, 3.0)
		over.draw_line(Vector2(b.x, a.y), Vector2(a.x, b.y), BAN_COLOUR, 3.0)
		over.draw_rect(r.grow(-1.0), BoardPanel.colour(by, BAN_COLOUR), false, 2.0)
	elif cid == _selected:
		over.draw_rect(r.grow(-1.0), PixelTheme.GOLD, false, 2.0)
	elif cid == _hovered:
		over.draw_rect(r.grow(-0.5), PixelTheme.TEXT_DIM, false, 1.0)


## Зона 6: ячейка на каждый ход банов по порядку — рамка цвета того, чей ход;
## внутри миниатюра забаненной карты целиком (в половину), её имя в две
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
			# Номер круга слева от его ячеек (строка над ними съела бы высоту сетки).
			var lap_col := HBoxContainer.new()
			lap_col.add_theme_constant_override("separation", 3)
			lap_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_slots.add_child(lap_col)
			var head := Label.new()
			L10n.bind(head, "ban.round_short", {"round": i / lap + 1})
			L10n.bind(head, "ban.round", {"round": i / lap + 1}, "tooltip_text")
			head.mouse_filter = Control.MOUSE_FILTER_PASS
			head.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
			head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			lap_col.add_child(head)
			lap_box = HBoxContainer.new()
			lap_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lap_box.add_theme_constant_override("separation", 2)
			lap_col.add_child(lap_box)
		var who := String(order[i])
		var colour := BoardPanel.colour(who, PixelTheme.TEXT)
		var now := i == turn_index and String(_view.get("turn", "")) != ""
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", PixelTheme.box(PixelTheme.PANEL_LO if not now else colour.darkened(0.6),
			colour if i <= turn_index else colour.darkened(0.55), 1, 1, 1))
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lap_box.add_child(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		slot.add_child(row)
		var card := String((bans[i] as Dictionary).get("card", "")) if i < bans.size() else ""
		# Пусто (ход впереди или SKIP) — тёмная рамка размером с миниатюру:
		# все восемь ячеек стоят ровно (критик UI).
		if card == "":
			var slot_hole := PanelContainer.new()
			slot_hole.add_theme_stylebox_override("panel", PixelTheme.box(PixelTheme.BG, colour.darkened(0.6), 1, 0, 0))
			slot_hole.custom_minimum_size = THUMB
			slot_hole.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(slot_hole)
		else:
			var pic := TextureRect.new()
			pic.custom_minimum_size = THUMB
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_SCALE
			pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			# Миниатюра целиком, как в сетках полуколод (владелец, 2026-11-01).
			pic.texture = CardView.mini_texture(card)
			row.add_child(pic)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.clip_contents = true  # длинное слово не вылезает за ячейку
		row.add_child(text)
		# Текущая ячейка залита цветом игрока — текст на ней светлый.
		var name_label := Label.new()
		name_label.text = L10n.text("ban.you") if who == _net.seat else EventLogPanel.player_name(who)
		name_label.add_theme_color_override("font_color", PixelTheme.TEXT if now else colour)
		name_label.clip_text = true
		name_label.custom_minimum_size.x = 30
		text.add_child(name_label)
		var what := Label.new()
		what.custom_minimum_size.x = 30
		if i < bans.size():
			# Имя карты уже на миниатюре — здесь её полуколода (критик UI).
			what.text = _deck_title(String(_cells[card]["deck"])) if _cells.has(card) else (L10n.text("ban.skipped") if card == "" else "")
			what.add_theme_color_override("font_color", PixelTheme.TEXT if card != "" else PixelTheme.TEXT_DIM)
			# Перенос только по пробелам (ICEWIND DALE); длинное слово обрезается,
			# целиком — в подсказке.
			what.autowrap_mode = TextServer.AUTOWRAP_WORD
			what.tooltip_text = what.text
			what.mouse_filter = Control.MOUSE_FILTER_PASS
		else:
			what.text = L10n.text("ban.now") if now else "-"
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
		L10n.bind(hint, "ban.hover")
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
	# Главная карта стоит на одном месте при любом наведении (критик UI): слева
	# от неё место под жетон, справа — под подсказки.
	card.position = Vector2(CardView.PIXEL_SIZE.x + CardPreview.MARGIN, 13)
	# Подпись — только состояние карты: полуколода и копии уже в подвале карты.
	var deck := String(_cells[cid]["deck"]) if _cells.has(cid) else ""
	var caption := Label.new()
	var by := String(banned_cards().get(cid, ""))
	var colour := PixelTheme.TEXT_DIM
	if by != "":
		L10n.bind(caption, "ban.banned", {"name": EventLogPanel.player_name(by)})
		colour = BAN_COLOUR
	elif (_view.get("locked", []) as Array).has(deck):
		caption.text = L10n.text("ban.deck_locked", {"deck": _deck_title(deck)})
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
	_place_extras(card, tokens, tips)


## Справа от карты — подсказки или жетоны (внахлёст, если их несколько). Есть
## и то и другое — справа жетоны, подсказки под картой поверх чата.
func _place_extras(card: CardView, tokens: Array[CardView], tips: Control) -> void:
	# Как у Alt (CardPreview): жетон слева от карты, подсказки справа.
	if tips != null:
		tips.size = tips.get_combined_minimum_size()
		tips.position = Vector2(card.position.x + card.size.x + CardPreview.MARGIN, card.position.y)
	_token_cycle = []
	_token_hold = false
	if tokens.is_empty():
		return
	card.draw.connect(func(): card.draw_rect(Rect2(-Vector2.ONE, card.size + Vector2(2, 2)), PixelTheme.GOLD, false, 1.0))
	# Место слева — под один жетон; несколько сменяют друг друга («TOKEN 1/2»).
	for i in tokens.size():
		tokens[i].position = Vector2(0, card.position.y)
		tokens[i].visible = i == 0
		if tokens.size() > 1:
			tokens[i].set_meta("tag", "%s %d/%d" % [String(tokens[i].get_meta("tag")), i + 1, tokens.size()])
	if tokens.size() > 1:
		_token_cycle = tokens
		_token_time = 0.0
		# Щелчок по жетону — следующий; пока мышь на нём, сам не листается.
		for t: CardView in tokens:
			t.mouse_filter = Control.MOUSE_FILTER_STOP
			L10n.bind(t, "ban.next_token", {}, "tooltip_text")
			t.mouse_entered.connect(func(): _token_hold = true)
			t.mouse_exited.connect(func(): _token_hold = false)
			t.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_next_token())


func _refresh() -> void:
	_refresh_info()
	var mine := my_turn()
	var turn := String(_view.get("turn", ""))
	var colour := BoardPanel.colour(turn, PixelTheme.TEXT)
	_skip.disabled = not mine
	_ban.disabled = not can_ban(_selected)
	_ban.tooltip_text = String(CardLibrary.card_data(_selected).get("name", ""))
	_ban.text = L10n.text("ban.ban_card", {"card": CardText.field(_selected, "name").to_upper()}) if _selected != "" else L10n.text("ban.ban")
	# BAN — главная кнопка: залита цветом банящего (критик UI); SKIP — обычная.
	var fill := PixelTheme.button_box(colour.darkened(0.45), colour.lightened(0.2))
	for state in ["normal", "hover", "pressed"]:
		_ban.add_theme_stylebox_override(state, fill)
	var seconds := ceili(_left)
	var starting := bool(_view.get("starting", false))
	_clock.text = "%d:%02d" % [seconds / 60, seconds % 60] if turn != "" or starting else ""
	_clock.add_theme_color_override("font_color", BAN_COLOUR.lightened(0.2) if seconds <= 10 and not starting else PixelTheme.TEXT)
	if starting and seconds > 0:
		# Баны кончились: 10 секунд посмотреть итог (владелец, 2026-11-03).
		_status.text = L10n.text("ban.starting", {"seconds": seconds})
		_status.add_theme_color_override("font_color", PixelTheme.GOLD)
		return
	if turn == "":
		_status.text = L10n.text("ban.done")
	elif mine and _selected != "":
		_status.text = L10n.text("ban.selected", {"card": CardText.field(_selected, "name").to_upper(), "deck": _deck_title(String(_cells[_selected]["deck"]))})
	elif mine:
		_status.text = L10n.text("ban.pick")
	else:
		_status.text = L10n.text("ban.other", {"name": EventLogPanel.player_name(turn).to_upper()})
	_status.add_theme_color_override("font_color", PixelTheme.GOLD if mine else colour)


## Сменить показанный жетон раз в TOKEN_SECONDS.
func _cycle_tokens(delta: float) -> void:
	if _token_cycle.size() < 2 or not is_instance_valid(_token_cycle[0]):
		return
	if _token_hold:
		return
	_token_time += delta
	if _token_time < TOKEN_SECONDS:
		return
	_next_token()


func _next_token() -> void:
	_token_time = 0.0
	var shown := 0
	for i in _token_cycle.size():
		if _token_cycle[i].visible:
			shown = i
	for i in _token_cycle.size():
		_token_cycle[i].visible = i == (shown + 1) % _token_cycle.size()


func _process(delta: float) -> void:
	_cycle_tokens(delta)
	if (String(_view.get("turn", "")) == "" and not bool(_view.get("starting", false))) or _left <= 0.0:
		return
	var before := ceili(_left)
	_left = maxf(0.0, _left - delta)
	if ceili(_left) != before:
		_refresh()


func _deck_title(deck: String) -> String:
	var key := "ban.deck." + deck
	return L10n.text(key) if L10n.catalog("en").has(key) else SetupScreen.deck_title(deck)


func _deck_tip(deck: String, shut: bool) -> String:
	var title := _deck_title(deck)
	var original := SetupScreen.deck_title(deck)
	return title + ("\n" + original if title != original else "") + ("\n" + L10n.text("ban.locked") if shut else "")


func _locale_changed() -> void:
	if _status == null:
		return
	var skip_disabled := _skip.disabled
	var ban_disabled := _ban.disabled
	for deck: String in _decks:
		var tab: Button = _decks[deck]["tab"]
		var shut := (_view.get("locked", []) as Array).has(deck)
		tab.text = ("x " if shut else "") + _deck_title(deck)
		tab.tooltip_text = _deck_tip(deck, shut)
	for cid: String in _cells:
		(_cells[cid]["face"] as TextureRect).texture = CardView.mini_texture(cid)
	_build_slots()
	_info_shown = "?"
	_refresh()
	# Changing language must not submit or re-enable an action awaiting the server.
	_skip.disabled = skip_disabled
	_ban.disabled = ban_disabled
	var scroll := _chat_scroll.scroll_vertical
	_chat_log.clear()
	for message: Dictionary in _messages:
		_append_chat(message.seat, message.text, message.deck)
	_chat_scroll.scroll_vertical = scroll
