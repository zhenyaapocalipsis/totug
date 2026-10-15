class_name CardLiveFace
extends RefCounted

## Лицо карты с живым текстом (CardLive, владелец 2026-10-11). Готовые PNG карт
## рисует tools/pixel_cards.gd нашим шрифтом 5x7; здесь тем же шрифтом и той же
## разметкой поле текста большой карты рисуется заново — с пометками после
## фраз ("(3)", "(2/4)"): зелёная — выполнено / не ноль, красная — нет.
## Цена со скидкой — новой цифрой зелёным, на большой и на мелкой карте; на
## мелкой (текста там нет) — ещё плашка с первой пометкой в углу арта.
## Готовые лица кэшируются: одна карта с одними числами рисуется один раз.

const PC := preload("res://tools/pixel_cards.gd")
const TEXT_TOP := 34 + PC.ART_H + 5
const MINI_COST_X := PC.MINI_SIDE_X + 2
const OK_INK := Color("1d6b2a")
const NO_INK := Color("9c1f33")
const OK_LIGHT := Color("5fd36a")
const NO_LIGHT := Color("ff6070")
## Пометка в тексте — слово с этим знаком впереди (\u0001 — зелёная, \u0002 — красная).
const MARK_OK := "\u0001"
const MARK_NO := "\u0002"

static var _cache: Dictionary = {}


static func full(cid: String, art: String, entry: Dictionary) -> Texture2D:
	var key := "F%s|%s|%s" % [cid, art, JSON.stringify(entry)]
	if not _cache.has(key):
		var base := CardView.pixel_texture(cid, art)
		if base == null:
			return null
		var img := base.get_image()
		img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		if entry.has("notes"):
			_draw_text_box(img, String(CardLibrary.card_data(cid).get("ability_text", "")), entry["notes"])
		if entry.has("cost"):
			_draw_cost_full(img, int(entry["cost"]), CardLibrary.card_cost(cid))
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


static func mini(cid: String, art: String, entry: Dictionary) -> Texture2D:
	var key := "M%s|%s|%s" % [cid, art, JSON.stringify(entry)]
	if not _cache.has(key):
		var base := CardView.mini_texture(cid, art)
		if base == null:
			return null
		var img := base.get_image()
		img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		if entry.has("cost"):
			img.fill_rect(Rect2i(MINI_COST_X, 2, PC.MINI_W - MINI_COST_X, 8), PC.C_FRAME)
			img.fill_rect(Rect2i(PC.MINI_W - 1, 2, 1, 8), PC.C_OUTLINE)
			_text(img, MINI_COST_X, 2, str(int(entry["cost"])), OK_LIGHT, 1, PC.C_OUTLINE)
		var notes: Array = entry.get("notes", [])
		if not notes.is_empty():
			var note: Dictionary = notes[-1] if String(notes[0]["text"]).begins_with("(-") \
				and notes.size() > 1 else notes[0]
			var label := String(note["text"]).trim_prefix("(").trim_suffix(")")
			var w := _width(label, 1)
			var x := PC.MINI_W - 3 - w - 2
			var y := PC.MINI_H - 3 - 9
			img.fill_rect(Rect2i(x - 2, y - 1, w + 4, 10), PC.C_OUTLINE)
			_text(img, x, y + 1, label, OK_LIGHT if note["ok"] else NO_LIGHT, 1)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## Текст карты с пометками: поле перерисовывается целиком, как в pixel_cards.gd.
## Пометка удлиняет текст: не влез — абзацы плотнее (промежуток 1 вместо 3), а
## если и так нет — поле поднимается на низ арта (fit_box). Возвращает высоту.
static func _draw_text_box(img: Image, raw: String, notes: Array) -> int:
	var w := img.get_width()
	var box := text_layout(raw, notes, w, img.get_height())
	var top: int = box["top"]
	var box_h: int = box["box_h"]
	img.fill_rect(Rect2i(7, top, w - 14, box_h), PC.C_OUTLINE)
	img.fill_rect(Rect2i(8, top + 1, w - 16, box_h - 2), PC.C_PARCH)
	img.fill_rect(Rect2i(8, top + box_h - 2, w - 16, 1), PC.C_PARCH_LO)
	img.fill_rect(Rect2i(w - 9, top + 1, 1, box_h - 2), PC.C_PARCH_LO)
	for dot: Vector2i in box["bullets"]:
		_text(img, dot.x, dot.y, "•", PC.C_INK, 1)
	for spot: Array in box["words"]:
		_draw_word(img, spot[0], spot[1], spot[2])
	return box["content_h"]


