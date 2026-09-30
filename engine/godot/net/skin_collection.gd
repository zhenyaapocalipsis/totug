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
## Лутбокс бросает ступень по BOX_ODDS: ULTRA — случайный шейдер (повтор —
## пыль), EPIC и LEGENDARY — пока просто пыль: для них будут альтернативные
## арты карт (вкладка CARDS). Шейдер можно создать за пыль (craft_shader).
##
## Коллекция хранится у игрока, в файле профиля (секция "collection"), как и
## история партий. В партию уходит только включённый шейдер.

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

## Пыль за место в партии поиска игры (первое место — лутбокс).
const DUST_BY_PLACE := {2: 40, 3: 30, 4: 20}
## Сколько пыли стоит создать предмет ступени.
const CRAFT_COST := {"epic": 200, "legendary": 600, "ultra": 1600}
## Сколько пыли даёт повтор (и пока — EPIC/LEGENDARY из лутбокса).
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


# --- хранение у игрока ---------------------------------------------------------

## {dust, boxes, owned: ["shader:faerie", ...], shader: включённый или ""}.
static func load_data() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(PlayerProfile.path())
	var owned: Array[String] = []
	var saved_owned = cfg.get_value(SECTION, "owned", [])
	if saved_owned is Array:
		for item in saved_owned:
			var parts := String(item).split(":")
			if parts.size() == 2 and parts[0] == SHADER_PREFIX and SHADERS.has(parts[1]) \
					and not owned.has(String(item)):
				owned.append(String(item))
	var shader := clean_shader(cfg.get_value(SECTION, "shader", ""))
	if not owned.has(shader_key(shader)):
		shader = ""
	return {"dust": maxi(0, int(cfg.get_value(SECTION, "dust", 0))),
		"boxes": maxi(0, int(cfg.get_value(SECTION, "boxes", 0))), "owned": owned, "shader": shader}


static func _save(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PlayerProfile.path())
	cfg.set_value(SECTION, "dust", int(data["dust"]))
	cfg.set_value(SECTION, "boxes", int(data["boxes"]))
	cfg.set_value(SECTION, "owned", data["owned"])
	cfg.set_value(SECTION, "shader", data["shader"])
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


## Открыть лутбокс: {tier, shader, duplicate, dust}; shader "" — выпала только
## пыль. {} — лутбоксов нет. Новый шейдер сразу включается, если до него был
## никакой.
static func open_box(rng: RandomNumberGenerator) -> Dictionary:
	var data := load_data()
	if int(data["boxes"]) <= 0:
		return {}
	var tier := tier_for_roll(rng.randi_range(0, 99))
	data["boxes"] = int(data["boxes"]) - 1
	var shader := ""
	var dup := false
	var dust := 0
	if tier == SHADER_TIER:
		shader = SHADERS[rng.randi_range(0, SHADERS.size() - 1)]
		dup = (data["owned"] as Array).has(shader_key(shader))
		if dup:
			dust = int(DUPLICATE_DUST[tier])
		else:
			(data["owned"] as Array).append(shader_key(shader))
			if String(data["shader"]) == "":
				data["shader"] = shader
	else:
		dust = int(DUPLICATE_DUST[tier])
	data["dust"] = int(data["dust"]) + dust
	_save(data)
	return {"tier": tier, "shader": shader, "duplicate": dup, "dust": dust}


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
