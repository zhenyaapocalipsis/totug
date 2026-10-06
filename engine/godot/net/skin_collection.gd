class_name SkinCollection
extends RefCounted

## Коллекция косметики (решение владельца, 2026-09-30), на игру не влияет.
##
## Награды — только за партии поиска игры (NetSession._match) на выделенном
## сервере: первое место получает лутбокс, остальные — пыль по месту.
##
## Шейдеры (решение владельца, 2026-09-30): FAERIE FIRE, GILDED, PRISM — как
## они выглядят, см. scenes/ui/card_skin.gdshader. Все — ступени ULTRA.
## Включённый шейдер ложится сразу на всю колоду игрока в партии, со
## стартовыми картами (CardView.skin_of); в маркете карты ничьи и обычные.
##
## Лутбокс бросает ступень по BOX_ODDS: ULTRA — случайный шейдер, EPIC и
## LEGENDARY — случайный альтернативный арт карты этой ступени (AltArts, вкладка
## CARDS); повтор — пыль. Шейдер и арт можно создать за пыль (craft_shader,
## craft_art).
##
## Коллекция хранится у игрока, в файле профиля (секция "collection"), как и
## история партий. В партию уходит только включённый шейдер; выбранные арты пока
## видны только в самой коллекции.

const TIERS: Array[String] = ["epic", "legendary", "ultra"]
const TIER_TITLES := {"epic": "EPIC", "legendary": "LEGENDARY", "ultra": "ULTRA"}
const TIER_COLOURS := {"epic": "b9a0ff", "legendary": "ffc24a", "ultra": "9ff0ff"}

const SHADERS: Array[String] = ["faerie", "gilded", "prism"]
const SHADER_TITLES := {"faerie": "FAERIE FIRE", "gilded": "GILDED", "prism": "PRISM"}
const SHADER_COLOURS := {"faerie": "b9a0ff", "gilded": "ffc24a", "prism": "9ff0ff"}
## Номер эффекта в card_skin.gdshader (0 — без шейдера).
const SHADER_INDEX := {"faerie": 1, "gilded": 2, "prism": 3}
## Ступень всех шейдеров.
const SHADER_TIER := "ultra"
const SHADER_PREFIX := "shader"
const ART_PREFIX := "alt"

## Пыль за место в партии поиска игры (первое место — лутбокс).
const DUST_BY_PLACE := {2: 40, 3: 30, 4: 20}
## Сколько пыли стоит создать предмет ступени.
const CRAFT_COST := {"epic": 200, "legendary": 600, "ultra": 1600}
## Сколько пыли даёт повтор (арт или шейдер, который уже есть).
const DUPLICATE_DUST := {"epic": 50, "legendary": 150, "ultra": 400}
## Шансы ступени в лутбоксе, в процентах (в сумме 100).
const BOX_ODDS := {"epic": 75, "legendary": 21, "ultra": 4}

const SECTION := "collection"


## Награда за место: {"boxes": 1} или {"dust": N}.
static func reward_for_place(place: int) -> Dictionary:
	if place <= 1:
		return {"boxes": 1}
	return {"dust": int(DUST_BY_PLACE.get(place, DUST_BY_PLACE[4]))}


## Шейдер из чужих рук (сеть, файл): известный или "".
static func clean_shader(shader: Variant) -> String:
	var s := str(shader) if shader != null else ""
	return s if SHADERS.has(s) else ""


static func shader_key(shader: String) -> String:
	return "%s:%s" % [SHADER_PREFIX, shader]


static func art_key(art: String) -> String:
	return "%s:%s" % [ART_PREFIX, art]


# --- хранение у игрока ---------------------------------------------------------

## {dust, boxes, owned: ["shader:faerie", "alt:48600_1", ...], shader: включённый
## или "", arts: {card_id: включённый арт этой карты}}.
static func load_data() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(PlayerProfile.path())
	var owned: Array[String] = []
	var saved_owned = cfg.get_value(SECTION, "owned", [])
	if saved_owned is Array:
		for item in saved_owned:
			var parts := String(item).split(":")
			if parts.size() == 2 and not owned.has(String(item)) \
					and ((parts[0] == SHADER_PREFIX and SHADERS.has(parts[1])) \
					or (parts[0] == ART_PREFIX and AltArts.has(parts[1]))):
				owned.append(String(item))
	var shader := clean_shader(cfg.get_value(SECTION, "shader", ""))
	if not owned.has(shader_key(shader)):
		shader = ""
	var arts := {}
	var saved_arts = cfg.get_value(SECTION, "arts", {})
	if saved_arts is Dictionary:
		for cid in saved_arts:
			var art := AltArts.clean(saved_arts[cid])
			if art != "" and AltArts.card_of(art) == String(cid) and owned.has(art_key(art)):
				arts[String(cid)] = art
	return {"dust": maxi(0, int(cfg.get_value(SECTION, "dust", 0))),
		"boxes": maxi(0, int(cfg.get_value(SECTION, "boxes", 0))), "owned": owned, "shader": shader,
		"arts": arts}


