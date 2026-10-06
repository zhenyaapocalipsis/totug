class_name CardFx
extends RefCounted

## Эффекты розыгрыша уникальных карт (в колоде одна копия): когда такую карту
## играют, витрина (CardShowcase) показывает её крупно и рисует вокруг свой
## эффект. Спрайты лежат в assets/card_fx/<card_id>/, сценарии — в таблице FX.
##
## Щупальца (Ulitharid) гибкие. Форма каждого — ломаная, снятая с рисунка
## владельца (2026-10-07; координаты в системе рисунка, SKETCH_CARD — где на нём
## карта), сглаженная: корень спрятан под краем карты, щупальце выползает из-за
## неё и идёт по своей кривой; где кривая возвращается на карту, оно идёт ПОВЕРХ
## неё. Тело — цепочка полосок спрайта вдоль кривой.
##
## Сочность: при выстреле по телу бежит затухающая волна (тело запаздывает за
## головой), голова перелетает цель и откатывается; по толщине пробегают
## сокращения; все щупальца приходят к финишу одновременно — карта вздрагивает,
## вторая ударная волна, брызги слизи. Вылезли — лёгкое дыхание кривой.
## Решение владельца: внутри эффектов полоски спрайта можно поворачивать на любой
## угол (общее пиксельное правило 1:1 здесь снято).

const SPRITE_PATH := "res://assets/card_fx/%s/%s.png"
## Сколько секунд висит карта с эффектом (обычная — CardShowcase.HOLD_TIME).
const HOLD_TIME := 2.8
## Шаг полосок тела.
const STEP := 3.0
## Сколько отсчётов у кривой щупальца, сколько вставок на звено ломаной, сколько
## проходов сглаживания и сколько отсчётов продолжения за концом (для перелёта).
const SPINE_N := 96
const SMOOTH_N := 8
const SMOOTH_PASSES := 14
const EXT_N := 14
## На сколько пикселей карты корень уходит под её край (чтобы тело не торчало).
const LEAD_IN := 26.0
## Момент, когда все щупальца дошли до финиша, и силы удара.
const IMPACT_T := 1.15
const IMPACT_SHAKE := 2.5
const IMPACT_DECAY := 9.0
## Ударные волны: квадрат вокруг карты расширяется и гаснет.
const RING_TIME := 0.45
const RING_GROW := 70.0
## Затухающая волна при выстреле и лёгкое дыхание кривой (пиксели).
const WHIP := 9.0
const WHIP_DECAY := 3.5
const IDLE := 2.5
## Брызги слизи: сколько, сколько живут, сторона квадрата, ускорение вниз.
const DROPS := 9
const DROP_LIFE := 0.55
const DROP_SIZE := 3.0
const DROP_GRAVITY := 280.0
## На сколько пикселей щупальце должно выйти за край карты, чтобы дальше идти ПОВЕРХ
## неё (не меньше половины ширины тела).
const BEHIND_GAP := 14.0
## Рабочие строки спрайта: с ROW_FROM (доля высоты; выше запечён завиток) берётся один
## период колец (ищется сам, RING_P_*); ниже гладкий острый конец. Кончик заостряется
## кодом на TIP_LEN пикселей.
const ROW_FROM := 0.19
const RING_P_MIN := 14
const RING_P_MAX := 90
## Сколько строк и точек поперёк тела сравниваем при поиске периода колец.
const RING_CHECK := 50
const RING_SAMPLES := 12
const TIP_LEN := 80.0
## Минимальная полуширина тела, пиксели: у самого острия щупальце не рвётся на пунктир.
const MIN_HALF := 0.9
## Размах бегущей по телу волны сжатия: на сколько пикселей «перетекают» кольца.
const RING_FLOW := 4.0
## Загиб кончика появляется после прихода: на сколько пикселей, на какой длине от
## головы и за сколько секунд.
const HOOK := 16.0
const HOOK_LEN := 70.0
const HOOK_TIME := 0.5
## Где на рисунке владельца лежит карта (x, y, ширина, высота).
const SKETCH_CARD := Rect2(320, 234, 410, 596)

