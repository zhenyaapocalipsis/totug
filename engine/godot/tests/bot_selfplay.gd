extends SceneTree

## Партии бот против бота (Bot-1) — проверка бота и первые цифры баланса.
## search=1 [budget= horizon= threads= cands= plan=0/1] — один игрок (по кругу мест) — искатель
## Bot-3; vs=search [vs_threads= vs_budget= vs_cands= vs_plan=0/1] — соперники тоже искатели.
## Запуск:
##   godot --headless --path engine/godot --script res://tests/bot_selfplay.gd -- games=20 players=2 mode=standard seed=1
## Печатает: победы по месту за столом, средние VP, длину партии, причины
## конца, сколько намерений сервер отклонил, и карты, с которыми чаще
## выигрывают (если игр достаточно).


func _initialize() -> void:
	var args := {"games": "10", "players": "2", "mode": GameSetup.MODE_STANDARD, "seed": "1"}
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var games := int(args["games"])
	var n := int(args["players"])
	var pids: Array[String] = []
	for i in range(n):
		pids.append("p%d" % (i + 1))

	var seat_wins := []
	seat_wins.resize(n)
	seat_wins.fill(0.0)
	var seat_vp := []
	seat_vp.resize(n)
	seat_vp.fill(0.0)
	var reasons := {}
	var total_rounds := 0.0
	var total_rejected := 0
	var unfinished := 0
	var card_games := {}   # card_id -> [игр куплено, из них побед]
	var fast_wins := 0.0  # fast=1: победы быстрого бота
	var fast_margin := 0.0  # сумма (VP героя − лучший VP остальных)
	BotSearch.horizon = int(args.get("horizon", "2"))
	var t0 := Time.get_ticks_msec()

	for g in range(games):
		var seed_value := int(args["seed"]) + g
		var state := GameSetup.new_game(pids, seed_value, [], false, true, true, String(args["mode"]))
		var server := GameServer.new(state)
		server.build_views = false
		# fast=1 / search=1: один игрок (по кругу мест) — быстрый бот или
		# искатель Bot-3 (budget=мс на решение), остальные — обычный Bot-1.
		var hero_mode := "fast" if args.get("fast", "0") == "1" else ("search" if args.get("search", "0") == "1" else "")
		var fast_pid: String = pids[g % n] if hero_mode != "" else ""
		var bought := {}  # pid -> {card_id: true}
		var turns := 0
		# Ведём партию сами (а не play_out), чтобы видеть покупки.
		var res := {"intents": 0, "rejected": 0}
		var in_row := 0
		while not state.game_over and int(res["intents"]) < 20000:
			var actor := BotPlayer.acting_player(server)
			var intent: Intent
			if in_row > 0:
				intent = BotPlayer.fallback_intent(server, actor)
			elif actor == fast_pid and hero_mode == "search":
				BotSearch.threads = int(args.get("threads", "0"))
				BotSearch.candidates = int(args.get("cands", "5"))
				BotSearch.plan_turns = args.get("plan", "0") == "1"
				intent = BotSearch.next_intent(server, actor, int(args.get("budget", "300")))
			elif args.get("vs", "bot1") == "search":
				# соперники — тоже искатели (vs_threads потоков, по умолчанию 1:
				# прежний Bot-3), чтобы мерить новую версию против старой
				BotSearch.threads = int(args.get("vs_threads", "1"))
				BotSearch.candidates = int(args.get("vs_cands", "4"))
				BotSearch.plan_turns = args.get("vs_plan", "0") == "1"
				intent = BotSearch.next_intent(server, actor, int(args.get("vs_budget", args.get("budget", "300"))))
			else:
				intent = BotPlayer.next_intent(server, actor, actor == fast_pid)
			var out: Dictionary = server.apply_intent(intent)
			res["intents"] += 1
			if int(out["error"]) != GameServer.Error.OK:
				res["rejected"] += 1
				in_row += 1
				if in_row > 2:
					server.apply_intent(Intent.end_turn(state.current_player()))
					in_row = 0
				continue
			in_row = 0
			for e: Dictionary in out["events"]:
				if e["type"] in ["recruit", "recruit_supply"]:
					var who := String(e["player_id"])
					if not bought.has(who):
						bought[who] = {}
					bought[who][String(e["card_id"])] = true
				elif e["type"] == "turn_ended":
					turns += 1
		if not state.game_over:
			unfinished += 1
			continue
		total_rejected += int(res["rejected"])
		total_rounds += float(turns) / n
		reasons[state.game_end_reason] = int(reasons.get(state.game_end_reason, 0)) + 1
		var vp := Scoring.library_card_vp(state)
		var winners := Scoring.winners(state, vp[0], vp[1])
		if fast_pid != "":
			var best_other := -INF
			for pid: String in state.turn_order:
				if pid != fast_pid:
					best_other = maxf(best_other, BotPlayer.final_vp(state, pid))
			fast_margin += BotPlayer.final_vp(state, fast_pid) - best_other
		if fast_pid != "" and winners.has(fast_pid):
			fast_wins += 1.0 / winners.size()
		for seat in range(n):
			var pid: String = state.turn_order[seat]
			seat_vp[seat] += BotPlayer.final_vp(state, pid)
			if winners.has(pid):
				seat_wins[seat] += 1.0 / winners.size()
			for cid: String in (bought.get(pid, {}) as Dictionary).keys():
				if not card_games.has(cid):
					card_games[cid] = [0, 0.0]
				card_games[cid][0] += 1
				if winners.has(pid):
					card_games[cid][1] += 1.0 / winners.size()
		print("игра %d (seed %d): раундов %d, конец %s, VP %s, победил %s, отклонено %d" % [
			g + 1, seed_value, int(float(turns) / n), state.game_end_reason,
			str(state.turn_order.map(func(pid): return "%s=%d" % [pid, BotPlayer.final_vp(state, pid)])),
			str(winners), int(res["rejected"])])

	var done := games - unfinished
	print("\n=== итог: %d игр, %d игроков, режим %s, %.1f с ===" % [
		games, n, args["mode"], (Time.get_ticks_msec() - t0) / 1000.0])
	if done == 0:
		print("ни одна партия не закончилась")
		quit(1)
		return
	for seat in range(n):
		print("место %d: побед %.0f%%, средние VP %.1f" % [seat + 1, 100.0 * seat_wins[seat] / done, seat_vp[seat] / done])
	print("средняя длина: %.1f раунда; причины конца: %s" % [total_rounds / done, str(reasons)])
	print("отклонено намерений всего: %d; не доиграно: %d" % [total_rejected, unfinished])
	if args.get("fast", "0") == "1":
		print("быстрый бот против полных: побед %.0f%% (ожидание %.0f%%)" % [100.0 * fast_wins / done, 100.0 / n])
	if args.get("search", "0") == "1":
		print("искатель против соперников (%s): побед %.0f%% (ожидание %.0f%%), VP в среднем %+.1f к лучшему сопернику; поиск менял выбор Bot-1 в %d из %d решений" % [args.get("vs", "bot1"), 100.0 * fast_wins / done, 100.0 / n, fast_margin / done, BotSearch.deviations, BotSearch.searches])
		print("планов хода: %d, перепланирований посреди хода: %d" % [BotPlan.plans_searched, BotPlan.replans])

	var rows := []
	for cid: String in card_games.keys():
		var c: Array = card_games[cid]
		if int(c[0]) >= maxi(3, done / 5):
			rows.append([CardLibrary.card_data(cid).get("name", cid), int(c[0]), 100.0 * float(c[1]) / int(c[0])])
	rows.sort_custom(func(a, b): return a[2] > b[2])
	if not rows.is_empty():
		print("\nкарта: в скольких играх куплена / %% побед купившего (ожидание %.0f%%)" % (100.0 / n))
		for r in rows:
			print("  %-28s %3d  %5.1f%%" % r)
	quit(0)
