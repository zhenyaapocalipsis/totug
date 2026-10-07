class_name CardFx
extends RefCounted

## Эффекты розыгрыша уникальных карт (в колоде одна копия): когда такую карту
## играют, витрина (CardShowcase) показывает её крупно и рисует вокруг свой
## эффект. Спрайты лежат в assets/card_fx/<card_id>/, сценарии — в таблице FX.
##
## Ulitharid (решение владельца, 2026-10-07) — три фазы:
##   1. Карта сыграна: короткий замах, щупальца рывком вылезают из-за карты, удар
##      (остановка времени, вспышка), дальше они живут — шарят, дышат — пока игрок
##      выбирает карту рынка (витрина в это время не держит вопрос, см. waiting).
##   2. Карта выбрана: из-за правого края Ulitharid к ней тянется новое щупальце
##      (reach) и обвивает её.
##   3. Все щупальца рывком уходят назад по своим линиям, обвитая карта едет с
##      последним и затягивается под Ulitharid; дальше — обычный розыгрыш.
##
## Форма щупалец — линии движения с рисунка владельца (SKETCH_CARD — где на нём
## карта): прямые, сопряжённые дугами окружностей. Корень спрятан под картой; где
## линия возвращается на карту, щупальце идёт ПОВЕРХ неё. Тело — цепочка полосок
## спрайта вдоль линии; форма и узор принадлежат телу (отсчёт от головы), поэтому
## щупальце вытягивается, а не дорисовывается. Свет — в шейдере (card_fx_skin),
## от одного источника сверху-слева при любом изгибе.
## Решение владельца: внутри эффектов полоски спрайта можно поворачивать на любой
## угол (общее пиксельное правило 1:1 здесь снято).

const SPRITE_PATH := "res://assets/card_fx/%s/%s.png"
const SKIN_SHADER := preload("res://scenes/ui/card_fx_skin.gdshader")

## Постановка, секунды времени эффекта (fx_time: без замаха, с остановкой на ударе).
## Замах до выхода (карта дрожит, свечение, искры у корней), рывок щупалец, удар.
const ANTIC := 0.15
const ANTIC_SHAKE := 1.5
const LUNGE := 0.4
const IMPACT_T := LUNGE
const HIT_STOP := 0.07
const FLASH_T := 0.14
const FLASH_ALPHA := 0.8
## С какого момента можно выбирать карту рынка; сколько щупальца живут без выбора.
const WAIT_T := 0.85
const LIVE_MIN := 0.9
## Фаза 2: щупальце тянется к карте, обвивает её, сжимает; фаза 3 — рывок назад.
const REACH_T := 0.45
const WRAP_T := 0.4
const GRAB_T := 0.3
const RETRACT_T := 0.45
const END_PAD := 0.1
## Сколько ждать выбора карты рынка, прежде чем отпустить щупальца самим (страховка).
const WAIT_MAX := 30.0
## Свечение вокруг карты: слоёв и прозрачность слоя; пылинки после удара.
const GLOW_LAYERS := 6
const GLOW_ALPHA := 0.1
const MOTES := 30
const MOTE_LIFE := 1.0
const MOTE_RISE := 40.0
## Обводка тела (пиксели) и тень (смещение).
const OUTLINE := 1.5
const SHADOW := Vector2(3, 4)
## Ширина тела у корня самого толстого щупальца, к которой подгоняется спрайт.
const ROOT_REF := 30.0
## Шаг полосок тела.
const STEP := 3.0
## Отсчёты линии щупальца, вставки на звено, проходы сглаживания, отсчёты продолжения
## за концом (для перелёта).
const SPINE_N := 96
const SMOOTH_N := 8
const SMOOTH_PASSES := 60
const EXT_N := 14
## Золотое сечение (пропорция дуг и прямых линии движения), фильтр Таубина.
const PHI := 1.618034
const TAUBIN_LAMBDA := 0.5
const TAUBIN_MU := -0.53
## Линия движения: допуск упрощения рисунка и шаг выборки (пиксели рисунка).
const FILLET_TOL := 9.0
const FILLET_STEP := 8.0
## На сколько пикселей карты корень уходит под её край.
const LEAD_IN := 26.0
## Тряска карты на ударе.
const IMPACT_SHAKE := 2.5
const IMPACT_DECAY := 9.0
## Ударная волна: квадрат вокруг карты расширяется и гаснет.
const RING_TIME := 0.45
const RING_GROW := 50.0
## Волна при рывке (затухает), шевеление и «дыхание» длины после удара (пиксели).
const WHIP := 12.0
const WHIP_DECAY := 6.0
const IDLE := 5.0
const BREATH := 6.0
## Брызги слизи: сколько, сколько живут, сторона квадрата, ускорение вниз.
const DROPS := 9
const DROP_LIFE := 0.55
const DROP_SIZE := 3.0
const DROP_GRAVITY := 280.0
## На сколько пикселей щупальце должно выйти за край карты, чтобы дальше идти ПОВЕРХ неё.
const BEHIND_GAP := 14.0
## Рабочие строки спрайта: с ROW_FROM (доля высоты; выше запечён завиток) берётся один
## период колец (ищется сам, RING_P_*).
const ROW_FROM := 0.19
const RING_P_MIN := 14
const RING_P_MAX := 90
const RING_CHECK := 50
const RING_SAMPLES := 12
## Сколько строк спрайта перекрываются на шве плитки (примерно одно кольцо).
const SEAM_ROWS := 18.0
## Форма тела: к голове толщина падает до BODY_TAPER (по всей длине) и ещё — у самого
## кончика — до TAPER_END на длине ~TIP_TAPER пикселей. Кольца мельчают с толщиной, но
## не больше чем в RING_SQUEEZE раз.
const BODY_TAPER := 0.55
const TAPER_END := 0.12
const TIP_TAPER := 38.0
const RING_SQUEEZE := 3.5
## Минимальная полуширина тела (у острия тоньше пикселя рисуется пунктиром).
const MIN_HALF := 0.9
## Загиб кончика после прихода: на сколько пикселей, на какой длине, за сколько секунд.
const HOOK := 12.0
const HOOK_LEN := 70.0
const HOOK_TIME := 0.4
## Щупальце к карте рынка: выход за правый край, кольцо вокруг карты (зазор, сжатие к
## концу, сколько оборотов), насколько сжимает карту на захвате.
const REACH_OUT := 24.0
const COIL_GAP := 3.0
const COIL_SHRINK := 3.0
const COIL_TURNS := 1.15
const GRAB_SQUEEZE := 2.0
## Где на рисунке владельца лежит карта (x, y, ширина, высота).
const SKETCH_CARD := Rect2(320, 234, 410, 596)

