class_name CardFx
extends RefCounted

## Эффекты розыгрыша уникальных карт (в колоде одна копия): когда такую карту
## играют, витрина (CardShowcase) показывает её крупно и рисует вокруг свой
## эффект. Спрайты лежат в assets/card_fx/<card_id>/, сценарии — в таблице FX.
##
## Щупальца (Ulitharid) гибкие: корень спрятан под картой, тело выползает из-под
## её края и идёт по длинной плавной кривой, заданной ключевыми углами. Само тело —
## цепочка полосок спрайта вдоль кривой, на неё накладывается лёгкая бегущая
## волна. Часть тела может идти поверх карты (front_from), будто щупальце
## обвивает её. Форма — по рисунку владельца (2026-10-07).
## Решение владельца: внутри эффектов полоски спрайта можно поворачивать на любой
## угол (общее пиксельное правило 1:1 здесь снято).

const SPRITE_PATH := "res://assets/card_fx/%s/%s.png"
## Сколько секунд висит карта с эффектом (обычная — CardShowcase.HOLD_TIME).
const HOLD_TIME := 2.1
## Выползание: базовое время и добавка на каждый пиксель длины; втягивание.
const CRAWL_BASE := 0.5
const CRAWL_PER_PX := 0.001
const RETRACT_AT := 1.6
const RETRACT_TIME := 0.4
## Кадров анимации щупальца в секунду (при speed = 1) и шаг полосок тела.
const FPS := 12.0
const STEP := 4.0
## На сколько отрезков разбита кривая щупальца.
const SPINE_N := 64
## Ударная волна: квадрат вокруг карты расширяется и гаснет.
const RING_TIME := 0.45
const RING_GROW := 70.0
## Спрайт: строки 0..TIP_ROWS — сужающийся кончик, дальше строки идут туда-обратно
## по REPEAT_ROWS (у спрайта оба конца сужаются, нужна только толстая середина).
const TIP_ROWS := 36
const REPEAT_ROWS := 60
## Вздрагивание карты, когда щупальце выходит: сила (пиксели) и затухание.
const JOLT := 2.0
const JOLT_DECAY := 12.0

