class_name CardPreview
extends Control

## Полная версия карты под курсором — общая для руки, маркета, полосы
## сыгранных карт, стопок и сводки ходов. Копия рисуется по центру экрана
## поверх всего и мышь не ловит, так что щелчок проходит к настоящей карте.
##
## Когда показывается (решение владельца, 2026-10-06):
##   - навёл мышь на карту рынка или сводки ходов (CardView.hover_full);
##   - зажат Alt — над любой картой. Alt можно зажать до наведения.
## В обоих случаях это полная карта в родном размере 176x254, без увеличения
## и без анимации: не «зум», а полный формат вместо мелкого лица.
##
## Почему копия, а не scale самой карты: карты в маркете и на полосах мелкие,
## и растянутый масштабом текст получается мыльным. Копия собирается в нужном
## размере и остаётся чёткой.

const CardText := preload("res://scenes/card_text.gd")
const L10n := preload("res://scenes/localization.gd")
const GameSettings := preload("res://scenes/game_settings.gd")
const MIN_SIZE := Vector2(176, 254)
const MARGIN := 4.0
## Поля подсказки (рамка и отступ TooltipPanel) — текст уже ширины карты на столько.
const TIP_PAD := 8.0

## Что делает действие (владелец, 2026-10-15: подсказка при наведении на
## жирное слово карты; новые слова New Era и базовые).
const KEYWORD_TIPS := {
	"DEVOUR": "DEVOUR: remove a card from the game.\nIt goes to the devoured pile.",
	"SUPPLANT": "SUPPLANT: assassinate a troop where you have presence,\nthen deploy your own troop in its place.",
	"DEPLOY": "DEPLOY: put a troop from your barracks on a free space\nwhere you have presence.",
	"ASSASSINATE": "ASSASSINATE: remove a troop where you have presence.\nIt goes to your trophy hall (1 VP each).",
	"PLACE": "PLACE A SPY: put a spy on a site.\nIt gives you presence there and counts for control.",
	"RETURN": "RETURN: send a troop or spy where you have presence\nback to its owner.",
	"PROMOTE": "PROMOTE: move a card into your Inner Circle.\nIt leaves your deck and scores its Inner Circle VP.",
	"BRIBE": "BRIBE: give 1 VP token to an opponent of your choice\nto get the effect after the arrow.",
	"STEAL": "STEAL: take VP tokens from another player.",
	"RECRUIT": "RECRUIT: take a card into your discard pile.",
	"RECRUITS": "RECRUIT: take a card into your discard pile.",
	"MOVE": "MOVE: take a troop where you have presence\nand put it on any free space.",
	"FOCUS": "FOCUS: works if you played another card of this aspect\nthis turn or reveal one from your hand.",
	"SCRY": "SCRY N: look at the top N cards of your deck\nand discard any of them.",
	"MIGHT": "MIGHT: works if you devoured a card this turn.\nThe second Might on a card needs 2 devours, and so on.",
	"FROSTBITE": "FROSTBITE: works when this card is discarded from your hand\n(not by the end-of-turn discard).",
	"DEVOTION": "DEVOTION: works when you recruit or promote this card.",
	"RETAIN": "RETAIN: in your turn, keep this card instead of playing it.\nIt comes back into your next hand on top of the usual 5 cards.",
	"RETAINED": "RETAIN: in your turn, keep this card instead of playing it.\nIt comes back into your next hand on top of the usual 5 cards.",
	"GLAMOUR": "GLAMOUR: spend 1 VP token (back to the supply) to switch this ability on.\nOnly one Glamour per card.",
	"EXPLORE": "EXPLORE: look at the top 2 cards of your deck. Put up to one that matches into your hand,\nthe rest on the top or bottom of your deck in any order.",
	"TRANSFORM": "TRANSFORM: this card turns into the stronger card it names.",
	"DISTINCT": "DISTINCT: count each card aspect only once,\nhowever many cards of it you played this turn.",
}

static var active: CardPreview = null

var _source: CardView
var _card: CardView
## Карта под курсором и состояние Alt.
var _hovered: CardView
var _alt := false
## Столбик подсказок справа от копии и жетоны карты слева от неё (только с
## зажатым Alt; владелец, 2026-11-01: подсказки шириной в полную карту).
var _tips: VBoxContainer
var _tokens: Array[CardView] = []
## Тёмная подложка под группой с Alt (карта, подсказки, жетоны): доска не
## просвечивает между ними (критик UI, 2026-11-01).
var _backdrop: ColorRect


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	L10n.events.changed.connect(_language_changed)
	z_index = 1100  # над рукой (z до 901), меню и списком стопки (1000)


func _enter_tree() -> void:
	active = self


func _exit_tree() -> void:
	if active == self:
		active = null


