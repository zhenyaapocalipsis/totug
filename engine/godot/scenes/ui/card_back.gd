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
const FIBRES := 58
const TWIST := 3.6
const HOLE := 22.0
## Радиус скругления углов рубашки.
const CORNER := 5.0

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
			var p := Vector2(x + 0.5, y + 0.5) - c
			# Расстояние до края скруглённого прямоугольника (внутри — меньше 0):
			# и край, и полосы рамки одинаково огибают углы — без зазубрин.
			var d := _edge(p, c, CORNER)
			if d > 0.0:
				continue
			var colour: Color
			if d > -1.0:
				colour = RAMP[0]
			elif d > -2.0:
				colour = ink.lightened(0.15)
			elif d > -RIM + 1.0:
				colour = ink
			elif d > -RIM:
				colour = ink.darkened(0.45)
			else:
				var light := _vortex(p.x, p.y)
				# Дизеринг вполсилы: тонкие струи иначе рассыпаются в пунктир.
				colour = RAMP[int(clampf(floorf(light * top + 0.35 + _bay(x, y) * 0.3), 0.0, float(top)))]
			img.set_pixel(x, y, colour)
	return img


## Со знаком расстояние от точки p (от центра) до края прямоугольника
## половины half со скруглёнными углами радиуса radius.
static func _edge(p: Vector2, half: Vector2, radius: float) -> float:
	var q := p.abs() - half + Vector2.ONE * radius
	return q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0) - radius


## Яркость воронки (0..1) в точке dx, dy от центра карты. Основа тёмная;
## светятся отдельные тонкие волокна, закрученные к чёрной дыре. Волокна не
## ровные: их ведёт плавная «рябь», к краям сильнее — как прожилки на
## рубашке Yu-Gi-Oh!.
static func _vortex(dx: float, dy: float) -> float:
	var ry := dy * 0.82
	var r := sqrt(dx * dx + ry * ry)
	var a := atan2(ry, dx)
	# Рябь: сумма медленных синусов по месту; у дыры почти нет, к углам сильнее.
	var ripple := sin(dx * 0.047 + sin(dy * 0.031) * 2.2) * 0.9 + sin(dy * 0.056 - dx * 0.021 + 1.3) * 0.7 \
		+ sin((dx + dy) * 0.083) * 0.25
	var s := a + log(r + 2.0) * TWIST + ripple * clampf((r - 36.0) / 70.0, 0.0, 1.2) * 0.36
	var u := s * FIBRES / TAU
	var fibre := floorf(u)
	# Номер струи по кругу: пройдя оборот, струя остаётся той же (иначе слева
	# от центра, на стыке углов, виден излом).
	var id := fposmod(fibre, float(FIBRES))
	# Светится не каждое волокно: часть ярких, часть еле видных.
	var lit := _hashf(id, 1.0)
	var bright := 0.55 + 0.45 * lit if lit > 0.4 else 0.2 + 0.4 * lit
	var width := 0.24 + 0.24 * _hashf(id, 2.0)
	# Струя идёт отрезками: вспыхивает и гаснет вдоль длины.
	var along := clampf(sin(r * (0.035 + 0.05 * _hashf(id, 3.0)) + _hashf(id, 4.0) * TAU) * 1.2 + 0.65, 0.0, 1.0)
	# Пучки: струи собираются в светлые жгуты с тёмными просветами между ними.
	var bundle := clampf(0.7 + 0.5 * sin(s * 5.0 + sin(r * 0.03) * 1.5), 0.4, 1.0)
	var across := 1.0 - clampf(absf(u - fibre - 0.5) / width, 0.0, 1.0)
	var core := across * across
	var halo := clampf(1.0 - absf(u - fibre - 0.5) / (width * 2.4), 0.0, 1.0)
	var streak := (core + halo * 0.45) * bright * along * bundle
	# Дыра в центре; ярче всего кольцо вокруг неё, к углам тусклее.
	var hole := clampf((r - HOLE) / 34.0, 0.0, 1.0)
	var ring := 1.0 - clampf((r - 75.0) / 75.0, 0.0, 0.6)
	return clampf(streak * pow(hole, 1.3) * ring * 1.6 + 0.04 * hole, 0.0, 1.0)


# --- кисти -------------------------------------------------------------------

static func _bay(x: int, y: int) -> float:
	return BAYER[(posmod(y, 4)) * 4 + posmod(x, 4)] / 16.0


## Случайное число 0..1 от номера волокна (одно и то же при каждом рисовании).
static func _hashf(n: float, salt: float) -> float:
	return fposmod(sin(n * 127.1 + salt * 311.7) * 43758.5453, 1.0)
