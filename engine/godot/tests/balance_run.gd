extends SceneTree

## Массовый прогон партий бот против бота для оценки баланса.
##
## Подборщик раскидывает партии по нескольким процессам Godot (процессы, а не
## потоки, — в потоках движок упирается в общую блокировку), каждый процесс
## пишет по строке JSON на партию, затем всё сводится в один JSON:
## места за столом, полуколоды, карты.
##
## Запуск:
##   godot --headless --path engine/godot --script res://tests/balance_run.gd -- name=std2 players=2 mode=standard games=2400 procs=8
## bot=search budget=200 — вместо Bot-1 играет искатель (Bot-4, один поток на
##   процесс) — медленно, для перепроверки находок.
## Итог: Claude outputs/balance/<name>.json (рядом — сырые партии <name>_games.jsonl).

const OUT_DIR := "res://../../Claude outputs/balance"


func _initialize() -> void:
	var args := {"mode": "standard", "players": "2", "games": "100", "procs": "8", "seed": "1",
		"bot": "bot1", "budget": "200", "name": "run", "role": "driver"}
	for a: String in OS.get_cmdline_user_args():
		var i := a.find("=")
		if i > 0:
			args[a.substr(0, i)] = a.substr(i + 1)
	if args["role"] == "worker":
		_worker(args)
	else:
		_driver(args)
	quit(0)


# --- рабочий процесс: партии и строка JSON на каждую --------------------------

func _worker(args: Dictionary) -> void:
	var n := int(args["players"])
	var ids := GameScreen.player_ids_for(n)
	var out := FileAccess.open(String(args["out"]), FileAccess.WRITE)
	BotSearch.threads = 1
	# Проверка гипотез: leader=0 — боты не выделяют лидера среди соперников.
	if args.has("leader"):
		BotPlayer.W_LEADER = float(args["leader"])
	for s in range(int(args["from"]), int(args["from"]) + int(args["count"])):
		var state := GameSetup.new_game(ids, s, [], false, true, true, String(args["mode"]))
		var server := GameServer.new(state, true, true, args["bot"] == "search")
		server.build_views = false
		var bought := {}
		for pid: String in ids:
			bought[pid] = {}
		var turns := 0
		var guard := 0
		var in_row := 0
		while not state.game_over and guard < 20000:
			guard += 1
			var actor := BotPlayer.acting_player(server)
			var intent: Intent
			if in_row > 0:
				intent = BotPlayer.fallback_intent(server, actor) if in_row <= 2 else Intent.end_turn(state.current_player())
			elif args["bot"] == "search":
				intent = BotSearch.next_intent(server, actor, int(args["budget"]))
			else:
				intent = BotPlayer.next_intent(server, actor)
			var res: Dictionary = server.apply_intent(intent)
			if int(res["error"]) != GameServer.Error.OK:
				in_row += 1
				continue
			in_row = 0
			for e: Dictionary in res["events"]:
				if e["type"] in ["recruit", "recruit_supply"]:
					var b: Dictionary = bought[String(e["player_id"])]
					var cid := String(e["card_id"])
					b[cid] = int(b.get(cid, 0)) + 1
				elif e["type"] == "turn_ended":
					turns += 1
		if not state.game_over:
			continue
		var vp_maps := Scoring.library_card_vp(state)
		var vp := {}
		for pid: String in ids:
			vp[pid] = BotPlayer.final_vp(state, pid)
		out.store_line(JSON.stringify({
			"seed": s, "players": n, "mode": args["mode"], "decks": Array(state.half_decks),
			"order": Array(state.turn_order), "rounds": float(turns) / n, "reason": state.game_end_reason,
			"vp": vp, "winners": Array(Scoring.winners(state, vp_maps[0], vp_maps[1])), "bought": bought,
		}))
		out.flush()
	out.close()


# --- подборщик: процессы и сводка -------------------------------------------

func _driver(args: Dictionary) -> void:
	var dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var games := int(args["games"])
	var procs := mini(int(args["procs"]), games)
	var per := ceili(float(games) / procs)
	var t0 := Time.get_ticks_msec()
	var jobs: Array = []
	for k in range(procs):
		var start := int(args["seed"]) + k * per
		var count := mini(per, int(args["seed"]) + games - start)
		if count <= 0:
			break
		var part := dir + "/%s_part%d.jsonl" % [args["name"], k]
		var pid := OS.create_process(OS.get_executable_path(), [
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/balance_run.gd", "--", "role=worker",
			"players=" + String(args["players"]), "mode=" + String(args["mode"]),
			"bot=" + String(args["bot"]), "budget=" + String(args["budget"]),
			"from=%d" % start, "count=%d" % count, "out=" + part] + (["leader=" + String(args["leader"])] if args.has("leader") else []))
		jobs.append([pid, part])
	var records: Array = []
	var all := FileAccess.open(dir + "/%s_games.jsonl" % args["name"], FileAccess.WRITE)
	for job: Array in jobs:
		while OS.is_process_running(int(job[0])):
			OS.delay_msec(500)
		for line: String in FileAccess.get_file_as_string(String(job[1])).split("\n", false):
			var rec = JSON.parse_string(line)
			if rec is Dictionary:
				records.append(rec)
				all.store_line(line)
		DirAccess.remove_absolute(String(job[1]))
	all.close()
	var summary := summarize(records)
	summary["name"] = args["name"]
	summary["bot"] = args["bot"]
	summary["seconds"] = (Time.get_ticks_msec() - t0) / 1000.0
	var f := FileAccess.open(dir + "/%s.json" % args["name"], FileAccess.WRITE)
	f.store_string(JSON.stringify(summary, "\t"))
	f.close()
	print("%s: %d партий за %.0f с" % [args["name"], records.size(), summary["seconds"]])
	for s: Dictionary in summary["seats"]:
		print("  место %d: побед %.1f%% (%.1f–%.1f), VP %.1f" % [s["seat"], s["win"] * 100, s["lo"] * 100, s["hi"] * 100, s["vp"]])


