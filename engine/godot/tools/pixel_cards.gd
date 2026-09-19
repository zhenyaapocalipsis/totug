extends SceneTree

## Pixel-art card faces for every card in data/cards/cards.json.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --script "C:/tyrants of the underdark godot/engine/godot/tools/pixel_cards.gd"
## Art is cropped from the sheets in cards/ and reduced to 28 colours; frame, text,
## icons and VP are drawn with a 5x7 pixel font. Output: one 1x PNG per card_id
## (display with nearest filtering, e.g. at x4), plus x2 preview sheets.

const ROOT := "C:/tyrants of the underdark godot/"
const OUT := ROOT + "engine/godot/assets/cards_pixel/"
const OUT_MINI := ROOT + "engine/godot/assets/cards_mini/"
## Мелкая карта для руки и маркета: на экране 640x360 полная карта не влезает,
## а ужимать её нельзя — текст превратится в кашу. Поэтому у каждой карты есть
## второе лицо, нарисованное сразу маленьким: имя, арт, цена и VP.
const MINI_W := 64
const MINI_H := 88
const PREVIEW := ROOT + "Claude outputs/pixel_cards_preview/"
const W := 176
const ART_H := 100
const ART_COLORS := 28
const LINE_H := 9
const PARA_GAP := 3

const C_OUTLINE := Color("0a0612")
const C_FRAME := Color("24153f")
const C_FRAME_HI := Color("4a2f82")
const C_FRAME_LO := Color("160c28")
const C_LIGHT := Color("f0e6d2")
const C_GREY := Color("a89cc0")
const C_PARCH := Color("e6d9bc")
const C_PARCH_LO := Color("bfae88")
const C_INK := Color("2a1a30")
const C_IC := Color("3b2c96")
const C_IC_HI := Color("6a5ad0")

const ASPECT_COLOR := {
	"CONQUEST": Color("8fd3ff"), "AMBITION": Color("f2d23c"), "GUILE": Color("5ccf5c"),
	"MALICE": Color("d0283e"), "OBEDIENCE": Color("ffffff"), "": Color("a89cc0"),
}

const KEYWORDS := ["DEVOUR", "SUPPLANT", "DEPLOY", "ASSASSINATE", "PLACE", "RETURN", "PROMOTE",
	"RECRUIT", "RECRUITS", "MOVE", "FOCUS"]

# deck id -> [sheet file, columns, card w, card h, art rect (x, y, w, h) inside the card]
const SHEETS := {
	483: ["drow + obidience + insane outcast.jpg", 10, 749, 1046, Rect2i(25, 195, 693, 365)],
	484: ["dragons.jpg", 10, 749, 1046, Rect2i(25, 195, 693, 365)],
	485: ["demons.jpg", 10, 749, 1046, Rect2i(25, 195, 693, 365)],
	486: ["elemental.jpg", 10, 749, 1046, Rect2i(25, 195, 693, 365)],
	487: ["aberations + undead.jpg", 7, 750, 1000, Rect2i(24, 200, 690, 340)],
}

