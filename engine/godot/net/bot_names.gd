class_name BotNames
extends RefCounted

## Имена и гербы ботов по цвету места (решение владельца, 2026-10-12): за столом
## бот — не "Green", а демон со своим гербом на фишках войск.
##
## Original 9x9 bot art is centred on the current PlayerProfile canvas.
## знак на пиксель: "." и пробел — не закрашено (виден цвет игрока), остальные —
## цвета из INK. Закрашено не больше PlayerProfile.max_painted(), как у людей.

const INK := {
	"K": Color8(18, 14, 22),     # тёмный контур
	"Y": Color8(244, 202, 64),   # золото
	"W": Color8(232, 222, 196),  # кость
	"R": Color8(204, 28, 40),    # кровь
	"G": Color8(104, 230, 92),   # яд
}

const BOTS := {
	# Азмодан, Владыка Греха: костяная голова с золотыми рогами и красными глазами.
	"red": {"name": "Azmodan", "art": [
		"         ",
		"   Y.Y   ",
		"  Y...Y  ",
		"  YWWWY  ",
		"  WRWRW  ",
		"  WWWWW  ",
		"   WKW   ",
		"         ",
		"         ",
	]},
	# Белиал, Владыка Лжи: золотой змей буквой S с красным языком.
	"green": {"name": "Belial", "art": [
		"         ",
		"   YYY   ",
		"  Y...R  ",
		"  Y..... ",
		"   YYY   ",
		"      Y  ",
		"      Y  ",
		"   YYY   ",
		"         ",
	]},
	# Андариэль, Дева Страданий: капля яда с бликом.
	"blue": {"name": "Andariel", "art": [
		"         ",
		"    G    ",
		"   GGG   ",
		"  GWGGG  ",
		"  GWGGG  ",
		"  GGGGG  ",
		"   GGG   ",
		"         ",
		"         ",
	]},
	# Дуриэль, Владыка Боли: личинка — костяная морда, красные глаза, зубы.
	"purple": {"name": "Duriel", "art": [
		"         ",
		"         ",
		"   WWW   ",
		"  WRWRW  ",
		"  WKKKW  ",
		"  KWKWK  ",
		"   KKK   ",
		"         ",
		"         ",
	]},
}


## Профиль бота за столом ({name, emblem}, как у PlayerProfile.seats);
## {} — у этого цвета бота нет.
static func profile(seat: String) -> Dictionary:
	if not BOTS.has(seat):
		return {}
	return {"name": String(BOTS[seat]["name"]), "emblem": emblem(seat)}


## Centre the original 9x9 bot art on the current troop canvas.
static func emblem(seat: String) -> String:
	var pixels: Array[Color] = []
	pixels.resize(PlayerProfile.SIZE * PlayerProfile.SIZE)
	pixels.fill(Color(0, 0, 0, 0))
	var offset := (PlayerProfile.SIZE-9)/2
	var art: Array = BOTS[seat]["art"]
	for y in mini(art.size(), PlayerProfile.SIZE):
		var row := String(art[y])
		for x in mini(row.length(), PlayerProfile.SIZE):
			if INK.has(row[x]):
				pixels[(y+offset) * PlayerProfile.SIZE + x+offset] = INK[row[x]]
	return PlayerProfile.emblem_from_pixels(pixels)
