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
## Щелчок по карте, когда карта задала вопрос "выбери карту в руке" (сбросить,
## сожрать): это ответ на вопрос, а не розыгрыш.
signal choice_clicked(card_id: String)

## Мелкое лицо карты пиксель в пиксель. Зона руки ужата (решение владельца,
## 2026-09-20): карты лежат внахлёст, а освободившаяся ширина отдана чату —
## в прежнюю его колонку в 62 пикселя строка просто не помещалась.
const CARD_SIZE := Vector2(80, 76)   # = CardView.MINI_SIZE, пиксель в пиксель
## Подъём заметный: на шести пикселях движение видно ступеньками (положение
## округляется до целого пикселя), на двенадцати оно читается как рывок вверх.
const HOVER_LIFT := 12.0
const BOTTOM_MARGIN := 2.0  # отступ ряда от нижнего края зоны
const GAP := 2.0
## Промежуток между рукой и картами Inner Circle в одном ряду (с чертой).
const ZONE_GAP := 9.0
## Вопросы, чьи карты встают в ряд руки справа от неё: метка вопроса -> подпись.
const ZONE_LABELS := {"inner_circle": "INNER CIRCLE", "discard": "DISCARD"}

## Жёсткость и затухание пружины. Затухание примерно вдвое меньше критического
## (2*sqrt(жёсткость) ≈ 41) — карта заметно проскакивает место и качнётся
## назад. Мягче было вяло: карта приползала, а не прыгала.
const SPRING_STIFFNESS := 420.0
const SPRING_DAMPING := 20.0
## Пружину считаем шагом не длиннее 1/30 с: на длинном кадре (просадка, окно
## свернули) она иначе разлетается.
const MAX_STEP := 1.0 / 30.0

## Слои ряда: подложка снизу (0), карты между 1 и числом карт, выдвинутая
## поверх всех, улетающая — над ней.
const Z_LIFTED := 900
const Z_FLYING := 901

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
## Чья рука: карты в ней — в образах этого игрока (CardView.set_owner).
var _viewer := ""
## Сейчас в руке отвечают на вопрос карты (см. choice_clicked).
var _choosing := false
## С какого места ряда идут карты Inner Circle (выбор "play a card from your
## inner circle"); -1 — их в ряду нет. Перед ними промежуток с чертой и
## подпись INNER CIRCLE.
var _split := -1
var _label: Label
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

	# Подложки под картами нет (макет владельца, 2026-09-24): зона руки
	# прозрачная, видны только сами карты.

	# Подпись над картами Inner Circle, когда они стоят в ряду справа от руки.
	_label = Label.new()
	_label.text = "INNER CIRCLE"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", PixelTheme.GOLD)
	_label.add_theme_color_override("font_shadow_color", PixelTheme.PANEL_LO)
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.visible = false
	add_child(_label)


func update_from_view(view: Dictionary, viewer_id: String) -> void:
	_viewer = viewer_id
	var p: Dictionary = (view["players"] as Dictionary)[viewer_id]
	var hand: Array = p.get("hand", [])
	var playable: Array = (view.get("legal", {}) as Dictionary).get("play_card", [])
	# Вопрос "выбери карту в руке": кликаются и подсвечены золотом только
	# карты-варианты (решение владельца, 2026-09-27).
	var pd: Dictionary = view.get("pending_decision", {})
	var mine := String(pd.get("player_id", "")) == viewer_id
	var tag := String(pd.get("tag", ""))
	_choosing = mine and (tag == "hand" or ZONE_LABELS.has(tag))
	var options: Array = pd.get("legal_options", []) if _choosing else []
	if _choosing:
		playable = options if tag == "hand" else []
	# Выбор из Inner Circle или сброса: их карты встают в тот же ряд справа от
	# руки, за промежутком с подписью. Рука видна, но тусклая и не кликается —
	# без окна и затемнения видны и она, и доска с рынком (решение владельца,
	# 2026-09-27). "" в вариантах — отказ, это Skip в строке вопроса.
	var zone_ids: Array = options.filter(func(o): return String(o) != "") \
		if ZONE_LABELS.has(tag) else []
	_label.text = ZONE_LABELS.get(tag, "")
	var entries: Array = []   # [card_id, карта из Inner Circle]
	for cid in hand:
		entries.append([String(cid), false])
	for cid in zone_ids:
		entries.append([String(cid), true])
	_split = hand.size() if not zone_ids.is_empty() and not hand.is_empty() else -1
	_label.visible = not zone_ids.is_empty()

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
		var played_zone := _is_zone(_played_card)
		var now := entries.filter(func(e): return e[0] == played_id and e[1] == played_zone).size()
		var before := old_cards.filter(func(c): return c.card_id == played_id and _is_zone(c) == played_zone).size()
		if now < before:
			played = old_cards.find(_played_card)
	_played_card = null

	var fresh := 0
	for entry: Array in entries:
		var cid: String = entry[0]
		var from_zone: bool = entry[1]
		var found := -1
		for j in range(old_cards.size()):
			if j != played and not reused.has(j) and old_cards[j].card_id == cid \
					and _is_zone(old_cards[j]) == from_zone:
				found = j
				break
		if found >= 0:
			reused[found] = true
			_cards.append(old_cards[found])
			_pos.append(old_pos[found])
			_vel.append(old_vel[found])
			_delay.append(old_delay[found])
		else:
			var made := _make_card(cid)
			made.set_meta("zone", from_zone)
			_cards.append(made)
			_pos.append(Vector2.ZERO)
			_vel.append(Vector2.ZERO)
			_delay.append(ENTER_STAGGER * fresh)
			_deal_sound(fresh)
			fresh += 1
		_cards[_cards.size() - 1].set_clickable(
			zone_ids.has(cid) if from_zone else playable.has(cid))

	for j in range(old_cards.size()):
		if reused.has(j):
			continue
		# Карты Inner Circle, которые не выбрали, в Inner Circle и остаются:
		# улетающая вверх выглядела бы сыгранной, поэтому убираем сразу.
		if _is_zone(old_cards[j]) and j != played:
			CardPreview.clear_hovered(old_cards[j])
			_clear_hovered(old_cards[j])
			remove_child(old_cards[j])
			old_cards[j].queue_free()
		else:
			_start_leaving(old_cards[j])

	_layout()
	queue_redraw()


