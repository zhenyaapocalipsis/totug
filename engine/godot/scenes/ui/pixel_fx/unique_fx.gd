class_name UniqueFx
extends RefCounted

## Постановки розыгрыша уникальных карт (в полуколоде одна копия), нарисованные
## своим пиксель-артом (Pix, PixPal, PixKit, PixArt) — без сгенерированных спрайтов.
## Витрина (CardShowcase) держит карту крупно, пока идёт постановка; холсты CardFx
## спрашивают кадры здесь (CardFx передаёт сюда все карты из RECIPES).
##
## Кадр рисуется по времени, раз в 1/FPS секунды — как покадровая анимация (у
## Blasphemous эффекты идут ступенями, а не плавно). Каждый кадр — три холста:
## позади карты, поверх неё и свет (glow, прибавляется к картинке поверх всего).
## Вещество (дым, кости, плоть) получает цветную обводку шейдером pix_outline.

const FPS := 20.0
## Холст вокруг карты: сколько пикселей по сторонам и сверху/снизу.
const MARGIN := Vector2i(340, 150)
const OUTLINE_SHADER := preload("res://scenes/ui/pixel_fx/pix_outline.gdshader")
const FLUID_SHADER := preload("res://scenes/ui/pixel_fx/pix_fluid.gdshader")
const SPRITE_SHADER := preload("res://scenes/ui/pixel_fx/pix_sprite.gdshader")
const SCREEN_SHADER := preload("res://scenes/ui/pixel_fx/pix_screen.gdshader")

## card_id -> постановка: len — сколько секунд держать карту; sound — звук (Sfx);
## stops — остановки времени на ударе [когда, сколько]; shakes — толчки карты
## [когда, сила, затухание]; trembles — дрожь [с, по, сила]; flashes — белые вспышки
## карты (когда).
const RECIPES := {
	# Red Dragon, фаза A (сценарий владельца 2026-10-18): дракон не рисуется (он на арте),
	# его присутствие — заряд, рёв (волна), тень крыльев, ветер, зарево и пепел.
	"48426": {"len": 3.4, "sound": "", "screen": true, "dim": 0.5,
		"stops": [[0.7, 0.1]], "shakes": [[0.7, 3.5, 5.0], [1.65, 1.5, 4.0]], "trembles": [[0.05, 0.7, 1.6]],
		"jolts": [0.7],
		"cues": [[0.0, "red_dragon_rumble"], [0.68, "red_dragon_roar"], [0.95, "red_dragon_wings"], [1.6, "red_dragon_breath"]]},
}

static var _layers: Dictionary = {}
static var _key := ""
static var _outline: ShaderMaterial
static var _add: CanvasItemMaterial


static func has(cid: String) -> bool:
	return RECIPES.has(cid)


static func sound(cid: String) -> String:
	return String(RECIPES[cid].get("sound", ""))


static func hold_end(cid: String) -> float:
	return float(RECIPES[cid]["len"])


## Насколько витрина затемняет экран под постановкой (1 — как обычно).
static func dim(cid: String) -> float:
	return float(RECIPES[cid].get("dim", 1.0))


## Время эффекта по секундам выдержки: ступенями по кадрам, на ударах замирает.
static func fx_time(cid: String, raw: float) -> float:
	var t := floorf(raw * FPS) / FPS
	var out := t
	for s: Array in RECIPES[cid].get("stops", []):
		if t > float(s[0]):
			out -= minf(t - float(s[0]), float(s[1]))
	return out


## Сдвиг карты (целые пиксели, по кадрам): дрожь перед ударом и толчок на ударе.
static func card_shift(cid: String, raw: float) -> Vector2:
	var t := floorf(raw * FPS) / FPS
	var r: Dictionary = RECIPES[cid]
	var off := Vector2.ZERO
	for tr: Array in r.get("trembles", []):
		var k := PixKit.span(t, float(tr[0]), float(tr[1]))
		if k > 0.0 and k < 1.0:
			off += Vector2(sin(t * 91.0), cos(t * 73.0)) * float(tr[2]) * k
	for sh: Array in r.get("shakes", []):
		var dt := t - float(sh[0])
		if dt >= 0.0:
			off += Vector2(sin(dt * 57.0), cos(dt * 43.0)) * float(sh[1]) * exp(-dt * float(sh[2]))
	# толчок: на кадре удара карта подпрыгивает на 3 пикселя, следующим — бьёт вниз
	var f := floori(raw * FPS)
	for j: float in r.get("jolts", []):
		var fj := floori(j * FPS)
		if f == fj:
			off.y -= 3.0
		elif f == fj + 1:
			off.y += 1.0
	return off.round()


