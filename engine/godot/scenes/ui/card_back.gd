class_name CardBack
extends RefCounted

## Рубашка карты в полный размер (CardView.PIXEL_SIZE, 1:1). Рубашки — готовые
## рисунки (решение владельца, 2026-09-30: рисовалки больше нет, стиль —
## тёмный минимализм как в Balatro): сплошной тёмный цвет фракции, толстая
## приглушённая рамка со скруглёнными углами и один простой знак в центре.
## CLASSIC есть у всех, остальные — по одной на фракцию, ступени ULTRA —
## выпадают из лутбокса или создаются за пыль (SkinCollection). Соперники
## видят рубашку, когда игрок берёт карту вслепую (CardShowcase).
##
## Всё рисуется кодом по пикселям, без сглаживания; переход к краям поля —
## дизеринг, без градиента.

const CLASSIC := "classic"
## Порядок показа в коллекции: CLASSIC, затем фракции в порядке полуколод.
const DESIGNS: Array[String] = ["classic", "drow", "dragons", "demons", "elementals", "aberrations", "undead"]
const NAMES := {"classic": "CLASSIC", "drow": "DROW", "dragons": "DRAGONS", "demons": "DEMONS",
	"elementals": "ELEMENTALS", "aberrations": "ABERRATIONS", "undead": "UNDEAD"}
## Поле и рамка/знак каждой рубашки.
const LOOK := {
	"classic": ["1e1830", "a08a4a"],
	"drow": ["22103a", "8a62b8"],
	"dragons": ["2e1406", "b86a26"],
	"demons": ["2e080e", "a83a46"],
	"elementals": ["06262e", "3a96a6"],
	"aberrations": ["122a0c", "5e9a34"],
	"undead": ["0e1630", "6a80b4"],
}
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
## Толщина рамки и отступ тонкой внутренней линии от края.
const RIM := 6
const INNER := 10

## Череп нежити: # — кость, o — глазница.
const SKULL := [
	"..#######..",
	".#########.",
	"###########",
	"###########",
	"#ooo###ooo#",
	"#ooo###ooo#",
	"###########",
	".####o####.",
	"..#######..",
	"..#.#.#.#..",
	"..#######..",
]

static var _textures: Dictionary = {}


## Рубашка из чужих рук (сеть, файл): известный рисунок или CLASSIC.
static func clean(design: String) -> String:
	return design if DESIGNS.has(design) else CLASSIC


## Готовая текстура рубашки; повторы берутся из кэша.
static func texture(design: String) -> ImageTexture:
	var d := clean(design)
	if not _textures.has(d):
		_textures[d] = ImageTexture.create_from_image(image(d))
	return _textures[d]


static func image(design: String) -> Image:
	var d := clean(design)
	var fill := Color(LOOK[d][0])
	var ink := Color(LOOK[d][1])
	var shade := fill.darkened(0.35)
	var size := Vector2i(CardView.PIXEL_SIZE)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := size / 2
	for y in size.y:
		for x in size.x:
			var cx := mini(x, size.x - 1 - x)
			var cy := mini(y, size.y - 1 - y)
			# Скруглённые углы.
			if cx < 4 and cy < 4 and (4 - cx) * (4 - cx) + (4 - cy) * (4 - cy) > 17:
				continue
			var colour := fill
			if cx < RIM or cy < RIM:
				colour = ink.darkened(0.25) if cx == 0 or cy == 0 else ink
			elif (cx == INNER or cy == INNER) and cx >= INNER and cy >= INNER:
				colour = ink.darkened(0.2)
			elif cx > INNER and cy > INNER:
				# К краям поля темнее — дизерингом.
				var dist := Vector2(x - c.x, (y - c.y) * 0.7).length() / 110.0
				if _bay(x, y) < dist * 0.6:
					colour = shade
			img.set_pixel(x, y, colour)
	match d:
		"drow":
			_spider(img, c, ink, fill)
		"dragons":
			_claws(img, c, ink)
		"demons":
			_horns(img, c, ink, fill)
		"elementals":
			_elements(img, c, ink, fill)
		"aberrations":
			_eye(img, c, ink, fill)
		"undead":
			_skull(img, c, ink, fill)
		_:
			_diamond(img, c, ink, fill)
	return img


