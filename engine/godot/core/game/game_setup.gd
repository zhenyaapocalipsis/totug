class_name GameSetup
extends RefCounted

## Сборка настоящей партии — единственная точка входа для UI (этап 7) и для
## любых прогонов на реальных данных. Раньше полноценное состояние собиралось
## только внутри тестов, каждым тестом по-своему и на выдуманных id карт
## ("M001", "NOBLE"); здесь оно собирается один раз и по-настоящему.
##
## Порядок ровно по рулбуку, стр. 4:
##   1-2. выбрать 2 полуколоды из шести и перетасовать их ВМЕСТЕ в колоду маркета
##   3.   выложить стопки House Guard и Priestess of Lolth
##   4.   если играем с полуколодой Demons — выложить стопку Insane Outcast
##   5.   открыть 6 верхних карт маркета (делает Market.build)
##   6.   расставить белые войска по данным сайтов
##   7-10.каждому игроку колода из 7 Noble + 3 Soldier, перетасовать, добрать 5
##   11.  каждый ставит войско на свободный стартовый сайт
##
## Состав полуколод и КОЛИЧЕСТВО КОПИЙ каждой карты берутся из
## data/cards/half_decks.json — он собран напрямую из сохранения TTS-мода
## (2745860709.json) и проверен: 6 полуколод × 20 уникальных карт + 3 стопки +
## 2 стартовые карты = ровно 125 карт cards.json, без остатка.
## Копий у карт РАЗНОЕ количество (от 1 до 4), а не по 2 — предположение
## "20 уникальных × 2 копии" было бы неверным.

const HALF_DECKS_PATH := "res://data/cards/half_decks.json"

## Стартовые сайты (рулбук стр. 4, шаг 11: "starting sites are those with black
## boxes"). Признака "чёрная рамка" в данных мода нет, поэтому список сверен
## вручную по картинкам гексов assets/hexes/*.png (чёрные таблички).
## Zi'Xzolca на гексе C6 белая — не стартовая.
const STARTING_SITE_NAMES := ["Magma Gate", "Menzoberranzan", "Xal Veldrin", "Caer Sidi", "Ath-Qua", "Wells of Darkness"]

const HAND_SIZE := 5

## Режимы сборки маркета (выбираются в меню перед партией):
##   STANDARD — две случайные разные полуколоды (рулбук);
##   DOUBLE   — одна случайная полуколода дважды;
##   RANDOM 3 / 4 / 6 — 3, 4 или 6 случайных полуколод, из них по 20 карт
##              каждого аспекта (см. build_market_cards).
const MODE_STANDARD := "standard"
const MODE_DOUBLE := "double"
const MODE_RANDOM_3 := "random3"
const MODE_RANDOM_4 := "random4"
const MODE_RANDOM_6 := "random6"
## New Era (проверка новых полуколод): Celestial Order + Shadow Isles
## (решение владельца 2026-10-08; до этого — Celestial + случайная
## классическая). Новые колоды в обычный пул не входят, пока не доделаны
## ("wip"), — иначе изменились бы сиды прежних партий.
## С NE-6 (2026-10-11) пару колод New Era игрок выбирает в меню: режим
## "newera:<колода>,<колода>"; просто "newera" — прежняя пара (старые
## реплеи и комнаты).
## С Siege-1 (2026-10-13) в том же переключателе — фанатские колоды Siege и
## Mercenaries (тоже "wip").
const MODE_NEW_ERA := "newera"
const NEW_ERA_DECKS: Array[String] = ["celestial", "shadow", "piltover", "siege", "mercenaries", "noxus", "freljord"]
const NEW_ERA_DEFAULT: Array[String] = ["celestial", "shadow"]
const MODES := [MODE_STANDARD, MODE_DOUBLE, MODE_RANDOM_3, MODE_RANDOM_4, MODE_RANDOM_6, MODE_NEW_ERA]
const MARKET_PER_ASPECT := 20

static var _half_deck_data: Dictionary = {}
## Только для прогонов баланса (tests/balance_run.gd all_decks=1): брать в
## случайный выбор и полуколоды "в работе" (New Era). Игра его не трогает.
static var include_wip := false


static func _load_half_decks() -> Dictionary:
	if not _half_deck_data.is_empty():
		return _half_deck_data
	var file := FileAccess.open(HALF_DECKS_PATH, FileAccess.READ)
	if file == null:
		push_error("не найден " + HALF_DECKS_PATH)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("повреждён " + HALF_DECKS_PATH)
		return {}
	_half_deck_data = parsed
	return _half_deck_data


