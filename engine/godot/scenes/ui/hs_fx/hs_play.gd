class_name HsPlay
extends Control

## Розыгрыш карты в духе Hearthstone (решения владельца 2026-10-19): без витрины и без
## затемнения; нажатую карту рука прячет сразу, и начинается эффект — префабы Hearthstone
## (HsFx: частицы, меши, анимации, материалы FX/CommonFX), перенесённые из Unity, по их
## же сценарию (Timeline / анимация). После «акта появления» в центре на секунду встаёт
## полноформатная карта (горящее появление Hearthstone), гаснет — и только потом игра
## показывает действия карты (released).
##
## Эффект стоит в своих мировых координатах Hearthstone и снят камерой Hearthstone
## (BoardCameras/Main Camera) на весь экран — как в
## игре. Материалы: шейдер hs_commonfx (пиксельная часть FX/CommonFX по его коду),
## вершинная часть — здесь (_vertex), тоже по коду. Пиксель-арт: сетка игры 960x540,
## кадры ступенями (HsFx.FPS).

## Акт появления закончился, карта погасла: можно показывать действия и вопросы.
signal released
## Толчок доски (сила в пикселях, BoardPanel.shake).
signal shake(power: float)

const COMMON_SHADER := preload("res://scenes/ui/hs_fx/hs_commonfx.gdshader")
## Камера доски Hearthstone (BoardCameras/Main Camera): где стоит, куда смотрит, вертикальный угол обзора.
const CAM_POS := Vector3(-7.795, 19.598, -5.965)
const CAM_FWD := Vector3(0.0, -0.998, 0.056)
const CAM_UP := Vector3(0.0, 0.056, 0.998)
const CAM_RIGHT := Vector3(1.0, 0.0, 0.0)
const CAM_FOV := 34.87
## Кусок текстуры «горящей копии» карты, занятый картой: как у GenFX_AbilityCard_Echo_BW
## в HS, чтобы анимация маски и растворения ложилась на карту так же. Сама текстура —
## своя (_echo_texture), по макету нашей мелкой карты, а не по рамке карты HS.
const ECHO_CARD := Vector2(0.55, 0.76)
## Миниатюра карты в центре доски — во столько раз крупнее своих пикселей.
const MINI_SCALE := 2
## Текстуры HS, нарисованные под его макет (портрет героя — арка), -> свои
## (tools/hs_own_textures.gd): у нас героя нет.
const OWN_TEXTURES := {
	"GenFX_HeroGlow_Soft_TransparentCenter": "res://assets/hs_fx/own/ring.png",
	"GenFX_HeroShadow_Internal": "res://assets/hs_fx/own/disc.png",
	"Cracks_HeroSocket_FriendlySide": "res://assets/hs_fx/own/cracks.png",
}

## Карта -> сценарий.
const RECIPES := {"48426": "worldbreaker"}
## Сценарий: len — длина; layers — префабы: fx, at (секунда старта), clip (анимация) и
## clip_root (путь аниматора), only (только это поддерево) и place (где его корень в
## мире), controls — [путь, с, по] (дорожки Timeline: объект включён и его частицы идут
## только в эти секунды), play_all — все частицы с начала слоя, under — узлы под картой.
## card — горящее появление карты: reveal (секунда), sweep (огонь проходит карту), hold
## (стоит), out (гаснет), place (точка карты в мире). cues — звуки, shakes — толчки.
const SCRIPTS := {
	# Deathwing, Worldbreaker (CATA_190h): CATAFX_Deathwing_CustomSummon_Spell (тень
	# с огненным шлейфом проносится над доской, дракон пикирует в героя — огненная
	# волна, вспышка, дым, угли) и CATAFX_Deathwing_Choice_Reveal (одна карта вместо
	# четырёх — в центральной позиции выбора, actorPosition_1).
	"worldbreaker": {"len": 4.6,
		"layers": [
			{"fx": "worldbreaker/summon", "at": 0.0,
				"clip": "worldbreaker/summon_anim", "clip_root": "TimelineRoot/AnimRoot",
				"controls": [["TimelineRoot/AnimRoot/TrailRoot/PS_Embers", 0.0, 6.0],
					["TimelineRoot/AnimRoot/TrailRoot/PS_Smoke", 0.067, 4.167],
					["TimelineRoot/AnimRoot/HeroRoot/PS_BurstFlames", 1.133, 4.717]],
				"hide": ["TimelineRoot/AnimRoot/HeroRoot/TokenRoot"],
				# тень дракона в HS — серая полупрозрачная, под светлую деревянную доску;
				# на нашей тёмной доске серый светлее фона — оставляем только затемнение
				"dark": ["TimelineRoot/AnimRoot/TrailRoot/Deathwing_Sweep"]},
			{"fx": "worldbreaker/reveal", "at": 1.7,
				"clip": "worldbreaker/reveal_anim", "clip_root": "Root/Bursts_Root/Burst0_New",
				"only": "Root/Bursts_Root/Burst0_New", "place": Vector3(-7.8, 3.802, -4.659),
				"play_all": true, "under": ["Quad_CardGlow_Backer"]},
		],
		"card": {"reveal": 2.15, "sweep": 0.6, "hold": 1.0, "out": 0.35, "place": Vector3(-7.8, 3.802, -4.659)},
		"cues": [[0.0, "CATA_190h_Enter_01"], [0.0, "CATA_190h_Enter_Dragon_01"], [0.85, "CATA_190h_Enter_02"],
			[1.0, "CATA_190h_Enter_Dragon_02"], [1.7, "CATA_190h_CardReveal_01"]],
		"shakes": [[0.0, 3.0], [1.133, 5.0]]},
}

