class_name BanPanel
extends Control

## Лобби банов поиска игры (этап Ban-1, владелец 2026-10-29). Стол собран —
## показаны все карты выбранных полуколод (у каждой — число копий), игроки по
## очереди банят до GameRoom.BANS_EACH карт; все копии забаненной карты уходят
## из рынка (в RANDOM рынок набирается из оставшихся). На бан минута, SKIP —
## пропустить свой бан. Состояние приходит с сервера (GameRoom.ban_view);
## экран только показывает его и шлёт выбор (NetSession.ban_card).
##
## Вёрстка кодом по той же причине, что и в game_screen.gd.

const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")
const CARD := Vector2i(CardView.MINI_SIZE)

var _net: NetSession
var _view: Dictionary = {}
var _left := 0.0
var _selected := ""
var _title: Label
var _status: Label
var _list: VBoxContainer
var _bans_line: RichTextLabel
var _skip: Button
var _ban: Button
## card_id -> {"card": CardView, "frame": Panel, "mark": Label}
var _cells: Dictionary = {}


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
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", GameScreen.zone_style(6))
	margin.add_child(plate)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	plate.add_child(col)

	_title = Label.new()
	_title.text = "BAN CARDS"
	_title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	_title.add_theme_color_override("font_color", PixelTheme.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	var note := Label.new()
	note.text = "Players take turns banning up to %d cards each. All copies of a banned card leave the market." \
		% GameRoom.BANS_EACH
	note.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)

	_bans_line = RichTextLabel.new()
	_bans_line.bbcode_enabled = true
	_bans_line.fit_content = true
	_bans_line.scroll_active = false
	_bans_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	_bans_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_bans_line)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 4)
	col.add_child(buttons)
	_skip = Button.new()
	_skip.text = "SKIP"
	_skip.custom_minimum_size = Vector2(70, 16)
	_skip.pressed.connect(func(): _send(""))
	buttons.add_child(_skip)
	_ban = Button.new()
	_ban.text = "BAN"
	_ban.custom_minimum_size = Vector2(140, 16)
	_ban.pressed.connect(func(): _send(_selected))
	buttons.add_child(_ban)
	# Полная карта при наведении (CardView.hover_full).
	add_child(CardPreview.new())


## Новое состояние с сервера.
func show_view(view: Dictionary) -> void:
	var decks: Array = view.get("decks", [])
	if decks != _view.get("decks", []):
		_build(decks)
	_view = view
	_left = float(view.get("left", 0.0))
	var banned := banned_cards()
	if banned.has(_selected) or not my_turn():
		_selected = ""
	for cid: String in _cells:
		var cell: Dictionary = _cells[cid]
		var by := String(banned.get(cid, ""))
		# Золотую рамку «можно нажать» не рисуем: она была бы у всех карт сразу
		# и прятала рамку выбранной. Забаненная — приглушена.
		(cell["card"] as CardView).set_clickable(false, by != "")
		var mark: Label = cell["mark"]
		mark.visible = by != ""
		if by != "":
			mark.add_theme_color_override("font_color", BoardPanel.colour(by, PixelTheme.DANGER))
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


## Для проверок: какие карты показаны.
func shown_cards() -> Array:
	return _cells.keys()


## Щелчок по карте в свой ход — выбрать её (BAN подтверждает).
func select(cid: String) -> void:
	if not my_turn() or banned_cards().has(cid) or not _cells.has(cid):
		return
	_selected = cid
	_refresh()


func _send(card: String) -> void:
	if not my_turn():
		return
	_net.ban_card(card)
	# Пока сервер не ответил, второй раз не жмём.
	_skip.disabled = true
	_ban.disabled = true


func _build(decks: Array) -> void:
	for child in _list.get_children():
		child.queue_free()
	_cells.clear()
	for deck in decks:
		var copies := GameSetup.half_deck_copies(String(deck))
		_list.add_child(GameScreen.section_label("%s  (%d cards)" % [SetupScreen.deck_title(String(deck)),
			copies.values().reduce(func(a, n): return a + int(n), 0)]))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 2)
		flow.add_theme_constant_override("v_separation", 2)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_child(flow)
		var ids: Array = copies.keys()
		ids.sort_custom(func(a, b):
			var ca := CollectionPage.card_cost(a)
			var cb := CollectionPage.card_cost(b)
			return ca < cb if ca != cb else String(a) < String(b))
		for cid: String in ids:
			if _cells.has(cid):
				continue  # DOUBLE: одна полуколода дважды — карта одна
			flow.add_child(_make_cell(cid, int(copies[cid])))


