class_name CardFx
extends RefCounted

## Эффекты розыгрыша уникальных карт (в колоде одна копия): когда такую карту
## играют, витрина (CardShowcase) показывает её крупно и рисует вокруг свой
## эффект. Спрайты лежат в assets/card_fx/<card_id>/, сценарии — в таблице FX.
##
## Щупальца (Ulitharid) гибкие. Форма каждого — ломаная, снятая с рисунка
## владельца (2026-10-07; координаты в системе рисунка, SKETCH_CARD — где на нём
## карта): корень спрятан под краем карты, щупальце выползает из-за неё и идёт по
## своей кривой; где кривая возвращается на карту, оно идёт ПОВЕРХ неё. Тело —
## цепочка полосок спрайта вдоль кривой, поверх лёгкая бегущая волна. У каждого
## щупальца своя длина, скорость, плавность и время.
## Решение владельца: внутри эффектов полоски спрайта можно поворачивать на любой
## угол (общее пиксельное правило 1:1 здесь снято).

const SPRITE_PATH := "res://assets/card_fx/%s/%s.png"
## Сколько секунд висит карта с эффектом (обычная — CardShowcase.HOLD_TIME).
const HOLD_TIME := 2.8
## Кадров анимации щупальца в секунду (при speed = 1) и шаг полосок тела.
const FPS := 12.0
const STEP := 4.0
## Сколько отсчётов у кривой щупальца и сколько вставок на звено ломаной.
const SPINE_N := 96
const SMOOTH_N := 8
## На сколько пикселей карты корень уходит под её край (чтобы тело не торчало).
const LEAD_IN := 26.0
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
## Где на рисунке владельца лежит карта (x, y, ширина, высота).
const SKETCH_CARD := Rect2(320, 234, 410, 596)

## card_id -> сценарий. sprite/frames — спрайт и число его кадров, tint — цвет
## ударной волны, sound — звук (см. Sfx), tentacles — щупальца:
##   path — ломаная с рисунка, от корня (на краю карты) к кончику;
##   width — толщина (доля спрайта; длинные тонкие, как на рисунке);
##   delay — задержка; dur — сколько ползёт наружу; ease — как разгоняется
##   (out / inout / in / back); retract_at, retract_dur — когда и как быстро
##   втягивается; wave, wsp — размах (пиксели) и скорость лёгкой волны;
##   speed — скорость кадров (минус — назад); phase — сдвиг всего.
const FX := {
	"48701": {
		"sprite": "anim", "frames": 17, "tint": Color("b05ad8"), "sound": "sink",
		"tentacles": [
			# большое: из-за верхнего края дугой налево, обратно диагональю ПОВЕРХ
			# карты и вниз справа
			{"path": [Vector2(425, 232), Vector2(405, 215), Vector2(380, 200), Vector2(350, 190),
				Vector2(320, 187), Vector2(290, 193), Vector2(265, 208), Vector2(245, 225),
				Vector2(232, 245), Vector2(225, 270), Vector2(222, 300), Vector2(222, 325),
				Vector2(235, 345), Vector2(255, 365), Vector2(285, 388), Vector2(320, 402),
				Vector2(360, 413), Vector2(400, 428), Vector2(450, 442), Vector2(500, 455),
				Vector2(550, 466), Vector2(600, 479), Vector2(650, 492), Vector2(690, 502),
				Vector2(730, 520), Vector2(770, 543), Vector2(805, 575), Vector2(835, 605),
				Vector2(850, 632), Vector2(851, 680), Vector2(850, 720), Vector2(846, 750)],
				"width": 0.55, "delay": 0.30, "dur": 1.0, "ease": "inout", "retract_at": 2.0,
				"retract_dur": 0.55, "wave": 5.0, "wsp": 4.2, "speed": 1.0, "phase": 0.0},
			# короткое справа сверху: наружу и обратно на карту
			{"path": [Vector2(725, 283), Vector2(750, 292), Vector2(768, 310), Vector2(775, 330),
				Vector2(768, 352), Vector2(745, 378), Vector2(722, 402), Vector2(700, 420),
				Vector2(688, 440), Vector2(682, 460)],
				"width": 0.5, "delay": 0.00, "dur": 0.32, "ease": "back", "retract_at": 1.9,
				"retract_dur": 0.22, "wave": 3.0, "wsp": 6.0, "speed": -1.4, "phase": 2.1},
			# слева посередине: наружу налево, обратно через край и вниз по карте
			{"path": [Vector2(318, 486), Vector2(298, 505), Vector2(285, 530), Vector2(283, 555),
				Vector2(292, 580), Vector2(310, 603), Vector2(335, 620), Vector2(360, 635),
				Vector2(380, 655), Vector2(390, 685), Vector2(392, 712), Vector2(390, 744),
				Vector2(375, 762), Vector2(358, 782)],
				"width": 0.5, "delay": 0.12, "dur": 0.65, "ease": "out", "retract_at": 1.95,
				"retract_dur": 0.35, "wave": 4.0, "wsp": 5.0, "speed": 0.8, "phase": 4.2},
			# длинное справа снизу: наружу, потом S-образно вниз-влево до низа экрана
			{"path": [Vector2(735, 637), Vector2(758, 647), Vector2(775, 665), Vector2(781, 700),
				Vector2(779, 738), Vector2(765, 775), Vector2(745, 800), Vector2(720, 815),
				Vector2(690, 825), Vector2(650, 845), Vector2(600, 875), Vector2(560, 895),
				Vector2(525, 918), Vector2(500, 945), Vector2(485, 975), Vector2(477, 1005),
				Vector2(475, 1040), Vector2(483, 1066)],
				"width": 0.6, "delay": 0.45, "dur": 1.3, "ease": "in", "retract_at": 2.15,
				"retract_dur": 0.45, "wave": 6.0, "wsp": 3.4, "speed": 1.3, "phase": 3.3},
		],
	},
}