## Для снимков: шаг времени за кадр (0 — настоящее время).
static var fixed_dt := 0.0
## Отладка (tools/hs_preview.gd): рисовать только узлы с этими именами (через запятую)
## и их потомков.
static var debug_only := ""

var board_area: Control
var _queue: Array[Dictionary] = []
var _item: Dictionary = {}
var _t := 0.0
var _released := false
var _cue_t := -1.0
var _script: Dictionary = {}
var _layers: Array[Dictionary] = []

## Эффект смешивается в буфере с плавающей точкой (HDR 2D), где альфа больше 1 вычитает фон, а яркость не обрезается.
## Для этого он рисуется в своём SubViewport поверх снимка экрана игры (снимок — в момент
## розыгрыша), и готовый кадр переводится в sRGB и кладётся поверх экрана.
const OUT_SHADER := preload("res://scenes/ui/hs_fx/hs_out.gdshader")
## Цвет FX считается в гамме, как задуманы материалы HS (серый 0.5 = «без изменений»,
## удвоение цвета вершины), и только результат переводится в линейный буфер кадра;
## в линейном счёте огонь и контур карты выходили тусклыми, а дым — розовым.
const GAMMA := true
const GAMMA_CLIP := 1.0

var _port := SubViewport.new()
var _bg := TextureRect.new()
var _view := TextureRect.new()
var _back := Control.new()
var _card := _CardLayer.new()
var _front := Control.new()
var _starting := false


static func has(cid: String) -> bool:
	return RECIPES.has(cid)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_port.use_hdr_2d = true
	_port.transparent_bg = false
	_port.disable_3d = true
	_port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_port)
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for c: Control in [_bg, _back, _card, _front]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_port.add_child(c)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var m := ShaderMaterial.new()
	m.shader = OUT_SHADER
	_view.material = m
	_view.texture = _port.get_texture()
	add_child(_view)
	visible = false


## Разыграть карту cid: face — её лицо, quiet — чужая (тише).
func play(cid: String, face: Texture2D, quiet: bool = false) -> void:
	if not has(cid):
		return
	_queue.append({"cid": cid, "face": face, "quiet": quiet})
	if _item.is_empty() and not _starting:
		_next()


## Идёт ли розыгрыш, который ещё держит действия карты.
func is_busy() -> bool:
	return (not _item.is_empty() and not _released) or _starting


## Готов ли кадр эффекта (снимок экрана взят) — для превью и снимков.
func is_ready() -> bool:
	return not _item.is_empty() and not _starting


func _next() -> void:
	for layer: Control in [_back, _front]:
		for c in layer.get_children():
			c.queue_free()
	_layers.clear()
	_item = {}
	visible = false
	set_process(false)
	_port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _queue.is_empty():
		return
	# снимок экрана без эффекта: ждём, пока кадр (уже без нас) дорисуется
	_starting = true
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	# окно может быть больше расчётного экрана (полный экран 1920x1080) — снимок в 960x540
	if shot.get_size() != Vector2i(size):
		shot.resize(int(size.x), int(size.y), Image.INTERPOLATE_NEAREST)
	_bg.texture = ImageTexture.create_from_image(shot)
	_starting = false
	_port.size = Vector2i(size)
	for c: Control in [_bg, _back, _card, _front]:
		c.position = Vector2.ZERO
		c.size = size
	_view.position = Vector2.ZERO
	_view.size = size
	_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_item = _queue.pop_front()
	_item["echo"] = _echo_texture(_item["face"])
	_script = SCRIPTS[RECIPES[_item["cid"]]]
	for spec: Dictionary in _script["layers"]:
		_layers.append(_make_layer(spec))
	_t = 0.0
	_released = false
	_cue_t = -1.0
	visible = true
	set_process(true)
	_frame()


func _process(delta: float) -> void:
	# Godot сам включает _process при входе в дерево — без розыгрыша выключаем
	if _item.is_empty():
		set_process(false)
		return
	_t += fixed_dt if fixed_dt > 0.0 else delta
	var cs: Dictionary = _script["card"]
	var card_end := float(cs["reveal"]) + float(cs["sweep"]) + float(cs["hold"]) + float(cs["out"])
	if not _released and _t >= card_end:
		_released = true
		released.emit()
	if _t >= float(_script["len"]):
		_next()
		return
	_cues(_t)
	_frame()


## Превью: кадр в момент t (секунды от начала розыгрыша), без звуков.
func debug_seek(t: float) -> void:
	_t = t
	_frame()


func _debug_skip(fx: HsFx, i: int) -> bool:
	if debug_only == "":
		return false
	var names := debug_only.split(",")
	var j := i
	while j >= 0:
		if String(fx.nodes[j]["name"]) in names:
			return false
		j = int(fx.nodes[j]["parent"])
	return true


## Звуки и толчки сценария — каждый, когда время его проходит.
func _cues(t: float) -> void:
	var dir := String((_script["layers"][0] as Dictionary)["fx"]).get_base_dir()
	for c: Array in _script["cues"]:
		if _cue_t < float(c[0]) and t >= float(c[0]):
			Sfx.play_file("res://assets/hs_fx/%s/%s.wav" % [dir, c[1]], bool(_item["quiet"]))
	for s: Array in _script["shakes"]:
		if _cue_t < float(s[0]) and t >= float(s[0]):
			shake.emit(float(s[1]))
	_cue_t = t


