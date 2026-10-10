extends SceneTree

## Подбор весов оценки бота (этап Bot-5) партиями Bot-1 против Bot-1.
##
## Веса (BotPlayer.get_weights) подбираются покоординатно: каждый вес по
## очереди пробуется больше и меньше текущего; новый набор играет против
## текущего на одних и тех же сидах, каждый сид — дважды с обменом мест.
## Изменение принимается, если новый набор выиграл не меньше ACCEPT партий
## и в среднем набрал больше VP. Шаг уменьшается после каждого прохода.
## Партии идут в нескольких процессах Godot параллельно (потоки упираются в
## общую блокировку движка, процессы — нет).
##
## Запуск (подборщик):
##   godot --headless --path engine/godot --script res://tests/bot_tune.gd -- sweeps=3 seeds=80 procs=8
## Итог: лучшие веса в user://bot_tune/best.json и в выводе; прогресс — в
## user://bot_tune/log.txt.
## Рабочий процесс (его запускает подборщик):
##   ... -- mode=worker a=<файл весов> b=<файл весов> from=<сид> count=<сидов> out=<файл>

const DIR := "user://bot_tune"
const ACCEPT := 0.54
const START_STEP := 0.35


func _initialize() -> void:
	var args := {"mode": "driver", "sweeps": "3", "seeds": "80", "procs": "8", "players": "2", "seed": "100000"}
	for a: String in OS.get_cmdline_user_args():
		var i := a.find("=")
		if i > 0:
			args[a.substr(0, i)] = a.substr(i + 1)
	if args["mode"] == "worker":
		_worker(args)
	else:
		_driver(args)
	quit(0)


# --- рабочий процесс ------------------------------------------------------

func _worker(args: Dictionary) -> void:
	var a: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args["a"]))
	var b: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args["b"]))
	var n := int(args["players"])
	var pids: Array[String] = []
	for i in range(n):
		pids.append("p%d" % (i + 1))
	var wins_a := 0.0
	var games := 0
	var margin := 0.0
	for s in range(int(args["from"]), int(args["from"]) + int(args["count"])):
		# Сид дважды: набор A за первым игроком и за вторым.
		for a_seat in range(2):
			var a_pid: String = pids[a_seat]
			var state := GameSetup.new_game(pids, s, [], false, true, true)
			var server := GameServer.new(state, true, true, false)
			server.build_views = false
			var guard := 0
			var in_row := 0
			while not state.game_over and guard < 20000:
				guard += 1
				var actor := BotPlayer.acting_player(server)
				BotPlayer.set_weights(a if actor == a_pid else b)
				var intent: Intent = BotPlayer.next_intent(server, actor) if in_row == 0 \
					else BotPlayer.fallback_intent(server, actor)
				if in_row > 2:
					intent = Intent.end_turn(state.current_player())
				if int(server.apply_intent(intent)["error"]) != GameServer.Error.OK:
					in_row += 1
				else:
					in_row = 0
			if not state.game_over:
				continue
			var vp := Scoring.library_card_vp(state)
			var winners := Scoring.winners(state, vp[0], vp[1])
			games += 1
			if winners.has(a_pid):
				wins_a += 1.0 / winners.size()
			var best_other := -INF
			for pid: String in pids:
				if pid != a_pid:
					best_other = maxf(best_other, BotPlayer.final_vp(state, pid))
			margin += BotPlayer.final_vp(state, a_pid) - best_other
	var f := FileAccess.open(args["out"], FileAccess.WRITE)
	f.store_string(JSON.stringify({"wins": wins_a, "games": games, "margin": margin}))
	f.close()


# --- подборщик ------------------------------------------------------------

var _log: FileAccess


func _driver(args: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_log = FileAccess.open(DIR + "/log.txt", FileAccess.WRITE)
	var current := BotPlayer.get_weights()
	_say("старт: %s" % JSON.stringify(current))
	var step := START_STEP
	var seeds := int(args["seeds"])
	for sweep in range(int(args["sweeps"])):
		# Новые сиды на каждый проход: веса не подгоняются под одни и те же партии.
		var from := int(args["seed"]) + sweep * 10000
		_say("\nпроход %d, шаг %.0f%%, %d партий на пробу" % [sweep + 1, step * 100.0, seeds * 2])
		for name: String in current.keys():
			for dir: float in [1.0, -1.0]:
				var trial := current.duplicate()
				trial[name] = float(current[name]) * (1.0 + dir * step)
				var r := _match(trial, current, from, seeds, args)
				var rate: float = r["wins"] / maxf(1.0, r["games"])
				var avg: float = r["margin"] / maxf(1.0, r["games"])
				var ok := rate >= ACCEPT and avg > 0.0
				_say("  %-16s %7.3f -> %7.3f: побед %4.1f%%, VP %+5.1f%s" % [name, current[name], trial[name],
					100.0 * rate, avg, "  ПРИНЯТО" if ok else ""])
				if ok:
					current = trial
					break  # в другую сторону этот вес уже не пробуем
		step *= 0.6
		_save(current)
	_say("\nитог: %s" % JSON.stringify(current))
	_log.close()


## Набор a против набора b: seeds сидов × 2 места, поровну по процессам.
func _match(a: Dictionary, b: Dictionary, from: int, seeds: int, args: Dictionary) -> Dictionary:
	var fa := DIR + "/a.json"
	var fb := DIR + "/b.json"
	_write(fa, a)
	_write(fb, b)
	var procs := mini(int(args["procs"]), seeds)
	var per := ceili(float(seeds) / procs)
	var running: Array = []  # [pid процесса, файл результата]
	for k in range(procs):
		var start := from + k * per
		var count := mini(per, from + seeds - start)
		if count <= 0:
			break
		var out := ProjectSettings.globalize_path(DIR + "/r%d.json" % k)
		DirAccess.remove_absolute(out)
		var pid := OS.create_process(OS.get_executable_path(), [
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/bot_tune.gd", "--", "mode=worker",
			"a=" + ProjectSettings.globalize_path(fa), "b=" + ProjectSettings.globalize_path(fb),
			"from=%d" % start, "count=%d" % count, "players=" + String(args["players"]), "out=" + out])
		running.append([pid, out])
	var total := {"wins": 0.0, "games": 0.0, "margin": 0.0}
	for job: Array in running:
		while OS.is_process_running(int(job[0])):
			OS.delay_msec(100)
		var text := FileAccess.get_file_as_string(String(job[1]))
		if text.is_empty():
			_say("    процесс не вернул результат: %s" % job[1])
			continue
		var r: Dictionary = JSON.parse_string(text)
		for key: String in total.keys():
			total[key] += float(r[key])
	return total


func _write(path: String, w: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(w))
	f.close()


func _save(w: Dictionary) -> void:
	_write(DIR + "/best.json", w)


func _say(text: String) -> void:
	print(text)
	_log.store_line(text)
	_log.flush()