const FONT := {
	"A": ["01110","10001","10001","11111","10001","10001","10001"],
	"B": ["11110","10001","10001","11110","10001","10001","11110"],
	"C": ["01110","10001","10000","10000","10000","10001","01110"],
	"D": ["11110","10001","10001","10001","10001","10001","11110"],
	"E": ["11111","10000","10000","11110","10000","10000","11111"],
	"F": ["11111","10000","10000","11110","10000","10000","10000"],
	"G": ["01110","10001","10000","10111","10001","10001","01111"],
	"H": ["10001","10001","10001","11111","10001","10001","10001"],
	"I": ["01110","00100","00100","00100","00100","00100","01110"],
	"J": ["00111","00010","00010","00010","00010","10010","01100"],
	"K": ["10001","10010","10100","11000","10100","10010","10001"],
	"L": ["10000","10000","10000","10000","10000","10000","11111"],
	"M": ["10001","11011","10101","10101","10001","10001","10001"],
	"N": ["10001","10001","11001","10101","10011","10001","10001"],
	"O": ["01110","10001","10001","10001","10001","10001","01110"],
	"P": ["11110","10001","10001","11110","10000","10000","10000"],
	"Q": ["01110","10001","10001","10001","10101","10010","01101"],
	"R": ["11110","10001","10001","11110","10100","10010","10001"],
	"S": ["01111","10000","10000","01110","00001","00001","11110"],
	"T": ["11111","00100","00100","00100","00100","00100","00100"],
	"U": ["10001","10001","10001","10001","10001","10001","01110"],
	"V": ["10001","10001","10001","10001","10001","01010","00100"],
	"W": ["10001","10001","10001","10101","10101","10101","01010"],
	"X": ["10001","10001","01010","00100","01010","10001","10001"],
	"Y": ["10001","10001","10001","01010","00100","00100","00100"],
	"Z": ["11111","00001","00010","00100","01000","10000","11111"],
	"0": ["01110","10001","10011","10101","11001","10001","01110"],
	"1": ["00100","01100","00100","00100","00100","00100","01110"],
	"2": ["01110","10001","00001","00010","00100","01000","11111"],
	"3": ["11111","00010","00100","00010","00001","10001","01110"],
	"4": ["00010","00110","01010","10010","11111","00010","00010"],
	"5": ["11111","10000","11110","00001","00001","10001","01110"],
	"6": ["00110","01000","10000","11110","10001","10001","01110"],
	"7": ["11111","00001","00010","00100","01000","01000","01000"],
	"8": ["01110","10001","10001","01110","10001","10001","01110"],
	"9": ["01110","10001","10001","01111","00001","00010","01100"],
	".": ["00000","00000","00000","00000","00000","01100","01100"],
	",": ["00000","00000","00000","00000","01100","00100","01000"],
	":": ["00000","01100","01100","00000","01100","01100","00000"],
	";": ["00000","01100","01100","00000","01100","00100","01000"],
	">": ["00000","01000","01100","01110","01100","01000","00000"],
	"-": ["00000","00000","00000","11111","00000","00000","00000"],
	"+": ["00000","00100","00100","11111","00100","00100","00000"],
	"'": ["00100","00100","01000","00000","00000","00000","00000"],
	"\"": ["01010","01010","00000","00000","00000","00000","00000"],
	"(": ["00010","00100","01000","01000","01000","00100","00010"],
	")": ["01000","00100","00010","00010","00010","00100","01000"],
	"/": ["00001","00010","00010","00100","01000","01000","10000"],
	"!": ["00100","00100","00100","00100","00100","00000","00100"],
	"?": ["01110","10001","00001","00010","00100","00000","00100"],
	"•": ["00000","00000","01110","01110","01110","00000","00000"],
	" ": ["00000","00000","00000","00000","00000","00000","00000"],
}
const CHAR_MAP := {"’": "'", "►": ">", "É": "E", "—": "-", "–": "-"}

const ICONS := {
	"CONQUEST": ["1010101","1111111","0111110","0110110","0111110","0111110","1111111"],
	"MALICE": ["0111110","1111111","1001001","1111111","0110110","0111110","0101010"],
	"AMBITION": ["0001000","1001001","1011101","1111111","1111111","0111110","0111110"],
	"GUILE": ["0111110","1000001","1011101","1010101","1011001","1000010","0111100"],
	"OBEDIENCE": ["0011100","0100010","0100010","1111111","1110111","1111111","0111110"],
}

