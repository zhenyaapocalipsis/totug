class_name HsPlay
extends Control

## Розыгрыш карты как в Hearthstone (решения владельца 2026-10-19/20): без витрины и
## без затемнения; нажатую карту рука прячет сразу, и идёт эффект Hearthstone, затем в
## центре доски на секунду проявляется миниатюра карты и гаснет — и только потом игра
## показывает действия карты (released). Действия карты (вытеснение, возврат шпиона, VP)
## тоже играют эффекты HS — на месте цели (action). Всё время розыгрыша, пока карта не
## отыграла все действия, по краям экрана висит дымка эффекта розыгрыша (fog_on/fog_off).
##
## Эффекты — запечённые кадры (assets/hs_fx/baked/<имя>/): Unity рисует оригинальные
## префабы Hearthstone из файлов игры его же шейдерами, частицами и Timeline, с камеры
## доски HS, и пишет кадры 960x540 с premultiplied-альфой (hs_unity, HsRender; рецепт —
## hs_unity/recipes/<имя>.json). Дорожка f### рисуется над картой, u### — под ней
## (подложка и горящий контур появления карты). Текстуры HS под его макет (рамка карты,
## портрет героя) при запекании заменены своими.

## Акт появления закончился, карта погасла: можно показывать действия и вопросы.
signal released
## Сдвиг «камеры» (тряска камеры Hearthstone) в пикселях экрана: доска сдвигается так же,
## как кадры эффектов (BoardPanel.camera_offset); дымка по краям экрана стоит.
signal camera_offset(offset: Vector2)

const BAKED := "res://assets/hs_fx/baked/"
const SOUNDS := "res://assets/hs_fx/"
## Расчётный экран: кадры запечены под него.
const DESIGN := Vector2(960, 540)
## Сколько кадров вперёд подгружать в фоне (кадры идут 60 в секунду, WebP распаковывается
## несколько миллисекунд).
const AHEAD := 12
## Сколько первых кадров должно быть готово до старта часов эффекта.
const WARM := 8
## Пикселей экрана 960x540 на единицу мира HS на уровне доски (камера доски HS: высота
## 19.6, вертикальный угол обзора 34.87).
const PX_PER_UNIT := 44.1

