class_name CardBack
extends RefCounted

## Рубашка карты в полный размер (CardView.PIXEL_SIZE, 1:1). Рубашки — готовые
## рисунки (решение владельца, 2026-09-30: рисовалки больше нет): CLASSIC есть
## у всех, остальные — по одной на фракцию, ступени ULTRA — выпадают из
## лутбокса или создаются за пыль (SkinCollection). Соперники видят рубашку,
## когда игрок берёт карту вслепую (CardShowcase).
##
## Всё рисуется кодом по пикселям, без сглаживания; общая рамка — тёмный край,
## кайма цвета рубашки и тонкая внутренняя линия.

const CLASSIC := "classic"
## Порядок показа в коллекции: CLASSIC, затем фракции в порядке полуколод.
const DESIGNS: Array[String] = ["classic", "web", "scales", "pits", "elements", "eye", "skull"]
const NAMES := {"classic": "CLASSIC", "web": "LOLTH'S WEB", "scales": "DRAGON SCALES",
	"pits": "DEMONWEB PITS", "elements": "ELEMENTAL PLANES", "eye": "BEHOLDER", "skull": "DEATH'S HEAD"}
const FACTIONS := {"classic": "", "web": "DROW", "scales": "DRAGONS", "pits": "DEMONS",
	"elements": "ELEMENTALS", "eye": "ABERRATIONS", "skull": "UNDEAD"}
## Поле, кайма и внутренняя линия каждой рубашки.
const LOOK := {
	"classic": ["2b1d40", "f2d23c", "6b4a9a"],
	"web": ["1c1230", "cbdbfc", "5b4a8a"],
	"scales": ["2a0e08", "f2b23c", "8a3a14"],
	"pits": ["0c0606", "df7126", "6a1a10"],
	"elements": ["0e2430", "5fcde4", "2a6a7a"],
	"eye": ["0e1a0c", "99e550", "3a6a22"],
	"skull": ["0e1428", "9badb7", "3f4a74"],
}
const BG := Color("1a1226")
const DIAMOND_A := Color("3d2a5c")
const DIAMOND_B := Color("24183a")
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