## card_id -> сценарий. sprite — спрайт тела, tint — цвет волн и брызг, sound — звук
## (см. Sfx), tentacles — щупальца фазы 1:
##   path — линия движения с рисунка, от корня (на краю карты) к кончику;
##   width — толщина у корня, пиксели; ease — характер рывка (back / snap / out);
##   phase — сдвиг волн (у каждого своё шевеление).
## reach — щупальце фазы 2: from — корень (доли карты, под картой), width, phase.
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
				"width": 30.0, "ease": "back", "phase": 0.0},
			# короткое справа сверху: наружу и обратно на карту
			{"path": [Vector2(725, 283), Vector2(750, 292), Vector2(768, 310), Vector2(775, 330),
				Vector2(768, 352), Vector2(745, 378), Vector2(722, 402), Vector2(700, 420),
				Vector2(688, 440), Vector2(682, 460)],
				"width": 20.0, "ease": "snap", "phase": 2.1},
			# слева посередине: наружу налево, обратно через край и вниз по карте
			{"path": [Vector2(318, 486), Vector2(298, 505), Vector2(285, 530), Vector2(283, 555),
				Vector2(292, 580), Vector2(310, 603), Vector2(335, 620), Vector2(360, 635),
				Vector2(380, 655), Vector2(390, 685), Vector2(392, 712), Vector2(390, 744),
				Vector2(375, 762), Vector2(358, 782)],
				"width": 24.0, "ease": "out", "phase": 4.2},
			# длинное справа снизу: наружу, потом S-образно вниз-влево до низа экрана
			{"path": [Vector2(735, 637), Vector2(758, 647), Vector2(775, 665), Vector2(781, 700),
				Vector2(779, 738), Vector2(765, 775), Vector2(745, 800), Vector2(720, 815),
				Vector2(690, 825), Vector2(650, 845), Vector2(600, 875), Vector2(560, 895),
				Vector2(525, 918), Vector2(500, 945), Vector2(485, 975), Vector2(477, 1005),
				Vector2(475, 1040), Vector2(483, 1066)],
				"width": 28.0, "ease": "back", "phase": 3.3},
		],
		"reach": {"from": Vector2(0.5, 0.42), "width": 24.0, "phase": 1.3},
	},
}

static var _cache: Dictionary = {}
## Отладка (tests/ui_shot.gd --isolate): рисовать только щупальца на чёрном фоне.
static var debug_isolate := false
static var _spines: Dictionary = {}
## Сетка эффекта: эффект рисуется на холсте в grid раз меньше экрана и растягивается
## без сглаживания — все точки эффекта одного размера. 1 — сетка экрана игры.
static var grid := 1


static func has(cid: String) -> bool:
	return FX.has(cid)


static func sound(cid: String) -> String:
	return String(FX[cid]["sound"]) if FX.has(cid) else ""


## Пустое состояние постановки (хранит витрина): когда начать фазу 2 (reach_at, время
## эффекта), к какой карте (rect — в координатах витрины, cid) и когда отпустить без
## фазы 2 (release).
static func new_state() -> Dictionary:
	return {"reach_at": INF, "reach_rect": Rect2(), "reach_cid": "", "release": INF}


## Время эффекта по секундам выдержки raw: первые ANTIC секунд — замах, в момент удара
## время замирает на HIT_STOP секунд.
static func fx_time(raw: float) -> float:
	var t := raw - ANTIC
	if t > IMPACT_T:
		t = IMPACT_T + maxf(0.0, t - IMPACT_T - HIT_STOP)
	return t


## Когда щупальца уходят назад (время эффекта); INF — ещё ждём выбора карты.
static func _retract_at(cid: String, st: Dictionary) -> float:
	var reach_at := float(st.get("reach_at", INF))
	if reach_at < INF:
		return reach_at + REACH_T + WRAP_T + GRAB_T
	var release := float(st.get("release", INF))
	if not FX[cid].has("reach"):
		release = minf(release, 0.0)
	if release < INF:
		return maxf(release, IMPACT_T + LIVE_MIN)
	return INF


## Сколько секунд выдержки длится эффект (INF — пока не выбрана карта рынка).
static func hold_end(cid: String, st: Dictionary) -> float:
	var r := _retract_at(cid, st)
	if r == INF:
		return INF
	return r + RETRACT_T + END_PAD + ANTIC + HIT_STOP


