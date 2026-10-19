class_name HsFx
extends RefCounted

## Эффект в духе Hearthstone: системы частиц Unity, перенесённые выгрузкой
## (Claude outputs/hs_fx/_tool -> assets/hs_fx/<имя>/fx.json + textures/).
## Частицы не живут между кадрами: состояние каждой считается заново от момента, когда
## её выпустили, по времени эффекта. Поэтому эффект можно заморозить, промотать и
## снять в GIF, а кадры идут ступенями (FPS), как покадровая пиксельная анимация.
##
## Пространство — как в Unity: x вправо, y вверх (высота над доской), z «от игрока»
## (вверх по экрану). На экран проецирует HsStage.

const FPS := 20.0
## Шаг, которым считаются скорость, силы и торможение частицы.
const STEP := 1.0 / 30.0
const GRAVITY := 9.81
## Не больше стольких частиц на систему за кадр (защита от тяжёлых систем).
const MAX_ALIVE := 600

## Режимы смешивания материала.
enum Blend { MIX, ADD, MUL }

var fx_name := ""
## Узлы префаба: name, parent, active, pos (Vector3), rot (Quaternion), scale (Vector3),
## ps (система частиц, как в fx.json), mesh, render_mode, tex, tex2, blend, alpha_mode,
## tint (Color), max_size.
var nodes: Array[Dictionary] = []

static var _cache: Dictionary = {}


## Префаб fx = "<эффект>/<префаб>": assets/hs_fx/<эффект>/<префаб>.json, текстуры —
## в assets/hs_fx/<эффект>/textures/.
static func load_fx(fx: String) -> HsFx:
	if _cache.has(fx):
		return _cache[fx]
	var e := HsFx.new()
	e.fx_name = fx
	var base := "res://assets/hs_fx/%s/" % fx.get_base_dir()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/hs_fx/%s.json" % fx))
	for n: Dictionary in data["nodes"]:
		e.nodes.append(e._parse_node(n, base))
	_cache[fx] = e
	return e


static var _clips: Dictionary = {}


## Анимация (выгрузка MuscleClip): {length, fps, curves: [{path, attr, values}]} — кривые
## с шагом 1/fps; path — путь объекта от аниматора, attr — свойство (scale.x,
## m_Enabled, _AlphaMul, _MainTex_ST.w, _WhiteColor#4 ...).
static func load_clip(clip: String) -> Dictionary:
	if not _clips.has(clip):
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/hs_fx/%s.json" % clip))
		for c: Dictionary in d["curves"]:
			c["values"] = PackedFloat32Array(c["values"])
		_clips[clip] = d
	return _clips[clip]


## Значение кривой c в момент t (ломаной между отсчётами).
static func clip_value(clip: Dictionary, c: Dictionary, t: float) -> float:
	var v: PackedFloat32Array = c["values"]
	var x := clampf(t, 0.0, float(clip["length"])) * float(clip["fps"])
	var i := clampi(floori(x), 0, v.size() - 1)
	var j := mini(i + 1, v.size() - 1)
	return lerpf(v[i], v[j], x - float(i))


## Узел по пути от узла root ("TrailRoot/Mesh_FireSweep"); -1 — нет.
func find_path(root: int, path: String) -> int:
	var at := root
	if path == "":
		return at
	for part in path.split("/"):
		var next := -1
		for j in nodes.size():
			if int(nodes[j]["parent"]) == at and nodes[j]["name"] == part:
				next = j
				break
		if next < 0:
			return -1
		at = next
	return at


