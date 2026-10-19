class_name HsPlay
extends Control

## Розыгрыш карты в духе Hearthstone (решения владельца 2026-10-19): без витрины и без
## затемнения; нажатую карту рука прячет сразу, и начинается эффект — префабы Hearthstone
## (HsFx: частицы, меши, анимации, материалы FX/CommonFX), перенесённые из Unity, по их
## же сценарию (Timeline / анимация). После «акта появления» в центре доски на секунду
## встаёт полноформатная карта (горящее появление Hearthstone), гаснет — и только потом
## игра показывает действия карты (released).
##
## Пиксель-арт: всё рисуется в сетке игры 960x540, кадры ступенями (HsFx.FPS), шейдеры
## дают прозрачность и цвет ступенями с узором Байера.

## Акт появления закончился, карта погасла: можно показывать действия и вопросы.
signal released
## Толчок доски (сила в пикселях, BoardPanel.shake).
signal shake(power: float)

const PARTICLE_SHADER := preload("res://scenes/ui/hs_fx/hs_particle.gdshader")
const COMMON_SHADER := preload("res://scenes/ui/hs_fx/hs_commonfx.gdshader")
## Проекция мира Hearthstone (камера над центром доски, перспектива): ширина доски в
## единицах (AOE_full_mesh), высота камеры над доской (что выше — крупнее и дальше от центра).
const BOARD_UNITS := 13.45
const CAMERA := 14.0
## Кусок текстуры «горящей копии» карты (GenFX_AbilityCard_Echo_BW), занятый картой.
const ECHO_CARD := Vector2(0.55, 0.76)

## Карта -> сценарий.
const RECIPES := {"48426": "worldbreaker"}
## Сценарий: len — длина; layers — префабы: fx, at (секунда старта), anchor ("board" —
## центр доски, "card" — карта в центре), clip (анимация) и clip_root (путь аниматора),
## only (рисовать только это поддерево), controls — [путь, с, по] (дорожки Timeline:
## объект включён и его частицы идут только в эти секунды), play_all — все частицы с
## начала слоя. card — горящее появление карты: reveal (секунда), sweep (линия огня
## проходит карту), hold (карта стоит), out (гаснет). cues — звуки, shakes — толчки.
const SCRIPTS := {
	# Deathwing, Worldbreaker (CATA_190h): CATAFX_Deathwing_CustomSummon_Spell (тень
	# пролетает над доской, дракон пикирует и врезается — огненная волна, вспышка,
	# дым, угли) и CATAFX_Deathwing_Choice_Reveal (карта проявляется полосой огня).
	"worldbreaker": {"len": 4.9,
		"layers": [
			{"fx": "worldbreaker/summon", "at": 0.0, "anchor": "board",
				"clip": "worldbreaker/summon_anim", "clip_root": "TimelineRoot/AnimRoot",
				"controls": [["TimelineRoot/AnimRoot/TrailRoot/PS_Embers", 0.0, 6.0],
					["TimelineRoot/AnimRoot/TrailRoot/PS_Smoke", 0.067, 4.167],
					["TimelineRoot/AnimRoot/HeroRoot/PS_BurstFlames", 1.133, 4.717]],
				"hide": ["TimelineRoot/AnimRoot/HeroRoot/TokenRoot"]},
			{"fx": "worldbreaker/reveal", "at": 2.2, "anchor": "card",
				"clip": "worldbreaker/reveal_anim", "clip_root": "Root/Bursts_Root/Burst0_New",
				"only": "Root/Bursts_Root/Burst0_New", "play_all": true},
		],
		"card": {"reveal": 2.2, "sweep": 0.5, "hold": 1.0, "out": 0.35},
		"cues": [[0.0, "CATA_190h_Enter_01"], [0.0, "CATA_190h_Enter_Dragon_01"], [0.85, "CATA_190h_Enter_02"],
			[1.0, "CATA_190h_Enter_Dragon_02"], [2.2, "CATA_190h_CardReveal_01"]],
		"shakes": [[0.0, 3.0], [1.133, 5.0]]},
}

## Для снимков: шаг времени за кадр (0 — настоящее время).
static var fixed_dt := 0.0
## Отладка (tools/hs_preview.gd): рисовать только узлы с этими именами (через запятую)
## и их потомков.
static var debug_only := ""
static var _shaders: Dictionary = {}