static var _cache: Dictionary = {}
static var _spines: Dictionary = {}


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
	var i := 0
	for tent: Dictionary in FX[cid]["tentacles"]:
		_draw_tentacle(c, cid, i, tent, card, t, false)
		i += 1


## Поверх карты: части щупалец, что лежат на ней.
static func draw_front(c: CanvasItem, cid: String, card: Rect2, t: float) -> void:
	var i := 0
	for tent: Dictionary in FX[cid]["tentacles"]:
		_draw_tentacle(c, cid, i, tent, card, t, true)
		i += 1


## На сколько пикселей вздрагивает карта: каждое щупальце, вылезая, толкает её
## в сторону, противоположную выходу.
static func card_shift(cid: String, t: float) -> Vector2:
	if not FX.has(cid):
		return Vector2.ZERO
	var shift := Vector2.ZERO
	var i := 0
	for tent: Dictionary in FX[cid]["tentacles"]:
		var dt := t - float(tent["delay"]) - float(tent["dur"]) * 0.4
		if dt > 0.0:
			var path: Array = tent["path"]
			var dir := ((path[1] as Vector2) - (path[0] as Vector2)).normalized()
			shift -= dir * JOLT * exp(-dt * JOLT_DECAY) * sin(dt * 40.0 + float(tent["phase"]))
		i += 1
	return shift.round()


static func _draw_ring(c: CanvasItem, cid: String, card: Rect2, t: float) -> void:
	var k := t / RING_TIME
	if k <= 0.0 or k >= 1.0:
		return
	var colour: Color = FX[cid]["tint"]
	colour.a = 0.7 * (1.0 - k)
	c.draw_rect(card.grow(roundf(RING_GROW * _ease_out_cubic(k))), colour, false, 2.0)


## Кривая щупальца в долях карты, ровно по длине: ломаная с рисунка, сглаженная
## и с заходом корня под край карты. Считается один раз на карту и размер.
## Возвращает {pts (доли карты, SPINE_N+1 точек), seg (пиксели), split (длина
## от корня, с которой тело идёт поверх карты, INF — никогда)}.
static func _spine_of(cid: String, index: int, size: Vector2) -> Dictionary:
	var key := "%s/%d/%d" % [cid, index, int(size.x)]
	if _spines.has(key):
		return _spines[key]
	var tent: Dictionary = FX[cid]["tentacles"][index]
	var path: Array = tent["path"]
	var raw: Array[Vector2] = []
	for p: Vector2 in path:
		raw.append((p - SKETCH_CARD.position) / SKETCH_CARD.size)
	# заход корня под карту: назад от первого звена
	var back := (raw[0] - raw[1]).normalized()
	raw.insert(0, raw[0] + back * Vector2(LEAD_IN, LEAD_IN) / size)
	# сглаживаем (Catmull-Rom) и считаем длину в пикселях
	var dense: Array[Vector2] = []
	for i in range(raw.size() - 1):
		var p0 := raw[maxi(i - 1, 0)]
		var p3 := raw[mini(i + 2, raw.size() - 1)]
		for k in range(SMOOTH_N):
			dense.append(raw[i].cubic_interpolate(raw[i + 1], p0, p3, float(k) / SMOOTH_N))
	dense.append(raw[raw.size() - 1])
	var cum: Array[float] = [0.0]
	for i in range(1, dense.size()):
		cum.append(cum[i - 1] + ((dense[i] - dense[i - 1]) * size).length())
	var total := cum[cum.size() - 1]
	var seg := total / SPINE_N
	# равномерные точки по длине
	var pts := PackedVector2Array()
	var j := 1
	for i in range(SPINE_N + 1):
		var a := seg * float(i)
		while j < dense.size() - 1 and cum[j] < a:
			j += 1
		var span := maxf(cum[j] - cum[j - 1], 0.0001)
		pts.append(dense[j - 1].lerp(dense[j], clampf((a - cum[j - 1]) / span, 0.0, 1.0)))
	# с какой длины тело идёт поверх карты: первый заход обратно на карту после
	# выхода за её край
	var split := INF
	var out := false
	for i in range(pts.size()):
		var q := pts[i]
		if not out and (q.x < -0.03 or q.x > 1.03 or q.y < -0.03 or q.y > 1.03):
			out = true
		elif out and q.x > 0.02 and q.x < 0.98 and q.y > 0.02 and q.y < 0.98:
			split = seg * float(i)
			break
	var res := {"pts": pts, "seg": seg, "split": split, "total": total}
	_spines[key] = res
	return res