func _parse_node(n: Dictionary, base: String) -> Dictionary:
	var nd := {"name": String(n["name"]), "parent": int(n["parent"]), "active": bool(n["active"]),
		"pos": _v3(n.get("pos"), Vector3.ZERO), "rot": _quat(n.get("rot")), "scale": _v3(n.get("scale"), Vector3.ONE),
		"ps": n.get("ps", {}), "mesh": n.get("mesh", null), "render_mode": -1}
	var r: Variant = n.get("renderer")
	if r is Dictionary:
		nd["render_mode"] = int((r as Dictionary).get("m_RenderMode", -1))
		nd["length_scale"] = float((r as Dictionary).get("m_LengthScale", 2.0))
		nd["velocity_scale"] = float((r as Dictionary).get("m_VelocityScale", 0.0))
		nd["max_size"] = float((r as Dictionary).get("m_MaxParticleSize", 0.5))
		var mats: Array = (r as Dictionary).get("materials", [])
		var m: Dictionary = mats[0] if not mats.is_empty() and mats[0] is Dictionary else {}
		var shader := String(m.get("shader", ""))
		nd["shader"] = shader
		nd["blend"] = blend_of(shader)
		nd["alpha_mode"] = 1 if shader.contains("ColorAsAlpha") else 0
		var tex: Dictionary = m.get("tex", {})
		var main := String((tex.get("_MainTex", {}) as Dictionary).get("tex", ""))
		if main == "" and not tex.is_empty():
			main = String((tex.values()[0] as Dictionary).get("tex", ""))
		nd["tex"] = _texture(base, main)
		nd["tex_name"] = main
		var colors: Dictionary = m.get("colors", {})
		var floats: Dictionary = m.get("floats", {})
		var tint := Color.WHITE
		if colors.has("_TintColor"):
			tint = _color(colors["_TintColor"])
		elif colors.has("_Color"):
			tint = _color(colors["_Color"])
		nd["tint"] = tint
		nd["intensity"] = float(floats.get("_Intensity", 1.0))
		nd["colors"] = colors
		nd["floats"] = floats
		nd["textures"] = tex
		nd["tex_base"] = base
		nd["keywords"] = m.get("keywords", [])
	var mesh: Variant = n.get("mesh")
	if mesh is Dictionary and (mesh as Dictionary).has("verts"):
		var md: Dictionary = mesh
		var verts := PackedVector3Array()
		var vf: Array = md["verts"]
		for k in range(0, vf.size(), 3):
			verts.append(Vector3(vf[k], vf[k + 1], vf[k + 2]))
		var uvs := PackedVector2Array()
		var uf: Array = md.get("uv", [])
		for k in range(0, uf.size(), 2):
			uvs.append(Vector2(uf[k], uf[k + 1]))
		var cols := PackedColorArray()
		var cf: Array = md.get("colors", [])
		for k in range(0, cf.size(), 4):
			cols.append(Color(cf[k], cf[k + 1], cf[k + 2], cf[k + 3]))
		nd["geom"] = {"verts": verts, "uv": uvs, "colors": cols, "tris": PackedInt32Array(md.get("tris", []))}
	return nd


## Режим смешивания по имени шейдера Hearthstone.
static func blend_of(shader: String) -> int:
	if (shader.contains("Multiply") and not shader.contains("AddMultiply")) or shader.contains("ContactShadow"):
		return Blend.MUL
	if shader.contains("Add"):
		return Blend.ADD
	return Blend.MIX


static func _texture(base: String, tex_name: String) -> Texture2D:
	if tex_name == "":
		return null
	var path := base + "textures/" + tex_name + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Текстура эффекта fx ("<эффект>/<префаб>" или "<эффект>") по имени.
static func texture_of(fx: String, tex_name: String) -> Texture2D:
	var dir := fx.get_base_dir() if fx.contains("/") else fx
	return _texture("res://assets/hs_fx/%s/" % dir, tex_name)


static func _v3(v: Variant, fallback: Vector3) -> Vector3:
	if not (v is Dictionary):
		return fallback
	var d: Dictionary = v
	return Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0)))


static func _quat(v: Variant) -> Quaternion:
	if not (v is Dictionary):
		return Quaternion.IDENTITY
	var d: Dictionary = v
	return Quaternion(float(d["x"]), float(d["y"]), float(d["z"]), float(d["w"])).normalized()