## Эффект ждёт выбора карты рынка (щупальца вылезли, вопрос можно показывать).
static func waiting(cid: String, raw: float, st: Dictionary) -> bool:
	return FX.has(cid) and FX[cid].has("reach") and _retract_at(cid, st) == INF \
		and fx_time(raw) >= WAIT_T


## Спрайт тела карты cid (подогнан под сетку, свет снят).
static func _sprite(cid: String) -> Texture2D:
	var name := String(FX[cid]["sprite"])
	var key := "%s/%s/%d" % [cid, name, grid]
	if not _cache.has(key):
		_cache[key] = _fit(load(SPRITE_PATH % [cid, name]), key)
	return _cache[key]


## Во сколько раз спрайт уменьшен под сетку (1 — как есть).
static func _scale(cid: String) -> float:
	_sprite(cid)
	return float(_cache["%s/%s/%d/scale" % [cid, FX[cid]["sprite"], grid]])


## Спрайт, подогнанный под сетку: одна точка спрайта — одна точка сетки (ширина тела
## ROOT_REF пикселей экрана = ROOT_REF / grid точек). Уменьшаем один раз и честно
## (Lanczos); край альфы чёткий. Запечённый свет снимаем (_flatten): свет даёт шейдер.
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
	if s <= 0.97:
		img.fix_alpha_edges()
		img.resize(maxi(int(roundf(float(w) * s)), 4), maxi(int(roundf(float(h) * s)), 8),
			Image.INTERPOLATE_LANCZOS)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var p := img.get_pixel(x, y)
			p.a = 1.0 if p.a > 0.5 else 0.0
			img.set_pixel(x, y, p)
	_flatten(img)
	return ImageTexture.create_from_image(img)


## Снимает со спрайта запечённый свет (слева светло, справа темно): средняя яркость
## каждой доли поперёк тела выравнивается, рисунок колец остаётся.
static func _flatten(img: Image) -> void:
	const B := 10
	var w := img.get_width()
	var h := img.get_height()
	var spans: Array[Vector2i] = []
	for y in range(h):
		var lo := w
		var hi := 0
		for x in range(w):
			if img.get_pixel(x, y).a > 0.5:
				lo = mini(lo, x)
				hi = maxi(hi, x + 1)
		spans.append(Vector2i(lo, hi))
	var sums := PackedFloat32Array()
	var cnts := PackedFloat32Array()
	sums.resize(B)
	cnts.resize(B)
	for y in range(int(ROW_FROM * float(h)), int(0.8 * float(h))):
		var sp := spans[y]
		if sp.y - sp.x < 3:
			continue
		for x in range(sp.x, sp.y):
			var b := clampi(int((float(x - sp.x) + 0.5) / float(sp.y - sp.x) * B), 0, B - 1)
			sums[b] += img.get_pixel(x, y).get_luminance()
			cnts[b] += 1.0
	var mean := 0.0
	var used := 0.0
	for b in range(B):
		if cnts[b] > 0.0:
			sums[b] /= cnts[b]
			mean += sums[b]
			used += 1.0
	mean /= maxf(used, 1.0)
	for y in range(h):
		var sp := spans[y]
		if sp.y - sp.x < 2:
			continue
		for x in range(sp.x, sp.y):
			var p := img.get_pixel(x, y)
			if p.a <= 0.5:
				continue
			var u := (float(x - sp.x) + 0.5) / float(sp.y - sp.x) * B - 0.5
			var b0 := clampi(int(floorf(u)), 0, B - 1)
			var b1 := clampi(b0 + 1, 0, B - 1)
			var m := lerpf(sums[b0], sums[b1], clampf(u - floorf(u), 0.0, 1.0))
			var f := clampf(mean / maxf(m, 0.02), 0.6, 2.2)
			img.set_pixel(x, y, Color(minf(p.r * f, 1.0), minf(p.g * f, 1.0), minf(p.b * f, 1.0), p.a))


## Сила свечения вокруг карты: нарастает в замахе, вспыхивает на ударе и гаснет.
static func _glow_level(raw: float) -> float:
	if raw < ANTIC:
		var k := raw / ANTIC
		return 0.45 * k * k
	var t := fx_time(raw)
	if t < IMPACT_T:
		return 0.45 + 0.2 * t / IMPACT_T
	return 0.35 + 0.65 * exp(-(t - IMPACT_T) * 4.0)


## Позади карты: ударная волна, обвитая карта рынка и те части щупалец, что под картой.
static func draw_behind(c: CanvasItem, cid: String, card: Rect2, raw: float, st: Dictionary) -> void:
	var t := fx_time(raw)
	_draw_ring(c, cid, card, t, IMPACT_T, 0.8, RING_GROW)
	var reach: bool = FX[cid].has("reach")
	if reach:
		_draw_grabbed(c, cid, card, t, st)
	var i := 0
	for tent: Dictionary in FX[cid]["tentacles"]:
		_draw_tentacle(c, cid, i, tent, card, t, st, false)
		i += 1
	if reach:
		_draw_reach(c, cid, card, t, st, false)