## Карта -> сценарий.
const RECIPES := {"48426": "worldbreaker", "48400": "onyxia", "48403": "malygos"}
## Сценарий: frames — папка кадров розыгрыша; sounds — папка звуков; card — появление
## карты в своём размере: face (full — полноформатная, mini — миниатюра; горящий контур
## в кадрах запечён под неё), reveal (секунда), sweep (проявляется снизу вверх), hold
## (стоит), out (гаснет), center (центр на экране 960x540 — центр квада Quad_CardGlow);
## cues — звуки [секунда, файл, громкость 0..1, высота тона (1)]; shakers — тряска камеры HS (дорожка
## CameraShaker2 в Timeline спелла): [с, по, амплитуда (единицы мира HS), кривая силы
## [[доля клипа, сила], ...], интервал смены точки, с]; fog — дымка розыгрыша (FOGS) и
## секунда её появления; actions — эффекты действий карты: событие -> frames, anchor
## (точка удара в кадрах на экране 960x540 — по центру огня в кадрах), follow (xy — кадр сдвигается в точку цели,
## y — только по высоте), cues, shakers, lead (через сколько секунд может начаться
## следующее действие).
const SCRIPTS := {
	# Deathwing, Worldbreaker (CATA_190h): CATAFX_Deathwing_CustomSummon_Spell (тень
	# дракона с огненным шлейфом проносится над доской, пике в центр доски (1.13 с),
	# огненная волна, вспышка, дым, угли) и сразу за ударом CATAFX_Deathwing_Choice_Reveal
	# (одна карта вместо четырёх, с 1.15 с; сама карта — через 0.45 с, WaitToShowCards;
	# огонь появления убран, осталось выжигание — владелец 2026-10-20). Действия карты
	# (вытеснение, возврат шпиона, VP) — обычные анимации игры (владелец 2026-10-21:
	# эффекты Raze/Topple HS убраны); дымка YoggFogg висит до конца розыгрыша карты.
	"worldbreaker": {"frames": "worldbreaker", "sounds": "worldbreaker",
		"card": {"face": "mini", "reveal": 1.6, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# громкости — AudioSource префабов HS; стингеры карт (m_PlayEffectDef) не нужны (владелец)
		"cues": [[0.0, "CATA_190h_Enter_01", 0.7], [0.0, "CATA_190h_Enter_Dragon_01", 0.7], [0.85, "CATA_190h_Enter_02", 0.7],
			[1.0, "CATA_190h_Enter_Dragon_02", 0.7], [1.15, "CATA_190h_CardReveal_01", 0.8]],
		"shakers": [[0.0, 1.133, 0.08, [[0.0, 0.5], [0.3, 0.99], [0.51, 0.23], [1.0, 0.0]], 0.075],
			[1.133, 2.533, 0.12, [[0.0, 0.5], [0.1, 0.99], [0.21, 0.98], [0.67, 0.15], [1.0, 0.0]], 0.075]],
		"fog": ["worldbreaker_fog", 0.1]},
	# Onyxia the Broodmother (CS3_032) — Black Dragon: ds1FX_Onyxia_CustomSummon (по FSM
	# спелла; без полёта миньона HS — владелец 2026-10-24: сгусток дыма и огня с нажатия
	# формируется в точке посадки, на 0.72 с «крик» — огненное кольцо с лучами, удар 1.5 с
	# — дым и угли; свечение миньона HS и трещины под ним убраны) и за ударом
	# Choice_Reveal Deathwing, как у Red Dragon (у Onyxia своего нет), выжигание чёрное
	# (владелец 2026-10-24: в тоне карты). Эффекта розыгрыша (m_PlayEffectDef) у Onyxia
	# нет — дымки нет.
	"onyxia": {"frames": "onyxia", "sounds": "onyxia",
		"card": {"face": "mini", "reveal": 1.97, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# громкости — AudioPlayClipAction FSM (AudioSource 1)
		"cues": [[0.0, "Onyxia_CustomSummon_Cast", 0.8], [1.5, "Onyxia_CustomSummon_Impact", 0.7]],
		# CameraShakerAction FSM в ударе: 0.2 по осям, случайная точка каждый кадр, 0.56 с
		"shakers": [[1.5, 2.06, 0.16, [[0.0, 1.0], [0.161, 0.9], [0.393, 0.27], [1.0, 0.0]], 0.0167]]},
	# Malygos, Aspect of Magic (DRG_270) — Blue Dragon: DRGFX_MalygosAspectOfMagic_CustomSummon
	# (Timeline спелла): в точке посадки искра раскрывается в синий магический портал со
	# спиралью и лучами, из него поднимается вспышка с кольцом и на 1.7 с падает вниз —
	# удар, фиолетовая вспышка газа и искры; свечение миньона HS и трещины убраны. За
	# ударом Choice_Reveal Deathwing, как у Red Dragon, выжигание синее (тон карты).
	# Дымки нет (нет m_PlayEffectDef).
	"malygos": {"frames": "malygos", "sounds": "malygos",
		"card": {"face": "mini", "reveal": 2.2, "sweep": 0.6, "hold": 1.0, "out": 0.35, "center": Vector2(490, 365)},
		# FSM: звук портала с начала, два звука удара в 1.7 с (второй — pitch 1.1)
		"cues": [[0.0, "MalygosAspectOfMagic_CustomSummon_Sound", 0.7], [1.7, "FlikSkyshiv_CustomSummon_Impact_Sound", 0.6, 1.1],
			[1.7, "AngelicaWarden_CustomSummon_Impact_Sound", 0.7]],
		# MainCameraShakerAction: 0.15 по осям, сила линейно 1 -> 0 за время тряски
		"shakers": [[0.7, 1.4, 0.12, [[0.0, 1.0], [1.0, 0.0]], 0.0167], [1.7, 2.0, 0.12, [[0.0, 1.0], [1.0, 0.0]], 0.0167]]},
}
## Дымка розыгрыша (YoggFogg — эффект розыгрыша карты в HS, m_PlayEffectDef): кадры
## запечены с появлением (Intro), долгим средним куском и уходом (End с секунды end).
## Средний кусок [loop[0], loop[1]] повторяется по кругу со сменой через fade секунд;
## уход — переход за end_fade в кадры с end. sound — петля [файл, появление, громкость,
## затухание], end_sound — звук ухода [файл, громкость].
const FOGS := {
	"worldbreaker_fog": {"sounds": "worldbreaker", "loop": [1.5, 4.5], "fade": 0.6, "end": 6.0, "end_fade": 0.3,
		"sound": ["CATA_190h_YoggFogg_Loop", 0.5, 0.8, 1.5], "end_sound": ["CATA_190h_YoggFogg_End", 0.3]},
}

## Для снимков: шаг времени за кадр (0 — настоящее время).
static var fixed_dt := 0.0

var board_area: Control
var _queue: Array[Dictionary] = []
## Розыгрыш (основной эффект): карта, сценарий, его кадры.
var _item: Dictionary = {}
var _script: Dictionary = {}
var _main: _Clip
var _released := false
## Эффекты действий: идут или ждут своей очереди.
var _actions: Array[_Clip] = []
## Часы HsPlay и время, раньше которого не начинается следующее действие.
var _clock := 0.0
var _action_free_at := 0.0
## Дымка.
var _fog: _Fog
var _fog_end_at := -1.0
var _fog_snd := AudioStreamPlayer.new()

var _fog_box := Control.new()
var _under_box := Control.new()
var _card := _CardLayer.new()
var _over_box := Control.new()


static func has(cid: String) -> bool:
	return RECIPES.has(cid)


## Есть ли у карты cid эффект для события kind (supplant, return_spy, vp_site).
static func has_action(cid: String, kind: String) -> bool:
	return has(cid) and (SCRIPTS[RECIPES[cid]].get("actions", {}) as Dictionary).has(kind)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: Control in [_fog_box, _under_box, _card, _over_box]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(c)
	_fog_snd.bus = Sfx.BUS
	add_child(_fog_snd)
	visible = false
	set_process(false)


## Разыграть карту cid: face — её лицо, quiet — чужая (тише); preview — только
## посмотреть (меню CARD ANIMATIONS): действий не будет, дымка уходит после эффекта.
func play(cid: String, face: Texture2D, quiet: bool = false, preview: bool = false) -> void:
	if not has(cid):
		return
	_queue.append({"cid": cid, "face": face, "quiet": quiet, "preview": preview})
	if _item.is_empty():
		_next()


## Эффект действия карты cid (событие kind) с целью в точке at (глобальные координаты):
## действия идут по очереди, каждое начинается, когда прежнее дошло до своего удара.
func action(cid: String, kind: String, at: Vector2, quiet: bool = false) -> void:
	if not has_action(cid, kind):
		return
	var spec: Dictionary = SCRIPTS[RECIPES[cid]]["actions"][kind]
	var target := _design(at)
	var off := target - Vector2(spec["anchor"])
	if String(spec["follow"]) == "y":
		off.x = 0.0
	var c := _Clip.new(self, String(spec["frames"]), String(SCRIPTS[RECIPES[cid]]["sounds"]), quiet, false)
	c.offset = off
	c.cues = spec.get("cues", [])
	c.set_shakers(spec.get("shakers", []))
	c.delay = maxf(0.0, _action_free_at - _clock)
	_action_free_at = _clock + c.delay + float(spec["lead"])
	_actions.append(c)
	_wake()


## Дымка розыгрыша карты cid: появляется через delay секунд (если её ещё нет).
func fog_on(cid: String, delay: float = 0.0, quiet: bool = false) -> void:
	if not has(cid) or not SCRIPTS[RECIPES[cid]].has("fog"):
		return
	_fog_end_at = -1.0
	if _fog != null and not _fog.ending:
		return
	if _fog != null:
		_fog.free_layers()
	var f: Array = SCRIPTS[RECIPES[cid]]["fog"]
	_fog = _Fog.new(self, String(f[0]), quiet)
	_fog.delay = delay
	_wake()


## Карта отыграла действия: дымка уходит, когда закончится очередь действий.
func fog_off() -> void:
	if _fog == null or _fog.ending:
		return
	_fog_end_at = maxf(_clock, _action_free_at) + 0.6


## Идёт ли розыгрыш, который ещё держит действия карты.
func is_busy() -> bool:
	return not _item.is_empty() and not _released


## Готов ли розыгрыш (для снимков и превью).
func is_ready() -> bool:
	return not _item.is_empty()


func _wake() -> void:
	visible = true
	set_process(true)


## Точка из глобальных координат в координаты расчётного экрана 960x540.
func _design(at: Vector2) -> Vector2:
	return (get_global_transform().affine_inverse() * at) * DESIGN / size


func _next() -> void:
	if _main != null:
		_main.free_layers()
	_main = null
	_item = {}
	_card.show_card(null, Rect2(), 0.0, 1.0)
	if _queue.is_empty():
		return
	_item = _queue.pop_front()
	_script = SCRIPTS[RECIPES[_item["cid"]]]
	_main = _Clip.new(self, String(_script["frames"]), String(_script["sounds"]), bool(_item["quiet"]), true)
	_main.cues = _script["cues"]
	_main.set_shakers(_script.get("shakers", []))
	_released = false
	var f: Array = _script.get("fog", [])
	if not f.is_empty():
		fog_on(_item["cid"], float(f[1]), bool(_item["quiet"]))
	_wake()


func _process(delta: float) -> void:
	var dt := fixed_dt if fixed_dt > 0.0 else delta
	_clock += dt
	if _main != null:
		_main.step(dt)
		_render_card()
		var cs: Dictionary = _script["card"]
		if not _released and _main.t >= float(cs["reveal"]) + float(cs["sweep"]) + float(cs["hold"]) + float(cs["out"]):
			_released = true
			released.emit()
		if _main.finished():
			if bool(_item.get("preview", false)):
				fog_off()
			_next()
	for c in _actions.duplicate():
		c.step(dt)
		if c.finished():
			c.free_layers()
			_actions.erase(c)
	if _fog != null:
		if _fog_end_at >= 0.0 and _clock >= _fog_end_at and not _fog.ending:
			_fog.end()
			_fog_end_at = -1.0
		_fog.step(dt)
		if _fog.finished():
			_fog.free_layers()
			_fog = null
	_set_camera(_camera())
	if _main == null and _actions.is_empty() and _fog == null:
		visible = false
		set_process(false)


## Кадр розыгрыша в момент t (секунды от начала), без звуков — для снимков.
func debug_seek(t: float) -> void:
	if _main != null:
		_main.seek(t)
		_render_card()


## Сдвиг камеры от тряски всех идущих эффектов (дымка не трясётся).
func _camera() -> Vector2:
	var off := Vector2.ZERO
	if _main != null:
		off += _main.shake_offset()
	for c in _actions:
		off += c.shake_offset()
	return off * PX_PER_UNIT * size.y / DESIGN.y


func _set_camera(off: Vector2) -> void:
	off = off.round()
	for c: Control in [_under_box, _card, _over_box]:
		c.position = off
	camera_offset.emit(off)


## Карта: проявляется снизу вверх, стоит, гаснет.
func _render_card() -> void:
	var cs: Dictionary = _script["card"]
	var t0 := float(cs["reveal"])
	if _main.t < t0:
		_card.show_card(null, Rect2(), 0.0, 1.0)
		return
	var shown := clampf((_main.t - t0) / float(cs["sweep"]), 0.0, 1.0)
	var out_at := t0 + float(cs["sweep"]) + float(cs["hold"])
	var a := 1.0 - clampf((_main.t - out_at) / float(cs["out"]), 0.0, 1.0)
	_card.show_card(_item["face"], _card_rect(), a, shown)


## Лицо карты для розыгрыша cid: полноформатное или миниатюра — как в сценарии (под него
## запечён горящий контур появления).
static func face_of(cid: String, art: String = "") -> Texture2D:
	var cs: Dictionary = SCRIPTS[RECIPES[cid]]["card"]
	return CardView.mini_texture(cid, art) if String(cs.get("face", "full")) == "mini" else CardView.pixel_texture(cid, art)


## Где карта на экране: в своём размере, центр сценария (960x540) -> размер HsPlay.
func _card_rect() -> Rect2:
	var k := size / DESIGN
	var face: Texture2D = _item["face"]
	var s := (face.get_size() if face != null else CardView.PIXEL_SIZE) * k
	var c := Vector2(_script["card"]["center"]) * k
	return Rect2((c - s * 0.5).round(), s.round())


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


## Набор запечённых кадров: meta, подгрузка в фоне, кадр по времени.
class _Frames:
	var dir: String
	var fps := 60.0
	var count := 0
	var under := {}
	var _cache := {}

	func _init(name: String) -> void:
		dir = BAKED + name + "/"
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "meta.json"))
		fps = float(meta["fps"])
		count = int(meta["frames"])
		for i in meta.get("under", []):
			under[int(i)] = true

	func length() -> float:
		return count / fps

	func index(t: float) -> int:
		return clampi(floori(t * fps), 0, count - 1)

	func path(track: String, i: int) -> String:
		return dir + "%s%03d.png" % [track, i]

	func request(track: String, i: int) -> void:
		if i < 0 or i >= count or (track == "u" and not under.has(i)):
			return
		var key := track + str(i)
		if _cache.has(key):
			return
		_cache[key] = null
		ResourceLoader.load_threaded_request(path(track, i), "Texture2D")

	func ready(i: int) -> bool:
		return ResourceLoader.load_threaded_get_status(path("f", i)) == ResourceLoader.THREAD_LOAD_LOADED

	func texture(track: String, i: int) -> Texture2D:
		if track == "u" and not under.has(i):
			return null
		var key := track + str(i)
		if _cache.has(key):
			var t: Texture2D = _cache[key]
			if t == null:
				t = ResourceLoader.load_threaded_get(path(track, i))
				_cache[key] = t
			return t
		var tex := load(path(track, i)) as Texture2D
		_cache[key] = tex
		return tex

	## Держать подгруженными кадры starts[j]..starts[j]+AHEAD (и подгрузить их в фоне),
	## остальные забыть.
	func keep(starts: Array) -> void:
		var need := {}
		for s: int in starts:
			for k in range(maxi(s, 0), mini(s + AHEAD, count)):
				need[k] = true
				request("f", k)
				request("u", k)
		for key: String in _cache.keys():
			if not need.has(int(key.substr(1))):
				_cache.erase(key)


