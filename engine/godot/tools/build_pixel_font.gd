extends SceneTree

## Собирает растровый шрифт интерфейса из глифов scenes/ui/pixel_font.gd:
## атлас assets/font/pixel5.png плюс описание pixel5.fnt (формат BMFont),
## который Godot импортирует как обычный шрифт для Label, Button и прочего.
##
## Запуск:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path <проект> \
##       --script res://tools/build_pixel_font.gd
##
## Ячейка 5x9 (базовая линия под строкой 6), шаг 6 px. Размер шрифта 9 даёт
## пиксель в пиксель; 18 — тот же шрифт ровно вдвое крупнее.

const OUT_DIR := "res://assets/font/"
const PNG_NAME := "pixel5.png"
const FNT_NAME := "pixel5.fnt"
const CELL_W := PixelFont.ADVANCE      # 6
const CELL_H := PixelFont.CELL_H       # 9
const COLUMNS := 16


func _init() -> void:
	var chars := _charset()
	var rows := int(ceil(float(chars.size()) / COLUMNS))
	var atlas := Image.create(COLUMNS * CELL_W, rows * CELL_H, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(1, 1, 1, 0))

	var lines: Array[String] = []
	var cell_of := {}
	for i in chars.size():
		var ch: String = chars[i]
		var cx := (i % COLUMNS) * CELL_W
		var cy := (i / COLUMNS) * CELL_H
		_blit_glyph(atlas, ch, cx, cy)
		cell_of[ch] = Vector2i(cx, cy)
		lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15"
			% [ch.unicode_at(0), cx, cy, CELL_W, CELL_H, CELL_W])

	# Замены из PixelFont.CHAR_MAP (типографское тире, кавычка и прочее) и
	# кириллица, которая пишется как латиница (CYRILLIC_SAME), — это
	# те же клетки атласа под другим кодом. Без них Label рисует пустой квадрат
	# на каждом таком знаке: подмену CHAR_MAP знает только наш рисовальщик.
	var aliases := PixelFont.CHAR_MAP.merged(PixelFont.CYRILLIC_SAME)
	for alias: String in aliases:
		var target: String = aliases[alias]
		if not cell_of.has(target):
			target = target.to_upper()
		if not cell_of.has(target):
			continue
		var cell: Vector2i = cell_of[target]
		lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15"
			% [alias.unicode_at(0), cell.x, cell.y, CELL_W, CELL_H, CELL_W])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var png_err := atlas.save_png(OUT_DIR + PNG_NAME)
	if png_err != OK:
		push_error("не удалось сохранить атлас: %d" % png_err)
		quit(1)
		return

	var fnt := PackedStringArray([
		"info face=\"pixel5\" size=%d bold=0 italic=0 charset=\"\" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0" % CELL_H,
		"common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0" % [
			CELL_H + 2, PixelFont.BASELINE, atlas.get_width(), atlas.get_height()],
		"page id=0 file=\"%s\"" % PNG_NAME,
		"chars count=%d" % lines.size(),
	])
	fnt.append_array(lines)
	var f := FileAccess.open(OUT_DIR + FNT_NAME, FileAccess.WRITE)
	if f == null:
		push_error("не удалось записать %s" % FNT_NAME)
		quit(1)
		return
	f.store_string("\n".join(fnt) + "\n")
	f.close()

	print("глифов: %d, атлас %dx%d" % [chars.size(), atlas.get_width(), atlas.get_height()])
	quit()


## Все символы, которые умеет рисовать PixelFont, без пробела-заглушки.
func _charset() -> Array[String]:
	var out: Array[String] = []
	for ch: String in PixelFont.FONT.keys():
		out.append(ch)
	for ch: String in PixelFont.LOWER.keys() + PixelFont.CYRILLIC.keys():
		if not out.has(ch):
			out.append(ch)
	out.sort_custom(func(a: String, b: String) -> bool: return a.unicode_at(0) < b.unicode_at(0))
	return out


func _blit_glyph(img: Image, ch: String, x: int, y: int) -> void:
	var glyph: Array = PixelFont.glyph(ch)
	for ry in glyph.size():
		var row: String = glyph[ry]
		for rx in row.length():
			if row[rx] == "1":
				img.set_pixel(x + rx, y + ry, Color(1, 1, 1, 1))
