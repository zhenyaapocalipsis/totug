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
const HOLD_TIME := 3.1
## Замах до выхода щупалец (карта дрожит, вокруг разгорается свечение, у корней искры),
## остановка времени на ударе и вспышка.
const ANTIC := 0.3
const ANTIC_SHAKE := 1.5
const HIT_STOP := 0.07
const FLASH_T := 0.16
const FLASH_ALPHA := 0.85
## Свечение вокруг карты: слоёв и прозрачность слоя; пылинки после удара.
const GLOW_LAYERS := 6
const GLOW_ALPHA := 0.1
const MOTES := 30
const MOTE_LIFE := 1.0
const MOTE_RISE := 40.0
## Обводка тела (пиксели) и тень на карте (смещение).
const OUTLINE := 1.5
const SHADOW := Vector2(3, 4)
## Ширина тела у корня самого толстого щупальца, к которой подгоняется спрайт.
const ROOT_REF := 22.0
## Сколько пикселей поверх-слоя у стыка с задним слоем остаются без обводки и тени.
const SEAM_SKIP := 9.0
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
## Сколько строк спрайта перекрываются на шве плитки (примерно одно кольцо).
const SEAM_ROWS := 18.0
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
## Сетка эффекта: эффект рисуется на холсте в grid раз меньше экрана и растягивается
## без сглаживания — все точки эффекта одного размера. 1 — сетка экрана игры.
static var grid := 2


static func has(cid: String) -> bool:
	return FX.has(cid)


static func sound(cid: String) -> String:
	return String(FX[cid]["sound"]) if FX.has(cid) else ""


## Спрайт щупальца карты cid.
static func _sprite(cid: String) -> Texture2D:
	var name := String(FX[cid]["sprite"])
	var key := "%s/%s/%d" % [cid, name, grid]
	if not _cache.has(key):
		_cache[key] = _fit(load(SPRITE_PATH % [cid, name]), key)
	return _cache[key]


## Во сколько раз спрайт уменьшен под сетку (1 — как есть); строки спрайта и периоды
## колец считаются в строках уменьшенного спрайта.
static func _scale(cid: String) -> float:
	_sprite(cid)
	return float(_cache["%s/%s/%d/scale" % [cid, FX[cid]["sprite"], grid]])


## Спрайт, подогнанный под сетку: одна точка спрайта — одна точка сетки (ширина тела
## ROOT_REF пикселей экрана = ROOT_REF / grid точек). Уменьшаем один раз и честно
## (Lanczos), а не на лету по ближайшему соседу — иначе тело зернит. Край альфы
## делаем чётким (пиксель-арт без полупрозрачных краёв).
static func _fit(tex: Texture2D, key: String) -> Texture2D:
	var img := tex.get_image()
	var w := img.get_width()
	var h := img.get_height()
	var sum := 0.0
	var n := 0
	for y in range(int(ROW_FROM * float(h)), int(0.8 * float(h))):
		var cnt := 0
		for x in range(w):
			if img.get_pixel(x, y).a > 0.5:
				cnt += 1
		sum += float(cnt)
		n += 1
	var s := minf(ROOT_REF / float(grid) / maxf(sum / float(maxi(n, 1)), 1.0), 1.0)
	_cache[key + "/scale"] = s
	if s > 0.97:
		return tex
	img.fix_alpha_edges()
	img.resize(maxi(int(roundf(float(w) * s)), 4), maxi(int(roundf(float(h) * s)), 8), Image.INTERPOLATE_LANCZOS)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var p := img.get_pixel(x, y)
			p.a = 1.0 if p.a > 0.5 else 0.0
			img.set_pixel(x, y, p)
	return ImageTexture.create_from_image(img)


## Время эффекта: raw — секунды с начала выдержки. Первые ANTIC секунд — замах (щупальца
## ещё не вышли), потом движение; в момент удара время замирает на HIT_STOP секунд.
static func _warp(raw: float) -> float:
	var t := raw - ANTIC
	if t > IMPACT_T:
		t = IMPACT_T + maxf(0.0, t - IMPACT_T - HIT_STOP)
	return t


