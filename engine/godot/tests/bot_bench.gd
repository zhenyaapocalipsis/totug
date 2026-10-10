extends SceneTree

## Замер скорости "партии в уме" (Bot-2): сколько стоит копия партии,
## догадка о скрытом и доигровка ботами. По этим цифрам выбирается, сколько
## проигрышей бот Bot-3 успеет сделать за секунду.
## Запуск:
##   godot --headless --path engine/godot --script res://tests/bot_bench.gd -- players=2


func _initialize() -> void:
	var n := 2
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("players="):
			n = int(a.get_slice("=", 1))
	var ids := GameScreen.player_ids_for(n)
	var server := GameServer.new(GameSetup.new_game(ids, 7, [], false, true, true))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var marks := [2, 6, 10]
	var turns := 0
	var waiting_for_question := false
	print("=== скорость партии в уме, %d игрока ===" % n)
	while not server.state.game_over:
		var res: Dictionary = server.apply_intent(BotPlayer.next_intent(server, BotPlayer.acting_player(server)))
		for e: Dictionary in res["events"]:
			if e["type"] == "turn_ended":
				turns += 1
		if waiting_for_question and not server.is_quiet():
			waiting_for_question = false
			_bench("копия посреди вопроса карты (повтор %d ходов)" % server._since.size(), 100, func(): server.clone())
			continue
		if marks.is_empty() or turns != int(marks[0]) * n or not server.is_quiet():
			continue
		marks.pop_front()
		print("\nраунд %d:" % (turns / n))
		var st := server.state
		var ctx := BotPlayer._context(st, ids[0])
		_bench("оценка позиции целиком (BotPlayer.evaluate)", 300, func(): BotPlayer.evaluate(st, ctx))
		_bench("  из неё: map_score одного игрока", 300, func(): st.control.map_score(ids[0], st.troops, st.spies))
		_bench("  из неё: ControlMarkers.evaluate", 300, func(): ControlMarkers.evaluate(st, ids[0]))
		_bench("  из неё: ClusterBonus.evaluate", 300, func(): ClusterBonus.evaluate(st, ids[0]))
		_bench("  из неё: Presence.deployable_slots", 300, func(): st.presence.deployable_slots(ids[0], st.troops, st.spies))
		_bench("контекст оценки (_context)", 300, func(): BotPlayer._context(st, ids[0]))
		# Bot-4: те же 30 кругов проверок на одном потоке и на всех ядрах.
		# Позиция с выбором: доигрываем копию, пока у первого игрока не будет
		# хотя бы двух вариантов.
		var probe := server.clone()
		probe._track = true  # чтобы копии probe работали и посреди вопроса карты
		var cands: Array[Intent] = []
		for k in range(300):
			var who := BotPlayer.acting_player(probe)
			if who == ids[0]:
				cands = BotPlayer.ranked_intents(probe.clone(), who, BotSearch.candidates)
				if cands.size() >= 2:
					break
			probe.apply_intent(BotPlayer.next_intent(probe, who))
		if cands.size() >= 2:
			for th in [1, 2, 4, 8, 15]:
				BotSearch.threads = th
				_bench("поиск, 30 кругов × %d вариантов, потоков %d" % [cands.size(), BotSearch.worker_count()], 1,
					func(): BotSearch._search(probe, ids[0], cands, 0, 5, 30))
			BotSearch.threads = 0
		_bench("копия в спокойной точке", 200, func(): server.clone())
		_bench("догадка о скрытом (копия + перемешивание)", 200, func(): BotSim.determinize(server, ids[0], rng))
		_bench("доигровка 1 хода, полный бот", 20, func(): BotSim.rollout(BotSim.determinize(server, ids[0], rng), 1, false))
		_bench("доигровка 1 хода, быстрый бот", 20, func(): BotSim.rollout(BotSim.determinize(server, ids[0], rng), 1))
		_bench("доигровка 1 круга, быстрый бот", 10, func(): BotSim.rollout(BotSim.determinize(server, ids[0], rng), n))
		_bench("доигровка до конца, быстрый бот", 3, func(): BotSim.rollout(BotSim.determinize(server, ids[0], rng)))
		waiting_for_question = true
	quit(0)


func _bench(title: String, times: int, body: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	for i in range(times):
		body.call()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / times
	print("  %-46s %8.2f мс  (%d в секунду)" % [title, ms, int(1000.0 / maxf(ms, 0.001))])