var board_area: Control
var _queue: Array[Dictionary] = []
var _item: Dictionary = {}
var _t := 0.0
var _released := false
var _cue_t := -1.0
var _script: Dictionary = {}
var _layers: Array[Dictionary] = []

var _back := Control.new()
var _card := _CardLayer.new()
var _front := Control.new()


static func has(cid: String) -> bool:
	return RECIPES.has(cid)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: Control in [_back, _card, _front]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
	visible = false


## Разыграть карту cid: face — её лицо, quiet — чужая (тише).
func play(cid: String, face: Texture2D, quiet: bool = false) -> void:
	if not has(cid):
		return
	_queue.append({"cid": cid, "face": face, "quiet": quiet})
	if _item.is_empty():
		_next()


## Идёт ли розыгрыш, который ещё держит действия карты.
func is_busy() -> bool:
	return not _item.is_empty() and not _released


func _next() -> void:
	for layer: Control in [_back, _front]:
		for c in layer.get_children():
			c.queue_free()
	_layers.clear()
	if _queue.is_empty():
		_item = {}
		visible = false
		set_process(false)
		return
	_item = _queue.pop_front()
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


func _board_rect() -> Rect2:
	if board_area == null:
		return Rect2(Vector2.ZERO, size)
	var r := board_area.get_global_rect()
	r.position -= get_global_position()
	return r


# --- слой (один префаб) --------------------------------------------------------------

func _make_layer(spec: Dictionary) -> Dictionary:
	var fx := HsFx.load_fx(String(spec["fx"]))
	var L := {"spec": spec, "fx": fx, "drawers": {}, "holder": Control.new(), "under": Control.new()}
	var holder: Control = L["holder"]
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_front if String(spec["anchor"]) == "card" else _back).add_child(holder)
	# подложки (Backer) — под картой
	var under: Control = L["under"]
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.add_child(under)
	var root := 0
	if spec.has("only"):
		root = fx.find_path(0, String(spec["only"]))
	L["root"] = root
	L["nodes"] = fx.subtree(root)
	L["clip"] = HsFx.load_clip(String(spec["clip"])) if spec.has("clip") else {}
	L["clip_root"] = fx.find_path(0, String(spec.get("clip_root", "")))
	# кривые анимации -> узлы
	var curves: Array = []
	if not (L["clip"] as Dictionary).is_empty():
		for c: Dictionary in L["clip"]["curves"]:
			var idx := fx.find_path(int(L["clip_root"]), String(c["path"]))
			if idx >= 0:
				curves.append([idx, String(c["attr"]), c])
	L["curves"] = curves
	# дорожки включения: узел -> [с, по] для него и всех его потомков
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
	return L


var _origin := Vector2.ZERO
var _scale := 40.0


func _to_screen(p: Vector3) -> Vector2:
	return _origin + Vector2(p.x, -p.z) * _scale * _persp(p.y)


static func _persp(y: float) -> float:
	return CAMERA / maxf(CAMERA - y, 1.0)


func _frame() -> void:
	var br := _board_rect()
	_origin = br.get_center().round()
	_scale = br.size.x / BOARD_UNITS
	for c: Control in [_back, _card, _front]:
		c.size = size
	var t := floorf(_t * HsFx.FPS) / HsFx.FPS
	for L: Dictionary in _layers:
		_render_layer(L, t)
	_render_card(t)


## Карта в центре доски: проявляется снизу вверх за полосой огня, стоит, гаснет.
func _render_card(t: float) -> void:
	var cs: Dictionary = _script["card"]
	var t0 := float(cs["reveal"])
	if t < t0:
		_card.show_card(null, Rect2(), 0.0, 1.0)
		return
	var big := CardView.PIXEL_SIZE
	var r := Rect2((_origin - big * 0.5).round(), big)
	var shown := clampf((t - t0) / float(cs["sweep"]), 0.0, 1.0)
	var out_at := t0 + float(cs["sweep"]) + float(cs["hold"])
	var a := 1.0 - clampf((t - out_at) / float(cs["out"]), 0.0, 1.0)
	_card.show_card(_item["face"], r, a, shown)


