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
const KEYWORDS := ["DEVOUR", "SUPPLANT", "DEPLOY", "ASSASSINATE", "PLACE", "RETURN", "PROMOTE", "BRIBE", "STEAL",
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
	# Piltover & Zaun (New Era)
	"Deploy 2 troops": "Patrol",
	"Return 2 of your troops -> Draw a card": "Shift Change",
	"Place a spy (full site: deploy 2 troops)": "Chem Deal",
	"Return a spy": "Sweep the Streets",
	"Draw a card": "Insight",
	"Assassinate a troop anywhere": "Long Shot",
	"+2 Influence, at end of turn promote a card you played": "Hextech Patent",
	"Assassinate a troop and return a spy": "Mercury Hammer",
	"This turn you may choose all options instead of one": "Grand Design",
	"This turn Focus effects trigger an additional time": "Upgrade!!!",
	"Focus cards from your top 6 into your hand, discard the rest": "Howling Gale",
	"Recruit a market card for free, gain VP equal to its deck VP": "Zephyr",
	"All of them": "Everything",  # ChooseEffect.ALL_LABEL (Homunculus)
	# Siege
	"Place a spy, then draw a card": "Lolth's Gaze",
	"Return one of your spies -> Put a played card or a card from your discard pile on top of your deck": "Move Forward",
	"Return one of your spies -> +2 Influence, you may promote a market card for its cost": "Red Throne",
	"+1 Power, +2 Influence": "Siege Fodder",
	"Gain 1 VP": "Breach",
	"+1 Power": "Sharpen Steel",
	"Move an enemy spy to another site": "False Trail",
	"Keep your Influence": "Hold Fire",
	"Convert 1 Influence to Power": "Load One Bolt",
	"Convert 2 Influence to Power": "Load Two Bolts",
	"Convert 3 Influence to Power": "Full Volley",
	# Mercenaries
	"Steal 1 VP": "Ambush",
	"Bribe -> +3 Power": "Hired Thugs",
	"Bribe -> Supplant a white troop": "Highest Bidder",
	"Discard a card -> Gain 1 VP and draw a card": "Fair Trade",
	"Bribe -> Place a spy and draw 2 cards": "Back Room",
	"Return one of your spies -> Steal 3 VP": "Cut Purse",
	"Return one of your spies -> Steal that site's control marker until your next turn": "Borrowed Banner",
	"Return one of your spies -> Swap this card with a card in a rival's discard pile": "Infiltrator",
	"Move one of your troops and gain 1 Influence": "Slaver's Round",
	"Bribe -> Swap 2 troops anywhere on the board": "Switched Chains",
	# Avernus (New Era Noxus)
	"Devour a card in your hand": "Cull the Weak",
	"Devour a card in your hand or your discard pile": "Blood Tithe",
	"Devour a card in the market": "Seize the Spoils",
	"Place a spy (full site: you may devour a card in your hand or discard pile)": "Crimson Rite",
	"+1 Power, devour a card in the market, your hand or discard pile": "Thorned Rose",
	"Place a spy, devour a card in the market (its replacement costs 3 less)": "Black Rose",
	"Return one of your spies -> +4 Influence": "Whispered Favour",
	"Place a spy, you may assassinate up to 3 troops there (then no deploying there this turn)": "Death Lotus",
	"Move up to 2 of your troops and draw a card": "Shunpo",
	"Devour half the market deck (if it is already empty, you win)": "Iron Dominion",
	"Play up to 2 cards from the devoured pile": "Realm of Death",
	"Each time you trigger Might this turn, supplant a troop": "Lord of Ruin",
	"Place 2 spies and draw a card": "Ravens Above",
	"Return any number of your spies -> +1 Influence and supplant a troop at each of those sites": "Grand Strategy",
	"Devour a card in your hand -> draw cards equal to its inner circle VP": "Daredevil",
	"Devour a card in the market -> gain VP equal to its deck VP": "Showstopper",
	"Assassinate 2 troops at a site": "Wild Rush",
	"Blade Fragments and Half-Dragons from your top 5 cards into your hand, discard the rest": "Broken Wings",
	# Icewind Dale (New Era Freljord)
	"Place a spy and scry 2 cards": "Bone Omens",
	"Return one of your spies -> each opponent discards down to 4 cards, scry 4 cards": "Rattling Bones",
	"Place a spy, each opponent with 3+ cards in hand discards a card, +1 Influence": "Prophet's Call",
	"Return one of your spies -> each opponent with 4+ cards in hand discards a card, +2 Power": "Spirit Howl",
	"Place a spy (another player's troop there: trigger the Frostbite of another card you played)": "Snare Line",
	"Deploy 2 troops, draw a card, then discard a card": "Pack Hunt",
	"Return any number of your spies -> +2 Power and draw a card for each": "Frozen Tomb",
	"Each opponent discards down to 3 cards": "Glacial Prison",
	"If each opponent has 4 or fewer cards in hand, supplant 2 troops": "Winter's Wrath",
	"Play a card from your inner circle as if from your hand (it stays there)": "Undying Rage",
	"Choose a site with your troop: move other troops there to empty spaces next to it": "Blink Away",
	"Move up to 3 of your troops: +1 Power for each one moved next to another player's troop": "Phase Pounce",
	# Calimshan (New Era Shurima)
	"Trigger the Devotion of another card you played this turn": "Petrifying Gaze",
	"Return a card from your inner circle to your hand, draw a card": "Stone Memory",
	"Place a spy, scry 3": "Sand Veil",
	"Return one of your spies -> look at the top 3 cards of your deck, put 1 in your hand, discard the rest": "Desert Omens",
	"Place a spy (site full: +3 Power)": "Coiled Strike",
	"Return one of your spies -> supplant a troop at that site, +2 Power": "Venom Bite",
	"Place a spy (site full: at end of turn, promote another card played this turn)": "Silent Prowl",
	"Return one of your spies -> supplant a troop at that site": "Ambush Leap",
	"Devour a card in your hand -> draw a card": "Swallow Whole",
	"Move up to 3 of your troops": "Shifting Sands",
	"Move an enemy troop": "Rock Slide",
	"Recruit a card that costs 5 or less for free": "Dust Bargain",
	"Recruit 2 cards that cost 3 or less for free": "Lost Friends",
	"Your opponent names a card": "Open Challenge",
	"Nobody names a card": "Stand Alone",
	"The player to your left names a card": "Left Flank",
	"The player to your right names a card": "Right Flank",
	"Both of them name a card": "Rally Cry",
	# Kara-Tur (New Era Ionia)
	"Play this card now": "Strike Now",
	"Retain it: keep it for your next hand": "Bide Your Time",
	"Place a spy (site full: +2 Power)": "Spore Cloud",
	"Deploy a troop for each different Aspect you played this turn": "Many Paths",
	"Double your Power": "Defiant Dance",
	"Return all enemy spies from a site": "Blade Surge",
	"Become Ambition: +1 Influence per Ambition card played": "Mask of Ambition",
	"Become Conquest: +1 Influence per Conquest card played": "Mask of Conquest",
	"Become Guile: +1 Influence per Guile card played": "Mask of Guile",
	"Become Malice: +1 Influence per Malice card played": "Mask of Malice",
	"Become Ambition: +1 Power per Ambition card played": "Tide of Ambition",
	"Become Conquest: +1 Power per Conquest card played": "Tide of Conquest",
	"Become Guile: +1 Power per Guile card played": "Tide of Guile",
	"Become Malice: +1 Power per Malice card played": "Tide of Malice",
	"Place a spy (site full: you may Retain the top card of your deck)": "Hidden Reserve",
	"Return two of your spies -> Retain a card you played this turn": "Long Game",
	"Place a spy (another player's troop there: you may Retain the top card of your deck)": "Shrill Warning",
	"This turn, cards cost 1 less to recruit": "Charm",
	"This turn, whenever you recruit a card, you may assassinate a troop": "Spirit Rush",
	"Place a spy -> assassinate a troop at that site": "Death Mark",
	# FEYWILD (New Era Bandle City)
	"No Glamour": "Plain Trick",
	"Return one of your spies -> assassinate up to 3 troops at that site": "Thundering Shuriken",
	"This turn, whenever you assassinate or supplant a troop, gain 1 VP": "Bounty Hunter",
	"This turn, whenever you assassinate a troop, you may supplant it instead": "Buster Shot",
	"This turn, you may put cards you recruit on top of your deck": "Book Mark",
	"Gain 1 VP for each card you recruit this turn": "Final Chapter",
	"Place a spy and deploy 4 troops": "Valkyrie",
	"Return one of your spies -> supplant a troop at that site and gain 1 VP": "Special Delivery",
	"Draw a card, then discard a card and gain 1 VP": "Trick Shot",
	"Glamour (1 VP): +2 Influence": "Glamour: Gilded Tea",
	"Gain a card that costs up to 3": "Pot of Gold",
	"Glamour (1 VP): +3 Influence instead": "Glamour: Golden Coins",
	"Glamour (1 VP): Gain a card that costs up to 5 instead": "Glamour: Rainbow's End",
	"Place a spy (site full: gain 1 VP)": "Crowded Canvas",
	"Return one of your spies -> +2 Influence and draw a card": "Fresh Paint",
	"Place a spy (another player's troop there: gain 1 VP)": "Slippery Grease",
	"Return one of your spies -> take 2 VP from each other player with a troop at that site": "Sticky Fingers",
	"Place a spy (site full: you may devour a card in your hand or discard pile to gain 1 VP)": "Arena Bet",
	"Return one of your spies -> devour 2 cards in the market, their replacements cost 2 less this turn": "Rigged Market",
	"Glamour (1 VP): Deploy 3 troops": "Glamour: Shadow Swarm",
	"Glamour (1 VP): Return a troop or spy": "Glamour: Night Snatch",
	"Glamour (1 VP): +2 Power": "Glamour: Dread Claws",
	"Glamour (1 VP): Supplant any troop instead": "Glamour: Choking Cloud",
	"Glamour (1 VP): Supplant a white troop anywhere instead": "Glamour: Drifting Smoke",
	"Glamour (1 VP): At end of turn, promote an Obedience card you played this turn": "Glamour: Mega Inferno",
	"Glamour (1 VP): At end of turn, promote another card you played this turn": "Glamour: Rally the Gang",
	"Place a spy -> move one of your troops to that site": "Open Portal",
	"Return one of your spies -> move up to one enemy troop at that site and one of your troops": "Swap Places",
	# FAR REALM (New Era Void)
	"Supplant a troop anywhere on the board": "Killer Instinct",
	"+1 Power for each card in your hand": "Icathian Rain",
	"Draw 2 cards, then discard a card": "Supercharge",
	"Assassinate 2 troops": "Void Seeker",
	"Return up to 2 troops or spies": "Call of the Void",
	"Supplant 2 white troops": "Malefic Visions",
	"Draw a card for every 2 sites under your total control": "Tremor Sense",
	"Supplant a troop and deploy 2 troops": "Unburrow",
	"Move up to 2 troops or spies": "Tunnel",
	"Move one of your spies": "Shift",
	"Move a spy": "Shift",
	"Done": "Hold",
	"+1 Influence for every 2 sites you control": "Lavender Tithe",
	"At end of turn, promote another card you played this turn": "Endless Banquet",
	"Look at the top 5 cards of your deck: up to 2 that cost 2 or less to your hand": "Hive Call",
	"+1 Power for every 2 sites you control": "Sand Swallow",
	"Return a troop": "Bedrock Breaker",
	"Place a spy (site full: deploy 2 troops)": "Brood Signal",
	"Return one of your spies -> supplant a white troop at that site": "Queen's Call",
	"Place a spy at a site": "Watching Eye",
	"Place a spy on a market card": "Gaze of the Abyss",
	"Gain a market card with the same name as a card you played this turn": "Echo of the Void",
	# CHULT (New Era Ixtal)
	"Copy the previous card you played": "Mimicry",
	"Copy a market card": "Stolen Guise",
	"Explore for a card that costs 3 or less": "Small Finds",
	"Explore for a card that costs 6 or more": "Grand Prize",
	"Deploy 3 troops (next to another player's troop: Explore for \"Deploy\")": "Trailblazer",
	"Explore for an odd cost card": "Odd Trail",
	"Explore for an even cost card": "Even Trail",
	"Put a card from your hand on top of your deck: supplant a troop and deploy a troop": "Axiom Strike",
	"You may shuffle your discard pile into your deck, then Scry 3": "Inner Eye",
	"Place a spy (site full: +1 Power and +1 Influence)": "Whispered Secret",
	"Return one of your spies, draw 2 cards, put a card from your hand on top of your deck": "Keeper's Vault",
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
