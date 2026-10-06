extends RefCounted

## Альтернативные арты карт (коллекция): исходники в "alt arts/" в корне проекта.
## Рисует их tools/pixel_cards.gd -- alt тем же пикселизатором, что и обычные
## карты. Фон (белый или прозрачный) не закрашивается: кадр приближается так, чтобы он не попал.

const SRC := "C:/tyrants of the underdark godot/alt arts/"

## [card_id, файл, редкость, вырез, вырез мини (Vector2i(-1, -1) = авто)].
## Вырез -- Vector3(центр x, верх, высота) в долях исходника, ширина по
## пропорциям окна арта. AUTO -- самый
## большой вырез: у широкой картинки по центру, у высокой ближе к верху.
## Вырез мини -- левый верхний угол куска 52x53 в арте большой карты 164x100.
const AUTO := Vector3.ZERO
const NO_FACE := Vector2i(-1, -1)
## Белые сами по себе (драконы, призраки): белое у них -- фигура, не фон.
const KEEP_WHITE := ["intellec devourer.png", "white dragon 1.png", "white dragon.png", "white wirmling.png", "ghost.png", "banshee.png"]
const ALT := [
	[48705, "aboleth.jpeg", "LEGENDARY", AUTO, NO_FACE],
	[48604, "air elemental.jpeg", "EPIC", Vector3(0.5,0.12,0.55), NO_FACE],
	[48500, "balor.png", "LEGENDARY", AUTO, NO_FACE],
	[48719, "banshee.png", "EPIC", Vector3(0.55,0.08,0.45), NO_FACE],
	[48715, "beholder 1.jpeg", "EPIC", AUTO, NO_FACE],
	[48715, "beholder.png", "EPIC", AUTO, NO_FACE],
	[48400, "black dragon.jpeg", "LEGENDARY", Vector3(0.5,0.3,0.47), NO_FACE],
	[48310, "black guard.jpeg", "EPIC", AUTO, NO_FACE],
	[48402, "black wirmling.jpeg", "EPIC", AUTO, NO_FACE],
	[48403, "blue dragon 1.jpeg", "LEGENDARY", Vector3(0.5,0.02,0.47), NO_FACE],
	[48403, "blue dragon.png", "LEGENDARY", AUTO, NO_FACE],
	[48405, "blue wirmling.jpeg", "EPIC", Vector3(0.5,0.02,0.49), NO_FACE],
	[48737, "carion crawler.png", "EPIC", AUTO, NO_FACE],
	[48706, "chuul.png", "EPIC", AUTO, NO_FACE],
	[48709, "cloaker.png", "EPIC", Vector3(0.5,0.08,0.6), NO_FACE],
	[48722, "conjerer 1.jpeg", "EPIC", Vector3(0.45,0.05,0.55), NO_FACE],
	[48714, "cranium rat.jpeg", "EPIC", Vector3(0.5,0.25,0.55), NO_FACE],
	[48714, "cranium rat.png", "EPIC", Vector3(0.5,0.6,0.4), NO_FACE],
	[48721, "death knight.jpeg", "LEGENDARY", AUTO, NO_FACE],
	[48713, "death tyrant.png", "LEGENDARY", AUTO, NO_FACE],
	[48318, "doppelganger.png", "EPIC", Vector3(0.5,0.12,0.5), NO_FACE],
	[48615, "earth elemental.png", "EPIC", Vector3(0.5,0.12,0.5), NO_FACE],
	[48700, "elder brain 1.jpeg", "LEGENDARY", Vector3(0.5,0.05,0.5), NO_FACE],
	[48700, "elder brain.jpeg", "LEGENDARY", Vector3(0.5,0.07,0.35), NO_FACE],
	[48506, "ettin.png", "EPIC", Vector3(0.45,0.02,0.5), NO_FACE],
	[48623, "fire elemental.png", "EPIC", Vector3(0.5,0.15,0.5), NO_FACE],
	[48736, "flesh golem.png", "EPIC", Vector3(0.4,0.03,0.45), NO_FACE],
	[48723, "ghost.png", "EPIC", Vector3(0.5,0.05,0.55), NO_FACE],
	[48509, "ghoul 1.png", "EPIC", AUTO, NO_FACE],
	[48509, "ghoul 2.png", "EPIC", Vector3(0.45,0,0.5), NO_FACE],
	[48509, "ghoul.png", "EPIC", Vector3(0.5,0.1,0.5), NO_FACE],
	[48512, "gibberin mouther.png", "EPIC", AUTO, NO_FACE],
	[48513, "glabrezu.png", "EPIC", AUTO, NO_FACE],
	[48419, "green dragon.jpeg", "LEGENDARY", Vector3(0.5,0.25,0.47), NO_FACE],
	[48712, "grimlock.png", "EPIC", AUTO, NO_FACE],
	[48516, "hezrou.png", "EPIC", Vector3(0.5,0.05,0.5), NO_FACE],
	[48325, "inquisitor.jpeg", "EPIC", Vector3(0.55,0,0.45), NO_FACE],
	[48703, "intellec devourer.png", "EPIC", Vector3(0.5,0,0.5), NO_FACE],
	[48519, "jakalwew.png", "EPIC", Vector3(0.5,0,0.45), NO_FACE],
	[48424, "kobold.jpeg", "EPIC", AUTO, NO_FACE],
	[48521, "marilith.png", "LEGENDARY", Vector3(0.45,0,0.5), NO_FACE],
	[48527, "miconyd adult.jpeg", "EPIC", Vector3(0.5,0.25,0.45), NO_FACE],
	[48524, "mind flare.png", "EPIC", Vector3(0.5,0.15,0.5), NO_FACE],
	[48735, "minotaue skeleton.jpeg", "EPIC", Vector3(0.45,0.05,0.55), NO_FACE],
	[48529, "myconid soverigne.jpeg", "EPIC", Vector3(0.5,0.02,0.45), NO_FACE],
	[48531, "nalfeshnee.png", "EPIC", Vector3(0.5,0,0.55), NO_FACE],
	[48534, "night hug.png", "EPIC", Vector3(0.45,0.05,0.4), NO_FACE],
	[48708, "nothic.png", "EPIC", Vector3(0.55,0.28,0.4), NO_FACE],
	[48731, "ogre zombie.jpeg", "EPIC", Vector3(0.45,0.05,0.5), NO_FACE],
	[48632, "olhydra.png", "LEGENDARY", Vector3(0.5,0.15,0.6), NO_FACE],
	[48702, "puppet.jpeg", "EPIC", Vector3(0.5,0,0.4), NO_FACE],
	[48711, "quaggoth.png", "EPIC", AUTO, NO_FACE],
	[48426, "red dragon 2.jpeg", "LEGENDARY", Vector3(0.55,0.05,0.47), NO_FACE],
	[48426, "red dragon.png", "LEGENDARY", AUTO, NO_FACE],
	[48428, "red wirmling.jpeg", "EPIC", Vector3(0.6,0.1,0.5), NO_FACE],
	[48729, "skeletal horde.jpeg", "EPIC", AUTO, NO_FACE],
	[48718, "spectator.png", "EPIC", Vector3(0.45,0.05,0.55), NO_FACE],
	[48537, "succubus.png", "EPIC", Vector3(0.5,0.1,0.5), NO_FACE],
	[48701, "ulithrid.jpeg", "LEGENDARY", Vector3(0.45,0,0.5), NO_FACE],
	[48739, "umber hulk.png", "EPIC", Vector3(0.5,0.25,0.6), NO_FACE],
	[48720, "vampire spawn.jpeg", "EPIC", Vector3(0.5,0.1,0.5), NO_FACE],
	[48728, "vampire.png", "LEGENDARY", AUTO, NO_FACE],
	[48538, "vrock.png", "EPIC", Vector3(0.5,0.3,0.45), NO_FACE],
	[48636, "water elemental.png", "EPIC", Vector3(0.55,0.1,0.55), NO_FACE],
	[48433, "white dragon.png", "LEGENDARY", AUTO, NO_FACE],
	[48436, "white wirmling.png", "EPIC", AUTO, NO_FACE],
	[48724, "wight.png", "EPIC", Vector3(0.45,0.05,0.55), NO_FACE],
	[48730, "wraith.jpeg", "EPIC", Vector3(0.4,0,0.5), NO_FACE],
	[48726, "zombie.jpeg", "EPIC", Vector3(0.5,0.1,0.5), NO_FACE],
]