## Поверх карты: части щупалец, что лежат на ней, брызги слизи, пылинки, светящиеся
## корни в замахе.
static func draw_front(c: CanvasItem, cid: String, card: Rect2, raw: float, st: Dictionary) -> void:
	var t := fx_time(raw)
	var i := 0
	for tent: Dictionary in FX[cid]["tentacles"]:
		_draw_tentacle(c, cid, i, tent, card, t, st, true)
		_draw_drops(c, cid, i, card, t)
		_draw_root_glow(c, cid, i, card, raw)
		i += 1
	if FX[cid].has("reach"):
		_draw_reach(c, cid, card, t, st, true)
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
## иначе позади) и растягивает без сглаживания; свет тела — шейдер card_fx_skin.
## Состояние берёт у хозяина: host.fx_view() -> {cid, rect, t, st} (пусто — эффекта нет).
class Canvas extends Control:
	var host: Control
	var front := false
	var holder: SubViewportContainer

	func _init(layer: Control, source: Control, in_front: bool) -> void:
		host = source
		front = in_front
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := ShaderMaterial.new()
		mat.shader = CardFx.SKIN_SHADER
		material = mat
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
		# сетку можно сменить на лету (F10 в игре)
		if holder.stretch_shrink != CardFx.grid:
			holder.stretch_shrink = CardFx.grid
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
			CardFx.draw_front(self, v["cid"], v["rect"], v["t"], v["st"])
		else:
			CardFx.draw_behind(self, v["cid"], v["rect"], v["t"], v["st"])


## На сколько пикселей вздрагивает карта: в замахе дрожит всё сильнее, на ударе — толчок
## и затухающая тряска.
static func card_shift(cid: String, raw: float) -> Vector2:
	if not FX.has(cid):
		return Vector2.ZERO
	if raw < ANTIC:
		var k := raw / ANTIC
		return (Vector2(sin(raw * 90.0), cos(raw * 77.0)) * ANTIC_SHAKE * k).round()
	var dt := fx_time(raw) - IMPACT_T
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
	if debug_isolate or raw > ANTIC + 0.2:
		return
	var sp := _spine_of(cid, index, card.size)
	var fpts: PackedVector2Array = sp["pts"]
	var p := (card.position + fpts[4] * card.size).round()
	var k := clampf(raw / ANTIC, 0.0, 1.0)
	var fade := 1.0 - clampf((raw - ANTIC) / 0.2, 0.0, 1.0)
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
	if debug_isolate or k <= 0.0 or k >= 1.0:
		return
	var colour: Color = FX[cid]["tint"]
	colour.a = alpha * 0.7 * (1.0 - k)
	c.draw_rect(card.grow(roundf(grow * (1.0 - pow(1.0 - k, 3.0)))), colour, false, maxf(2.0, float(grid)))


## Линия щупальца фазы 1 в долях карты, ровно по длине: линия движения с рисунка
## (_rounded), с заходом корня под край карты и прямым продолжением за концом — туда
## голова перелетает цель. Считается один раз на карту и размер. Возвращает {pts, seg
## (пиксели), split (длина от корня, с которой тело идёт поверх карты, INF — никогда),
## total (длина до цели)}.
static func _spine_of(cid: String, index: int, size: Vector2) -> Dictionary:
	var key := "%s/%d/%d" % [cid, index, int(size.x)]
	if _spines.has(key):
		return _spines[key]
	var tent: Dictionary = FX[cid]["tentacles"][index]
	var raw: Array[Vector2] = []
	for p: Vector2 in _rounded(tent["path"]):
		raw.append((p - SKETCH_CARD.position) / SKETCH_CARD.size)
	# заход корня под карту: назад от первого звена
	var back := (raw[0] - raw[1]).normalized()
	raw.insert(0, raw[0] + back * Vector2(LEAD_IN, LEAD_IN) / size)
	# Catmull-Rom и длина в пикселях
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
	var pts := PackedVector2Array()
	var j := 1
	for i in range(SPINE_N + 1):
		var a := seg * float(i)
		while j < dense.size() - 1 and cum[j] < a:
			j += 1
		var span := maxf(cum[j] - cum[j - 1], 0.0001)
		pts.append(dense[j - 1].lerp(dense[j], clampf((a - cum[j - 1]) / span, 0.0, 1.0)))
	# фильтр Таубина: сглаживает стыки прямых и дуг, кривизна меняется плавно
	pts = _taubin(pts, SMOOTH_PASSES)
	# продолжение за концом по последнему направлению
	var dir := ((pts[pts.size() - 1] - pts[pts.size() - 4]) * size).normalized()
	for i in range(1, EXT_N + 1):
		pts.append(pts[SPINE_N] + dir * seg * float(i) / size)
	# с какой длины тело идёт поверх карты: как только вышло за край на BEHIND_GAP
	var split := INF
	for i in range(SPINE_N + 1):
		var q := pts[i] * size
		var gap := Vector2(maxf(maxf(-q.x, q.x - size.x), 0.0), maxf(maxf(-q.y, q.y - size.y), 0.0)).length()
		if gap >= BEHIND_GAP:
			split = seg * float(i)
			break
	var res := {"pts": pts, "seg": seg, "split": split, "total": total}
	_spines[key] = res
	return res


static func _taubin(pts: PackedVector2Array, passes: int) -> PackedVector2Array:
	for _pass in range(passes):
		for f in [TAUBIN_LAMBDA, TAUBIN_MU]:
			var old := pts.duplicate()
			for i in range(1, pts.size() - 1):
				pts[i] = old[i] + ((old[i - 1] + old[i + 1]) * 0.5 - old[i]) * f
	return pts


