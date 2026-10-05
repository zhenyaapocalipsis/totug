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
const MARKER_FILL := Color("f6e08a")
const MARKER_EDGE := Color("e0a820")
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
	_paint_plates(img, schematic)
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


## Подложки гексов (BoardSchematic._plates): комната из набора тайлов темы
## главного города гекса (с маркером, иначе самого большого) — пол внутри,
## стена по краю. Наборы — PixelLab create_topdown_tileset, Wang 16 px: лист
## 4x4, номер тайла = NW*8 + NE*4 + SW*2 + SE (1 — угол на полу). Подложка
## собирается как рамка: углы и края — тайлы стены, середина — тайл «весь
## пол», отражённый по хэшу клетки, чтобы узор не шёл рядами. Нет набора —
## набор "cave".
const WALLS_DIR := "res://assets/board_walls/"
const WALL_TILE := 16
const FLOOR_KEY := 15
## Тайлы темнее, чем сгенерированы: светлые полы (зал, руины, туман) иначе
## спорят с белыми рамками городов и трассами.
const PLATE_DIM := 0.55
const SITE_THEMES := {
	"Lolth Shrine": "temple", "Wells of Darkness": "temple",
	"Great Web": "web", "The Great Web": "web", "Spiderhome": "web",
	"Web (N)": "web", "Web (NE)": "web", "Web (NW)": "web",
	"Web (S)": "web", "Web (SE)": "web", "Web (SW)": "web",
	"Menzoberranzan": "drow", "Erelhei-Cinlu": "drow", "Xal Veldrin": "drow",
	"Zi'Xzolca": "drow", "Xith Idrana": "drow", "Xelathir": "drow",
	"Venathir": "drow", "Enzithir": "drow",
	"Council Chamber": "hall", "Caer Sidi": "hall",
	"Black Gate": "gate", "Red Gate": "gate",
	"Darkflame": "lava", "Magma Gate": "lava",
	"Araumycos": "fungus", "Red Forest": "fungus", "Shedaklah": "fungus",
	"Iblith": "ruins", "Kulggen": "ruins", "Vrith": "ruins",
	"Spiral Desert": "desert", "Iron Wastes": "desert",
	"Fogtown": "mist", "Faerholme": "mist", "Darklight Realm": "mist", "The Twilight": "mist",
	"Thanatos Gate": "necro", "Gallenghast": "necro",
}
static var _walls_cache: Dictionary = {}   # theme -> Image or null


static func _walls(theme: String) -> Variant:
	if not _walls_cache.has(theme):
		var path := WALLS_DIR + "walls_" + theme + ".png"
		var sheet: Variant = null
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				var image := tex.get_image()
				if image.is_compressed():
					image.decompress()
				sheet = image
		_walls_cache[theme] = sheet
	return _walls_cache[theme]


## Тема гекса: город с маркером, иначе город с наибольшим числом мест.
static func _hex_theme(schematic: Dictionary, hex: String) -> String:
	var best := ""
	var best_rank := -1
	for site_id: String in (schematic.get("sites", {}) as Dictionary).keys():
		if site_id.get_slice(":", 0) != hex:
			continue
		var site: Dictionary = schematic["sites"][site_id]
		var rank := (site.get("slots", {}) as Dictionary).size() + (100 if bool(site.get("marker", false)) else 0)
		if rank > best_rank:
			best_rank = rank
			best = String(site.get("name", ""))
	return String(SITE_THEMES.get(best, "cave"))


static func _paint_plates(img: Image, schematic: Dictionary) -> void:
	var t := WALL_TILE
	for hex: String in (schematic.get("plates", {}) as Dictionary).keys():
		var sheet: Variant = _walls(_hex_theme(schematic, hex))
		if sheet == null:
			sheet = _walls("cave")
		if sheet == null:
			continue
		var p: Array = schematic["plates"][hex]
		var x0 := roundi(p[0])
		var y0 := roundi(p[1])
		var w := roundi(p[2])
		var h := roundi(p[3])
		for y in h:
			# ряд тайла: 0 — верхняя стена, 2 — нижняя, 1 — пол; v — строка в тайле
			var row := 0 if y < t else (2 if y >= h - t else 1)
			var v := y if row == 0 else (y - (h - t) if row == 2 else (y - t) % t)
			for x in w:
				var col := 0 if x < t else (2 if x >= w - t else 1)
				var u := x if col == 0 else (x - (w - t) if col == 2 else (x - t) % t)
				# углы тайла на полу: NW, NE, SW, SE
				var key := (8 if col != 0 and row != 0 else 0) + (4 if col != 2 and row != 0 else 0) \
					+ (2 if col != 0 and row != 2 else 0) + (1 if col != 2 and row != 2 else 0)
				var sx := u
				var sy := v
				if key == FLOOR_KEY:
					var flip := absi(hash(Vector3i(x0 + x - u, y0 + y - v, 0))) % 4
					sx = (t - 1 - u) if flip & 1 else u
					sy = (t - 1 - v) if flip & 2 else v
				var px := x0 + x
				var py := y0 + y
				if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
					continue
				var c := (sheet as Image).get_pixel((key % 4) * t + sx, (key / 4) * t + sy)
				if c.a > 0.0:
					img.set_pixel(px, py, Color(c.r * PLATE_DIM, c.g * PLATE_DIM, c.b * PLATE_DIM, c.a))


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


## A troop token as a small image: coloured disc with a dark rim. The
## player's emblem (PlayerProfile) is painted over the disc; its empty
## pixels keep the seat colour.
static func token(colour: Color, emblem: String = "") -> Image:
	var r := BoardSchematic.SLOT_R
	var img := Image.create(r * 2 + 1, r * 2 + 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	disc(img, Vector2i(r, r), r, Color(0.04, 0.03, 0.06))
	disc(img, Vector2i(r, r), r - 1, colour)
	if emblem != "":
		var pixels := PlayerProfile.emblem_pixels(emblem)
		for i in pixels.size():
			if pixels[i].a > 0.0:
				img.set_pixel(i % PlayerProfile.SIZE, i / PlayerProfile.SIZE, pixels[i])
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
	var fill := MARKER_FILL if marker else (BOX_DARK if dark else BOX_LIGHT)
	var ink := BOX_LIGHT if dark and not marker else INK

	# Город с маркером контроля (даёт Influence) — светло-золотая плашка в
	# золотой рамке толщиной 2 (тёмная плашка читалась бы как стартовый город).
	# Второй пиксель рамки снаружи, чтобы не налезть на название и места.
	if marker:
		img.fill_rect(rect.grow(1), MARKER_EDGE)
	img.fill_rect(rect, MARKER_EDGE if marker else (BOX_LIGHT if dark else INK))
	img.fill_rect(rect.grow(-1), fill)
	var box := BoardSchematic.site_box(String(site["name"]), (site["slots"] as Dictionary).size(), marker)
	var name_at: Vector2 = box["name_at"]
	PixelFont.draw_text(img, rect.position.x + int(name_at.x), rect.position.y + int(name_at.y),
		BoardSchematic.short_name(String(site["name"])), ink)
	var vp_at: Vector2 = box["vp_at"]
	PixelFont.draw_text(img, rect.position.x + int(vp_at.x), rect.position.y + int(vp_at.y),
		str(site["vp"]), ink, BoardSchematic.VP_SCALE)
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
