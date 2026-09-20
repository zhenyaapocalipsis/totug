class_name HandPanel
extends Control

## Рука игрока-зрителя у нижнего края экрана. Карты лежат в ряд ЦЕЛИКОМ на
## экране — за нижний край ничего не выходит. Карта под курсором немного
## выдвигается вверх и рисуется поверх соседних; прочитать её целиком можно
## увеличенной копией по зажатому Alt (CardPreview).
##
## Карта кликается, только если сервер назвал её в legal["play_card"] — то
## есть в свой ход и когда не ждём чьё-то решение.
##
## Карты живут между обновлениями вида: при новом состоянии панель не сносит
## ряд и не строит его заново, а ищет для каждой карты руки уже существующий
## CardView с тем же card_id. Иначе никакая анимация невозможна — узел живёт
## один кадр. Пришедшие карты выезжают снизу с задержкой друг за другом,
## ушедшие (сыгранные) уплывают вниз и гаснут, а оставшиеся плавно съезжают
## на новые места.
##
## Едут карты на пружине, а не по прямой: пружина сама даёт лёгкий перелёт и
## возврат, из-за которого движение читается как «вес» карты. Положение на
## экране всегда округляется до целого пикселя — иначе пиксельное лицо карты
## мылится на дробных координатах.

signal card_clicked(card_id: String)

## Мелкое лицо карты пиксель в пиксель. Ширина зоны подобрана так, что пять
## карт (обычная рука) стоят рядом с зазором в 2 пикселя и не наезжают друг на
## друга; шестая и дальше ложатся внахлёст.
const CARD_SIZE := Vector2(80, 91)   # = CardView.MINI_SIZE, пиксель в пиксель
## Подъём заметный: на шести пикселях движение видно ступеньками (положение
## округляется до целого пикселя), на двенадцати оно читается как рывок вверх.
const HOVER_LIFT := 12.0
const BOTTOM_MARGIN := 2.0  # отступ ряда от нижнего края зоны
const GAP := 2.0

## Жёсткость и затухание пружины. Затухание примерно вдвое меньше критического
## (2*sqrt(жёсткость) ≈ 41) — карта заметно проскакивает место и качнётся
## назад. Мягче было вяло: карта приползала, а не прыгала.
const SPRING_STIFFNESS := 420.0
const SPRING_DAMPING := 20.0
## Пружину считаем шагом не длиннее 1/30 с: на длинном кадре (просадка, окно
## свернули) она иначе разлетается.
const MAX_STEP := 1.0 / 30.0

const ENTER_DROP := 60.0      # откуда выезжает новая карта — из-под края экрана
const ENTER_STAGGER := 0.05   # пауза между соседними картами раздачи
## Сыгранная карта улетает ВВЕРХ — туда, где лежит полоса сыгранных карт.
const LEAVE_TIME := 0.28
const LEAVE_SPEED := 300.0
const LEAVE_ACCEL := 900.0    # разгон: карту будто утягивает

var _cards: Array[CardView] = []
var _pos: Array[Vector2] = []    # текущее дробное положение карты
var _vel: Array[Vector2] = []    # скорость пружины
var _delay: Array[float] = []    # сколько ещё ждать перед выездом в ряд
var _leaving: Array[CardView] = []
var _leaving_left: Array[float] = []
var _leaving_speed: Array[float] = []
## Карта под курсором — именно узел, а не индекс: при обновлении руки карты
## переставляются местами, и запомненный индекс указал бы на чужую карту.
var _hovered_card: CardView = null
## Карта, по которой только что щёлкнули: сервер вернёт руку без неё, и
## улететь должна именно она. Без этой пометки в полёт уходила бы последняя
## одноимённая карта ряда — в руке три Noble, и при розыгрыше самого левого
## «сыгранной» выглядела бы самая правая.
var _played_card: CardView = null
var _tray: Panel
## Размер, под который в последний раз считали ряд: зона получает настоящий
## размер позже, чем в неё кладут карты, и без этой сверки ряд остаётся
## посчитанным по нулевой ширине и уезжает за нижний край.
var _built_for := Vector2.ZERO
# Геометрия ряда, посчитанная в _layout().
var _row_x0 := 0.0
var _row_step := 0.0
var _row_y := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Подложка под картами — чтобы зона руки читалась как зона.
	_tray = Panel.new()
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.add_theme_stylebox_override("panel",
		PixelTheme.box(PixelTheme.PANEL, PixelTheme.BORDER, 1, 0, 0))
	add_child(_tray)


