extends SceneTree

## Прогон многих случайных ПОЛНЫХ партий целиком (setup -> ходы -> конец игры
## -> финальный подсчёт), а не одного показательного примера — тот же принцип,
## что в sweep_layouts.gd (ошибка 16 из claude/progress.md: одна раскладка
## ничего не доказывает, 73 из 180 разваливались). Здесь то же самое для
## цикла хода: проверяем не один сценарий, а сотню случайных.
##
## Важная оговорка. На этапе 2 карты не разыгрываются по-настоящему (см.
## claude/stage2-start-here.md) — а значит НИКТО и НИКОГДА не выдаёт Power
## или Influence: этот пул наполняют исключительно эффекты карт (этап 5).
## Без внешнего источника ресурсов партия в чистом этапе 2 вообще не могла бы
## сдвинуться с места. Поэтому здесь бот КАЖДЫЙ ход получает случайный пул
## Power/Influence (0..6) как заглушку за ещё не реализованный розыгрыш
## карт — это единственный способ нагрузить действия, конец хода и конец
## игры реальным давлением. Когда этап 5 добавит настоящие карты, этот файл
## нужно будет переключить на настоящую выдачу ресурсов через эффекты.
##
## godot --headless --path godot --script res://tests/sweep_games.gd

const GAMES := 60
const MAX_TURNS := 2000
const MAX_ACTIONS_PER_TURN := 25
const STARTING_SITE_NAMES := ["Caer Sidi", "Xal Veldrin", "Ath-Qua", "Zi'Xzolca"]

var _bad := 0


func _initialize() -> void:
	var board_data := BoardData.load_all()
	var builder := BoardData.make_builder()

	var cost_rng := RandomNumberGenerator.new()
	cost_rng.seed = 9001
	_market_costs = _make_market_cost_table(cost_rng)

	for g in range(GAMES):
		var seed_value: int = g * 104729 + 17
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value

		var num_players: int = [2, 3, 4][g % 3]
		var graph := _build_board(builder, board_data, num_players, rng)
		var state := _setup_game(graph, board_data["sites"], num_players, rng)

		var ok := _play_out(state, rng, seed_value)
		if not ok:
			_bad += 1

	print("партий сыграно: %d, с проблемами: %d" % [GAMES, _bad])
	quit(1 if _bad > 0 else 0)


# --- сборка доски (переиспользует подход sweep_layouts.gd) ------------------

func _build_board(builder: BoardBuilder, data: Dictionary, num_players: int, rng: RandomNumberGenerator) -> MapGraph:
	var layout: Dictionary = (data["layouts"] as Dictionary)[str(num_players)]
	var hexes := _pick_hexes(num_players, rng)
	var rot := RotationOptimizer.optimize(hexes, layout["adjacency"], {}, data["edges"], rng)
	return builder.build(num_players, hexes, rot)


func _pick_hexes(num_players: int, rng: RandomNumberGenerator) -> Dictionary:
	var centre := ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8", "A9"]
	var ring := ["C1", "C2", "C3", "C4", "C5", "C6"]
	_shuffle(ring, rng)
	var r := {
		"a": centre[rng.randi_range(0, 8)], "b1": "B1",
		"c_n1": ring[0], "c_n2": ring[1], "c_n3": ring[2],
		"c_s1": ring[3], "c_s2": ring[4], "c_s3": ring[5],
	}
	if num_players == 2:
		r["b2"] = "B2"
	elif num_players == 3:
		r["b2"] = "B2"
		r["b3"] = "B3"
	else:
		var b := ["B2", "B3", "B4", "B5", "B6"]
		_shuffle(b, rng)
		var corners := ["corner0", "corner60", "corner180", "corner240", "corner300"]
		for i in corners.size():
			r[corners[i]] = b[i]
		r["c7"] = "C7"
		r["c8"] = "C8"
	return r


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = list[i]
		list[i] = list[j]
		list[j] = t


# --- синтетическая база карт (этап 4 сделает настоящую) --------------------

## card_id -> cost. Уникальные id, чтобы можно было проверить сохранение
## числа карт простым подсчётом вхождений по префиксу.
func _make_market_cost_table(rng: RandomNumberGenerator) -> Dictionary:
	var costs := {}
	for i in range(80):
		costs["M%03d" % i] = rng.randi_range(0, 8)
	return costs


func _make_market_halves() -> Array:
	var half_a: Array[String] = []
	var half_b: Array[String] = []
	for i in range(40):
		half_a.append("M%03d" % i)
	for i in range(40, 80):
		half_b.append("M%03d" % i)
	return [half_a, half_b]


# --- setup партии -------------------------------------------------------

