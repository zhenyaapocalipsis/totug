extends SceneTree

## Сила карт для бота (этап Bot-8): сколько карта на самом деле приносит за
## розыгрыш, а не сколько стоит.
##
## Позиции берутся из партий Bot-1 (2 и 4 игрока, все полуколоды): начало
## хода, рука набрана, ничего не сыграно. В каждой позиции ход доигрывается
## Bot-1 до покупок дважды — с рукой как есть и с рукой плюс проверяемая
## карта (одинаковый RNG), и сравнивается итог: оценка доски
## (BotPlayer.evaluate), VP карт (Promote), Influence (по цене Power — из
## замера Soldier) и карты, которые пришлось сбросить соперникам.
## Сила = средняя разница, в VP-эквиваленте; r — то же в ресурсах
## (Noble = Soldier = 1).
##
## Запуск:
##   godot --headless --path engine/godot --script res://tests/card_strength.gd -- positions=400 procs=8
## Итог: res://data/bot/card_strength.json (его читает BotPlayer).

const OUT := "res://data/bot/card_strength.json"
const SOLDIER := "48344"
const NOBLE := "48342"
## Сколько стоит одна карта, сброшенная соперником, в долях средней карты.
const RIVAL_CARD := 1.0


func _initialize() -> void:
	var args := {"positions": "400", "procs": "8", "seed": "500001", "role": "driver"}
	for a: String in OS.get_cmdline_user_args():
		var i := a.find("=")
		if i > 0:
			args[a.substr(0, i)] = a.substr(i + 1)
	if args["role"] == "worker":
		_worker(args)
	else:
		_driver(args)
	quit(0)


## Все карты, которые бывают в партии: полуколоды (с New Era), стопки,
## стартовая колода.
static func all_cards() -> Array[String]:
	var was := GameSetup.include_wip
	GameSetup.include_wip = true
	var seen := {}
	for deck: String in GameSetup.available_half_decks():
		for cid: String in GameSetup.expand_half_deck(deck):
			seen[cid] = true
	GameSetup.include_wip = was
	for cid: String in GameSetup.starting_deck():
		seen[cid] = true
	for cid: String in Supplies.PURCHASABLE:
		seen[cid] = true
	seen[Supplies.INSANE_OUTCAST] = true
	var out: Array[String] = []
	out.assign(seen.keys())
	out.sort()
	return out


# --- рабочий процесс --------------------------------------------------------

func _worker(args: Dictionary) -> void:
	GameSetup.include_wip = true
	var cards := all_cards()
	var sums := {}  # cid -> [n, board, influence, rival_cards]
	for cid: String in cards:
		sums[cid] = [0, 0.0, 0.0, 0.0]
	var want := int(args["count"])
	var got := 0
	var s := int(args["from"])
	while got < want:
		for pos: GameServer in _positions(s):
			if got >= want:
				break
			got += 1
			_measure(pos, cards, sums)
		s += 1
	var f := FileAccess.open(String(args["out"]), FileAccess.WRITE)
	f.store_string(JSON.stringify(sums))
	f.close()


## Несколько позиций из одной партии Bot-1: начало хода с 3-го круга, через
## раз, чтобы позиции одной партии не были слишком похожи.
static func _positions(s: int) -> Array:
	var n := 2 if s % 2 == 0 else 4
	var mode := GameSetup.MODE_STANDARD if n == 2 else GameSetup.MODE_RANDOM_4
	var ids := GameScreen.player_ids_for(n)
	var state := GameSetup.new_game(ids, s, [], false, true, true, mode)
	var server := GameServer.new(state, true, true, false)
	server.build_views = false
	var out: Array = []
	var turns := 0
	var guard := 0
	var in_row := 0
	var last_turn_player := ""
	while not state.game_over and guard < 20000:
		guard += 1
		var cur := state.current_player()
		if server.is_quiet() and cur != last_turn_player and state.players[cur].deck.played_pile.is_empty():
			last_turn_player = cur
			turns += 1
			if turns > 2 * n and turns % 3 == 0:
				out.append(server.clone())
		var actor := BotPlayer.acting_player(server)
		var intent: Intent = BotPlayer.next_intent(server, actor, true) if in_row == 0 \
			else BotPlayer.fallback_intent(server, actor)
		if in_row > 2:
			intent = Intent.end_turn(cur)
		if int(server.apply_intent(intent)["error"]) != GameServer.Error.OK:
			in_row += 1
		else:
			in_row = 0
	return out


## Одна позиция: ход без карты и с каждой картой, разница итогов.
static func _measure(pos: GameServer, cards: Array[String], sums: Dictionary) -> void:
	var me := pos.state.current_player()
	var ctx := BotPlayer._context(pos.state, me)
	ctx["opp_w"] = _opp_weights(pos.state, me)
	var base := _play(pos, me, "", ctx)
	for cid: String in cards:
		var r := _play(pos, me, cid, ctx)
		var row: Array = sums[cid]
		row[0] += 1
		row[1] += r[0] - base[0]
		row[2] += r[1] - base[1]
		row[3] += r[2] - base[2]


