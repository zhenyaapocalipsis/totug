class_name CardBack
extends RefCounted

## Рубашка карты в полный размер (CardView.PIXEL_SIZE, 1:1). Рубашки — готовые
## рисунки (решение владельца, 2026-09-30: рисовалки нет, стиль — тёмный
## минимализм как в Balatro): поле у всех одного цвета — основного цвета
## лицевой стороны карт (её тёмно-фиолетовой рамки), рамка со скруглёнными
## углами — цвета фракции, поле замощено приглушёнными знаками фракции.
## CLASSIC есть у всех, остальные — ступени ULTRA — выпадают из лутбокса или
## создаются за пыль (SkinCollection). Соперники видят рубашку, когда игрок
## берёт карту вслепую (CardShowcase). В коллекции рубашка переливается
## шейдером card_skin.gdshader (ступень BACK_SHEEN).
##
## Всё рисуется кодом по пикселям, без сглаживания; знаки — пиксельные
## спрайты-строки (# — знак, . — пусто).

const CLASSIC := "classic"
## Порядок показа в коллекции: CLASSIC, затем фракции в порядке полуколод.
const DESIGNS: Array[String] = ["classic", "drow", "dragons", "demons", "elementals", "aberrations", "undead"]
const NAMES := {"classic": "CLASSIC", "drow": "DROW", "dragons": "DRAGONS", "demons": "DEMONS",
	"elementals": "ELEMENTALS", "aberrations": "ABERRATIONS", "undead": "UNDEAD"}
## Поле — основной цвет лицевой стороны карты (рамка карт cards_pixel).
const FIELD := Color("24153f")
## Рамка и знаки каждой рубашки.
const INK := {
	"classic": "b0924a",
	"drow": "9a6ad0",
	"dragons": "d07a2a",
	"demons": "c04450",
	"elementals": "3aa6b6",
	"aberrations": "6aae3a",
	"undead": "7a92c8",
}
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
## Толщина рамки и отступ тонкой внутренней линии от края.
const RIM := 6
const INNER := 10
## Шаг узора знаков; каждый второй ряд сдвинут на полшага.
const STEP := Vector2i(26, 26)
## Насколько знаки узора видны на поле (0 — не видны, 1 — цвет рамки).
const PATTERN_MIX := 0.5

## Знаки узора. У стихий их четыре — огонь, вода, земля, воздух — по очереди.
const GLYPHS := {
	"classic": [[
		"...#...",
		"..#.#..",
		".#...#.",
		"#..#..#",
		".#...#.",
		"..#.#..",
		"...#...",
	]],
	"drow": [[
		"#..#...#..#",
		".#..#.#..#.",
		"..#.###.#..",
		"...#####...",
		"#####.#####",
		"...#####...",
		"..#######..",
		".#.#####.#.",
		"#..#####..#",
		"....###....",
	]],
	"dragons": [[
		"....#....#....#",
		"...##...##...##",
		"...#....#....#.",
		"..##...##...##.",
		"..#....#....#..",
		".##...##...##..",
		".#....#....#...",
		"#....#....#....",
	]],
	"demons": [[
		"#.........#",
		"#.........#",
		"##.......##",
		".##.....##.",
		"..#######..",
		"..#.###.#..",
		"..#######..",
		"...#####...",
	]],
	"elementals": [
		[
			"...#...",
			"..##...",
			"..###.#",
			".####.#",
			".######",
			"###.###",
			"##...##",
			"##...##",
			".#####.",
		], [
			"...#...",
			"...#...",
			"..###..",
			"..###..",
			".#####.",
			"##.####",
			"#.#####",
			"##.####",
			".#####.",
		], [
			"...#...",
			"..###..",
			"..####.",
			".###.#.",
			".######",
			"###.###",
			"#######",
		], [
			"..####.",
			"......#",
			"######.",
			".......",
			"#####..",
			".....#.",
			"..###..",
		],
	],
	"aberrations": [[
		"....#####....",
		"..#########..",
		".####...####.",
		"####..#..####",
		".####...####.",
		"..#########..",
		"....#####....",
	]],
	"undead": [[
		"..#####..",
		".#######.",
		"#########",
		"#..###..#",
		"#..###..#",
		"####.####",
		".#######.",
		"..#.#.#..",
		"..#####..",
	]],
}

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
	var ink := Color(INK[d])
	var shade := FIELD.darkened(0.35)
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
			var colour := FIELD
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
	_pattern(img, d, FIELD.lerp(ink, PATTERN_MIX))
	return img


## Поле замощено знаками рубашки: сетка STEP от центра карты, каждый второй
## ряд со сдвигом; знаки у края поля обрезаются внутренней линией.
static func _pattern(img: Image, design: String, colour: Color) -> void:
	var glyphs: Array = GLYPHS[design]
	var size := img.get_size()
	var inside := Rect2i(INNER + 1, INNER + 1, size.x - 2 * INNER - 2, size.y - 2 * INNER - 2)
	var c := size / 2
	for row in range(-6, 7):
		for col in range(-5, 6):
			var at := c + Vector2i(col * STEP.x + (STEP.x / 2 if posmod(row, 2) == 1 else 0), row * STEP.y)
			var glyph: Array = glyphs[posmod(row * 3 + col, glyphs.size())]
			var h := glyph.size()
			var w := String(glyph[0]).length()
			var origin := at - Vector2i(w / 2, h / 2)
			for gy in h:
				var line: String = glyph[gy]
				for gx in line.length():
					var p := origin + Vector2i(gx, gy)
					if line[gx] == "#" and inside.has_point(p):
						img.set_pixelv(p, colour)


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
