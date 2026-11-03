class_name PilesWindow
extends Control

## Окно раскладки карт по стопкам (владелец, 2026-11-03, вариант B — игроки
## не понимали пошаговые вопросы):
##   Explore (tag "explore") — все просмотренные карты в ряд, справа от
##     каждой HAND (или PROMOTE) / TOP / BOTTOM и стрелки порядка; DONE
##     справа от всех карт шлёт весь расклад одним ответом-планом
##     (IxtalCards._Peek.PLAN).
##   Lamia (tag "lamia") — две стопки рядом, подписи вертикально слева от них:
##     "split" — хозяин Lamia щёлкает карту, и она переходит в другую стопку
##       (туда и обратно, пока не нажал DONE — тогда раздел уходит целиком);
##     "pick" — соперник видит открытую стопку картами, закрытую рубашками и
##       выбирает, какая вернётся ему на колоду; другую сыграет хозяин Lamia.
## Вид — как полоса вопроса (DecisionDialog, «Choose one»): та же полоса под
## доской над счётчиком Power/Influence, без подложки, высотой в карту — на
## доску не заходит (владелец, 2026-11-03: все вопросы на одной полосе).
## Слева карта, которая спрашивает, рядом «X decides», вопрос, подсказка,
## справа карты и кнопки. Состояние приходит с сервера в
## pending_decision.data; окно шлёт только ответ.

signal answered(answer: Variant)

const CARD := CardView.MINI_SIZE
const PLAN := "plan:"
const GAP := 4
## Ширина столбца вопроса: не уже и не шире этого, остальное — картам.
const TEXT_MIN := 120.0
const TEXT_MAX := 260.0
## Кнопки справа от карты одной ширины столбиком.
const BUTTON_W := 44.0

var _frame: PanelContainer
var _asker: HBoxContainer
var _who: Label
var _title: Label
var _hint: Label
var _text: VBoxContainer
var _body: HBoxContainer
## Explore: карты по порядку слева направо и куда каждая ("take" / "top" / "bottom").
var _cards: Array = []
var _where: Array = []
var _data: Dictionary = {}
## Lamia, раздел: открытая и закрытая стопки, пока игрок не нажал DONE.
var _up: Array = []
var _down: Array = []
var _viewer := ""
## Ключ показанного вопроса: тот же вопрос пришёл снова — расклад игрока не сбрасываем.
var _key := ""


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_frame.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DecisionDialog.HEAD_GAP)
	_frame.add_child(row)
	_asker = HBoxContainer.new()
	_asker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_asker)
	_text = VBoxContainer.new()
	_text.add_theme_constant_override("separation", 1)
	row.add_child(_text)
	_who = Label.new()
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label: Label in [_who, _title, _hint]:
		label.add_theme_color_override("font_shadow_color", PixelTheme.PANEL_LO)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		_text.add_child(label)
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", GAP * 2)
	row.add_child(_body)


## Низ окна — на столько выше низа зоны доски (как полоса DecisionDialog).
func set_strip_bottom(value: float) -> void:
	_frame.offset_top = -value
	_frame.offset_bottom = -value


## Вопросы, которые показывает это окно, а не DecisionDialog.
static func handles(pd: Dictionary) -> bool:
	return String(pd.get("tag", "")) in ["explore", "lamia"] and not (pd.get("data", {}) as Dictionary).is_empty()


## Показать вопрос pd (свой: варианты и данные есть только у решающего).
func show_decision(pd: Dictionary, viewer_id: String) -> void:
	_data = pd.get("data", {})
	_viewer = viewer_id
	var key := "%s|%s|%s" % [pd.get("tag", ""), pd.get("prompt", ""), str(_data)]
	visible = true
	if key == _key:
		return
	_key = key
	var decider := String(pd.get("player_id", viewer_id))
	_who.text = "%s decides" % EventLogPanel.player_name(decider)
	_who.modulate = EventLogPanel.player_color(decider)
	for child in _asker.get_children():
		_asker.remove_child(child)
		child.queue_free()
	var asker := String(pd.get("source_card", ""))
	if CardView.pixel_texture(asker) != null:
		var card := CardView.new(asker, int(CARD.x), int(CARD.y))
		card.set_card_owner(decider)
		card.highlight = false
		_asker.add_child(card)
	if String(pd.get("tag", "")) == "explore":
		_cards = (_data.get("cards", []) as Array).duplicate()
		_where = []
		for c in _cards:
			_where.append("top")
		_build_explore()
	elif String(_data.get("step", "")) == "split":
		_up = []
		_down = []
		_build_split()
	else:
		_build_pick()