## Один идущий эффект: кадры (над картой и под ней), сдвиг на экране, звуки, тряска.
class _Clip:
	var host: HsPlay
	var frames: _Frames
	var sounds: String
	var quiet := false
	var t := 0.0
	var delay := 0.0
	var offset := Vector2.ZERO
	var cues: Array = []
	var shakers: Array = []
	var shake_points: Array = []
	var over := _FrameLayer.new()
	var under_layer := _FrameLayer.new()
	var _cue_t := -1.0
	var _warm := WARM
	var _warm_asked := 0
	var _shown := -1

	func _init(h: HsPlay, name: String, sound_dir: String, q: bool, with_under: bool) -> void:
		host = h
		frames = _Frames.new(name)
		sounds = sound_dir
		quiet = q
		_warm = mini(WARM, frames.count)
		host._over_box.add_child(over)
		if with_under or not frames.under.is_empty():
			host._under_box.add_child(under_layer)

	func set_shakers(list: Array) -> void:
		shakers = list
		shake_points = []
		for sh: Array in list:
			shake_points.append(HsPlay._shake_path(float(sh[2])))

	func finished() -> bool:
		return _warm == 0 and delay <= 0.0 and t >= frames.length()

	func free_layers() -> void:
		over.queue_free()
		under_layer.queue_free()

	func step(dt: float) -> void:
		if delay > 0.0:
			delay -= dt
			_preload()
			return
		if not _preload():
			return
		t += dt
		_cues()
		_show()

	func seek(time: float) -> void:
		t = time
		_warm = 0
		_show()

	## Первые кадры распаковываются (по два за кадр игры: готовые уходят в видеокарту
	## понемногу); часы эффекта стоят, пока они не готовы.
	func _preload() -> bool:
		if _warm == 0:
			return true
		for k in range(_warm_asked, mini(_warm_asked + 2, _warm)):
			frames.request("f", k)
			frames.request("u", k)
		_warm_asked = mini(_warm_asked + 2, _warm)
		for k in _warm:
			if k >= _warm_asked or not frames.ready(k):
				return false
		_warm = 0
		return delay <= 0.0

	func _show() -> void:
		var i := frames.index(t)
		var k := host.size / DESIGN
		for l: _FrameLayer in [over, under_layer]:
			l.position = (offset * k).round()
			l.size = host.size
		if i != _shown:
			_shown = i
			over.show_frame(frames.texture("f", i))
			under_layer.show_frame(frames.texture("u", i))
			frames.keep([i])

	func _cues() -> void:
		for c: Array in cues:
			if _cue_t < float(c[0]) and t >= float(c[0]):
				var vol := float(c[2]) if c.size() > 2 else 1.0
				var pitch := float(c[3]) if c.size() > 3 else 1.0
				Sfx.play_file(SOUNDS + sounds + "/" + String(c[1]) + ".wav", quiet, linear_to_db(vol), pitch)
		_cue_t = t

	## Сдвиг камеры в момент t, как ShakerHelper.UpdateTarget: доля клипа -> номер точки
	## (каждые interval секунд — следующая), переход между точками с двойным косинусным
	## сглаживанием, умножение на кривую силы. В мире HS вверх экрана — +z, сдвиг камеры
	## вверх двигает картинку вниз. В единицах мира HS.
	func shake_offset() -> Vector2:
		var off := Vector2.ZERO
		if delay > 0.0 or _warm > 0:
			return off
		for n in shakers.size():
			var sh: Array = shakers[n]
			var t0 := float(sh[0])
			var t1 := float(sh[1])
			if t < t0 or t >= t1:
				continue
			var u := (t - t0) / (t1 - t0)
			var s := u * (t1 - t0) / float(sh[4])
			var i := floori(s)
			var w := 1.0 - (0.5 + 0.5 * cos((s - i) * PI))
			w = 1.0 - (0.5 + 0.5 * cos(w * PI))
			var pts: PackedVector2Array = shake_points[n]
			var p := pts[i % pts.size()].lerp(pts[(i + 1) % pts.size()], w) * HsPlay._curve(sh[3], u)
			off += Vector2(-p.x, p.y)
		return off


