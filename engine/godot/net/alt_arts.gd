class_name AltArts
extends RefCounted

## Альтернативные арты карт (решение владельца, 2026-10-06): к карте у игрока
## может быть несколько артов, каждый EPIC или LEGENDARY. Арт — это замена
## картинки в окне арта большой карты и на мини-карте, больше ничего не меняется.
##
## Идентификатор арта — "<card_id>_<n>" (например "48600_1"). Картинки лежат в
## assets/cards_alt (полная карта) и assets/cards_alt_mini (мини). Рисуются
## tools/pixel_cards.gd -- alt из исходников в "alt arts/" (список и редкость —
## tools/alt_arts.gd); сюда список переносится после каждого прогона.

const FULL_DIR := "res://assets/cards_alt/"
const MINI_DIR := "res://assets/cards_alt_mini/"

## арт -> ступень (SkinCollection.TIERS)
const TIER_OF := {
	"48310_1": "epic",
	"48318_1": "epic",
	"48325_1": "epic",
	"48400_1": "legendary",
	"48402_1": "epic",
	"48403_1": "legendary",
	"48403_2": "legendary",
	"48405_1": "epic",
	"48419_1": "legendary",
	"48424_1": "epic",
	"48426_1": "legendary",
	"48426_2": "legendary",
	"48428_1": "epic",
	"48433_1": "legendary",
	"48436_1": "epic",
	"48500_1": "legendary",
	"48506_1": "epic",
	"48509_1": "epic",
	"48509_2": "epic",
	"48509_3": "epic",
	"48512_1": "epic",
	"48513_1": "epic",
	"48516_1": "epic",
	"48519_1": "epic",
	"48521_1": "legendary",
	"48527_1": "epic",
	"48529_1": "epic",
	"48531_1": "epic",
	"48534_1": "epic",
	"48537_1": "epic",
	"48538_1": "epic",
	"48604_1": "epic",
	"48615_1": "epic",
	"48623_1": "epic",
	"48632_1": "legendary",
	"48636_1": "epic",
	"48700_1": "legendary",
	"48700_2": "legendary",
	"48703_1": "epic",
	"48705_1": "legendary",
	"48706_1": "epic",
	"48708_1": "epic",
	"48709_1": "epic",
	"48711_1": "epic",
	"48712_1": "epic",
	"48713_1": "legendary",
	"48714_1": "epic",
	"48714_2": "epic",
	"48715_1": "epic",
	"48715_2": "epic",
	"48718_1": "epic",
	"48719_1": "epic",
	"48720_1": "epic",
	"48721_1": "legendary",
	"48722_1": "epic",
	"48723_1": "epic",
	"48724_1": "epic",
	"48726_1": "epic",
	"48728_1": "legendary",
	"48729_1": "epic",
	"48730_1": "epic",
	"48731_1": "epic",
	"48735_1": "epic",
	"48736_1": "epic",
	"48737_1": "epic",
	"48739_1": "epic",
}


## Карта, к которой относится арт ("48600_1" -> "48600").
static func card_of(art: String) -> String:
	return art.get_slice("_", 0)


static func has(art: String) -> bool:
	return TIER_OF.has(art)


## Арт из чужих рук (файл, сеть): известный или "".
static func clean(art: Variant) -> String:
	var s := str(art) if art != null else ""
	return s if TIER_OF.has(s) else ""


static func tier_of(art: String) -> String:
	return String(TIER_OF.get(art, ""))


## Все арты карты: сначала EPIC, потом LEGENDARY, по номеру.
static func arts_of(cid: String) -> Array[String]:
	var out: Array[String] = []
	for art: String in TIER_OF:
		if card_of(art) == cid:
			out.append(art)
	out.sort_custom(func(a: String, b: String) -> bool:
		var ta := SkinCollection.TIERS.find(tier_of(a))
		var tb := SkinCollection.TIERS.find(tier_of(b))
		return a < b if ta == tb else ta < tb)
	return out


## Все арты ступени (для лутбокса), по порядку.
static func arts_of_tier(tier: String) -> Array[String]:
	var out: Array[String] = []
	for art: String in TIER_OF:
		if TIER_OF[art] == tier:
			out.append(art)
	out.sort()
	return out


static func full_texture(art: String) -> Texture2D:
	var path := FULL_DIR + art + ".png"
	return load(path) as Texture2D if TIER_OF.has(art) and ResourceLoader.exists(path) else null


static func mini_texture(art: String) -> Texture2D:
	var path := MINI_DIR + art + ".png"
	return load(path) as Texture2D if TIER_OF.has(art) and ResourceLoader.exists(path) else null


## Включённые арты игрока одной строкой, как они идут по сети и лежат в профиле
## стола: ID через запятую, не больше одного на карту, только известные, по
## порядку (одинаковые наборы — одинаковые строки). Чужое и лишнее отбрасывается.
static func clean_list(value: Variant) -> String:
	var by_card := {}
	for item in (str(value).split(",") if value != null else PackedStringArray()):
		var art := clean(item.strip_edges())
		if art != "" and not by_card.has(card_of(art)):
			by_card[card_of(art)] = art
	var out: Array = by_card.values()
	out.sort()
	return ",".join(out)


## Строка артов -> {card_id: арт}.
static func list_to_map(list: String) -> Dictionary:
	var map := {}
	for art in clean_list(list).split(",", false):
		map[card_of(art)] = art
	return map


## Словарь {card_id: арт} -> строка артов.
static func map_to_list(map: Dictionary) -> String:
	return clean_list(",".join(PackedStringArray(map.values())))