## card_id -> сценарий. sprite — спрайт щупальца (прямой, у основания толстый, к
## кончику тонкий), tint — цвет ударной волны, sound — звук (см. Sfx), tentacles —
## щупальца:
##   path — ломаная с рисунка, от корня (на краю карты) к кончику;
##   width — толщина у корня, пиксели (дальше тоньше);
##   delay — задержка; dur — сколько ползёт наружу; ease — как разгоняется
##   (out / inout / in / back / launch); retract_at, retract_dur — когда и как быстро
##   втягивается; phase — сдвиг волн (у каждого своя).
const FX := {
	"48701": {
		"sprite": "tentacle_illithid", "tint": Color("7f8cff"), "sound": "sink",
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
				"width": 22.0, "delay": 0.0, "dur": 1.15, "ease": "launch", "retract_at": 2.2,
				"retract_dur": 0.45, "phase": 0.0},
			# короткое справа сверху: наружу и обратно на карту
			{"path": [Vector2(725, 283), Vector2(750, 292), Vector2(768, 310), Vector2(775, 330),
				Vector2(768, 352), Vector2(745, 378), Vector2(722, 402), Vector2(700, 420),
				Vector2(688, 440), Vector2(682, 460)],
				"width": 14.0, "delay": 0.0, "dur": 1.15, "ease": "launch", "retract_at": 2.2,
				"retract_dur": 0.45, "phase": 2.1},
			# слева посередине: наружу налево, обратно через край и вниз по карте
			{"path": [Vector2(318, 486), Vector2(298, 505), Vector2(285, 530), Vector2(283, 555),
				Vector2(292, 580), Vector2(310, 603), Vector2(335, 620), Vector2(360, 635),
				Vector2(380, 655), Vector2(390, 685), Vector2(392, 712), Vector2(390, 744),
				Vector2(375, 762), Vector2(358, 782)],
				"width": 17.0, "delay": 0.0, "dur": 1.15, "ease": "launch", "retract_at": 2.2,
				"retract_dur": 0.45, "phase": 4.2},
			# длинное справа снизу: наружу, потом S-образно вниз-влево до низа экрана
			{"path": [Vector2(735, 637), Vector2(758, 647), Vector2(775, 665), Vector2(781, 700),
				Vector2(779, 738), Vector2(765, 775), Vector2(745, 800), Vector2(720, 815),
				Vector2(690, 825), Vector2(650, 845), Vector2(600, 875), Vector2(560, 895),
				Vector2(525, 918), Vector2(500, 945), Vector2(485, 975), Vector2(477, 1005),
				Vector2(475, 1040), Vector2(483, 1066)],
				"width": 20.0, "delay": 0.0, "dur": 1.15, "ease": "launch", "retract_at": 2.2,
				"retract_dur": 0.45, "phase": 3.3},
		],
	},
}

static var _cache: Dictionary = {}
## Отладка (tests/ui_shot.gd --isolate): рисовать только щупальца на чёрном фоне.
static var debug_isolate := false
static var _spines: Dictionary = {}


static func has(cid: String) -> bool:
	return FX.has(cid)


static func sound(cid: String) -> String:
	return String(FX[cid]["sound"]) if FX.has(cid) else ""


## Спрайт щупальца карты cid.
static func _sprite(cid: String) -> Texture2D:
	var name := String(FX[cid]["sprite"])
	var key := "%s/%s" % [cid, name]
	if not _cache.has(key):
		_cache[key] = load(SPRITE_PATH % [cid, name])
	return _cache[key]


## Позади карты: ударные волны и те части щупалец, что под картой.
static func draw_behind(c: CanvasItem, cid: String, card: Rect2, t: float) -> void:
	_draw_ring(c, cid, card, t, 0.0, 1.0, RING_GROW)
	_draw_ring(c, cid, card, t, IMPACT_T, 0.7, RING_GROW * 0.6)
	var i := 0
	for tent: Dictionary in FX[cid]["tentacles"]:
		_draw_tentacle(c, cid, i, tent, card, t, false)
		i += 1


## Поверх карты: части щупалец, что лежат на ней, и брызги слизи.
static func draw_front(c: CanvasItem, cid: String, card: Rect2, t: float) -> void:
	var i := 0
	for tent: Dictionary in FX[cid]["tentacles"]:
		_draw_tentacle(c, cid, i, tent, card, t, true)
		_draw_drops(c, cid, i, card, t)
		i += 1


## На сколько пикселей вздрагивает карта: удар в момент, когда все щупальца дошли.
static func card_shift(cid: String, t: float) -> Vector2:
	var dt := t - IMPACT_T
	if not FX.has(cid) or dt <= 0.0:
		return Vector2.ZERO
	return (Vector2(sin(dt * 55.0), cos(dt * 47.0)) * IMPACT_SHAKE * exp(-dt * IMPACT_DECAY)).round()