func _make_cell(cid: String, count: int) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 0)
	var box := Control.new()
	box.custom_minimum_size = CARD + Vector2i(2, 2)
	cell.add_child(box)
	# Рамка выбранной карты — золотая, на пиксель вокруг.
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", PixelTheme.box(Color(0, 0, 0, 0), PixelTheme.GOLD, 1, 1, 1))
	frame.visible = false
	box.add_child(frame)
	var card := CardView.new(cid, CARD.x, CARD.y)
	card.hover_full = true
	card.position = Vector2(1, 1)
	card.size = Vector2(CARD)
	card.pressed.connect(func(c: String): select(c))
	card.refused.connect(func(c: String): select(c))
	box.add_child(card)
	# Забаненная карта: крупное BANNED цвета того, кто забанил, поверх арта.
	var mark := Label.new()
	mark.text = "BANNED"
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_theme_color_override("font_outline_color", PixelTheme.BG)
	mark.add_theme_constant_override("outline_size", 3)
	# Тёмная плашка под надписью: на пёстром арте без неё не читается.
	mark.add_theme_stylebox_override("normal", PixelTheme.box(Color(PixelTheme.BG, 0.85), Color(PixelTheme.BG, 0.85), 0, 0, 0))
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Ровно по ширине арта (рамка карты + MINI_ART).
	mark.position = Vector2(1 + CardView.MINI_ART.x, CardView.MINI_ART.y + 18)
	mark.size = Vector2(CardView.MINI_ART.z - CardView.MINI_ART.x, 12)
	mark.clip_text = true
	mark.visible = false
	box.add_child(mark)
	var copies := Label.new()
	copies.text = "x%d" % count
	copies.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	copies.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(copies)
	_cells[cid] = {"card": card, "frame": frame, "mark": mark}
	return cell


func _refresh() -> void:
	for cid: String in _cells:
		(_cells[cid]["frame"] as Panel).visible = cid == _selected
	var mine := my_turn()
	_skip.disabled = not mine
	_ban.disabled = not mine or _selected == ""
	_ban.text = "BAN %s" % String(CardLibrary.card_data(_selected).get("name", "")).to_upper() if _selected != "" else "BAN"
	# Сколько своих банов уже сделано — «1 of 2».
	var done := 0
	for b: Dictionary in _view.get("bans", []):
		if String(b["seat"]) == _net.seat:
			done += 1
	var turn := String(_view.get("turn", ""))
	var seconds := ceili(_left)
	var clock := "%d:%02d" % [seconds / 60, seconds % 60]
	if turn == "":
		_status.text = "Bans are done. Dealing the cards..."
	elif mine:
		_status.text = "Your ban (%d of %d): click a card, then BAN or SKIP.  %s" % [done + 1,
			int(_view.get("each", GameRoom.BANS_EACH)), clock]
	else:
		_status.text = "%s is banning...  %s" % [EventLogPanel.player_name(turn), clock]
	_status.add_theme_color_override("font_color", PixelTheme.GOLD if mine else PixelTheme.TEXT)
	var parts: PackedStringArray = []
	for b: Dictionary in _view.get("bans", []):
		var who := String(b["seat"])
		var what := String(CardLibrary.card_data(String(b["card"])).get("name", "")) if String(b["card"]) != "" else "skipped"
		parts.append("[color=#%s]%s[/color]: %s" % [BoardPanel.colour(who, PixelTheme.TEXT).to_html(false),
			EventLogPanel.player_name(who), what])
	_bans_line.text = "BANS  " + (",  ".join(parts) if not parts.is_empty() else "none yet")


func _process(delta: float) -> void:
	if String(_view.get("turn", "")) == "" or _left <= 0.0:
		return
	var before := ceili(_left)
	_left = maxf(0.0, _left - delta)
	if ceili(_left) != before:
		_refresh()