var img: Image
var sheets_cache := {}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(OUT_MINI)
	var all: Array = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "engine/godot/data/cards/cards.json"))

	# One layout for the whole set: the text box fits the longest card text.
	var max_text_px := 0
	var max_name := ""
	for c: Dictionary in all:
		var h := text_block_height(layout_text(sv(c["ability_text"])))
		if h > max_text_px:
			max_text_px = h
			max_name = sv(c["name"])
	print("tallest text: ", max_name, " ", max_text_px, "px")
	var text_top := 34 + ART_H + 5
	var text_h := max_text_px + 8
	var H := text_top + text_h + 22
	print("card size: ", W, "x", H)

	DirAccess.make_dir_recursive_absolute(PREVIEW)
	var rendered: Array[Image] = []
	for c: Dictionary in all:
		if not SHEETS.has(int(c["card_id"]) / 100):
			print("no art sheet for card ", c["card_id"], " ", c["name"])
			continue
		var card := render(c, H, text_top, text_h)
		card.save_png(OUT + "%d.png" % int(c["card_id"]))
		rendered.append(card)
		render_mini(c).save_png(OUT_MINI + "%d.png" % int(c["card_id"]))
	print("rendered: ", rendered.size())

	# preview sheets: 5x5 cards at x2
	var s := 2
	var gap := 6
	var per_page := 25
	for page in ceili(rendered.size() / float(per_page)):
		var sheet := Image.create(5 * (W * s + gap) + gap, 5 * (H * s + gap) + gap, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.08, 0.08, 0.1))
		for i in range(page * per_page, mini(rendered.size(), (page + 1) * per_page)):
			var j := i - page * per_page
			var b := rendered[i].duplicate() as Image
			b.resize(W * s, H * s, Image.INTERPOLATE_NEAREST)
			sheet.blit_rect(b, Rect2i(0, 0, W * s, H * s), Vector2i(gap + (j % 5) * (W * s + gap), gap + (j / 5) * (H * s + gap)))
		sheet.save_png(PREVIEW + "sheet_%d.png" % (page + 1))
	quit()


func render(c: Dictionary, H: int, text_top: int, text_h: int) -> Image:
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(C_OUTLINE)
	rect(1, 1, W - 2, H - 2, C_FRAME)
	rect(1, 1, W - 2, 1, C_FRAME_HI)
	rect(1, 1, 1, H - 2, C_FRAME_HI)
	rect(1, H - 2, W - 2, 1, C_FRAME_LO)
	rect(W - 2, 1, 1, H - 2, C_FRAME_LO)

	var card_id := int(c["card_id"])
	var aspect := sv(c["aspect"])
	var aspect_col: Color = ASPECT_COLOR.get(aspect, C_GREY)

	# header: cost (2x, right) + name (2x if it fits, else 1x in one or two lines)
	var cost_str := "" if c["cost"] == null else str(int(c["cost"]))
	var cost_w := text_width(cost_str, 2)
	if cost_str != "":
		text(W - 7 - cost_w, 6, cost_str, C_LIGHT, 2, C_OUTLINE)
	var name := clean(sv(c["name"]))
	var name_room := W - 14 - (cost_w + 10 if cost_str != "" else 0)
	if text_width(name, 2) <= name_room:
		text(7, 6, name, C_LIGHT, 2, C_OUTLINE)
	else:
		var nl := wrap_plain(name, name_room)
		if nl.size() == 1:
			text(7, 10, nl[0], C_LIGHT, 1, C_OUTLINE)
		else:
			text(7, 3, nl[0], C_LIGHT, 1, C_OUTLINE)
			text(7, 13, nl[1], C_LIGHT, 1, C_OUTLINE)

	# aspect row
	if aspect != "":
		glyph_rows(7, 24, ICONS[aspect], aspect_col)
		text(17, 24, aspect, aspect_col, 1)
	var type_str := clean(sv(c["type"]))
	text(W - 7 - text_width(type_str, 1), 24, type_str, C_GREY, 1)

	# art
	var aw := W - 12
	var art := pixelize(art_region(card_id, aw, ART_H), aw, ART_H, ART_COLORS)
	rect(5, 33, aw + 2, ART_H + 2, C_OUTLINE)
	img.blit_rect(art, Rect2i(0, 0, aw, ART_H), Vector2i(6, 34))

	# text box
	rect(7, text_top, W - 14, text_h, C_OUTLINE)
	rect(8, text_top + 1, W - 16, text_h - 2, C_PARCH)
	rect(8, text_top + text_h - 2, W - 16, 1, C_PARCH_LO)
	rect(W - 9, text_top + 1, 1, text_h - 2, C_PARCH_LO)
	var paras := layout_text(sv(c["ability_text"]))
	var content_h := text_block_height(paras)
	var y := text_top + 4 + (text_h - 8 - content_h) / 2
	for p: Dictionary in paras:
		for li in p["lines"].size():
			var x := 11 + (8 if p["bullet"] else 0)
			if p["bullet"] and li == 0:
				text(11, y, "•", C_INK, 1)
			for tok: Array in p["lines"][li]:
				draw_word(x, y, String(tok[0]))
				x += word_width(String(tok[0])) + 5
			y += LINE_H
		y += PARA_GAP

	# footer: set name + VP
	var by := H - 19
	rect(W - 42, by, 17, 15, C_OUTLINE)
	rect(W - 41, by + 1, 15, 13, C_LIGHT)
	var dv := str(int(c["deck_vp"]))
	text(W - 33 - text_width(dv, 1) / 2, by + 4, dv, C_INK, 1)
	circle(W - 15, by + 7, 8, C_OUTLINE)
	circle(W - 15, by + 7, 7, C_IC)
	circle(W - 16, by + 6, 5, C_IC_HI)
	circle(W - 15, by + 7, 4, C_IC)
	var iv := str(int(c["inner_circle_vp"]))
	text(W - 15 - text_width(iv, 1) / 2, by + 4, iv, C_LIGHT, 1)
	text(9, by + 4, set_name(card_id, sv(c["type"])), C_GREY, 1)
	return img