static func _ease(kind: String, x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	match kind:
		"in":
			return x * x
		"inout":
			return x * x * (3.0 - 2.0 * x)
		"back":
			var c1 := 1.70158
			return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
	return 1.0 - pow(1.0 - x, 3.0)


static func _draw_tentacle(c: CanvasItem, cid: String, index: int, tent: Dictionary, card: Rect2,
		t: float, front: bool) -> void:
	var sp := _spine_of(cid, index, card.size)
	var seg := float(sp["seg"])
	var total := float(sp["total"])
	var split := float(sp["split"])
	var delay := float(tent["delay"])
	var out := _ease(String(tent["ease"]), (t - delay) / float(tent["dur"]))
	var gone := _ease("in", (t - float(tent["retract_at"])) / float(tent["retract_dur"]))
	var phase := float(tent["phase"])
	# голова «нащупывает»: чуть подаётся вперёд и назад, пока щупальце снаружи
	var progress := out * (1.0 - gone) * (1.0 + 0.012 * sin(t * 3.0 + phase) * out)
	var head := minf(total * progress, total)
	var count := int(head / STEP)
	if count < 2:
		return
	var fpts: PackedVector2Array = sp["pts"]
	# точки кривой в пикселях со слабой бегущей волной (корень и кончик живут по-разному)
	var wave := float(tent["wave"])
	var wsp := float(tent["wsp"])
	var pts := PackedVector2Array()
	for i in range(fpts.size()):
		var p := card.position + fpts[i] * card.size
		var prev := card.position + fpts[maxi(i - 1, 0)] * card.size
		var next := card.position + fpts[mini(i + 1, fpts.size() - 1)] * card.size
		var u := float(i) / SPINE_N
		var off := wave * sin(u * 9.0 - t * wsp + phase) * clampf(u * 4.0, 0.0, 1.0)
		pts.append(p + (next - prev).orthogonal().normalized() * off)

	# точки тела от кончика к корню
	var body := PackedVector2Array()
	for j in range(count + 1):
		var a := maxf(head - float(j) * STEP, 0.0)
		var k := minf(a / seg, float(SPINE_N) - 0.001)
		var i0 := int(k)
		body.append(pts[i0].lerp(pts[i0 + 1], k - float(i0)))

	var tex := _sprite(cid, _pingpong(t * FPS * float(tent["speed"]) + phase * 5.0, int(FX[cid]["frames"])))
	if tex == null:
		return
	var s := float(tent["width"])
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var hw := w * 0.5 * s
	var colours := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	for j in range(count):
		# длина от корня до этой полоски: дальше split — поверх карты
		if (head - float(j) * STEP >= split) != front:
			continue
		# строка спрайта: тонкое щупальце — спрайт уменьшен целиком (и по длине тоже)
		var d := float(j) * STEP / s
		var row := d
		if d >= TIP_ROWS:
			var m := fposmod(d - TIP_ROWS, 2.0 * REPEAT_ROWS)
			row = TIP_ROWS + (m if m < REPEAT_ROWS else 2.0 * REPEAT_ROWS - m)
		var v0 := row / h
		var v1 := minf(row + STEP / s, h) / h
		var n0 := (body[mini(j + 1, count)] - body[maxi(j - 1, 0)]).orthogonal().normalized() * hw
		var n1 := (body[mini(j + 2, count)] - body[j]).orthogonal().normalized() * hw
		# draw_primitive, а не draw_polygon: тот отказывается рисовать «скрученный» кусок
		c.draw_primitive(
			PackedVector2Array([body[j] - n0, body[j] + n0, body[j + 1] + n1, body[j + 1] - n1]),
			colours, PackedVector2Array([Vector2(0, v0), Vector2(1, v0), Vector2(1, v1), Vector2(0, v1)]), tex)


static func _ease_out_cubic(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)