## card_id -> сценарий. sprite/frames — спрайт и число его кадров, tint — цвет
## ударной волны, sound — звук (см. Sfx), tentacles — щупальца:
##   base — корень (доли карты, под её краем); reach — длина кривой в пикселях;
##   knots — курс (радианы, 0 — вправо, дальше по часовой) в равных долях длины
##   от корня до кончика, между ними плавно; wave/wsp — размах и скорость лёгкой
##   волны; delay — задержка; speed — скорость кадров анимации (минус — назад);
##   phase — сдвиг всего; front_from — с какой длины от корня тело идёт ПОВЕРХ
##   карты (нет — всё позади). У каждого своё: движутся вразнобой.
const FX := {
	"48701": {
		"sprite": "anim", "frames": 17, "tint": Color("b05ad8"), "sound": "sink",
		"tentacles": [
			# петля слева, потом по диагонали поверх карты и вниз по правой стороне
			{"base": Vector2(0.14, 0.05), "reach": 560.0,
				"knots": [-2.3, -3.7, -5.7, -5.75, -5.5, -5.0, -4.7], "wave": 0.14, "wsp": 4.2,
				"delay": 0.00, "speed": 1.0, "phase": 0.0, "front_from": 130.0},
			# от правого верхнего края вниз вдоль правой стороны
			{"base": Vector2(0.97, 0.10), "reach": 300.0,
				"knots": [0.2, 0.9, 1.5, 1.7], "wave": 0.16, "wsp": 5.0,
				"delay": 0.12, "speed": -1.3, "phase": 2.1},
			# от левого края вниз с изгибом
			{"base": Vector2(0.02, 0.45), "reach": 210.0,
				"knots": [2.4, 2.0, 1.5, 1.2], "wave": 0.16, "wsp": 3.8,
				"delay": 0.06, "speed": 0.8, "phase": 4.2},
			# короткий крючок справа
			{"base": Vector2(0.98, 0.66), "reach": 140.0,
				"knots": [0.15, 0.7, 1.7, 2.9], "wave": 0.12, "wsp": 4.6,
				"delay": 0.18, "speed": -1.1, "phase": 1.0},
			# длинное снизу экрана: из-за правого нижнего края вниз-влево
			{"base": Vector2(0.95, 0.88), "reach": 320.0,
				"knots": [2.4, 2.1, 1.8, 1.6], "wave": 0.14, "wsp": 4.0,
				"delay": 0.04, "speed": 1.3, "phase": 3.3},
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


## Позади карты: ударная волна и те части щупалец, что под картой.
static func draw_behind(c: CanvasItem, cid: String, card: Rect2, t: float) -> void:
	_draw_ring(c, cid, card, t)
	for tent: Dictionary in FX[cid]["tentacles"]:
		_draw_tentacle(c, cid, tent, card, t, false)


## Поверх карты: части щупалец, что обвивают её спереди.
static func draw_front(c: CanvasItem, cid: String, card: Rect2, t: float) -> void:
	for tent: Dictionary in FX[cid]["tentacles"]:
		if tent.has("front_from"):
			_draw_tentacle(c, cid, tent, card, t, true)


## На сколько пикселей вздрагивает карта: каждое щупальце, вылезая, толкает её.
static func card_shift(cid: String, t: float) -> Vector2:
	if not FX.has(cid):
		return Vector2.ZERO
	var shift := Vector2.ZERO
	for tent: Dictionary in FX[cid]["tentacles"]:
		var dt := t - float(tent["delay"]) - 0.3
		if dt > 0.0:
			var dir := Vector2.from_angle(float((tent["knots"] as Array)[0]))
			shift -= dir * JOLT * exp(-dt * JOLT_DECAY) * sin(dt * 40.0 + float(tent["phase"]))
	return shift.round()


static func _draw_ring(c: CanvasItem, cid: String, card: Rect2, t: float) -> void:
	var k := t / RING_TIME
	if k <= 0.0 or k >= 1.0:
		return
	var colour: Color = FX[cid]["tint"]
	colour.a = 0.7 * (1.0 - k)
	c.draw_rect(card.grow(roundf(RING_GROW * _ease_out(k))), colour, false, 2.0)


## Курс щупальца на доле длины u (0..1): плавно между ключевыми углами knots.
static func _heading(knots: Array, u: float) -> float:
	var n := knots.size()
	var k := clampf(u, 0.0, 1.0) * float(n - 1)
	var i := mini(int(k), n - 2)
	var pre := float(knots[maxi(i - 1, 0)])
	var post := float(knots[mini(i + 2, n - 1)])
	return cubic_interpolate(float(knots[i]), float(knots[i + 1]), pre, post, k - float(i))


## Кривая щупальца от корня: курс по ключевым углам + лёгкая бегущая волна,
## нарастающая к кончику, так что щупальце живёт, а не застыло.
static func _spine(tent: Dictionary, root: Vector2, t: float) -> PackedVector2Array:
	var knots: Array = tent["knots"]
	var seg := float(tent["reach"]) / SPINE_N
	var wave := float(tent["wave"])
	var wsp := float(tent["wsp"])
	var phase := float(tent["phase"])
	var pts := PackedVector2Array([root])
	var pos := root
	for i in range(1, SPINE_N + 1):
		var u := float(i) / SPINE_N
		var heading := _heading(knots, u) + wave * u * sin(u * 7.0 - t * wsp + phase)
		pos += Vector2.from_angle(heading) * seg
		pts.append(pos)
	return pts


static func _draw_tentacle(c: CanvasItem, cid: String, tent: Dictionary, card: Rect2, t: float,
		front: bool) -> void:
	var reach := float(tent["reach"])
	var delay := float(tent["delay"])
	var crawl := _ease_out_cubic((t - delay) / (CRAWL_BASE + reach * CRAWL_PER_PX))
	var gone := _ease_in((t - RETRACT_AT - delay * 0.5) / RETRACT_TIME)
	# голова «нащупывает»: чуть подаётся вперёд и назад, пока щупальце снаружи
	var probe := 1.0 + 0.03 * sin(t * 3.0 + float(tent["phase"])) * crawl
	var progress := crawl * (1.0 - gone) * probe
	if progress <= 0.0:
		return
	var root := (card.position + card.size * (tent["base"] as Vector2)).round()
	var pts := _spine(tent, root, t)
	var seg := reach / SPINE_N
	var head := reach * progress
	# длина тела — всё, что вылезло (корень остаётся под картой)
	var count := int(head / STEP)
	if count < 2:
		return

	# точки тела от кончика к корню по кривой
	var body := PackedVector2Array()
	for j in range(count + 1):
		var a := maxf(head - float(j) * STEP, 0.0)
		var k := minf(a / seg, float(SPINE_N) - 0.001)
		var i0 := int(k)
		body.append(pts[i0].lerp(pts[i0 + 1], k - float(i0)))

	var tex := _sprite(cid, _pingpong(t * FPS * float(tent["speed"]) + float(tent["phase"]) * 5.0,
		int(FX[cid]["frames"])))
	if tex == null:
		return
	var split := float(tent.get("front_from", INF))
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var hw := w * 0.5
	var colours := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	for j in range(count):
		# длина от корня до этой полоски: дальше front_from — поверх карты
		if (head - float(j) * STEP >= split) != front:
			continue
		var d := float(j) * STEP
		# дальше кончика строки идут туда-обратно: на стыке нет скачка в сторону
		var row := d
		if d >= TIP_ROWS:
			var m := fposmod(d - TIP_ROWS, 2.0 * REPEAT_ROWS)
			row = TIP_ROWS + (m if m < REPEAT_ROWS else 2.0 * REPEAT_ROWS - m)
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