## Сила свечения вокруг карты: нарастает в замахе, вспыхивает на ударе и гаснет.
static func _glow_level(raw: float) -> float:
	if raw < ANTIC:
		var k := raw / ANTIC
		return 0.45 * k * k
	var t := _warp(raw)
	if t < IMPACT_T:
		return 0.45 + 0.2 * t / IMPACT_T
	return 0.35 + 0.65 * exp(-(t - IMPACT_T) * 4.0)


## Позади карты: ударные волны и те части щупалец, что под картой.
static func draw_behind(c: CanvasItem, cid: String, card: Rect2, raw: float) -> void:
	var t := _warp(raw)
	_draw_ring(c, cid, card, t, 0.0, 1.0, RING_GROW)
	_draw_ring(c, cid, card, t, IMPACT_T, 0.7, RING_GROW * 0.6)
	var i := 0
	for tent: Dictionary in FX[cid]["tentacles"]:
		_draw_tentacle(c, cid, i, tent, card, t, false)
		i += 1


## Поверх карты: части щупалец, что лежат на ней, брызги слизи, пылинки, светящиеся
## корни в замахе и белая вспышка удара.
static func draw_front(c: CanvasItem, cid: String, card: Rect2, raw: float) -> void:
	var t := _warp(raw)
	var i := 0
	for tent: Dictionary in FX[cid]["tentacles"]:
		_draw_tentacle(c, cid, i, tent, card, t, true)
		_draw_drops(c, cid, i, card, t)
		_draw_root_glow(c, cid, i, card, raw)
		i += 1
	if debug_isolate:
		return
	_draw_motes(c, cid, card, t)


## Белая вспышка на карте в момент удара (рисуется в полном разрешении, не на сетке
## эффекта: края карты должны остаться резкими).
static func draw_flash(c: CanvasItem, card: Rect2, raw: float) -> void:
	var kf := (raw - ANTIC - IMPACT_T) / FLASH_T
	if kf >= 0.0 and kf < 1.0:
		c.draw_rect(card, Color(1, 1, 1, FLASH_ALPHA * (1.0 - kf)))


## Холст эффекта: рисует его в SubViewport в grid раз меньше экрана (front — поверх карты,
## иначе позади) и растягивает без сглаживания. Состояние берёт у хозяина:
## host.fx_view() -> {cid, rect, t} (пусто, если эффект не идёт).
class Canvas extends Control:
	var host: Control
	var front := false
	var holder: SubViewportContainer

	func _init(layer: Control, source: Control, in_front: bool) -> void:
		host = source
		front = in_front
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		holder = SubViewportContainer.new()
		holder.stretch = true
		holder.stretch_shrink = CardFx.grid
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		holder.show_behind_parent = not in_front
		holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var port := SubViewport.new()
		port.transparent_bg = true
		port.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		holder.add_child(port)
		port.add_child(self)
		layer.add_child(holder)

	func _process(_delta: float) -> void:
		var v: Dictionary = host.call("fx_view")
		holder.visible = not v.is_empty()
		if holder.visible:
			queue_redraw()

	func _draw() -> void:
		var v: Dictionary = host.call("fx_view")
		if v.is_empty():
			return
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / float(CardFx.grid))
		if front:
			CardFx.draw_front(self, v["cid"], v["rect"], v["t"])
		else:
			CardFx.draw_behind(self, v["cid"], v["rect"], v["t"])


## На сколько пикселей вздрагивает карта: в замахе дрожит всё сильнее, на ударе — толчок
## вниз и затухающая тряска.
static func card_shift(cid: String, raw: float) -> Vector2:
	if not FX.has(cid):
		return Vector2.ZERO
	if raw < ANTIC:
		var k := raw / ANTIC
		return (Vector2(sin(raw * 90.0), cos(raw * 77.0)) * ANTIC_SHAKE * k).round()
	var dt := _warp(raw) - IMPACT_T
	if dt < 0.0:
		return Vector2.ZERO
	return (Vector2(sin(dt * 55.0), cos(dt * 47.0)) * IMPACT_SHAKE * exp(-dt * IMPACT_DECAY)).round()


