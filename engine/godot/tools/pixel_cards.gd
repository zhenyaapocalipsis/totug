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
## второе лицо, нарисованное сразу маленьким: имя, цена, арт и оба VP.
##
## Ширина 80, а не 64: в 64 имена вроде WATER ELEMENTAL MYRMIDON не влезали
## даже в две строки и обрезались, а WEAPONMASTER уезжал за край. Размер один
## на все карты — иначе они не встанут ровным рядом в руке и маркете.
const MINI_W := 80
const MINI_H := 76
## Шапка и арт под ней. В шапке слева имя, справа колонка: цена, значок
## аспекта, VP в колоде и во внутреннем круге (решение владельца, 2026-09-24).
const MINI_HEAD := 26
const MINI_ART_H := 45
const MINI_LINE_H := 8
const MINI_NAME_LINES := 3
## Ширина правой колонки шапки: две плашки VP по 7 пикселей с зазором в 1.
const MINI_VP_W := 15
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
const C_GOLD := Color("f2d23c")

const ASPECT_COLOR := {
	"CONQUEST": Color("8fd3ff"), "AMBITION": Color("f2d23c"), "GUILE": Color("5ccf5c"),
	"MALICE": Color("d0283e"), "OBEDIENCE": Color("ffffff"), "": Color("a89cc0"),
}

const KEYWORDS := ["DEVOUR", "SUPPLANT", "DEPLOY", "ASSASSINATE", "PLACE", "RETURN", "PROMOTE",
	"RECRUIT", "RECRUITS", "MOVE", "FOCUS"]

## Где можно рвать слово, которое само шире строки мелкой карты: границы слогов
## (номер буквы, после которой ставится дефис). Берётся самая дальняя граница,
## что влезает в строку (решение владельца, 2026-09-24: переносить по слогам).
## Слова, которых тут нет, рвутся примерно посередине — генератор печатает их
## как "hyphenated", их стоит дописать сюда.
const NAME_BREAKS := {
	"AMBASSADOR": [2, 5, 7], "BLACKGUARD": [5], "BRAINWASHED": [5], "DEATHBLADE": [5],
	"DEMOGORGON": [2, 4, 7], "DOPPELGANGER": [3, 6, 9], "DRAGONCLAW": [3, 6],
	"INFILTRATOR": [2, 5, 8], "INFORMATION": [2, 5, 7], "INQUISITOR": [2, 5, 7],
	"JACKALWERE": [4, 6], "MINDWITNESS": [4, 7], "NALFESHNEE": [3, 7],
	"NECROMANCER": [3, 5, 8], "NEGOTIATOR": [2, 4, 6, 7], "SHATTERKEEL": [4, 7],
	"SPELLSPINNER": [5, 9], "WEAPONMASTER": [6, 9], "WYRMSPEAKER": [4, 9],
}

