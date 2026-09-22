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


static func paint(schematic: Dictionary) -> Image:
	var size: Array = schematic.get("size", [1, 1])
	var img := Image.create(maxi(1, int(size[0])), maxi(1, int(size[1])), false, Image.FORMAT_RGBA8)
	# Заливка прозрачная, а не BG: под доской лежит живой фон экрана
	# (scenes/ui/underdark_bg.gd), и схема должна плыть поверх него.
	# Внутренности колец ниже закрашиваются BG отдельно — там стоят фишки,
	# и им нужен ровный тёмный кружок.
	img.fill(Color(BG, 0.0))
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