## Упрощение ломаной (Дуглас — Пойкер): оставляет вершины, от которых рисунок отходит
## дальше tol пикселей.
static func _simplify(pts: Array, tol: float) -> Array[Vector2]:
	var keep := PackedByteArray()
	keep.resize(pts.size())
	keep[0] = 1
	keep[pts.size() - 1] = 1
	var stack: Array[Vector2i] = [Vector2i(0, pts.size() - 1)]
	while not stack.is_empty():
		var range_i: Vector2i = stack.pop_back()
		var a: Vector2 = pts[range_i.x]
		var b: Vector2 = pts[range_i.y]
		var far := -1
		var far_d := tol
		for i in range(range_i.x + 1, range_i.y):
			var p: Vector2 = pts[i]
			var d: float = (Geometry2D.get_closest_point_to_segment(p, a, b) - p).length()
			if d > far_d:
				far_d = d
				far = i
		if far >= 0:
			keep[far] = 1
			stack.append(Vector2i(range_i.x, far))
			stack.append(Vector2i(far, range_i.y))
	var res: Array[Vector2] = []
	for i in range(pts.size()):
		if keep[i] == 1:
			res.append(pts[i])
	return res


## Линия движения из ломаной: прямые, углы сопряжены дугами окружностей. Дуга забирает
## 1/PHI от свободной части прилегающей прямой (остальное остаётся прямым — дуги и
## прямые лежат в золотой пропорции). Точки через равные FILLET_STEP.
static func _rounded(path: Array) -> Array[Vector2]:
	var v := _simplify(path, FILLET_TOL)
	var out: Array[Vector2] = [v[0]]
	var used := 0.0
	for i in range(1, v.size() - 1):
		var d1 := (v[i] - v[i - 1]).normalized()
		var d2 := (v[i + 1] - v[i]).normalized()
		var turn := d1.angle_to(d2)
		var len_prev := v[i].distance_to(v[i - 1]) - used
		var len_next := v[i].distance_to(v[i + 1])
		# последнему углу резервировать нечего, остальным — половину следующей прямой
		var room := minf(len_prev, len_next * (1.0 if i == v.size() - 2 else 0.5))
		var tang := room / PHI
		if absf(turn) < 0.02 or tang < 2.0:
			out.append(v[i])
			used = 0.0
			continue
		var r := tang / tan(absf(turn) * 0.5)
		var side := d1.rotated(PI * 0.5) * signf(turn)
		var start := v[i] - d1 * tang
		out.append(start)
		var steps := maxi(int(absf(turn) / 0.1), 2)
		for k in range(1, steps + 1):
			var a := absf(turn) * float(k) / float(steps)
			out.append(start + (d1 * sin(a) + side * (1.0 - cos(a))) * r)
		used = tang
	out.append(v[v.size() - 1])
	var res: Array[Vector2] = []
	for p in _resample(PackedVector2Array(out), FILLET_STEP):
		res.append(p)
	return res