## Ступенчатое свечение вокруг карты (слои-рамки, как «пиксельное» гало).
static func draw_glow(c: CanvasItem, cid: String, card: Rect2, raw: float) -> void:
	if debug_isolate:
		return
	var g := _glow_level(raw)
	var colour: Color = FX[cid]["tint"]
	for i in range(GLOW_LAYERS):
		colour.a = g * GLOW_ALPHA * (1.0 - float(i) / GLOW_LAYERS)
		c.draw_rect(card.grow(6.0 + 9.0 * float(i)), colour)


## Светящаяся точка у корня каждого щупальца: в замахе разгорается, на старте гаснет.
static func _draw_root_glow(c: CanvasItem, cid: String, index: int, card: Rect2, raw: float) -> void:
	if debug_isolate or raw > ANTIC + 0.25:
		return
	var sp := _spine_of(cid, index, card.size)
	var fpts: PackedVector2Array = sp["pts"]
	var p := (card.position + fpts[4] * card.size).round()
	var k := clampf(raw / ANTIC, 0.0, 1.0)
	var fade := 1.0 - clampf((raw - ANTIC) / 0.25, 0.0, 1.0)
	var colour: Color = (FX[cid]["tint"] as Color).lerp(Color.WHITE, 0.5)
	for s in [10.0, 6.0, 3.0]:
		colour.a = k * fade * (0.9 if s < 5.0 else 0.35)
		c.draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), colour)


## Пылинки: после удара разлетаются от краёв карты, тянутся вверх и гаснут.
static func _draw_motes(c: CanvasItem, cid: String, card: Rect2, t: float) -> void:
	var tau := t - IMPACT_T
	if tau <= 0.0 or tau >= MOTE_LIFE:
		return
	var colour: Color = (FX[cid]["tint"] as Color).lerp(Color.WHITE, 0.55)
	var rng := RandomNumberGenerator.new()
	var centre := card.get_center()
	var half := card.size * 0.5
	for k in range(MOTES):
		rng.seed = hash("%s/mote/%d" % [cid, k])
		var dir := Vector2.from_angle(rng.randf_range(0.0, TAU))
		var reach := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
		var start := centre + dir * reach
		var speed := rng.randf_range(25.0, 110.0)
		var pos := start + dir * speed * tau + Vector2(0, -MOTE_RISE * tau * tau)
		var life := 1.0 - tau / MOTE_LIFE
		# мерцание: часть пылинок гаснет раньше и вспыхивает
		colour.a = life * (0.55 + 0.45 * sin(tau * 30.0 + float(k)))
		var side := float(grid) * (2.0 if rng.randf() > 0.3 else 3.0)
		c.draw_rect(Rect2(pos.round(), Vector2(side, side)), colour)