func set_name(card_id: int, type: String) -> String:
	match card_id / 100:
		483: return "DROW"
		484: return "DRAGONS"
		485: return "DEMONS"
		486: return "ELEMENTAL"
	# the shared sheet: indices 0-19 and Umber Hulk (39) belong to the Aberrations half
	var idx := card_id % 100
	return "ABERRATIONS" if idx < 20 or idx == 39 else "UNDEAD"


func art_region(card_id: int, aw: int, ah: int) -> Image:
	var deck := card_id / 100
	var idx := card_id % 100
	var info: Array = SHEETS[deck]
	if not sheets_cache.has(deck):
		sheets_cache[deck] = Image.load_from_file(ROOT + "cards/" + String(info[0]))
	var sheet: Image = sheets_cache[deck]
	var cols: int = info[1]
	var cw: int = info[2]
	var ch: int = info[3]
	var r: Rect2i = info[4]
	# largest crop with the art window's aspect ratio, centred in the art area
	var want_w := int(r.size.y * aw / float(ah))
	var crop := r
	if want_w <= r.size.x:
		crop = Rect2i(r.position.x + (r.size.x - want_w) / 2, r.position.y, want_w, r.size.y)
	else:
		var want_h := int(r.size.x * ah / float(aw))
		crop = Rect2i(r.position.x, r.position.y + (r.size.y - want_h) / 2, r.size.x, want_h)
	return sheet.get_region(Rect2i((idx % cols) * cw + crop.position.x, (idx / cols) * ch + crop.position.y, crop.size.x, crop.size.y))


## Card text lines in cards.json are the printed line breaks, not paragraphs.
## Rejoin them: a new paragraph starts after "." or ":", before a bullet,
## after a resource line ("+2 Power"), or before an "<Aspect> Focus" line.
func layout_text(raw: String) -> Array:
	var paras: Array[String] = []
	for line in raw.split("\n"):
		line = line.strip_edges()
		if line == "":
			continue
		if paras.is_empty():
			paras.append(line)
			continue
		var prev := paras[-1]
		var resource_line := RegEx.create_from_string("^(\\+\\d+ (Power|Influence) ?)+$")
		var brk := prev.ends_with(".") or prev.ends_with(":") or line.begins_with("•") \
			or resource_line.search(prev) != null or line.begins_with("+") or line.contains("Focus ►")
		if prev.ends_with("►"):
			brk = false
		if brk:
			paras.append(line)
		elif prev.ends_with("-"):
			paras[-1] = prev + line
		else:
			paras[-1] = prev + " " + line
	var out: Array = []
	var room := W - 22
	for p in paras:
		var bullet := p.begins_with("•")
		if bullet:
			p = p.substr(1).strip_edges()
		var width := room - (8 if bullet else 0)
		var lines: Array = []
		var cur: Array = []
		var cur_w := 0
		for word in clean(p).split(" ", false):
			var ww := word_width(word)
			if cur.is_empty():
				cur = [[word]]
				cur_w = ww
			elif cur_w + 5 + ww <= width:
				cur.append([word])
				cur_w += 5 + ww
			else:
				lines.append(cur)
				cur = [[word]]
				cur_w = ww
		if not cur.is_empty():
			lines.append(cur)
		out.append({"bullet": bullet, "lines": lines})
	return out


