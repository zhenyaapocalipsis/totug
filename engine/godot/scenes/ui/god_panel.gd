class_name GodPanel
extends PanelContainer

## Панель режима бога (хотсит, владелец 2026-10-20): слева во всю высоту
## экрана, поверх сводки ходов и дектрекера — доска остаётся открытой для
## щелчков. Сама партию не трогает: кнопки шлют action_requested (словарь
## GodMode без player_id — его добавляет экран), а инструмент доски (tool,
## colour) экран читает в своих обработчиках щелчков по доске.
## Клавиша G прячет и показывает панель (GameScreen).
## FX — вместо выдачи карты щелчок показывает её анимацию розыгрыша (fx_requested).

signal action_requested(action: Dictionary)
signal fx_requested(card_id: String)

const TOOL_OFF := ""
const TOOL_TROOP := "troop"
const TOOL_SPY := "spy"
const TOOL_ERASE := "erase"
const ZONE_TITLES := {"hand": "HAND", "deck": "DECK", "discard": "DISC", "inner": "INNER"}
const ROW_H := 12.0

## Инструмент доски: что делает щелчок по месту, локации или шпиону.
var tool := TOOL_OFF
## Цвет войск и шпионов инструмента: id игрока или "white" (только войска).
var colour := ""
## Сколько копий выдаёт щелчок по карте и куда.
var count := 1
var zone := "hand"
## Режим просмотра анимаций: в списке только карты с HsPlay, щелчок играет эффект.
var fx := false

var _ids: Array[String] = []
var _turn_buttons := {}
var _colour_buttons := {}
var _tool_buttons := {}
var _count_label: Label
var _search: LineEdit
var _list: VBoxContainer
var _cards: Array[Button] = []
## Заголовок колоды -> её кнопки в списке (заголовок прячется вместе с ними).
var _groups := {}
var _fx_button: Button
var _pause_button: Button
var _frame_label: Label
## Анимации розыгрыша экрана: пауза и шаг по кадрам (задаёт GameScreen).
var hs_play: HsPlay
var _hint: Label
var _preview: TextureRect


func _init(player_ids: Array[String]) -> void:
	_ids = player_ids.duplicate()
	colour = _ids[0] if not _ids.is_empty() else ""
	theme = PixelTheme.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", PixelTheme.box(PixelTheme.PANEL, PixelTheme.GOLD, 1, 3, 3))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	add_child(col)

	var title := Label.new()
	title.text = "GOD MODE"
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.tooltip_text = "G: hide or show this panel"
	col.add_child(title)

	col.add_child(_heading("TURN"))
	var turns: Array[Control] = []
	for pid: String in _ids:
		var b := _chip(pid, func(): action_requested.emit({"op": "set_turn", "player_id": pid}))
		b.tooltip_text = "Give the turn to %s now (start of turn, hands are kept)" % EventLogPanel.player_name(pid)
		_turn_buttons[pid] = b
		turns.append(b)
	col.add_child(_row(turns))

	col.add_child(_heading("RESOURCES"))
	for res: Array in [["POWER", "power"], ["INFL", "influence"], ["VP", "vp"]]:
		var name_label := Label.new()
		name_label.text = String(res[0])
		name_label.custom_minimum_size.x = 34
		var items: Array[Control] = [name_label]
		for step: int in [1, 5, -1]:
			var key := String(res[1])
			var b := _button("%+d" % step, func(): action_requested.emit({"op": "resources", key: step}))
			b.custom_minimum_size.x = 24
			items.append(b)
		col.add_child(_row(items))
	col.add_child(_row([
		_button("DRAW 1", func(): action_requested.emit({"op": "draw", "count": 1})),
		_button("HAND > DISC", func(): action_requested.emit({"op": "discard_hand"})),
	]))

	col.add_child(_heading("BOARD"))
	var tools: Array[Control] = []
	var group := ButtonGroup.new()
	for t: Array in [["OFF", TOOL_OFF], ["TROOP", TOOL_TROOP], ["SPY", TOOL_SPY], ["ERASE", TOOL_ERASE]]:
		var key := String(t[1])
		var b := _toggle(String(t[0]), group, key == tool)
		b.pressed.connect(func(): set_tool(key))
		_tool_buttons[key] = b
		tools.append(b)
	col.add_child(_row(tools))
	var chips: Array[Control] = []
	var colour_group := ButtonGroup.new()
	for pid: String in _ids + [GameState.WHITE]:
		var b := _chip(pid, func(): set_colour(pid))
		b.toggle_mode = true
		b.button_group = colour_group
		b.button_pressed = pid == colour
		b.tooltip_text = "Troops and spies of %s" % ("neutral white (troops only)" if pid == GameState.WHITE
			else EventLogPanel.player_name(pid))
		_colour_buttons[pid] = b
		chips.append(b)
	col.add_child(_row(chips))
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 60
	col.add_child(_hint)

	col.add_child(_heading("CARDS"))
	var zones: Array[Control] = []
	var zone_group := ButtonGroup.new()
	for z: String in GodMode.ZONES:
		var b := _toggle(String(ZONE_TITLES[z]), zone_group, z == zone)
		b.pressed.connect(func(): zone = z)
		b.tooltip_text = {"hand": "Cards go to the hand", "deck": "Cards go on top of the deck",
			"discard": "Cards go to the discard pile", "inner": "Cards go to the Inner Circle"}[z]
		zones.append(b)
	col.add_child(_row(zones))
	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.custom_minimum_size.x = 30
	_fx_button = _button("FX", func(): set_fx(_fx_button.button_pressed))
	_fx_button.toggle_mode = true
	_fx_button.tooltip_text = "Click a card to watch its play animation (only cards with one are listed)"
	col.add_child(_row([
		_button("-", func(): set_count(count - 1)), _count_label, _button("+", func(): set_count(count + 1)),
		_fx_button,
	]))
	_pause_button = _button("PAUSE", func(): toggle_pause())
	_pause_button.toggle_mode = true
	_pause_button.tooltip_text = "P: pause card animations"
	var back := _button("<", func(): step(-1))
	back.tooltip_text = "Left: previous frame (pauses)"
	var fwd := _button(">", func(): step(1))
	fwd.tooltip_text = "Right: next frame (pauses)"
	_frame_label = Label.new()
	_frame_label.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	col.add_child(_row([_pause_button, back, fwd, _frame_label]))
	_search = LineEdit.new()
	_search.placeholder_text = "search card..."
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String): _filter())
	col.add_child(_search)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_fill_cards()

	# Карта под курсором — крупно справа от панели, поверх доски.
	_preview = TextureRect.new()
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.visible = false
	_preview.top_level = true
	_preview.z_index = 960
	add_child(_preview)

	set_count(1)
	set_tool(TOOL_OFF)


