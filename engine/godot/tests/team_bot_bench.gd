extends SceneTree

## Стенд Team-4: боты 2 на 2 «за команду» против ботов «по-старому» (союзник
## для них — соперник, BotPlayer.selfish). Половина партий — командные за
## красных, половина — за синих, чтобы место за столом не решало.
## Запуск:
##   godot --headless --path engine/godot --script res://tests/team_bot_bench.gd -- games=40 fast


func _initialize() -> void:
	var games := 20
	var fast := false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("games="):
			games = int(a.get_slice("=", 1))
		elif a == "fast":
			fast = true
	var ids := GameScreen.player_ids_for(4)
	var wins := 0.0
	var margin := 0
	var t0 := Time.get_ticks_msec()
	for g in range(games):
		var team_side := "red" if g % 2 == 0 else "blue"
		var state := GameSetup.new_game(ids, 1000 + g / 2, [], false, true, true, GameSetup.MODE_STANDARD, true)
		BotPlayer.selfish.clear()
		for pid: String in ids:
			if state.side_of(pid) != team_side:
				BotPlayer.selfish[pid] = true
		var server := GameServer.new(state)
		var steps := 0
		while not state.game_over and steps < 20000:
			steps += 1
			server.apply_intent(BotPlayer.next_intent(server, BotPlayer.acting_player(server), fast))
		var vp := Scoring.library_card_vp(state)
		var winners := Scoring.winners(state, vp[0], vp[1])
		var mine := Scoring.final_score(state, state.members_of(team_side)[0], vp[0], vp[1])
		var other_side := "blue" if team_side == "red" else "red"
		var theirs := Scoring.final_score(state, state.members_of(other_side)[0], vp[0], vp[1])
		margin += mine - theirs
		var won := winners.any(func(w): return state.side_of(w) == team_side)
		var lost := winners.any(func(w): return state.side_of(w) == other_side)
		wins += 1.0 if won and not lost else (0.5 if won and lost else 0.0)
		print("партия %d: командные за %s, %d : %d" % [g + 1, team_side, mine, theirs])
	BotPlayer.selfish.clear()
	print("=== командные боты: %.1f побед из %d (%.0f%%), средний перевес %.1f VP, %d с ===" % [
		wins, games, 100.0 * wins / games, float(margin) / games, (Time.get_ticks_msec() - t0) / 1000])
	quit()