func text_block_height(paras: Array) -> int:
	var h := 0
	for p: Dictionary in paras:
		h += p["lines"].size() * LINE_H + PARA_GAP
	return h - PARA_GAP - 2


func clean(s: String) -> String:
	s = s.to_upper()
	for k: String in CHAR_MAP:
		s = s.replace(k, CHAR_MAP[k])
	return s


func is_keyword(word: String) -> bool:
	return KEYWORDS.has(word.rstrip(".,:;"))


## Bold = glyph drawn twice, shifted one pixel right (1px wider per letter).
func word_width(word: String) -> int:
	var bare := word.rstrip(".,:;")
	var extra := bare.length() if is_keyword(word) else 0
	return text_width(word, 1) + extra


func draw_word(x: int, y: int, word: String) -> void:
	if not is_keyword(word):
		text(x, y, word, C_INK, 1)
		return
	var bare := word.rstrip(".,:;")
	for i in bare.length():
		var g: Array = glyph(bare[i])
		glyph_rows(x + i * 7, y, g, C_INK)
		glyph_rows(x + i * 7 + 1, y, g, C_INK)
	text(x + bare.length() * 7, y, word.substr(bare.length()), C_INK, 1)


func wrap_plain(s: String, max_px: int) -> Array[String]:
	var out: Array[String] = []
	var cur := ""
	for word in s.split(" "):
		var t := word if cur == "" else cur + " " + word
		if text_width(t, 1) > max_px and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = t
	out.append(cur)
	return out


func text_width(s: String, scale: int) -> int:
	return max(0, s.length() * (6 * scale - (scale - 1)) - 1)


func glyph(ch: String) -> Array:
	if not FONT.has(ch):
		print("missing glyph: ", ch)
		return FONT[" "]
	return FONT[ch]


func rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