static func _draw_ring(c: CanvasItem, cid: String, card: Rect2, t: float, at: float, alpha: float,
		grow: float) -> void:
	var k := (t - at) / RING_TIME
	if debug_isolate:
		return
	if k <= 0.0 or k >= 1.0:
		return
	var colour: Color = FX[cid]["tint"]
	colour.a = alpha * 0.7 * (1.0 - k)
	c.draw_rect(card.grow(roundf(grow * (1.0 - pow(1.0 - k, 3.0)))), colour, false, maxf(2.0, float(grid)))


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
		halves.append(maxf(profile * taper * (1.0 + pulse * sin(dist * 0.07 - t * 9.0 + phase)),
			maxf(MIN_HALF, 0.5 * float(grid))))
		# текстура привязана к ГОЛОВЕ: кольца едут вместе с ней (щупальце движется, а не
		# «открывается» из-под маски); по телу бегут волны сжатия, поэтому кольца
		# перетекают и когда щупальце уже дошло.
		var flow := RING_FLOW * sin(dist * 0.045 - t * 4.5 + phase)
		rows.append(dist * density + flow * density)
	var colours := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	# тень на карте и тёмная обводка: щупальце отделяется от синего арта
	var no_uv := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	for pass_i in range(2):
		var shade := Color(0.02, 0.03, 0.08, 0.4 if pass_i == 0 else 1.0)
		var shades := PackedColorArray([shade, shade, shade, shade])
		var shift := ((SHADOW / float(grid)).round() * float(grid)) if pass_i == 0 else Vector2.ZERO
		var outline := maxf(OUTLINE, float(grid))
		for j in range(count):
			if (head - float(j) * STEP >= split) != front:
				continue
			# у стыка слоёв (поверх карты начинается за краем) обводку и тень не рисуем:
			# иначе они ложатся серой полосой на конец заднего куска тела
			if front and head - float(j) * STEP < split + SEAM_SKIP:
				continue
			var m0 := normals[j] * (halves[j] + outline)
			var m1 := normals[j + 1] * (halves[j + 1] + outline)
			c.draw_primitive(PackedVector2Array([body[j] - m0 + shift, body[j] + m0 + shift,
				body[j + 1] + m1 + shift, body[j + 1] - m1 + shift]), shades, no_uv)
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
		var quad := PackedVector2Array([body[j] - n0, body[j] + n0, body[j + 1] + n1, body[j + 1] - n1])
		c.draw_primitive(quad, colours, PackedVector2Array([
			Vector2(lefts[i0] / w, r0 / h), Vector2(rights[i0] / w, r0 / h),
			Vector2(rights[i1] / w, r1 / h), Vector2(lefts[i1] / w, r1 / h)]), tex)
		# шов плитки: в начале каждого периода поверх накладывается настоящее продолжение
		# предыдущей плитки (строки спрайта на период ниже), затухая за SEAM_ROWS строк —
		# узор и яркость перетекают без ступеньки
		var phase_row := r0 - row_lo
		var seam_rows := SEAM_ROWS * float(bounds["scale"])
		if phase_row < seam_rows:
			var fade := Color(1, 1, 1, 1.0 - phase_row / seam_rows)
			var j0 := clampi(int(r0 + period), 0, lefts.size() - 1)
			var j1 := clampi(int(r1 + period), 0, lefts.size() - 1)
			c.draw_primitive(quad, PackedColorArray([fade, fade, fade, fade]), PackedVector2Array([
				Vector2(lefts[j0] / w, (r0 + period) / h), Vector2(rights[j0] / w, (r0 + period) / h),
				Vector2(rights[j1] / w, (r1 + period) / h), Vector2(lefts[j1] / w, (r1 + period) / h)]), tex)


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
	var sc := _scale(cid)
	var p_min := maxi(int(float(RING_P_MIN) * sc), 3)
	var p_max := maxi(int(float(RING_P_MAX) * sc), p_min + 2)
	var check := maxi(int(float(RING_CHECK) * sc), 8)
	var best_p := p_min
	var best_err := INF
	for p in range(p_min, p_max + 1):
		var err := 0.0
		for y in range(y0, y0 + check):
			for k in range(RING_SAMPLES):
				var u := (float(k) + 0.5) / RING_SAMPLES
				var a := img.get_pixel(int(lerpf(sl[y], sr[y], u)), y)
				var b := img.get_pixel(int(lerpf(sl[y + p], sr[y + p], u)), y + p)
				err += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
		# слабо предпочитаем короткий период (длинный лучше совпадает и выглядит живее)
		err *= 1.0 + 0.0005 / sc * float(p)
		if err < best_err:
			best_err = err
			best_p = p
	var total_w := 0.0
	for y in range(y0, y0 + best_p):
		total_w += sr[y] - sl[y]
	var res := {"left": sl, "right": sr, "mean": total_w / float(best_p), "y0": y0, "period": best_p,
		"scale": sc}
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
			var side := maxf(DROP_SIZE, 2.0 * float(grid))
			c.draw_rect(Rect2(pos.round(), Vector2(side, side)), colour)