## Арты, которые автоподбор зума отбросил (на листе превью их показывает
## режим "-- alt rejected" без нижнего предела зума).
const REJECTED := [
	[48705, "aboleth 1.png", "LEGENDARY", AUTO, NO_FACE],
	[48501, "demogorgon.jpeg", "LEGENDARY", AUTO, NO_FACE],
	[48501, "demogorgon.png", "LEGENDARY", AUTO, NO_FACE],
	[48503, "derro.png", "EPIC", AUTO, NO_FACE],
	[48421, "green wirmling.png", "EPIC", AUTO, NO_FACE],
	[48535, "orcus.png", "LEGENDARY", AUTO, NO_FACE],
	[48426, "red dragon 1.jpeg", "LEGENDARY", AUTO, NO_FACE],
	[48433, "white dragon 1.png", "LEGENDARY", AUTO, NO_FACE],
	[48639, "yan-c-bin.png", "LEGENDARY", AUTO, NO_FACE],
	[48539, "zuggtmoy.png", "LEGENDARY", AUTO, NO_FACE],
	[48419, "green dragon.png", "LEGENDARY", AUTO, NO_FACE],
	[48701, "ulithrid.jpeg", "LEGENDARY", AUTO, NO_FACE],
	[48524, "mind flare.png", "EPIC", AUTO, NO_FACE],
	[48702, "puppet.jpeg", "EPIC", AUTO, NO_FACE],
]