func circle(cx: int, cy: int, r: int, c: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r + r:
				img.set_pixel(cx + dx, cy + dy, c)


func glyph_rows(x: int, y: int, rows: Array, c: Color, s: int = 1) -> void:
	for ry in rows.size():
		var row: String = rows[ry]
		for rx in row.length():
			if row[rx] == "1":
				img.fill_rect(Rect2i(x + rx * s, y + ry * s, s, s), c)


func text(x: int, y: int, s: String, c: Color, scale: int, shadow := Color(0, 0, 0, 0)) -> void:
	for i in s.length():
		var g: Array = glyph(s[i])
		if shadow.a > 0:
			glyph_rows(x + i * (6 * scale - (scale - 1)) + scale, y + scale, g, shadow, scale)
		glyph_rows(x + i * (6 * scale - (scale - 1)), y, g, c, scale)


func pixelize(src: Image, tw: int, th: int, k: int) -> Image:
	var im := src.duplicate() as Image
	im.convert(Image.FORMAT_RGBA8)
	im.resize(tw, th, Image.INTERPOLATE_LANCZOS)
	var px: Array[Color] = []
	for y in th:
		for x in tw:
			var c := im.get_pixel(x, y)
			c = Color.from_hsv(c.h, clampf(c.s * 1.2, 0, 1), clampf(c.v * 1.05, 0, 1))
			im.set_pixel(x, y, c)
			px.append(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var centers: Array[Color] = []
	for i in k:
		centers.append(px[rng.randi_range(0, px.size() - 1)])
	for it in 14:
		var sums: Array[Vector3] = []
		var counts: Array[int] = []
		for i in k:
			sums.append(Vector3.ZERO)
			counts.append(0)
		for c in px:
			var b := nearest(centers, c)
			sums[b] += Vector3(c.r, c.g, c.b)
			counts[b] += 1
		for i in k:
			if counts[i] > 0:
				var m := sums[i] / counts[i]
				centers[i] = Color(m.x, m.y, m.z)
	for y in th:
		for x in tw:
			var p := centers[nearest(centers, im.get_pixel(x, y))]
			im.set_pixel(x, y, Color(p.r, p.g, p.b, 1))
	return im


func nearest(centers: Array[Color], c: Color) -> int:
	var best := 0
	var bd := 1e9
	for i in centers.size():
		var p := centers[i]
		var d := (p.r - c.r) * (p.r - c.r) * 0.3 + (p.g - c.g) * (p.g - c.g) * 0.59 + (p.b - c.b) * (p.b - c.b) * 0.11
		if d < bd:
			bd = d
			best = i
	return best


func sv(v: Variant) -> String:
	return "" if v == null else str(v)





## Мелкое лицо карты 64x88 для руки, маркета и полос сыгранных карт: шапка в
## цвет аспекта с именем в две строки, арт, а внизу цена, тип и оба значения
## VP. Текста способности здесь нет — его читают на большой карте под курсором.
func render_mini(c: Dictionary) -> Image:
	img = Image.create(MINI_W, MINI_H, false, Image.FORMAT_RGBA8)
	img.fill(C_OUTLINE)
	var aspect := sv(c["aspect"])
	var aspect_col: Color = ASPECT_COLOR.get(aspect, C_GREY)
	rect(1, 1, MINI_W - 2, MINI_H - 2, C_FRAME)
	rect(1, 1, MINI_W - 2, 1, C_FRAME_HI)
	rect(1, MINI_H - 2, MINI_W - 2, 1, C_FRAME_LO)

	# шапка: имя в две строки на подложке цвета аспекта
	rect(1, 1, MINI_W - 2, 18, Color(aspect_col.darkened(0.62), 1.0))
	rect(1, 18, MINI_W - 2, 1, C_OUTLINE)
	var name_lines := wrap_plain(clean(sv(c["name"])), MINI_W - 7)
	for i in mini(name_lines.size(), 2):
		var line: String = name_lines[i]
		if i == 1 and name_lines.size() > 2:
			line = line.substr(0, 8) + "."
		text(3, 2 + i * 8, line, C_LIGHT, 1, C_OUTLINE)

	# арт
	var art := pixelize(art_region(int(c["card_id"]), MINI_W - 6, 34), MINI_W - 6, 34, 16)
	img.blit_rect(art, Rect2i(0, 0, MINI_W - 6, 34), Vector2i(3, 20))
	rect(2, 19, MINI_W - 4, 1, C_OUTLINE)
	rect(2, 54, MINI_W - 4, 1, C_OUTLINE)

	# строка аспекта и типа
	if aspect != "":
		glyph_rows(3, 57, ICONS[aspect], aspect_col)
	var type_str := clean(sv(c["type"]))
	text(12, 57, type_str.substr(0, 8), C_GREY, 1)

	# цена крупно слева, VP колоды и Внутреннего круга справа
	var cost_str := "" if c["cost"] == null else str(int(c["cost"]))
	if cost_str != "":
		text(4, 68, cost_str, C_LIGHT, 2, C_OUTLINE)
	var dv := str(int(c["deck_vp"]))
	rect(MINI_W - 31, 68, 14, 12, C_OUTLINE)
	rect(MINI_W - 30, 69, 12, 10, C_LIGHT)
	text(MINI_W - 24 - text_width(dv, 1) / 2, 71, dv, C_INK, 1)
	circle(MINI_W - 10, 74, 7, C_OUTLINE)
	circle(MINI_W - 10, 74, 6, C_IC)
	circle(MINI_W - 11, 73, 4, C_IC_HI)
	circle(MINI_W - 10, 74, 3, C_IC)
	var iv := str(int(c["inner_circle_vp"]))
	text(MINI_W - 10 - text_width(iv, 1) / 2, 71, iv, C_LIGHT, 1)
	return img
