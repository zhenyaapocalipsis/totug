class_name CardFx
extends RefCounted

## Эффекты розыгрыша уникальных карт (в колоде одна копия): когда такую карту
## играют, витрина (CardShowcase) показывает её крупно и рисует вокруг свой
## эффект. Спрайты лежат в assets/card_fx/<card_id>/, сценарии — в таблице FX.
##
## Щупальца (Ulitharid) — гибкие: тело собирается из полосок спрайта вдоль
## плавной кривой, поэтому щупальце по-настоящему гнётся, ползёт, обвивает карту
## и сжимает её. Корни уходят за край экрана — обрезанных концов нет.
## Решение владельца (2026-10-07): внутри эффектов полоски спрайта можно
## поворачивать на любой угол (общее пиксельное правило 1:1 здесь снято).

const SPRITE_PATH := "res://assets/card_fx/%s/%s.png"
## Сколько секунд висит карта с эффектом (обычная — CardShowcase.HOLD_TIME).
const HOLD_TIME := 2.0
## Время заползания щупальца до карты.
const CRAWL_TIME := 0.8
## С какого момента щупальца сжимают карту и когда уползают.
const SQUEEZE_AT := 0.85
const RETRACT_AT := 1.55
const RETRACT_TIME := 0.4
## Кадров анимации щупальца в секунду (при speed = 1) и полоски тела.
const FPS := 12.0
const STEP := 4.0
## Сколько отсчётов у кривой подхода и у витка вокруг карты.
const BEZ_N := 36
const ARC_N := 36
## Ударная волна: квадрат вокруг карты расширяется и гаснет.
const RING_TIME := 0.45
const RING_GROW := 70.0
## Спрайт: строки 0..TIP_ROWS — сужающийся кончик, остальные повторяются
## по REPEAT_ROWS, пока хватает длины тела.
const TIP_ROWS := 36
const REPEAT_ROWS := 60

## card_id -> сценарий. sprite/frames — спрайт и число его кадров, tint — цвет
## ударной волны, sound — звук (см. Sfx), tentacles — щупальца:
##   start — откуда выползает (доли экрана, за краем); theta — угол на карте, где
##   оно впервые её касается (0 — справа, дальше по часовой); sweep — на сколько
##   радиан обвивает карту (знак — в какую сторону); bend — изгиб подхода;
##   delay — задержка; len — длина тела, пиксели; wig/wsp — размах и скорость
##   извивания; speed — скорость кадров анимации (минус — назад); phase —
##   сдвиг всего. У каждого своё: движутся вразнобой.
const FX := {
	"48701": {
		"sprite": "anim", "frames": 17, "tint": Color("b05ad8"), "sound": "sink",
		"tentacles": [
			{"start": Vector2(-0.07, 1.06), "theta": 2.45, "sweep": 2.1, "bend": 130.0, "delay": 0.00,
				"len": 380.0, "wig": 18.0, "wsp": 5.5, "speed": 1.0, "phase": 0.0},
			{"start": Vector2(1.07, 1.05), "theta": 0.75, "sweep": -1.9, "bend": -110.0, "delay": 0.10,
				"len": 420.0, "wig": 22.0, "wsp": 4.1, "speed": -1.3, "phase": 2.1},
			{"start": Vector2(-0.07, -0.06), "theta": 4.3, "sweep": 1.6, "bend": -120.0, "delay": 0.06,
				"len": 360.0, "wig": 16.0, "wsp": 6.3, "speed": 0.8, "phase": 4.2},
			{"start": Vector2(1.07, -0.06), "theta": 5.1, "sweep": -1.5, "bend": 100.0, "delay": 0.16,
				"len": 400.0, "wig": 20.0, "wsp": 4.8, "speed": -1.1, "phase": 1.0},
			{"start": Vector2(0.42, 1.09), "theta": 1.5, "sweep": -1.2, "bend": 90.0, "delay": 0.22,
				"len": 340.0, "wig": 14.0, "wsp": 5.0, "speed": 1.4, "phase": 3.3},
		],
	},
}

static var _cache: Dictionary = {}


static func has(cid: String) -> bool:
	return FX.has(cid)


static func sound(cid: String) -> String:
	return String(FX[cid]["sound"]) if FX.has(cid) else ""


## Кадр index анимации карты cid (файлы <sprite>_<index>.png).
static func _sprite(cid: String, index: int) -> Texture2D:
	var name := "%s_%d" % [String(FX[cid]["sprite"]), index]
	var key := "%s/%s" % [cid, name]
	if not _cache.has(key):
		_cache[key] = load(SPRITE_PATH % [cid, name])
	return _cache[key]


## Номер кадра при движении туда-обратно: положение pos.
static func _pingpong(pos: float, n: int) -> int:
	var cycle := 2 * (n - 1)
	var k := posmod(int(floorf(pos)), cycle)
	return k if k < n else cycle - k


## Позади карты: ударная волна.
static func draw_behind(c: CanvasItem, cid: String, card: Rect2, t: float) -> void:
	var k := t / RING_TIME
	if k <= 0.0 or k >= 1.0:
		return
	var colour: Color = FX[cid]["tint"]
	colour.a = 0.7 * (1.0 - k)
	c.draw_rect(card.grow(roundf(RING_GROW * _ease_out(k))), colour, false, 2.0)


## Поверх карты: щупальца, обвивающие её. view — размер экрана (витрины).
static func draw_front(c: CanvasItem, cid: String, card: Rect2, t: float, view: Vector2) -> void:
	var fx: Dictionary = FX[cid]
	var squeeze := _ease_out((t - SQUEEZE_AT) / 0.45)
	# отступ от края карты: заползают снаружи, потом сжимают до самой рамки
	var margin := lerpf(18.0, 3.0, squeeze) + 1.2 * sin(t * 38.0) * squeeze
	var half := card.size * 0.5 + Vector2(margin, margin)
	for tent: Dictionary in fx["tentacles"]:
		_draw_tentacle(c, cid, tent, card.get_center(), half, view, t, squeeze)