# --- камера --------------------------------------------------------------------------

## Точка мира -> экран (x, y в пикселях игры) и глубина (z).
func _project(p: Vector3) -> Vector3:
	var d := p - CAM_POS
	var z := maxf(d.dot(CAM_FWD), 0.05)
	var k := (size.y * 0.5) / tan(deg_to_rad(CAM_FOV) * 0.5)
	return Vector3(size.x * 0.5 + d.dot(CAM_RIGHT) / z * k, size.y * 0.5 - d.dot(CAM_UP) / z * k, z)


## Сколько пикселей экрана в одной единице мира на глубине z.
func _px_per_unit(z: float) -> float:
	return (size.y * 0.5) / tan(deg_to_rad(CAM_FOV) * 0.5) / maxf(z, 0.05)


# --- слой (один префаб) --------------------------------------------------------------

func _make_layer(spec: Dictionary) -> Dictionary:
	var fx := HsFx.load_fx(String(spec["fx"]))
	var L := {"spec": spec, "fx": fx, "drawers": {}, "holder": Control.new(), "under_holder": Control.new()}
	for h: Control in [L["holder"], L["under_holder"]]:
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# поверх карты — слой карты (only), остальное — под ней; подложки (under) — под картой
	if spec.has("only"):
		_front.add_child(L["holder"])
	else:
		_back.add_child(L["holder"])
	_back.add_child(L["under_holder"])
	var root := 0
	if spec.has("only"):
		root = fx.find_path(0, String(spec["only"]))
	L["root"] = root
	L["nodes"] = fx.subtree(root)
	L["clip"] = HsFx.load_clip(String(spec["clip"])) if spec.has("clip") else {}
	L["clip_root"] = fx.find_path(0, String(spec.get("clip_root", "")))
	var curves: Array = []
	if not (L["clip"] as Dictionary).is_empty():
		for c: Dictionary in L["clip"]["curves"]:
			var idx := fx.find_path(int(L["clip_root"]), String(c["path"]))
			if idx >= 0:
				curves.append([idx, String(c["attr"]), c])
	L["curves"] = curves
	var spans := {}
	for ctl: Array in spec.get("controls", []):
		var idx := fx.find_path(0, String(ctl[0]))
		if idx < 0:
			continue
		for j in fx.subtree(idx):
			spans[j] = [float(ctl[1]), float(ctl[2])]
	L["spans"] = spans
	var hidden := {}
	for p: String in spec.get("hide", []):
		var idx := fx.find_path(0, p)
		if idx >= 0:
			for j in fx.subtree(idx):
				hidden[j] = true
	L["hidden"] = hidden
	var dark := {}
	for p: String in spec.get("dark", []):
		var idx := fx.find_path(0, p)
		if idx >= 0:
			for j in fx.subtree(idx):
				dark[j] = true
	L["dark"] = dark
	return L


func _frame() -> void:
	for c: Control in [_back, _card, _front]:
		c.size = size
	var t := floorf(_t * HsFx.FPS) / HsFx.FPS
	for L: Dictionary in _layers:
		_render_layer(L, t)
	_render_card(t)


## Где карта на экране: миниатюра в MINI_SCALE раз с центром в точке place сценария.
func _card_rect() -> Rect2:
	var cs: Dictionary = _script["card"]
	var c := _project(cs["place"])
	var s := CardView.MINI_SIZE * MINI_SCALE
	return Rect2((Vector2(c.x, c.y) - s * 0.5).round(), s)


## «Горящая копия» нашей мелкой карты для Choice_Reveal: светлые линии по её макету
## (рамка, окно арта, черта у цены, буквы имени и цена) с ореолом и серой серединой —
## как устроена GenFX_AbilityCard_Echo_BW у HS (RGBR: яркость = альфа).
static func _echo_texture(face: Texture2D) -> Texture2D:
	var w := int(CardView.MINI_SIZE.x)
	var h := int(CardView.MINI_SIZE.y)
	var lines := PackedFloat32Array()
	lines.resize(w * h)
	var mark := func(x: int, y: int) -> void:
		if x >= 0 and y >= 0 and x < w and y < h:
			lines[y * w + x] = 1.0
	for x in w:
		mark.call(x, 0)
		mark.call(x, h - 1)
	for y in h:
		mark.call(0, y)
		mark.call(w - 1, y)
	# окно арта (tools/pixel_cards.gd render_mini: обводка от y=27, ширина 54)
	for x in range(2, 56):
		mark.call(x, 27)
		mark.call(x, 82)
	for y in range(27, 83):
		mark.call(2, y)
		mark.call(55, y)
	# черта между именем и ценой
	for y in range(2, 18):
		mark.call(50, y)
	# буквы имени и цена — светлые пиксели шапки
	if face != null:
		var img := face.get_image()
		img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		if img.get_size() == Vector2i(w, h):
			for y in range(1, 27):
				for x in range(1, w - 1):
					if img.get_pixel(x, y).get_luminance() > 0.7:
						mark.call(x, y)
	# сетка вдвое мельче пикселя карты: линии, ореол (размытие) и серая середина
	var k := 2
	var pad := Vector2i(roundi(w * k * (1.0 / ECHO_CARD.x - 1.0) * 0.5), roundi(h * k * (1.0 / ECHO_CARD.y - 1.0) * 0.5))
	var gw := w * k + pad.x * 2
	var gh := h * k + pad.y * 2
	var base := PackedFloat32Array()
	base.resize(gw * gh)
	for y in h * k:
		for x in w * k:
			base[(y + pad.y) * gw + x + pad.x] = lines[(y / k) * w + x / k]
	var glow := _box_blur(_box_blur(base, gw, gh, 3), gw, gh, 3)
	var out := Image.create(gw, gh, false, Image.FORMAT_RGBA8)
	for y in gh:
		for x in gw:
			var i := y * gw + x
			var inside := x >= pad.x and y >= pad.y and x < pad.x + w * k and y < pad.y + h * k
			var v := maxf(base[i], minf(glow[i] * 1.6, 0.85))
			if inside:
				v = maxf(v, 0.32)
			out.set_pixel(x, y, Color(v, v, v, 1.0))
	out.resize(gw * 3, gh * 3, Image.INTERPOLATE_BILINEAR)
	out.generate_mipmaps()
	return ImageTexture.create_from_image(out)


