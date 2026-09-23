class_name SchematicPainter
extends RefCounted

## Paints BoardSchematic.build() output into a 1x pixel-art image: traces,
## tunnel rings, site boxes with names, troop spaces and VP. Troops, spies and
## highlights are drawn on top by BoardPanel, so the image only changes when
## the board itself does.

const BG := Color(0.05, 0.05, 0.07)
const TRACE := Color("d9d2ea")
const BOX_LIGHT := Color("e6e0f0")
const BOX_DARK := Color("1c1830")
const INK := Color("241c34")
const MARKER := Color("f2d23c")
const TRACE_WIDTH := 2
## Скругление прямого угла: угол срезается на столько пикселей вдоль каждой
## стороны, а срез заполняется диагональю. Больше 3 на пиксельной схеме уже не
## «скругление», а заметный скос.
const CORNER_R := 3.0

## Stage 0 (см. memory project_board_packing / чат 2026-09-23): фон под схемой
## из арта отдельных гексов, PixelLab, dark fantasy card art. Сырой арт —
## res://assets/hex_bg/hex_<ID>.png, ОДНА картинка на плитку (не 6 поворотов):
## поворот и «сжатие» схемы (BoardSchematic.SQUEEZE) применяются к пикселям
## арта на лету при выборке (_sample_art), той же формулой, что кладёт узлы и
## трассы (BoardBuilder.rotate_local -> BoardSchematic.to_schematic). Плитки
## без файла просто остаются без фона — старый вид не меняется.
##
## Соседи на схеме не гасятся друг под друга (владелец, 2026-09-23: без
## виньетки) — на стыке виден настоящий край арта, каким его сгенерировали.
const ART_DIR := "res://assets/hex_bg/"
## Пикселей арта на единицу раскладки (те же единицы, что INRADIUS). Подобрано
## так, чтобы апофема гекса (INRADIUS) укладывалась в разумный радиус арта —
## величина того же порядка, что и сама плитка при генерации (~176x176).
const ART_SCALE := 10.0
## Схема развёрнута на 90° (см. _blit_hex_art) — этим компенсируем, чтобы арт
## смотрел на игрока, а не «лежал на боку».
const ART_FACING_OFFSET := -90.0

static var _art_cache: Dictionary = {}   # tile id -> Image or null (нет файла)

## Тематические объекты (PixelLab, владелец 2026-09-23): вручную подобраны
## под лор конкретных плиток, а не под все 27 — рисуются как есть, без обрезки
## по гексу и без поворота под rotation плитки (это отдельно стоящий объект,
## а не сама поверхность гекса).
const OBJECTS_DIR := "res://assets/hex_objects/"
const OBJECT_TILES := ["B2", "C2"]   # Lolth Shrine (паук), Araumycos (грибы)
static var _object_cache: Dictionary = {}   # tile id -> Image or null (нет файла)


static func paint(schematic: Dictionary, show_art := false, show_objects := false) -> Image:
	var size: Array = schematic.get("size", [1, 1])
	var img := Image.create(maxi(1, int(size[0])), maxi(1, int(size[1])), false, Image.FORMAT_RGBA8)
	# Заливка прозрачная, а не BG: под доской лежит живой фон экрана
	# (scenes/ui/underdark_bg.gd), и схема должна плыть поверх него.
	# Внутренности колец ниже закрашиваются BG отдельно — там стоят фишки,
	# и им нужен ровный тёмный кружок.
	img.fill(Color(BG, 0.0))
	if show_art:
		_paint_background(img, schematic)
	if show_objects:
		_paint_objects(img, schematic)
	for flat: Array in schematic.get("traces", []):
		var points := PackedVector2Array()
		for i in range(0, flat.size(), 2):
			points.append(Vector2(flat[i], flat[i + 1]))
		for seg: Array in rounded(points):
			_line(img, seg[0], seg[1], TRACE)
	for slot_id: String in (schematic.get("rings", {}) as Dictionary).keys():
		var at: Array = schematic["rings"][slot_id]
		var c := Vector2i(roundi(at[0]), roundi(at[1]))
		disc(img, c, BoardSchematic.RING_R, TRACE)
		disc(img, c, BoardSchematic.RING_R - 2, BG)
	for site_id: String in (schematic.get("sites", {}) as Dictionary).keys():
		_site(img, schematic["sites"][site_id])
	return img