## Где что лежит в поле текста карты размера w x h (так же рисует и
## tools/pixel_cards.gd без пометок): {top, box_h, content_h, bullets:
## [Vector2i], words: [[x, y, слово]]}.
static func text_layout(raw: String, notes: Array, w: int, h: int) -> Dictionary:
	var text_h := h - 22 - TEXT_TOP
	var paras := layout(raw, notes, w)
	var fit := fit_box(paras, text_h)
	var gap: int = fit[0]
	var top: int = TEXT_TOP - int(fit[1])
	var box_h: int = text_h + int(fit[1])
	var content_h := block_height(paras, gap)
	var bullets: Array[Vector2i] = []
	var words: Array = []
	var y := top + 4 + (box_h - 8 - content_h) / 2
	for p: Dictionary in paras:
		for li in p["lines"].size():
			var x := 11 + (8 if p["bullet"] else 0)
			if p["bullet"] and li == 0:
				bullets.append(Vector2i(11, y))
			for word: String in p["lines"][li]:
				words.append([x, y, word])
				x += word_width(word) + 5
			y += PC.LINE_H
		y += gap
	return {"top": top, "box_h": box_h, "content_h": content_h, "bullets": bullets, "words": words}


## Ключевые слова на большой карте (для подсказок при наведении):
## [[Rect2i в пикселях лица, слово без знаков]].
static func keyword_spots(cid: String, notes: Array, w: int, h: int) -> Array:
	var out: Array = []
	var raw := String(CardLibrary.card_data(cid).get("ability_text", ""))
	for spot: Array in text_layout(raw, notes, w, h)["words"]:
		var word := String(spot[2])
		if word.begins_with(MARK_OK) or word.begins_with(MARK_NO) or not is_keyword(word):
			continue
		var bare := word.rstrip(".,:;")
		out.append([Rect2i(spot[0] - 1, spot[1] - 1, word_width(bare) + 2, 9), bare])
	return out


## [промежуток между абзацами, на сколько поднять поле над артом].
static func fit_box(paras: Array, text_h: int) -> Array:
	var room := text_h - 8
	if block_height(paras, PC.PARA_GAP) <= room:
		return [PC.PARA_GAP, 0]
	return [1, maxi(0, block_height(paras, 1) - room)]


## Разметка как PC.layout_text, только в абзацы сначала вставляются пометки.
static func layout(raw: String, notes: Array, w: int = PC.W) -> Array:
	var paras: Array[String] = []
	# Та же строка ресурсов, что в PC.layout_text ("• +1 Power", "+1 Power, +1 Influence").
	var resource_line := RegEx.create_from_string("^(• )?(\\+\\d+ (Power|Influence),? ?)+$")
	for line in raw.split("\n"):
		line = line.strip_edges()
		if line == "":
			continue
		if paras.is_empty():
			paras.append(line)
			continue
		var prev := paras[-1]
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
	var cleaned: Array[String] = []
	for p in paras:
		cleaned.append(clean(p))
	for note: Dictionary in notes:
		var phrase := String(note["phrase"])
		for i in cleaned.size():
			var at := cleaned[i].find(phrase)
			if at < 0:
				continue
			var end := at + phrase.length()
			# Знак препинания после фразы уходит за пометку: "CONTROL (3)."
			var tail := ""
			while end < cleaned[i].length() and ".,:;".contains(cleaned[i][end]):
				tail += cleaned[i][end]
				end += 1
			var mark := MARK_OK if note["ok"] else MARK_NO
			cleaned[i] = cleaned[i].substr(0, at + phrase.length()) + " " + mark + String(note["text"]) + tail \
				+ cleaned[i].substr(end)
			break
	var out: Array = []
	var room := w - 22
	for p in cleaned:
		var bullet := p.begins_with("•")
		if bullet:
			p = p.substr(1).strip_edges()
		var width := room - (8 if bullet else 0)
		var lines: Array = []
		var cur: Array = []
		var cur_w := 0
		for word in p.split(" ", false):
			var ww := word_width(word)
			if cur.is_empty():
				cur = [word]
				cur_w = ww
			elif cur_w + 5 + ww <= width:
				cur.append(word)
				cur_w += 5 + ww
			else:
				lines.append(cur)
				cur = [word]
				cur_w = ww
		if not cur.is_empty():
			lines.append(cur)
		out.append({"bullet": bullet, "lines": lines})
	return out