static func _color(v: Variant) -> Color:
	if not (v is Dictionary):
		return Color.WHITE
	var d: Dictionary = v
	return Color(float(d.get("r", 1.0)), float(d.get("g", 1.0)), float(d.get("b", 1.0)), float(d.get("a", 1.0)))


## Номер первого узла с именем node_name (-1 — нет).
func find(node_name: String) -> int:
	for i in nodes.size():
		if nodes[i]["name"] == node_name:
			return i
	return -1


## Узел i и все его потомки (для «включить вместе с детьми»).
func subtree(i: int) -> Array[int]:
	var out: Array[int] = [i]
	var k := 0
	while k < out.size():
		for j in nodes.size():
			if int(nodes[j]["parent"]) == out[k]:
				out.append(j)
		k += 1
	return out


## Локальный переход узла: позицию и масштаб можно подменить (узел едет по сценарию
## или по анимации).
func local_xf(i: int, pos_override: Variant = null, scale_override: Variant = null) -> Transform3D:
	var nd := nodes[i]
	var pos: Vector3 = pos_override if pos_override != null else nd["pos"]
	var sc: Vector3 = scale_override if scale_override != null else nd["scale"]
	return Transform3D(Basis(nd["rot"] as Quaternion) * Basis.from_scale(sc), pos)


# --- кривые Unity ------------------------------------------------------------------

## AnimationCurve (m_Curve: ключи time, value, inSlope, outSlope) — кубика Эрмита.
static func curve(cv: Variant, x: float) -> float:
	if not (cv is Dictionary):
		return 0.0
	var keys: Array = (cv as Dictionary).get("m_Curve", [])
	if keys.is_empty():
		return 0.0
	var k0: Dictionary = keys[0]
	if keys.size() == 1 or x <= float(k0["time"]):
		return float(k0["value"])
	var kl: Dictionary = keys[keys.size() - 1]
	if x >= float(kl["time"]):
		return float(kl["value"])
	for i in keys.size() - 1:
		var a: Dictionary = keys[i]
		var b: Dictionary = keys[i + 1]
		var t0 := float(a["time"])
		var t1 := float(b["time"])
		if x < t1:
			var dt := maxf(t1 - t0, 1e-5)
			var s := (x - t0) / dt
			var m0 := float(a["outSlope"]) * dt
			var m1 := float(b["inSlope"]) * dt
			var s2 := s * s
			var s3 := s2 * s
			return (2.0 * s3 - 3.0 * s2 + 1.0) * float(a["value"]) + (s3 - 2.0 * s2 + s) * m0 \
				+ (-2.0 * s3 + 3.0 * s2) * float(b["value"]) + (s3 - s2) * m1
	return float(kl["value"])


## MinMaxCurve: 0 — число, 1 — кривая, 2 — между двумя кривыми, 3 — между двумя числами.
static func mmc(c: Variant, x: float, r: float) -> float:
	if not (c is Dictionary):
		return 0.0
	var d: Dictionary = c
	match int(d.get("minMaxState", 0)):
		1:
			return float(d["scalar"]) * curve(d["maxCurve"], x)
		2:
			return float(d["scalar"]) * lerpf(curve(d["minCurve"], x), curve(d["maxCurve"], x), r)
		3:
			return lerpf(float(d["minScalar"]), float(d["scalar"]), r)
	return float(d.get("scalar", 0.0))


## Gradient Unity: до 8 ключей цвета (ctimeN) и прозрачности (atimeN), время в 0..65535.
static func gradient(g: Variant, x: float) -> Color:
	if not (g is Dictionary):
		return Color.WHITE
	var d: Dictionary = g
	var nc := int(d.get("m_NumColorKeys", 2))
	var na := int(d.get("m_NumAlphaKeys", 2))
	var rgb := _grad_part(d, "ctime", nc, x, true)
	var a := _grad_part(d, "atime", na, x, false)
	return Color(rgb.r, rgb.g, rgb.b, a.a)