## На сколько пикселей дрожит карта в тисках щупалец.
static func card_shift(cid: String, t: float) -> Vector2:
	if not FX.has(cid):
		return Vector2.ZERO
	var ramp := clampf((t - SQUEEZE_AT) / 0.2, 0.0, 1.0) * (1.0 - clampf((t - RETRACT_AT) / 0.3, 0.0, 1.0))
	return (Vector2(sin(t * 61.0), sin(t * 47.0 + 1.3)) * 1.6 * ramp).round()


## Точка на скруглённом прямоугольнике (суперэллипс) вокруг centre в направлении theta.
static func _rect_point(centre: Vector2, half: Vector2, theta: float) -> Vector2:
	var dir := Vector2(cos(theta), sin(theta))
	var k := pow(pow(absf(dir.x) / half.x, 5.0) + pow(absf(dir.y) / half.y, 5.0), -0.2)
	return centre + dir * k


## Путь головы: из-за края экрана к карте и витком вокруг неё.
static func _path(tent: Dictionary, centre: Vector2, half: Vector2, view: Vector2) -> PackedVector2Array:
	var start: Vector2 = (tent["start"] as Vector2) * view
	var theta := float(tent["theta"])
	var sweep := float(tent["sweep"])
	var land := _rect_point(centre, half, theta)
	var tangent := (_rect_point(centre, half, theta + signf(sweep) * 0.06) - land).normalized()
	var chord := land - start
	var c1 := start + chord * 0.35 + chord.orthogonal().normalized() * float(tent["bend"])
	var c2 := land - tangent * 150.0
	var pts := PackedVector2Array()
	for i in range(BEZ_N + 1):
		var u := float(i) / BEZ_N
		var a := start.lerp(c1, u)
		var b := c1.lerp(c2, u)
		var d := c2.lerp(land, u)
		pts.append(a.lerp(b, u).lerp(b.lerp(d, u), u))
	for i in range(1, ARC_N + 1):
		pts.append(_rect_point(centre, half, theta + sweep * float(i) / ARC_N))
	return pts


static func _draw_tentacle(c: CanvasItem, cid: String, tent: Dictionary, centre: Vector2,
		half: Vector2, view: Vector2, t: float, squeeze: float) -> void:
	var delay := float(tent["delay"])
	var crawl := _ease_out_cubic((t - delay) / CRAWL_TIME)
	var gone := _ease_in((t - RETRACT_AT - delay * 0.5) / RETRACT_TIME)
	var progress := crawl * (1.0 - gone)
	if progress <= 0.0:
		return
	var pts := _path(tent, centre, half, view)
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
	var head := cum[cum.size() - 1] * progress
	var phase := float(tent["phase"])
	var count := int(float(tent["len"]) / STEP)

	# точки тела от кончика к корню; за началом пути тело тянется прямо назад
	var back := (pts[0] - pts[1]).normalized()
	var body := PackedVector2Array()
	var i := pts.size() - 1
	for j in range(count + 1):
		var a := minf(head - float(j) * STEP, cum[cum.size() - 1])
		if a <= 0.0:
			body.append(pts[0] + back * (-a))
			continue
		while i > 1 and cum[i - 1] > a:
			i -= 1
		var u := (a - cum[i - 1]) / maxf(cum[i] - cum[i - 1], 0.001)
		body.append(pts[i - 1].lerp(pts[i], u))

	# извивание: поперёк тела бежит волна, у кончика и в середине сильнее
	var wig := float(tent["wig"]) * (1.0 - 0.65 * squeeze)
	var raw := body.duplicate()
	for j in range(count + 1):
		var prev := raw[maxi(j - 1, 0)]
		var next := raw[mini(j + 1, count)]
		var normal := (next - prev).orthogonal().normalized()
		var d := float(j) * STEP
		var wave := sin(d * 0.05 - t * float(tent["wsp"]) + phase) \
			+ 0.5 * sin(d * 0.021 + t * 2.7 + phase * 1.7)
		body[j] = raw[j] + normal * wig * wave * clampf(d / 60.0, 0.0, 1.0)

	var tex := _sprite(cid, _pingpong(t * FPS * float(tent["speed"]) + phase * 5.0, int(FX[cid]["frames"])))
	if tex == null:
		return
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var hw := w * 0.5 * 1.1
	var colours := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	for j in range(count):
		var d := float(j) * STEP
		# дальше кончика строки идут туда-обратно: на стыке нет скачка в сторону
		var row := d
		if d >= TIP_ROWS:
			var k := fposmod(d - TIP_ROWS, 2.0 * REPEAT_ROWS)
			row = TIP_ROWS + (k if k < REPEAT_ROWS else 2.0 * REPEAT_ROWS - k)
		var v0 := row / h
		var v1 := minf(row + STEP, h) / h
		var n0 := (body[mini(j + 1, count)] - body[maxi(j - 1, 0)]).orthogonal().normalized() * hw
		var n1 := (body[mini(j + 2, count)] - body[j]).orthogonal().normalized() * hw
		# draw_primitive, а не draw_polygon: тот отказывается рисовать «скрученный» кусок
		c.draw_primitive(
			PackedVector2Array([body[j] - n0, body[j] + n0, body[j + 1] + n1, body[j + 1] - n1]),
			colours, PackedVector2Array([Vector2(0, v0), Vector2(1, v0), Vector2(1, v1), Vector2(0, v1)]), tex)


static func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x)


static func _ease_out_cubic(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


static func _ease_in(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x