## Шорох карты, входящей в руку, в момент её вылета; каждая следующая карта
## раздачи — на полутон выше, как в Balatro.
func _deal_sound(order: int) -> void:
	if order == 0 or not is_inside_tree():
		Sfx.play("draw", false, order)
		return
	get_tree().create_timer(ENTER_STAGGER * order).timeout.connect(
		func() -> void: Sfx.play("draw", false, order))


static func _is_zone(card: CardView) -> bool:
	return bool(card.get_meta("zone", false))


## Сколько карт с таким card_id лежит в ряду.
static func _count_of(cards: Array[CardView], cid: String) -> int:
	var n := 0
	for card in cards:
		if card.card_id == cid:
			n += 1
	return n


func _make_card(cid: String) -> CardView:
	var card := CardView.new(cid, int(CARD_SIZE.x), int(CARD_SIZE.y))
	card.set_card_owner(_viewer)
	card.pressed.connect(func(clicked: String):
		# Запомнить до отправки: сервер ответит новой рукой синхронно, прямо
		# внутри card_clicked, и к тому моменту пометка уже нужна.
		_played_card = card
		if _choosing:
			choice_clicked.emit(clicked)
		else:
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
	card.z_index = Z_FLYING   # летит поверх оставшихся карт, а не под ними
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


## Считает геометрию ряда. Сами карты сюда не ставятся — их
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
	# Промежуток перед Inner Circle не внахлёст: первая его карта стоит
	# целиком правее последней карты руки (см. _split_extra).
	var divider := CARD_SIZE.x + ZONE_GAP if _split > 0 else 0.0
	var steps := n - 1 - (1 if _split > 0 else 0)
	_row_step = CARD_SIZE.x + GAP
	if steps > 0 and CARD_SIZE.x + divider + _row_step * steps > size.x:
		_row_step = maxf(floorf((size.x - CARD_SIZE.x - divider) / steps), 6.0)
	var total := CARD_SIZE.x + divider + _row_step * maxi(steps, 0)
	_row_x0 = floorf((size.x - total) * 0.5)
	if _split >= 0 or _label.visible:
		# Подпись по центру над картами Inner Circle, в полосе над рядом.
		var first := maxi(_split, 0)
		var x0 := _row_x0 + _row_step * first + _split_extra(first)
		var x1 := _row_x0 + _row_step * (n - 1) + _split_extra(n - 1) + CARD_SIZE.x
		_label.position = Vector2(x0, _row_y - PixelTheme.LINE_H - 1)
		_label.size = Vector2(x1 - x0, PixelTheme.LINE_H)
	queue_redraw()

	# До первого настоящего размера ряд считался по нулевой ширине; ехать
	# оттуда пружиной незачем — ставим карты сразу на места.
	if first_real_size:
		for i in range(n):
			_pos[i] = _target_of(i)
			_vel[i] = Vector2.ZERO
			_cards[i].position = _pos[i].round()


## Порядок наложения карт в ряду. Карты лежат внахлёст, и ПРАВАЯ лежит поверх
## левой: имя на мелком лице написано слева, поэтому из-под соседки должно
## торчать начало имени, а не его хвост. Выдвинутая карта — поверх всех,
## улетающая — ещё выше.
func _z_of(index: int, lifted: bool) -> int:
	return Z_LIFTED if lifted else index + 1


## Место, к которому едет карта: своё место в ряду, приподнятое, если карта
## под курсором. Подъём переключается сразу, без своего сглаживания — плавность
## даёт одна только пружина. Раньше сглаживаний было два, и они гасили друг
## друга: карта выползала вверх по пикселю за кадр, то есть ступеньками.
func _target_of(i: int) -> Vector2:
	var lifted := HOVER_LIFT if _cards[i] == _hovered_card else 0.0
	return Vector2(_row_x0 + _row_step * i + _split_extra(i), _row_y - lifted)


## Сдвиг карт Inner Circle вправо: первая встаёт на ZONE_GAP правее конца
## последней карты руки, дальше — обычным шагом.
func _split_extra(i: int) -> float:
	if _split <= 0 or i < _split:
		return 0.0
	return CARD_SIZE.x + ZONE_GAP - _row_step


## Черта посередине промежутка между рукой и Inner Circle.
func _draw() -> void:
	if _split <= 0 or _split >= _cards.size():
		return
	var x := floorf(_row_x0 + _row_step * (_split - 1) + CARD_SIZE.x + ZONE_GAP * 0.5)
	draw_line(Vector2(x, _row_y), Vector2(x, _row_y + CARD_SIZE.y), PixelTheme.GOLD, 1.0)


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
			_cards[i].z_index = _z_of(i, false)
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
		_cards[i].z_index = _z_of(i, _pos[i].y < _row_y - 0.5)

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