## Белая вспышка карты: два кадра — почти белый и вполовину (ступенями).
static func flash_alpha(cid: String, raw: float) -> float:
	var frame := floori(raw * FPS)
	for at: float in RECIPES[cid].get("flashes", []):
		var f0 := floori(at * FPS)
		if frame == f0:
			return 0.85
		if frame == f0 + 1:
			return 0.4
	return 0.0


static func outline_material() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
	return _outline


static func add_material() -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add


## Холсты кадра для карты cid в рамке card на холсте размера area: back, front, glow
## (Pix) и шейдерные слои огня/дыма under/over для каждой стороны. Кадр собирается
## один раз, потом берётся готовый.
static func frame(cid: String, card: Rect2, raw: float, area: Vector2) -> Dictionary:
	var f := floori(raw * FPS)
	var key := "%s/%d/%d/%d" % [cid, f, int(card.position.x), int(card.position.y)]
	if key == _key and not _layers.is_empty():
		return _layers
	var box := Rect2i(Vector2i(card.position) - MARGIN, Vector2i(card.size) + MARGIN * 2)
	box = box.intersection(Rect2i(Vector2i.ZERO, Vector2i(area)))
	if _layers.is_empty() or (_layers["back"] as Pix).w != box.size.x or (_layers["back"] as Pix).h != box.size.y:
		_layers = {"back": Pix.new(box.size.x, box.size.y), "front": Pix.new(box.size.x, box.size.y),
			"glow": Pix.new(box.size.x, box.size.y)}
	for k: String in ["back", "front", "glow"]:
		var p: Pix = _layers[k]
		p.ox = box.position.x
		p.oy = box.position.y
		p.clear()
		p.no_clip()
	_key = key
	var t := fx_time(cid, raw)
	_layers["t"] = t
	_layers["box"] = Rect2(box)
	_layers["area"] = Rect2(Vector2.ZERO, area)
	for side: String in ["back", "front"]:
		_layers["under_" + side] = []
		_layers["sprites_" + side] = []
		_layers["over_" + side] = []
	draw_recipe(cid, _layers, card, t)
	_layers["tex"] = {}
	return _layers


## Шейдерный слой огня/дыма (pix_fluid.gdshader) в кадр: side — "back"/"front", over —
## поверх пиксельного холста этой стороны; mode 0 струя, 1 пламя над краем, 2 дым;
## p0, p1, w0, w1 — геометрия (см. шейдер); opts — head, tail, power, seed, flip,
## ramp (имя палитры PixPal), pad (запас прямоугольника вокруг p0-p1).
static func fluid(L: Dictionary, side: String, over: bool, mode: int, p0: Vector2, p1: Vector2,
		w0: float, w1: float, opts: Dictionary = {}) -> void:
	var pad := float(opts.get("pad", maxf(w0, w1) * 2.0 + 8.0))
	var r := Rect2(p0, Vector2.ZERO).expand(p1).grow(pad)
	if mode == 1:
		r = r.grow(w1 * 1.2)
	r = r.intersection(L["area"])
	if r.size.x < 1.0 or r.size.y < 1.0:
		return
	var item := opts.duplicate()
	item.merge({"mode": mode, "p0": p0, "p1": p1, "w0": w0, "w1": w1, "rect": Rect2(r.position.floor(), r.size.ceil())})
	(L[("over_" if over else "under_") + side] as Array).append(item)


static var _sheets: Dictionary = {}


## Лист кадров существа assets/card_fx/<name>.png + .json (tools/sprite_pixelize.gd):
## {tex, w, h, cols, fps, anims: имя -> [первый кадр, сколько], mouths: [[x, y]...]}.
static func sheet(name: String) -> Dictionary:
	if not _sheets.has(name):
		var base := "res://assets/card_fx/%s" % name
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
		meta["tex"] = load(base + ".png")
		_sheets[name] = meta
	return _sheets[name]