func close() -> void:
	visible = false
	_key = ""


func _clear() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()


func _card(cid: String) -> CardView:
	var card := CardView.new(cid, int(CARD.x), int(CARD.y))
	card.set_clickable(false, false)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return card


## Кнопка темы, как Show у полосы вопроса; on — выбранная (нажатая, золотая надпись).
func _button(text: String, on: bool, action: Callable, width: float = BUTTON_W) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.x = width
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.toggle_mode = on
	b.button_pressed = on
	if on:
		for state in ["font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(state, PixelTheme.GOLD)
	b.pressed.connect(action)
	return b


## Вопрос и подсказка в столбце шириной во всё, что не заняли карты (но
## TEXT_MIN..TEXT_MAX); не влезают в высоту карты — вопрос обычным шрифтом.
func _set_text(title: String, hint: String) -> void:
	_title.text = title
	_hint.text = hint
	var used := _body.get_combined_minimum_size().x + CARD.x * float(_asker.get_child_count()) \
		+ DecisionDialog.HEAD_GAP * 2.0
	var width := clampf(size.x - 4.0 - used, TEXT_MIN, TEXT_MAX) if size.x > 0.0 else TEXT_MAX
	for label: Label in [_who, _title, _hint]:
		label.custom_minimum_size.x = width
	_title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	if _text_height(width) > CARD.y:
		_title.remove_theme_font_size_override("font_size")


func _text_height(width: float) -> float:
	var h := 0.0
	for label: Label in [_who, _title, _hint]:
		var font := label.get_theme_font("font")
		h += font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, width,
			label.get_theme_font_size("font_size")).y + 1.0
	return h


# --- Explore ---------------------------------------------------------------------

func _build_explore() -> void:
	_clear()
	var label := String(_data.get("take_label", "HAND"))
	var what := String(_data.get("what", ""))
	var takeable: Array = _data.get("takeable", [])
	for i in _cards.size():
		var cid := String(_cards[i])
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 2)
		var card := _card(cid)
		card.highlight = true
		card.set_clickable(_where[i] == "take", false)
		pair.add_child(card)
		# справа от карты столбиком: HAND, TOP, BOTTOM, стрелки порядка
		var actions := VBoxContainer.new()
		actions.add_theme_constant_override("separation", 1)
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		if takeable.has(cid) and (int(_data.get("take_left", 0)) > 0 or (_data.get("free", []) as Array).has(cid)):
			actions.add_child(_button(label, _where[i] == "take", _set_where.bind(i, "take")))
		actions.add_child(_button("TOP", _where[i] == "top", _set_where.bind(i, "top")))
		actions.add_child(_button("BOTTOM", _where[i] == "bottom", _set_where.bind(i, "bottom")))
		var move := HBoxContainer.new()
		move.add_theme_constant_override("separation", 1)
		move.add_child(_button("<", false, _swap.bind(i, i - 1), BUTTON_W * 0.5 - 0.5) if i > 0 else _spacer())
		move.add_child(_button(">", false, _swap.bind(i, i + 1), BUTTON_W * 0.5 - 0.5) if i < _cards.size() - 1 else _spacer())
		actions.add_child(move)
		pair.add_child(actions)
		_body.add_child(pair)
	_body.add_child(_button("DONE", false, _send_plan, 40.0))
	var rules := PackedStringArray()
	if int(_data.get("take_left", 0)) > 0 and takeable.is_empty():
		rules.append("No card here is %s." % what)
	elif int(_data.get("take_left", 0)) > 0:
		rules.append("%s: one card%s." % [label, " that is %s" % what if label == "HAND" and what != "" else ""])
	rules.append("TOP: the left one ends up on top.")
	_set_text("Explore the top %d cards:" % _cards.size() if label == "HAND"
		else "Promote one of the top %d cards:" % _cards.size(), " ".join(rules))


func _spacer() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.x = BUTTON_W * 0.5 - 0.5
	return gap


## Карта i — в руку, наверх или вниз. Обычную карту в руку можно одну:
## прежняя возвращается наверх (Living Gust of Wind выбор не тратит).
func _set_where(i: int, where: String) -> void:
	var free: Array = _data.get("free", [])
	if where == "take" and not free.has(String(_cards[i])):
		for j in _cards.size():
			if j != i and _where[j] == "take" and not free.has(String(_cards[j])):
				_where[j] = "top"
	_where[i] = where
	_build_explore()


func _swap(i: int, j: int) -> void:
	var c = _cards[i]
	_cards[i] = _cards[j]
	_cards[j] = c
	var w = _where[i]
	_where[i] = _where[j]
	_where[j] = w
	_build_explore()


