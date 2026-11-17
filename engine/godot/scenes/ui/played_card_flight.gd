extends TextureRect

const ENTER_TIME := 0.30
const HOLD_TIME := 0.85
const EXIT_TIME := 0.38

var _motion: Tween
var _dwell: Tween
var _slot: CardView
var _feed: TurnFeed
var _departing := false
var card_id: String
var _find_choice_card: Callable
var _choice_card: CardView
var _choice_owner := ""
var _dock_start: Rect2
var _dock_rect: Rect2
var _dock_time := 0.0


func _init(cid: String, face: Texture2D) -> void:
	card_id = cid
	texture = face
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_process(false)


## Старт в координатах экрана, посадка в координатах слоя карты.
func enter(from: Rect2, stage: Rect2) -> void:
	global_position = from.position
	size = from.size
	var start := get_rect()
	_motion = create_tween()
	_motion.tween_method(func(t: float):
		size = start.size.lerp(stage.size, t).round()
		position = (start.get_center().lerp(stage.get_center(), t) - size * 0.5
			- Vector2(0, 14.0 * sin(t * PI))).round(),
		0.0, 1.0, ENTER_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func park_at(slot: CardView, feed: TurnFeed, unique: bool) -> void:
	_slot = slot
	_feed = feed
	_slot.modulate.a = 0.0
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dwell = create_tween()
	_dwell.tween_interval(0.35 if unique else ENTER_TIME + HOLD_TIME)
	_dwell.tween_callback(depart)


func is_docking() -> bool:
	return _find_choice_card.is_valid()


## Во время посадки миниатюра остаётся в раскладке и принимает ввод.
## В конце полёта её лицо подменяет спрайт в том же прямоугольнике.
func dock_to(find_choice_card: Callable, owner: String) -> void:
	_motion.kill()
	_dwell.kill()
	_find_choice_card = find_choice_card
	_choice_owner = owner
	_dock_start = get_global_rect()
	_dock_rect = _dock_start
	set_process(true)
	_process(0.0)


func _process(delta: float) -> void:
	if not is_docking():
		return
	var target: CardView = _find_choice_card.call()
	if target != _choice_card:
		_show_choice_card()
		_choice_card = target
		if target != null and target.owner_seat != _choice_owner:
			target.set_card_owner(_choice_owner)
	if target == null:
		hide()
		return
	var rect := target.get_global_rect()
	if not rect.has_area():
		target.modulate.a = 0.0
		hide()
		return
	_dock_time = minf(ENTER_TIME, _dock_time + delta)
	if _dock_time >= ENTER_TIME:
		_dock_rect = rect
		target.modulate.a = 1.0
		hide()
		return
	var t := 1.0 - pow(1.0 - _dock_time / ENTER_TIME, 3.0)
	_dock_rect = Rect2(_dock_start.position.lerp(rect.position, t).round(),
		_dock_start.size.lerp(rect.size, t).round())
	_dock_rect.position.y -= roundf(14.0 * sin(t * PI))
	size = _dock_rect.size
	global_position = _dock_rect.position
	target.modulate.a = 0.0
	show()


func _show_choice_card() -> void:
	if is_instance_valid(_choice_card):
		_choice_card.modulate.a = 1.0


func depart() -> void:
	if _departing:
		return
	_departing = true
	if _dwell != null:
		_dwell.kill()
	if is_docking():
		_find_choice_card = Callable()
		set_process(false)
		_show_choice_card()
		size = _dock_rect.size
		global_position = _dock_rect.position
		show()
	if not is_instance_valid(_slot) or not _slot.is_inside_tree():
		queue_free()
		return
	# Сводка может прокрутиться в ходе полёта. Целимся в актуальное место
	# карты и заканчиваем у края, если игрок сейчас читает старые ходы.
	var start := get_global_rect()
	if _motion != null:
		_motion.kill()
	_motion = create_tween()
	_motion.tween_method(func(t: float):
		if not is_instance_valid(_slot) or not _slot.is_inside_tree():
			modulate.a = 0.0
			return
		var target := _slot.get_global_rect()
		var visible_area := _feed.card_viewport_rect()
		var center := target.get_center()
		var visible_target := visible_area.has_point(center)
		if not visible_target:
			center = center.clamp(visible_area.position, visible_area.end)
		size = start.size.lerp(target.size, t).round()
		global_position = (start.get_center().lerp(center, t) - size * 0.5
			- Vector2(0, 20.0 * sin(t * PI))).round()
		modulate.a = 1.0 if visible_target else 1.0 - t,
		0.0, 1.0, EXIT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_callback(func():
		if is_instance_valid(_slot):
			_slot.modulate.a = 1.0
			_slot.mouse_filter = Control.MOUSE_FILTER_PASS
			_slot.flash_arrival()
		queue_free())