static func _grad_part(d: Dictionary, key: String, n: int, x: float, colour: bool) -> Color:
	var prev_t := -1.0
	var prev := Color.WHITE
	for i in maxi(n, 1):
		var c := _color(d.get("key%d" % i))
		var t := float(d.get("%s%d" % [key, i], 0.0)) / 65535.0
		if i == 0 and x <= t:
			return c
		if x <= t:
			var k := (x - prev_t) / maxf(t - prev_t, 1e-5)
			return prev.lerp(c, k) if colour else Color(1, 1, 1, lerpf(prev.a, c.a, k))
		prev = c
		prev_t = t
	return prev


## MinMaxGradient: 0 — цвет, 1 — градиент, 2 — между двумя цветами, 3 — между двумя
## градиентами, 4 — случайный цвет из градиента.
static func mmg(g: Variant, x: float, r: float) -> Color:
	if not (g is Dictionary):
		return Color.WHITE
	var d: Dictionary = g
	match int(d.get("minMaxState", 0)):
		1:
			return gradient(d["maxGradient"], x)
		2:
			return _color(d["minColor"]).lerp(_color(d["maxColor"]), r)
		3:
			return gradient(d["minGradient"], x).lerp(gradient(d["maxGradient"], x), r)
		4:
			return gradient(d["maxGradient"], r)
	return _color(d.get("maxColor"))


## Случайное 0..1, одно и то же для (система, канал, частица).
static func rnd(a: int, b: int, c: int) -> float:
	var h := hash(Vector3i(a, b, c))
	return float(h & 0xFFFFFF) / float(0xFFFFFF)


# --- частицы -----------------------------------------------------------------------