static func _draw_ring(c: CanvasItem, cid: String, card: Rect2, t: float, at: float, alpha: float,
		grow: float) -> void:
	var k := (t - at) / RING_TIME
	if debug_isolate:
		return
	if k <= 0.0 or k >= 1.0:
		return
	var colour: Color = FX[cid]["tint"]
	colour.a = alpha * 0.7 * (1.0 - k)
	c.draw_rect(card.grow(roundf(grow * (1.0 - pow(1.0 - k, 3.0)))), colour, false, 2.0)


## Кривая щупальца в долях карты, ровно по длине: ломаная с рисунка, сглаженная
## (рисунок рукодельный, в нём изломы), с заходом корня под край карты и
## прямым продолжением за концом — туда голова перелетает цель. Считается один
## раз на карту и размер. Возвращает {pts, seg (пиксели), split (длина от корня, с
## которой тело идёт поверх карты, INF — никогда), total (длина до цели)}.
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
	# убираем изломы: несколько проходов [1 2 1]/4, концы стоят на месте
	for _pass in range(SMOOTH_PASSES):
		for i in range(1, pts.size() - 1):
			pts[i] = (pts[i - 1] + pts[i] * 2.0 + pts[i + 1]) * 0.25
	# продолжение за концом по последнему направлению
	var dir := ((pts[pts.size() - 1] - pts[pts.size() - 4]) * size).normalized()
	for i in range(1, EXT_N + 1):
		pts.append(pts[SPINE_N] + dir * seg * float(i) / size)
	# с какой длины тело идёт поверх карты: первый заход обратно на карту после
	# выхода за её край
	var split := INF
	for i in range(SPINE_N + 1):
		# расстояние (пиксели) от центра щупальца до прямоугольника карты
		var q := pts[i] * size
		var gap := Vector2(maxf(maxf(-q.x, q.x - size.x), 0.0), maxf(maxf(-q.y, q.y - size.y), 0.0)).length()
		if gap >= BEHIND_GAP:
			# позади карты — только корень, пока щупальце не вышло за край на ширину
			# тела; дальше всё поверх карты (иначе на рамке тело режется: одна сторона
			# ныряет под рамку, другая остаётся сверху)
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
			# перелёт ~10% за цель и возврат
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
	var raw_t := (t - delay) / float(tent["dur"])
	# перелёт ограничен: спрайт не вытягивается за продолжение кривой
	var out := _ease_unclamped(String(tent["ease"]), raw_t)
	var gone := _ease("in", (t - float(tent["retract_at"])) / float(tent["retract_dur"]))
	var phase := float(tent["phase"])
	var head := minf(total * out * (1.0 - gone), seg * float(SPINE_N + EXT_N - 1))
	var count := int(head / STEP)
	if count < 2:
		return
	var fpts: PackedVector2Array = sp["pts"]
	# точки кривой в пикселях; при выстреле по телу бежит затухающая волна (тело
	# запаздывает за головой), потом остаётся лёгкое дыхание; при втягивании щупальце
	# хлещет. Корень стоит на месте.
	var since := maxf(t - delay, 0.0)
	# короткое щупальце только выходит из-под карты — ему не до хлёста
	var amp := (WHIP * exp(-WHIP_DECAY * since) + IDLE * clampf(out, 0.0, 1.0) \
		+ WHIP * 1.3 * gone * (1.0 - gone) * 4.0) * smoothstep(0.0, 1.0, head / 140.0)
	var pts := PackedVector2Array()
	for i in range(fpts.size()):
		var p := card.position + fpts[i] * card.size
		var prev := card.position + fpts[maxi(i - 1, 0)] * card.size
		var next := card.position + fpts[mini(i + 1, fpts.size() - 1)] * card.size
		var u := float(i) / SPINE_N
		var off := amp * sin(u * 5.5 - t * 5.0 + phase) * clampf(u * 3.0, 0.0, 1.0)
		pts.append(p + (next - prev).orthogonal().normalized() * off)

	# точки тела от кончика к корню
	var body := PackedVector2Array()
	for j in range(count + 1):
		var a := maxf(head - float(j) * STEP, 0.0)
		var k := minf(a / seg, float(fpts.size()) - 1.001)
		var i0 := int(k)
		body.append(pts[i0].lerp(pts[i0 + 1], k - float(i0)))

	# загиб кончика: щупальце выходит прямым и закручивается, уже когда дошло
	var hook := HOOK * smoothstep(0.0, 1.0, (t - delay - float(tent["dur"]) * 0.85) / HOOK_TIME) \
		* (1.0 - gone) * (1.0 if sin(phase) >= 0.0 else -1.0)
	if absf(hook) > 0.01:
		var bent := body.duplicate()
		for j in range(mini(int(HOOK_LEN / STEP) + 1, count + 1)):
			var nrm := (body[mini(j + 1, count)] - body[maxi(j - 1, 0)]).orthogonal().normalized()
			bent[j] = body[j] + nrm * hook * pow(1.0 - float(j) * STEP / HOOK_LEN, 2.0)
		body = bent

	var tex := _sprite(cid)
	if tex == null:
		return
	var bounds := _bounds(cid)
	var lefts: PackedFloat32Array = bounds["left"]
	var rights: PackedFloat32Array = bounds["right"]
	var h := float(tex.get_height())
	var w := float(tex.get_width())
	var row_lo := float(bounds["y0"])
	var period := float(bounds["period"])
	# плотность текстуры постоянна (пиксели квадратные) на любой длине: сколько строк
	# спрайта приходится на пиксель вдоль щупальца. Тело спрайта (в среднем mean_w
	# пикселей) должно уместиться в заданную ширину у корня.
	var root_w := float(tent["width"])
	var density := float(bounds["mean"]) / root_w
	# пока щупальце в движении, по телу бегут сокращения (толщина пульсирует)
	var pulse := 0.12 * (1.0 - clampf(out, 0.0, 1.0)) + 0.04 + 0.1 * gone

	# точки полосок от головы к корню: нормаль, полуширина и строка спрайта (без зацикливания;
	# зацикливание — ниже, при рисовании каждой полоски)
	var normals := PackedVector2Array()
	var halves := PackedFloat32Array()
	var rows := PackedFloat32Array()
	for j in range(count + 1):
		normals.append((body[mini(j + 1, count)] - body[maxi(j - 1, 0)]).orthogonal().normalized())
		var dist := float(j) * STEP
		var a := maxf(head - dist, 0.0)
		# толщина: у корня полная, к дальнему концу тоньше, у самой головы — остриё
		var profile := root_w * 0.5 * (1.0 - 0.55 * clampf(a / total, 0.0, 1.0))
		var taper := pow(clampf(dist / TIP_LEN, 0.0, 1.0), 0.6)
		# не тоньше MIN_HALF: острие тоньше пикселя рисуется пунктиром и «рвётся»
		halves.append(maxf(profile * taper * (1.0 + pulse * sin(dist * 0.07 - t * 9.0 + phase)), MIN_HALF))
		# текстура привязана к ГОЛОВЕ: кольца едут вместе с ней (щупальце движется, а не
		# «открывается» из-под маски); по телу бегут волны сжатия, поэтому кольца
		# перетекают и когда щупальце уже дошло.
		var flow := RING_FLOW * sin(dist * 0.045 - t * 4.5 + phase)
		rows.append(dist * density + flow * density)
	var colours := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	for j in range(count):
		# длина от корня до этой полоски: дальше split — поверх карты
		if (head - float(j) * STEP >= split) != front:
			continue
		# внутри полоски строки идут непрерывно: переход через конец периода случается
		# только между полосками (иначе вся плитка за один шаг разворачивается назад и
		# щупальце «рвётся»); узор в конце периода совпадает с началом
		var r0 := row_lo + fposmod(rows[j], period)
		var r1 := r0 + (rows[j + 1] - rows[j])
		var i0 := clampi(int(r0), 0, lefts.size() - 1)
		var i1 := clampi(int(r1), 0, lefts.size() - 1)
		var n0 := normals[j] * halves[j]
		var n1 := normals[j + 1] * halves[j + 1]
		# draw_primitive, а не draw_polygon: тот отказывается рисовать «скрученный» кусок
		c.draw_primitive(
			PackedVector2Array([body[j] - n0, body[j] + n0, body[j + 1] + n1, body[j + 1] - n1]),
			colours, PackedVector2Array([
				Vector2(lefts[i0] / w, r0 / h), Vector2(rights[i0] / w, r0 / h),
				Vector2(rights[i1] / w, r1 / h), Vector2(lefts[i1] / w, r1 / h)]), tex)


