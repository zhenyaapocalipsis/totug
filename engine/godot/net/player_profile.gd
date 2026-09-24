class_name PlayerProfile
extends RefCounted

## Профиль игрока: имя и герб. Герб рисуется прямо на фишке войска — это
## картинка 9x9 (как SchematicPainter.token), рисовать можно только внутри
## ободка. Ободок всегда цвета места (red/blue/...) и не меняется — даже
## целиком закрашенная фишка показывает, чьё это войско; незакрашенные пиксели
## тоже остаются цветом места.
##
## Профиль хранится у игрока (user://profile.cfg), в сетевой игре уходит в
## комнату (NetSession._profile_up) и раздаётся всем вместе с лобби.
##
## Герб передаётся строкой: 81 пиксель по 4 байта RGBA в шестнадцатеричном
## виде (648 знаков), построчно сверху вниз. Прозрачный пиксель — 00000000.

const SIZE := 9
const RADIUS := 4
const NAME_MAX := 12
const EMBLEM_LENGTH := SIZE * SIZE * 8
const PATH := "user://profile.cfg"
## Имя рисуется пиксельным шрифтом: только знаки, которые в нём есть.
const NAME_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 -_.'"

## Профили за столом: цвет места -> {name, emblem}. Их читают экраны
## (EventLogPanel.player_name, фишки на доске); ставит game_scene/лобби.
static var seats: Dictionary = {}


## Можно ли красить пиксель: он внутри цветного кружка фишки (без ободка).
## Та же формула круга, что у SchematicPainter.disc с радиусом RADIUS - 1.
static func paintable(x: int, y: int) -> bool:
	var r := RADIUS - 1
	var dx := x - RADIUS
	var dy := y - RADIUS
	return dx * dx + dy * dy <= r * r + r


static func blank_emblem() -> String:
	return "0".repeat(EMBLEM_LENGTH)


## Пиксели герба (SIZE*SIZE цветов; прозрачный — Color(0,0,0,0)).
static func emblem_pixels(emblem: String) -> Array[Color]:
	var out: Array[Color] = []
	out.resize(SIZE * SIZE)
	out.fill(Color(0, 0, 0, 0))
	var clean := clean_emblem(emblem)
	if clean == "":
		return out
	var bytes := clean.hex_decode()
	for i in SIZE * SIZE:
		if bytes[i * 4 + 3] != 0:
			out[i] = Color8(bytes[i * 4], bytes[i * 4 + 1], bytes[i * 4 + 2])
	return out


static func emblem_from_pixels(pixels: Array[Color]) -> String:
	var bytes := PackedByteArray()
	bytes.resize(SIZE * SIZE * 4)
	for i in mini(pixels.size(), SIZE * SIZE):
		var c := pixels[i]
		if c.a > 0.5 and paintable(i % SIZE, i / SIZE):
			bytes[i * 4] = c.r8
			bytes[i * 4 + 1] = c.g8
			bytes[i * 4 + 2] = c.b8
			bytes[i * 4 + 3] = 255
	return bytes.hex_encode()


static func is_blank(emblem: String) -> bool:
	return clean_emblem(emblem) == "" or clean_emblem(emblem) == blank_emblem()


## Герб из чужих рук (файл, сеть): неверный — "", иначе пиксели вне кружка
## стёрты, прозрачность только 0 или 255.
static func clean_emblem(emblem: String) -> String:
	if emblem.length() != EMBLEM_LENGTH:
		return ""
	for ch in emblem:
		if not "0123456789abcdefABCDEF".contains(ch):
			return ""
	var bytes := emblem.hex_decode()
	for i in SIZE * SIZE:
		if bytes[i * 4 + 3] == 0 or not paintable(i % SIZE, i / SIZE):
			for k in 4:
				bytes[i * 4 + k] = 0
		else:
			bytes[i * 4 + 3] = 255
	return bytes.hex_encode()


static func clean_name(text: String) -> String:
	var out := ""
	for ch in text.strip_edges():
		if NAME_CHARS.contains(ch) and not (ch == " " and out.ends_with(" ")):
			out += ch
	return out.strip_edges().left(NAME_MAX).strip_edges()


static func clean(profile: Dictionary) -> Dictionary:
	return {
		"name": clean_name(String(profile.get("name", ""))),
		"emblem": clean_emblem(String(profile.get("emblem", ""))),
	}


static func load_local() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return {"name": "", "emblem": ""}
	return clean({"name": cfg.get_value("profile", "name", ""), "emblem": cfg.get_value("profile", "emblem", "")})


static func save_local(profile: Dictionary) -> int:
	var p := clean(profile)
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "name", p["name"])
	cfg.set_value("profile", "emblem", p["emblem"])
	return cfg.save(PATH)


static func name_of(seat: String) -> String:
	return String((seats.get(seat, {}) as Dictionary).get("name", ""))


static func emblem_of(seat: String) -> String:
	return String((seats.get(seat, {}) as Dictionary).get("emblem", ""))