## Частицы системы i, включённой в момент t_play и выключенной в t_stop (INF — не
## выключали), в момент t. xf_at(time) -> Transform3D — где система в мире в этот
## момент (она может ехать вместе с родителем). Каждая частица — {p: Vector3 мира,
## v: скорость мира, size, rot, col, frame}.
func particles(i: int, t_play: float, t_stop: float, t: float, xf_at: Callable) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ps: Dictionary = nodes[i]["ps"]
	if ps.is_empty():
		return out
	var im: Dictionary = ps["InitialModule"]
	var dur := maxf(float(ps.get("lengthInSec", 1.0)), 0.01)
	var loop := bool(ps.get("looping", false))
	var seed := i * 7919 + 17
	var delay := mmc(ps.get("startDelay"), 0.0, rnd(seed, 0, 0))
	var tau := t - t_play - delay
	if tau < 0.0:
		return out
	var emit_end := INF if loop else dur
	if t_stop < INF:
		emit_end = minf(emit_end, t_stop - t_play - delay)
	var until := minf(tau, emit_end)
	var spawns := _spawn_times(ps, seed, dur, until, emit_end)
	if spawns.is_empty():
		return out

	var shape: Dictionary = ps.get("ShapeModule", {})
	var vel_m: Dictionary = ps.get("VelocityModule", {})
	var force_m: Dictionary = ps.get("ForceModule", {})
	var clamp_m: Dictionary = ps.get("ClampVelocityModule", {})
	var size_m: Dictionary = ps.get("SizeModule", {})
	var rot_m: Dictionary = ps.get("RotationModule", {})
	var col_m: Dictionary = ps.get("ColorModule", {})
	var uv_m: Dictionary = ps.get("UVModule", {})
	var scaling := int(ps.get("scalingMode", 0))
	var world_sim := int(ps.get("moveWithTransform", 0)) == 1
	var local_scale: Vector3 = nodes[i]["scale"]
	var now_xf: Transform3D = xf_at.call(t)

	# с конца: при перегрузке пропадают самые старые (как и в Unity при maxParticles)
	for n in range(spawns.size() - 1, -1, -1):
		if out.size() >= MAX_ALIVE:
			break
		var ts: float = spawns[n]
		var age := tau - ts
		var xs := fmod(ts, dur) / dur
		var life := mmc(im.get("startLifetime"), xs, rnd(seed, 1, n))
		if life <= 0.0 or age >= life or age < 0.0:
			continue
		var u := age / life
		var xf: Transform3D = xf_at.call(t_play + delay + ts) if world_sim else now_xf
		var rot_b := xf.basis.orthonormalized()
		var world_scale := xf.basis.get_scale()
		var start_scale := local_scale if scaling == 1 else world_scale
		var sim_scale := world_scale if scaling == 0 else (local_scale if scaling == 1 else Vector3.ONE)
		var sim_k := (sim_scale.x + sim_scale.y + sim_scale.z) / 3.0

		var sh := _shape_sample(ps, shape, seed, n)
		var p_loc: Vector3 = (sh[0] as Vector3) * start_scale
		var v_loc: Vector3 = (sh[1] as Vector3) * mmc(im.get("startSpeed"), xs, rnd(seed, 2, n)) * sim_scale
		var p_w := Vector3.ZERO
		var v_w := Vector3.ZERO
		var g := mmc(im.get("gravityModifier"), xs, rnd(seed, 7, n)) * GRAVITY
		var spin := 0.0
		var steps := maxi(1, ceili(age / STEP))
		var h := age / float(steps)
		var r5 := rnd(seed, 5, n)
		var r6 := rnd(seed, 6, n)
		var r13 := rnd(seed, 13, n)
		for s in steps:
			var uu := (float(s) + 0.5) * h / life
			if not vel_m.is_empty():
				var vv := Vector3(mmc(vel_m.get("x"), uu, r5), mmc(vel_m.get("y"), uu, r5), mmc(vel_m.get("z"), uu, r5))
				vv *= mmc(vel_m.get("speedModifier"), uu, r5) if vel_m.has("speedModifier") else 1.0
				if bool(vel_m.get("inWorldSpace", false)):
					p_w += vv * h
				else:
					p_loc += vv * sim_scale * h
			if not force_m.is_empty():
				var a := Vector3(mmc(force_m.get("x"), uu, r6), mmc(force_m.get("y"), uu, r6), mmc(force_m.get("z"), uu, r6))
				if bool(force_m.get("inWorldSpace", false)):
					v_w += a * h
				else:
					v_loc += a * sim_scale * h
			v_w.y -= g * h
			if not clamp_m.is_empty():
				var limit := mmc(clamp_m.get("magnitude"), uu, r6) * sim_k
				var damp := float(clamp_m.get("dampen", 0.0))
				var spd := v_loc.length()
				if spd > limit and damp > 0.0:
					v_loc = v_loc / spd * lerpf(spd, limit, 1.0 - pow(1.0 - minf(damp, 0.999), h * 30.0))
				var drag := mmc(clamp_m.get("drag"), uu, r6)
				if drag > 0.0:
					v_loc *= maxf(0.0, 1.0 - drag * h)
			if not rot_m.is_empty():
				spin += mmc(rot_m.get("curve"), uu, r13) * h
			p_loc += v_loc * h
			p_w += v_w * h

		var size := mmc(im.get("startSize"), xs, rnd(seed, 3, n)) * sim_k
		if not size_m.is_empty():
			size *= mmc(size_m.get("curve"), u, rnd(seed, 8, n))
		var rot := mmc(im.get("startRotation"), xs, rnd(seed, 4, n)) + spin
		if rnd(seed, 9, n) < float(im.get("randomizeRotationDirection", 0.0)):
			rot = -rot
		var col := mmg(im.get("startColor"), xs, rnd(seed, 10, n))
		if not col_m.is_empty():
			col *= mmg(col_m.get("gradient"), u, rnd(seed, 11, n))
		var frame := 0
		if not uv_m.is_empty():
			frame = _uv_frame(uv_m, u, rnd(seed, 12, n))
		out.append({"p": xf.origin + rot_b * p_loc + p_w, "v": rot_b * v_loc + v_w, "size": size,
			"rot": rot, "col": col, "frame": frame})
	return out