func _setup_game(graph: MapGraph, site_data: Dictionary, num_players: int, rng: RandomNumberGenerator) -> GameState:
	var state := GameState.new(graph, rng.randi())
	state.setup_white_troops(site_data)

	var halves := _make_market_halves()
	state.market = Market.build(halves[0], halves[1], state.rng)

	var player_ids: Array[String] = []
	for i in range(num_players):
		player_ids.append("P%d" % i)
	for player_id in player_ids:
		# рулбук стр. 4: 7 Noble + 3 Soldier
		var starting: Array[String] = PlayerState.make_starting_deck("NOBLE", "SOLDIER")
		state.add_player(player_id, starting)
		state.players[player_id].deck.draw_up_to(5, state.rng)

	# стартовые сайты: подтверждённых 4 кандидата хватает на 2-4 игроков без
	# коллизий (рулбук стр. 4, шаг 11 — свободный стартовый сайт)
	var starting_site_ids := _find_starting_sites(graph)
	for i in player_ids.size():
		if i < starting_site_ids.size():
			state.setup_deploy_starting_troop(player_ids[i], starting_site_ids[i])

	return state


func _find_starting_sites(graph: MapGraph) -> Array[String]:
	var found: Array[String] = []
	for site_id: String in graph.sites.keys():
		if STARTING_SITE_NAMES.has(graph.sites[site_id]["name"]):
			found.append(site_id)
	return found


# --- розыгрыш партии -----------------------------------------------------

func _play_out(state: GameState, rng: RandomNumberGenerator, seed_value: int) -> bool:
	var killed_by_victim: Dictionary = {}  # player_id -> сколько раз убили ИХ войско
	var ok := true

	var turns := 0
	while not state.game_over and turns < MAX_TURNS:
		turns += 1
		var player_id := state.current_player()
		var p: PlayerState = state.players[player_id]

		# региональный бонус гекса A2 (core/rules/cluster_bonus.gd) — начисляется в
		# начале хода, ДО заглушки за розыгрыш карт, в тот же пул
		TurnEngine.start_turn(state, player_id)

		# заглушка за ещё не реализованный розыгрыш карт (см. заголовок файла)
		p.power += rng.randi_range(0, 6)
		p.influence += rng.randi_range(0, 6)

		# "играем" случайные карты из руки — структурно, без эффекта (этап 5)
		for card_id: String in p.deck.hand.duplicate():
			if rng.randf() < 0.5:
				p.deck.play_from_hand(card_id)

		_take_random_actions(state, player_id, rng, killed_by_victim)

		if not _check_invariants(state, seed_value, turns):
			ok = false

		TurnEngine.end_turn(state, player_id)
		GameEnd.advance_turn(state)

	if turns >= MAX_TURNS and not state.game_over:
		print("  ПРОБЛЕМА сид=%d: партия не закончилась за %d ходов" % [seed_value, MAX_TURNS])
		ok = false

	if not _check_final_conservation(state, seed_value, killed_by_victim):
		ok = false

	return ok


func _take_random_actions(state: GameState, player_id: String, rng: RandomNumberGenerator, killed_by_victim: Dictionary) -> void:
	var p: PlayerState = state.players[player_id]
	for _i in range(MAX_ACTIONS_PER_TURN):
		var choice := rng.randi_range(0, 3)
		var acted := false
		match choice:
			0:
				acted = _try_deploy(state, player_id, rng)
			1:
				acted = _try_assassinate(state, player_id, rng, killed_by_victim)
			2:
				acted = _try_recruit(state, player_id, rng)
			3:
				acted = _try_return_spy(state, player_id, rng)
		if not acted and p.power < 1 and p.influence < 1:
			break


func _try_deploy(state: GameState, player_id: String, rng: RandomNumberGenerator) -> bool:
	var p: PlayerState = state.players[player_id]
	if p.power < Actions.COST_DEPLOY:
		return false
	if p.troops_in_barracks <= 0:
		return Actions.deploy(state, player_id, "")
	var legal := state.presence.deployable_slots(player_id, state.troops, state.spies)
	if legal.is_empty():
		return false
	var slot: String = legal[rng.randi_range(0, legal.size() - 1)]
	return Actions.deploy(state, player_id, slot)


func _try_assassinate(state: GameState, player_id: String, rng: RandomNumberGenerator, killed_by_victim: Dictionary) -> bool:
	var p: PlayerState = state.players[player_id]
	if p.power < Actions.COST_ASSASSINATE:
		return false
	var legal := state.presence.assassinatable_slots(player_id, state.troops, state.spies)
	if legal.is_empty():
		return false
	var slot: String = legal[rng.randi_range(0, legal.size() - 1)]
	var victim: String = state.troops.get(slot, "")
	var success := Actions.assassinate(state, player_id, slot)
	if success and victim != "" and victim != "white":
		killed_by_victim[victim] = int(killed_by_victim.get(victim, 0)) + 1
	return success


