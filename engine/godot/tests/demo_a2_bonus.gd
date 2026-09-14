extends SceneTree

## Наглядный прогон регионального бонуса гекса A2: не набор проверок, а читаемая
## пошаговая история одной партии, специально для того, чтобы владелец игры мог
## своими глазами увидеть, что и когда начисляется — без чтения кода.
##
## godot --headless --path godot --script res://tests/demo_a2_bonus.gd

func _initialize() -> void:
	print("=== ДЕМО: региональный бонус гекса A2 (Fogtown / Gallenghast / Darkflame) ===\n")

	var graph := MapGraph.new()
	graph.add_site("fogtown", "Fogtown", 4, "A2")
	graph.add_site("gallenghast", "Gallenghast", 4, "A2")
	graph.add_site("darkflame", "Darkflame", 4, "A2")
	for prefix in ["fogtown", "gallenghast", "darkflame"]:
		for i in range(3):
			graph.add_slot("%s_%d" % [prefix, i], "A2", Vector2(i, 0), prefix)
	graph.finalize()

	var state := GameState.new(graph, 1)
	state.add_player("Игрок Red", ["c0", "c1", "c2", "c3", "c4"])
	state.add_player("Игрок Blue", ["c0", "c1", "c2", "c3", "c4"])
	var red: PlayerState = state.players["Игрок Red"]
	var blue: PlayerState = state.players["Игрок Blue"]
	red.deck.draw_up_to(5, state.rng)
	blue.deck.draw_up_to(5, state.rng)

	print("Сайты гекса A2 на столе: Fogtown (VP 4), Gallenghast (VP 4), Darkflame (VP 4), по 3 троп-слота каждый.")
	print("Печатный текст бонуса на тайле A2 (Demonweb v2.2):")
	print("  TROOPS IN ALL 3        -> 1 Influence / ход")
	print("  CONTROL ALL 3          -> 1 Influence, 1 Power, 1 VP / ход")
	print("  TOTAL CONTROL OF ALL 3 -> 2 Influence, 2 Power, 4 VP / ход\n")

	_turn(state, "--- Ход 1: у Red нет войск нигде на A2 ---")
	_report(state, "Игрок Red")

	print("\n>>> Red разворачивает по одному войску на Fogtown, Gallenghast и Darkflame.")
	state.troops["fogtown_0"] = "Игрок Red"
	state.troops["gallenghast_0"] = "Игрок Red"
	state.troops["darkflame_0"] = "Игрок Red"
	_turn(state, "--- Ход 2: у Red войско есть на всех трёх, но Blue пока сильнее нигде не сидит ---")
	_report(state, "Игрок Red")

	print("\n>>> Blue тоже разворачивает по войску на все три сайта (тир 'troops in all 3' не эксклюзивный).")
	state.troops["fogtown_1"] = "Игрок Blue"
	state.troops["gallenghast_1"] = "Игрок Blue"
	state.troops["darkflame_1"] = "Игрок Blue"
	_turn(state, "--- Ход 3: оба игрока держат войска на всех трёх сайтах одновременно ---")
	_report(state, "Игрок Red")
	_report(state, "Игрок Blue")

	print("\n>>> Red добавляет по второму войску на каждый сайт и получает перевес (контроль всех трёх).")
	state.troops["fogtown_2"] = "Игрок Red"
	state.troops["gallenghast_2"] = "Игрок Red"
	state.troops["darkflame_2"] = "Игрок Red"
	_turn(state, "--- Ход 4: Red контролирует все три сайта (2 войска против 1 у Blue на каждом) ---")
	_report(state, "Игрок Red")
	_report(state, "Игрок Blue")
	print("  (у Blue по-прежнему войско на каждом сайте — тир 'troops in all 3' у него сохраняется,")
	print("   контроль Red ему не мешает: это два независимых игрока, а не общий ресурс)")

	print("\n>>> Red изгоняет войско Blue отовсюду и занимает ВСЕ 9 слотов сам — тотальный контроль всех трёх.")
	state.troops["fogtown_1"] = "Игрок Red"
	state.troops["gallenghast_1"] = "Игрок Red"
	state.troops["darkflame_1"] = "Игрок Red"
	_turn(state, "--- Ход 5: Red занимает все 9 слотов трёх сайтов гекса A2 ---")
	_report(state, "Игрок Red")

	print("\n=== Итог: тиры не складываются между собой (control -> заменяется total control),")
	print("    но 'troops in all 3' может получить одновременно несколько игроков. ===")
	quit(0)


func _turn(state: GameState, header: String) -> void:
	print(header)


func _report(state: GameState, player_id: String) -> void:
	var reward: ClusterBonus.Reward = ClusterBonus.evaluate(state, player_id)
	print("  %s: бонус A2 сейчас = %d Influence, %d Power, %d VP/ход"
		% [player_id, reward.influence, reward.power, reward.vp])