## Карты по колодам (стартовые и запас, потом полуколоды как в half_decks.json,
## потом прочие), внутри колоды по цене: имя и цена (у стартовых и запаса цены нет).
func _fill_cards() -> void:
	for group: Array in deck_groups():
		var head := _heading(String(group[0]))
		head.add_theme_color_override("font_color", PixelTheme.GOLD)
		_list.add_child(head)
		var buttons: Array[Button] = []
		for cid: String in group[1]:
			var b := _card_button(cid, String(group[0]))
			_list.add_child(b)
			_cards.append(b)
			buttons.append(b)
		_groups[head] = buttons


## [[название колоды, [card_id по возрастанию цены]], ...]; каждая карта — один раз.
static func deck_groups() -> Array:
	var data := GameSetup._load_half_decks()
	var base: Array = (data.get("starting_deck", {}) as Dictionary).get("copies", {}).keys()
	for s: Dictionary in (data.get("supplies", {}) as Dictionary).values():
		base.append(String(s["card_id"]))
	var groups := [["BASE", base]]
	var decks: Dictionary = data.get("half_decks", {})
	for key: String in decks:
		groups.append([SetupScreen.deck_title(key), (decks[key] as Dictionary).get("copies", {}).keys()])
	groups.append(["OTHER", CardLibrary.all_ids()])
	var seen := {}
	var out := []
	for g: Array in groups:
		var ids: Array[String] = []
		for cid: Variant in g[1]:
			if not seen.has(String(cid)) and not CardLibrary.card_data(String(cid)).is_empty():
				seen[String(cid)] = true
				ids.append(String(cid))
		ids.sort_custom(func(a: String, b: String):
			var ca := _cost(a)
			var cb := _cost(b)
			return ca < cb if ca != cb else card_name(a).naturalnocasecmp_to(card_name(b)) < 0)
		if not ids.is_empty():
			out.append([g[0], ids])
	return out


static func _cost(cid: String) -> int:
	var cost: Variant = CardLibrary.card_data(cid).get("cost")
	return -1 if cost == null else int(cost)


