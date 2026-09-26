class_name CardBack
extends RefCounted

## Рубашка карты в полный размер (CardView.PIXEL_SIZE, 1:1): тёмная рамка с
## золотой каймой, в центре — рисунок игрока (PlayerProfile, BACK_SIZE x
## BACK_SIZE, каждый пиксель рисунка — квадрат ZOOM x ZOOM) или, если рисунка
## нет, обычный ромб. Картинка одна для игры (CardShowcase) и для редактора
## (CardBackScreen), чтобы игрок видел ровно то, что увидят соперники.

const ZOOM := 4
const BG := Color("1a1226")
const FIELD := Color("2b1d40")
const INNER_LINE := Color("6b4a9a")
const DIAMOND_A := Color("3d2a5c")
const DIAMOND_B := Color("24183a")

static var _textures: Dictionary = {}


## Готовая текстура рубашки back (строка PlayerProfile); повторы берутся из кэша.
static func texture(back: String) -> ImageTexture:
	if not _textures.has(back):
		_textures[back] = ImageTexture.create_from_image(image(back))
	return _textures[back]


static func image(back: String) -> Image:
	var size := Vector2i(CardView.PIXEL_SIZE)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var r := Rect2i(Vector2i.ZERO, size)
	img.fill(BG)
	img.fill_rect(r.grow(-2), FIELD)
	_outline(img, r.grow(-2), PixelTheme.GOLD)
	_outline(img, r.grow(-6), INNER_LINE)
	var c := size / 2
	if PlayerProfile.clean_back(back) == "":
		_diamonds(img, c)
		return img
	var pixels := PlayerProfile.back_pixels(back)
	var n := PlayerProfile.BACK_SIZE
	var origin := c - Vector2i.ONE * n * ZOOM / 2
	for i in n * n:
		if pixels[i].a > 0.0:
			img.fill_rect(Rect2i(origin + Vector2i(i % n, i / n) * ZOOM, Vector2i.ONE * ZOOM), pixels[i])
	return img


## Рисунка нет — вложенные ромбы и золотая точка, как было до редактора.
static func _diamonds(img: Image, c: Vector2i) -> void:
	for i in range(6):
		var d := 34 - i * 6
		var dx := roundi(d * 0.7)
		var colour := DIAMOND_A if i % 2 == 0 else DIAMOND_B
		for y in range(-d, d + 1):
			var half := int(dx * (1.0 - absf(y) / d))
			img.fill_rect(Rect2i(c.x - half, c.y + y, half * 2 + 1, 1), colour)
	img.fill_rect(Rect2i(c - Vector2i(3, 3), Vector2i(6, 6)), PixelTheme.GOLD)


static func _outline(img: Image, r: Rect2i, colour: Color) -> void:
	img.fill_rect(Rect2i(r.position, Vector2i(r.size.x, 1)), colour)
	img.fill_rect(Rect2i(r.position.x, r.end.y - 1, r.size.x, 1), colour)
	img.fill_rect(Rect2i(r.position, Vector2i(1, r.size.y)), colour)
	img.fill_rect(Rect2i(r.end.x - 1, r.position.y, 1, r.size.y), colour)