static func _save(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PlayerProfile.path())
	cfg.set_value(SECTION, "dust", int(data["dust"]))
	cfg.set_value(SECTION, "boxes", int(data["boxes"]))
	cfg.set_value(SECTION, "owned", data["owned"])
	cfg.set_value(SECTION, "shader", data["shader"])
	cfg.set_value(SECTION, "arts", data["arts"])
	# Образы отдельных карт (до 2026-09-30) больше не нужны.
	if cfg.has_section_key(SECTION, "active"):
		cfg.erase_section_key(SECTION, "active")
	cfg.save(PlayerProfile.path())


static func owns_shader(shader: String) -> bool:
	return (load_data()["owned"] as Array).has(shader_key(shader))


## Включённый шейдер — он уходит в партию вместе с профилем ("" — без него).
static func active_shader() -> String:
	return String(load_data()["shader"])


## Получить награду от сервера ({"boxes": N} / {"dust": N}).
static func grant(reward: Dictionary) -> void:
	var data := load_data()
	data["boxes"] = int(data["boxes"]) + maxi(0, int(reward.get("boxes", 0)))
	data["dust"] = int(data["dust"]) + maxi(0, int(reward.get("dust", 0)))
	_save(data)


## Ступень по шансам BOX_ODDS; roll — число 0..99.
static func tier_for_roll(roll: int) -> String:
	var edge := 0
	for tier in TIERS:
		edge += int(BOX_ODDS[tier])
		if roll < edge:
			return tier
	return TIERS[0]


## Открыть лутбокс: {tier, shader, art, duplicate, dust}; ULTRA — shader, EPIC и
## LEGENDARY — art ("" у другого). {} — лутбоксов нет. Повтор — пыль вместо
## предмета. Новый шейдер сразу включается, если до него был никакой; новый арт
## — если у его карты не был выбран никакой.
static func open_box(rng: RandomNumberGenerator) -> Dictionary:
	var data := load_data()
	if int(data["boxes"]) <= 0:
		return {}
	var tier := tier_for_roll(rng.randi_range(0, 99))
	data["boxes"] = int(data["boxes"]) - 1
	var shader := ""
	var art := ""
	var dup := false
	var dust := 0
	var key := ""
	if tier == SHADER_TIER:
		shader = SHADERS[rng.randi_range(0, SHADERS.size() - 1)]
		key = shader_key(shader)
	else:
		var pool := AltArts.arts_of_tier(tier)
		if not pool.is_empty():
			art = pool[rng.randi_range(0, pool.size() - 1)]
			key = art_key(art)
	dup = key == "" or (data["owned"] as Array).has(key)
	if dup:
		dust = int(DUPLICATE_DUST[tier])
		dup = key != ""
	else:
		(data["owned"] as Array).append(key)
		if shader != "" and String(data["shader"]) == "":
			data["shader"] = shader
		if art != "" and not (data["arts"] as Dictionary).has(AltArts.card_of(art)):
			data["arts"][AltArts.card_of(art)] = art
	data["dust"] = int(data["dust"]) + dust
	_save(data)
	return {"tier": tier, "shader": shader, "art": art, "duplicate": dup, "dust": dust}


## Создать шейдер за пыль (цена ULTRA) и сразу включить. false — уже есть или
## не хватает пыли.
static func craft_shader(shader: String) -> bool:
	if not SHADERS.has(shader):
		return false
	var data := load_data()
	var cost := int(CRAFT_COST[SHADER_TIER])
	if (data["owned"] as Array).has(shader_key(shader)) or int(data["dust"]) < cost:
		return false
	data["dust"] = int(data["dust"]) - cost
	(data["owned"] as Array).append(shader_key(shader))
	data["shader"] = shader
	_save(data)
	return true


## Включить шейдер ("" — колода без шейдера). false — он не открыт.
static func set_shader(shader: String) -> bool:
	var data := load_data()
	if shader != "" and not (data["owned"] as Array).has(shader_key(shader)):
		return false
	data["shader"] = clean_shader(shader)
	_save(data)
	return true


# --- альтернативные арты ---------------------------------------------------------

static func owns_art(art: String) -> bool:
	return (load_data()["owned"] as Array).has(art_key(art))


## Включённый арт карты ("" — оригинальный).
static func art_of(cid: String) -> String:
	return String((load_data()["arts"] as Dictionary).get(cid, ""))


## Сколько пыли стоит создать арт.
static func art_cost(art: String) -> int:
	return int(CRAFT_COST.get(AltArts.tier_of(art), 0))


## Создать арт за пыль и сразу включить. false — неизвестный, уже есть или не
## хватает пыли.
static func craft_art(art: String) -> bool:
	if not AltArts.has(art):
		return false
	var data := load_data()
	var cost := art_cost(art)
	if (data["owned"] as Array).has(art_key(art)) or int(data["dust"]) < cost:
		return false
	data["dust"] = int(data["dust"]) - cost
	(data["owned"] as Array).append(art_key(art))
	data["arts"][AltArts.card_of(art)] = art
	_save(data)
	return true


## Включить арт карты ("" — оригинальный; cid нужен только тогда). false — арт
## не открыт или чужой карты.
static func set_art(cid: String, art: String) -> bool:
	var data := load_data()
	if art == "":
		(data["arts"] as Dictionary).erase(cid)
	else:
		if not (data["owned"] as Array).has(art_key(art)) or AltArts.card_of(art) != cid:
			return false
		data["arts"][cid] = art
	_save(data)
	return true
