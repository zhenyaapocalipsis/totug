class_name OptionCard
extends Control

## Вариант "Choose one" в виде полноформатной карты: рамка и арт сыгранной
## карты, а в поле текста — только этот вариант. Без названия, цены, аспекта,
## фракции и VP (решение владельца, 2026-09-24): игрок выбирает не карту, а
## действие, и арт лишь напоминает, чья это способность.
##
## Лицо собирается в Image пиксель в пиксель по разметке tools/pixel_cards.gd
## (те же цвета, шрифт 5x7 заглавными, ключевые слова жирным) и рисуется в 1x.

signal pressed

const W := 176
## Окно арта на полной карте (tools/pixel_cards.gd: rect(5, 33, aw + 2, ART_H + 2)).
const ART_SRC := Rect2i(5, 33, W - 10, 102)
const TOP := 4
const TEXT_TOP := TOP + 102 + 5
const LINE_H := 9
const TEXT_MIN_H := 30
const BOTTOM := 5

const C_OUTLINE := Color("0a0612")
const C_FRAME := Color("24153f")
const C_FRAME_HI := Color("4a2f82")
const C_FRAME_LO := Color("160c28")
const C_PARCH := Color("e6d9bc")
const C_PARCH_LO := Color("bfae88")
const C_INK := Color("2a1a30")
const KEYWORDS := ["DEVOUR", "SUPPLANT", "DEPLOY", "ASSASSINATE", "PLACE", "RETURN", "PROMOTE",
	"RECRUIT", "RECRUITS", "MOVE", "FOCUS"]

var _tex: ImageTexture
var _hover := false


## text_lines — высота поля текста в строках: у всех вариантов одного выбора
## она одинаковая, чтобы карты стояли ровным рядом.
func _init(card_id: String, text: String, text_lines: int) -> void:
	var text_h := maxi(TEXT_MIN_H, text_lines * LINE_H + 8)
	var h := TEXT_TOP + text_h + BOTTOM
	custom_minimum_size = Vector2(W, h)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())
	_tex = ImageTexture.create_from_image(render(card_id, text, text_h))


## Число строк, в которые текст варианта ляжет на карте.
static func line_count(text: String) -> int:
	return _wrap(text).size()


static func render(card_id: String, text: String, text_h: int) -> Image:
	var h := TEXT_TOP + text_h + BOTTOM
	var img := Image.create(W, h, false, Image.FORMAT_RGBA8)
	img.fill(C_OUTLINE)
	img.fill_rect(Rect2i(1, 1, W - 2, h - 2), C_FRAME)
	img.fill_rect(Rect2i(1, 1, W - 2, 1), C_FRAME_HI)
	img.fill_rect(Rect2i(1, 1, 1, h - 2), C_FRAME_HI)
	img.fill_rect(Rect2i(1, h - 2, W - 2, 1), C_FRAME_LO)
	img.fill_rect(Rect2i(W - 2, 1, 1, h - 2), C_FRAME_LO)

	# арт (с чёрной обводкой) — прямо с полной карты
	var face: Texture2D = CardView.pixel_texture(card_id)
	if face != null:
		var src := face.get_image()
		if src.is_compressed():
			src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		img.blit_rect(src, ART_SRC, Vector2i(ART_SRC.position.x, TOP))
	else:
		img.fill_rect(Rect2i(ART_SRC.position.x, TOP, ART_SRC.size.x, ART_SRC.size.y), C_FRAME_LO)

	# поле текста
	img.fill_rect(Rect2i(7, TEXT_TOP, W - 14, text_h), C_OUTLINE)
	img.fill_rect(Rect2i(8, TEXT_TOP + 1, W - 16, text_h - 2), C_PARCH)
	img.fill_rect(Rect2i(8, TEXT_TOP + text_h - 2, W - 16, 1), C_PARCH_LO)
	img.fill_rect(Rect2i(W - 9, TEXT_TOP + 1, 1, text_h - 2), C_PARCH_LO)
	var lines := _wrap(text)
	var y := TEXT_TOP + (text_h - (lines.size() * LINE_H - 2)) / 2
	for line: Array in lines:
		var line_w := -5
		for word: String in line:
			line_w += _word_width(word) + 5
		var x := (W - line_w) / 2
		for word: String in line:
			_draw_word(img, x, y, word)
			x += _word_width(word) + 5
		y += LINE_H
	return img


## Слова по строкам поля текста (ширина как у полной карты: W - 22).
static func _wrap(text: String) -> Array:
	var clean := text.replace("->", "►").to_upper()
	var lines: Array = []
	var cur: Array = []
	var cur_w := 0
	for word in clean.split(" ", false):
		var ww := _word_width(word)
		if not cur.is_empty() and cur_w + 5 + ww <= W - 22:
			cur.append(word)
			cur_w += 5 + ww
		else:
			if not cur.is_empty():
				lines.append(cur)
			cur = [word]
			cur_w = ww
	if not cur.is_empty():
		lines.append(cur)
	return lines


static func _is_keyword(word: String) -> bool:
	return KEYWORDS.has(word.rstrip(".,:;"))


## Ключевое слово — жирное: каждая буква дважды со сдвигом на пиксель.
static func _word_width(word: String) -> int:
	var extra := word.rstrip(".,:;").length() if _is_keyword(word) else 0
	return PixelFont.text_width(word) + extra


static func _draw_word(img: Image, x: int, y: int, word: String) -> void:
	if not _is_keyword(word):
		PixelFont.draw_text(img, x, y, word, C_INK)
		return
	var bare := word.rstrip(".,:;")
	for i in bare.length():
		PixelFont.draw_text(img, x + i * 7, y, bare[i], C_INK)
		PixelFont.draw_text(img, x + i * 7 + 1, y, bare[i], C_INK)
	PixelFont.draw_text(img, x + bare.length() * 7, y, word.substr(bare.length()), C_INK)


func _draw() -> void:
	draw_texture(_tex, Vector2.ZERO)
	# золотая рамка — карту можно выбрать; под курсором — толще
	draw_rect(Rect2(Vector2.ZERO, size).grow(-0.5), PixelTheme.GOLD, false, 1.0)
	if _hover:
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)).grow(-0.5), PixelTheme.GOLD, false, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit()
		accept_event()
