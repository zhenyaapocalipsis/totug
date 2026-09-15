class_name HandPanel
extends Control

## Рука игрока-зрителя у нижнего края экрана. В покое карты выглядывают из-за
## края (видны шапки), при наведении на зону рука выезжает целиком, наведённая
## карта показывается крупнее (CardPreview).
##
## Карта кликается, только если сервер назвал её в legal["play_card"] — то
## есть в свой ход и когда не ждём чьё-то решение.

signal card_clicked(card_id: String)

const CARD_SIZE := Vector2(140, 196)
const PEEK := 58.0          # сколько карты видно, пока рука опущена
const BOTTOM_MARGIN := 8.0  # отступ от края, когда рука поднята
const GAP := 6.0
const RAISE_TIME := 0.16

var _cards: Array[CardView] = []
var _lift := 0.0  # 0 — опущена, 1 — поднята
var _mouse := Vector2(-1e6, -1e6)
var _tray: Panel


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Подложка под выглядывающими картами — чтобы зона руки читалась как зона.
	_tray = Panel.new()
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.085, 0.115)
	style.border_color = Color(0.24, 0.22, 0.3)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	_tray.add_theme_stylebox_override("panel", style)
	add_child(_tray)


func update_from_view(view: Dictionary, viewer_id: String) -> void:
	for card in _cards:
		remove_child(card)
		card.queue_free()
	_cards.clear()

	var p: Dictionary = (view["players"] as Dictionary)[viewer_id]
	var hand: Array = p.get("hand", [])
	var playable: Array = (view.get("legal", {}) as Dictionary).get("play_card", [])

	for cid: String in hand:
		var card := CardView.new(cid, int(CARD_SIZE.x), int(CARD_SIZE.y))
		card.set_clickable(playable.has(cid))
		card.pressed.connect(func(clicked: String): card_clicked.emit(clicked))
		add_child(card)
		_cards.append(card)
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse = Vector2(-1e6, -1e6)  # курсор ушёл из окна — рука опускается


func _layout() -> void:
	var lowered_y := size.y - PEEK
	var raised_y := size.y - BOTTOM_MARGIN - CARD_SIZE.y
	var t := smoothstep(0.0, 1.0, _lift)
	var y := lerpf(lowered_y, raised_y, t)

	var n := _cards.size()
	var step := CARD_SIZE.x + GAP
	if n > 1 and CARD_SIZE.x + step * (n - 1) > size.x:
		step = (size.x - CARD_SIZE.x) / (n - 1)
	var total := CARD_SIZE.x + step * maxi(n - 1, 0)
	var x0 := (size.x - total) * 0.5
	for i in range(n):
		_cards[i].position = Vector2(x0 + step * i, y)

	_tray.position = Vector2(0, lowered_y - 8)
	_tray.size = Vector2(size.x, PEEK + 20)


## Где мышь «над рукой»: над выглядывающими картами или подложкой, а когда
## рука поднята — над самими картами.
func _hover_rect() -> Rect2:
	var rect := _tray.get_global_rect()
	for card in _cards:
		rect = rect.merge(card.get_global_rect())
	return rect.grow(6)


## Положение мыши берём из событий, а не get_global_mouse_position(): тот
## читает системный курсор и не видит событий, поданных тестом.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse = get_global_transform() * (make_input_local(event) as InputEventMouse).position


func _process(delta: float) -> void:
	var over := not _cards.is_empty() and _hover_rect().has_point(_mouse)
	var target := 1.0 if over else 0.0
	if not is_equal_approx(_lift, target):
		_lift = move_toward(_lift, target, delta / RAISE_TIME)
		_layout()


## Для проверок: поднята ли рука полностью.
func is_raised() -> bool:
	return is_equal_approx(_lift, 1.0)
