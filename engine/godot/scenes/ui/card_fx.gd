class_name CardFx
extends RefCounted

## Эффекты розыгрыша уникальных карт (в колоде одна копия): когда такую карту
## играют, витрина (CardShowcase) показывает её крупно и рисует вокруг свой
## эффект. Спрайты лежат в assets/card_fx/<card_id>/, сценарии — в таблице FX.
##
## Щупальца (Ulitharid) гибкие: корень спрятан под картой, тело выползает из-под
## её края по плавной дуге, а само тело — цепочка полосок спрайта вдоль кривой,
## которая каждый кадр пересчитывается с бегущей волной и подкруткой кончика.
## Решение владельца (2026-10-07): внутри эффектов полоски спрайта можно
## поворачивать на любой угол (общее пиксельное правило 1:1 здесь снято).

const SPRITE_PATH := "res://assets/card_fx/%s/%s.png"
## Сколько секунд висит карта с эффектом (обычная — CardShowcase.HOLD_TIME).
const HOLD_TIME := 1.9
## Время выползания щупальца, момент и время втягивания обратно под карту.
const CRAWL_TIME := 0.6
const RETRACT_AT := 1.45
const RETRACT_TIME := 0.35
## Кадров анимации щупальца в секунду (при speed = 1) и шаг полосок тела.
const FPS := 12.0
const STEP := 4.0
## На сколько отрезков разбита кривая щупальца.
const SPINE_N := 48
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
##   base — корень (доли карты, под ней); dir — куда выползает (радианы, 0 —
##   вправо, дальше по часовой); reach — на сколько пикселей вылезает; bend —
##   общий изгиб дуги; wave — размах волны (радианы); wsp — её скорость; curl —
##   подкрутка кончика; delay — задержка; speed — скорость кадров анимации
##   (минус — назад); phase — сдвиг всего. У каждого своё: движутся вразнобой.
const FX := {
	"48701": {
		"sprite": "anim", "frames": 17, "tint": Color("b05ad8"), "sound": "sink",
		"tentacles": [
			{"base": Vector2(0.25, 0.20), "dir": -1.95, "reach": 130.0, "bend": 0.5, "wave": 0.9, "wsp": 4.6,
				"curl": 1.4, "delay": 0.00, "speed": 1.0, "phase": 0.0},
			{"base": Vector2(0.75, 0.22), "dir": -1.2, "reach": 120.0, "bend": -0.6, "wave": 1.0, "wsp": 3.8,
				"curl": -1.5, "delay": 0.09, "speed": -1.3, "phase": 2.1},
			{"base": Vector2(0.20, 0.34), "dir": 3.35, "reach": 240.0, "bend": -0.7, "wave": 0.8, "wsp": 5.2,
				"curl": 1.6, "delay": 0.04, "speed": 0.8, "phase": 4.2},
			{"base": Vector2(0.20, 0.76), "dir": 2.75, "reach": 220.0, "bend": 0.8, "wave": 1.0, "wsp": 4.1,
				"curl": -1.3, "delay": 0.14, "speed": -1.1, "phase": 1.0},
			{"base": Vector2(0.80, 0.40), "dir": -0.2, "reach": 250.0, "bend": 0.6, "wave": 0.9, "wsp": 4.9,
				"curl": -1.6, "delay": 0.10, "speed": 1.4, "phase": 3.3},
			{"base": Vector2(0.80, 0.78), "dir": 0.45, "reach": 225.0, "bend": -0.8, "wave": 1.0, "wsp": 3.6,
				"curl": 1.4, "delay": 0.02, "speed": -0.9, "phase": 5.5},
			{"base": Vector2(0.35, 0.86), "dir": 1.95, "reach": 150.0, "bend": 0.7, "wave": 0.8, "wsp": 5.6,
				"curl": -1.4, "delay": 0.17, "speed": 1.2, "phase": 0.7},
			{"base": Vector2(0.65, 0.86), "dir": 1.2, "reach": 160.0, "bend": -0.5, "wave": 0.9, "wsp": 4.3,
				"curl": 1.5, "delay": 0.06, "speed": -1.0, "phase": 2.9},
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


## Позади карты: ударная волна и щупальца, выползающие из-под неё.
static func draw_behind(c: CanvasItem, cid: String, card: Rect2, t: float) -> void:
	_draw_ring(c, cid, card, t)
	for tent: Dictionary in FX[cid]["tentacles"]:
		_draw_tentacle(c, cid, tent, card, t)


## На сколько пикселей вздрагивает карта: каждое щупальце, вылезая, толкает её.
static func card_shift(cid: String, t: float) -> Vector2:
	if not FX.has(cid):
		return Vector2.ZERO
	var shift := Vector2.ZERO
	for tent: Dictionary in FX[cid]["tentacles"]:
		var dt := t - float(tent["delay"]) - CRAWL_TIME * 0.5
		if dt > 0.0:
			var dir := Vector2.from_angle(float(tent["dir"]))
			shift -= dir * JOLT * exp(-dt * JOLT_DECAY) * sin(dt * 40.0 + float(tent["phase"]))
	return shift.round()


static func _draw_ring(c: CanvasItem, cid: String, card: Rect2, t: float) -> void:
	var k := t / RING_TIME
	if k <= 0.0 or k >= 1.0:
		return
	var colour: Color = FX[cid]["tint"]
	colour.a = 0.7 * (1.0 - k)
	c.draw_rect(card.grow(roundf(RING_GROW * _ease_out(k))), colour, false, 2.0)


## Кривая щупальца от корня: курс меняется вдоль длины (общий изгиб + бегущая
## волна + подкрутка кончика), так что щупальце извивается, а не торчит палкой.
static func _spine(tent: Dictionary, root: Vector2, t: float) -> PackedVector2Array:
	var reach := float(tent["reach"])
	var dir := float(tent["dir"])
	var bend := float(tent["bend"])
	var wave := float(tent["wave"])
	var wsp := float(tent["wsp"])
	var curl := float(tent["curl"])
	var phase := float(tent["phase"])
	var pts := PackedVector2Array([root])
	var pos := root
	var seg := reach / SPINE_N
	for i in range(1, SPINE_N + 1):
		var u := float(i) / SPINE_N
		# курс: дуга + волна, нарастающая к кончику + подкрутка на последней трети
		var heading := dir + bend * u + wave * u * sin(u * 5.0 - t * wsp + phase) \
			+ curl * pow(u, 3.0) * (0.75 + 0.25 * sin(t * 2.3 + phase))
		pos += Vector2.from_angle(heading) * seg
		pts.append(pos)
	return pts


static func _draw_tentacle(c: CanvasItem, cid: String, tent: Dictionary, card: Rect2, t: float) -> void:
	var delay := float(tent["delay"])
	var crawl := _ease_out_cubic((t - delay) / CRAWL_TIME)
	var gone := _ease_in((t - RETRACT_AT - delay * 0.5) / RETRACT_TIME)
	# голова «нащупывает»: чуть подаётся вперёд и назад, пока щупальце снаружи
	var probe := 1.0 + 0.05 * sin(t * 3.0 + float(tent["phase"])) * crawl
	var progress := crawl * (1.0 - gone) * probe
	if progress <= 0.0:
		return
	var root := (card.position + card.size * (tent["base"] as Vector2)).round()
	var pts := _spine(tent, root, t)
	var seg := float(tent["reach"]) / SPINE_N
	var head := float(tent["reach"]) * progress
	# длина тела — всё, что вылезло (корень остаётся под картой)
	var count := int(head / STEP)
	if count < 2:
		return

	# точки тела от кончика к корню по кривой; ближе корня — в корне
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
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var hw := w * 0.5
	var colours := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	for j in range(count):
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