## Череп нежити: # — кость, o — глазница, O — огонёк в глазнице, n — нос, t — зубы.
const SKULL := [
	"....#######....",
	"..###########..",
	".#############.",
	"###############",
	"###############",
	"##ooo#####ooo##",
	"#ooOoo###ooOoo#",
	"#oOOOo###oOOOo#",
	"##ooo#nnn#ooo##",
	".#####nnn#####.",
	"..#####n#####..",
	"...#########...",
	"...#t#t#t#t#...",
	"...#########...",
	".....#####.....",
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
	var look: Array = LOOK[d]
	var size := Vector2i(CardView.PIXEL_SIZE)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var r := Rect2i(Vector2i.ZERO, size)
	img.fill(BG)
	img.fill_rect(r.grow(-2), Color(look[0]))
	var c := size / 2
	var field := r.grow(-7)
	match d:
		"web":
			_web(img, c, field)
		"scales":
			_scales(img, c, field)
		"pits":
			_pits(img, c, field)
		"elements":
			_elements(img, c, field)
		"eye":
			_eye(img, c, field)
		"skull":
			_skull(img, c, field)
		_:
			_diamonds(img, c)
	_outline(img, r.grow(-2), Color(look[1]))
	_outline(img, r.grow(-6), Color(look[2]))
	return img


# --- рисунки -----------------------------------------------------------------

## CLASSIC — вложенные ромбы и золотая точка.
static func _diamonds(img: Image, c: Vector2i) -> void:
	for i in range(6):
		var d := 34 - i * 6
		var dx := roundi(d * 0.7)
		var colour := DIAMOND_A if i % 2 == 0 else DIAMOND_B
		for y in range(-d, d + 1):
			var half := int(dx * (1.0 - absf(y) / d))
			img.fill_rect(Rect2i(c.x - half, c.y + y, half * 2 + 1, 1), colour)
	img.fill_rect(Rect2i(c - Vector2i(3, 3), Vector2i(6, 6)), PixelTheme.GOLD)


## LOLTH'S WEB (дроу): паутина во всё поле и паук в центре.
static func _web(img: Image, c: Vector2i, field: Rect2i) -> void:
	var spokes := 16
	var silk := Color("7f74b0")
	var bright := Color("cbdbfc")
	for i in spokes:
		var a := TAU * i / spokes
		_line(img, c, c + Vector2i(roundi(cos(a) * 200), roundi(sin(a) * 200)), silk, field)
	for k in range(1, 14):
		var radius := 9.0 + 11.0 * k + k * k * 0.35
		var colour := bright if k <= 3 else silk
		for i in spokes:
			var a0 := TAU * i / spokes
			var a1 := TAU * (i + 1) / spokes
			var prev := Vector2i(-9999, -9999)
			for s in 13:
				var t := s / 12.0
				var a := lerpf(a0, a1, t)
				# Нить между спицами провисает к центру.
				var rr := radius * (1.0 - 0.1 * 4.0 * t * (1.0 - t))
				var p := c + Vector2i(roundi(cos(a) * rr), roundi(sin(a) * rr))
				if prev.x > -9999:
					_line(img, prev, p, colour, field)
				prev = p
	# Паук: брюшко, голова, восемь ног, красная метка.
	var body := Color("140c1e")
	var rim := Color("6a5ad0")
	for leg in 4:
		for side in [-1, 1]:
			var knee := c + Vector2i(side * (10 + leg * 2), -8 + leg * 5)
			var foot := knee + Vector2i(side * 6, 6 + leg)
			_line(img, c + Vector2i(0, -2 + leg * 2), knee, body, field)
			_line(img, knee, foot, body, field)
	_disc(img, c + Vector2i(0, 7), 8, body, rim)
	_disc(img, c + Vector2i(0, -5), 5, body, rim)
	img.fill_rect(Rect2i(c + Vector2i(-1, 4), Vector2i(3, 2)), Color("d0283e"))
	img.fill_rect(Rect2i(c + Vector2i(0, 6), Vector2i(1, 3)), Color("d0283e"))
	img.set_pixelv(c + Vector2i(-2, -6), PixelTheme.GOLD)
	img.set_pixelv(c + Vector2i(2, -6), PixelTheme.GOLD)


## DRAGON SCALES (драконы): чешуя рядами и драконий глаз в медальоне.
static func _scales(img: Image, c: Vector2i, field: Rect2i) -> void:
	var ramp := [Color("d9892a"), Color("a8521a"), Color("6e2a10"), Color("3e1408")]
	var edge := Color("1e0804")
	var w := 16
	var h := 10
	var rad := 10.5
	for y in range(field.position.y, field.end.y):
		for x in range(field.position.x, field.end.x):
			var row := floori(float(y) / h)
			var hit := false
			for i in [row - 1, row, row + 1]:
				if hit:
					break
				var off: int = (i % 2) * (w / 2)
				var col := floori(float(x - off + w / 2) / w)
				for j in [col - 1, col, col + 1]:
					var cx := float(j * w + off)
					var cy := float(i * h)
					var dist := Vector2(x - cx, y - cy).length()
					if dist <= rad:
						var k := clampf(dist / rad * 0.8 + (cy - y) / rad * 0.35, 0.0, 1.0)
						var shade: Color = ramp[mini(3, int(k * 3.0 + _bay(x, y)))]
						img.set_pixel(x, y, edge if dist > rad - 1.2 else shade)
						hit = true
						break
	# Медальон с глазом: золотой обод, огненная радужка, вертикальный зрачок.
	_disc(img, c, 30, Color("1e0804"), Color("f2d23c"))
	_ring(img, c, 27, Color("8a3a14"))
	for y in range(-20, 21):
		for x in range(-26, 27):
			var e := (x * x) / 676.0 + (y * y) / 400.0
			if e <= 1.0:
				var iris: Color = Color("fbf236").lerp(Color("df7126"), clampf(e * 1.4 + _bay(x, y) * 0.3, 0.0, 1.0))
				img.set_pixelv(c + Vector2i(x, y), iris)
	for y in range(-18, 19):
		var half := int(4.0 * (1.0 - absf(y) / 19.0) + 0.5)
		img.fill_rect(Rect2i(c.x - half, c.y + y, half * 2 + 1, 1), Color("0c0402"))
	img.fill_rect(Rect2i(c + Vector2i(-12, -10), Vector2i(3, 3)), Color("fff6d0"))


## DEMONWEB PITS (демоны): чёрный камень в лавовых трещинах, огненное кольцо.
static func _pits(img: Image, c: Vector2i, field: Rect2i) -> void:
	var cell := 22
	for y in range(field.position.y, field.end.y):
		for x in range(field.position.x, field.end.x):
			var gx := floori(float(x) / cell)
			var gy := floori(float(y) / cell)
			var d1 := 1e9
			var d2 := 1e9
			for oy in [-1, 0, 1]:
				for ox in [-1, 0, 1]:
					var px: float = (gx + ox + _hash(gx + ox, gy + oy)) * cell
					var py: float = (gy + oy + _hash(gy + oy + 7, gx + ox + 3)) * cell
					var dd := Vector2(x - px, y - py).length()
					if dd < d1:
						d2 = d1
						d1 = dd
					elif dd < d2:
						d2 = dd
			var gap := d2 - d1
			var colour := Color("140a08") if (x + y) % 7 == 0 and _hash(x, y) > 0.6 else Color("0c0606")
			if gap < 1.2:
				colour = Color("fbf236") if gap < 0.5 else Color("df7126")
			elif gap < 3.0 and _bay(x, y) < 0.9 - (gap - 1.2) * 0.4:
				colour = Color("8a1a10") if gap < 2.2 else Color("4a0c08")
			img.set_pixel(x, y, colour)
	# Огненное кольцо и три следа когтей.
	_disc(img, c, 32, Color("0c0606"), Color("4a0c08"))
	for rr in [30, 29, 28]:
		_ring(img, c, rr, Color("df7126") if rr == 29 else Color("8a1a10"))
	for y in range(-26, 27):
		for x in range(-26, 27):
			var dd := Vector2(x, y).length()
			if dd < 26 and _bay(x, y) < 0.25 * (1.0 - dd / 26.0) + 0.05:
				img.set_pixelv(c + Vector2i(x, y), Color("4a0c08"))
	for k in [-1, 0, 1]:
		var a := c + Vector2i(-16 + k * 10, -18)
		var b := c + Vector2i(4 + k * 10, 18)
		_line(img, a, b, Color("fbf236"), field)
		_line(img, a + Vector2i(1, 0), b + Vector2i(1, 0), Color("df7126"), field)


## ELEMENTAL PLANES (элементали): круг из четырёх стихий на волнах силы.
static func _elements(img: Image, c: Vector2i, field: Rect2i) -> void:
	for y in range(field.position.y, field.end.y):
		for x in range(field.position.x, field.end.x):
			var dd := Vector2(x - c.x, (y - c.y) * 0.8).length()
			if int(dd) % 10 == 0:
				img.set_pixel(x, y, Color("1c4450"))
			elif int(dd) % 10 == 5 and _bay(x, y) < 0.5:
				img.set_pixel(x, y, Color("163440"))
	var quads := [Color("df7126"), Color("306082"), Color("6abe30"), Color("cbdbfc")]
	var dark := [Color("8a3a14"), Color("1c3a5a"), Color("37642a"), Color("7f8aa8")]
	for y in range(-40, 41):
		for x in range(-40, 41):
			var dd := Vector2(x, y).length()
			if dd > 40:
				continue
			# Четверти: огонь сверху, вода справа, земля снизу, воздух слева.
			var q := 0 if (y < 0 and absi(x) <= -y) else (1 if (x > 0 and absi(y) < x) else (2 if y > 0 and absi(x) <= y else 3))
			var colour: Color = quads[q] if dd < 38 - _bay(x, y) * 6.0 else dark[q]
			if absi(absi(x) - absi(y)) <= 0 or dd >= 39:
				colour = Color("0e2430")
			img.set_pixelv(c + Vector2i(x, y), colour)
	_ring(img, c, 41, Color("5fcde4"))
	# Знаки стихий: пламя, волна, камень, вихрь.
	var ink := Color("0e2430")
	for i in 9:
		img.fill_rect(Rect2i(c.x - (9 - i) / 2, c.y - 16 - i, 9 - (i / 2) * 2 + (i % 2), 1), ink)
	for x in range(-8, 9):
		img.set_pixelv(c + Vector2i(22 + x / 2, roundi(sin(x * 0.8) * 3)), ink)
		img.set_pixelv(c + Vector2i(22 + x / 2, 5 + roundi(sin(x * 0.8) * 3)), ink)
	img.fill_rect(Rect2i(c + Vector2i(-6, 17), Vector2i(12, 7)), ink)
	img.fill_rect(Rect2i(c + Vector2i(-3, 14), Vector2i(7, 3)), ink)
	for s in 26:
		var a := s * 0.45
		var rr := 1.5 + s * 0.3
		img.set_pixelv(c + Vector2i(-24 + roundi(cos(a) * rr), roundi(sin(a) * rr)), ink)


## BEHOLDER (аберрации): большой глаз, вокруг — глаза на стебельках.
static func _eye(img: Image, c: Vector2i, field: Rect2i) -> void:
	for y in range(field.position.y, field.end.y):
		for x in range(field.position.x, field.end.x):
			if _hash(x / 3, y / 3) > 0.93 and _bay(x, y) < 0.6:
				img.set_pixel(x, y, Color("1e3614"))
	var stalks := 10
	for i in stalks:
		var a := TAU * i / stalks - PI / 2.0
		var tip := c + Vector2i(roundi(cos(a) * 62), roundi(sin(a) * 70))
		var mid := c + Vector2i(roundi(cos(a + 0.25) * 42), roundi(sin(a + 0.25) * 48))
		for w in [0, 1]:
			_line(img, c + Vector2i(w, 0), mid + Vector2i(w, 0), Color("3a6a22"), field)
			_line(img, mid + Vector2i(w, 0), tip + Vector2i(w, 0), Color("3a6a22"), field)
		_disc(img, tip, 5, Color("eec39a"), Color("1e3614"))
		_disc(img, tip, 2, Color("99e550"), Color("99e550"))
		img.set_pixelv(tip, Color("0e1a0c"))
	# Главный глаз: веко, белок, зелёная радужка, щель-зрачок, блик.
	for y in range(-26, 27):
		for x in range(-40, 41):
			var e := (x * x) / 1600.0 + (y * y) / 676.0
			if e <= 1.0:
				img.set_pixelv(c + Vector2i(x, y), Color("3a6a22") if e > 0.82 else Color("eec39a"))
	for y in range(-18, 19):
		for x in range(-18, 19):
			var dd := Vector2(x, y).length()
			if dd <= 18:
				var k := clampf(dd / 18.0 + _bay(x, y) * 0.25, 0.0, 1.0)
				img.set_pixelv(c + Vector2i(x, y), Color("99e550").lerp(Color("37642a"), k))
	for y in range(-16, 17):
		var half := int(3.0 * (1.0 - absf(y) / 17.0) + 0.5)
		img.fill_rect(Rect2i(c.x - half, c.y + y, half * 2 + 1, 1), Color("0e1a0c"))
	img.fill_rect(Rect2i(c + Vector2i(-10, -9), Vector2i(3, 3)), Color("ffffff"))


## DEATH'S HEAD (нежить): череп на скрещённых костях, в глазницах огоньки.
static func _skull(img: Image, c: Vector2i, field: Rect2i) -> void:
	for y in range(field.position.y, field.end.y):
		var fog := absf(sin(y * 0.09)) * 0.5
		for x in range(field.position.x, field.end.x):
			if _bay(x, y) < fog * 0.35:
				img.set_pixel(x, y, Color("18203c"))
	var bone := Color("cbdbfc")
	var bone_dark := Color("7f8aa8")
	for side in [-1, 1]:
		var a := c + Vector2i(-side * 44, -40)
		var b := c + Vector2i(side * 44, 46)
		for w in range(-3, 4):
			_line(img, a + Vector2i(w, 0), b + Vector2i(w, 0), bone_dark if absi(w) == 3 else bone, field)
		for end in [a, b]:
			_disc(img, end + Vector2i(-3, 0), 4, bone, bone_dark)
			_disc(img, end + Vector2i(3, 0), 4, bone, bone_dark)
	var zoom := 4
	var n := SKULL.size()
	var origin := c - Vector2i(15 * zoom / 2, n * zoom / 2 + 4)
	for row in n:
		var line: String = SKULL[row]
		for col in line.length():
			var ch := line[col]
			if ch == ".":
				continue
			var colour := bone
			match ch:
				"o", "n", "t":
					colour = Color("0e1428")
				"O":
					colour = Color("5fcde4")
				_:
					var below := row + 1 < n and String(SKULL[row + 1])[col] == "."
					var right := col + 1 < line.length() and line[col + 1] == "."
					if below or right or col >= 11:
						colour = Color("9badb7")
			img.fill_rect(Rect2i(origin + Vector2i(col, row) * zoom, Vector2i.ONE * zoom), colour)
	for eye in [Vector2i(3, 7), Vector2i(11, 7)]:
		img.fill_rect(Rect2i(origin + eye * zoom + Vector2i(1, 1), Vector2i(2, 2)), Color("ffffff"))


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
