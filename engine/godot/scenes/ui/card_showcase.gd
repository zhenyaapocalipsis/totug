class_name CardShowcase
extends Control

## «Витрина»: то, что игроки иначе пропускают (соперник купил карту, кто-то
## промоутил верхнюю карту колоды, съел карту рынка), показывается крупной
## картой над доской с плашкой «RED RECRUITS» — журнал никто не читает.
##
## Карта прилетает из места, откуда её взяли (слот рынка), или появляется
## вспышкой прямо в центре; взятая вслепую сначала лежит рубашкой и
## переворачивается белой вспышкой. Повисев, улетает туда, куда попала
## (барак соперника, своя стопка Inner Circle), а съеденная рассыпается на
## пиксельные квадратики.
##
## Одна карта сразу нескольким игрокам (изгои от Ghoul, Demogorgon) — рядом
## крупных копий, над каждой плашка получателя; каждая улетает к своему.
##
## Показы идут очередью: соперник может сделать пять дел за ход. Чем длиннее
## очередь, тем быстрее идёт каждый показ; щелчок по карте проматывает её.
## Игру витрина не держит: состояние уже применено, она лишь догоняет его.
##
## Пиксельное правило: карта крупно — всегда в масштабе 1:1 (PIXEL_SIZE), в
## полёте — мелкой картинкой (mini) тоже 1:1. Промежуточных масштабов нет.

## Очередь показов кончилась — окно выбора, ждавшее витрину, можно показать.
signal finished

const ENTER_TIME := 0.24
const BACK_TIME := 0.4
const HOLD_TIME := 0.8
const FLASH_TIME := 0.14
const EXIT_TIME := 0.36
const CRUMBLE_TIME := 0.62
const FLY_ARC := 40.0
const DIM_SPEED := 5.0
## Во сколько раз быстрее идёт показ за каждую карту, ждущую в очереди.
const SPEED_PER_QUEUED := 0.6
const MAX_SPEED := 3.0
## Сторона квадратика, на которые рассыпается съеденная карта (пиксели карты).
const CRUMBLE_BLOCK := 8
const TRAIL := 3

## Зона, в центре которой витрина показывает карту (затемняется весь экран).
var board_area: Control = null

var _queue: Array[Dictionary] = []
var _item: Dictionary = {}
var _phase := ""
var _t := 0.0
var _flash := 0.0
var _dim := 0.0
## Шлейфы летящих мелких карт: по одному на каждую точку назначения.
var _trails: Array = []
var _card_rect := Rect2()
## Плашки над картами: по одной на каждую карту ряда (обычно одна).
var _banners: Array[PanelContainer] = []
## Промежуток между картами ряда.
const ROW_GAP := 8.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


## Поставить карту в очередь показа.
##   text      — плашка над картой («RED RECRUITS»);
##   colour    — цвет игрока для плашки;
##   from      — откуда прилетает (точка экрана) или null — вспышкой в центре;
##   to        — куда улетает (точка экрана) или null — рассыпается;
##   face_down — взята вслепую: сначала рубашка, потом переворот;
##   back      — рисунок рубашки владельца (PlayerProfile, "" — обычная).
func show_card(cid: String, text: String, colour: Color, from: Variant, to: Variant,
		face_down: bool = false, back: String = "") -> void:
	_enqueue(cid, [{"text": text, "colour": colour, "to": to}], from, face_down, back)


## Одна карта сразу нескольким игрокам (изгои от Ghoul, Demogorgon): ряд
## крупных копий, над каждой своя плашка, и каждая улетает в свою точку.
## slots — [{text, colour, to}], to — точка экрана (не null).
func show_row(cid: String, slots: Array[Dictionary]) -> void:
	_enqueue(cid, slots, null, false, "")


func _enqueue(cid: String, slots: Array, from: Variant, face_down: bool, back: String) -> void:
	_queue.append({"cid": cid, "slots": slots, "from": from,
		"face_down": face_down, "back": CardBack.texture(back),
		"face": CardView.pixel_texture(cid), "mini": CardView.mini_texture(cid)})
	if _item.is_empty():
		_next()
	set_process(true)


## Карта рассыпается (съедена): у неё нет точки, куда улетать.
func _crumbles() -> bool:
	return (_item["slots"] as Array).size() == 1 and _item["slots"][0]["to"] == null