## Названия всех доступных полуколод: drow, dragons, demons, elementals,
## aberrations, undead (Mercenaries/Siege исключены владельцем игры на этапе 4 —
## их изображений нет на диске).
## Полуколоды с "wip": true (новые колоды New Era, пока не все эффекты готовы)
## в выбор не попадают.
static func available_half_decks() -> Array[String]:
	var result: Array[String] = []
	var decks: Dictionary = _load_half_decks().get("half_decks", {})
	for key: String in decks.keys():
		if (decks[key] as Dictionary).get("wip", false) and not include_wip:
			continue
		result.append(key)
	result.sort()
	return result


## Развернуть полуколоду в плоский список card_id с учётом числа копий.
static func expand_half_deck(name: String) -> Array[String]:
	var decks: Dictionary = _load_half_decks().get("half_decks", {})
	var cards: Array[String] = []
	if not decks.has(name):
		push_error("нет полуколоды: " + name)
		return cards
	var copies: Dictionary = (decks[name] as Dictionary)["copies"]
	var ids: Array = copies.keys()
	ids.sort()  # детерминированный порядок ДО тасовки: одинаковый сид -> одинаковая партия
	for card_id: String in ids:
		for i in range(int(copies[card_id])):
			cards.append(card_id)
	return cards


static func starting_deck() -> Array[String]:
	var sd: Dictionary = _load_half_decks().get("starting_deck", {})
	var copies: Dictionary = sd.get("copies", {})
	var cards: Array[String] = []
	var ids: Array = copies.keys()
	ids.sort()
	for card_id: String in ids:
		for i in range(int(copies[card_id])):
			cards.append(card_id)
	return cards


## Главная точка входа. half_decks — какие две полуколоды в игре; если пусто,
## выбираются две случайные (рулбук: "choose two half-decks").
## interactive_start=true: шаг 11 не расставляет войска сама по порядку хода,
## а оставляет state.starting_site_candidates заполненным — GameServer при
## создании превратит это в решение каждого игрока (свой стартовый сайт
## выбирает сам игрок, а не движок). false (по умолчанию) — старое
## синхронное поведение, на которое опираются тесты и sweep-прогоны.
## random_first_player=true: очередь хода (turn_order) перемешивается, вместо
## того чтобы совпадать с порядком player_ids — так первый ходящий выбирается
## случайно (рулбук стр. 4). false по умолчанию: многие тесты вызывают
## new_game(["red", "blue"], seed) и полагаются на то, что первым ходит
## именно red — реальный экран игры включает этот флаг явно.
static func new_game(player_ids: Array[String], seed_value: int = 0,
		half_decks: Array[String] = [], with_x_hexes: bool = false,
		interactive_start: bool = false, random_first_player: bool = false,
		mode: String = MODE_STANDARD, team_game: bool = false) -> GameState:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var players := player_ids.size()
	var data := BoardData.load_all()
	var hex_by_slot := pick_hexes(players, rng, with_x_hexes)
	var layout: Dictionary = (data["layouts"] as Dictionary)[str(players)]
	var rotations := RotationOptimizer.optimize(
		hex_by_slot, layout["adjacency"], {}, data["edges"], rng)
	var graph: MapGraph = BoardData.make_builder().build(players, hex_by_slot, rotations)

	var state := GameState.new(graph, seed_value)
	state.layout = {
		"player_count": players,
		"hex_by_slot": hex_by_slot,
		"rotations": rotations,
	}

	# 1-2. колода маркета: полуколоды по режиму, перетасованные ВМЕСТЕ (не стопкой)
	var chosen: Array[String] = half_decks.duplicate()
	if chosen.size() != mode_deck_count(mode):
		chosen = pick_half_decks(mode, rng)
	var market_cards := build_market_cards(mode, chosen, rng)
	state.market = Market.build(market_cards, [], state.rng)

	state.half_decks = chosen.duplicate()
	state.game_mode = mode

	# 3-4. общие стопки; Insane Outcast — только если в маркете есть карты Demons
	# или Shadow Isles (New Era), Twig Blight — только с Shadow Isles
	var demon_cards := expand_half_deck("demons")
	var shadow_cards := expand_half_deck("shadow")
	var with_demons := market_cards.any(func(cid: String) -> bool: return demon_cards.has(cid))
	var with_shadow := market_cards.any(func(cid: String) -> bool: return shadow_cards.has(cid))
	# Icewind Dale: Demon Armor из колоды Masterwork (Stone Giant) раздаёт Insane Outcast
	var with_forge := market_cards.has(FreljordCards.STONE_GIANT)
	state.supplies = Supplies.standard(with_demons or with_shadow or with_forge, with_shadow)
	# Avernus (New Era Noxus): 3 Blade Fragment для Half-Dragon
	if market_cards.has(NoxusCards.HALF_DRAGON):
		state.supplies.counts[NoxusCards.BLADE_FRAGMENT] = NoxusCards.FRAGMENT_SUPPLY
	# Icewind Dale: колода предметов Masterwork для Stone Giant
	if with_forge:
		state.masterwork = FreljordCards.MASTERWORK.duplicate()
		Deck.shuffle_array(state.masterwork, state.rng)

	# 6. белые войска
	state.setup_white_troops(data["sites"])

	# 7-10. колоды игроков
	var ordered_ids: Array[String] = player_ids.duplicate()
	if team_game and players == 4:
		ordered_ids = team_order(player_ids, state.rng if random_first_player else null)
		state.set_teams(team_map(player_ids))
	elif random_first_player:
		Deck.shuffle_array(ordered_ids, state.rng)
	var base_deck := starting_deck()
	for player_id: String in ordered_ids:
		state.add_player(player_id, base_deck.duplicate())
		var p: PlayerState = state.players[player_id]
		p.deck.shuffle_draw_pile(state.rng)
		p.deck.draw_up_to(HAND_SIZE, state.rng)
	state.pool_stocks()  # 2v2: общие бараки команды (80 войск, 10 шпионов)

	# 11. стартовое войско каждому на свободном стартовом сайте
	var starting_sites := find_starting_sites(graph)
	if interactive_start:
		state.starting_site_candidates = starting_sites
	else:
		for i in range(player_ids.size()):
			if i < starting_sites.size():
				state.setup_deploy_starting_troop(player_ids[i], starting_sites[i])

	return state