## Моменты рождения частиц (секунды от старта системы): поток rateOverTime и залпы.
func _spawn_times(ps: Dictionary, seed: int, dur: float, until: float, emit_end: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var em: Dictionary = ps.get("EmissionModule", {})
	if em.is_empty():
		return out
	var rate: Variant = em.get("rateOverTime")
	if rate is Dictionary and (float((rate as Dictionary).get("scalar", 0.0)) > 0.0):
		var acc := 0.0
		var s := 0.0
		var dt := 1.0 / 60.0
		while s < until and out.size() < 6000:
			var x := fmod(s, dur) / dur
			acc += mmc(rate, x, rnd(seed, 20, int(s / dur))) * dt
			while acc >= 1.0:
				acc -= 1.0
				out.append(s)
			s += dt
	var bursts: Array = em.get("m_Bursts", [])
	var count := mini(int(em.get("m_BurstCount", bursts.size())), bursts.size())
	for b in count:
		var bd: Dictionary = bursts[b]
		var at0 := float(bd.get("time", 0.0))
		var cycles := int(bd.get("cycleCount", 1))
		var interval := float(bd.get("repeatInterval", 0.0))
		var c := 0
		while true:
			var at := at0 + float(c) * interval
			if at > until or at > emit_end:
				break
			var cnt := roundi(mmc(bd.get("countCurve"), 0.0, rnd(seed, 21, b * 100 + c)))
			for q in cnt:
				out.append(at)
			c += 1
			if (cycles > 0 and c >= cycles) or interval <= 0.0:
				break
	out.sort()
	return out


## Точка и направление вылета по форме (ShapeModule) в пространстве системы.
func _shape_sample(ps: Dictionary, sm: Dictionary, seed: int, n: int) -> Array:
	var r1 := rnd(seed, 30, n)
	var r2 := rnd(seed, 31, n)
	var r3 := rnd(seed, 32, n)
	var pos := Vector3.ZERO
	var dir := Vector3(0, 0, 1)
	if sm.is_empty() or not bool(sm.get("enabled", true)):
		return [pos, dir]
	var type := int(sm.get("type", 4))
	var radius := float((sm.get("radius", {}) as Dictionary).get("value", 1.0)) if sm.get("radius") is Dictionary else 1.0
	var arc := deg_to_rad(float((sm.get("arc", {}) as Dictionary).get("value", 360.0))) if sm.get("arc") is Dictionary else TAU
	var thick := float(sm.get("radiusThickness", 1.0))
	var phi := r1 * arc
	match type:
		4, 7, 8, 9:   # конус: основание — круг, направление наклоняется к краю
			var rr := radius * sqrt(lerpf(1.0 - thick, 1.0, r2) if thick < 1.0 else r2)
			if type == 7 or type == 9:
				rr = radius
			var ang := deg_to_rad(float(sm.get("angle", 25.0))) * (rr / maxf(radius, 1e-4))
			pos = Vector3(cos(phi) * rr, sin(phi) * rr, 0.0)
			dir = Vector3(sin(ang) * cos(phi), sin(ang) * sin(phi), cos(ang))
			if type == 8 or type == 9:
				pos += dir * float(sm.get("length", 5.0)) * r3
		0, 1, 2, 3:   # сфера / полусфера
			var z := r2 * 2.0 - 1.0
			if type >= 2:
				z = absf(z)
			var q := sqrt(maxf(0.0, 1.0 - z * z))
			dir = Vector3(q * cos(phi), q * sin(phi), z)
			var rr := radius * (1.0 if type == 1 or type == 3 else pow(lerpf(1.0 - thick, 1.0, r3), 1.0 / 3.0))
			pos = dir * rr
		10, 11, 17:   # круг (в плоскости XY), разлёт от центра
			var rr := radius * (1.0 if type == 11 else sqrt(lerpf(1.0 - thick, 1.0, r2)))
			pos = Vector3(cos(phi) * rr, sin(phi) * rr, 0.0)
			dir = Vector3(cos(phi), sin(phi), 0.0)
		12:   # отрезок вдоль X
			pos = Vector3((r1 * 2.0 - 1.0) * radius, 0.0, 0.0)
			dir = Vector3(0, 1, 0)
		6, 13, 14:   # меш (у Hearthstone — прямоугольник доски): точка внутри или по краю
			var mesh: Variant = ps.get("shapeMesh")
			var c := Vector3.ZERO
			var ext := Vector3(0.5, 0.0, 0.5)
			if mesh is Dictionary:
				c = _v3((mesh as Dictionary).get("center"), Vector3.ZERO)
				ext = _v3((mesh as Dictionary).get("extent"), ext)
			if mesh is Dictionary and String((mesh as Dictionary).get("name", "")).contains("border"):
				var per := r1 * 4.0
				var side := int(per)
				var f := per - float(side)
				var corner := [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]
				pos = c + ((corner[side % 4] as Vector3).lerp(corner[(side + 1) % 4], f)) * ext
			else:
				pos = c + Vector3((r1 * 2.0 - 1.0) * ext.x, (r3 * 2.0 - 1.0) * ext.y, (r2 * 2.0 - 1.0) * ext.z)
			dir = Vector3(0, 1, 0)
		_:   # коробка и прочее
			pos = Vector3(r1 - 0.5, r2 - 0.5, r3 - 0.5)
			dir = Vector3(0, 0, 1)
	var rnd_dir := float(sm.get("randomDirectionAmount", 0.0))
	if rnd_dir > 0.0:
		var rd := Vector3(rnd(seed, 33, n) - 0.5, rnd(seed, 34, n) - 0.5, rnd(seed, 35, n) - 0.5).normalized()
		dir = dir.lerp(rd, rnd_dir).normalized()
	var sph := float(sm.get("sphericalDirectionAmount", 0.0))
	if sph > 0.0 and pos.length() > 1e-4:
		dir = dir.lerp(pos.normalized(), sph).normalized()
	var sc := _v3(sm.get("m_Scale"), Vector3.ONE)
	var eul := _v3(sm.get("m_Rotation"), Vector3.ZERO)
	var b := Basis.from_euler(Vector3(deg_to_rad(eul.x), deg_to_rad(eul.y), deg_to_rad(eul.z)), EULER_ORDER_YXZ)
	pos = b * (pos * sc) + _v3(sm.get("m_Position"), Vector3.ZERO)
	dir = b * dir
	return [pos, dir]


## Кадр раскадровки (UVModule): листы tilesX x tilesY, кадр по кривой frameOverTime.
static func _uv_frame(uv: Dictionary, u: float, r: float) -> int:
	var tx := maxi(int(uv.get("tilesX", 1)), 1)
	var ty := maxi(int(uv.get("tilesY", 1)), 1)
	var count := tx * ty if int(uv.get("animationType", 0)) == 0 else tx
	var cycles := maxf(float(uv.get("cycles", 1.0)), 1.0)
	var x := fmod(u * cycles, 1.0)
	var v := mmc(uv.get("frameOverTime"), x, r) + mmc(uv.get("startFrame"), 0.0, r)
	var f := floori(v * float(count)) if v <= 1.0001 else floori(v)
	f = clampi(f, 0, count - 1)
	if int(uv.get("animationType", 0)) == 1:
		f += int(uv.get("rowIndex", 0)) * tx
	return f


## Сетка раскадровки текстуры узла i (1x1 — без раскадровки).
func tiles(i: int) -> Vector2i:
	var uv: Dictionary = (nodes[i]["ps"] as Dictionary).get("UVModule", {})
	if uv.is_empty():
		return Vector2i.ONE
	return Vector2i(maxi(int(uv.get("tilesX", 1)), 1), maxi(int(uv.get("tilesY", 1)), 1))