## Вырезы по лицам (Vector3(центр x, верх, высота) в долях картинки): у этих
## артов автоподбор зума резал лицо. Если и в таком вырезе остаётся больше
## FACE_BG_MAX фона, арт отбрасывается.
const FACE_BG_MAX := 0.03
## Кадр, который владелец выбрал сам: фон в нём не проверяется, зум не нужен.
const FACE_BG_ALLOW := {"intellec devourer.png": 1.0}
## Нижние пределы зума; режим "rejected" в pixel_cards.gd опускает их, чтобы
## показать, что выйдет из ранее отбракованных артов.
static var face_zoom_min := 0.55
const FACE_CROP := {
	"vrock.png": Vector3(0.5, 0.30, 0.30),
	"umber hulk.png": Vector3(0.55, 0.15, 0.45),
	"ulithrid.jpeg": Vector3(0.53, 0.02, 0.36),
	"spectator.png": Vector3(0.47, 0.12, 0.5),
	"quaggoth.png": Vector3(0.45, 0.36, 0.28),
	"puppet.jpeg": Vector3(0.5, 0.17, 0.24),
	"nothic.png": Vector3(0.5, 0.36, 0.26),
	"night hug.png": Vector3(0.5, 0.10, 0.28),
	"myconid soverigne.jpeg": Vector3(0.53, 0.08, 0.34),
	"mind flare.png": Vector3(0.5, 0.25, 0.4),
	"marilith.png": Vector3(0.55, 0.15, 0.3),
	"kobold.jpeg": Vector3(0.62, 0.22, 0.3),
	"intellec devourer.png": Vector3(0.5, 0.22, 0.45),
	"fire elemental.png": Vector3(0.5, 0.22, 0.45),
	"elder brain 1.jpeg": Vector3(0.5, 0.10, 0.45),
	"elder brain.jpeg": Vector3(0.5, 0.28, 0.24),
}

## Кусок исходника с пропорциями окна арта aw x ah, в размере (aw, ah) * scale --
## дальше его ужимает и квантует pixelize(). Зум такой, чтобы в кадр не попал
## фон (белый или прозрачный): берётся самый большой кадр почти без фона. Если
## для этого пришлось бы приблизить слишком сильно (меньше MIN_ZOOM_KEEP от
## самого большого возможного кадра), арт отбрасывается -- возвращается null.
## Остатки прозрачного в кадре остаются чёрными: ничего не закрашиваем.
static var min_zoom_keep := 0.45
const EDGE_BG_MAX := 0.015
const SEARCH_SIZE := 240