func _try_recruit(state: GameState, player_id: String, rng: RandomNumberGenerator) -> bool:
	var p: PlayerState = state.players[player_id]
	if p.influence <= 0:
		return false
	var affordable: Array[int] = []
	for i in state.market.display.size():
		var card_id: String = state.market.display[i]
		if card_id == "":
			continue
		var cost: int = int(_market_costs.get(card_id, 999))
		if cost <= p.influence:
			affordable.append(i)
	if affordable.is_empty():
		return false
	var index: int = affordable[rng.randi_range(0, affordable.size() - 1)]
	var cost: int = int(_market_costs.get(state.market.display[index], 999))
	return Actions.recruit(state, player_id, index, cost)


func _try_return_spy(state: GameState, player_id: String, rng: RandomNumberGenerator) -> bool:
	var p: PlayerState = state.players[player_id]
	if p.power < Actions.COST_RETURN_SPY:
		return false
	var candidates: Array = []
	for site_id: String in state.spies.keys():
		var owners: Array = state.spies[site_id]
		for owner in owners:
			if owner != player_id and state.presence.has_presence_at_site(player_id, site_id, state.troops, state.spies):
				candidates.append([site_id, owner])
	if candidates.is_empty():
		return false
	var pick: Array = candidates[rng.randi_range(0, candidates.size() - 1)]
	return Actions.return_enemy_spy(state, player_id, pick[0], pick[1])


# --- инварианты -----------------------------------------------------------

var _market_costs: Dictionary = {}


func _check_invariants(state: GameState, seed_value: int, turn: int) -> bool:
	var ok := true
	for player_id: String in state.players.keys():
		var p: PlayerState = state.players[player_id]
		if p.power < 0:
			print("  ПРОБЛЕМА сид=%d ход=%d: у %s отрицательный Power" % [seed_value, turn, player_id])
			ok = false
		if p.influence < 0:
			print("  ПРОБЛЕМА сид=%d ход=%d: у %s отрицательный Influence" % [seed_value, turn, player_id])
			ok = false
		if p.troops_in_barracks < 0:
			print("  ПРОБЛЕМА сид=%d ход=%d: у %s отрицательный барак войск" % [seed_value, turn, player_id])
			ok = false
		if p.spies_in_barracks < 0 or p.spies_in_barracks > PlayerState.STARTING_SPIES:
			print("  ПРОБЛЕМА сид=%d ход=%d: у %s барак шпионов вне [0,5]: %d"
				% [seed_value, turn, player_id, p.spies_in_barracks])
			ok = false
	if state.vp_bank.ones < 0 or state.vp_bank.fives < 0:
		print("  ПРОБЛЕМА сид=%d ход=%d: банк VP ушёл в минус" % [seed_value, turn])
		ok = false
	var bank_total := state.vp_bank.total_remaining()
	var tokens_total := 0
	for player_id: String in state.players.keys():
		tokens_total += int((state.players[player_id] as PlayerState).vp_tokens)
	if bank_total + tokens_total != 40 + 16 * 5:
		print("  ПРОБЛЕМА сид=%d ход=%d: VP-токены не сохраняются (банк %d + у игроков %d != 120)"
			% [seed_value, turn, bank_total, tokens_total])
		ok = false
	if state.market.display.size() != Market.DISPLAY_SIZE:
		print("  ПРОБЛЕМА сид=%d ход=%d: дисплей маркета не из 6 слотов" % [seed_value, turn])
		ok = false
	return ok


func _check_final_conservation(state: GameState, seed_value: int, killed_by_victim: Dictionary) -> bool:
	var ok := true

	# войска игрока: барак + на доске + убитые = 40
	var on_board: Dictionary = {}
	for owner: String in state.troops.values():
		if owner == "" or owner == "white":
			continue
		on_board[owner] = int(on_board.get(owner, 0)) + 1
	for player_id: String in state.players.keys():
		var p: PlayerState = state.players[player_id]
		var total: int = p.troops_in_barracks + int(on_board.get(player_id, 0)) + int(killed_by_victim.get(player_id, 0))
		if total != PlayerState.STARTING_TROOPS:
			print("  ПРОБЛЕМА сид=%d: войска %s не сохраняются (барак %d + доска %d + убито %d = %d, ожидалось %d)"
				% [seed_value, player_id, p.troops_in_barracks, int(on_board.get(player_id, 0)),
					int(killed_by_victim.get(player_id, 0)), total, PlayerState.STARTING_TROOPS])
			ok = false

	# карты маркета (префикс "M"): нигде не потерялись и не задвоились
	var market_card_count := state.market.deck.size()
	for card_id: String in state.market.display:
		if card_id != "":
			market_card_count += 1
	for player_id: String in state.players.keys():
		var deck: Deck = (state.players[player_id] as PlayerState).deck
		for card_id: String in deck.cards_outside_inner_circle():
			if card_id.begins_with("M"):
				market_card_count += 1
		for card_id: String in deck.inner_circle:
			if card_id.begins_with("M"):
				market_card_count += 1
	if market_card_count != 80:
		print("  ПРОБЛЕМА сид=%d: карты маркета не сохраняются (найдено %d, ожидалось 80)"
			% [seed_value, market_card_count])
		ok = false

	return ok