## Номер кадра листа: анимация anim, кадр i внутри неё (обрезается по длине).
static func anim_frame(name: String, anim: String, i: int) -> int:
	var a: Array = sheet(name)["anims"][anim]
	return int(a[0]) + clampi(i, 0, int(a[1]) - 1)


## Существо в кадр: кадр frame листа name, левый верхний угол pos (экран), side —
## "back"/"front". opts: flip, dissolve, silhouette, flash, rim, rim_dir, rim_color.
static func sprite(L: Dictionary, side: String, name: String, frame: int, pos: Vector2, opts: Dictionary = {}) -> void:
	var item := opts.duplicate()
	item.merge({"sheet": name, "frame": frame, "pos": pos.floor()})
	(L["sprites_" + side] as Array).append(item)


## Где пасть существа на экране: кадр frame листа name, поставленного в pos.
static func mouth_at(name: String, frame: int, pos: Vector2, flip: bool = false) -> Vector2:
	var s := sheet(name)
	var m: Array = s["mouths"][frame]
	var x := float(m[0]) if not flip else float(int(s["w"]) - 1 - int(m[0]))
	return pos.floor() + Vector2(x, float(m[1]))


static var _palettes: Dictionary = {}


## Палитра name строкой пикселей (для шейдера).
static func palette_texture(name: String) -> ImageTexture:
	if not _palettes.has(name):
		var cols: Array = PixPal.RAMPS[name]
		var img := Image.create_empty(cols.size(), 1, false, Image.FORMAT_RGBA8)
		for i in cols.size():
			img.set_pixel(i, 0, Color(String(cols[i])))
		_palettes[name] = ImageTexture.create_from_image(img)
	return _palettes[name]


## Текстура холста name текущего кадра (одна загрузка на кадр).
static func texture(layers: Dictionary, name: String) -> Texture2D:
	var cache: Dictionary = layers["tex"]
	if not cache.has(name):
		cache[name] = (layers[name] as Pix).texture()
	return cache[name]


static func draw_recipe(cid: String, L: Dictionary, card: Rect2, t: float) -> void:
	match cid:
		"48426":
			_red_dragon(L, card, t)


## Параметры экранного прохода (pix_screen.gdshader) для карты cid в рамке card
## (время эффекта t); пусто — прохода нет.
static func screen_params(cid: String, card: Rect2, t: float) -> Dictionary:
	if not bool(RECIPES[cid].get("screen", false)):
		return {}
	match cid:
		"48426":
			return _red_dragon_screen(card, t)
	return {}


