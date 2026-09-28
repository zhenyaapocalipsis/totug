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
##
## Рубашка карт (back) — рисунок BACK_SIZE x BACK_SIZE в центре рубашки
## (CardBack), закодирован так же, как герб. Пустая рубашка — "" (обычный
## ромб), чтобы не гонять по сети тысячи нулей.

const SIZE := 9
const BACK_SIZE := 32
const BACK_LENGTH := BACK_SIZE * BACK_SIZE * 8
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


## Пиксели рубашки (BACK_SIZE*BACK_SIZE цветов; прозрачный — Color(0,0,0,0)).
static func back_pixels(back: String) -> Array[Color]:
	var out: Array[Color] = []
	out.resize(BACK_SIZE * BACK_SIZE)
	out.fill(Color(0, 0, 0, 0))
	var clean := clean_back(back)
	if clean == "":
		return out
	var bytes := clean.hex_decode()
	for i in BACK_SIZE * BACK_SIZE:
		if bytes[i * 4 + 3] != 0:
			out[i] = Color8(bytes[i * 4], bytes[i * 4 + 1], bytes[i * 4 + 2])
	return out


## Рубашка строкой; ничего не нарисовано — "".
static func back_from_pixels(pixels: Array[Color]) -> String:
	var bytes := PackedByteArray()
	bytes.resize(BACK_SIZE * BACK_SIZE * 4)
	var painted := false
	for i in mini(pixels.size(), BACK_SIZE * BACK_SIZE):
		var c := pixels[i]
		if c.a > 0.5:
			bytes[i * 4] = c.r8
			bytes[i * 4 + 1] = c.g8
			bytes[i * 4 + 2] = c.b8
			bytes[i * 4 + 3] = 255
			painted = true
	return bytes.hex_encode() if painted else ""


## Рубашка из чужих рук (файл, сеть): неверная или пустая — "", иначе
## прозрачность только 0 или 255.
static func clean_back(back: String) -> String:
	if back.length() != BACK_LENGTH:
		return ""
	for ch in back:
		if not "0123456789abcdefABCDEF".contains(ch):
			return ""
	var bytes := back.hex_decode()
	var painted := false
	for i in BACK_SIZE * BACK_SIZE:
		if bytes[i * 4 + 3] == 0:
			for k in 4:
				bytes[i * 4 + k] = 0
		else:
			bytes[i * 4 + 3] = 255
			painted = true
	return bytes.hex_encode() if painted else ""


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
		"back": clean_back(String(profile.get("back", ""))),
	}


## Тесты подменяют файл профиля своим: сетевой тест проходит через настоящий
## NetSession, и тот записал бы рейтинг тестового сервера (1000) в профиль
## игрока (так и случилось 2026-09-26 — у владельца в меню «обнулился» рейтинг).
static var path_override := ""


## Файл профиля. `-- --profile=2` в строке запуска — отдельный профиль (и свой
## ключ рейтинга): так два окна на одном компьютере — два разных игрока.
static func path() -> String:
	if path_override != "":
		return path_override
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			return "user://profile_%s.cfg" % clean_name(arg.get_slice("=", 1)).replace(" ", "_")
	return PATH


static func load_local() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path()) != OK:
		return {"name": "", "emblem": "", "back": ""}
	return clean({"name": cfg.get_value("profile", "name", ""), "emblem": cfg.get_value("profile", "emblem", ""),
		"back": cfg.get_value("profile", "back", "")})


## Профиль уже создан — есть имя. Файл сам по себе не в счёт: ключ рейтинга
## (key()) записывается в него и без имени.
static func has_local() -> bool:
	return String(load_local()["name"]) != ""


## Имя и герб; ключ рейтинга, рубашка и запомненный рейтинг в файле не трогаются.
static func save_local(profile: Dictionary) -> int:
	var p := clean(profile)
	var cfg := ConfigFile.new()
	cfg.load(path())
	cfg.set_value("profile", "name", p["name"])
	cfg.set_value("profile", "emblem", p["emblem"])
	return cfg.save(path())


## Рубашку сохраняет свой экран (CardBackScreen), отдельно от имени и герба.
static func save_back(back: String) -> int:
	var cfg := ConfigFile.new()
	cfg.load(path())
	cfg.set_value("profile", "back", clean_back(back))
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


## Запомнить, что сервер сообщил: {rating, games, wins} (games/wins может не быть).
static func cache_stats(stats: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path())
	cfg.set_value("rating", "value", int(stats["rating"]))
	for field in ["games", "wins"]:
		if stats.has(field):
			cfg.set_value("rating", field, int(stats[field]))
	cfg.save(path())


