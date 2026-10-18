class_name Pix
extends RefCounted

## Пиксельный холст эффектов уникальных карт: рисуем точками, как художник в
## редакторе, а не векторами со сглаживанием. Один пиксель холста = один пиксель
## экрана игры (960x540). Правила (разбор Blasphemous, Kirokaze, waneella):
## - цвета только из палитры (PixPal), никакой полупрозрачности: где нужно «гаснуть»,
##   пиксели выпадают узором Байера (растворение дырами), как в Blasphemous;
## - формы — по центрам пикселей, без лесенок-двойников;
## - холст знает свой угол на экране (ox, oy), рисуют в координатах экрана.
## Сплошные формы заливаются строками (Image.fill_rect) — GDScript медленный на
## отдельных точках, а комьев огня в кадре сотни.
##
## Альфа хранит вид пикселя для шейдера обводки (pix_outline.gdshader):
## MATTER (255) — «вещество», вокруг него шейдер рисует цветную обводку;
## LIGHT (254) — свет, искры, огонь: без обводки.

const MATTER := 255
const LIGHT := 254
const NONE := Color(0, 0, 0, 0)

## Порог Байера 4x4 (0..15): какой пиксель выпадает первым при растворении.
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var w: int
var h: int
var ox := 0
var oy := 0
var img: Image
var _tex: ImageTexture
## Окно обрезки в пикселях холста (рисуется только внутри); по умолчанию весь холст.
var _cx0 := 0
var _cy0 := 0
var _cx1 := 0
var _cy1 := 0


func _init(width: int, height: int) -> void:
	w = width
	h = height
	img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	no_clip()


## Рисовать только внутри прямоугольника r (координаты экрана): например, свет огня —
## только на карте, а не бурыми кругами по тёмному фону.
func set_clip(r: Rect2) -> void:
	_cx0 = maxi(floori(r.position.x) - ox, 0)
	_cy0 = maxi(floori(r.position.y) - oy, 0)
	_cx1 = mini(ceili(r.end.x) - ox, w) - 1
	_cy1 = mini(ceili(r.end.y) - oy, h) - 1


func no_clip() -> void:
	_cx0 = 0
	_cy0 = 0
	_cx1 = w - 1
	_cy1 = h - 1


## Цвет палитры с видом пикселя в альфе (MATTER или LIGHT).
static func col(c: Color, kind: int = MATTER) -> Color:
	return Color(c.r, c.g, c.b, float(kind) / 255.0)


static func hex(s: String, kind: int = MATTER) -> Color:
	return col(Color(s), kind)


static func as_kind(c: Color, kind: int) -> Color:
	return Color(c.r, c.g, c.b, float(kind) / 255.0)


func clear() -> void:
	img.fill(NONE)


## Пиксель выпадает при растворении силы k (0 — цел, 1 — исчез целиком).
static func gone(x: int, y: int, k: float) -> bool:
	return k * 16.0 > float(BAYER[(y & 3) * 4 + (x & 3)]) + 0.5


func put(x: int, y: int, c: Color) -> void:
	x -= ox
	y -= oy
	if x < _cx0 or y < _cy0 or x > _cx1 or y > _cy1:
		return
	img.set_pixel(x, y, c)


## Пиксель с растворением k (узор Байера, привязан к экрану — узор не «плывёт»).
func put_d(x: int, y: int, c: Color, k: float) -> void:
	if k > 0.0 and gone(x, y, k):
		return
	put(x, y, c)


func get_c(x: int, y: int) -> Color:
	x -= ox
	y -= oy
	if x < 0 or y < 0 or x >= w or y >= h:
		return NONE
	return img.get_pixel(x, y)


## Строка пикселей x0..x1 (включительно) на высоте y.
func hspan(x0: int, x1: int, y: int, c: Color, k: float = 0.0) -> void:
	y -= oy
	if y < _cy0 or y > _cy1:
		return
	x0 = maxi(x0 - ox, _cx0)
	x1 = mini(x1 - ox, _cx1)
	if x1 < x0:
		return
	if k <= 0.0:
		img.fill_rect(Rect2i(x0, y, x1 - x0 + 1, 1), c)
		return
	if k >= 1.0:
		return
	var sy := y + oy
	for x in range(x0, x1 + 1):
		if not gone(x + ox, sy, k):
			img.set_pixel(x, y, c)


func rect(x: int, y: int, rw: int, rh: int, c: Color, k: float = 0.0) -> void:
	for yy in range(y, y + rh):
		hspan(x, x + rw - 1, yy, c, k)