## Сцена одной стороны эффекта (позади карты или поверх): шейдерный огонь/дым под
## пиксельным холстом, сам холст (с обводкой), шейдерные слои поверх и, у передней
## стороны, свет (прибавляется к картинке). Её держит холст витрины (CardFx.Canvas) и
## превью (tools/fx_preview.gd); show_frame(кадр UniqueFx.frame) раскладывает слои.
class Stage extends Control:
	var side := "back"
	var _under := Control.new()
	var _sprites := Control.new()
	var _pix := TextureRect.new()
	var _over := Control.new()
	var _glow := TextureRect.new()

	func _init(which: String) -> void:
		side = which
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for c: Control in [_under, _sprites, _pix, _over, _glow]:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(c)
		_pix.material = UniqueFx.outline_material()
		_glow.material = UniqueFx.add_material()
		_glow.visible = which == "front"

	func show_frame(L: Dictionary) -> void:
		var box: Rect2 = L["box"]
		_pix.texture = UniqueFx.texture(L, side)
		_pix.position = box.position
		_pix.size = box.size
		if side == "front":
			_glow.texture = UniqueFx.texture(L, "glow")
			_glow.position = box.position
			_glow.size = box.size
		_fill(_under, L["under_" + side], float(L["t"]))
		_fill_sprites(L["sprites_" + side])
		_fill(_over, L["over_" + side], float(L["t"]))

	func _fill_sprites(items: Array) -> void:
		while _sprites.get_child_count() < items.size():
			var r := TextureRect.new()
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			r.stretch_mode = TextureRect.STRETCH_KEEP
			r.texture = AtlasTexture.new()
			var m := ShaderMaterial.new()
			m.shader = UniqueFx.SPRITE_SHADER
			r.material = m
			_sprites.add_child(r)
		for i in _sprites.get_child_count():
			var r: TextureRect = _sprites.get_child(i)
			r.visible = i < items.size()
			if not r.visible:
				continue
			var it: Dictionary = items[i]
			var s := UniqueFx.sheet(String(it["sheet"]))
			var fw := int(s["w"])
			var fh := int(s["h"])
			var cols := int(s["cols"])
			var f := int(it["frame"])
			var at: AtlasTexture = r.texture
			at.atlas = s["tex"]
			at.region = Rect2((f % cols) * fw, (f / cols) * fh, fw, fh)
			r.flip_h = bool(it.get("flip", false))
			r.position = it["pos"]
			r.size = Vector2(fw, fh)
			var m: ShaderMaterial = r.material
			m.set_shader_parameter("dissolve", float(it.get("dissolve", 0.0)))
			m.set_shader_parameter("wipe", float(it.get("wipe", 0.0)))
			var asz := Vector2((s["tex"] as Texture2D).get_size())
			m.set_shader_parameter("region_uv", Vector4(at.region.position.x / asz.x, at.region.position.y / asz.y, at.region.end.x / asz.x, at.region.end.y / asz.y))
			m.set_shader_parameter("silhouette", float(it.get("silhouette", 0.0)))
			m.set_shader_parameter("flash", float(it.get("flash", 0.0)))
			m.set_shader_parameter("rim", float(it.get("rim", 0.0)))
			m.set_shader_parameter("rim_dir", it.get("rim_dir", Vector2(-1, -1)))
			m.set_shader_parameter("rim_color", it.get("rim_color", Color(1.0, 0.55, 0.25)))
			m.set_shader_parameter("outline", float(it.get("outline", 1.0)))

	func _fill(holder: Control, items: Array, t: float) -> void:
		while holder.get_child_count() < items.size():
			var r := ColorRect.new()
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var m := ShaderMaterial.new()
			m.shader = UniqueFx.FLUID_SHADER
			r.material = m
			holder.add_child(r)
		for i in holder.get_child_count():
			var r: ColorRect = holder.get_child(i)
			r.visible = i < items.size()
			if not r.visible:
				continue
			var it: Dictionary = items[i]
			var rect: Rect2 = it["rect"]
			r.position = rect.position
			r.size = rect.size
			var m: ShaderMaterial = r.material
			m.set_shader_parameter("mode", int(it["mode"]))
			m.set_shader_parameter("origin", rect.position)
			m.set_shader_parameter("p0", it["p0"])
			m.set_shader_parameter("p1", it["p1"])
			m.set_shader_parameter("w0", float(it["w0"]))
			m.set_shader_parameter("w1", float(it["w1"]))
			m.set_shader_parameter("head", float(it.get("head", 1.0)))
			m.set_shader_parameter("tail", float(it.get("tail", 0.0)))
			m.set_shader_parameter("power", float(it.get("power", 1.0)))
			m.set_shader_parameter("seed", float(it.get("seed", 0.0)))
			m.set_shader_parameter("flip", float(it.get("flip", 1.0)))
			m.set_shader_parameter("cool", float(it.get("cool", 0.22)))
			m.set_shader_parameter("warp", float(it.get("warp", 0.0)))
			m.set_shader_parameter("time", t)
			var ramp := String(it.get("ramp", "fire" if int(it["mode"]) != 2 else "smoke"))
			m.set_shader_parameter("palette", UniqueFx.palette_texture(ramp))
			m.set_shader_parameter("colours", (PixPal.RAMPS[ramp] as Array).size())