## Курсор вошёл в карту.
static func set_hovered(card: CardView) -> void:
	if active != null:
		active._hovered = card
		active._sync()


## Курсор ушёл с карты (снимаем, только если это та самая карта).
static func clear_hovered(card: CardView) -> void:
	if active != null and active._hovered == card:
		active._hovered = null
		active._sync()


## Для проверок и для подсказки: зажат ли сейчас Alt.
func alt_held() -> bool:
	return _alt


## Для проверок: показана ли сейчас полная копия карты.
## Для проверок: размер показанной копии (без анимации роста).
func preview_size() -> Vector2:
	return _card.size if _card != null else Vector2.ZERO


func has_preview() -> bool:
	return _card != null


## Клавиша увеличения (Alt, переназначается в настройках) приходит двумя
## путями: событием самой клавиши и — если это Alt, Shift или Ctrl — флагом на
## любом другом событии (например, движении мыши с уже зажатой клавишей).
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if GameSettings.is_key(key, "zoom") or key.physical_keycode == GameSettings.key("zoom"):
			_set_alt(key.pressed)
			return
	if event is InputEventWithModifiers:
		var held: Variant = GameSettings.modifier_held(event as InputEventWithModifiers, "zoom")
		if held != null:
			_set_alt(bool(held))


func _set_alt(value: bool) -> void:
	if _alt == value:
		return
	_alt = value
	_sync()


## Копия живёт, пока мышь на исходной карте (фиксация по Alt убрана,
## владелец, 2026-10-16). С зажатым Alt справа от копии сразу стоит столбик
## подсказок ко всем жирным действиям карты — наводить мышь на слова не нужно.
func _sync() -> void:
	var hovered := _hovered != null and is_instance_valid(_hovered)
	if hovered and (_alt or _hovered.hover_full):
		if _source != _hovered:
			_show(_hovered)
		_sync_tips()
	elif _card != null:
		_hide()


## Показать полную версию карты в родном размере.
func _show(card: CardView) -> void:
	_hide()
	_source = card
	var room := get_viewport_rect().size - Vector2.ONE * MARGIN * 2
	var s: Vector2
	if CardView.pixel_texture(card.card_id) != null:
		s = CardView.PIXEL_SIZE.min(room)
	else:
		s = MIN_SIZE
	_card = CardView.new(card.card_id, int(s.x), int(s.y))
	_card.hover_preview = false
	_card.set_skin(card.skin)
	_card.set_art(card.art)
	_card.set_live(card.live)
	_card.set_clickable(card.clickable, false)
	CardView._ignore_mouse(_card)
	add_child(_card)
	_card.size = s
	_card.pivot_offset = s * 0.5
	_place()


## Столбик подсказок и жетоны есть, только пока зажат Alt.
func _sync_tips() -> void:
	if _alt and _tips == null and _tokens.is_empty() and _source != null:
		_tips = tips_column(_source, _card.size.x)
		if _tips != null:
			add_child(_tips)
		_tokens = token_cards(_source.card_id, _card.size)
		for t: CardView in _tokens:
			add_child(t)
		_place()
	elif not _alt:
		_drop_extras()


func _drop_extras() -> void:
	if _backdrop != null:
		_backdrop.queue_free()
		_backdrop = null
	if _tips != null:
		_tips.queue_free()
		_tips = null
	for t: CardView in _tokens:
		t.queue_free()
	_tokens.clear()


## Подсказки ко всем жирным действиям карты (KEYWORD_TIPS) по порядку текста,
## каждая один раз, столбиком шириной width (ширина полной карты); null —
## подсказывать нечего. Общий и для лобби банов (BanPanel).
static func tips_column(card: CardView, width: float) -> VBoxContainer:
	var tips := tips_for(card)
	if tips.is_empty():
		return null
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	for tip: String in tips:
		var panel := PanelContainer.new()
		panel.theme_type_variation = "TooltipPanel"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.theme_type_variation = "TooltipLabel"
		# Переносы — по ширине карты, а не заданные в тексте.
		label.text = tip.replace("\n", " ")
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = width - TIP_PAD
		panel.add_child(label)
		col.add_child(panel)
	return col


## Тексты подсказок к жирным словам карты, без повторов.
static func tips_for(card: CardView) -> Array[String]:
	var out: Array[String] = []
	if CardView.pixel_texture(card.card_id) == null:
		return out
	var notes: Array = []
	if card.live and CardView.live_data.has(card.card_id):
		notes = (CardView.live_data[card.card_id] as Dictionary).get("notes", [])
	for spot: Array in CardLiveFace.keyword_spots(card.card_id, notes,
			int(CardView.PIXEL_SIZE.x), int(CardView.PIXEL_SIZE.y)):
		var tip := keyword_tip(String(spot[1]))
		if tip != "" and not out.has(tip):
			out.append(tip)
	return out


