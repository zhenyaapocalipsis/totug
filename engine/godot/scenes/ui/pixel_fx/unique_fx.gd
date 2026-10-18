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

## card_id -> постановка: len — сколько секунд держать карту; sound — звук (Sfx);
## stops — остановки времени на ударе [когда, сколько]; shakes — толчки карты
## [когда, сила, затухание]; trembles — дрожь [с, по, сила]; flashes — белые вспышки
## карты (когда).
const RECIPES := {
	# пока пусто: постановка Red Dragon снята владельцем (2026-10-18)
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
	pass


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
			m.set_shader_parameter("time", t)
			var ramp := String(it.get("ramp", "fire" if int(it["mode"]) != 2 else "smoke"))
			m.set_shader_parameter("palette", UniqueFx.palette_texture(ramp))
			m.set_shader_parameter("colours", (PixPal.RAMPS[ramp] as Array).size())