## Экранный проход постановки (pix_screen.gdshader): прямоугольник во весь экран, который
## берёт уже нарисованную картинку (доска, карта, слои эффекта) и преломляет, темнит,
## подсвечивает её. Должен быть последним ребёнком витрины. host.fx_view() -> {cid,
## rect, t} — как у холстов CardFx; без хозяина параметры задают через show_params.
class ScreenFx extends ColorRect:
	var host: Control

	func _init(source: Control = null) -> void:
		host = source
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var m := ShaderMaterial.new()
		m.shader = UniqueFx.SCREEN_SHADER
		material = m
		visible = false

	func _process(_delta: float) -> void:
		if host == null:
			return
		var v: Dictionary = host.call("fx_view")
		var p: Dictionary = {}
		if not v.is_empty() and UniqueFx.has(v["cid"]):
			p = UniqueFx.screen_params(v["cid"], v["rect"], UniqueFx.fx_time(v["cid"], v["t"]))
			_cues(String(v["cid"]), float(v["t"]))
		else:
			_cue_t = -1.0
		show_params(p)

	## Звуки постановки (RECIPES "cues": [секунда, имя в assets/sfx/fx/]): каждый — когда
	## время его проходит; новая постановка (время пошло заново) начинает сначала.
	var _cue_t := -1.0

	func _cues(cid: String, t: float) -> void:
		if t < _cue_t:
			_cue_t = -1.0
		for c: Array in UniqueFx.RECIPES[cid].get("cues", []):
			if _cue_t < float(c[0]) and t >= float(c[0]):
				Sfx.play_file("res://assets/sfx/fx/%s.mp3" % c[1])
		_cue_t = t

	## Задать параметры шейдера (пусто — спрятать проход).
	func show_params(p: Dictionary) -> void:
		visible = not p.is_empty()
		if not visible:
			return
		var m: ShaderMaterial = material
		m.set_shader_parameter("game_size", get_viewport_rect().size)
		for k: String in p:
			m.set_shader_parameter(k, p[k])


# --- Red Dragon, фаза A -------------------------------------------------------------
# Сценарий (владелец утвердил 2026-10-18; правки: огонь посередине, тень живая, огонь
# живой, рык вместо реплики, медленнее): дракон не рисуется — он на арте карты.
#   0.00-0.70 заряд: гул, виньетка в багровый, рамка раскаляется, марево, дрожь;
#   0.70      рёв: рык, толчок, стоп-кадр, волна по доске, пепел, красное арта вспыхивает;
#   0.85-2.35 тень дракона пролетает справа налево: крылья машут, хвост и шея волной,
#             за ней ветер и угли; взмахи крыльев слышны;
#   1.90-3.00 огненный вал проносится посередине поля за картой (рёв огня), свечение,
#             дым над ним;
#   2.90-3.40 пепел оседает, рамка гаснет.

const RD_ROAR := 0.7
const RD_SHADOW := Vector2(0.85, 2.45)
const RD_TRAIL_Y := 250.0
const RD_TRAIL_LAG := 0.35
const RD_PATCHES := 46
const RD_END := 3.4
## Лист тени (PixelLab: силуэт сверху + анимация взмахов) и огня (vfx_workbench).
const RD_SHADOW_SHEET := "48426/shadow"
const RD_FIRE_SHEET := "48426/fire"
const RD_SCORCH_SHEET := "48426/scorch"
## Силуэт на листе смотрит вверх-влево; поворот, чтобы летел влево; увеличение.
const RD_SHADOW_ANGLE := -PI * 0.25
const RD_SHADOW_SCALE := 3.0


## Жар рамки карты 0..1: растёт к рёву, на рёве — добела, потом остывает.
static func _rd_heat(t: float) -> float:
	if t < RD_ROAR:
		return 0.15 + 0.6 * PixKit.ease_in(t / RD_ROAR, 1.6)
	return 1.0 - 0.7 * PixKit.ease_out(PixKit.span(t, RD_ROAR, 1.8), 2.0) - 0.3 * PixKit.span(t, 2.6, RD_END)


## Где тень дракона: центр, кадр взмаха (12 к/с по кругу), пасть на экране; пусто —
## тени нет. Летит справа налево через середину экрана, чуть покачиваясь.
static func _rd_shadow(t: float) -> Dictionary:
	var s := PixKit.span(t, RD_SHADOW.x, RD_SHADOW.y)
	if s <= 0.0 or s >= 1.0:
		return {}
	var sheet_d := sheet(RD_SHADOW_SHEET)
	var n := int(sheet_d["anims"]["flap"][1])
	var frame := anim_frame(RD_SHADOW_SHEET, "flap", int(t * 12.0) % n)
	var c := Vector2(lerpf(1380.0, -420.0, s), 250.0 + sin(t * 5.0) * 6.0)
	var size := Vector2(float(sheet_d["w"]), float(sheet_d["h"]))
	var m: Array = sheet_d["mouths"][frame]
	var mouth := c + ((Vector2(float(m[0]), float(m[1])) - size * 0.5) * RD_SHADOW_SCALE).rotated(RD_SHADOW_ANGLE)
	return {"c": c, "frame": frame, "mouth": mouth.floor(), "size": size, "sheet": sheet_d}


