class_name CardPreview
extends Control

## Увеличенная копия карты под курсором — общая для руки, маркета и полос
## сыгранных карт. Копия рисуется поверх всего экрана и мышь не ловит, так что
## щелчок проходит к настоящей карте под ней.
##
## Почему копия, а не scale самой карты: карты в маркете и на полосах мелкие,
## и растянутый масштабом текст получается мыльным. Копия собирается в нужном
## размере и остаётся чёткой. Короткая анимация масштаба от размера исходной
## карты делает вид, что увеличилась сама карта.

const GROW := 1.15
const MIN_SIZE := Vector2(176, 246)
const MARGIN := 6.0
const ANIM_TIME := 0.09

static var active: CardPreview = null

var _source: CardView
var _card: CardView


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100


func _enter_tree() -> void:
	active = self


func _exit_tree() -> void:
	if active == self:
		active = null


static func show_for(card: CardView) -> void:
	if active != null:
		active._show(card)


static func hide_for(card: CardView) -> void:
	if active != null and active._source == card:
		active._hide()


func _show(card: CardView) -> void:
	_hide()
	_source = card
	var s: Vector2 = (card.size * GROW).max(MIN_SIZE).round()
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
	_place()  # рука выезжает — копия едет следом