## Переопределения анимации узлов слоя в момент tau: узел -> {scale, pos, enabled, props}.
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
			# цвет: #4..#7 — r, g, b, a
			var name := attr.get_slice("#", 0)
			var ci := int(attr.get_slice("#", 1)) - 4
			(o["props"] as Dictionary)[name + "/" + str(ci)] = v
		elif k >= 0:
			(o["props"] as Dictionary)[base + "/" + str(k)] = v
		else:
			(o["props"] as Dictionary)[attr] = v
	return out


func _world(L: Dictionary, i: int, st: Dictionary, cache: Dictionary) -> Transform3D:
	if cache.has(i):
		return cache[i]
	var fx: HsFx = L["fx"]
	var xf: Transform3D
	if i == int(L["root"]):
		xf = _anchor(L)
	else:
		var o: Dictionary = st.get(i, {})
		var local := fx.local_xf(i, o.get("position", null), o.get("scale", null))
		xf = _world(L, int(fx.nodes[i]["parent"]), st, cache) * local
	cache[i] = xf
	return xf


## Где корень слоя в мире: место героя (у Hearthstone эффект стоит на портрете героя —
## низ доски, HERO_Z от центра), или (карта) так, чтобы карта в его пространстве
## (по z от -2.41 до 2.41) легла на карту в центре экрана.
const HERO_Z := -3.0


func _anchor(L: Dictionary) -> Transform3D:
	if String((L["spec"] as Dictionary)["anchor"]) == "card":
		var k := CardView.PIXEL_SIZE.y * 0.5 / (2.41 * _scale)
		return Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO)
	return Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, HERO_Z))


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
		d.quads.clear()
		d.tris.clear()
	if tau < 0.0:
		for d: _Drawer in drawers.values():
			d.queue_redraw()
		return
	var st := _clip_state(L, tau)
	var cache := {}
	for i: int in L["nodes"]:
		var nd: Dictionary = fx.nodes[i]
		if not nd.has("shader") or not _on(L, i, tau) or _debug_skip(fx, i):
			continue
		var o: Dictionary = st.get(i, {})
		if not bool(o.get("enabled", true)):
			continue
		var props: Dictionary = o.get("props", {})
		if not (nd["ps"] as Dictionary).is_empty():
			var span: Array = (L["spans"] as Dictionary).get(i, [0.0, INF])
			var play := float(span[0]) if not bool(spec.get("play_all", false)) else 0.0
			var xf_at := func(_time: float) -> Transform3D:
				return _world(L, i, st, cache)
			var parts := fx.particles(i, play, float(span[1]), tau, xf_at)
			if parts.is_empty():
				continue
			var d := _drawer(L, i, props, tau, false)
			var tex: Texture2D = d.tex
			if tex == null:
				continue
			var tiles := fx.tiles(i)
			var cell := Vector2(tex.get_size()) / Vector2(tiles)
			var max_px := float(nd.get("max_size", 0.5)) * 540.0
			var mode := int(nd["render_mode"])
			for p: Dictionary in parts:
				var pos: Vector3 = p["p"]
				var px := clampf(float(p["size"]) * _scale * _persp(pos.y), 1.0, max_px)
				var f := int(p["frame"])
				var src := Rect2(Vector2(f % tiles.x, f / tiles.x) * cell, cell)
				var rot := -float(p["rot"])
				var sz := Vector2(px, px)
				if mode == 1:
					# вытянутая по скорости
					var vel: Vector3 = p["v"]
					var sv := _to_screen(pos + vel * 0.05) - _to_screen(pos)
					sv *= 20.0
					rot = sv.angle() + PI * 0.5
					sz.y = px * float(nd.get("length_scale", 2.0)) + sv.length() * float(nd.get("velocity_scale", 0.0))
				d.quads.append([_to_screen(pos).round(), sz.round(), rot, p["col"], src])
		elif nd.has("geom"):
			var d := _drawer(L, i, props, tau, true)
			var g: Dictionary = nd["geom"]
			var xf := _world(L, i, st, cache)
			var pts := PackedVector2Array()
			var behind := PackedByteArray()
			for v: Vector3 in g["verts"]:
				var w := xf * v
				pts.append(_to_screen(w).round())
				behind.append(1 if w.y > CAMERA - 1.5 else 0)
			# треугольники у самой камеры и за ней не рисуются
			var idx: PackedInt32Array = g["tris"]
			var keep := PackedInt32Array()
			for k in range(0, idx.size() - 2, 3):
				if behind[idx[k]] + behind[idx[k + 1]] + behind[idx[k + 2]] == 0:
					keep.append_array([idx[k], idx[k + 1], idx[k + 2]])
			d.tris.append([keep, pts, g["colors"], g["uv"]])
		else:
			# плоскость без выгруженной геометрии — квад Unity 1x1 (XY)
			var d := _drawer(L, i, props, tau, true)
			var xf := _world(L, i, st, cache)
			var pts := PackedVector2Array()
			for c: Vector3 in [Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)]:
				pts.append(_to_screen(xf * c).round())
			if String(spec["anchor"]) == "card":
				pts = _echo_quad()
			var w := Color.WHITE
			d.tris.append([PackedInt32Array([0, 1, 2, 0, 2, 3]), pts, PackedColorArray([w, w, w, w]),
				PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])])
	for d: _Drawer in drawers.values():
		d.queue_redraw()