## Для проверок и чтобы не показывать лишнего: идёт ли сейчас показ.
func is_busy() -> bool:
	return not _item.is_empty()


func queued() -> int:
	return _queue.size() + (0 if _item.is_empty() else 1)


## Промотать текущую карту: сразу к уходу (рубашка — сразу лицом).
func skip() -> void:
	if _phase == "enter" or _phase == "back" or _phase == "hold":
		_item["face_down"] = false
		_set_phase("exit")


func _next() -> void:
	_trails.clear()
	if _queue.is_empty():
		_item = {}
		_phase = ""
		for banner in _banners:
			banner.visible = false
		finished.emit()
		return
	_item = _queue.pop_front()
	_set_phase("enter")
	_flash = 0.0 if _item["from"] != null else FLASH_TIME
	var slots: Array = _item["slots"]
	while _banners.size() < slots.size():
		var banner := PanelContainer.new()
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.add_theme_color_override("font_color", PixelTheme.TEXT)
		banner.add_child(label)
		banner.visible = false
		add_child(banner)
		_banners.append(banner)
	for i in slots.size():
		var banner := _banners[i]
		(banner.get_child(0) as Label).text = String(slots[i]["text"])
		var colour: Color = slots[i]["colour"]
		banner.add_theme_stylebox_override("panel",
			PixelTheme.box(colour.darkened(0.55), colour, 1, 6, 2))
		banner.reset_size()


func _set_phase(phase: String) -> void:
	_phase = phase
	_t = 0.0
	_trails.clear()


func _process(delta: float) -> void:
	var speed := minf(1.0 + SPEED_PER_QUEUED * _queue.size(), MAX_SPEED)
	var step := delta * speed
	_t += step
	_flash = maxf(0.0, _flash - step)
	var want := 1.0 if not _item.is_empty() else 0.0
	_dim = move_toward(_dim, want, delta * DIM_SPEED)

	match _phase:
		"enter":
			if _t >= ENTER_TIME:
				_set_phase("back" if bool(_item["face_down"]) else "hold")
				if _item["from"] != null:
					_flash = FLASH_TIME
		"back":
			if _t >= BACK_TIME:
				_set_phase("hold")
				_flash = FLASH_TIME
		"hold":
			if _t >= HOLD_TIME:
				_set_phase("exit")
		"exit":
			if _t >= (CRUMBLE_TIME if _crumbles() else EXIT_TIME):
				_next()

	if _item.is_empty() and _dim <= 0.0:
		set_process(false)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _item.is_empty() or not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT \
			and _card_rect.has_point(get_local_mouse_position()):
		skip()
		get_viewport().set_input_as_handled()


# --- отрисовка ----------------------------------------------------------------

func _area() -> Rect2:
	if board_area == null:
		return Rect2(Vector2.ZERO, size)
	var r := board_area.get_global_rect()
	r.position -= get_global_position()
	return r


func _draw() -> void:
	var area := _area()
	if _dim > 0.0:
		# Затемняем весь экран, а не только доску: вокруг доски стоят сводка,
		# рука и рынок, и тёмный прямоугольник обрывался бы посреди экрана.
		draw_rect(Rect2(Vector2.ZERO, size), Color(PixelTheme.DIM, PixelTheme.DIM.a * _dim))
	for banner in _banners:
		banner.visible = false
	_card_rect = Rect2()
	if _item.is_empty():
		return

	var centre := area.get_center().round()
	var rects := _row_rects(area)
	var face: Texture2D = _item["face"]
	var slots: Array = _item["slots"]

	match _phase:
		"enter":
			if _item["from"] == null:
				_draw_row(rects, face, bool(_item["face_down"]))
			else:
				var p := _ease_out(_t / ENTER_TIME)
				_draw_small_at((_item["from"] as Vector2).lerp(centre, p))
		"back":
			_draw_row(rects, face, true)
		"hold":
			_draw_row(rects, face, false)
		"exit":
			if _crumbles():
				_draw_crumble(rects[0], face, _t / CRUMBLE_TIME)
				_show_banner(0, rects[0])
			else:
				# Каждая копия улетает из своего места ряда в свою точку.
				var p := _ease_in(_t / EXIT_TIME)
				for i in slots.size():
					var from: Vector2 = (rects[i] as Rect2).get_center().round()
					var to: Vector2 = slots[i]["to"]
					var mid := from.lerp(to, 0.5) + Vector2(0, -FLY_ARC)
					_draw_small_at(from.lerp(mid, p).lerp(mid.lerp(to, p), p), i)