## Расклад игрока ответом-планом "plan:take=..;top=..;bottom=..".
func plan() -> String:
	# Обычные массивы: PackedStringArray в словаре при приведении копируется,
	# и append уходил в копию — план уходил пустым.
	var parts := {"take": [], "top": [], "bottom": []}
	for i in _cards.size():
		(parts[_where[i]] as Array).append(String(_cards[i]))
	return "%stake=%s;top=%s;bottom=%s" % [PLAN, ",".join(PackedStringArray(parts["take"])),
		",".join(PackedStringArray(parts["top"])), ",".join(PackedStringArray(parts["bottom"]))]


func _send_plan() -> void:
	close()
	answered.emit(plan())


# --- Lamia -----------------------------------------------------------------------

## Стопка: подпись вертикально слева, карты (три и больше — внахлёст) или рубашки.
func _pile(caption: String, cards: Array, backs: int, click: Callable) -> HBoxContainer:
	var pile := HBoxContainer.new()
	pile.add_theme_constant_override("separation", 2)
	pile.add_child(VerticalLabel.new("%s %d" % [caption, cards.size() + backs]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2 if cards.size() + backs < 3 else -int(CARD.x * 0.45))
	row.custom_minimum_size = Vector2(CARD.x, CARD.y)
	for cid in cards:
		var card := _card(String(cid))
		if click.is_valid():
			card.highlight = true
			card.set_clickable(true)
			card.pressed.connect(click)
		row.add_child(card)
	var texture := CardBack.texture(PlayerProfile.back_of(_viewer))
	for i in backs:
		var rect := TextureRect.new()
		rect.texture = texture
		rect.custom_minimum_size = CARD
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(rect)
	pile.add_child(row)
	return pile


## Lamia, раздел: карта перекладывается щелчком из стопки в стопку туда и
## обратно (владелец, 2026-11-03); DONE шлёт открытую стопку целиком.
func _build_split() -> void:
	_clear()
	if _up.is_empty() and _down.is_empty():
		_up = (_data.get("face_up", []) as Array).duplicate()
		_down = (_data.get("face_down", []) as Array).duplicate()
	var rival := EventLogPanel.player_name(String(_data.get("rival", ""))).to_upper()
	_body.add_child(_pile("FACE UP", _up, 0, _move_card.bind(true)))
	_body.add_child(_pile("FACE DOWN", _down, 0, _move_card.bind(false)))
	_body.add_child(_button("DONE", false, func() -> void:
		var up := ",".join(PackedStringArray(_up))
		close()
		answered.emit("%sup=%s" % [PLAN, up]), 40.0))
	_set_text("Split %s's top cards:" % rival,
		"Click a card to move it to the other pile. %s returns one pile to their deck, you play the other." % rival)


func _move_card(cid: String, from_up: bool) -> void:
	var from: Array = _up if from_up else _down
	var to: Array = _down if from_up else _up
	from.erase(cid)
	to.append(cid)
	_build_split()


## Lamia, выбор соперника: справа от каждой стопки — кнопка «вернуть её на колоду».
func _build_pick() -> void:
	_clear()
	var rival := EventLogPanel.player_name(String(_data.get("rival", ""))).to_upper()
	_body.add_child(_pile("FACE UP", _data.get("face_up", []), 0, Callable()))
	_body.add_child(_button("BACK ON\nMY DECK", false, _pick.bind(0)))
	_body.add_child(_pile("FACE DOWN", [], int(_data.get("face_down_count", 0)), Callable()))
	_body.add_child(_button("BACK ON\nMY DECK", false, _pick.bind(1)))
	_set_text("Which pile goes back on your deck?", "%s plays the other pile for free." % rival)


func _pick(i: int) -> void:
	close()
	answered.emit(i)


## Подпись стопки снизу вверх (повёрнута на 90°): узкая, не тратит ширину полосы.
class VerticalLabel extends Control:
	var text := ""

	func _init(value: String) -> void:
		text = value
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		var font := get_theme_font("font", "Label")
		var font_size := get_theme_font_size("font_size", "Label")
		custom_minimum_size = Vector2(font.get_height(font_size), CARD.y)
		queue_redraw()

	func _draw() -> void:
		var font := get_theme_font("font", "Label")
		var font_size := get_theme_font_size("font_size", "Label")
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		# текст по центру высоты карты, читается снизу вверх
		draw_set_transform(Vector2(0.0, (CARD.y + width) * 0.5), -PI * 0.5)
		draw_string(font, Vector2(0.0, font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, PixelTheme.TEXT_DIM)
