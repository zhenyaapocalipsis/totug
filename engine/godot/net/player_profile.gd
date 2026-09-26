class_name PlayerProfile
extends RefCounted

## Профиль игрока: имя и герб. Герб рисуется прямо на фишке войска — это
## картинка 9x9 (как SchematicPainter.token), рисовать можно только внутри
## кружка; ободок остаётся тёмным, а незакрашенные пиксели заливаются цветом
## места (red/blue/...), чтобы чужие войска всё равно отличались по цвету.
## Закрасить кружок целиком нельзя: не меньше MIN_SEAT_PIXELS пикселей
## остаются цветом места (решение владельца, 2026-09-25).
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
## Сколько пикселей кружка (из 37) должны остаться цветом места.
const MIN_SEAT_PIXELS := 12
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


## Сколько всего пикселей можно красить (37 при фишке 9x9).
static func paintable_count() -> int:
	var n := 0
	for i in SIZE * SIZE:
		if paintable(i % SIZE, i / SIZE):
			n += 1
	return n


## Сколько пикселей можно закрасить, не нарушив MIN_SEAT_PIXELS.
static func max_painted() -> int:
	return paintable_count() - MIN_SEAT_PIXELS


static func painted_count(pixels: Array[Color]) -> int:
	var n := 0
	for i in mini(pixels.size(), SIZE * SIZE):
		if pixels[i].a > 0.5 and paintable(i % SIZE, i / SIZE):
			n += 1
	return n


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


## Герб из чужих рук (файл, сеть): неверный или закрашенный сильнее
## max_painted() — "", иначе пиксели вне кружка стёрты, прозрачность только
## 0 или 255.
static func clean_emblem(emblem: String) -> String:
	if emblem.length() != EMBLEM_LENGTH:
		return ""
	for ch in emblem:
		if not "0123456789abcdefABCDEF".contains(ch):
			return ""
	var bytes := emblem.hex_decode()
	var painted := 0
	for i in SIZE * SIZE:
		if bytes[i * 4 + 3] == 0 or not paintable(i % SIZE, i / SIZE):
			for k in 4:
				bytes[i * 4 + k] = 0
		else:
			bytes[i * 4 + 3] = 255
			painted += 1
	if painted > max_painted():
		return ""
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


## Файл профиля. `-- --profile=2` в строке запуска — отдельный профиль (и свой
## ключ рейтинга): так два окна на одном компьютере — два разных игрока.
static func path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			return "user://profile_%s.cfg" % clean_name(arg.get_slice("=", 1)).replace(" ", "_")
	return PATH


static func load_local() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path()) != OK:
		return {"name": "", "emblem": ""}
	return clean({"name": cfg.get_value("profile", "name", ""), "emblem": cfg.get_value("profile", "emblem", "")})


## Профиль уже создан — есть имя. Файл сам по себе не в счёт: ключ рейтинга
## (key()) записывается в него и без имени.
static func has_local() -> bool:
	return String(load_local()["name"]) != ""


## Имя и герб; ключ рейтинга и запомненный рейтинг в файле не трогаются.
static func save_local(profile: Dictionary) -> int:
	var p := clean(profile)
	var cfg := ConfigFile.new()
	cfg.load(path())
	cfg.set_value("profile", "name", p["name"])
	cfg.set_value("profile", "emblem", p["emblem"])
	return cfg.save(path())


## Секретный ключ игрока для рейтинга (RatingBook). Создаётся при первом
## обращении и больше не меняется; никому, кроме сервера, не показывается.
static func key() -> String:
	var cfg := ConfigFile.new()
	cfg.load(path())
	var k := String(cfg.get_value("rating", "key", ""))
	if k.length() < 32:
		var bytes := Crypto.new().generate_random_bytes(16)
		k = bytes.hex_encode()
		cfg.set_value("rating", "key", k)
		cfg.save(path())
	return k


## Рейтинг, который сервер сообщил в последний раз (-1 — ещё не играл онлайн).
## Только для показа в меню: настоящий хранится на сервере.
static func cached_rating() -> int:
	var cfg := ConfigFile.new()
	cfg.load(path())
	return int(cfg.get_value("rating", "value", -1))


static func cache_rating(value: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path())
	cfg.set_value("rating", "value", value)
	cfg.save(path())


static func name_of(seat: String) -> String:
	return String((seats.get(seat, {}) as Dictionary).get("name", ""))


static func emblem_of(seat: String) -> String:
	return String((seats.get(seat, {}) as Dictionary).get("emblem", ""))