## Когда вспыхивает земля в точке x: центр тени прошёл над ней RD_TRAIL_LAG секунд назад.
static func _rd_ignite_at(x: float) -> float:
	var s := (1380.0 - x) / 1800.0
	return lerpf(RD_SHADOW.x, RD_SHADOW.y, s) + RD_TRAIL_LAG


## Где сейчас фронт огненного следа (x) и горит ли след (y, 0..1).
static func _rd_front(t: float) -> Vector2:
	var s := PixKit.span(t - RD_TRAIL_LAG, RD_SHADOW.x, RD_SHADOW.y)
	var x := lerpf(1380.0, -420.0, s)
	var on := PixKit.span(t, _rd_ignite_at(940.0), _rd_ignite_at(900.0)) * (1.0 - PixKit.span(t, 2.7, 3.2))
	return Vector2(clampf(x, 40.0, 920.0), on)


static func _red_dragon_screen(card: Rect2, t: float) -> Dictionary:
	var fade_out := 1.0 - PixKit.span(t, 2.9, RD_END)
	var sh := _rd_shadow(t)
	var art_pulse := 0.0
	if t < RD_ROAR:
		art_pulse = 0.2 + 0.3 * absf(sin(t * 17.0)) * t / RD_ROAR
	else:
		art_pulse = 1.0 - 0.7 * PixKit.ease_out(PixKit.span(t, RD_ROAR, 1.6), 2.0)
	var front := _rd_front(t)
	var p := {
		"time": t,
		"card": Vector4(card.position.x, card.position.y, card.size.x, card.size.y),
		"art": Vector4(card.position.x + 4.0, card.position.y + 22.0, card.size.x - 8.0, 112.0),
		"wave_t": PixKit.span(t, RD_ROAR, RD_ROAR + 0.8) if t >= RD_ROAR else -1.0,
		"wave_c": card.get_center() + Vector2(0, -40),
		"wave_r": 600.0,
		"heat": PixKit.span(t, 0.05, RD_ROAR) * (1.0 - 0.4 * PixKit.span(t, RD_ROAR, 1.6)) * fade_out,
		"art_glow": maxf(art_pulse, front.y * 0.5) * fade_out,
		"shadow_x": -1e4,
		"wind": 0.0,
		"sky": 0.0,
		"vignette": 0.85 * PixKit.ease_out(PixKit.span(t, 0.0, 0.6), 2.0) * fade_out,
	}
	if not sh.is_empty():
		var sd: Dictionary = sh["sheet"]
		var tex: Texture2D = sd["tex"]
		var ts := Vector2(tex.get_size())
		var fw := float(sd["w"])
		var fh := float(sd["h"])
		var cols := int(sd["cols"])
		var f := int(sh["frame"])
		var o := Vector2(float(f % cols) * fw, float(f / cols) * fh)
		p.merge({"shadow_x": (sh["c"] as Vector2).x, "shadow_y": (sh["c"] as Vector2).y,
			"shadow_tex": tex, "shadow_uv": Vector4(o.x / ts.x, o.y / ts.y, (o.x + fw) / ts.x, (o.y + fh) / ts.y),
			"shadow_size": Vector2(fw, fh), "shadow_angle": RD_SHADOW_ANGLE, "shadow_scale": RD_SHADOW_SCALE,
			"wind": 1.0}, true)
	if front.y > 0.0:
		p.merge({"sky": front.y * (0.85 + 0.15 * sin(t * 31.0)), "sky_c": Vector2(front.x + 60.0, RD_TRAIL_Y)}, true)
	return p