## Границы тела спрайта по строкам (непрозрачные пиксели; левая и правая, в пикселях
## от левого края), начало и период колец и средняя ширина тела на этом периоде.
## Считается один раз: по ним полоска растягивается ровно на тело, а S-образный изгиб
## спрайта не уводит тело в сторону.
static func _bounds(cid: String) -> Dictionary:
	var key := "bounds/" + cid
	if _cache.has(key):
		return _cache[key]
	var img := _sprite(cid).get_image()
	var h := img.get_height()
	var w := img.get_width()
	var lefts := PackedFloat32Array()
	var rights := PackedFloat32Array()
	for y in range(h):
		var lo := w
		var hi := 0
		for x in range(w):
			if img.get_pixel(x, y).a > 0.5:
				lo = mini(lo, x)
				hi = maxi(hi, x + 1)
		lefts.append(float(lo) if hi > 0 else 0.0)
		rights.append(float(hi) if hi > 0 else float(w))
	# сглаживаем границы по соседним строкам: без дрожи краёв
	var sl := lefts.duplicate()
	var sr := rights.duplicate()
	for y in range(1, h - 1):
		sl[y] = (lefts[y - 1] + lefts[y] + lefts[y + 1]) / 3.0
		sr[y] = (rights[y - 1] + rights[y] + rights[y + 1]) / 3.0
	# период колец: на сколько строк надо отступить, чтобы узор тела (в долях ширины
	# тела, а не в пикселях) совпал сам с собой. Тогда кусок спрайта можно повторять
	# встык без зеркала — кольца не меняют наклон.
	var y0 := int(ROW_FROM * h)
	var best_p := RING_P_MIN
	var best_err := INF
	for p in range(RING_P_MIN, RING_P_MAX + 1):
		var err := 0.0
		for y in range(y0, y0 + RING_CHECK):
			for k in range(RING_SAMPLES):
				var u := (float(k) + 0.5) / RING_SAMPLES
				var a := img.get_pixel(int(lerpf(sl[y], sr[y], u)), y)
				var b := img.get_pixel(int(lerpf(sl[y + p], sr[y + p], u)), y + p)
				err += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
		# слабо предпочитаем короткий период (длинный лучше совпадает и выглядит живее)
		err *= 1.0 + 0.0005 * float(p)
		if err < best_err:
			best_err = err
			best_p = p
	var total_w := 0.0
	for y in range(y0, y0 + best_p):
		total_w += sr[y] - sl[y]
	var res := {"left": sl, "right": sr, "mean": total_w / float(best_p), "y0": y0, "period": best_p}
	_cache[key] = res
	return res