## Квад «горящей копии» карты: карта текстуры (ECHO_CARD) ложится на карту в центре.
func _echo_quad() -> PackedVector2Array:
	var big := CardView.PIXEL_SIZE / ECHO_CARD
	var r := Rect2((_origin - big * 0.5).round(), big.round())
	return PackedVector2Array([Vector2(r.position.x, r.end.y), r.end, Vector2(r.end.x, r.position.y), r.position])


func _drawer(L: Dictionary, i: int, props: Dictionary, tau: float, mesh: bool) -> _Drawer:
	var drawers: Dictionary = L["drawers"]
	var fx: HsFx = L["fx"]
	var nd: Dictionary = fx.nodes[i]
	var d: _Drawer
	if drawers.has(i):
		d = drawers[i]
	else:
		d = _Drawer.new()
		d.node = i
		d.size = size
		var mat := ShaderMaterial.new()
		var common := String(nd.get("shader", "")).contains("CommonFX")
		mat.shader = COMMON_SHADER if common else _particle_shader(int(nd.get("blend", HsFx.Blend.MIX)))
		d.material = mat
		d.common = common
		var holder: Control = L["under"] if String(nd["name"]).contains("Backer") else L["holder"]
		var at := 0
		for c in holder.get_children():
			if (c as _Drawer).node < i:
				at += 1
		holder.add_child(d)
		holder.move_child(d, at)
		drawers[i] = d
	var mat: ShaderMaterial = d.material
	if d.common:
		_common_params(mat, nd, props, tau, mesh)
		d.tex = mat.get_shader_parameter("main_tex")
	else:
		d.tex = nd.get("tex")
		mat.set_shader_parameter("alpha_mode", int(nd.get("alpha_mode", 0)))
		mat.set_shader_parameter("kind", 2 if int(nd.get("blend", 0)) == HsFx.Blend.MUL else 0)
	return d


static func _particle_shader(blend: int) -> Shader:
	if not _shaders.has(blend):
		var s := Shader.new()
		var mode := "blend_add" if blend == HsFx.Blend.ADD else ("blend_mul" if blend == HsFx.Blend.MUL else "blend_mix")
		s.code = PARTICLE_SHADER.code.replace("render_mode blend_mix;", "render_mode %s;" % mode)
		_shaders[blend] = s
	return _shaders[blend]