## Команды 2 на 2 (этап Team-1): игроки 1 и 3 — команда первого (id
## команды = id игрока 1, "red"), игроки 2 и 4 — команда второго ("blue").
static func team_map(player_ids: Array[String]) -> Dictionary:
	return {
		player_ids[0]: player_ids[0], player_ids[2]: player_ids[0],
		player_ids[1]: player_ids[1], player_ids[3]: player_ids[1],
	}


## Очередь хода 2 на 2: команды через одного (A1 → B1 → A2 → B2). С rng
## случайно, какая команда ходит первой и в каком порядке игроки внутри команд.
static func team_order(player_ids: Array[String], rng: RandomNumberGenerator = null) -> Array[String]:
	var a: Array[String] = [player_ids[0], player_ids[2]]
	var b: Array[String] = [player_ids[1], player_ids[3]]
	if rng != null:
		if rng.randi() % 2 == 1:
			a.reverse()
		if rng.randi() % 2 == 1:
			b.reverse()
		if rng.randi() % 2 == 1:
			var t := a
			a = b
			b = t
	return [a[0], b[0], a[1], b[1]]


static func _pick_two_half_decks(rng: RandomNumberGenerator) -> Array[String]:
	var pool := available_half_decks()
	var first: int = rng.randi_range(0, pool.size() - 1)
	var second: int = rng.randi_range(0, pool.size() - 2)
	if second >= first:
		second += 1
	var result: Array[String] = [pool[first], pool[second]]
	return result


## Сколько полуколод берёт режим (для DOUBLE — одна и та же дважды).
static func mode_deck_count(mode: String) -> int:
	match mode:
		MODE_RANDOM_3:
			return 3
		MODE_RANDOM_4:
			return 4
		MODE_RANDOM_6:
			return 6
	return 2


## Случайные полуколоды для режима. STANDARD — старый выбор двух разных
## (тот же порядок вызовов rng, чтобы сиды прежних партий не поменялись).
static func pick_half_decks(mode: String, rng: RandomNumberGenerator) -> Array[String]:
	var pool := available_half_decks()
	match mode:
		MODE_DOUBLE:
			var one: String = pool[rng.randi_range(0, pool.size() - 1)]
			var twice: Array[String] = [one, one]
			return twice
		MODE_RANDOM_3, MODE_RANDOM_4, MODE_RANDOM_6:
			Deck.shuffle_array(pool, rng)
			return pool.slice(0, mini(mode_deck_count(mode), pool.size()))
	if is_new_era(mode):
		return new_era_pair(mode)
	return _pick_two_half_decks(rng)


static func is_new_era(mode: String) -> bool:
	return mode == MODE_NEW_ERA or mode.begins_with(MODE_NEW_ERA + ":")


## Режим известен игре (меню, сетевая комната, реплей).
static func is_mode(mode: String) -> bool:
	if MODES.has(mode):
		return true
	return is_new_era(mode) and new_era_mode(new_era_pair(mode)) == mode