static func _own_texture(base: String, tex_name: String) -> Texture2D:
	if OWN_TEXTURES.has(tex_name):
		return load(OWN_TEXTURES[tex_name]) as Texture2D
	return HsFx._texture(base, tex_name)


## Размытие окном (2r+1) по строкам и столбцам.
static func _box_blur(src: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	var n := float(2 * r + 1)
	for y in h:
		for x in w:
			var s := 0.0
			for d in range(-r, r + 1):
				s += src[y * w + clampi(x + d, 0, w - 1)]
			tmp[y * w + x] = s / n
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		for x in w:
			var s := 0.0
			for d in range(-r, r + 1):
				s += tmp[clampi(y + d, 0, h - 1) * w + x]
			out[y * w + x] = s / n
	return out


## Карта: проявляется снизу вверх за полосой огня, стоит, гаснет.
func _render_card(t: float) -> void:
	var cs: Dictionary = _script["card"]
	var t0 := float(cs["reveal"])
	if t < t0:
		_card.show_card(null, Rect2(), 0.0, 1.0)
		return
	var shown := clampf((t - t0) / float(cs["sweep"]), 0.0, 1.0)
	var out_at := t0 + float(cs["sweep"]) + float(cs["hold"])
	var a := 1.0 - clampf((t - out_at) / float(cs["out"]), 0.0, 1.0)
	_card.show_card(_item["face"], _card_rect(), a, shown)


## Переопределения анимации узлов слоя в момент tau: узел -> {scale, position, enabled, props}.
func _clip_state(L: Dictionary, tau: float) -> Dictionary:
	var out := {}
	var clip: Dictionary = L["clip"]
	for cv: Array in L["curves"]:
		var idx: int = cv[0]
		var attr: String = cv[1]
		var v := HsFx.clip_value(clip, cv[2], tau)
		if not out.has(idx):
			out[idx] = {"props": {}}
		var o: Dictionary = out[idx]
		var dot := attr.rfind(".")
		var comp := attr.substr(dot + 1) if dot >= 0 else ""
		var base := attr.substr(0, dot) if dot >= 0 else attr
		var k := "xyzw".find(comp) if comp != "" else -1
		if base == "scale" or base == "position":
			if not o.has(base):
				var nd: Dictionary = (L["fx"] as HsFx).nodes[idx]
				o[base] = nd["scale"] if base == "scale" else nd["pos"]
			var vec: Vector3 = o[base]
			vec[k] = v
			o[base] = vec
		elif attr == "m_Enabled":
			o["enabled"] = v > 0.5
		elif attr.contains("#"):
			var name := attr.get_slice("#", 0)
			(o["props"] as Dictionary)[name + "/" + str(int(attr.get_slice("#", 1)) - 4)] = v
		elif k >= 0:
			(o["props"] as Dictionary)[base + "/" + str(k)] = v
		else:
			(o["props"] as Dictionary)[attr] = v
	return out


func _world(L: Dictionary, i: int, st: Dictionary, cache: Dictionary) -> Transform3D:
	if cache.has(i):
		return cache[i]
	var fx: HsFx = L["fx"]
	var nd: Dictionary = fx.nodes[i]
	var o: Dictionary = st.get(i, {})
	var xf: Transform3D
	if i == int(L["root"]):
		# корень слоя: свой мировой поворот и масштаб, место — из сценария или префаба
		var spec: Dictionary = L["spec"]
		var pos: Vector3 = spec.get("place", nd["pos"])
		xf = fx.local_xf(i, pos, o.get("scale", null))
	else:
		xf = _world(L, int(nd["parent"]), st, cache) * fx.local_xf(i, o.get("position", null), o.get("scale", null))
	cache[i] = xf
	return xf


## Узел включён: в префабе (с родителями) или его включила дорожка в эти секунды.
func _on(L: Dictionary, i: int, tau: float) -> bool:
	if (L["hidden"] as Dictionary).has(i):
		return false
	var spans: Dictionary = L["spans"]
	if spans.has(i):
		var s: Array = spans[i]
		return tau >= float(s[0]) and tau < float(s[1])
	var fx: HsFx = L["fx"]
	var j := i
	while j >= 0 and j != int(L["root"]):
		if not bool(fx.nodes[j]["active"]):
			return false
		j = int(fx.nodes[j]["parent"])
	return true


func _render_layer(L: Dictionary, t: float) -> void:
	var spec: Dictionary = L["spec"]
	var tau := t - float(spec["at"])
	var fx: HsFx = L["fx"]
	var drawers: Dictionary = L["drawers"]
	for d: _Drawer in drawers.values():
		d.clear()
	if tau >= 0.0:
		var st := _clip_state(L, tau)
		var cache := {}
		for i: int in L["nodes"]:
			var nd: Dictionary = fx.nodes[i]
			if not nd.has("shader") or not String(nd["shader"]).contains("CommonFX"):
				continue
			if not _on(L, i, tau) or _debug_skip(fx, i):
				continue
			var o: Dictionary = st.get(i, {})
			if not bool(o.get("enabled", true)):
				continue
			var m := _material(nd, o.get("props", {}))
			if (L["dark"] as Dictionary).has(i):
				m["color_mul"] = 0.0
			if OS.get_environment("HS_DEBUG") != "" and (nd["ps"] as Dictionary).is_empty():
				print("t=%.2f %s tex=%s alpha_mul=%s color_mul=%s df=%s vm=%s color=%s kw=%s" % [tau, nd["name"],
					m["main_tex"] != null, m["alpha_mul"], m["color_mul"], m["dissolve_factor"], m["vm_st"], m["color"], nd.get("keywords")])
			if m["main_tex"] == null:
				continue
			if String(m["main_tex"].resource_path).get_file().begins_with("GenFX_AbilityCard_Echo"):
				m["main_tex"] = _item["echo"]
			var d := _drawer(L, i)
			_apply(d, m, tau)
			if not (nd["ps"] as Dictionary).is_empty():
				_emit_particles(L, i, d, m, st, cache, tau)
			elif nd.has("geom"):
				var g: Dictionary = nd["geom"]
				_emit_mesh(d, m, _world(L, i, st, cache), g["verts"], g["uv"], g["colors"], g["tris"], tau)
			elif spec.has("only"):
				# «горящая копия» карты: квад на карту (кусок ECHO_CARD текстуры — на её рамку)
				var r := _card_rect()
				var big := r.size / ECHO_CARD
				var q := Rect2(r.get_center() - big * 0.5, big)
				_emit_screen_quad(d, m, q, tau)
			else:
				var g := _grid_quad()
				_emit_mesh(d, m, _world(L, i, st, cache), g[0], g[1], PackedColorArray(), g[2], tau)
	for d: _Drawer in drawers.values():
		d.commit()


func _drawer(L: Dictionary, i: int) -> _Drawer:
	var drawers: Dictionary = L["drawers"]
	if drawers.has(i):
		return drawers[i]
	var fx: HsFx = L["fx"]
	var d := _Drawer.new()
	d.node = i
	d.size = size
	var mat := ShaderMaterial.new()
	mat.shader = COMMON_SHADER
	d.material = mat
	var holder: Control = L["holder"]
	if String(fx.nodes[i]["name"]) in (L["spec"] as Dictionary).get("under", []):
		holder = L["under_holder"]
	var at := 0
	for c in holder.get_children():
		if (c as _Drawer).node < i:
			at += 1
	holder.add_child(d)
	holder.move_child(d, at)
	drawers[i] = d
	return d


# --- материал FX/CommonFX -------------------------------------------------------------

## Параметры материала узла с поправками анимации (props: "имя" или "имя/компонента").
func _material(nd: Dictionary, props: Dictionary) -> Dictionary:
	var floats: Dictionary = nd.get("floats", {})
	var colors: Dictionary = nd.get("colors", {})
	var texs: Dictionary = nd.get("textures", {})
	var F := func(n: String, def: float) -> float:
		return float(props.get(n, floats.get(n, def)))
	var C := func(n: String, def: Color = Color(0, 0, 0, 0)) -> Color:
		var c := HsFx._color(colors.get(n)) if colors.has(n) else def
		for k in 4:
			var key := n + "/" + str(k)
			if props.has(key):
				c[k] = float(props[key])
		return c
	var ST := func(n: String) -> Vector4:
		var td: Dictionary = texs.get(n, {})
		var sc: Dictionary = td.get("scale", {"x": 1.0, "y": 1.0})
		var of: Dictionary = td.get("offset", {"x": 0.0, "y": 0.0})
		var v := Vector4(float(sc["x"]), float(sc["y"]), float(of["x"]), float(of["y"]))
		for k in 4:
			var key := n + "_ST/" + str(k)
			if props.has(key):
				v[k] = float(props[key])
		return v
	var kw: Array = nd.get("keywords", [])
	var base := String(nd.get("tex_base", ""))
	var main := String((texs.get("_MainTex", {}) as Dictionary).get("tex", ""))
	var second := String((texs.get("_SecondTex", {}) as Dictionary).get("tex", ""))
	var second_mode := 0
	if "_SECONDTEXTURE_MASK" in kw:
		second_mode = 1
	elif "_SECONDTEXTURE_ADD" in kw:
		second_mode = 2
	elif "_SECONDTEXTURE_NOISEUV" in kw:
		second_mode = 3
	var dissolve := 1 if "_DISSOLVE_MAINALPHA" in kw else (2 if "_DISSOLVE_SECONDALPHA" in kw else 0)
	var m := {
		"main_tex": _own_texture(base, main),
		"second_tex": _own_texture(base, second) if second != "" and (second_mode > 0 or dissolve == 2) else null,
		"rgbr": not ("_TEXTURETYPE_RGBA" in kw), "ramp": "_COLORING_RAMP" in kw,
		"second_mode": second_mode, "dissolve": dissolve,
		"scrolling": "_SCROLLING_ON" in kw, "global_uv": "_SECONDTEXGLOBALUV_ON" in kw,
		"rotation": "_SECONDTEXROTATION_ON" in kw, "vmask": "_VERTEXMASK_ON" in kw,
		"color": C.call("_Color", Color.WHITE), "main_st": ST.call("_MainTex"), "second_st": ST.call("_SecondTex"),
		"swap": F.call("_SwapUV", 0.0), "second_swap": F.call("_SecondTexSwapUV", 0.0),
		"scroll": C.call("_ScrollingSpeed"), "second_speed": C.call("_SecondTexSpeed_NoiseForce"),
		"rot_speed": F.call("_SecondTexRotSpeed", 0.0), "init_rot": F.call("_SecondTexInitRot", 0.0),
		"color2": C.call("_Color2", Color.WHITE), "color_mul2": F.call("_ColorMul2", 1.0),
		"white": C.call("_WhiteColor"), "mid": C.call("_MidColor"), "last": C.call("_LastColor"),
		"mid_pos": F.call("_MiddlePointPos", 0.5), "color_mul": F.call("_ColorMul", 1.0),
		"color_add": F.call("_ColorAdd", 0.0), "alpha_mul": F.call("_AlphaMul", 1.0),
		"premul": F.call("_PremultipliedRGBTexture", 1.0), "clamp_uv": F.call("_ClampUV", 0.0),
		"second_clamp": F.call("_SecondTexClampUV", 0.0), "dissolve_factor": F.call("_DissolveFactor", 0.0),
		"smooth": F.call("_DissolveSmoothness", 0.1), "min_alpha": F.call("_MinAlpha", 0.0),
		"ignore_va": F.call("_IgnoreVertexAlpha", 0.0), "vm_alpha_mul": F.call("_VertexMaskAlphaMul", 1.0),
		"vm_st": C.call("_VertexMaskUVScaleOffset", Color(1, 1, 0, 0)),
		"vm_grad": C.call("_VertexMaskLinearGradient", Color(1, 1, 1, 1)),
	}
	return m


func _apply(d: _Drawer, m: Dictionary, tau: float) -> void:
	var mat: ShaderMaterial = d.material
	d.tex = m["main_tex"]
	mat.set_shader_parameter("main_tex", m["main_tex"])
	mat.set_shader_parameter("linear_space", not GAMMA)
	mat.set_shader_parameter("gamma_clip", GAMMA_CLIP)
	mat.set_shader_parameter("has_second", m["second_tex"] != null)
	if m["second_tex"] != null:
		mat.set_shader_parameter("second_tex", m["second_tex"])
	mat.set_shader_parameter("rgbr", m["rgbr"])
	mat.set_shader_parameter("ramp", m["ramp"])
	mat.set_shader_parameter("second_mode", m["second_mode"])
	mat.set_shader_parameter("dissolve", m["dissolve"])
	mat.set_shader_parameter("clamp_uv", m["clamp_uv"])
	mat.set_shader_parameter("second_clamp", m["second_clamp"])
	var sp: Color = m["second_speed"]
	mat.set_shader_parameter("noise_force", Vector2(sp.b, sp.a))
	mat.set_shader_parameter("color_mul", m["color_mul"])
	mat.set_shader_parameter("color_add", m["color_add"])
	mat.set_shader_parameter("premul", m["premul"])
	for k: String in ["white", "mid", "last"]:
		var c: Color = m[k]
		mat.set_shader_parameter(k + "_color", Vector3(c.r, c.g, c.b))
	mat.set_shader_parameter("mid_pos", m["mid_pos"])
	var c2: Color = m["color2"]
	mat.set_shader_parameter("color2", Vector4(c2.r, c2.g, c2.b, c2.a))
	mat.set_shader_parameter("color_mul2", m["color_mul2"])
	mat.set_shader_parameter("dissolve_factor", m["dissolve_factor"])
	mat.set_shader_parameter("smoothness", m["smooth"])
	mat.set_shader_parameter("fade", 1.0 - clampf((_t - (float(_script["len"]) - 0.5)) / 0.5, 0.0, 1.0))


## Цвет материала Unity: при счёте в гамме — как есть, иначе rgb из sRGB в линейный.
static func _lin(c: Color) -> Color:
	if GAMMA:
		return c
	return Color(pow(c.r, 2.2), pow(c.g, 2.2), pow(c.b, 2.2), c.a)


## Вершинная часть FX/CommonFX (по коду вершинного шейдера): uv, world — точка в мире,
## vcol — цвет вершины. -> [uv основной, CUSTOM0 (uv второй, порог, альфа вершины),
## цвет o3, CUSTOM1 (второй цвет o2)].
static func _vertex(m: Dictionary, uv: Vector2, world: Vector3, vcol: Color, time2: float) -> Array:
	var st: Vector4 = m["main_st"]
	var muv := Vector2(uv.x * st.x + st.z, uv.y * st.y + st.w)
	muv = muv.lerp(Vector2(muv.y, muv.x), float(m["swap"]))
	var scroll: Color = m["scroll"]
	if m["scrolling"]:
		muv += Vector2(fposmod(time2 * scroll.r, 1.0), fposmod(time2 * scroll.g, 1.0))
	var sst: Vector4 = m["second_st"]
	var base := Vector2(world.x, world.z) if m["global_uv"] else uv
	var suv := Vector2(base.x * sst.x + sst.z, base.y * sst.y + sst.w)
	suv = suv.lerp(Vector2(suv.y, suv.x), float(m["second_swap"]))
	var sp: Color = m["second_speed"]
	suv += Vector2(fposmod(time2 * sp.r, 1.0), fposmod(time2 * sp.g, 1.0))
	if m["rotation"]:
		var half := Vector2(sst.x, sst.y) * 0.5
		suv -= half
		var ang := float(m["rot_speed"]) * time2 - float(m["init_rot"]) * 0.017453
		var cs := cos(ang)
		var sn := sin(ang)
		suv = Vector2(cs * suv.x + sn * suv.y, -sn * suv.x + cs * suv.y) + half
	var mask := 1.0
	if m["vmask"]:
		var vm: Color = m["vm_st"]
		var u2 := Vector2(uv.x * vm.r + vm.b, uv.y * vm.g + vm.a)
		var g: Color = m["vm_grad"]
		var grad := lerpf(lerpf(g.r, g.g, u2.x), lerpf(g.b, g.a, u2.x), u2.y)
		var e := u2 * 2.0 - Vector2.ONE
		var radial := clampf((1.0 - e.dot(e)) * float(m["vm_alpha_mul"]), 0.0, 1.0)
		mask = clampf(grad * radial, 0.0, 1.0)
	var va := vcol.a * mask
	var aa := maxf(va, float(m["ignore_va"]))
	var col: Color = _lin(m["color"])
	var rgb := Vector3(vcol.r * col.r, vcol.g * col.g, vcol.b * col.b)
	var second_alpha := int(m["dissolve"]) == 2
	var k := (col.a if second_alpha else aa * col.a) * float(m["alpha_mul"])
	var bright := clampf(maxf(rgb.x, maxf(rgb.y, rgb.z)) * 2.0 - 1.0, 0.0, 1.0)
	var o3 := Color(2.0 * rgb.x * k, 2.0 * rgb.y * k, 2.0 * rgb.z * k, (1.0 - bright) * k)
	var smooth := float(m["smooth"])
	var thr := maxf(float(m["dissolve_factor"]) * 1.01, 1.0 - va - float(m["min_alpha"])) * (2.0 * smooth + 1.0) - smooth
	var o2 := Color(0, 0, 0, 0)
	if int(m["second_mode"]) == 2:
		var c2: Color = _lin(m["color2"])
		var rgb2 := Vector3(vcol.r * c2.r, vcol.g * c2.g, vcol.b * c2.b)
		var a2 := aa * c2.a
		var b2 := clampf(maxf(rgb2.x, maxf(rgb2.y, rgb2.z)) * 2.0 - 1.0, 0.0, 1.0)
		var cm2 := float(m["color_mul2"])
		o2 = Color(2.0 * rgb2.x * cm2 * a2, 2.0 * rgb2.y * cm2 * a2, 2.0 * rgb2.z * cm2 * a2, (1.0 - b2) * a2)
	return [muv, Color(suv.x, suv.y, thr, aa if second_alpha else 0.0), o3, o2]


func _emit_mesh(d: _Drawer, m: Dictionary, xf: Transform3D, verts: PackedVector3Array, uvs: PackedVector2Array,
		cols: PackedColorArray, tris: PackedInt32Array, tau: float) -> void:
	var base := d.points.size()
	var behind := PackedByteArray()
	for k in verts.size():
		var w := xf * verts[k]
		var p := _project(w)
		behind.append(1 if (w - CAM_POS).dot(CAM_FWD) < 0.3 else 0)
		var vs := _vertex(m, uvs[k] if k < uvs.size() else Vector2.ZERO, w,
			cols[k] if k < cols.size() else Color.WHITE, tau * 2.0)
		d.add_vertex(Vector2(p.x, p.y), vs[0], vs[2], vs[1], vs[3])
	for k in range(0, tris.size() - 2, 3):
		if behind[tris[k]] + behind[tris[k + 1]] + behind[tris[k + 2]] == 0:
			d.indices.append_array([base + tris[k], base + tris[k + 1], base + tris[k + 2]])


## Плоскость сеткой GRID x GRID: маска по вершинам считается в вершинах, и на четырёх
## углах она нулевая — нужна сетка, как у мешей Hearthstone.
const GRID := 16


## Квад 1x1 Unity (плоскость XY, UV 0..1) сеткой: [вершины, uv, индексы].
static func _grid_quad() -> Array:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for y in GRID + 1:
		for x in GRID + 1:
			var u := Vector2(float(x) / GRID, float(y) / GRID)
			uvs.append(u)
			verts.append(Vector3(u.x - 0.5, u.y - 0.5, 0.0))
	for y in GRID:
		for x in GRID:
			var a := y * (GRID + 1) + x
			idx.append_array([a, a + 1, a + GRID + 2, a, a + GRID + 2, a + GRID + 1])
	return [verts, uvs, idx]


func _emit_screen_quad(d: _Drawer, m: Dictionary, r: Rect2, tau: float) -> void:
	var g := _grid_quad()
	var base := d.points.size()
	for k in (g[1] as PackedVector2Array).size():
		var u: Vector2 = g[1][k]
		var p := Vector2(r.position.x + u.x * r.size.x, r.end.y - u.y * r.size.y)
		var vs := _vertex(m, u, Vector3.ZERO, Color.WHITE, tau * 2.0)
		d.add_vertex(p, vs[0], vs[2], vs[1], vs[3])
	for k: int in g[2]:
		d.indices.append(base + k)


func _emit_particles(L: Dictionary, i: int, d: _Drawer, m: Dictionary, st: Dictionary, cache: Dictionary, tau: float) -> void:
	var fx: HsFx = L["fx"]
	var nd: Dictionary = fx.nodes[i]
	var spec: Dictionary = L["spec"]
	var span: Array = (L["spans"] as Dictionary).get(i, [0.0, INF])
	var play := 0.0 if bool(spec.get("play_all", false)) else float(span[0])
	var xf_at := func(_time: float) -> Transform3D:
		return _world(L, i, st, cache)
	var parts := fx.particles(i, play, float(span[1]), tau, xf_at)
	if OS.get_environment("HS_DEBUG") != "" and not parts.is_empty():
		var avg := Vector3.ZERO
		for p: Dictionary in parts:
			avg += p["p"]
		var xf: Transform3D = xf_at.call(tau)
		print("t=%.2f %s n=%d emitter=%s avg=%s basis=%s" % [tau, nd["name"], parts.size(), xf.origin, avg / parts.size(), xf.basis])
	var tiles := fx.tiles(i)
	var mode := int(nd["render_mode"])
	for p: Dictionary in parts:
		var pos: Vector3 = p["p"]
		var size := float(p["size"])
		var f := int(p["frame"])
		# кусок раскадровки в UV Unity: кадр 0 — левый верхний
		var col_i := f % tiles.x
		var row_i := f / tiles.x
		var u0 := float(col_i) / tiles.x
		var u1 := float(col_i + 1) / tiles.x
		var v1 := 1.0 - float(row_i) / tiles.y
		var v0 := 1.0 - float(row_i + 1) / tiles.y
		var uvs := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
		var corners: Array = []
		var rot := float(p["rot"])
		if mode == 2:
			# горизонтальный (лежит на земле): углы в мире, поворот вокруг вертикали
			var h := size * 0.5
			for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var rc := c.rotated(-rot) * h
				var w := pos + Vector3(rc.x, 0.0, rc.y)
				var sp := _project(w)
				corners.append(Vector2(sp.x, sp.y))
		elif mode == 1:
			# вытянутый по скорости: длина = размер x lengthScale + скорость x velocityScale
			var vel: Vector3 = p["v"]
			var dir := vel.normalized() if vel.length() > 1e-4 else Vector3(0, 0, 1)
			var length := size * float(nd.get("length_scale", 2.0)) + vel.length() * float(nd.get("velocity_scale", 0.0))
			var a := _project(pos)
			var b := _project(pos - dir * length)
			var axis := Vector2(b.x - a.x, b.y - a.y)
			var side := axis.orthogonal().normalized() * size * 0.5 * _px_per_unit(a.z)
			var a2 := Vector2(a.x, a.y)
			corners = [a2 - side, a2 + side, a2 + side + axis, a2 - side + axis]
		else:
			var c := _project(pos)
			var half := size * 0.5 * _px_per_unit(c.z)
			for k: Vector2 in [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				corners.append(Vector2(c.x, c.y) + (k * half).rotated(-rot))
		var base := d.points.size()
		for k in 4:
			var vs := _vertex(m, uvs[k], pos, p["col"], tau * 2.0)
			d.add_vertex(corners[k], vs[0], vs[2], vs[1], vs[3])
		d.indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


# --- слои отрисовки ------------------------------------------------------------------

## Слой одного узла: свой материал CommonFX; кадр — 2D-меш (вершины, UV, цвет, CUSTOM0/1).
class _Drawer extends Control:
	var node := -1
	var tex: Texture2D
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var custom0 := PackedFloat32Array()
	var custom1 := PackedFloat32Array()
	var indices := PackedInt32Array()
	var _mesh := ArrayMesh.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func clear() -> void:
		points.clear()
		uvs.clear()
		colors.clear()
		custom0.clear()
		custom1.clear()
		indices.clear()

	func add_vertex(p: Vector2, uv: Vector2, col: Color, c0: Color, c1: Color) -> void:
		points.append(p.round())
		uvs.append(uv)
		# HDR 2D сам переводит цвет вершины из sRGB в линейный — отдаём его в sRGB, чтобы
		# в шейдер пришло ровно посчитанное (o3); альфа не переводится
		colors.append(Color(_to_srgb(col.r), _to_srgb(col.g), _to_srgb(col.b), col.a))
		custom0.append_array([c0.r, c0.g, c0.b, c0.a])
		custom1.append_array([c1.r, c1.g, c1.b, c1.a])

	static func _to_srgb(c: float) -> float:
		if c <= 0.0031308:
			return maxf(c, 0.0) * 12.92
		return 1.055 * pow(c, 1.0 / 2.4) - 0.055

	func commit() -> void:
		_mesh.clear_surfaces()
		if not indices.is_empty():
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = points
			arr[Mesh.ARRAY_TEX_UV] = uvs
			arr[Mesh.ARRAY_COLOR] = colors
			arr[Mesh.ARRAY_CUSTOM0] = custom0
			arr[Mesh.ARRAY_CUSTOM1] = custom1
			arr[Mesh.ARRAY_INDEX] = indices
			var fmt := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
				| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) | Mesh.ARRAY_FLAG_USE_2D_VERTICES
			_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt)
		queue_redraw()

	func _draw() -> void:
		if tex != null and _mesh.get_surface_count() > 0:
			draw_mesh(_mesh, tex)


## Карта: видна нижняя часть shown (0..1) — огонь проявляет её снизу вверх.
class _CardLayer extends Control:
	var _face: Texture2D
	var _rect := Rect2()
	var _alpha := 0.0
	var _shown := 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
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