## Места крупных карт: одна — по центру зоны, несколько — рядом в ряд по
## центру. Если ряд не влезает в зону, карты заходят друг на друга.
func _row_rects(area: Rect2) -> Array[Rect2]:
	var big := CardView.PIXEL_SIZE
	var n: int = (_item["slots"] as Array).size()
	var step := big.x + ROW_GAP
	if n > 1:
		step = minf(step, floorf((area.size.x - big.x) / float(n - 1)))
	var width := big.x + step * float(n - 1)
	var left := area.get_center().x - width * 0.5
	var top := area.get_center().y - big.y * 0.5
	var rects: Array[Rect2] = []
	for i in n:
		rects.append(Rect2(Vector2(left + step * float(i), top).round(), big))
	return rects


## Ряд крупных карт: лицом или рубашкой, в первые мгновения — белая вспышка.
func _draw_row(rects: Array[Rect2], face: Texture2D, down: bool) -> void:
	for i in rects.size():
		var rect := rects[i]
		_card_rect = rect if i == 0 else _card_rect.merge(rect)
		if down or face == null:
			_draw_back(rect)
		else:
			draw_texture_rect(face, rect, false)
		if _flash > 0.0:
			draw_rect(rect, Color(1, 1, 1, 0.8 * _flash / FLASH_TIME))
		_show_banner(i, rect)


func _show_banner(index: int, card: Rect2) -> void:
	var banner := _banners[index]
	banner.visible = true
	var s := banner.get_combined_minimum_size()
	banner.size = s
	banner.position = Vector2(roundf(card.get_center().x - s.x * 0.5), card.position.y - s.y - 3)


## Карта в полёте — мелкой картинкой 1:1 со шлейфом из прошлых позиций.
## trail — номер шлейфа: копии, летящие в разные места, тянут каждая свой.
func _draw_small_at(pos: Vector2, trail: int = 0) -> void:
	pos = pos.round()
	while _trails.size() <= trail:
		_trails.append([])
	var points: Array = _trails[trail]
	if points.is_empty() or points.back() != pos:
		points.append(pos)
		if points.size() > TRAIL + 1:
			points.pop_front()
	var tex: Texture2D = _item["mini"]
	var s: Vector2 = CardView.MINI_SIZE if tex != null else CardView.PIXEL_SIZE * 0.5
	if tex == null:
		tex = _item["face"]
	for i in range(points.size()):
		var last := i == points.size() - 1
		var a := 1.0 if last else 0.35 * float(i + 1) / points.size()
		var r := Rect2((points[i] - s * 0.5).round(), s)
		if tex != null:
			draw_texture_rect(tex, r, false, Color(1, 1, 1, a))
		else:
			_draw_back(r, a)
		if last:
			_card_rect = r


## Съеденная карта рассыпается: квадратики сползают вниз и в стороны,
## краснеют и гаснут; нижние уходят раньше верхних.
func _draw_crumble(rect: Rect2, face: Texture2D, t: float) -> void:
	if face == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(_item["cid"]))
	var b := float(CRUMBLE_BLOCK)
	var y := 0.0
	while y < rect.size.y:
		var x := 0.0
		while x < rect.size.x:
			var drift := Vector2(rng.randf_range(-40, 40), rng.randf_range(10, 80))
			var start := rng.randf() * 0.45 * (1.0 - y / rect.size.y)
			var k := clampf((t - start) / 0.55, 0.0, 1.0)
			if k < 1.0:
				var pos := (rect.position + Vector2(x, y) + drift * k * k).round()
				var col := Color(1, 1, 1).lerp(Color(1, 0.3, 0.25), minf(1.0, k * 2.5))
				col.a = 1.0 - k
				draw_texture_rect_region(face, Rect2(pos, Vector2(b, b)),
					Rect2(Vector2(x, y), Vector2(b, b)), col)
			x += b
		y += b


## Рубашка карты (CardBack) — с рисунком владельца карты.
func _draw_back(r: Rect2, a: float = 1.0) -> void:
	draw_texture_rect(_item["back"], r, false, Color(1, 1, 1, a))


static func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x)


static func _ease_in(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x