## Ломаная со скруглёнными углами, отрезками [от, до]. Каждый угол срезается
## на CORNER_R вдоль обеих сторон (но не больше половины короткой стороны), а
## сам срез рисуется диагональю: на пиксельной картинке это и читается как
## скругление. Концы ломаной остаются на месте — трасса должна доходить до
## рамки локации и до кольца.
static func rounded(points: PackedVector2Array) -> Array:
	var out: Array = []
	if points.size() < 2:
		return out
	var at := points[0]
	for i in range(1, points.size()):
		var corner := points[i]
		if i == points.size() - 1:
			out.append([at, corner])
			break
		var into := (corner - at)
		var out_of := (points[i + 1] - corner)
		var r := minf(CORNER_R, minf(into.length(), out_of.length() * 0.5))
		if r < 1.0:
			out.append([at, corner])
			at = corner
			continue
		var before := corner - into.normalized() * r
		var after := corner + out_of.normalized() * r
		out.append([at, before])
		out.append([before, after])
		at = after
	return out


## Filled pixel circle (the same shape the card tool uses).
static func disc(img: Image, c: Vector2i, r: int, colour: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r + r:
				var x := c.x + dx
				var y := c.y + dy
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					img.set_pixel(x, y, colour)


## A troop token as a small image: coloured disc with a dark rim.
static func token(colour: Color) -> Image:
	var r := BoardSchematic.SLOT_R
	var img := Image.create(r * 2 + 1, r * 2 + 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	disc(img, Vector2i(r, r), r, Color(0.04, 0.03, 0.06))
	disc(img, Vector2i(r, r), r - 1, colour)
	return img


## Octilinear line with a square brush, so diagonals stay as thick as straights.
static func _line(img: Image, a: Vector2, b: Vector2, colour: Color) -> void:
	var from := Vector2i(a.round())
	var to := Vector2i(b.round())
	var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
	var off := TRACE_WIDTH / 2
	for i in steps + 1:
		var t := 0.0 if steps == 0 else float(i) / steps
		var p := Vector2i((Vector2(from) + Vector2(to - from) * t).round())
		img.fill_rect(Rect2i(p.x - off, p.y - off, TRACE_WIDTH, TRACE_WIDTH), colour)


static func _site(img: Image, site: Dictionary) -> void:
	var r: Array = site["rect"]
	var rect := Rect2i(roundi(r[0]), roundi(r[1]), roundi(r[2]), roundi(r[3]))
	var dark := bool(site.get("starting", false))
	var marker := bool(site.get("marker", false))
	var fill := BOX_DARK if dark else BOX_LIGHT
	var ink := BOX_LIGHT if dark else INK

	img.fill_rect(rect, MARKER if marker else (BOX_LIGHT if dark else INK))
	img.fill_rect(rect.grow(-1), fill)
	var box := BoardSchematic.site_box(String(site["name"]), (site["slots"] as Dictionary).size())
	var name_at: Vector2 = box["name_at"]
	PixelFont.draw_text(img, rect.position.x + int(name_at.x), rect.position.y + int(name_at.y),
		BoardSchematic.short_name(String(site["name"])), ink)
	var vp_at: Vector2 = box["vp_at"]
	PixelFont.draw_text(img, rect.position.x + int(vp_at.x), rect.position.y + int(vp_at.y),
		str(site["vp"]), MARKER if marker else ink, BoardSchematic.VP_SCALE)
	for slot_id: String in (site["slots"] as Dictionary).keys():
		var at: Array = site["slots"][slot_id]
		var c := Vector2i(roundi(at[0]), roundi(at[1]))
		disc(img, c, BoardSchematic.SLOT_R, ink)
		disc(img, c, BoardSchematic.SLOT_R - 1, fill)


# --- фон из арта гексов (Stage 0) ---------------------------------------------

static func _raw_art(tile_id: String) -> Variant:
	if tile_id == "":
		return null
	if not _art_cache.has(tile_id):
		var path := ART_DIR + "hex_%s.png" % tile_id
		_art_cache[tile_id] = Image.load_from_file(path) if FileAccess.file_exists(path) else null
	return _art_cache[tile_id]


static func _paint_background(img: Image, schematic: Dictionary) -> void:
	for hex: String in (schematic.get("hexes", {}) as Dictionary).keys():
		var info: Dictionary = schematic["hexes"][hex]
		var art: Variant = _raw_art(String(info.get("tile", "")))
		if art == null:
			continue
		var centre := Vector2(float(info["x"]), float(info["y"]))
		_blit_hex_art(img, art, centre, float(info.get("rotation", 0.0)))


# --- тематические объекты на отдельных плитках -----------------------------

static func _raw_object(tile_id: String) -> Variant:
	if tile_id == "" or not OBJECT_TILES.has(tile_id):
		return null
	if not _object_cache.has(tile_id):
		var path := OBJECTS_DIR + "obj_%s.png" % tile_id
		_object_cache[tile_id] = Image.load_from_file(path) if FileAccess.file_exists(path) else null
	return _object_cache[tile_id]


## В отличие от _blit_hex_art: без обрезки по контуру гекса и без поворота —
## объект просто стоит по центру своего гекса, своей высотой вверх.
static func _paint_objects(img: Image, schematic: Dictionary) -> void:
	for hex: String in (schematic.get("hexes", {}) as Dictionary).keys():
		var info: Dictionary = schematic["hexes"][hex]
		var obj: Variant = _raw_object(String(info.get("tile", "")))
		if obj == null:
			continue
		var object_img: Image = obj
		var centre := Vector2(float(info["x"]), float(info["y"]))
		var at := Vector2i(centre) - object_img.get_size() / 2
		# У крайних гексов доски центр стоит близко к краю самой картинки схемы
		# (IMAGE_MARGIN всего в пару пикселей) — без этого объект обрезался бы
		# рамкой картинки. Сдвигаем внутрь, а не обрезаем.
		at.x = clampi(at.x, 0, img.get_width() - object_img.get_width())
		at.y = clampi(at.y, 0, img.get_height() - object_img.get_height())
		img.blend_rect(object_img, Rect2i(Vector2i.ZERO, object_img.get_size()), at)


## Кладёт арт одной плитки в её гекс схемы. Гекс на схеме сжат и повёрнут на
## 90° (BoardSchematic.to_schematic), а сама плитка ещё повёрнута на свою
## rotation_deg (BoardBuilder.rotate_local) — картинка идёт ВЫБОРКОЙ (обратным
## преобразованием) из неповёрнутого сырого арта в уже готовые пиксели схемы,
## а не наоборот: тогда никакой домашней заготовки на 6 поворотов не нужно,
## одна картинка на плитку покрывает все.
##
## Вывод формулы — core/map/board_schematic.gd (_collect, to_schematic) и
## core/map/board_builder.gd (rotate_local), сведены в две линейные замены:
##   печатное (x,z) --rotate_local(rot)--> (rx,rz)
##   (rx,rz) --to_schematic--> (fx,fy) = (rz, rx/SQUEEZE) * (K/INRADIUS)
## Обратная замена (dest -> печатное) — ниже, x/z даны через cos/sin поворота.
static func _blit_hex_art(img: Image, art: Image, centre: Vector2, rotation_deg: float) -> void:
	var poly := BoardSchematic.hex_polygon(centre)
	var bbox := Rect2(poly[0], Vector2.ZERO)
	for p: Vector2 in poly:
		bbox = bbox.expand(p)
	var x0 := maxi(0, int(floor(bbox.position.x)))
	var y0 := maxi(0, int(floor(bbox.position.y)))
	var x1 := mini(img.get_width() - 1, int(ceil(bbox.end.x)))
	var y1 := mini(img.get_height() - 1, int(ceil(bbox.end.y)))

	# Вся схема развёрнута на 90° по часовой (BoardSchematic: "hex north points
	# right") — арт рисовался «как смотрят на карту сверху», поэтому его нужно
	# довернуть на те же 90°, иначе сюжет ложится на бок.
	var rad := deg_to_rad(rotation_deg + ART_FACING_OFFSET)
	var cos_r := cos(rad)
	var sin_r := sin(rad)
	var k_ir := BoardSchematic.K / BoardSchematic.INRADIUS
	var art_c := Vector2(art.get_width() / 2.0, art.get_height() / 2.0)

	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var pt := Vector2(x, y)
			if not Geometry2D.is_point_in_polygon(pt, poly):
				continue
			var f := pt - centre
			# dest (f) -> печатное (x,z), обратное to_schematic + rotate_local
			var a := f.x / k_ir
			var b := f.y * BoardSchematic.SQUEEZE / k_ir
			var lx := cos_r * b - sin_r * a
			var lz := sin_r * b + cos_r * a
			var ax := roundi(art_c.x + lx * ART_SCALE)
			var ay := roundi(art_c.y - lz * ART_SCALE)
			if ax < 0 or ay < 0 or ax >= art.get_width() or ay >= art.get_height():
				continue
			img.set_pixel(x, y, art.get_pixel(ax, ay))
