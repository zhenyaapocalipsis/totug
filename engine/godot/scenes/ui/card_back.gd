class_name CardBack
extends RefCounted

## Рубашка карты в полный размер (CardView.PIXEL_SIZE, 1:1). Рубашки — готовые
## рисунки (решение владельца, 2026-09-30: рисовалки нет, без знаков и без
## шейдера; стиль — воронка, как рубашка Yu-Gi-Oh!): светящиеся струи по
## спирали вокруг чёрной дыры, в цвете фракции на тёмном цвете карты; рамка со
## скруглёнными углами — цвета фракции. У каждой фракции своя закрутка
## (VORTEX). CLASSIC есть у всех, остальные — ступени ULTRA —
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
## Воронка каждой рубашки: [сколько рукавов, закрутка, направление].
const VORTEX := {
	"classic": [6, 2.6, 1],
	"drow": [7, 2.9, -1],
	"dragons": [5, 2.3, 1],
	"demons": [6, 3.2, -1],
	"elementals": [8, 2.4, 1],
	"aberrations": [5, 3.4, 1],
	"undead": [7, 2.2, -1],
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
	# Палитра воронки: почти чёрный (цвет карты во тьме) -> цвет фракции -> блик.
	var ramp: Array[Color] = [FIELD.darkened(0.55), FIELD.lerp(ink, 0.25).darkened(0.35), ink.darkened(0.3),
		ink, ink.lightened(0.45)]
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
			var colour: Color
			if cx < RIM or cy < RIM:
				colour = ink.darkened(0.25) if cx == 0 or cy == 0 else ink.darkened(0.1)
			elif (cx == INNER or cy == INNER) and cx >= INNER and cy >= INNER:
				colour = ink.darkened(0.35)
			elif cx < INNER or cy < INNER:
				colour = ramp[0]
			else:
				var level := int(clampf(floorf(_vortex(d, x - c.x, y - c.y) * 4.0 + _bay(x, y)), 0.0, 4.0))
				colour = ramp[level]
			img.set_pixel(x, y, colour)
	return img


## Яркость воронки (0..1) в точке dx, dy от центра: логарифмическая спираль
## тонких светящихся струй, чёрная дыра в центре, к краям темнее.
static func _vortex(design: String, dx: int, dy: int) -> float:
	var v: Array = VORTEX[design]
	var arms := float(v[0])
	var ry := dy * 0.78
	var r := sqrt(dx * dx + ry * ry)
	var a := atan2(ry, float(dx)) * float(v[2])
	var s := a + log(r + 1.0) * float(v[1])
	# Струи: узкие гребни, чуть колеблются; вторая, тонкая семья — между ними.
	var ridge := pow(maxf(0.0, sin(s * arms + sin(s * 2.0 + r * 0.045) * 1.3)), 7.0)
	var thin := pow(maxf(0.0, sin(s * arms * 2.0 + 1.7 + r * 0.02)), 12.0)
	# Частота — целая: иначе на стыке углов (слева от центра) виден шов.
	var glow := 0.5 + 0.5 * sin(s * floorf(arms * 0.5) + 1.0)
	var light := ridge * 0.8 + thin * 0.35 + glow * 0.22
	var hole := clampf((r - 12.0) / 34.0, 0.0, 1.0)
	var edge := 1.0 - clampf((r - 60.0) / 90.0, 0.0, 1.0) * 0.6
	return light * hole * hole * edge


# --- кисти -------------------------------------------------------------------

static func _bay(x: int, y: int) -> float:
	return BAYER[(posmod(y, 4)) * 4 + posmod(x, 4)] / 16.0
