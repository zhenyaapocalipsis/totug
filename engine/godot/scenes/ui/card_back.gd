class_name CardBack
extends RefCounted

## Рубашка карты в полный размер (CardView.PIXEL_SIZE, 1:1). Рубашки — готовые
## рисунки (решение владельца, 2026-09-30: рисовалки нет; стиль — тёмные
## абстракции, без знаков и без шейдера): поле у всех одного цвета — основного
## цвета лицевой стороны карт (её тёмно-фиолетовой рамки), рамка со
## скруглёнными углами — цвета фракции, по полю — свой геометрический узор в
## два приглушённых тона. CLASSIC есть у всех, остальные — ступени ULTRA —
## выпадают из лутбокса или создаются за пыль (SkinCollection). Соперники
## видят рубашку, когда игрок берёт карту вслепую (CardShowcase).
##
## Всё рисуется кодом по пикселям, без сглаживания.

const CLASSIC := "classic"
## Порядок показа в коллекции: CLASSIC, затем фракции в порядке полуколод.
const DESIGNS: Array[String] = ["classic", "drow", "dragons", "demons", "elementals", "aberrations", "undead"]
const NAMES := {"classic": "CLASSIC", "drow": "DROW", "dragons": "DRAGONS", "demons": "DEMONS",
	"elementals": "ELEMENTALS", "aberrations": "ABERRATIONS", "undead": "UNDEAD"}
## Поле — основной цвет лицевой стороны карты (рамка карт cards_pixel).
const FIELD := Color("24153f")
## Рамка и узор каждой рубашки.
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
## Насколько тона узора ближе к цвету рамки (0 — цвет поля).
const TONES := [0.0, 0.22, 0.45]

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
	var tones: Array[Color] = []
	for k in TONES:
		tones.append(FIELD.lerp(ink, k))
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
			var colour: Color = tones[_tone(d, x - c.x, y - c.y, x, y)]
			if cx < RIM or cy < RIM:
				colour = ink.darkened(0.25) if cx == 0 or cy == 0 else ink
			elif (cx == INNER or cy == INNER) and cx >= INNER and cy >= INNER:
				colour = ink.darkened(0.2)
			elif cx < INNER or cy < INNER:
				colour = FIELD
			img.set_pixel(x, y, colour)
	return img


## Тон узора (0 — поле, 1, 2 — светлее) в точке dx, dy от центра карты.
## Все узоры симметричны относительно центра.
static func _tone(design: String, dx: int, dy: int, x: int, y: int) -> int:
	var ax := absi(dx)
	var ay := absi(dy)
	match design:
		"drow":
			# Вложенные прямоугольники — круги по воде от центра.
			var d := maxf(ax, ay * 0.69)
			return 2 if posmod(int(d), 12) == 0 and d >= 1.0 else (1 if posmod(int(d / 12.0), 2) == 0 else 0)
		"dragons":
			# Шевроны, как чешуя на хребте.
			var v := ay + ax * 0.75
			return 2 if posmod(int(v), 14) == 0 and v >= 1.0 else (1 if posmod(int(v / 14.0), 2) == 1 else 0)
		"demons":
			# Лучи из центра и тёмное сердце.
			var r := Vector2(dx, dy).length()
			if r < 16:
				return 2 if r > 13 else 0
			var sector := int(floorf((atan2(dy, dx) + PI) / TAU * 20.0))
			return 1 if sector % 2 == 0 else 0
		"elementals":
			# Круги, расходящиеся от центра.
			var r := Vector2(dx, dy).length()
			return 2 if posmod(int(r), 10) == 0 and r >= 1.0 else (1 if posmod(int(r / 10.0), 2) == 1 else 0)
		"aberrations":
			# Волны, будто что-то шевелится под поверхностью.
			var w := dy + sin(dx * 0.13) * 5.0
			return 2 if posmod(floori(w), 11) == 0 else (1 if posmod(floori(w / 11.0), 2) == 0 else 0)
		"undead":
			# Решётка квадратов, к краям рассыпается в пыль.
			var cell := posmod(int(floorf((dx + 4) / 8.0)) + int(floorf((dy + 4) / 8.0)), 2) == 0
			var fade := 1.0 - Vector2(ax / 80.0, ay / 118.0).length() * 0.9
			return 1 if cell and _bay(x, y) < fade else 0
		_:
			# CLASSIC: ромбическая сетка, ромбы через один залиты.
			var u := dx + dy
			var v := dx - dy
			if posmod(u, 16) == 0 or posmod(v, 16) == 0:
				return 2
			return 1 if posmod(int(floorf(u / 16.0)) + int(floorf(v / 16.0)), 2) == 0 else 0


# --- кисти -------------------------------------------------------------------

static func _bay(x: int, y: int) -> float:
	return BAYER[(posmod(y, 4)) * 4 + posmod(x, 4)] / 16.0