# --- знаки -------------------------------------------------------------------

## CLASSIC: ромб-рамка.
static func _diamond(img: Image, c: Vector2i, ink: Color, fill: Color) -> void:
	for d in 14:
		img.fill_rect(Rect2i(c.x - (13 - d), c.y - d, (13 - d) * 2 + 1, 1), ink)
		img.fill_rect(Rect2i(c.x - (13 - d), c.y + d, (13 - d) * 2 + 1, 1), ink)
	for d in 8:
		img.fill_rect(Rect2i(c.x - (7 - d), c.y - d, (7 - d) * 2 + 1, 1), fill)
		img.fill_rect(Rect2i(c.x - (7 - d), c.y + d, (7 - d) * 2 + 1, 1), fill)


## DROW: паук — брюшко, голова и восемь ног.
static func _spider(img: Image, c: Vector2i, ink: Color, fill: Color) -> void:
	var r := Rect2i(Vector2i.ZERO, img.get_size())
	for leg in 4:
		for side in [-1, 1]:
			var knee := c + Vector2i(side * (10 + leg * 2), -9 + leg * 5)
			var foot := knee + Vector2i(side * 6, 7 + leg)
			for w in 2:
				_line(img, c + Vector2i(w * side, -3 + leg * 2), knee + Vector2i(w * side, 0), ink, r)
				_line(img, knee + Vector2i(w * side, 0), foot + Vector2i(w * side, 0), ink, r)
	_disc(img, c + Vector2i(0, 6), 8, ink, ink)
	_disc(img, c + Vector2i(0, -6), 5, ink, ink)
	img.fill_rect(Rect2i(c + Vector2i(-1, 3), Vector2i(3, 2)), fill)
	img.fill_rect(Rect2i(c + Vector2i(0, 5), Vector2i(1, 3)), fill)
	img.fill_rect(Rect2i(c + Vector2i(-1, 8), Vector2i(3, 2)), fill)


## DRAGONS: три следа когтей.
static func _claws(img: Image, c: Vector2i, ink: Color) -> void:
	for k in [-1, 0, 1]:
		for t in 30:
			var y := -15 + t
			var x: int = k * 9 + roundi(-y * 0.35 + sin(t * 0.1) * 2.0)
			var half := int(2.5 * sin(PI * t / 29.0) + 0.5)
			img.fill_rect(Rect2i(c.x + x - half, c.y + y, half * 2 + 1, 1), ink)


## DEMONS: пара рогов над полукругом лба.
static func _horns(img: Image, c: Vector2i, ink: Color, fill: Color) -> void:
	for side in [-1, 1]:
		for t in 26:
			var k := t / 25.0
			var x: int = side * roundi(6 + 12 * sin(k * 1.9))
			var y := 8 - roundi(26 * k)
			var half := int(4.0 * (1.0 - k) + 0.5)
			img.fill_rect(Rect2i(c.x + x - half, c.y + y, half * 2 + 1, 1), ink)
	for y in range(0, 10):
		var half := int(sqrt(maxf(0.0, 100.0 - y * y)) * 1.1)
		img.fill_rect(Rect2i(c.x - half, c.y + 6 + y, half * 2 + 1, 1), ink)
	img.fill_rect(Rect2i(c + Vector2i(-6, 9), Vector2i(4, 2)), fill)
	img.fill_rect(Rect2i(c + Vector2i(3, 9), Vector2i(4, 2)), fill)