## Доиграть ход me на копии (с картой cid в руке, если не пусто) до покупок.
## Итог: [оценка доски + VP карт, Influence, взвешенные карты, сброшенные
## соперниками].
static func _play(pos: GameServer, me: String, cid: String, ctx: Dictionary) -> Array:
	var sim := pos.clone()
	var st := sim.state
	if cid != "":
		st.players[me].deck.hand.append(cid)
	var vp0 := _card_vp(st, me)
	var rivals0 := {}
	for pid: String in st.turn_order:
		rivals0[pid] = [st.players[pid].deck.hand.size(), _outcasts(st, pid), _card_vp(st, pid)]
	var guard := 0
	while not st.game_over and guard < 400:
		guard += 1
		var actor := BotPlayer.acting_player(sim)
		var intent: Intent = BotPlayer.next_intent(sim, actor)
		if actor == me and not sim.resolver.is_waiting() and intent.type in [
				Intent.Type.ACTION_RECRUIT, Intent.Type.ACTION_RECRUIT_SUPPLY, Intent.Type.END_TURN]:
			break
		if int(sim.apply_intent(intent)["error"]) != GameServer.Error.OK:
			break
	var influence := float(st.players[me].influence)
	# Конец хода: эффекты "At end of turn" (Promote сыгранных карт) — их VP
	# тоже заслуга карты. Вопросы конца хода решает Bot-1.
	if not st.game_over and int(sim.apply_intent(Intent.end_turn(me))["error"]) == GameServer.Error.OK:
		while not st.game_over and guard < 600 and sim.resolver.is_waiting():
			guard += 1
			var actor := BotPlayer.acting_player(sim)
			if int(sim.apply_intent(BotPlayer.next_intent(sim, actor))["error"]) != GameServer.Error.OK:
				break
	# Соперникам: сброшенные из руки и подкинутые Insane Outcast — как
	# потерянные карты; их VP карт — как есть.
	var lost := 0.0
	var board := BotPlayer.evaluate(st, ctx) + _card_vp(st, me) - vp0
	var weights: Dictionary = ctx["opp_w"]
	for pid: String in weights.keys():
		var was: Array = rivals0[pid]
		var w := float(weights[pid])
		lost += w * float(int(was[0]) - st.players[pid].deck.hand.size() + _outcasts(st, pid) - int(was[1]))
		board += w * (float(was[2]) - _card_vp(st, pid))
	return [board, influence, lost]


static func _outcasts(st: GameState, pid: String) -> int:
	return st.players[pid].deck.cards_outside_inner_circle().count(Supplies.INSANE_OUTCAST)


static func _card_vp(st: GameState, pid: String) -> float:
	var b := Scoring.breakdown(st, pid)
	return float(b["deck"]) + float(b["inner_circle"])


static func _opp_weights(st: GameState, me: String) -> Dictionary:
	var w := {}
	var opps := st.turn_order.size() - 1
	for pid: String in st.turn_order:
		if pid != me:
			w[pid] = 1.0 / opps
	return w


# --- подборщик ------------------------------------------------------------

func _driver(args: Dictionary) -> void:
	var procs := int(args["procs"])
	var total := int(args["positions"])
	var per := ceili(float(total) / procs)
	var t0 := Time.get_ticks_msec()
	var jobs: Array = []
	for k in range(procs):
		var part := OS.get_user_data_dir() + "/card_strength_part%d.json" % k
		var pid := OS.create_process(OS.get_executable_path(), [
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/card_strength.gd", "--", "role=worker",
			"from=%d" % (int(args["seed"]) + k * 1000), "count=%d" % per, "out=" + part])
		jobs.append([pid, part])
	var sums := {}
	for job: Array in jobs:
		while OS.is_process_running(int(job[0])):
			OS.delay_msec(500)
		var part = JSON.parse_string(FileAccess.get_file_as_string(String(job[1])))
		DirAccess.remove_absolute(String(job[1]))
		if not part is Dictionary:
			push_error("нет итога процесса " + String(job[1]))
			continue
		for cid: String in part.keys():
			if not sums.has(cid):
				sums[cid] = [0, 0.0, 0.0, 0.0]
			for i in range(4):
				sums[cid][i] += float(part[cid][i])
	# Цена Influence = цена Power: Noble (+1 Influence) стоит столько же,
	# сколько Soldier (+1 Power) — в стартовой колоде они на равных.
	var s_row: Array = sums[SOLDIER]
	var ival := float(s_row[1]) / maxf(1.0, float(s_row[0]))
	var cards := {}
	var raw := {}
	for cid: String in sums.keys():
		var row: Array = sums[cid]
		var n := maxf(1.0, float(row[0]))
		raw[cid] = (float(row[1]) + ival * float(row[2])) / n
	var avg_card := 0.0
	for cid: String in GameSetup.starting_deck():
		avg_card += float(raw[cid])
	avg_card /= GameSetup.starting_deck().size()
	for cid: String in sums.keys():
		var row: Array = sums[cid]
		var n := maxf(1.0, float(row[0]))
		var s := float(raw[cid]) + RIVAL_CARD * avg_card * float(row[3]) / n
		cards[cid] = {"name": CardLibrary.card_data(cid).get("name", cid), "s": snappedf(s, 0.001),
			"r": snappedf(s / maxf(0.001, ival), 0.01), "n": int(row[0])}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/bot"))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"ival": snappedf(ival, 0.0001), "positions": total, "cards": cards}, "\t", true))
	f.close()
	print("сила карт: %d позиций за %.0f с, 1 ресурс = %.3f VP" % [total, (Time.get_ticks_msec() - t0) / 1000.0, ival])
	var ids: Array = cards.keys()
	ids.sort_custom(func(a, b): return float(cards[a]["r"]) > float(cards[b]["r"]))
	for cid: String in ids:
		var c: Dictionary = cards[cid]
		print("  %5.2f  %s (цена %s)" % [c["r"], c["name"], str(CardLibrary.card_cost(cid))])