static func source(entry: Array, aw: int, ah: int, scale: int) -> Image:
	var im := Image.load_from_file(SRC + String(entry[1]))
	im.convert(Image.FORMAT_RGBA8)
	var mode := background_mode(im)
	if KEEP_WHITE.has(entry[1]):
		mode = BG_NONE
	var min_spot := 150 * scale * scale
	if not FACE_CROP.has(entry[1]):
		var r := best_crop(im, mode, entry[3], aw, ah)
		if r.size == Vector2i.ZERO:
			return null
		var part := im.get_region(r)
		part.resize(aw * scale, ah * scale, Image.INTERPOLATE_LANCZOS)
		flatten(part)
		return part

	# Вырез по лицу; пока в нём больше FACE_BG_MAX фона, приближаем к его центру.
	var v: Vector3 = FACE_CROP[entry[1]]
	var h0 := v.z * im.get_height()
	var centre := Vector2(v.x * im.get_width(), v.y * im.get_height() + h0 * 0.5)
	var z := 1.0
	while z >= face_zoom_min:
		var ch := int(h0 * z)
		var cw := int(ch * aw / float(ah))
		var r := Rect2i(int(centre.x) - cw / 2, int(centre.y) - ch / 2, cw, ch)
		r.position.x = clampi(r.position.x, 0, maxi(im.get_width() - cw, 0))
		r.position.y = clampi(r.position.y, 0, maxi(im.get_height() - ch, 0))
		var part := im.get_region(r)
		part.resize(aw * scale, ah * scale, Image.INTERPOLATE_LANCZOS)
		var n := 0
		for b in background_mask(part, mode, min_spot):
			n += 1 if b == 1 else 0
		if n <= FACE_BG_ALLOW.get(entry[1], FACE_BG_MAX) * part.get_width() * part.get_height():
			flatten(part)
			return part
		z -= 0.08
	return null


## Самый большой кадр aw:ah, где фона не больше EDGE_BG_MAX; из таких -- ближайший
## к выбранному вручную центру (v: x центра, y верха и высота в долях картинки).
## Если ручного выреза нет (AUTO), центр -- середина картинки. Пустой Rect2i --
## кадра нет.
static func best_crop(im: Image, mode: int, v: Vector3, aw: int, ah: int) -> Rect2i:
	var W := im.get_width()
	var H := im.get_height()
	var k := minf(1.0, SEARCH_SIZE / float(maxi(W, H)))
	var sm := im.duplicate() as Image
	sm.resize(maxi(int(W * k), 1), maxi(int(H * k), 1), Image.INTERPOLATE_BILINEAR)
	var w := sm.get_width()
	var h := sm.get_height()
	var bg := background_mask(sm, mode, int(150 * k * k))
	# интегральная картинка фона
	var sat := PackedInt32Array()
	sat.resize((w + 1) * (h + 1))
	for y in h:
		var row := 0
		for x in w:
			row += 1 if bg[y * w + x] == 1 else 0
			sat[(y + 1) * (w + 1) + x + 1] = sat[y * (w + 1) + x + 1] + row

	var hmax := mini(h, int(w * ah / float(aw)))
	var want_h := hmax
	if v != AUTO:
		want_h = mini(hmax, int(v.z * h))
	var centre := Vector2((v.x if v != AUTO else 0.5) * w, (v.y * h + want_h * 0.5) if v != AUTO else h * 0.5)
	var best := Rect2i()
	var h_try := hmax
	while h_try >= int(hmax * min_zoom_keep):
		var w_try := int(h_try * aw / float(ah))
		var limit := int(w_try * h_try * EDGE_BG_MAX)
		var bd := 1e18
		for y in range(0, h - h_try + 1, 2):
			for x in range(0, w - w_try + 1, 2):
				var n := sat[(y + h_try) * (w + 1) + x + w_try] - sat[y * (w + 1) + x + w_try] \
					- sat[(y + h_try) * (w + 1) + x] + sat[y * (w + 1) + x]
				if n > limit:
					continue
				var d := Vector2(x + w_try * 0.5, y + h_try * 0.5).distance_squared_to(centre)
				if d < bd:
					bd = d
					best = Rect2i(x, y, w_try, h_try)
		if best.size != Vector2i.ZERO:
			# не ближе, чем просил ручной вырез: зум нужен только против фона
			if h_try > want_h:
				var again := Rect2i()
				var ad := 1e18
				var w2 := int(want_h * aw / float(ah))
				var lim2 := int(w2 * want_h * EDGE_BG_MAX)
				for y in range(0, h - want_h + 1, 2):
					for x in range(0, w - w2 + 1, 2):
						var n := sat[(y + want_h) * (w + 1) + x + w2] - sat[y * (w + 1) + x + w2] \
							- sat[(y + want_h) * (w + 1) + x] + sat[y * (w + 1) + x]
						if n > lim2:
							continue
						var d := Vector2(x + w2 * 0.5, y + want_h * 0.5).distance_squared_to(centre)
						if d < ad:
							ad = d
							again = Rect2i(x, y, w2, want_h)
				if again.size != Vector2i.ZERO:
					best = again
			break
		h_try -= maxi(1, int(hmax * 0.02))
	if best.size == Vector2i.ZERO:
		return best
	return Rect2i(Vector2i(Vector2(best.position) / k), Vector2i(Vector2(best.size) / k)).intersection(Rect2i(0, 0, W, H))