## Для карточки игрока: {rating (-1 — ещё не играл онлайн), games, wins}.
static func cached_stats() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(path())
	return {"rating": int(cfg.get_value("rating", "value", -1)), "games": int(cfg.get_value("rating", "games", 0)),
		"wins": int(cfg.get_value("rating", "wins", 0))}


# --- звание по рейтингу ------------------------------------------------------

## Звания по рейтингу (2026-09-28): новичок с START=1000 — WARRIOR.
## [нижняя граница рейтинга, название, цвет камня].
const RANKS := [
	[0, "DRIDER", "8f563b"],
	[950, "WARRIOR", "9badb7"],
	[1050, "PRIESTESS", "639bff"],
	[1150, "MATRON", "f2d23c"],
	[1250, "TYRANT", "d77bba"],
]
const UNRANKED_COLOUR := "595652"
const RANK_ICON := 7


## Номер звания (0..RANKS.size()-1); -1 — рейтинга ещё нет.
static func rank_index(rating: int) -> int:
	if rating < 0:
		return -1
	var i := 0
	for n in RANKS.size():
		if rating >= int(RANKS[n][0]):
			i = n
	return i


static func rank_title(rating: int) -> String:
	var i := rank_index(rating)
	return "UNRANKED" if i < 0 else String(RANKS[i][1])


static func rank_colour(rating: int) -> Color:
	var i := rank_index(rating)
	return Color(UNRANKED_COLOUR if i < 0 else String(RANKS[i][2]))


## Значок звания: гранёный камень-ромб 7x7 цвета звания.
static func rank_icon(rating: int) -> Image:
	var colour := rank_colour(rating)
	var img := Image.create(RANK_ICON, RANK_ICON, false, Image.FORMAT_RGBA8)
	var c := RANK_ICON / 2
	for y in RANK_ICON:
		for x in RANK_ICON:
			var d := absi(x - c) + absi(y - c)
			if d > c:
				continue
			var px := colour
			if d == c:
				px = colour.darkened(0.55)
			elif x < c and y <= c or (x == c and y < c):
				px = colour.lightened(0.35)
			img.set_pixel(x, y, px)
	img.set_pixel(c - 1, c - 1, Color.WHITE)
	return img


# --- история онлайн-партий -----------------------------------------------------

const HISTORY_MAX := 10


## Последние партии, новые первыми. Хранится у игрока (в файле профиля).
static func history() -> Array:
	var cfg := ConfigFile.new()
	cfg.load(path())
	var list = cfg.get_value("history", "games", [])
	return list if list is Array else []


static func add_history(entry: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path())
	var list := history()
	list.push_front(entry)
	cfg.set_value("history", "games", list.slice(0, HISTORY_MAX))
	cfg.save(path())


## Строка истории из итога партии (NetSession._rating): result — место ->
## {rating, delta, vp, won}, profiles — место -> {name, emblem}.
## Место: победитель первый; иначе 1 + сколько игроков победили или набрали больше.
static func history_entry(own_seat: String, result: Dictionary, profiles: Dictionary) -> Dictionary:
	var mine: Dictionary = result[own_seat]
	var players := []
	var place := 1
	for pid: String in result:
		var r: Dictionary = result[pid]
		var p: Dictionary = profiles.get(pid, {})
		players.append({"seat": pid, "name": String(p.get("name", "")), "emblem": String(p.get("emblem", "")),
			"vp": int(r.get("vp", 0)), "won": bool(r.get("won", false))})
		if pid != own_seat and not bool(mine.get("won", false)) \
				and (bool(r.get("won", false)) or int(r.get("vp", 0)) > int(mine.get("vp", 0))):
			place += 1
	players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["won"] and not b["won"] or (a["won"] == b["won"] and a["vp"] > b["vp"]))
	return {"time": int(Time.get_unix_time_from_system()), "seat": own_seat, "place": place,
		"vp": int(mine.get("vp", 0)), "won": bool(mine.get("won", false)), "rating": int(mine["rating"]),
		"delta": int(mine.get("delta", 0)), "players": players}


static func name_of(seat: String) -> String:
	return String((seats.get(seat, {}) as Dictionary).get("name", ""))


static func emblem_of(seat: String) -> String:
	return String((seats.get(seat, {}) as Dictionary).get("emblem", ""))


static func back_of(seat: String) -> String:
	return String((seats.get(seat, {}) as Dictionary).get("back", ""))