## Точки ломаной через равные шаги по длине (первая и последняя — на месте).
static func _resample(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	var res := PackedVector2Array([pts[0]])
	var next := step
	var acc := 0.0
	for i in range(1, pts.size()):
		var seg_len := pts[i].distance_to(pts[i - 1])
		while seg_len > 0.0 and next <= acc + seg_len:
			res.append(pts[i - 1].lerp(pts[i], (next - acc) / seg_len))
			next += step
		acc += seg_len
	if res[res.size() - 1].distance_to(pts[pts.size() - 1]) > 0.01:
		res.append(pts[pts.size() - 1])
	return res


static func _ease(kind: String, x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	match kind:
		"in":
			return x * x
		"inout":
			return x * x * (3.0 - 2.0 * x)
		"snap":
			return 1.0 - pow(1.0 - x, 5.0)
	return 1.0 - pow(1.0 - x, 3.0)


## Как _ease, но «back» не обрезается сверху: перелёт (до ~10%) — значения больше 1.
static func _ease_unclamped(kind: String, x: float) -> float:
	if kind == "back":
		x = clampf(x, 0.0, 1.0)
		return 1.0 + 2.70158 * pow(x - 1.0, 3.0) + 1.70158 * pow(x - 1.0, 2.0)
	return _ease(kind, x)


## Щупальце фазы 1: рывок из-за карты (у каждого свой характер, финиш общий), потом
## шевеление и «дыхание», на фазе 3 — назад по той же линии.
static func _draw_tentacle(c: CanvasItem, cid: String, index: int, tent: Dictionary, card: Rect2,
		t: float, st: Dictionary, front: bool) -> void:
	var sp := _spine_of(cid, index, card.size)
	var seg := float(sp["seg"])
	var total := float(sp["total"])
	var split := float(sp["split"])
	var phase := float(tent["phase"])
	var out := _ease_unclamped(String(tent["ease"]), t / LUNGE)
	var gone := _ease("inout", (t - _retract_at(cid, st)) / RETRACT_T)
	var live := smoothstep(0.0, 1.0, (t - LUNGE) / 0.4)
	var breath := BREATH * sin(t * 1.8 + phase) * live
	var head := clampf((total * out + breath) * (1.0 - gone), 0.0, seg * float(SPINE_N + EXT_N - 1))
	var count := int(head / STEP)
	if count < 2:
		return
	var fpts: PackedVector2Array = sp["pts"]
	# волна по телу: на рывке сильная и быстро гаснет, потом каждое щупальце шевелится
	# в своём темпе; корень стоит на месте
	var amp := (WHIP * exp(-WHIP_DECAY * maxf(t, 0.0)) + IDLE * live) \
		* (1.0 - gone) * smoothstep(0.0, 1.0, head / 140.0)
	var speed := 2.2 + 0.3 * phase
	var pts := PackedVector2Array()
	for i in range(fpts.size()):
		var p := card.position + fpts[i] * card.size
		var prev := card.position + fpts[maxi(i - 1, 0)] * card.size
		var next := card.position + fpts[mini(i + 1, fpts.size() - 1)] * card.size
		var u := float(i) / SPINE_N
		var off := amp * sin(u * 5.0 - t * speed + phase) * smoothstep(0.0, 0.4, u)
		pts.append(p + (next - prev).orthogonal().normalized() * off)
	# точки тела от кончика к корню (Catmull-Rom: без изломов между отсчётами)
	var body := PackedVector2Array()
	for j in range(count + 1):
		var k := minf(maxf(head - float(j) * STEP, 0.0) / seg, float(fpts.size()) - 1.001)
		var i0 := int(k)
		body.append(pts[i0].cubic_interpolate(pts[i0 + 1], pts[maxi(i0 - 1, 0)],
			pts[mini(i0 + 2, pts.size() - 1)], k - float(i0)))
	# загиб кончика: появляется после прихода
	var hook := HOOK * smoothstep(0.0, 1.0, (t - LUNGE * 0.85) / HOOK_TIME) \
		* (1.0 - gone) * (1.0 if sin(phase) >= 0.0 else -1.0)
	if absf(hook) > 0.01:
		var bent := body.duplicate()
		for j in range(mini(int(HOOK_LEN / STEP) + 1, count + 1)):
			var nrm := (body[mini(j + 1, count)] - body[maxi(j - 1, 0)]).orthogonal().normalized()
			bent[j] = body[j] + nrm * hook * pow(1.0 - float(j) * STEP / HOOK_LEN, 2.0)
		body = bent
	# полоска j поверх карты, если она дальше split от корня
	var mask := PackedByteArray()
	mask.resize(count)
	for j in range(count):
		mask[j] = 1 if head - float(j) * STEP >= split else 0
	_draw_body(c, cid, body, float(tent["width"]), total, mask, front)


## Линия щупальца фазы 2 (пиксели витрины): из-под середины карты вправо, за край,
## дугой к левому краю выбранной карты рынка, снизу вверх — и кольцом вокруг карты.
## Возвращает {line, coil, anchor}: line — до точки захвата, coil — кольцо от неё.
static func _reach_geom(cid: String, card: Rect2, st: Dictionary, tight: float) -> Dictionary:
	var rd: Dictionary = FX[cid]["reach"]
	var r: Rect2 = st["reach_rect"]
	var root := card.position + (rd["from"] as Vector2) * card.size
	var centre := r.get_center()
	var a0 := r.size.x * 0.5 + COIL_GAP
	var anchor := Vector2(centre.x - a0, centre.y)
	var exit := Vector2(card.end.x + REACH_OUT, root.y)
	# к точке захвата — снизу вверх, чтобы линия плавно перешла в кольцо
	var below := anchor + Vector2(0, maxf(r.size.y * 0.5, 24.0))
	# между ними — дуга вверх, а не прямая палка
	var mid := (exit + below) * 0.5 + Vector2(0, -0.22 * exit.distance_to(below))
	var line := _resample(PackedVector2Array(_rounded([root, exit, mid, below, anchor])), 2.0)
	line = _taubin(line, 40)
	var coil := PackedVector2Array()
	var steps := 120
	for k in range(steps + 1):
		var f := float(k) / steps
		# от левого края по часовой (на экране y вниз): вверх, вправо, вниз, влево
		var ang := PI + f * COIL_TURNS * TAU
		var shrink := COIL_SHRINK * f + tight
		var a := a0 - shrink
		var b := r.size.y * 0.5 + COIL_GAP - shrink
		var cs := cos(ang)
		var sn := sin(ang)
		# суперэллипс: прямоугольник со скруглёнными углами
		coil.append(centre + Vector2(a * signf(cs) * sqrt(absf(cs)), b * signf(sn) * sqrt(absf(sn))))
	coil = _resample(coil, 2.0)
	return {"line": line, "coil": coil, "anchor": anchor}


## Длина ломаной.
static func _length(pts: PackedVector2Array) -> float:
	var s := 0.0
	for i in range(1, pts.size()):
		s += pts[i].distance_to(pts[i - 1])
	return s


## Точка ломаной на длине a от начала.
static func _point_at(pts: PackedVector2Array, a: float) -> Vector2:
	var acc := 0.0
	for i in range(1, pts.size()):
		var l := pts[i].distance_to(pts[i - 1])
		if acc + l >= a:
			return pts[i - 1].lerp(pts[i], clampf((a - acc) / maxf(l, 0.0001), 0.0, 1.0))
		acc += l
	return pts[pts.size() - 1]


## Фазы 2–3 для щупальца к карте рынка: где сейчас его линия (с учётом того, что на
## фазе 3 кольцо с картой едет назад по линии) и голова. {} — щупальца ещё нет.
static func _reach_now(cid: String, card: Rect2, t: float, st: Dictionary) -> Dictionary:
	var reach_at := float(st.get("reach_at", INF))
	if reach_at == INF or t < reach_at or (st["reach_rect"] as Rect2).size.x < 1.0:
		return {}
	var tr := t - reach_at
	var grab_k := smoothstep(0.0, 1.0, (tr - REACH_T - WRAP_T) / GRAB_T)
	var geom := _reach_geom(cid, card, st, GRAB_SQUEEZE * grab_k)
	var line: PackedVector2Array = geom["line"]
	var coil: PackedVector2Array = geom["coil"]
	var line_len := _length(line)
	var coil_len := _length(coil)
	var gone := _ease("inout", (t - _retract_at(cid, st)) / RETRACT_T)
	var shift := Vector2.ZERO
	var path := PackedVector2Array()
	var head := 0.0
	if gone <= 0.0:
		path = line.duplicate()
		path.append_array(coil.slice(1))
		head = line_len * _ease("out", tr / REACH_T) + coil_len * _ease("inout", (tr - REACH_T) / WRAP_T)
	else:
		# кольцо с картой едет назад по линии; тело, что было на линии, уходит под карту
		var keep := line_len * (1.0 - gone)
		var cut := PackedVector2Array([line[0]])
		var acc := 0.0
		for i in range(1, line.size()):
			var l := line[i].distance_to(line[i - 1])
			if acc + l > keep:
				break
			acc += l
			cut.append(line[i])
		var end := _point_at(line, keep)
		cut.append(end)
		shift = end - (geom["anchor"] as Vector2)
		path = cut
		for k in range(1, coil.size()):
			path.append(coil[k] + shift)
		head = _length(path)
	return {"path": path, "head": head, "total": line_len + coil_len, "shift": shift,
		"grab": grab_k, "gone": gone}


## Щупальце к карте рынка: тело по текущей линии; позади карты — то, что внутри неё.
static func _draw_reach(c: CanvasItem, cid: String, card: Rect2, t: float, st: Dictionary,
		front: bool) -> void:
	var now := _reach_now(cid, card, t, st)
	if now.is_empty():
		return
	var path: PackedVector2Array = now["path"]
	var head := float(now["head"])
	var count := int(head / STEP)
	if count < 2:
		return
	var body := PackedVector2Array()
	for j in range(count + 1):
		body.append(_point_at(path, maxf(head - float(j) * STEP, 0.0)))
	var inside := card.grow(BEHIND_GAP)
	var mask := PackedByteArray()
	mask.resize(count)
	for j in range(count):
		mask[j] = 0 if inside.has_point((body[j] + body[j + 1]) * 0.5) else 1
	_draw_body(c, cid, body, float(FX[cid]["reach"]["width"]), float(now["total"]), mask, front)
	# брызги на захвате
	if front:
		var r: Rect2 = st["reach_rect"]
		_burst(c, cid, "grab", Vector2(r.position.x, r.get_center().y), t,
			float(st["reach_at"]) + REACH_T + WRAP_T)


## Обвитая карта рынка: лежит на своём месте (под ней на рынке уже следующая), на захвате
## дрожит, на фазе 3 едет с кольцом и уходит под Ulitharid.
static func _draw_grabbed(c: CanvasItem, cid: String, card: Rect2, t: float, st: Dictionary) -> void:
	var now := _reach_now(cid, card, t, st)
	if now.is_empty() or String(st["reach_cid"]) == "":
		return
	var tex := CardView.mini_texture(String(st["reach_cid"]))
	if tex == null:
		return
	var r: Rect2 = st["reach_rect"]
	var jitter := Vector2.ZERO
	var grab := float(now["grab"])
	if grab > 0.0 and grab < 1.0:
		jitter = Vector2(sin(t * 70.0), cos(t * 63.0)) * 1.2
	c.draw_texture_rect(tex, Rect2((r.position + (now["shift"] as Vector2) + jitter).round(), r.size), false)


## Тело щупальца по точкам body (от головы к корню): тень, обводка и кожа. Полоска j
## рисуется в этом слое, если mask[j] (1 — поверх карты) совпадает с front.
static func _draw_body(c: CanvasItem, cid: String, body: PackedVector2Array, root_w: float,
		total: float, mask: PackedByteArray, front: bool) -> void:
	var count := body.size() - 1
	if count < 2:
		return
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
	# строк спрайта на пиксель длины у корня; к голове кольца мельчают вместе с толщиной
	var density := float(bounds["mean"]) / root_w
	var normals := PackedVector2Array()
	var halves := PackedFloat32Array()
	var rows := PackedFloat32Array()
	var row := 0.0
	var prev_k := 0.0
	for j in range(count + 1):
		normals.append((body[mini(j + 1, count)] - body[maxi(j - 1, 0)]).orthogonal().normalized())
		var dist := float(j) * STEP
		# форма принадлежит телу (отсчёт от головы): толстое почти сразу за кончиком
		var k := (BODY_TAPER + (1.0 - BODY_TAPER) * clampf(dist / total, 0.0, 1.0)) \
			* (TAPER_END + (1.0 - TAPER_END) * (1.0 - exp(-dist / TIP_TAPER)))
		if j > 0:
			row += STEP * density * minf(2.0 / (k + prev_k), RING_SQUEEZE)
		prev_k = k
		rows.append(row)
		# острие — точка; дальше не тоньше MIN_HALF (тоньше рисуется пунктиром)
		var floor_half := maxf(MIN_HALF, 0.5 * float(grid)) * minf(float(j) / 3.0, 1.0)
		halves.append(0.0 if j == 0 else maxf(root_w * 0.5 * k, floor_half))
	# тень и тёмная обводка: щупальце отделяется от синего арта
	var no_uv := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	var outline := maxf(OUTLINE, float(grid))
	for pass_i in range(2):
		var shade := Color(0.02, 0.03, 0.08, 0.4 if pass_i == 0 else 1.0)
		var shades := PackedColorArray([shade, shade, shade, shade])
		var shift := ((SHADOW / float(grid)).round() * float(grid)) if pass_i == 0 else Vector2.ZERO
		for j in range(count):
			if (mask[j] == 1) != front:
				continue
			# у стыка слоёв обводку и тень поверх не рисуем: иначе они ложатся полосой на
			# конец заднего куска тела
			if front and _near_seam(mask, j):
				continue
			var m0 := normals[j] * (halves[j] + outline * minf(float(j) / 3.0, 1.0))
			var m1 := normals[j + 1] * (halves[j + 1] + outline * minf(float(j + 1) / 3.0, 1.0))
			c.draw_primitive(PackedVector2Array([body[j] - m0 + shift, body[j] + m0 + shift,
				body[j + 1] + m1 + shift, body[j + 1] - m1 + shift]), shades, no_uv)
	var lit := not debug_isolate
	for j in range(count):
		if (mask[j] == 1) != front:
			continue
		# внутри полоски строки идут непрерывно: переход через конец периода — только
		# между полосками; узор в конце периода совпадает с началом
		var r0 := row_lo + fposmod(rows[j], period)
		var r1 := r0 + (rows[j + 1] - rows[j])
		var i0 := clampi(int(r0), 0, lefts.size() - 1)
		var i1 := clampi(int(r1), 0, lefts.size() - 1)
		var n0 := normals[j] * halves[j]
		var n1 := normals[j + 1] * halves[j + 1]
		# draw_primitive, а не draw_polygon: тот отказывается рисовать «скрученный» кусок
		var quad := PackedVector2Array([body[j] - n0, body[j] + n0, body[j + 1] + n1, body[j + 1] - n1])
		c.draw_primitive(quad, _skin_colours(normals[j], normals[j + 1], 1.0, lit), PackedVector2Array([
			Vector2(lefts[i0] / w, r0 / h), Vector2(rights[i0] / w, r0 / h),
			Vector2(rights[i1] / w, r1 / h), Vector2(lefts[i1] / w, r1 / h)]), tex)
		# шов плитки: в начале периода поверх — настоящее продолжение предыдущей плитки
		var phase_row := r0 - row_lo
		var seam_rows := SEAM_ROWS * float(bounds["scale"])
		if phase_row < seam_rows:
			var j0 := clampi(int(r0 + period), 0, lefts.size() - 1)
			var j1 := clampi(int(r1 + period), 0, lefts.size() - 1)
			c.draw_primitive(quad, _skin_colours(normals[j], normals[j + 1], 1.0 - phase_row / seam_rows, lit),
				PackedVector2Array([
				Vector2(lefts[j0] / w, (r0 + period) / h), Vector2(rights[j0] / w, (r0 + period) / h),
				Vector2(rights[j1] / w, (r1 + period) / h), Vector2(lefts[j1] / w, (r1 + period) / h)]), tex)


## Полоска j поверх карты рядом (3 полоски) со стыком с задним слоем.
static func _near_seam(mask: PackedByteArray, j: int) -> bool:
	for i in range(maxi(j - 3, 0), mini(j + 4, mask.size())):
		if mask[i] != 1:
			return true
	return false


## Вершинные цвета полоски кожи для шейдера света: сторона поперёк тела и нормаль (см.
## card_fx_skin.gdshader); без света — просто белый с прозрачностью.
static func _skin_colours(n0: Vector2, n1: Vector2, alpha: float, lit: bool) -> PackedColorArray:
	if not lit:
		var white := Color(1, 1, 1, alpha)
		return PackedColorArray([white, white, white, white])
	return PackedColorArray([
		Color(0.0, n0.x * 0.5 + 0.5, n0.y * 0.5 + 0.5, alpha),
		Color(1.0, n0.x * 0.5 + 0.5, n0.y * 0.5 + 0.5, alpha),
		Color(1.0, n1.x * 0.5 + 0.5, n1.y * 0.5 + 0.5, alpha),
		Color(0.0, n1.x * 0.5 + 0.5, n1.y * 0.5 + 0.5, alpha)])


## Границы тела спрайта по строкам (левая и правая, в пикселях), начало и период колец
## и средняя ширина тела на этом периоде. Считается один раз.
static func _bounds(cid: String) -> Dictionary:
	var key := "bounds/%s/%d" % [cid, grid]
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
	# период колец: на сколько строк отступить, чтобы узор тела (в долях ширины) совпал
	# сам с собой — кусок повторяется встык без зеркала
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


## Брызги слизи из головы щупальца в момент удара.
static func _draw_drops(c: CanvasItem, cid: String, index: int, card: Rect2, t: float) -> void:
	var sp := _spine_of(cid, index, card.size)
	var fpts: PackedVector2Array = sp["pts"]
	_burst(c, cid, "drops/%d" % index, card.position + fpts[SPINE_N] * card.size, t, IMPACT_T)


## Россыпь капель из точки origin в момент at: каждая летит по своей дуге и падает;
## разброс детерминирован (одинаков у всех игроков).
static func _burst(c: CanvasItem, cid: String, key: String, origin: Vector2, t: float, at: float) -> void:
	var tau := t - at
	if tau <= 0.0 or tau >= DROP_LIFE:
		return
	var colour: Color = (FX[cid]["tint"] as Color).lerp(Color.WHITE, 0.35)
	colour.a = 1.0 - tau / DROP_LIFE
	var side := maxf(DROP_SIZE, 2.0 * float(grid))
	var rng := RandomNumberGenerator.new()
	for k in range(DROPS):
		rng.seed = hash("%s/%s/%d" % [cid, key, k])
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(70.0, 170.0)
		var pos := origin + Vector2.from_angle(angle) * speed * tau + Vector2(0, DROP_GRAVITY * tau * tau * 0.5)
		c.draw_rect(Rect2(pos.round(), Vector2(side, side)), colour)
