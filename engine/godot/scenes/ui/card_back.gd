class_name CardBack
extends RefCounted

## Рубашка карты в полный размер (CardView.PIXEL_SIZE, 1:1). Рубашка одна на
## всех (решение владельца, 2026-09-30): воронка в духе рубашки Yu-Gi-Oh! —
## густые тонкие волокна закручиваются к чёрной дыре в центре, снаружи ярче,
## к центру темнее; всё в основном цвете карты (тёмно-фиолетовая рамка
## cards_pixel) и его светлых оттенках. Рамка со скруглёнными углами.
## Соперники видят рубашку, когда игрок берёт карту вслепую (CardShowcase).
##
## Рисуется кодом по пикселям: яркость воронки квантуется в палитру RAMP
## дизерингом Байера, без сглаживания.

const CLASSIC := "classic"
const DESIGNS: Array[String] = ["classic"]
const NAMES := {"classic": "CLASSIC"}
## Основной цвет лицевой стороны карты (её рамка) — от него вся палитра.
const FIELD := Color("24153f")
## Цвет рамки рубашки.
const INK := {"classic": "4a2f82"}
## Палитра воронки от тьмы к блику — оттенки цвета карты.
const RAMP: Array[Color] = [Color("0c0716"), Color("1a0f2e"), Color("24153f"), Color("3b2766"),
	Color("5b3f99"), Color("8a6ad0"), Color("c8b4f0")]
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
## Толщина рамки.
const RIM := 7
## Воронка: сколько волокон на оборот, закрутка и центр дыры.
const FIBRES := 46
const TWIST := 4.2
const HOLE := 16.0

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
	var ink := Color(INK[clean(design)])
	var size := Vector2i(CardView.PIXEL_SIZE)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(size) * 0.5
	var top := RAMP.size() - 1
	for y in size.y:
		for x in size.x:
			var cx := mini(x, size.x - 1 - x)
			var cy := mini(y, size.y - 1 - y)
			# Скруглённые углы.
			if cx < 4 and cy < 4 and (4 - cx) * (4 - cx) + (4 - cy) * (4 - cy) > 17:
				continue
			var colour: Color
			if cx == 0 or cy == 0:
				colour = RAMP[0]
			elif cx < RIM or cy < RIM:
				# Рамка: светлая кромка снаружи, тёмная — у поля.
				if cx == 1 or cy == 1:
					colour = ink.lightened(0.15)
				elif cx == RIM - 1 or cy == RIM - 1:
					colour = ink.darkened(0.45)
				else:
					colour = ink
			else:
				var light := _vortex(x + 0.5 - c.x, y + 0.5 - c.y)
				var level := int(clampf(floorf(light * top + _bay(x, y)), 0.0, float(top)))
				colour = RAMP[level]
			img.set_pixel(x, y, colour)
	return img


## Яркость воронки (0..1) в точке dx, dy от центра карты.
static func _vortex(dx: float, dy: float) -> float:
	# Воронка чуть вытянута по высоте карты.
	var ry := dy * 0.8
	var r := sqrt(dx * dx + ry * ry)
	var a := atan2(ry, dx)
	# Логарифмическая спираль: к центру закручивается всё сильнее, как тоннель.
	var s := a + log(r + 2.0) * TWIST
	var u := s * FIBRES / TAU
	var fibre := floorf(u)
	# Каждое волокно — своей яркости и толщины, и мерцает вдоль длины.
	var bright := 0.35 + 0.65 * _hashf(fibre, 1.0)
	var width := 0.35 + 0.35 * _hashf(fibre, 2.0)
	var along := 0.55 + 0.45 * sin(r * (0.06 + 0.05 * _hashf(fibre, 3.0)) + _hashf(fibre, 4.0) * TAU)
	var across := 1.0 - clampf(absf(u - fibre - 0.5) / width, 0.0, 1.0)
	var streak := across * across * bright * along
	# Широкие светлые «рукава» под волокнами — чтобы не было пустоты.
	var arms := 0.5 + 0.5 * sin(s * 4.0 + sin(s * 2.0) * 1.5)
	# Чёрная дыра в центре, ярче всего снаружи, к самым углам чуть гаснет.
	var hole := clampf((r - HOLE) / 42.0, 0.0, 1.0)
	var outer := 1.0 - clampf((r - 105.0) / 60.0, 0.0, 0.35)
	return clampf((streak * 0.8 + arms * 0.5) * pow(hole, 1.6) * outer * 1.45, 0.0, 1.0)


# --- кисти -------------------------------------------------------------------

static func _bay(x: int, y: int) -> float:
	return BAYER[(posmod(y, 4)) * 4 + posmod(x, 4)] / 16.0


## Случайное число 0..1 от номера волокна (одно и то же при каждом рисовании).
static func _hashf(n: float, salt: float) -> float:
	return fposmod(sin(n * 127.1 + salt * 311.7) * 43758.5453, 1.0)