# deck id -> [sheet file, columns, card w, card h, art rect (x, y, w, h) inside the card]
const SHEETS := {
	483: ["drow + obidience + insane outcast.jpg", 10, 749, 1046, Rect2i(25, 195, 693, 365)],
	484: ["dragons.jpg", 10, 749, 1046, Rect2i(25, 195, 693, 365)],
	485: ["demons.jpg", 10, 749, 1046, Rect2i(25, 195, 693, 365)],
	486: ["elemental.jpg", 10, 749, 1046, Rect2i(25, 195, 693, 365)],
	487: ["aberations + undead.jpg", 7, 750, 1000, Rect2i(24, 200, 690, 340)],
}
## Карты не из листов TTS: отдельная картинка карты и окно арта в ней.
const SINGLE_ART := {
	48345: ["conscription_officer.webp", Rect2i(60, 172, 675, 420)],
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

	# "-- mini": перерисовать только мелкие лица, не трогая большие карты. Полный
	# прогон долгий (подбор палитры для каждого арта), а разметку мелкой карты
	# приходится перебирать по многу раз.
	if OS.get_cmdline_user_args().has("mini"):
		render_mini_preview(all)
		return

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
		if not SHEETS.has(int(c["card_id"]) / 100) and not SINGLE_ART.has(int(c["card_id"])):
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
	# Плашки VP такие же, как на мелкой карте (решение владельца, 2026-09-24).
	var ic_x := mini_vp_badge(W - 7, by + 3, str(int(c["inner_circle_vp"])), C_IC_HI, C_LIGHT)
	mini_vp_badge(ic_x - 1, by + 3, str(int(c["deck_vp"])), C_PARCH, C_INK)
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
	if SINGLE_ART.has(card_id):
		var one: Array = SINGLE_ART[card_id]
		return crop_to(Image.load_from_file(ROOT + "cards/" + String(one[0])), one[1], aw, ah)
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
	var cell := Vector2i((idx % cols) * cw, (idx / cols) * ch)
	return crop_to(sheet, Rect2i(cell + r.position, r.size), aw, ah)


func crop_to(sheet: Image, r: Rect2i, aw: int, ah: int) -> Image:
	# largest crop with the art window's aspect ratio, centred in the art area
	var want_w := int(r.size.y * aw / float(ah))
	var crop := r
	if want_w <= r.size.x:
		crop = Rect2i(r.position.x + (r.size.x - want_w) / 2, r.position.y, want_w, r.size.y)
	else:
		var want_h := int(r.size.x * ah / float(aw))
		crop = Rect2i(r.position.x, r.position.y + (r.size.y - want_h) / 2, r.size.x, want_h)
	return sheet.get_region(crop)


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





## Мелкое лицо карты 80x76 для руки, маркета и полос сыгранных карт: шапка в
## цвет аспекта с именем и ценой, под ней арт — и всё. Ни типа существа, ни
## текста способности, ни VP здесь нет: для хода они ничего не решают, а
## прочесть их можно на большой карте под курсором.
##
## Цена стоит в правом верхнем углу, как на большой карте: в маркете виден
## только верх лица, и цена должна попадать в него вместе с именем.
func render_mini(c: Dictionary) -> Image:
	img = Image.create(MINI_W, MINI_H, false, Image.FORMAT_RGBA8)
	img.fill(C_OUTLINE)
	var aspect := sv(c["aspect"])
	var aspect_col: Color = ASPECT_COLOR.get(aspect, C_GREY)
	rect(1, 1, MINI_W - 2, MINI_H - 2, C_FRAME)
	rect(1, 1, MINI_W - 2, 1, C_FRAME_HI)
	# Низ рамки того же цвета, что бока (а не темнее, как у большой карты):
	# полоска в один пиксель под артом замыкает рамку, и карта перестаёт
	# выглядеть обрезанной по нижнему краю.
	rect(1, MINI_H - 2, MINI_W - 2, 1, C_FRAME)

	# Шапка цвета рамки карты, одна на все карты (решение владельца,
	# 2026-09-24): аспект теперь показывает значок, а не подложка.
	rect(1, 1, MINI_W - 2, MINI_HEAD, C_FRAME)
	# Правая колонка сверху вниз: цена (того же цвета, что имя), значок
	# аспекта, плашки VP в колоде и VP во внутреннем круге.
	var cost_str := "" if c["cost"] == null else str(int(c["cost"]))
	if cost_str != "":
		text(MINI_W - 3 - text_width(cost_str, 1), 2, cost_str, C_LIGHT, 1, C_OUTLINE)
	if aspect != "":
		glyph_rows(MINI_W - 3 - 7, 10, ICONS[aspect], aspect_col)
	# Плашки прижаты к правому краю; ширина по числу (у Insane Outcast -1).
	var ic_x := mini_vp_badge(MINI_W - 3, 18, str(int(c["inner_circle_vp"])), C_IC_HI, C_LIGHT)
	mini_vp_badge(ic_x - 1, 18, str(int(c["deck_vp"])), C_PARCH, C_INK)
	# Колонка во всю высоту шапки, поэтому имя идёт слева от неё во всех строках.
	var room := MINI_W - 5 - (MINI_VP_W + 3)
	var name_lines := wrap_name(clean(sv(c["name"])), room, room, MINI_NAME_LINES, MINI_NAME_LINES)
	# По верхнему краю, а не по центру шапки: имя должно начинаться на одной
	# линии с ценой, иначе короткие имена провисают относительно неё.
	for i in name_lines.size():
		text(3, 2 + i * MINI_LINE_H, name_lines[i], C_LIGHT, 1, C_OUTLINE)

	# арт
	var art_y := 1 + MINI_HEAD + 1
	var aw := MINI_W - 6
	var art := pixelize(art_region(int(c["card_id"]), aw, MINI_ART_H), aw, MINI_ART_H, 16)
	# Чёрная обводка в пиксель по всему периметру арта, как на большой карте.
	rect(2, art_y - 1, aw + 2, MINI_ART_H + 2, C_OUTLINE)
	img.blit_rect(art, Rect2i(0, 0, aw, MINI_ART_H), Vector2i(3, art_y))
	return img


## Плашка VP высотой 9, правым краем на right: светлая — VP в колоде,
## фиолетовая — во внутреннем круге (цвета как на большой карте). Возвращает
## левый край плашки.
func mini_vp_badge(right: int, y: int, v: String, bg: Color, fg: Color) -> int:
	var w := text_width(v, 1) + 2
	rect(right - w, y, w, 9, bg)
	text(right - w + 1, y + 1, v, fg, 1)
	return right - w


## Имя мелкой карты: до max_lines строк. Первые blocked строк помещаются слева
## от цены (ширина beside), остальные идут под ней во всю ширину (free). Слово
## длиннее строки рвётся: по дефису, если он есть, иначе просто по месту с
## дефисом — иначе WEAPONMASTER и MELEE-MAGTHERE уезжают за край карты.
func wrap_name(s: String, beside: int, free: int, blocked: int, max_lines: int) -> Array[String]:
	var lines: Array[String] = []
	var words: Array = Array(s.split(" ", false))
	var cur := ""
	var i := 0
	while i < words.size():
		var room: int = free if lines.size() >= blocked else beside
		var word := String(words[i])
		var joined := word if cur == "" else cur + " " + word
		if text_width(joined, 1) <= room:
			cur = joined
			i += 1
		elif cur != "":
			lines.append(cur)
			cur = ""
		else:
			var parts := split_word(word, room)
			lines.append(parts[0])
			words[i] = parts[1]
	if cur != "":
		lines.append(cur)
	if lines.size() > max_lines:
		print("name does not fit: ", s, " -> ", lines)
		lines.resize(max_lines)
		lines[max_lines - 1] = lines[max_lines - 1] + "."
	return lines


## Делит слово, которое само шире строки. Сначала пробуем последний дефис,
## который ещё влезает, потом границу слога из NAME_BREAKS, иначе ставим дефис
## сами — поближе к середине слова.
func split_word(word: String, room: int) -> Array[String]:
	for k in range(word.length() - 1, 0, -1):
		if word[k] == "-" and text_width(word.substr(0, k + 1), 1) <= room:
			return [word.substr(0, k + 1), word.substr(k + 1)]
	var fit := maxi((room + 1) / 6 - 1, 1)
	var cut := 0
	for b: int in NAME_BREAKS.get(word, []):
		if b <= fit:
			cut = maxi(cut, b)
	if cut == 0:
		cut = mini(fit, (word.length() + 1) / 2)
		print("hyphenated: ", word, " -> ", word.substr(0, cut), "- ", word.substr(cut))
	return [word.substr(0, cut) + "-", word.substr(cut)]


## Мелкие лица в assets, а заодно листы в x4 для просмотра разметки глазом.
func render_mini_preview(all: Array) -> void:
	var dir := PREVIEW + "mini/"
	DirAccess.make_dir_recursive_absolute(dir)
	var rendered: Array[Image] = []
	for c: Dictionary in all:
		if not SHEETS.has(int(c["card_id"]) / 100) and not SINGLE_ART.has(int(c["card_id"])):
			continue
		var m := render_mini(c)
		m.save_png(OUT_MINI + "%d.png" % int(c["card_id"]))
		rendered.append(m)
	print("mini rendered: ", rendered.size(), " ", MINI_W, "x", MINI_H)

	var s := 4
	var gap := 8
	var cols := 6
	var rows := 4
	var per_page := cols * rows
	for page in ceili(rendered.size() / float(per_page)):
		var sheet := Image.create(cols * (MINI_W * s + gap) + gap, rows * (MINI_H * s + gap) + gap,
			false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.04, 0.03, 0.07))
		for i in range(page * per_page, mini(rendered.size(), (page + 1) * per_page)):
			var j := i - page * per_page
			var b := rendered[i].duplicate() as Image
			b.resize(MINI_W * s, MINI_H * s, Image.INTERPOLATE_NEAREST)
			sheet.blit_rect(b, Rect2i(0, 0, MINI_W * s, MINI_H * s),
				Vector2i(gap + (j % cols) * (MINI_W * s + gap), gap + (j / cols) * (MINI_H * s + gap)))
		sheet.save_png(dir + "sheet_%d.png" % (page + 1))
	quit()