static func block_height(paras: Array, gap: int = PC.PARA_GAP) -> int:
	var h := 0
	for p: Dictionary in paras:
		h += p["lines"].size() * PC.LINE_H + gap
	return h - gap - 2


static func clean(s: String) -> String:
	s = s.to_upper()
	for k: String in PC.CHAR_MAP:
		s = s.replace(k, PC.CHAR_MAP[k])
	return s


static func _bare(word: String) -> String:
	return word.trim_prefix(MARK_OK).trim_prefix(MARK_NO)


static func is_keyword(word: String) -> bool:
	return PC.KEYWORDS.has(word.rstrip(".,:;"))


static func word_width(word: String) -> int:
	var plain := _bare(word)
	var extra := plain.rstrip(".,:;").length() if is_keyword(plain) else 0
	return _width(plain, 1) + extra


static func _draw_word(img: Image, x: int, y: int, word: String) -> void:
	if word.begins_with(MARK_OK) or word.begins_with(MARK_NO):
		_text(img, x, y, _bare(word), OK_INK if word.begins_with(MARK_OK) else NO_INK, 1)
		return
	if not is_keyword(word):
		_text(img, x, y, word, PC.C_INK, 1)
		return
	# Ключевое слово — жирным: буква дважды, со сдвигом на пиксель.
	var bare := word.rstrip(".,:;")
	for i in bare.length():
		var g: Array = _glyph(bare[i])
		_rows(img, x + i * 7, y, g, PC.C_INK)
		_rows(img, x + i * 7 + 1, y, g, PC.C_INK)
	_text(img, x + bare.length() * 7, y, word.substr(bare.length()), PC.C_INK, 1)


## Новая цена в шапке большой карты: старую закрашиваем цветом рамки.
static func _draw_cost_full(img: Image, cost: int, printed: int) -> void:
	var w := img.get_width()
	var printed_w := _width(str(printed), 2)
	img.fill_rect(Rect2i(w - 7 - printed_w - 1, 5, printed_w + 4, 17), PC.C_FRAME)
	var s := str(cost)
	_text(img, w - 7 - _width(s, 2), 6, s, OK_LIGHT, 2, PC.C_OUTLINE)


static func _width(s: String, scale: int) -> int:
	return maxi(0, s.length() * (6 * scale - (scale - 1)) - 1)


static func _glyph(ch: String) -> Array:
	return PC.FONT.get(ch, PC.FONT[" "])


static func _rows(img: Image, x: int, y: int, rows: Array, c: Color, s: int = 1) -> void:
	for ry in rows.size():
		var row: String = rows[ry]
		for rx in row.length():
			if row[rx] == "1":
				img.fill_rect(Rect2i(x + rx * s, y + ry * s, s, s), c)


static func _text(img: Image, x: int, y: int, s: String, c: Color, scale: int, shadow := Color(0, 0, 0, 0)) -> void:
	for i in s.length():
		var g := _glyph(s[i])
		if shadow.a > 0:
			_rows(img, x + i * (6 * scale - (scale - 1)) + scale, y + scale, g, shadow, scale)
		_rows(img, x + i * (6 * scale - (scale - 1)), y, g, c, scale)