## Что считать фоном: только прозрачное (BG_NONE); ещё и почти белое -- у
## картинок на белом листе, где белая хотя бы четверть края (BG_WHITE); у
## картинок с прозрачностью ещё и светлые бледные разводы вокруг фигуры
## (BG_SPLASH). Снег и небо сцен не трогаем.
const BG_NONE := 0
const BG_WHITE := 1
const BG_SPLASH := 2


static func background_mode(im: Image) -> int:
	if im.detect_alpha() != Image.ALPHA_NONE:
		return BG_SPLASH
	var white := 0
	var total := 0
	for x in range(0, im.get_width(), 4):
		for y: int in [0, im.get_height() - 1]:
			total += 1
			if is_bg(im.get_pixel(x, y), BG_WHITE):
				white += 1
	return BG_WHITE if white >= total / 4 else BG_NONE


## Фон -- то, что связано с краем картинки через фоновые пиксели (светлые места
## внутри фигуры не трогаем). На белом листе фон ещё и замкнутые белые пятна
## от min_spot пикселей (между щупальцами, змеями). 1 -- фон.
static func background_mask(im: Image, mode: int, min_spot: int) -> PackedByteArray:
	var w := im.get_width()
	var h := im.get_height()
	var bg := PackedByteArray()
	bg.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	flood(im, bg, stack, mode, 1)
	for i in w * h:
		var c := im.get_pixel(i % w, i / w)
		if bg[i] != 0:
			continue
		if c.a < 0.05:
			# дырки насквозь прозрачные -- тоже фон
			bg[i] = 1
		elif mode == BG_WHITE and c.v > 0.97 and c.s < 0.03:
			# замкнутое белое пятно; мелкое (блик) остаётся фигурой -- метка 2
			var spot := flood(im, bg, [i], BG_WHITE, 1)
			if spot.size() < min_spot:
				for j in spot:
					bg[j] = 2
	return bg


## Ничего не закрашиваем: прозрачные пиксели остаются тем, что они есть -- чёрным.
static func flatten(im: Image) -> void:
	var base := Image.create(im.get_width(), im.get_height(), false, Image.FORMAT_RGBA8)
	base.fill(Color.BLACK)
	base.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i.ZERO)
	im.copy_from(base)


## Заливка по фоновым пикселям из стартовых точек: помечает их mark и
## возвращает их номера.
static func flood(im: Image, bg: PackedByteArray, stack: Array, mode: int, mark: int) -> Array[int]:
	var w := im.get_width()
	var h := im.get_height()
	var got: Array[int] = []
	while not stack.is_empty():
		var i: int = stack.pop_back()
		if bg[i] != 0 or not is_bg(im.get_pixel(i % w, i / w), mode):
			continue
		bg[i] = mark
		got.append(i)
		var x := i % w
		var y := i / w
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)
	return got


static func is_bg(c: Color, mode: int) -> bool:
	if c.a < 0.6:
		return true
	match mode:
		BG_WHITE:
			return c.v > 0.8 and c.s < 0.16
		BG_SPLASH:
			return c.v > 0.72 and c.s < 0.3
	return false