## Две колоды режима New Era; непонятная запись — прежняя пара.
static func new_era_pair(mode: String) -> Array[String]:
	var pair: Array[String] = []
	if mode.begins_with(MODE_NEW_ERA + ":"):
		for deck: String in mode.substr(MODE_NEW_ERA.length() + 1).split(","):
			if NEW_ERA_DECKS.has(deck) and not pair.has(deck):
				pair.append(deck)
	if pair.size() != 2:
		pair.assign(NEW_ERA_DEFAULT)
	return pair


## Строка режима для пары колод (порядок как в NEW_ERA_DECKS).
static func new_era_mode(pair: Array) -> String:
	var sorted: Array[String] = []
	for deck: String in NEW_ERA_DECKS:
		if pair.has(deck):
			sorted.append(deck)
	if sorted == NEW_ERA_DEFAULT:
		return MODE_NEW_ERA
	return MODE_NEW_ERA + ":" + ",".join(sorted)


## Колода маркета из выбранных полуколод.
## STANDARD/DOUBLE: полуколоды целиком (DOUBLE — 2 × одна и та же, 80 карт).
## RANDOM 3/4/6: все копии всех выбранных полуколод сваливаются в общий пул,
## и по КАЖДОМУ аспекту из него случайно берутся MARKET_PER_ASPECT карт —
## как в обычном маркете (2 полуколоды × 10 копий на аспект = 20). Карты с
## большим числом копий так и остаются вероятнее, как в обычной игре.
static func build_market_cards(mode: String, decks: Array[String], rng: RandomNumberGenerator) -> Array[String]:
	var cards: Array[String] = []
	for deck_name: String in decks:
		cards.append_array(expand_half_deck(deck_name))
	if mode not in [MODE_RANDOM_3, MODE_RANDOM_4, MODE_RANDOM_6]:
		return cards
	var by_aspect := {}
	for cid: String in cards:
		var aspect := CardLibrary.card_aspect(cid)
		if not by_aspect.has(aspect):
			by_aspect[aspect] = [] as Array[String]
		(by_aspect[aspect] as Array[String]).append(cid)
	var aspects: Array = by_aspect.keys()
	aspects.sort()  # детерминированность: одинаковый сид -> одинаковый маркет
	var result: Array[String] = []
	for aspect: String in aspects:
		var pool: Array[String] = by_aspect[aspect]
		Deck.shuffle_array(pool, rng)
		result.append_array(pool.slice(0, mini(MARKET_PER_ASPECT, pool.size())))
	return result


static func find_starting_sites(graph: MapGraph) -> Array[String]:
	var found: Array[String] = []
	for site_id: String in graph.sites.keys():
		if STARTING_SITE_NAMES.has(graph.sites[site_id]["name"]):
			found.append(site_id)
	found.sort()  # детерминированность: порядок ключей Dictionary не гарантирован
	return found


## Выбор гексов для раскладки на 2/3/4 игроков по правилам мода
## (generateDemonwebMap*Player). Раньше жил внутри tests/build_layout.gd —
## перенесён сюда, чтобы у игры и у диагностики раскладок была ОДНА реализация:
## однажды алгоритм, написанный дважды, уже разошёлся (claude/progress.md,
## ошибка 9), повторять не хочется.
static func pick_hexes(players: int, rng: RandomNumberGenerator, with_x: bool = false) -> Dictionary:
	# Решение владельца: в центре только A1, A2, A3 и A9 (Wells of Darkness).
	var centre_pool := ["A1", "A2", "A3", "A9"]
	var ring_pool := ["C1", "C2", "C3", "C4", "C5", "C6"]
	if with_x:
		ring_pool.append_array(["X1", "X2", "X3", "X4"])
	Deck.shuffle_array(ring_pool, rng)

	var result := {
		"a": centre_pool[rng.randi_range(0, centre_pool.size() - 1)],
		"b1": "B1",
		"c_n1": ring_pool[0], "c_n2": ring_pool[1], "c_n3": ring_pool[2],
		"c_s1": ring_pool[3], "c_s2": ring_pool[4], "c_s3": ring_pool[5],
	}
	match players:
		2:
			result["b2"] = "B2"
		3:
			result["b2"] = "B2"
			result["b3"] = "B3"
		4:
			var b_pool := ["B2", "B3", "B4", "B5", "B6"]
			Deck.shuffle_array(b_pool, rng)
			var corners := ["corner0", "corner60", "corner180", "corner240", "corner300"]
			for i in corners.size():
				result[corners[i]] = b_pool[i]
			var extra := ["C7", "C8"]
			if rng.randi_range(0, 1) == 1:
				extra.reverse()
			result["c7"] = extra[0]
			result["c8"] = extra[1]
		_:
			push_error("нет раскладки на %d игроков" % players)
	return result