## Круг по центрам пикселей; маленький радиус всё равно даёт точку.
func disc(cx: float, cy: float, r: float, c: Color, k: float = 0.0) -> void:
	if r < 0.75:
		put_d(floori(cx), floori(cy), c, k)
		return
	var r2 := r * r
	for y in range(floori(cy - r), ceili(cy + r) + 1):
		var dy := float(y) + 0.5 - cy
		var s := r2 - dy * dy
		if s < 0.0:
			continue
		var half := sqrt(s)
		hspan(ceili(cx - half - 0.5), floori(cx + half - 0.5), y, c, k)


## Кольцо между радиусами r0 и r1.
func ring(cx: float, cy: float, r0: float, r1: float, c: Color, k: float = 0.0) -> void:
	var a := r0 * r0
	var b := r1 * r1
	for y in range(floori(cy - r1), ceili(cy + r1) + 1):
		var dy := float(y) + 0.5 - cy
		var so := b - dy * dy
		if so < 0.0:
			continue
		var ho := sqrt(so)
		var si := a - dy * dy
		if si <= 0.0:
			hspan(ceili(cx - ho - 0.5), floori(cx + ho - 0.5), y, c, k)
		else:
			var hi := sqrt(si)
			hspan(ceili(cx - ho - 0.5), floori(cx - hi - 0.5), y, c, k)
			hspan(ceili(cx + hi - 0.5), floori(cx + ho - 0.5), y, c, k)


## Эллипс (rx, ry), повёрнутый на угол ang.
func ellipse(cx: float, cy: float, rx: float, ry: float, ang: float, c: Color, k: float = 0.0) -> void:
	var pts := PackedVector2Array()
	var n := clampi(ceili(maxf(rx, ry) * 1.5), 12, 64)
	for i in n:
		var a := float(i) / float(n) * TAU
		pts.append(Vector2(cx, cy) + Vector2(cos(a) * rx, sin(a) * ry).rotated(ang))
	poly(pts, c, k)


## Линия в 1 пиксель (Брезенхэм).
func line(x0: int, y0: int, x1: int, y1: int, c: Color, k: float = 0.0) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		put_d(x0, y0, c, k)
		if x0 == x1 and y0 == y1:
			return
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


func line_v(a: Vector2, b: Vector2, c: Color, k: float = 0.0) -> void:
	line(floori(a.x), floori(a.y), floori(b.x), floori(b.y), c, k)


## Отрезок с толщиной: радиус r0 у a, r1 у b (круги на концах и трапеция между).
func capsule(a: Vector2, b: Vector2, r0: float, r1: float, c: Color, k: float = 0.0) -> void:
	disc(a.x, a.y, r0, c, k)
	disc(b.x, b.y, r1, c, k)
	var d := b - a
	if d.length_squared() < 0.01:
		return
	var n := d.normalized().orthogonal()
	poly(PackedVector2Array([a + n * r0, b + n * r1, b - n * r1, a - n * r0]), c, k)


## Многоугольник (по центрам пикселей, чёт-нечет).
func poly(pts: PackedVector2Array, c: Color, k: float = 0.0) -> void:
	var n := pts.size()
	if n < 3:
		return
	var y0 := INF
	var y1 := -INF
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var xs := PackedFloat32Array()
	for y in range(maxi(floori(y0), oy), mini(ceili(y1), oy + h - 1) + 1):
		var fy := float(y) + 0.5
		xs.clear()
		for i in n:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			if (a.y <= fy and b.y > fy) or (b.y <= fy and a.y > fy):
				xs.append(a.x + (fy - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for j in range(0, xs.size() - 1, 2):
			hspan(ceili(xs[j] - 0.5), floori(xs[j + 1] - 0.5), y, c, k)


## Спрайт (PixArt) в точке x, y; flip — зеркально; k — растворение; tint — если
## непрозрачный, все пиксели спрайта этим цветом (силуэт, вспышка).
func blit(s: Dictionary, x: int, y: int, flip: bool = false, k: float = 0.0, tint: Color = NONE) -> void:
	var sw: int = s["w"]
	var sh: int = s["h"]
	var px: PackedColorArray = s["px"]
	for j in sh:
		for i in sw:
			var c := px[j * sw + i]
			if c.a == 0.0:
				continue
			put_d(x + (sw - 1 - i if flip else i), y + j, tint if tint.a > 0.0 else c, k)


func texture() -> ImageTexture:
	if _tex == null:
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)
	return _tex