## Параметры шейдера CommonFX из материала узла и анимации (props: "имя" или "имя/компонента").
func _common_params(mat: ShaderMaterial, nd: Dictionary, props: Dictionary, tau: float, mesh: bool) -> void:
	var floats: Dictionary = nd.get("floats", {})
	var colors: Dictionary = nd.get("colors", {})
	var texs: Dictionary = nd.get("textures", {})
	var F := func(n: String, def: float) -> float:
		return float(props.get(n, floats.get(n, def)))
	var C := func(n: String) -> Color:
		var c := HsFx._color(colors.get(n)) if colors.has(n) else Color(0, 0, 0, 0)
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
	var base := String(nd.get("tex_base", ""))
	var main := String((texs.get("_MainTex", {}) as Dictionary).get("tex", ""))
	var second := String((texs.get("_SecondTex", {}) as Dictionary).get("tex", ""))
	mat.set_shader_parameter("main_tex", HsFx._texture(base, main))
	# режимы шейдера — по его ключевым словам (как их включил материал)
	var kw: Array = nd.get("keywords", [])
	var second_mode := 0
	if "_SECONDTEXTURE_MASK" in kw:
		second_mode = 1
	elif "_SECONDTEXTURE_ADD" in kw:
		second_mode = 2
	elif "_SECONDTEXTURE_NOISEUV" in kw:
		second_mode = 3
	var dissolve := 1 if "_DISSOLVE_MAINALPHA" in kw else (2 if "_DISSOLVE_SECONDALPHA" in kw else 0)
	var use_second: bool = (second_mode > 0 or dissolve == 2) and second != ""
	mat.set_shader_parameter("has_second", use_second)
	if use_second:
		mat.set_shader_parameter("second_tex", HsFx._texture(base, second))
	mat.set_shader_parameter("unity_uv", mesh)
	mat.set_shader_parameter("main_st", ST.call("_MainTex"))
	var scr: Color = C.call("_ScrollingSpeed")
	mat.set_shader_parameter("scroll", Vector2(scr.r, scr.g) * (1.0 if "_SCROLLING_ON" in kw else 0.0))
	mat.set_shader_parameter("clamp_uv", F.call("_ClampUV", 0.0) > 0.0)
	mat.set_shader_parameter("second_st", ST.call("_SecondTex"))
	var sn: Color = C.call("_SecondTexSpeed_NoiseForce")
	mat.set_shader_parameter("second_speed", Vector2(sn.r, sn.g))
	mat.set_shader_parameter("noise_force", sn.b)
	mat.set_shader_parameter("second_mode", second_mode)
	mat.set_shader_parameter("dissolve", dissolve)
	mat.set_shader_parameter("dissolve_factor", F.call("_DissolveFactor", 0.0))
	mat.set_shader_parameter("dissolve_smooth", F.call("_DissolveSmoothness", 0.1))
	var coloring: bool = "_COLORING_RAMP" in kw
	mat.set_shader_parameter("coloring", coloring)
	mat.set_shader_parameter("white_color", C.call("_WhiteColor"))
	mat.set_shader_parameter("mid_color", C.call("_MidColor"))
	mat.set_shader_parameter("last_color", C.call("_LastColor"))
	mat.set_shader_parameter("mid_pos", F.call("_MiddlePointPos", 0.5))
	mat.set_shader_parameter("tint", Color.WHITE if coloring else C.call("_Color"))
	mat.set_shader_parameter("color_mul", F.call("_ColorMul", 1.0))
	mat.set_shader_parameter("color_add", F.call("_ColorAdd", 0.0))
	mat.set_shader_parameter("alpha_mul", F.call("_AlphaMul", 1.0))
	mat.set_shader_parameter("min_alpha", F.call("_MinAlpha", 0.0))
	mat.set_shader_parameter("vmask", "_VERTEXMASK_ON" in kw)
	var vm: Color = C.call("_VertexMaskUVScaleOffset")
	mat.set_shader_parameter("vmask_st", Vector4(vm.r, vm.g, vm.b, vm.a))
	mat.set_shader_parameter("time", tau)
	mat.set_shader_parameter("fade", 1.0 - clampf((_t - (float(_script["len"]) - 0.6)) / 0.6, 0.0, 1.0))


# --- слои отрисовки ------------------------------------------------------------------

## Слой одной системы частиц или меша: свой материал (шейдер), свои кадры.
class _Drawer extends Control:
	var node := -1
	var common := false
	var tex: Texture2D
	## [центр, размер, поворот, цвет, кусок текстуры]
	var quads: Array = []
	## [индексы, точки, цвета, uv]
	var tris: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func _draw() -> void:
		if tex == null:
			return
		for q: Array in quads:
			var sz: Vector2 = q[1]
			draw_set_transform(q[0], float(q[2]), Vector2.ONE)
			draw_texture_rect_region(tex, Rect2(-sz * 0.5, sz), q[4], q[3])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for m: Array in tris:
			var cols: PackedColorArray = m[2]
			if cols.size() != (m[1] as PackedVector2Array).size():
				cols = PackedColorArray()
				cols.resize((m[1] as PackedVector2Array).size())
				cols.fill(Color.WHITE)
			RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), m[0], m[1], cols, m[3],
				PackedInt32Array(), PackedFloat32Array(), tex.get_rid())


## Карта в центре доски: видна нижняя часть shown (0..1) — огонь проявляет её снизу вверх.
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