## Как _ease, но «back» не обрезается сверху: перелёт — это значения больше 1.
static func _ease_unclamped(kind: String, x: float) -> float:
	if kind == "launch":
		# плавный разгон из-под карты, на подходе лёгкий перелёт (до ~9%) и посадка
		x = clampf(x, 0.0, 1.0)
		var s := x * x * (3.0 - 2.0 * x)
		return s * (1.0 + 0.09 * sin(clampf((x - 0.55) / 0.45, 0.0, 1.0) * PI))
	if kind == "back":
		x = clampf(x, 0.0, 1.0)
		return 1.0 + 2.70158 * pow(x - 1.0, 3.0) + 1.70158 * pow(x - 1.0, 2.0)
	return _ease(kind, x)


## Брызги слизи: из-под края карты при выстреле и из головы щупальца при ударе.
## Каждая капля летит по своей дуге; разброс детерминирован (одинаков у всех).
static func _draw_drops(c: CanvasItem, cid: String, index: int, card: Rect2, t: float) -> void:
	var sp := _spine_of(cid, index, card.size)
	var fpts: PackedVector2Array = sp["pts"]
	var colour: Color = FX[cid]["tint"]
	colour = colour.lerp(Color.WHITE, 0.35)
	var root := card.position + fpts[5] * card.size
	var out_dir := ((fpts[6] - fpts[4]) * card.size).normalized()
	var head := card.position + fpts[SPINE_N] * card.size
	var rng := RandomNumberGenerator.new()
	for src in range(2):
		var at := 0.05 if src == 0 else IMPACT_T
		var tau := t - at
		if tau <= 0.0 or tau >= DROP_LIFE:
			continue
		var origin := root if src == 0 else head
		for k in range(DROPS):
			rng.seed = hash("%s/%d/%d/%d" % [cid, index, src, k])
			var angle := out_dir.angle() + rng.randf_range(-0.9, 0.9) if src == 0 \
				else rng.randf_range(0.0, TAU)
			var speed := rng.randf_range(70.0, 170.0)
			var pos := origin + Vector2.from_angle(angle) * speed * tau + Vector2(0, DROP_GRAVITY * tau * tau * 0.5)
			colour.a = 1.0 - tau / DROP_LIFE
			c.draw_rect(Rect2(pos.round(), Vector2(DROP_SIZE, DROP_SIZE)), colour)
