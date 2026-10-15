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

const GameSettings := preload("res://scenes/game_settings.gd")
const MIN_SIZE := Vector2(176, 254)
const MARGIN := 4.0

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
	"TRANSFORM": "TRANSFORM: this card turns into the stronger card it names.",
}

static var active: CardPreview = null

var _source: CardView
var _card: CardView
## Карта под курсором и состояние Alt.
var _hovered: CardView
var _alt := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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


## Пока Alt зажат, показанная карта не пропадает, даже если мышь ушла с
## исходной (владелец, 2026-10-15): можно навести мышь на слова самой копии и
## прочитать подсказки. Отпустил Alt — карта пропадает. Пока Alt зажат,
## другая карта на пути мыши показанную не сменяет (владелец, 2026-10-15).
func _sync() -> void:
	if _alt and _card != null:
		return
	var hovered := _hovered != null and is_instance_valid(_hovered)
	if hovered and (_alt or _hovered.hover_full):
		if _source != _hovered:
			_show(_hovered)
	elif _card != null and not _alt:
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
	_add_keyword_tips(card, s)
	_place()


## Над каждым ключевым словом копии — прозрачная площадка с подсказкой:
## наведение мыши показывает, что делает это действие (KEYWORD_TIPS).
func _add_keyword_tips(card: CardView, s: Vector2) -> void:
	if CardView.pixel_texture(card.card_id) == null:
		return
	var notes: Array = []
	if card.live and CardView.live_data.has(card.card_id):
		notes = (CardView.live_data[card.card_id] as Dictionary).get("notes", [])
	var k := s / CardView.PIXEL_SIZE
	for spot: Array in CardLiveFace.keyword_spots(card.card_id, notes,
			int(CardView.PIXEL_SIZE.x), int(CardView.PIXEL_SIZE.y)):
		var tip := keyword_tip(String(spot[1]))
		if tip == "":
			continue
		var r: Rect2i = spot[0]
		var area := Control.new()
		area.mouse_filter = Control.MOUSE_FILTER_STOP
		area.tooltip_text = tip
		area.position = Vector2(r.position) * k
		area.size = Vector2(r.size) * k
		_card.add_child(area)


## Подсказка к ключевому слову карты ("" — нет).
static func keyword_tip(word: String) -> String:
	return String(KEYWORD_TIPS.get(word.to_upper(), ""))


func _hide() -> void:
	_source = null
	if _card != null:
		_card.queue_free()
		_card = null


## Копия стоит по центру экрана (решение владельца, 2026-09-24), откуда бы ни
## была исходная карта.
func _place() -> void:
	var area: Rect2 = get_global_rect()
	_card.global_position = (area.get_center() - _card.size * 0.5).floor()


func _process(_delta: float) -> void:
	if _card == null:
		return
	# Исходную карту могли пересоздать (перерисовка после хода) или спрятать;
	# с зажатым Alt копия остаётся до отпускания.
	if not _alt and (not is_instance_valid(_source) or not _source.is_visible_in_tree()):
		_hide()
		return
	_place()  # карта в руке приподнимается — копия едет следом
