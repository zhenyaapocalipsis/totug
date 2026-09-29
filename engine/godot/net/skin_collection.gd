class_name SkinCollection
extends RefCounted

## Образы карт (решение владельца, 2026-09-30): косметика, на игру не влияет.
##
## Награды — только за партии поиска игры (NetSession._match) на выделенном
## сервере: первое место получает лутбокс, остальные — пыль по месту. Лутбокс
## даёт случайный образ случайной карты; повтор уже открытого образа
## превращается в пыль. За пыль образ можно создать сам (craft).
##
## Три ступени образа: EPIC (Faerie Fire), LEGENDARY (позолота), ULTRA
## (призма); как они выглядят — scenes/ui/card_skin.gdshader.
##
## Коллекция хранится у игрока, в файле профиля (секция "collection"), как и
## история партий. В партию уходят только включённые образы (active): карта ->
## ступень. В игре образ виден на картах, которые игрок купил с рынка (карты
## стартовой колоды образов не имеют — у них нет цены).

const TIERS: Array[String] = ["epic", "legendary", "ultra"]
const TIER_TITLES := {"epic": "EPIC", "legendary": "LEGENDARY", "ultra": "ULTRA"}
const TIER_COLOURS := {"epic": "b9a0ff", "legendary": "ffc24a", "ultra": "9ff0ff"}
## Номер ступени для шейдера (0 — без образа).
const TIER_INDEX := {"epic": 1, "legendary": 2, "ultra": 3}

## Пыль за место в партии поиска игры (первое место — лутбокс).
const DUST_BY_PLACE := {2: 40, 3: 30, 4: 20}
## Сколько пыли стоит создать образ.
const CRAFT_COST := {"epic": 200, "legendary": 600, "ultra": 1600}
## Сколько пыли даёт повтор образа из лутбокса.
const DUPLICATE_DUST := {"epic": 50, "legendary": 150, "ultra": 400}
## Шансы ступени в лутбоксе, в процентах (в сумме 100).
const BOX_ODDS := {"epic": 75, "legendary": 21, "ultra": 4}

const SECTION := "collection"


## Карты, у которых может быть образ: все, что покупаются (есть цена).
static func skinnable_cards() -> Array[String]:
	var out: Array[String] = []
	for cid in CardLibrary.all_ids():
		if CardLibrary.card_cost(cid) >= 0:
			out.append(cid)
	return out


static func is_skinnable(cid: String) -> bool:
	return CardLibrary.card_cost(cid) >= 0


## Награда за место: {"boxes": 1} или {"dust": N}.
static func reward_for_place(place: int) -> Dictionary:
	if place <= 1:
		return {"boxes": 1}
	return {"dust": int(DUST_BY_PLACE.get(place, DUST_BY_PLACE[4]))}


## Включённые образы из чужих рук (сеть): только настоящие карты с ценой и
## настоящие ступени.
static func clean_skins(skins: Variant) -> Dictionary:
	var out := {}
	if not skins is Dictionary:
		return out
	for cid in (skins as Dictionary):
		var tier := String((skins as Dictionary)[cid])
		if TIERS.has(tier) and is_skinnable(String(cid)):
			out[String(cid)] = tier
	return out


# --- хранение у игрока ---------------------------------------------------------

## {dust, boxes, owned: ["карта:ступень", ...], active: карта -> ступень}.
static func load_data() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(PlayerProfile.path())
	var owned: Array[String] = []
	var saved_owned = cfg.get_value(SECTION, "owned", [])
	if saved_owned is Array:
		for item in saved_owned:
			var parts := String(item).split(":")
			if parts.size() == 2 and TIERS.has(parts[1]) and is_skinnable(parts[0]) and not owned.has(String(item)):
				owned.append(String(item))
	var active := {}
	var saved_active = cfg.get_value(SECTION, "active", {})
	for cid in clean_skins(saved_active):
		if owned.has(skin_key(cid, String(saved_active[cid]))):
			active[cid] = String(saved_active[cid])
	return {"dust": maxi(0, int(cfg.get_value(SECTION, "dust", 0))),
		"boxes": maxi(0, int(cfg.get_value(SECTION, "boxes", 0))), "owned": owned, "active": active}


static func _save(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PlayerProfile.path())
	cfg.set_value(SECTION, "dust", int(data["dust"]))
	cfg.set_value(SECTION, "boxes", int(data["boxes"]))
	cfg.set_value(SECTION, "owned", data["owned"])
	cfg.set_value(SECTION, "active", data["active"])
	cfg.save(PlayerProfile.path())


static func skin_key(cid: String, tier: String) -> String:
	return "%s:%s" % [cid, tier]


static func owns(cid: String, tier: String) -> bool:
	return (load_data()["owned"] as Array).has(skin_key(cid, tier))


## Включённые образы — они уходят в партию вместе с профилем.
static func active() -> Dictionary:
	return load_data()["active"]


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


## Открыть лутбокс: {card, tier, duplicate, dust}; {} — лутбоксов нет.
## Новый образ сразу включается, если у карты ещё не было включённого.
static func open_box(rng: RandomNumberGenerator) -> Dictionary:
	var data := load_data()
	if int(data["boxes"]) <= 0:
		return {}
	var cards := skinnable_cards()
	var cid := cards[rng.randi_range(0, cards.size() - 1)]
	var tier := tier_for_roll(rng.randi_range(0, 99))
	data["boxes"] = int(data["boxes"]) - 1
	var key := skin_key(cid, tier)
	var dup := (data["owned"] as Array).has(key)
	var dust := 0
	if dup:
		dust = int(DUPLICATE_DUST[tier])
		data["dust"] = int(data["dust"]) + dust
	else:
		(data["owned"] as Array).append(key)
		if not (data["active"] as Dictionary).has(cid):
			data["active"][cid] = tier
	_save(data)
	return {"card": cid, "tier": tier, "duplicate": dup, "dust": dust}


## Создать образ за пыль. false — уже есть, не хватает пыли или карта без образов.
static func craft(cid: String, tier: String) -> bool:
	if not TIERS.has(tier) or not is_skinnable(cid):
		return false
	var data := load_data()
	var key := skin_key(cid, tier)
	if (data["owned"] as Array).has(key) or int(data["dust"]) < int(CRAFT_COST[tier]):
		return false
	data["dust"] = int(data["dust"]) - int(CRAFT_COST[tier])
	(data["owned"] as Array).append(key)
	data["active"][cid] = tier
	_save(data)
	return true


## Включить образ карты (tier "" — показывать карту обычной).
static func set_active(cid: String, tier: String) -> bool:
	var data := load_data()
	if tier == "":
		(data["active"] as Dictionary).erase(cid)
	elif (data["owned"] as Array).has(skin_key(cid, tier)):
		data["active"][cid] = tier
	else:
		return false
	_save(data)
	return true
