extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print(("ok: " if ok else "FAIL: ") + message)

func _run() -> void:
	var state := _build_rich_state()
	TurnEngine.start_turn(state, "red")
	var red: PlayerState = state.players["red"]
	red.power = 0
	_play_with(state, "48737", [0])
	check(not red.deck.played_pile.has("48737"), "Crawler left played pile")
	var power := red.power
	_play_with(state, "50120")
	check(red.power == power + 2, "Bone Naga remembers Crawler: +2 Power")
	TurnEngine.start_turn(state, "red")
	power = red.power
	_play_with(state, "50120")
	check(red.power == power, "Previous turn does not count")
	_play_with(state, "50120")
	check(red.power == power + 2, "Second Bone Naga sees first copy")
	for effect_card in ["48345", "48521"]:
		state = _build_rich_state()
		TurnEngine.start_turn(state, "red")
		red = state.players["red"]
		var blue: PlayerState = state.players["blue"]
		state.players["green"].deck.hand.clear()
		blue.deck.hand.assign([effect_card, "48342", "48342", "48344", "48343", "48340", "48336", "48331"])
		var r := _play_with(state, "49413")
		check(r.pending.legal_options.size() == 8, "Jarlaxle shows full 8-card hand including duplicates")
		TurnEngine.resume_card(state, effect_card, r)
		if effect_card == "48345":
			TurnEngine.resume_card(state, 1, r)
		check(r.pending.player_id == "red" and r.pending.data.get("acting_for") == "blue", "Red chooses for blue")
		var view := StateView.for_player_with_pending(state, "red", r.pending)
		var other := StateView.for_player_with_pending(state, "green", r.pending)
		check(other.pending_decision.legal_options.is_empty() and other.pending_decision.data.is_empty(), "Other player receives no private choices")
		check(not (view.players.blue as Dictionary).has("hand"), "No unrelated private hand data exposed")
		var panel := HandPanel.new()
		root.add_child(panel)
		panel.update_from_view(view, "red")
		check(not panel._choosing, "Own hand is not used for foreign choice")
		var dialog := DecisionDialog.new()
		root.add_child(dialog)
		dialog.update_from_view(view, "red")
		check(dialog._cards_slot.visible and dialog._cards_slot.get_child_count() >= 7, "Foreign cards displayed as clickable choices")
		var replies: Array = []
		dialog.option_chosen.connect(func(value): replies.append(value))
		var choice := dialog._cards_slot.get_child(0) as CardView
		choice.pressed.emit(choice.card_id)
		check(replies == ["48342"], "Click submits foreign target")
		var own_hand := red.deck.hand.duplicate()
		var promoted_before := blue.deck.inner_circle.count("48342")
		var devoured_before := state.devoured_pile.count("48342")
		TurnEngine.resume_card(state, replies[0], r)
		check(blue.deck.hand.count("48342") == 1 and red.deck.hand == own_hand, "Only blue loses target card")
		check(blue.deck.inner_circle.count("48342") == promoted_before + 1 if effect_card == "48345" else state.devoured_pile.count("48342") == devoured_before + 1, "Promote / Devour completed")
		panel.free()
		dialog.free()
	print("card regressions: passed %d, failed %d" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _build_rich_state(seed_value: int = 99) -> GameState:
	var data := BoardData.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var layout: Dictionary = (data["layouts"] as Dictionary)["2"]
	var adjacency: Array = layout["adjacency"]

	var hex_by_slot := {}
	# небольшой детерминированный набор гексов на 2 игроков, без X-гексов
	var centers: Array = ["A1"]
	var ring: Array = ["C1", "C2", "C3", "C4", "C5", "C6"]
	hex_by_slot["center"] = centers[0]
	var ring_names: Array = ["c0", "c1", "c2", "c3", "c4", "c5"]
	for i in range(ring.size()):
		hex_by_slot[ring_names[i]] = ring[i]
	hex_by_slot["b1"] = "B1"
	hex_by_slot["b2"] = "B2"

	var rotations := RotationOptimizer.optimize(hex_by_slot, adjacency, {}, data["edges"], rng)
	var graph: MapGraph = BoardData.make_builder().build(2, hex_by_slot, rotations)

	var state := GameState.new(graph, seed_value)
	state.add_player("red", [])
	state.add_player("blue", [])
	state.add_player("green", [])

	var slot_ids: Array = graph.slots.keys()
	slot_ids.sort()

	# расставляем войска по кругу: red, blue, green, white, пусто, повтор...
	var owners: Array[String] = ["red", "blue", "green", "white", ""]
	for i in range(slot_ids.size()):
		var owner: String = owners[i % owners.size()]
		if owner != "":
			state.troops[slot_ids[i]] = owner

	var site_ids: Array = graph.sites.keys()
	site_ids.sort()
	for i in range(site_ids.size()):
		var site_id: String = site_ids[i]
		var spy_owner: String = ["red", "blue", "green"][i % 3]
		state.spies[site_id] = [spy_owner]

	# карточные пулы: набор реальных card_id, кроме карты, которая будет
	# подставлена в руку самим тестом.
	var sample_ids: Array[String] = ["48342", "48344", "48343", "48340", "48336", "48331"]
	for pid: String in state.turn_order:
		var p: PlayerState = state.players[pid]
		p.deck = Deck.new(sample_ids.duplicate())
		p.deck.hand = sample_ids.duplicate()
		p.deck.discard_pile = sample_ids.duplicate()
		p.deck.inner_circle = sample_ids.duplicate()
		p.power = 20
		p.influence = 20
		p.troops_in_barracks = 30
		p.spies_in_barracks = 3
		p.trophy_hall_count = 6
		p.white_trophy_count = 3

	var half_a: Array[String] = sample_ids.duplicate()
	var half_b: Array[String] = sample_ids.duplicate()
	half_a.append_array(sample_ids)
	half_b.append_array(sample_ids)
	state.market = Market.build(half_a, half_b, state.rng)

	return state


## Отвечает на pending_decision максимально "активно" (реальная цель вместо
## "" / -1, вторая ветка choose_one, true на confirm), чтобы прогнать как
## можно больше кода эффекта. Возвращает число прогонов (для контроля
## отсутствия зависаний).

func _play_with(state: GameState, card_id: String, answers: Array = []) -> EffectResolver:
	var r := EffectResolver.new()
	if not state.players["red"].deck.hand.has(card_id):
		state.players["red"].deck.hand.append(card_id)
	TurnEngine.play_card(state, "red", card_id, r)
	for a in answers:
		if not r.is_waiting():
			break
		TurnEngine.resume_card(state, a, r)
	return r


## Слот с войском owner среди вариантов вопроса (или "").
