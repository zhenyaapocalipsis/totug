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
## boxes"). ВНИМАНИЕ: признака "чёрная рамка" в данных мода нет ни в каком виде,
## поэтому список собран по названиям и владельцем игры пока НЕ подтверждён —
## см. claude/progress.md. Если он назовёт настоящий список, менять надо здесь.
const STARTING_SITE_NAMES := ["Caer Sidi", "Xal Veldrin", "Ath-Qua", "Zi'Xzolca"]

const HAND_SIZE := 5

static var _half_deck_data: Dictionary = {}


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
static func available_half_decks() -> Array[String]:
	var result: Array[String] = []
	for key: String in (_load_half_decks().get("half_decks", {}) as Dictionary).keys():
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
		interactive_start: bool = false, random_first_player: bool = false) -> GameState:
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

	# 1-2. колода маркета: две полуколоды, перетасованные ВМЕСТЕ (не стопкой)
	var chosen: Array[String] = half_decks.duplicate()
	if chosen.size() != 2:
		chosen = _pick_two_half_decks(rng)
	state.market = Market.build(expand_half_deck(chosen[0]), expand_half_deck(chosen[1]), state.rng)

	# 3-4. общие стопки; Insane Outcast — только если в игре Demons
	state.supplies = Supplies.standard(chosen.has("demons"))

	# 6. белые войска
	state.setup_white_troops(data["sites"])

	# 7-10. колоды игроков
	var ordered_ids: Array[String] = player_ids.duplicate()
	if random_first_player:
		Deck.shuffle_array(ordered_ids, state.rng)
	var base_deck := starting_deck()
	for player_id: String in ordered_ids:
		state.add_player(player_id, base_deck.duplicate())
		var p: PlayerState = state.players[player_id]
		p.deck.shuffle_draw_pile(state.rng)
		p.deck.draw_up_to(HAND_SIZE, state.rng)

	# 11. стартовое войско каждому на свободном стартовом сайте
	var starting_sites := find_starting_sites(graph)
	if interactive_start:
		state.starting_site_candidates = starting_sites
	else:
		for i in range(player_ids.size()):
			if i < starting_sites.size():
				state.setup_deploy_starting_troop(player_ids[i], starting_sites[i])

	return state


static func _pick_two_half_decks(rng: RandomNumberGenerator) -> Array[String]:
	var pool := available_half_decks()
	var first: int = rng.randi_range(0, pool.size() - 1)
	var second: int = rng.randi_range(0, pool.size() - 2)
	if second >= first:
		second += 1
	var result: Array[String] = [pool[first], pool[second]]
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
	var centre_pool := ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8", "A9"]
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