## ELEMENTALS: круг, разделённый крестом на четыре стихии.
static func _elements(img: Image, c: Vector2i, ink: Color, fill: Color) -> void:
	_disc(img, c, 15, ink, ink)
	_disc(img, c, 11, fill, fill)
	img.fill_rect(Rect2i(c.x - 1, c.y - 15, 3, 31), ink)
	img.fill_rect(Rect2i(c.x - 15, c.y - 1, 31, 3), ink)
	for q in [Vector2i(-6, -6), Vector2i(6, -6), Vector2i(-6, 6), Vector2i(6, 6)]:
		_disc(img, c + q, 2, ink, ink)


## ABERRATIONS: глаз с круглым зрачком и ресницами-стебельками.
static func _eye(img: Image, c: Vector2i, ink: Color, fill: Color) -> void:
	for y in range(-9, 10):
		var half := int(16.0 * sqrt(1.0 - (y * y) / 100.0))
		img.fill_rect(Rect2i(c.x - half, c.y + y, half * 2 + 1, 1), ink)
	_disc(img, c, 6, fill, fill)
	_disc(img, c, 3, ink, ink)
	for k in [-2, -1, 0, 1, 2]:
		var a: float = -PI / 2.0 + k * 0.5
		var from := c + Vector2i(roundi(cos(a) * 12), roundi(sin(a) * 9))
		var to := c + Vector2i(roundi(cos(a) * 19), roundi(sin(a) * 17))
		_line(img, from, to, ink, Rect2i(Vector2i.ZERO, img.get_size()))


## UNDEAD: череп.
static func _skull(img: Image, c: Vector2i, ink: Color, fill: Color) -> void:
	var zoom := 3
	var w: int = String(SKULL[0]).length()
	var origin := c - Vector2i(w * zoom / 2, SKULL.size() * zoom / 2)
	for row in SKULL.size():
		var line: String = SKULL[row]
		for col in line.length():
			if line[col] == ".":
				continue
			img.fill_rect(Rect2i(origin + Vector2i(col, row) * zoom, Vector2i.ONE * zoom),
				fill if line[col] == "o" else ink)


# --- кисти -------------------------------------------------------------------

static func _bay(x: int, y: int) -> float:
	return BAYER[(posmod(y, 4)) * 4 + posmod(x, 4)] / 16.0


static func _hash(x: int, y: int) -> float:
	var h := x * 374761393 + y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0x7fffffff) / 2147483647.0


## Отрезок по Брезенхэму, только внутри rect.
static func _line(img: Image, a: Vector2i, b: Vector2i, colour: Color, rect: Rect2i) -> void:
	var d := (b - a).abs()
	var s := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var err := d.x - d.y
	var p := a
	for _i in d.x + d.y + 2:
		if rect.has_point(p):
			img.set_pixelv(p, colour)
		if p == b:
			break
		var e2 := err * 2
		if e2 > -d.y:
			err -= d.y
			p.x += s.x
		if e2 < d.x:
			err += d.x
			p.y += s.y


static func _disc(img: Image, c: Vector2i, radius: int, fill: Color, rim: Color) -> void:
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var dd := x * x + y * y
			if dd <= radius * radius + radius:
				img.set_pixelv(c + Vector2i(x, y), rim if dd > (radius - 1) * (radius - 1) + radius - 1 else fill)


static func _ring(img: Image, c: Vector2i, radius: int, colour: Color) -> void:
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var dd := x * x + y * y
			if dd <= radius * radius + radius and dd > (radius - 1) * (radius - 1) + radius - 1:
				img.set_pixelv(c + Vector2i(x, y), colour)


static func _outline(img: Image, r: Rect2i, colour: Color) -> void:
	img.fill_rect(Rect2i(r.position, Vector2i(r.size.x, 1)), colour)
	img.fill_rect(Rect2i(r.position.x, r.end.y - 1, r.size.x, 1), colour)
	img.fill_rect(Rect2i(r.position, Vector2i(1, r.size.y)), colour)
	img.fill_rect(Rect2i(r.end.x - 1, r.position.y, 1, r.size.y), colour)