func update_from_view(view: Dictionary, viewer_id: String) -> void:
	var p: Dictionary = (view["players"] as Dictionary)[viewer_id]
	var hand: Array = p.get("hand", [])
	var playable: Array = (view.get("legal", {}) as Dictionary).get("play_card", [])

	var old_cards := _cards
	var old_pos := _pos
	var old_vel := _vel
	var old_delay := _delay
	var reused := {}   # индексы прежнего ряда, которые уже разобрали
	_cards = []
	_pos = []
	_vel = []
	_delay = []

	# Щёлкнутая карта из сопоставления исключается — иначе её место займёт она
	# же, а улетит одноимённая соседка.
	var played := -1
	if _played_card != null and is_instance_valid(_played_card):
		var played_id := _played_card.card_id
		if hand.count(played_id) < _count_of(old_cards, played_id):
			played = old_cards.find(_played_card)
	_played_card = null

	var fresh := 0
	for cid: String in hand:
		var found := -1
		for j in range(old_cards.size()):
			if j != played and not reused.has(j) and old_cards[j].card_id == cid:
				found = j
				break
		if found >= 0:
			reused[found] = true
			_cards.append(old_cards[found])
			_pos.append(old_pos[found])
			_vel.append(old_vel[found])
			_delay.append(old_delay[found])
		else:
			_cards.append(_make_card(cid))
			_pos.append(Vector2.ZERO)
			_vel.append(Vector2.ZERO)
			_delay.append(ENTER_STAGGER * fresh)
			fresh += 1
		_cards[_cards.size() - 1].set_clickable(playable.has(cid))

	for j in range(old_cards.size()):
		if not reused.has(j):
			_start_leaving(old_cards[j])

	_layout()


## Сколько карт с таким card_id лежит в ряду.
static func _count_of(cards: Array[CardView], cid: String) -> int:
	var n := 0
	for card in cards:
		if card.card_id == cid:
			n += 1
	return n


func _make_card(cid: String) -> CardView:
	var card := CardView.new(cid, int(CARD_SIZE.x), int(CARD_SIZE.y))
	card.pressed.connect(func(clicked: String):
		# Запомнить до отправки: сервер ответит новой рукой синхронно, прямо
		# внутри card_clicked, и к тому моменту пометка уже нужна.
		_played_card = card
		card_clicked.emit(clicked))
	# Ткнули в карту, которую сейчас играть нельзя — она дёргается и краснеет,
	# вместо того чтобы молча ничего не сделать.
	card.refused.connect(func(_clicked: String): card.shake_refusal())
	card.mouse_entered.connect(func(): _hovered_card = card)
	card.mouse_exited.connect(func(): _clear_hovered(card))
	add_child(card)
	return card


## Сыгранная карта не исчезает мгновенно: она уплывает вниз за край экрана и
## гаснет. Кликать её по дороге уже нельзя — действие уже ушло на сервер.
func _start_leaving(card: CardView) -> void:
	if card == _hovered_card:
		_hovered_card = null
	card.set_clickable(false)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.z_index = 2   # летит поверх оставшихся карт, а не под ними
	_leaving.append(card)
	_leaving_left.append(LEAVE_TIME)
	_leaving_speed.append(LEAVE_SPEED)


func _clear_hovered(card: CardView) -> void:
	if _hovered_card == card:
		_hovered_card = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		_hovered_card = null  # курсор ушёл из окна


