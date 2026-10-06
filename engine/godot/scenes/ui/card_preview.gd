class_name CardPreview
extends Control

## Полная версия карты под курсором — общая для руки, маркета, полосы
## сыгранных карт, стопок и сводки ходов. Копия рисуется по центру экрана
## поверх всего и мышь не ловит, так что щелчок проходит к настоящей карте.
##
## Два режима (решение владельца, 2026-09-26):
##   - просто навёл мышь на карту рынка или сводки ходов (CardView.hover_full)
##     — полная карта в родном размере 176x254, без
##     анимации: не «увеличение», а полный формат вместо мелкого лица; в руке,
##     на полосе сыгранных и в стопках наведение без Alt ничего не показывает;
##   - зажат Alt — любая карта в наибольшем целом масштабе (на 960x540 это
##     2x), с короткой анимацией роста. Alt можно зажать до наведения и
##     отпустить после — копия растёт и сжимается следом.
##
## Почему копия, а не scale самой карты: карты в маркете и на полосах мелкие,
## и растянутый масштабом текст получается мыльным. Копия собирается в нужном
## размере и остаётся чёткой.

const GameSettings := preload("res://scenes/game_settings.gd")
const GROW := 1.15
const MIN_SIZE := Vector2(176, 254)
const MARGIN := 4.0
const ANIM_TIME := 0.09
## Полная карта 176x254 под Alt — в наибольшем целом масштабе, какой влезает
## в экран. Целый масштаб обязателен: при дробном пиксели карты разъезжаются.
const PIXEL_SCALE_MAX := 2.0

static var active: CardPreview = null

var _source: CardView
var _card: CardView
## Карта под курсором и состояние Alt; _big — копия показана в режиме Alt.
var _hovered: CardView
var _alt := false
var _big := false


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


func _sync() -> void:
	var hovered := _hovered != null and is_instance_valid(_hovered)
	if hovered and (_alt or _hovered.hover_full):
		if _source != _hovered or _big != _alt:
			_show(_hovered, _alt)
	elif _card != null:
		_hide()


## Показать полную версию карты: big — под Alt, крупно и с ростом.
func _show(card: CardView, big: bool) -> void:
	# Растём от того, что было на экране: от полной копии (Alt зажали над
	# уже показанной картой) или от самой мелкой карты.
	var from_size: Vector2 = _card.size if _card != null and _source == card else card.size
	_hide()
	_source = card
	_big = big
	var room := get_viewport_rect().size - Vector2.ONE * MARGIN * 2
	var s: Vector2
	if CardView.pixel_texture(card.card_id) != null:
		var k := 1.0
		if big:
			var fit := floorf(minf(room.x / CardView.PIXEL_SIZE.x, room.y / CardView.PIXEL_SIZE.y))
			k = clampf(fit, 1.0, PIXEL_SCALE_MAX)  # целый масштаб — пиксели ровные
		s = (CardView.PIXEL_SIZE * k).min(room)
	else:
		s = ((card.size * GROW).max(MIN_SIZE) if big else MIN_SIZE).round()
	_card = CardView.new(card.card_id, int(s.x), int(s.y))
	_card.hover_preview = false
	_card.set_skin(card.skin)
	_card.set_clickable(card.clickable, false)
	CardView._ignore_mouse(_card)
	add_child(_card)
	_card.size = s
	_card.pivot_offset = s * 0.5
	_place()
	if big:
		_card.scale = (from_size / s).clamp(Vector2(0.2, 0.2), Vector2.ONE)
		create_tween().tween_property(_card, "scale", Vector2.ONE, ANIM_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _hide() -> void:
	_source = null
	_big = false
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
	# Исходную карту могли пересоздать (перерисовка после хода) или спрятать.
	if not is_instance_valid(_source) or not _source.is_visible_in_tree():
		_hide()
		return
	_place()  # карта в руке приподнимается — копия едет следом