static func _red_dragon(L: Dictionary, card: Rect2, t: float) -> void:
	var back: Pix = L["back"]
	var front: Pix = L["front"]
	var fire := PixPal.ramp("fire", Pix.LIGHT)
	var ash := PixPal.ramp("smoke", Pix.LIGHT)
	var heat := _rd_heat(t)

	# раскалённая рамка: внешний ряд и ряд по краю карты, ступень огня по жару,
	# по периметру мерцает кусками (у каждого куска свой шум, меняется по кадрам)
	var frame_i := floori(t * FPS)
	var x0 := int(card.position.x) - 1
	var y0 := int(card.position.y) - 1
	var x1 := int(card.end.x)
	var y1 := int(card.end.y)
	var per := PackedVector2Array()
	for x in range(x0, x1 + 1):
		per.append(Vector2(x, y0))
		per.append(Vector2(x, y1))
	for y in range(y0 + 1, y1):
		per.append(Vector2(x0, y))
		per.append(Vector2(x1, y))
	for q in per:
		var seg := int(q.x + q.y) / 6
		var h := clampf(heat * (0.75 + 0.5 * PixKit.rnd(frame_i / 2, seg)), 0.0, 1.0)
		if h < 0.12:
			continue
		front.put(int(q.x), int(q.y), PixPal.at(fire, 1.0 - h))
		if h > 0.45:
			var inner := q + (card.get_center() - q).sign()
			front.put(int(inner.x), int(inner.y), PixPal.at(fire, minf(1.25 - h, 1.0)))

	# ореол жара вокруг карты (позади неё): три рамки-ступени, дальние — реже
	for i in 3:
		var g := card.grow(2.0 + 3.0 * float(i) + 3.0 * heat)
		var k := clampf(0.2 + 0.25 * float(i) + (1.0 - heat) * 0.7, 0.0, 1.0)
		var c := fire[mini(3 + i, fire.size() - 1)]
		var gx := int(g.position.x)
		var gy := int(g.position.y)
		var gw := int(g.size.x)
		var gh := int(g.size.y)
		back.rect(gx, gy, gw, 3, c, k)
		back.rect(gx, gy + gh - 3, gw, 3, c, k)
		back.rect(gx, gy + 3, 3, gh - 6, c, k)
		back.rect(gx + gw - 3, gy + 3, 3, gh - 6, c, k)

	# фронт ударной волны: огненное кольцо, растворяется
	var wc := card.get_center() + Vector2(0, -40)
	var wt := PixKit.span(t, RD_ROAR, RD_ROAR + 0.8) if t >= RD_ROAR else -1.0
	PixKit.shock(back, wc.x, wc.y, 600.0, wt, fire[2], 6.0)
	PixKit.shock(back, wc.x, wc.y, 570.0, wt, fire[4], 4.0)

	# искры с верхнего края, пока карта раскаляется
	PixKit.embers(front, 61, Vector2(card.get_center().x, card.position.y), t, 30, -PI * 0.5, 1.2, 60.0,
		Vector2(0, -35), 1.2, fire.slice(0, 6), card.size.x)

	# рёв: пепел и угли разлетаются со всех краёв карты
	var since := t - RD_ROAR
	if since >= 0.0:
		var edges := [[Vector2(card.get_center().x, card.position.y), -PI * 0.5, card.size.x],
			[Vector2(card.get_center().x, card.end.y), PI * 0.5, card.size.x],
			[Vector2(card.position.x, card.get_center().y), PI, card.size.y],
			[Vector2(card.end.x, card.get_center().y), 0.0, card.size.y]]
		for i in edges.size():
			var e: Array = edges[i]
			PixKit.embers(front, 70 + i, e[0], since, 22, float(e[1]), 1.0, 200.0, Vector2(0, 80), 1.0,
				fire.slice(0, 7), float(e[2]))
			PixKit.embers(back, 80 + i, e[0], since, 14, float(e[1]), 1.3, 130.0, Vector2(0, 50), 1.2,
				ash.slice(0, 4), float(e[2]))

	# ветер за тенью: угли и пепел несёт влево
	var sd := _rd_shadow(t)
	if not sd.is_empty():
		var sc: Vector2 = sd["c"]
		PixKit.embers(front, 91, sc + Vector2(300.0, 0.0), t - RD_SHADOW.x, 60, PI, 0.3, 420.0,
			Vector2(-160, 10), 0.9, fire.slice(1, 7), 380.0)

	# огненный след (вид сверху): тень пролетела — и за ней с задержкой волной справа
	# налево вспыхивает земля посередине поля: пятна пламени (PixelLab, сверху)
	# разгораются, горят, догорают до тлеющих выжженных пятен; дым над следом
	var by := RD_TRAIL_Y
	var fire_s := sheet(RD_FIRE_SHEET)
	var fn := int(fire_s["anims"]["loop"][1])
	var fw := float(fire_s["w"])
	var fh := float(fire_s["h"])
	var sc_sheet := sheet(RD_SCORCH_SHEET)
	var sn := int(sc_sheet["anims"]["loop"][1])
	for i in RD_PATCHES:
		var x := 40.0 + 880.0 * float(i) / float(RD_PATCHES - 1) + PixKit.rnd_range(141, i, -10.0, 10.0)
		var y := by + PixKit.rnd_range(142, i, -28.0, 28.0)
		var t0 := _rd_ignite_at(x)
		if t < t0:
			continue
		var life := PixKit.rnd_range(143, i, 0.8, 1.2)
		var appear := PixKit.span(t, t0, t0 + 0.1)
		var burnt := PixKit.span(t, t0 + life, t0 + life + 0.35)
		var gone := PixKit.span(t, 2.9, RD_END)
		# выжженное пятно под огнём — с середины горения и до конца
		if t >= t0 + 0.3:
			var sf := anim_frame(RD_SCORCH_SHEET, "loop", (int(t * 10.0) + i * 5) % sn)
			sprite(L, "back", RD_SCORCH_SHEET, sf, Vector2(x - 45.0, y - 20.0),
				{"outline": 0.0, "dissolve": maxf(1.0 - PixKit.span(t, t0 + 0.3, t0 + 0.6), gone), "wipe": 0.0})
		if burnt < 1.0:
			var ff := anim_frame(RD_FIRE_SHEET, "loop", (int(t * 16.0) + i * 3) % fn)
			sprite(L, "back", RD_FIRE_SHEET, ff, Vector2(x - fw * 0.5, y - fh * 0.5),
				{"outline": 0.0, "flip": i % 2 == 1, "dissolve": maxf(1.0 - appear, maxf(burnt, gone)), "wipe": 0.0})
		PixKit.embers(back, 150 + i, Vector2(x, y), t - t0, 6, -PI * 0.5, 2.0, 40.0, Vector2(-15, -25), 1.0,
			fire.slice(0, 6), 30.0)
	var sm := PixKit.span(t, _rd_ignite_at(900.0) + 0.3, _rd_ignite_at(900.0) + 0.7) * (1.0 - PixKit.span(t, 3.0, RD_END))
	if sm > 0.0:
		for i in 4:
			var p0 := Vector2(860.0 - 230.0 * float(i), by - 10.0)
			var on := PixKit.span(t, _rd_ignite_at(p0.x) + 0.25, _rd_ignite_at(p0.x) + 0.6)
			if on > 0.0:
				fluid(L, "back", false, 2, p0, p0 + Vector2(-14, -150), 22.0, 46.0,
					{"power": sm * on * (0.65 + 0.25 * float(i % 2)), "seed": 7.0 + float(i) * 13.0})

	# пепел оседает после вала: медленные хлопья, качаются
	var fall := t - _rd_ignite_at(900.0) - 0.4
	if fall > 0.0:
		for i in 80:
			var born := PixKit.rnd(101, i) * 0.8
			var a := fall - born
			if a < 0.0:
				continue
			var x := PixKit.rnd(102, i) * 960.0 + sin(a * 3.0 + float(i)) * 8.0
			var y := by - 120.0 + PixKit.rnd(105, i) * 60.0 + a * PixKit.rnd_range(103, i, 30.0, 70.0)
			var hot := PixKit.rnd(104, i) < 0.35 and a < 0.6
			var c := fire[2] if hot else ash[mini(i % 3, ash.size() - 1)]
			back.put(floori(x), floori(y), c)
			if i % 3 == 0:
				back.put(floori(x) + 1, floori(y), c)
