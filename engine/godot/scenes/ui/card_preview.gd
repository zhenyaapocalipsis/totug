class_name CardPreview
extends Control

## Увеличенная копия карты под курсором — общая для руки, маркета, полосы
## сыгранных карт и стопок. Копия рисуется поверх всего экрана и мышь не ловит,
## так что щелчок проходит к настоящей карте под ней.
##
## Показывается ТОЛЬКО пока зажат Alt (решение владельца): при обычном
## наведении карта не увеличивается и ничего не закрывает. Alt можно зажать до
## наведения и отпустить после — копия появляется и исчезает следом.
##
## Почему копия, а не scale самой карты: карты в маркете и на полосах мелкие,
## и растянутый масштабом текст получается мыльным. Копия собирается в нужном
## размере и остаётся чёткой. Короткая анимация масштаба от размера исходной
## карты делает вид, что увеличилась сама карта.

const GROW := 1.15
const MIN_SIZE := Vector2(176, 254)
const MARGIN := 4.0
const ANIM_TIME := 0.09
## Экран — 640x360, и полная карта 176x254 помещается на нём ровно один раз.
## Целый масштаб обязателен: при дробном пиксели карты разъезжаются.
const PIXEL_SCALE := 1.0

static var active: CardPreview = null

var _source: CardView
var _card: CardView
## Карта под курсором и состояние Alt — копия живёт, только когда есть оба.
var _hovered: CardView
var _alt := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100


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


## Для проверок: показана ли сейчас увеличенная копия.
func has_preview() -> bool:
	return _card != null


## Alt приходит двумя путями: событием самой клавиши и флагом alt_pressed на
## любом другом событии (например, движении мыши с уже зажатым Alt).
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode == KEY_ALT or key.physical_keycode == KEY_ALT:
			_set_alt(key.pressed)
			return
	if event is InputEventWithModifiers:
		_set_alt((event as InputEventWithModifiers).alt_pressed)


func _set_alt(value: bool) -> void:
	if _alt == value:
		return
	_alt = value
	_sync()


func _sync() -> void:
	if _alt and _hovered != null and is_instance_valid(_hovered):
		if _source != _hovered:
			_show(_hovered)
	elif _card != null:
		_hide()


func _show(card: CardView) -> void:
	_hide()
	_source = card
	var s: Vector2 = (card.size * GROW).max(MIN_SIZE).round()
	if CardView.pixel_texture(card.card_id) != null:
		s = CardView.PIXEL_SIZE * PIXEL_SCALE  # целый масштаб — пиксели ровные
		s = s.min(get_viewport_rect().size - Vector2.ONE * MARGIN * 2)
	_card = CardView.new(card.card_id, int(s.x), int(s.y))
	_card.hover_preview = false
	_card.set_clickable(card.clickable, false)
	CardView._ignore_mouse(_card)
	add_child(_card)
	_card.size = s
	_card.pivot_offset = s * 0.5
	_card.scale = (card.size / s).clamp(Vector2(0.2, 0.2), Vector2.ONE)
	_place()
	create_tween().tween_property(_card, "scale", Vector2.ONE, ANIM_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _hide() -> void:
	_source = null
	if _card != null:
		_card.queue_free()
		_card = null


## Копия стоит по центру исходной карты, но не вылезает за край экрана:
## у нижней руки растёт вверх, у верхней полосы — вниз, у маркета — влево.
func _place() -> void:
	var r: Rect2 = _source.get_global_rect()
	var s: Vector2 = _card.size
	var area: Rect2 = get_global_rect().grow(-MARGIN)
	var pos: Vector2 = r.get_center() - s * 0.5
	pos.x = clampf(pos.x, area.position.x, maxf(area.end.x - s.x, area.position.x))
	pos.y = clampf(pos.y, area.position.y, maxf(area.end.y - s.y, area.position.y))
	_card.global_position = pos


func _process(_delta: float) -> void:
	if _card == null:
		return
	# Исходную карту могли пересоздать (перерисовка после хода) или спрятать.
	if not is_instance_valid(_source) or not _source.is_visible_in_tree():
		_hide()
		return
	_place()  # карта в руке приподнимается — копия едет следом