## Сводка по партиям: места, полуколоды, карты. Проценты побед — с 95%
## интервалом Уилсона (lo..hi): если ожидание 1/n вне интервала, отклонение
## вряд ли случайно.
static func summarize(records: Array) -> Dictionary:
	var deck_of := {}
	for deck: String in ["drow", "dragons", "demons", "elementals", "aberrations", "undead", "celestial", "shadow"]:
		for cid: String in GameSetup.expand_half_deck(deck):
			deck_of[cid] = deck
	var n := int(records[0]["players"]) if not records.is_empty() else 2
	var seats := []
	for i in range(n):
		seats.append({"seat": i + 1, "wins": 0.0, "vp": 0.0})
	var rounds := 0.0
	var reasons := {}
	var decks := {}   # полуколода -> {games, buys, win_buys}
	var cards := {}   # карта -> {avail, bought_games, buyer_games, buyer_wins, copies}
	var all_buys := 0.0
	var all_win_buys := 0.0
	for rec: Dictionary in records:
		rounds += float(rec["rounds"])
		reasons[rec["reason"]] = int(reasons.get(rec["reason"], 0)) + 1
		var winners: Array = rec["winners"]
		var order: Array = rec["order"]
		for i in range(order.size()):
			var pid: String = order[i]
			seats[i]["vp"] += float(rec["vp"][pid])
			if winners.has(pid):
				seats[i]["wins"] += 1.0 / winners.size()
		var present := {}
		for d: String in rec["decks"]:
			present[d] = true
		for d: String in present.keys():
			if not decks.has(d):
				decks[d] = {"games": 0, "buys": 0.0, "win_buys": 0.0, "vp": 0.0}
			decks[d]["games"] += 1
		# Какие карты были доступны: все карты полуколод партии + запас.
		var avail := {}
		for cid: String in deck_of.keys():
			if present.has(deck_of[cid]):
				avail[cid] = true
		for cid: String in ["48343", "48340"]:
			avail[cid] = true
		for cid: String in avail.keys():
			if not cards.has(cid):
				cards[cid] = {"avail": 0, "bought_games": 0, "buyer_games": 0, "buyer_wins": 0.0, "copies": 0}
			cards[cid]["avail"] += 1
		var bought_here := {}
		for pid: String in order:
			var share := 1.0 / winners.size() if winners.has(pid) else 0.0
			var b: Dictionary = rec["bought"][pid]
			for cid: String in b.keys():
				var copies := int(b[cid])
				if not cards.has(cid):
					cards[cid] = {"avail": 1, "bought_games": 0, "buyer_games": 0, "buyer_wins": 0.0, "copies": 0}
				cards[cid]["buyer_games"] += 1
				cards[cid]["buyer_wins"] += share
				cards[cid]["copies"] += copies
				bought_here[cid] = true
				all_buys += copies
				all_win_buys += copies * share
				var d: String = deck_of.get(cid, "supply")
				if decks.has(d):
					decks[d]["buys"] += copies
					decks[d]["win_buys"] += copies * share
		for cid: String in bought_here.keys():
			cards[cid]["bought_games"] += 1
	var games := records.size()
	for s: Dictionary in seats:
		var ci := _wilson(s["wins"], games)
		s["win"] = s["wins"] / maxf(1.0, games)
		s["lo"] = ci[0]
		s["hi"] = ci[1]
		s["vp"] = s["vp"] / maxf(1.0, games)
	var base_share := all_win_buys / maxf(1.0, all_buys)
	var deck_rows := []
	for d: String in decks.keys():
		var row: Dictionary = decks[d]
		var share: float = row["win_buys"] / maxf(1.0, row["buys"])
		deck_rows.append({"deck": d, "games": row["games"], "buys": row["buys"],
			"win_share": share, "lift": share / maxf(0.0001, base_share)})
	deck_rows.sort_custom(func(a, b): return a["lift"] > b["lift"])
	var card_rows := []
	for cid: String in cards.keys():
		var c: Dictionary = cards[cid]
		var win: float = c["buyer_wins"] / maxf(1.0, c["buyer_games"])
		var ci := _wilson(c["buyer_wins"], c["buyer_games"])
		card_rows.append({"id": cid, "name": CardLibrary.card_data(cid).get("name", cid),
			"deck": deck_of.get(cid, "supply"), "cost": CardLibrary.card_cost(cid),
			"avail": c["avail"], "pick_rate": float(c["bought_games"]) / maxf(1.0, c["avail"]),
			"buyer_games": c["buyer_games"], "win": win, "lo": ci[0], "hi": ci[1],
			"copies": float(c["copies"]) / maxf(1.0, c["buyer_games"])})
	card_rows.sort_custom(func(a, b): return a["win"] > b["win"])
	return {"games": games, "players": n, "mode": records[0]["mode"] if games > 0 else "",
		"rounds": rounds / maxf(1.0, games), "reasons": reasons, "seats": seats,
		"expected": 1.0 / n, "base_win_share": base_share, "decks": deck_rows, "cards": card_rows}


## 95% интервал Уилсона для доли побед wins из total.
static func _wilson(wins: float, total: float) -> Array:
	if total <= 0.0:
		return [0.0, 1.0]
	var z := 1.96
	var p := wins / total
	var denom := 1.0 + z * z / total
	var centre := (p + z * z / (2.0 * total)) / denom
	var half := z * sqrt(p * (1.0 - p) / total + z * z / (4.0 * total * total)) / denom
	return [maxf(0.0, centre - half), minf(1.0, centre + half)]