## Считает геометрию ряда и кладёт подложку. Сами карты сюда не ставятся — их
## каждый кадр подтягивает к своим местам пружина в _process().
##
## Ряд карт прижат к низу зоны. Если карт больше, чем влезает, они ложатся
## внахлёст — но ни одна не выходит за края зоны.
func _layout() -> void:
	var first_real_size := _built_for == Vector2.ZERO and size.x > 1.0
	_built_for = size
	_row_y = size.y - BOTTOM_MARGIN - CARD_SIZE.y
	var n := _cards.size()
	# Шаг только целый: на дробном пиксели карты разъезжаются и лицо мылится.
	_row_step = CARD_SIZE.x + GAP
	if n > 1 and CARD_SIZE.x + _row_step * (n - 1) > size.x:
		_row_step = maxf(floorf((size.x - CARD_SIZE.x) / (n - 1)), 6.0)
	var total := CARD_SIZE.x + _row_step * maxi(n - 1, 0)
	_row_x0 = floorf((size.x - total) * 0.5)

	_tray.position = Vector2(0, _row_y - 2)
	_tray.size = Vector2(size.x, size.y - _row_y + 2)

	# До первого настоящего размера ряд считался по нулевой ширине; ехать
	# оттуда пружиной незачем — ставим карты сразу на места.
	if first_real_size:
		for i in range(n):
			_pos[i] = _target_of(i)
			_vel[i] = Vector2.ZERO
			_cards[i].position = _pos[i].round()


## Место, к которому едет карта: своё место в ряду, приподнятое, если карта
## под курсором. Подъём переключается сразу, без своего сглаживания — плавность
## даёт одна только пружина. Раньше сглаживаний было два, и они гасили друг
## друга: карта выползала вверх по пикселю за кадр, то есть ступеньками.
func _target_of(i: int) -> Vector2:
	var lifted := HOVER_LIFT if _cards[i] == _hovered_card else 0.0
	return Vector2(_row_x0 + _row_step * i, _row_y - lifted)


func _process(delta: float) -> void:
	var dt := minf(delta, MAX_STEP)
	if size != _built_for:
		_layout()

	for i in range(_cards.size()):
		var want := _target_of(i)

		if _delay[i] > 0.0:
			# Карта ещё ждёт своей очереди в раздаче — стоит под краем экрана.
			_delay[i] -= dt
			_pos[i] = want + Vector2(0, ENTER_DROP)
			_vel[i] = Vector2.ZERO
			_cards[i].position = _pos[i].round()
			_cards[i].z_index = 0
			continue

		_vel[i] += (want - _pos[i]) * SPRING_STIFFNESS * dt
		# Затухание экспоненциальное, а не линейное: на длинном кадре линейное
		# съедало почти всю скорость и движение застывало.
		_vel[i] *= exp(-SPRING_DAMPING * dt)
		_pos[i] += _vel[i] * dt
		if _pos[i].distance_to(want) < 0.05 and _vel[i].length() < 1.0:
			_pos[i] = want
			_vel[i] = Vector2.ZERO
		_cards[i].position = _pos[i].round()
		# Выдвинутая карта не должна прятаться под соседней справа.
		_cards[i].z_index = 1 if _pos[i].y < _row_y - 0.5 else 0

	for j in range(_leaving.size() - 1, -1, -1):
		var card: CardView = _leaving[j]
		_leaving_left[j] -= dt
		_leaving_speed[j] += LEAVE_ACCEL * dt
		card.position = Vector2(card.position.x,
			roundf(card.position.y - _leaving_speed[j] * dt))
		card.modulate.a = clampf(_leaving_left[j] / LEAVE_TIME, 0.0, 1.0)
		if _leaving_left[j] <= 0.0:
			_leaving.remove_at(j)
			_leaving_left.remove_at(j)
			_leaving_speed.remove_at(j)
			remove_child(card)
			card.queue_free()


## Для проверок: карты, которые сейчас улетают из руки.
func leaving_cards() -> Array[CardView]:
	return _leaving.duplicate()


## Для проверок: индекс карты, которая сейчас выдвинута (-1 — ни одной).
func hovered_index() -> int:
	return _cards.find(_hovered_card) if _hovered_card != null else -1


## Для проверок: все карты доехали до своих мест и никто не уплывает.
func is_settled() -> bool:
	if not _leaving.is_empty() or _built_for == Vector2.ZERO:
		return false
	for i in range(_cards.size()):
		if _delay[i] > 0.0 or _pos[i].distance_to(_target_of(i)) > 0.5:
			return false
	return true
