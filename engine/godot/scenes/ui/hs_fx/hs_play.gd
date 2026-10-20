class_name HsPlay
extends Control

## Розыгрыш карты как в Hearthstone (решения владельца 2026-10-19/20): без витрины и
## без затемнения; нажатую карту рука прячет сразу, и идёт эффект Hearthstone, затем в
## центре доски на секунду проявляется миниатюра карты и гаснет — и только потом игра
## показывает действия карты (released).
##
## Эффект — запечённые кадры (assets/hs_fx/baked/<имя>/): Unity рисует оригинальные
## префабы Hearthstone из файлов игры его же шейдерами, частицами и Timeline, с камеры
## доски HS, и пишет кадры 960x540 с premultiplied-альфой (hs_unity, HsRender; рецепт —
## hs_unity/recipes/<имя>.json). Дорожка f### рисуется над картой, u### — под ней
## (подложка и горящий контур появления карты). Текстуры HS под его макет (рамка карты,
## портрет героя) при запекании заменены своими.

## Акт появления закончился, карта погасла: можно показывать действия и вопросы.
signal released
## Сдвиг «камеры» (тряска камеры Hearthstone) в пикселях экрана: доска сдвигается так же,
## как кадры эффекта (BoardPanel.camera_offset). В конце розыгрыша — ноль.
signal camera_offset(offset: Vector2)

const BAKED := "res://assets/hs_fx/baked/"
## Сколько кадров вперёд подгружать в фоне (кадры идут 60 в секунду, WebP распаковывается
## несколько миллисекунд).
const AHEAD := 12
## Сколько первых кадров должно быть готово до старта часов эффекта.
const WARM := 8

