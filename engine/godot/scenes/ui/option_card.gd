class_name OptionCard
extends Control

## Вариант "Choose one" в виде полноформатной карты — того же размера и той же
## разметки, что обычная карта (tools/pixel_cards.gd): название варианта в
## шапке, арт сыгранной карты, в поле текста — только этот вариант. Цены,
## аспекта, фракции и VP нет (решения владельца, 2026-09-24): игрок выбирает
## не карту, а действие, и арт лишь напоминает, чья это способность.
##
## Лицо собирается из пиксельной карты: шапка, поле текста и подвал
## перерисовываются, арт и рамка остаются как есть. Рисуется в 1x.

signal pressed

const W := 176
const H := 254
const TEXT_TOP := 139
const TEXT_H := 93
const LINE_H := 9

const C_OUTLINE := Color("0a0612")
const C_FRAME := Color("24153f")
const C_LIGHT := Color("f0e6d2")
const C_PARCH := Color("e6d9bc")
const C_PARCH_LO := Color("bfae88")
const C_INK := Color("2a1a30")
const KEYWORDS := ["DEVOUR", "SUPPLANT", "DEPLOY", "ASSASSINATE", "PLACE", "RETURN", "PROMOTE",
	"RECRUIT", "RECRUITS", "MOVE", "FOCUS"]

## Названия вариантов — по тексту варианта (ChooseEffect.labels), одинаковые
## действия у разных карт называются одинаково. Нет в таблице — шапка пустая.
const NAMES := {
	"+1 Influence": "Pull Rank",
	"+2 Influence": "Silver Tongue",
	"+3 Influence": "Honeyed Words",
	"+2 Power": "Iron Resolve",
	"Place a spy": "Shadow Agent",
	"Place 2 spies": "Web of Eyes",
	"Deploy a troop": "Muster",
	"Deploy 3 troops": "Legion",
	"Deploy three troops": "Legion",
	"Deploy 4 troops": "War Host",
	"Assassinate a troop": "Poisoned Blade",
	"Assassinate a white troop": "Cull the Weak",
	"Assassinate 2 white troops": "Purge",
	"Supplant a troop": "Usurper",
	"Supplant a white troop anywhere on the board": "Overthrow",
	"At end of turn, promote another card played this turn": "Patronage",
	"Promote another card in your hand": "Draft Orders",
	"Return one of your spies -> Supplant a troop at that spy's site": "Inside Job",
	"Return one of your spies -> assassinate a troop at that spy's site": "Hidden Blade",
	"Return one of your spies -> +3 Influence": "Spy's Report",
	"Return one of your spies -> +4 Power": "Rally Signal",
	"Return one of your spies -> +5 Power": "Call to Arms",
	"Return one of your spies -> +2 Power +2 Influence": "Double Agent",
	"Return one of your spies -> Draw 2 cards": "Whispers",
	"Return one of your spies -> Draw 3 cards": "Secrets Sold",
	"Return one of your spies -> Deploy 3 troops": "Open the Gates",
	"Return one of your spies -> Draw a card; each opponent with more than 3 cards discards a card": "Sow Dread",
	"Return one of your spies -> treat the top devoured card as if it was in the market this turn": "Grave Robber",
	"Return one of your spies -> Recruit up to 2 cards that cost 3 or less": "Recruiters",
	"Return any number of your spies -> supplant a troop at each of those sites": "Night of Knives",
	"Place a spy, then supplant a troop at that site": "Infiltrate",
	"Return one of your spies -> supplant a troop at that spy's site, then gain VP per site controlled": "Coup",
	"Draw a card, then choose an opponent with more than 3 cards to discard a card": "Mind Games",
	"Return up to two troops or spies": "Banishment",
	"Draw a card for each spy you have on the board": "Spymaster",
	"Devour this card -> at end of turn, promote up to 2 other cards played this turn": "Final Gift",
	"Devour this card -> assassinate up to three white troops at a single site": "Massacre",
	"Devour a card in your hand -> Supplant a troop": "Sacrifice",
	"Promote this card, or a card from your hand or discard pile": "Ascension",
	"Take a white troop from any trophy hall and deploy it": "Turncoats",
	"Promote a card from your discard pile, then gain VP per inner circle card": "Exaltation",
	# Celestial Order (New Era)
	"+3 Power": "Charge",
	"Look at the top 6 cards: House Guards into your hand": "Call the Guard",
	"House Guard or Priestess into your hand, +4 Power": "Rally the Faithful",
	"Promote up to 2 Obedience cards from hand or discard": "Knighting",
	"Promote a card in your hand": "Anointing",
	"Move one of your troops": "Redeploy",
	"Deploy 2 troops and draw a card": "Vanguard",
	"Return 2 of your troops -> Supplant a white troop anywhere": "Holy Strike",
	"Draw a card per House Guard played this turn": "Muster Roll",
	"Place a spy (full site: draw a card)": "Watchful Eye",
	"Return one of your spies -> Draw a card, +3 Power": "Revelation",
	"Promote a card in your hand, deploy troops equal to its inner circle VP": "Reinforcements",
	"Supplant a white troop": "Claim the Wilds",
	"+1 Influence per spy you have on the board": "Network",
	"Return a troop or spy": "Dismissal",
	"Put a House Guard into your hand": "Squire",
	"Place a spy and return up to 2 troops at that site": "Binding Chains",
	"Return one of your spies -> return up to 3 troops there, then deploy up to 3 troops there": "Purge and Hold",
	"Put your deck into your discard pile, then promote a card from it": "Royal Decree",
	"Assassinate up to 4 troops at one site": "Dragonfire",
	"Return troops -> supplant that many at one site": "Dragon's Due",
	"Return another player's troop or spy": "Exile",
	"+2 Influence, House Guards cost 1 less this turn": "Requisition",
	# Shadow Isles (New Era)
	"Place a spy (full site: each opponent recruits an Insane Outcast)": "Haunting",
	"Return one of your spies -> Insane Outcasts from your top 5 cards into your hand, draw a card": "Soul Harvest",
	"Deploy 3 troops, each opponent recruits an Insane Outcast": "Ride of Dread",
	"Insane Outcasts from your top 6 cards into your hand": "Gather the Lost",
	"Devour a card in your hand, then draw a card": "Rend",
	"Scry 1, then draw a card per Insane Outcast played this turn": "Grim Harvest",
	"Deploy 3 troops, Insane Outcasts from your top 6 cards into your hand": "Deathless March",
	"Place a spy and draw a card": "Restless Watch",
	"Return any number of your spies -> assassinate a troop for each": "Poltergeist Fury",
	"Deploy 3 troops (next to another player's troop: each opponent recruits an Insane Outcast)": "Cursed Legion",
	"Move a troop": "March",
	"Place a spy, then scry 3": "Far Sight",
	"Return one of your spies -> +3 Power": "Spirit Lash",
	"An opponent splits your top 5 cards into two piles, keep one": "Gloom Choice",
	"Supplant a troop anywhere": "Shadow Step",
	"+4 Power": "Grave Strength",
	"Recruit one of the top 3 devoured cards for free": "Grave Digging",
}