## Для проверок: сколько подсказок стоит в столбике.
func tips_shown() -> int:
	return _tips.get_child_count() if _tips != null else 0


## Подсказка к ключевому слову карты ("" — нет).
static func keyword_tip(word: String) -> String:
	var key := "keyword." + CardText.keyword(word)
	return L10n.text(key) if L10n.catalog("en").has(key) else String(KEYWORD_TIPS.get(word.to_upper(), ""))


func _hide() -> void:
	_source = null
	_drop_extras()
	if _card != null:
		_card.queue_free()
		_card = null


## Копия стоит по центру экрана (решение владельца, 2026-09-24), откуда бы ни
## была исходная карта.
func _place() -> void:
	var area: Rect2 = get_global_rect()
	_card.global_position = (area.get_center() - _card.size * 0.5).floor()
	place_extras(_card, _tokens, _tips, area)
	_place_backdrop()


func _place_backdrop() -> void:
	if _tips == null and _tokens.is_empty():
		return
	if _backdrop == null:
		_backdrop = ColorRect.new()
		_backdrop.color = Color(0, 0, 0, 0.5)
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_backdrop)
	# Жетоны place_extras ставит в начало списка детей — подложка ещё раньше.
	move_child(_backdrop, 0)
	var box := _card.get_global_rect()
	if _tips != null:
		box = box.merge(_tips.get_global_rect())
	for t: CardView in _tokens:
		box = box.merge(t.get_global_rect())
	# Подписи жетонов стоят над картами — подложка чуть выше.
	box = box.grow(MARGIN)
	box.position.y -= 10
	box.size.y += 10
	_backdrop.global_position = box.position
	_backdrop.size = box.size


## Полные копии жетонов и вторых сторон карты (CollectionPage.TOKENS) размера
## size — показываются слева от неё.
static func token_cards(cid: String, size: Vector2) -> Array[CardView]:
	var out: Array[CardView] = []
	for token: String in CollectionPage.card_forms(cid).slice(1):
		var view := CardView.new(token, int(size.x), int(size.y))
		view.hover_preview = false
		CardView._ignore_mouse(view)
		view.size = size
		# Подпись над жетоном (критик UI, 2026-11-01): что это за карта.
		var tag := "TRANSFORMS INTO" if String(CardLibrary.card_data(cid).get("ability_text", "")).to_upper().contains("TRANSFORM") else "TOKEN"
		view.set_meta("tag", tag)
		view.draw.connect(func():
			var font := view.get_theme_default_font()
			view.draw_string(font, Vector2(0, -3), L10n.text("card.token" if view.get_meta("tag") == "TOKEN" else "card.transforms_into"), HORIZONTAL_ALIGNMENT_LEFT, -1, PixelTheme.SIZE, PixelTheme.TEXT_DIM))
		L10n.events.changed.connect(view.queue_redraw)
		out.append(view)
	return out


## Подсказки — справа от карты, жетоны — слева, первый вплотную к ней. Не
## помещаются в area слева — жетоны наезжают друг на друга, но не за край.
static func place_extras(card: Control, tokens: Array[CardView], tips: Control, area: Rect2) -> void:
	# Есть жетоны — главная карта в золотой рамке, чтобы не спутать.
	if not tokens.is_empty() and not card.has_meta("framed"):
		card.set_meta("framed", true)
		card.draw.connect(func(): card.draw_rect(Rect2(-Vector2.ONE, card.size + Vector2(2, 2)), PixelTheme.GOLD, false, 1.0))
		card.queue_redraw()
	if tips != null:
		tips.size = tips.get_combined_minimum_size()
		tips.global_position = card.global_position + Vector2(card.size.x + MARGIN, 0)
	if tokens.is_empty():
		return
	var step := card.size.x + MARGIN
	var room := card.global_position.x - area.position.x - MARGIN
	if tokens.size() * step > room:
		step = maxf(12.0, (room - card.size.x) / maxf(1.0, tokens.size() - 1)) if tokens.size() > 1 else room
	for i in tokens.size():
		var t := tokens[i]
		t.global_position = (card.global_position - Vector2(card.size.x + MARGIN + step * i, 0)).floor()
		# Дальний жетон — под ближним: раньше в списке детей (z_index ниже нуля
		# спрятал бы его под фоном экрана).
		if t.get_parent() != null:
			t.get_parent().move_child(t, 0)


func _process(_delta: float) -> void:
	if _card == null:
		return
	# Исходную карту могли пересоздать (перерисовка после хода) или спрятать.
	if not is_instance_valid(_source) or not _source.is_visible_in_tree():
		_hide()
		return
	_place()  # карта в руке приподнимается — копия едет следом


func _language_changed() -> void:
	_drop_extras()
	if _card != null:
		_sync_tips()