## Карта -> сценарий.
const RECIPES := {"48426": "worldbreaker"}
## Сценарий: len — длина (с); frames — папка запечённых кадров; card — появление
## карты в своём размере: face (full — полноформатная, mini — миниатюра; горящий контур
## в кадрах запечён под неё), reveal (секунда), sweep (проявляется снизу вверх), hold
## (стоит), out (гаснет), center (центр на экране 960x540 — центр квада Quad_CardGlow);
## cues — звуки [секунда, файл в папке сценария, громкость 0..1]; loop — звук-петля
## [файл, старт, появление, стоп, затухание, громкость]; shakers — тряска камеры HS (дорожка
## CameraShaker2 в Timeline спелла): [с, по, амплитуда (единицы мира HS), кривая силы
## [[доля клипа, сила], ...], интервал смены точки, с].
const SCRIPTS := {
	# Deathwing, Worldbreaker (CATA_190h): CATAFX_Deathwing_CustomSummon_Spell (тень
	# дракона с огненным шлейфом проносится над доской, пике в центр доски (1.13 с),
	# огненная волна, вспышка, дым, угли) и сразу за ударом CATAFX_Deathwing_Choice_Reveal
	# (одна карта вместо четырёх, с 1.15 с; сама карта — через 0.45 с, WaitToShowCards).
	"worldbreaker": {"len": 4.6, "frames": "worldbreaker",
		"card": {"face": "mini", "reveal": 1.6, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# громкости — AudioSource префабов HS; стингер — m_PlayEffectDef карты; дымка
		# YoggFogg (эффект розыгрыша, с 0.1 с): петля с появлением 0.5 с, уход в 2.6 с
		# (анимация End, частицы гаснут, петля затухает 1.5 с, звук ухода — 0.3)
		"cues": [[0.0, "CATA_190h_DeathwingWorldbreaker_Stinger", 0.5],
			[0.0, "CATA_190h_Enter_01", 0.7], [0.0, "CATA_190h_Enter_Dragon_01", 0.7], [0.85, "CATA_190h_Enter_02", 0.7],
			[1.0, "CATA_190h_Enter_Dragon_02", 0.7], [1.15, "CATA_190h_CardReveal_01", 0.8],
			[2.6, "CATA_190h_YoggFogg_End", 0.3]],
		"loop": ["CATA_190h_YoggFogg_Loop", 0.1, 0.5, 2.6, 1.5, 0.8],
		"shakers": [[0.0, 1.133, 0.08, [[0.0, 0.5], [0.3, 0.99], [0.51, 0.23], [1.0, 0.0]], 0.075],
			[1.133, 2.533, 0.12, [[0.0, 0.5], [0.1, 0.99], [0.21, 0.98], [0.67, 0.15], [1.0, 0.0]], 0.075]]},
}

## Пикселей экрана 960x540 на единицу мира HS на уровне доски (камера доски HS: высота
## 19.6, вертикальный угол обзора 34.87).
const PX_PER_UNIT := 44.1

## Для снимков: шаг времени за кадр (0 — настоящее время).
static var fixed_dt := 0.0

var board_area: Control
var _queue: Array[Dictionary] = []
var _item: Dictionary = {}
var _script: Dictionary = {}
var _meta: Dictionary = {}
var _under: Dictionary = {}
var _t := 0.0
var _released := false
var _cue_t := -1.0
var _shown_frame := -1
var _cache: Dictionary = {}
## Сколько первых кадров ещё ждём перед стартом (0 — эффект идёт) и сколько уже запрошено.
var _warm := 0
var _warm_asked := 0
## Тряска камеры: для каждой дорожки shakers — 30 точек на эллипсе амплитуды.
var _shake_points: Array = []

## Звук-петля сценария (loop).
var _loop := AudioStreamPlayer.new()

var _under_layer := _FrameLayer.new()
var _card := _CardLayer.new()
var _over_layer := _FrameLayer.new()


static func has(cid: String) -> bool:
	return RECIPES.has(cid)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: Control in [_under_layer, _card, _over_layer]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(c)
	_loop.bus = Sfx.BUS
	add_child(_loop)
	visible = false
	set_process(false)


## Разыграть карту cid: face — её миниатюра, quiet — чужая (тише).
func play(cid: String, face: Texture2D, quiet: bool = false) -> void:
	if not has(cid):
		return
	_queue.append({"cid": cid, "face": face, "quiet": quiet})
	if _item.is_empty():
		_next()


## Идёт ли розыгрыш, который ещё держит действия карты.
func is_busy() -> bool:
	return not _item.is_empty() and not _released


## Готов ли розыгрыш (для снимков и превью).
func is_ready() -> bool:
	return not _item.is_empty()


func _next() -> void:
	_item = {}
	_cache.clear()
	_under_layer.show_frame(null)
	_over_layer.show_frame(null)
	_card.show_card(null, Rect2(), 0.0, 1.0)
	_set_camera(Vector2.ZERO)
	_loop.stop()
	visible = false
	set_process(false)
	if _queue.is_empty():
		return
	_item = _queue.pop_front()
	_script = SCRIPTS[RECIPES[_item["cid"]]]
	var dir := BAKED + String(_script["frames"]) + "/"
	_meta = JSON.parse_string(FileAccess.get_file_as_string(dir + "meta.json"))
	_under = {}
	for i in _meta.get("under", []):
		_under[int(i)] = true
	_t = 0.0
	_released = false
	_cue_t = -1.0
	_shown_frame = -1
	_shake_points = []
	for sh: Array in _script.get("shakers", []):
		_shake_points.append(_shake_path(float(sh[2])))
	# часы эффекта идут, когда первые кадры уже распакованы (WebP) — иначе первые
	# кадры ждут загрузки и дёргаются
	_warm = mini(WARM, int(_meta["frames"]))
	_warm_asked = 0
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	# Godot сам включает _process при входе в дерево — без розыгрыша выключаем
	if _item.is_empty():
		set_process(false)
		return
	if _warm > 0:
		# по два кадра за кадр игры: готовые кадры уходят в видеокарту понемногу
		for k in range(_warm_asked, mini(_warm_asked + 2, _warm)):
			_request("f", k)
		_warm_asked = mini(_warm_asked + 2, _warm)
		for k in _warm:
			if k >= _warm_asked or ResourceLoader.load_threaded_get_status(_path("f", k)) != ResourceLoader.THREAD_LOAD_LOADED:
				return
		_warm = 0
		_frame()
		return
	_t += fixed_dt if fixed_dt > 0.0 else delta
	var cs: Dictionary = _script["card"]
	if not _released and _t >= float(cs["reveal"]) + float(cs["sweep"]) + float(cs["hold"]) + float(cs["out"]):
		_released = true
		released.emit()
	if _t >= float(_script["len"]):
		_next()
		return
	_cues(_t)
	_set_camera(_shake_offset(_t))
	_frame()


## Кадр в момент t (секунды от начала розыгрыша), без звуков — для снимков.
func debug_seek(t: float) -> void:
	_t = t
	_frame()


## Звуки сценария — каждый, когда время его проходит; петля — с появлением и затуханием.
func _cues(t: float) -> void:
	var dir := "res://assets/hs_fx/%s/" % _script["frames"]
	for c: Array in _script["cues"]:
		if _cue_t < float(c[0]) and t >= float(c[0]):
			var vol := float(c[2]) if c.size() > 2 else 1.0
			Sfx.play_file(dir + String(c[1]) + ".wav", bool(_item["quiet"]), linear_to_db(vol))
	var lp: Array = _script.get("loop", [])
	if not lp.is_empty():
		if _cue_t < float(lp[1]) and t >= float(lp[1]) and Sfx.volume > 0.0:
			_loop.stream = load(dir + String(lp[0]) + ".wav")
			_loop.play()
		var k := clampf((t - float(lp[1])) / float(lp[2]), 0.0, 1.0) \
			* (1.0 - clampf((t - float(lp[3])) / float(lp[4]), 0.0, 1.0))
		_loop.volume_db = linear_to_db(maxf(k * float(lp[5]), 0.0001)) + (Sfx.OTHER_DB if bool(_item["quiet"]) else 0.0)
	_cue_t = t


## Точки тряски, как ShakerHelper.Initialize в Hearthstone: 30 направлений, каждое
## следующее повёрнуто на 100..260 градусов от прежнего (камеру бросает туда-обратно),
## точка — на эллипсе амплитуды.
static func _shake_path(amount: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var a := randf_range(0.0, 6.283)
	for i in 30:
		if i > 0:
			a = randf_range(a + 1.745, a + 4.538)
		pts.append(Vector2(cos(a), sin(a)) * amount)
	return pts


## Сдвиг камеры в момент t, как ShakerHelper.UpdateTarget: доля клипа -> номер точки
## (каждые interval секунд — следующая), переход между точками с двойным косинусным
## сглаживанием, умножение на кривую силы. В мире HS вверх экрана — +z, сдвиг камеры
## вверх двигает картинку вниз.
func _shake_offset(t: float) -> Vector2:
	var off := Vector2.ZERO
	var shakers: Array = _script.get("shakers", [])
	for k in shakers.size():
		var sh: Array = shakers[k]
		var t0 := float(sh[0])
		var t1 := float(sh[1])
		if t < t0 or t >= t1:
			continue
		var u := (t - t0) / (t1 - t0)
		var steps := (t1 - t0) / float(sh[4])
		var s := u * steps
		var i := floori(s)
		var w := 1.0 - (0.5 + 0.5 * cos((s - i) * PI))
		w = 1.0 - (0.5 + 0.5 * cos(w * PI))
		var pts: PackedVector2Array = _shake_points[k]
		var p := pts[i % pts.size()].lerp(pts[(i + 1) % pts.size()], w) * _curve(sh[3], u)
		off += Vector2(-p.x, p.y)
	return off * PX_PER_UNIT * size.y / 540.0


## Кривая силы HS [[доля, сила], ...]: гладкая (кубическая Эрмита с наклонами,
## не дающими выбросов, как «auto» у Unity).
static func _curve(keys: Array, u: float) -> float:
	if u <= float(keys[0][0]):
		return float(keys[0][1])
	for j in range(1, keys.size()):
		var x0 := float(keys[j - 1][0])
		var x1 := float(keys[j][0])
		if u > x1:
			continue
		var y0 := float(keys[j - 1][1])
		var y1 := float(keys[j][1])
		var h := x1 - x0
		var m0 := _slope(keys, j - 1)
		var m1 := _slope(keys, j)
		var v := (u - x0) / h
		var v2 := v * v
		var v3 := v2 * v
		return (2 * v3 - 3 * v2 + 1) * y0 + (v3 - 2 * v2 + v) * h * m0 + (-2 * v3 + 3 * v2) * y1 + (v3 - v2) * h * m1
	return float(keys[-1][1])


static func _slope(keys: Array, j: int) -> float:
	if j == 0 or j == keys.size() - 1:
		return 0.0
	var d0 := (float(keys[j][1]) - float(keys[j - 1][1])) / (float(keys[j][0]) - float(keys[j - 1][0]))
	var d1 := (float(keys[j + 1][1]) - float(keys[j][1])) / (float(keys[j + 1][0]) - float(keys[j][0]))
	if d0 * d1 <= 0.0:
		return 0.0
	return 2.0 / (1.0 / d0 + 1.0 / d1)


func _set_camera(off: Vector2) -> void:
	off = off.round()
	for c: Control in [_under_layer, _card, _over_layer]:
		c.position = off
	camera_offset.emit(off)


func _frame() -> void:
	var n := int(_meta["frames"])
	var i := mini(floori(_t * float(_meta["fps"])), n - 1)
	if i != _shown_frame:
		_shown_frame = i
		_over_layer.show_frame(_texture("f", i))
		_under_layer.show_frame(_texture("u", i) if _under.has(i) else null)
		for k in range(i + 1, mini(i + 1 + AHEAD, n)):
			_request("f", k)
			if _under.has(k):
				_request("u", k)
		for key: String in _cache.keys():
			if int(key.substr(1)) < i:
				_cache.erase(key)
	_render_card()


func _path(track: String, i: int) -> String:
	return BAKED + String(_script["frames"]) + "/%s%03d.png" % [track, i]


func _request(track: String, i: int) -> void:
	var key := track + str(i)
	if _cache.has(key):
		return
	_cache[key] = null
	ResourceLoader.load_threaded_request(_path(track, i), "Texture2D")


func _texture(track: String, i: int) -> Texture2D:
	var key := track + str(i)
	var path := _path(track, i)
	if _cache.has(key):
		var t: Texture2D = _cache[key]
		if t == null:
			t = ResourceLoader.load_threaded_get(path)
			_cache[key] = t
		return t
	var tex := load(path) as Texture2D
	_cache[key] = tex
	return tex


## Миниатюра: проявляется снизу вверх, стоит, гаснет.
func _render_card() -> void:
	var cs: Dictionary = _script["card"]
	var t0 := float(cs["reveal"])
	if _t < t0:
		_card.show_card(null, Rect2(), 0.0, 1.0)
		return
	var shown := clampf((_t - t0) / float(cs["sweep"]), 0.0, 1.0)
	var out_at := t0 + float(cs["sweep"]) + float(cs["hold"])
	var a := 1.0 - clampf((_t - out_at) / float(cs["out"]), 0.0, 1.0)
	_card.show_card(_item["face"], _card_rect(), a, shown)


## Лицо карты для розыгрыша cid: полноформатное или миниатюра — как в сценарии (под него
## запечён горящий контур появления).
static func face_of(cid: String, art: String = "") -> Texture2D:
	var cs: Dictionary = SCRIPTS[RECIPES[cid]]["card"]
	return CardView.mini_texture(cid, art) if String(cs.get("face", "full")) == "mini" else CardView.pixel_texture(cid, art)


## Где карта на экране: в своём размере, центр сценария (960x540) -> размер HsPlay.
func _card_rect() -> Rect2:
	var k := size / Vector2(960, 540)
	var face: Texture2D = _item["face"]
	var s := (face.get_size() if face != null else CardView.PIXEL_SIZE) * k
	var c := Vector2(_script["card"]["center"]) * k
	return Rect2((c - s * 0.5).round(), s.round())


## Кадр эффекта на весь экран: premultiplied-альфа (One, OneMinusSrcAlpha). Кадры сжаты
## WebP с потерями: цвет шумит, альфа точная — пиксель с нулевой альфой пустой, его шум
## не рисуется (у настоящих пикселей эффекта альфа не ниже 1/255).
const FRAME_SHADER := "shader_type canvas_item;\nrender_mode blend_premul_alpha;\n" \
	+ "void fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tCOLOR = c.a > 0.0 ? c : vec4(0.0);\n}\n"


class _FrameLayer extends Control:
	var _tex: Texture2D

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sh := Shader.new()
		sh.code = FRAME_SHADER
		var m := ShaderMaterial.new()
		m.shader = sh
		material = m

	func show_frame(tex: Texture2D) -> void:
		_tex = tex
		queue_redraw()

	func _draw() -> void:
		if _tex != null:
			draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)


## Карта: видна нижняя часть shown (0..1) — огонь проявляет её снизу вверх.
class _CardLayer extends Control:
	var _face: Texture2D
	var _rect := Rect2()
	var _alpha := 0.0
	var _shown := 1.0

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func show_card(face: Texture2D, r: Rect2, a: float, shown: float) -> void:
		_face = face
		_rect = r
		_alpha = a
		_shown = shown
		queue_redraw()

	func _draw() -> void:
		if _face == null or _alpha <= 0.0 or _shown <= 0.0:
			return
		var h := roundf(_rect.size.y * _shown)
		var src := Rect2(0.0, float(_face.get_height()) * (1.0 - h / _rect.size.y), float(_face.get_width()),
			float(_face.get_height()) * h / _rect.size.y)
		draw_texture_rect_region(_face, Rect2(_rect.position.x, _rect.end.y - h, _rect.size.x, h), src, Color(1, 1, 1, _alpha))