var _tex: ImageTexture


func _init(card_id: String, text: String, seat: String = "") -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_tex = ImageTexture.create_from_image(render(card_id, text, CardView.art_of(seat, card_id)))
	# Образ владельца лежит и на карте с вариантами (решение владельца, 2026-10-06).
	var skin := CardView.skin_of(seat, card_id)
	if skin != "":
		var mat := ShaderMaterial.new()
		CardView.configure_skin(mat, SkinCollection.SHADER_INDEX[skin], false)
		material = mat


static func option_name(text: String) -> String:
	return String(NAMES.get(text, ""))


static func render(card_id: String, text: String, art: String = "") -> Image:
	var img: Image
	var face: Texture2D = CardView.pixel_texture(card_id, art)
	if face != null:
		img = face.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
	else:
		img = Image.create(W, H, false, Image.FORMAT_RGBA8)
		img.fill(C_OUTLINE)
		img.fill_rect(Rect2i(2, 2, W - 4, H - 4), C_FRAME)

	# шапка и строка аспекта — фон рамки, затем название варианта
	img.fill_rect(Rect2i(2, 2, W - 4, 31), C_FRAME)
	var name := option_name(text).to_upper()
	var room := W - 14
	if _text_width(name, 2) <= room:
		_text(img, (W - _text_width(name, 2)) / 2, 11, name, C_LIGHT, 2)
	else:
		var lines := _wrap_plain(name, room)
		var y := 13 if lines.size() == 1 else 8
		for line in lines.slice(0, 2):
			_text(img, (W - _text_width(line, 1)) / 2, y, line, C_LIGHT, 1)
			y += 10

	# поле текста
	img.fill_rect(Rect2i(7, TEXT_TOP, W - 14, TEXT_H), C_OUTLINE)
	img.fill_rect(Rect2i(8, TEXT_TOP + 1, W - 16, TEXT_H - 2), C_PARCH)
	img.fill_rect(Rect2i(8, TEXT_TOP + TEXT_H - 2, W - 16, 1), C_PARCH_LO)
	img.fill_rect(Rect2i(W - 9, TEXT_TOP + 1, 1, TEXT_H - 2), C_PARCH_LO)
	var lines := _wrap(text)
	var y := TEXT_TOP + (TEXT_H - (lines.size() * LINE_H - 2)) / 2
	for line: Array in lines:
		var line_w := -5
		for word: String in line:
			line_w += _word_width(word) + 5
		var x := (W - line_w) / 2
		for word: String in line:
			_draw_word(img, x, y, word)
			x += _word_width(word) + 5
		y += LINE_H

	# подвал без фракции и VP
	img.fill_rect(Rect2i(2, TEXT_TOP + TEXT_H + 1, W - 4, H - TEXT_TOP - TEXT_H - 3), C_FRAME)
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


static func _wrap_plain(s: String, max_px: int) -> Array[String]:
	var out: Array[String] = []
	var cur := ""
	for word in s.split(" "):
		var t := word if cur == "" else cur + " " + word
		if _text_width(t, 1) > max_px and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = t
	out.append(cur)
	return out


## Шаг букв как в генераторе карт: при 2x буквы стоят плотнее (11 px, не 12).
static func _text_width(s: String, scale: int) -> int:
	return maxi(0, s.length() * (6 * scale - (scale - 1)) - 1)


## Текст с тенью (как название на обычной карте).
static func _text(img: Image, x: int, y: int, s: String, c: Color, scale: int) -> void:
	var step := 6 * scale - (scale - 1)
	for i in s.length():
		_glyph(img, x + i * step + scale, y + scale, s[i], C_OUTLINE, scale)
		_glyph(img, x + i * step, y, s[i], c, scale)


static func _glyph(img: Image, x: int, y: int, ch: String, c: Color, scale: int) -> void:
	var rows: Array = PixelFont.glyph(ch)
	for ry in rows.size():
		var row: String = rows[ry]
		for rx in row.length():
			if row[rx] == "1":
				img.fill_rect(Rect2i(x + rx * scale, y + ry * scale, scale, scale), c)


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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit()
		accept_event()