func _card_button(cid: String, deck: String) -> Button:
	var cost: Variant = CardLibrary.card_data(cid).get("cost")
	var b := Button.new()
	b.text = card_name(cid) + ("" if cost == null else "  %d" % int(cost))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("card_id", cid)
	b.set_meta("search", "%s %s %s %s" % [card_name(cid), CardLibrary.card_aspect(cid),
		CardLibrary.card_type(cid), deck])
	b.add_theme_stylebox_override("normal", PixelTheme.fill(Color(0, 0, 0, 0), 2, 0))
	b.add_theme_stylebox_override("hover", PixelTheme.fill(PixelTheme.BORDER, 2, 0))
	b.add_theme_stylebox_override("pressed", PixelTheme.fill(PixelTheme.GOLD, 2, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", PixelTheme.TEXT)
	b.add_theme_color_override("font_hover_color", PixelTheme.GOLD)
	b.pressed.connect(func():
		if fx:
			fx_requested.emit(cid)
		else:
			give(cid))
	b.mouse_entered.connect(func(): _show_preview(cid, b))
	b.mouse_exited.connect(func(): _preview.visible = false)
	return b


static func card_name(cid: String) -> String:
	return String(CardLibrary.card_data(cid).get("name", cid))


## Выдать карту cid: count копий в зону zone.
func give(cid: String) -> void:
	action_requested.emit({"op": "give", "card_id": cid, "count": count, "zone": zone})


## Карты, подходящие под поиск (по имени, аспекту, расе).
func visible_cards() -> Array[String]:
	var out: Array[String] = []
	for b: Button in _cards:
		if b.visible:
			out.append(String(b.get_meta("card_id")))
	return out


func set_search(text: String) -> void:
	_search.text = text
	_filter()


func _filter() -> void:
	var words := _search.text.strip_edges().to_lower().split(" ", false)
	for b: Button in _cards:
		var hay := String(b.get_meta("search")).to_lower()
		var ok := not fx or HsPlay.has(String(b.get_meta("card_id")))
		for w: String in words:
			if not hay.contains(w):
				ok = false
				break
		b.visible = ok
	for head: Label in _groups:
		head.visible = (_groups[head] as Array).any(func(b: Button): return b.visible)


## FX включён: щелчок по карте показывает анимацию розыгрыша, а не выдаёт карту.
func set_fx(on: bool) -> void:
	fx = on
	_fx_button.set_pressed_no_signal(on)
	_filter()


## Пауза анимаций розыгрыша (клавиша P).
func toggle_pause() -> void:
	if hs_play != null:
		hs_play.set_paused(not hs_play.paused)


## Шаг анимации на n кадров, с паузой (стрелки влево и вправо).
func step(n: int) -> void:
	if hs_play != null:
		hs_play.step_frames(n)


func _process(_delta: float) -> void:
	if hs_play == null:
		return
	_pause_button.set_pressed_no_signal(hs_play.paused)
	var f := hs_play.frame_info()
	_frame_label.text = "" if f.y == 0 else "%d/%d" % [f.x + 1, f.y]


func set_count(value: int) -> void:
	count = clampi(value, 1, GodMode.MAX_COUNT)
	_count_label.text = "x%d" % count


func set_tool(value: String) -> void:
	tool = value
	(_tool_buttons[value] as Button).set_pressed_no_signal(true)
	if tool == TOOL_SPY and colour == GameState.WHITE:
		set_colour(_ids[0])
	_hint.text = {
		TOOL_OFF: "Board clicks play normally.",
		TOOL_TROOP: "Click a space: place a troop (again: remove).",
		TOOL_SPY: "Click a site: place a spy (again: remove).",
		TOOL_ERASE: "Click a troop or spy to remove it, a site to clear it.",
	}[tool]


func set_colour(pid: String) -> void:
	if pid == GameState.WHITE and tool == TOOL_SPY:
		pid = colour if colour != GameState.WHITE else _ids[0]
	colour = pid
	(_colour_buttons[pid] as Button).set_pressed_no_signal(true)


## Подсветить, чей сейчас ход.
func show_turn(current: String) -> void:
	for pid: String in _turn_buttons:
		var b: Button = _turn_buttons[pid]
		b.text = "<>" if pid == current else ""


func _show_preview(cid: String, from: Control) -> void:
	var tex := CardView.pixel_texture(cid)
	if tex == null:
		_preview.visible = false
		return
	_preview.texture = tex
	_preview.size = tex.get_size()
	var r := get_global_rect()
	var y := clampf(from.get_global_rect().position.y - tex.get_size().y * 0.5,
		r.position.y, maxf(r.position.y, r.end.y - tex.get_size().y))
	_preview.global_position = Vector2(r.end.x + 2.0, y)
	_preview.visible = true


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	return label


func _row(items: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for item: Control in items:
		row.add_child(item)
	return row


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 14)
	SetupScreen._style_button(b)
	b.pressed.connect(action)
	return b


func _toggle(text: String, group: ButtonGroup, on: bool) -> Button:
	var b := _button(text, func(): pass)
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = on
	return b


## Квадрат цвета игрока (или белый — нейтральные войска).
func _chip(pid: String, action: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(24, 14)
	var c: Color = Color(0.9, 0.9, 0.9) if pid == GameState.WHITE else BoardPanel.colour(pid, Color.GRAY)
	b.add_theme_stylebox_override("normal", PixelTheme.button_box(c.darkened(0.25), PixelTheme.BORDER))
	b.add_theme_stylebox_override("hover", PixelTheme.button_box(c, PixelTheme.GOLD))
	b.add_theme_stylebox_override("pressed", PixelTheme.button_box(c, PixelTheme.GOLD, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", PixelTheme.BG)
	b.add_theme_color_override("font_hover_color", PixelTheme.BG)
	b.add_theme_color_override("font_pressed_color", PixelTheme.BG)
	b.pressed.connect(action)
	return b