## Дымка: появление, средний кусок по кругу (смена через fade), уход по запросу; две
## дорожки кадров для плавных переходов. Не трясётся.
class _Fog:
	var host: HsPlay
	var frames: _Frames
	var spec: Dictionary
	var quiet := false
	var t := 0.0
	var delay := 0.0
	var ending := false
	var _end_t := 0.0
	var _end_phase := 0.0
	var _a := _FrameLayer.new()
	var _b := _FrameLayer.new()
	var _warm := WARM
	var _warm_asked := 0
	var _started := false

	func _init(h: HsPlay, name: String, q: bool) -> void:
		host = h
		frames = _Frames.new(name)
		spec = FOGS[name]
		quiet = q
		_warm = mini(WARM, frames.count)
		host._fog_box.add_child(_b)
		host._fog_box.add_child(_a)

	func free_layers() -> void:
		_a.queue_free()
		_b.queue_free()
		host._fog_snd.stop()

	var _dead := false

	func finished() -> bool:
		return _dead or (ending and float(spec["end"]) + (t - _end_t) >= frames.length())

	func end() -> void:
		if not _started:
			# дымка ещё не появилась — просто не показываем её
			ending = true
			_dead = true
			return
		ending = true
		_end_t = t
		_end_phase = _phase(t)
		var snd: Array = spec["end_sound"]
		Sfx.play_file(SOUNDS + String(spec["sounds"]) + "/" + String(snd[0]) + ".wav", quiet, linear_to_db(float(snd[1])))

	## Время в кадрах дымки до ухода: появление, затем средний кусок по кругу.
	func _phase(time: float) -> float:
		var a := float(spec["loop"][0])
		var b := float(spec["loop"][1])
		if time < b:
			return time
		return a + fmod(time - b, b - a)

	func step(dt: float) -> void:
		if delay > 0.0:
			delay -= dt
			_preload()
			return
		if not _preload():
			return
		if not _started:
			_started = true
			var snd: Array = spec["sound"]
			host._fog_snd.stream = load(SOUNDS + String(spec["sounds"]) + "/" + String(snd[0]) + ".wav")
			if Sfx.volume > 0.0:
				host._fog_snd.play()
		t += dt
		_sound()
		_show()

	func _preload() -> bool:
		if _warm == 0:
			return true
		for k in range(_warm_asked, mini(_warm_asked + 2, _warm)):
			frames.request("f", k)
		_warm_asked = mini(_warm_asked + 2, _warm)
		for k in _warm:
			if k >= _warm_asked or not frames.ready(k):
				return false
		_warm = 0
		return delay <= 0.0

	func _sound() -> void:
		var snd: Array = spec["sound"]
		var k := clampf(t / float(snd[1]), 0.0, 1.0)
		if ending:
			k *= 1.0 - clampf((t - _end_t) / float(snd[3]), 0.0, 1.0)
		host._fog_snd.volume_db = linear_to_db(maxf(k * float(snd[2]), 0.0001)) + (Sfx.OTHER_DB if quiet else 0.0)

	func _show() -> void:
		var main_t: float
		var side_t := -1.0
		var side_w := 0.0
		if ending:
			var d := t - _end_t
			main_t = float(spec["end"]) + d
			side_t = _end_phase + d
			side_w = 1.0 - clampf(d / float(spec["end_fade"]), 0.0, 1.0)
		else:
			main_t = _phase(t)
			var a := float(spec["loop"][0])
			var b := float(spec["loop"][1])
			if t >= b:
				# начало нового круга: прошлый круг продолжается за b и тает
				side_t = main_t + (b - a)
				side_w = 1.0 - clampf((main_t - a) / float(spec["fade"]), 0.0, 1.0)
		var i := frames.index(main_t)
		_a.size = host.size
		_b.size = host.size
		_a.show_frame(frames.texture("f", i), 1.0 - side_w if side_w > 0.0 else 1.0)
		var keep := [i]
		if side_w > 0.0:
			var j := frames.index(side_t)
			_b.show_frame(frames.texture("f", j), side_w)
			keep.append(j)
		else:
			_b.show_frame(null)
		# заранее в памяти: начало круга (переход с конца куска) и начало ухода
		if not ending:
			keep.append(frames.index(float(spec["loop"][0])))
			keep.append(frames.index(float(spec["end"])))
		frames.keep(keep)


