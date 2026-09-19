class_name HandPanel
extends Control

## Рука игрока-зрителя у нижнего края экрана. Карты лежат в ряд ЦЕЛИКОМ на
## экране — за нижний край ничего не выходит. Карта под курсором немного
## выдвигается вверх и рисуется поверх соседних; прочитать её целиком можно
## увеличенной копией по зажатому Alt (CardPreview).
##
## Карта кликается, только если сервер назвал её в legal["play_card"] — то
## есть в свой ход и когда не ждём чьё-то решение.

signal card_clicked(card_id: String)

## Мелкое лицо карты пиксель в пиксель. Ширина зоны подобрана так, что пять
## карт (обычная рука) стоят рядом с зазором в 2 пикселя и не наезжают друг на
## друга; шестая и дальше ложатся внахлёст.
const CARD_SIZE := Vector2(80, 91)   # = CardView.MINI_SIZE, пиксель в пиксель
const HOVER_LIFT := 6.0     # на сколько выдвигается карта под курсором
const BOTTOM_MARGIN := 2.0  # отступ ряда от нижнего края зоны
const GAP := 2.0
const LIFT_TIME := 0.10

var _cards: Array[CardView] = []
var _lifts: Array[float] = []   # 0..1 на карту: насколько она выдвинута
var _hovered := -1
var _tray: Panel
## Размер, под который в последний раз считали ряд: зона получает настоящий
## размер позже, чем в неё кладут карты, и без этой сверки ряд остаётся
## посчитанным по нулевой ширине и уезжает за нижний край.
var _built_for := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Подложка под картами — чтобы зона руки читалась как зона.
	_tray = Panel.new()
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.add_theme_stylebox_override("panel",
		PixelTheme.box(PixelTheme.PANEL, PixelTheme.BORDER, 1, 0, 0))
	add_child(_tray)


func update_from_view(view: Dictionary, viewer_id: String) -> void:
	for card in _cards:
		remove_child(card)
		card.queue_free()
	_cards.clear()
	_lifts.clear()
	_hovered = -1

	var p: Dictionary = (view["players"] as Dictionary)[viewer_id]
	var hand: Array = p.get("hand", [])
	var playable: Array = (view.get("legal", {}) as Dictionary).get("play_card", [])

	for cid: String in hand:
		var index := _cards.size()
		var card := CardView.new(cid, int(CARD_SIZE.x), int(CARD_SIZE.y))
		card.set_clickable(playable.has(cid))
		card.pressed.connect(func(clicked: String): card_clicked.emit(clicked))
		card.mouse_entered.connect(func(): _set_hovered(index))
		card.mouse_exited.connect(func(): _clear_hovered(index))
		add_child(card)
		_cards.append(card)
		_lifts.append(0.0)
	_layout()


func _set_hovered(index: int) -> void:
	_hovered = index


func _clear_hovered(index: int) -> void:
	if _hovered == index:
		_hovered = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_hovered = -1  # курсор ушёл из окна


## Ряд карт прижат к низу зоны. Если карт больше, чем влезает, они ложатся
## внахлёст — но ни одна не выходит за края зоны.
func _layout() -> void:
	_built_for = size
	var base_y := size.y - BOTTOM_MARGIN - CARD_SIZE.y
	var n := _cards.size()
	# Шаг только целый: на дробном пиксели карты разъезжаются и лицо мылится.
	var step := CARD_SIZE.x + GAP
	if n > 1 and CARD_SIZE.x + step * (n - 1) > size.x:
		step = maxf(floorf((size.x - CARD_SIZE.x) / (n - 1)), 6.0)
	var total := CARD_SIZE.x + step * maxi(n - 1, 0)
	var x0 := floorf((size.x - total) * 0.5)
	for i in range(n):
		var lift: float = _lifts[i] if i < _lifts.size() else 0.0
		_cards[i].position = Vector2(x0 + step * i,
			roundf(base_y - HOVER_LIFT * smoothstep(0.0, 1.0, lift)))
		# Выдвинутая карта не должна прятаться под соседней справа.
		_cards[i].z_index = 1 if lift > 0.01 else 0

	_tray.position = Vector2(0, base_y - 2)
	_tray.size = Vector2(size.x, size.y - base_y + 2)


func _process(delta: float) -> void:
	var changed := size != _built_for
	for i in range(_lifts.size()):
		var target := 1.0 if i == _hovered else 0.0
		if not is_equal_approx(_lifts[i], target):
			_lifts[i] = move_toward(_lifts[i], target, delta / LIFT_TIME)
			changed = true
	if changed:
		_layout()


## Для проверок: индекс карты, которая сейчас выдвинута (-1 — ни одной).
func hovered_index() -> int:
	return _hovered