## Кадр эффекта на весь экран: premultiplied-альфа (One, OneMinusSrcAlpha). Кадры сжаты
## WebP с потерями: цвет шумит, альфа точная — пиксель с нулевой альфой пустой, его шум
## не рисуется (у настоящих пикселей эффекта альфа не ниже 1/255). alpha — общая
## прозрачность кадра (переходы дымки).
## Пиксель-арт (владелец, 2026-10-21): кадр рисуется крупным пикселем PIXEL_BLOCK x
## PIXEL_BLOCK пикселей игры (без сглаживания), яркость — PIXEL_LEVELS ровными ступенями
## с сохранением оттенка (поканальные ступени давали грязные оливковые тона), прозрачность
## — PIXEL_ALPHA ступенями; без дизеринга (решётка Байера по дымке рябила поверх
## интерфейса). Ступени — в premultiplied-виде: чистый свет (альфа ~0) остаётся светом.
const PIXEL_LEVELS := 6.0
const PIXEL_ALPHA := 8.0
const PIXEL_BLOCK := 2.0
const FRAME_SHADER := "shader_type canvas_item;\nrender_mode blend_premul_alpha;\n" \
	+ "uniform float alpha = 1.0;\nuniform float levels = 7.0;\nuniform float alpha_levels = 4.0;\n" \
	+ "uniform float block = 1.0;\n" \
	+ "float step_to(float v, float n, float d) { return clamp(floor(v * n + d) / n, 0.0, 1.0); }\n" \
	+ "void fragment() {\n" \
	+ "\tvec2 tsz = vec2(textureSize(TEXTURE, 0));\n\tvec2 px = floor(UV * tsz / block) * block;\n" \
	+ "\tvec4 c = texture(TEXTURE, (px + 0.5 * block) / tsz);\n" \
	+ "\tif (c.a <= 0.0) { COLOR = vec4(0.0); } else {\n" \
	+ "\t\tfloat d = 0.5;\n" \
	+ "\t\tfloat v = max(c.r, max(c.g, c.b));\n" \
	+ "\t\tvec4 q = vec4(v > 0.0 ? c.rgb * (step_to(v, levels, d) / v) : vec3(0.0), step_to(c.a, alpha_levels, d));\n" \
	+ "\t\tCOLOR = q * alpha;\n\t}\n}\n"
static var _frame_shader: Shader


class _FrameLayer extends Control:
	var _tex: Texture2D
	var _mat := ShaderMaterial.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if HsPlay._frame_shader == null:
			HsPlay._frame_shader = Shader.new()
			HsPlay._frame_shader.code = FRAME_SHADER
		_mat.shader = HsPlay._frame_shader
		_mat.set_shader_parameter("levels", PIXEL_LEVELS)
		_mat.set_shader_parameter("alpha_levels", PIXEL_ALPHA)
		_mat.set_shader_parameter("block", PIXEL_BLOCK)
		material = _mat

	func show_frame(tex: Texture2D, alpha: float = 1.0) -> void:
		_mat.set_shader_parameter("alpha", alpha)
		if tex != _tex:
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
