class_name BotSearch
extends RefCounted

## Сильный бот (этап Bot-3): ISMCTS на один ход вглубь поверх Bot-1.
##
## Bot-1 предлагает несколько лучших по своей оценке вариантов (ranked_intents):
## куда тратить Power, что купить (или ничего), как ответить на вопрос карты.
## Для каждого варианта бот много раз проигрывает будущее в уме (BotSim):
##   1. копия партии с новой догадкой о скрытом (determinize) — бот не знает
##      чужих рук и порядка колод, а перебирает правдоподобные варианты;
##   2. в копии делается проверяемый ход;
##   3. копия доигрывается быстрыми ботами до начала следующего хода бота —
##      так в оценку попадают и его же следующие действия, и ответ соперников;
##   4. позиция оценивается (BotSim.value: 0..1).
## Все варианты проверяются на одних и тех же догадках (общий сид на круг):
## тогда разница между вариантами — от самого хода, а не от удачи в добор.
## Слабые варианты отсеиваются по ходу (successive halving); побеждает лучший
## средний результат, при равенстве — выбор Bot-1.
##
## Время: budget_ms на одно решение. Решения без выбора (одна карта в руке,
## один допустимый ответ) — сразу, без поиска.

const DEFAULT_BUDGET_MS := 800
## Сколько вариантов Bot-1 проверять на решение (без "ничего не покупать").
static var candidates := 5
## Главная фаза хода — планом целиком (BotPlan); false — по одному решению.
## Выключено: в матче против поиска по одному решению план проиграл
## (42% побед, −3.4 VP за 24 партии) — пересчёт на каждом шаге сильнее.
static var plan_turns := false
## Во сколько раз больше времени на поиск плана, чем на одно решение.
const PLAN_BUDGET_FACTOR := 3

## Сколько своих следующих ходов доигрывать в уме (1 — до начала следующего).
## 2 заметно сильнее 1: 88% побед у Bot-1 против 63% (24 партии на двоих).
static var horizon := 2
## Сколько проверок вести параллельно (0 — по числу ядер, см. worker_count).
## Все проверки независимы: у каждой своя копия партии.
static var threads := 0
## Статистика для прогонов: сколько решений искали и сколько раз поиск
## выбрал не то, что выбрал бы Bot-1.
static var searches := 0
static var deviations := 0


## Ход бота-искателя за pid (null — сейчас действует не он).
## seed — откуда брать догадки (одинаковый seed — одинаковое решение).
## max_rounds > 0 — вместо времени ровно столько кругов проверок (тесты:
## результат не зависит от скорости компьютера).
static func next_intent(server: GameServer, pid: String, budget_ms: int = DEFAULT_BUDGET_MS, seed: int = 0, max_rounds: int = 0) -> Intent:
	if BotPlayer.acting_player(server) != pid:
		return null
	# Главная фаза (карты разыграны) — планом на весь остаток хода (Bot-5).
	# Один поиск вместо нескольких, поэтому времени на него больше.
	if plan_turns and BotPlan.is_plan_phase(server, pid):
		return BotPlan.next_step(server, pid, budget_ms * PLAN_BUDGET_FACTOR, seed, max_rounds)
	# Варианты — на копии: оценка Bot-1 на миг переставляет войска, а поиск
	# может идти в отдельном потоке, пока экран читает настоящую партию.
	var options := BotPlayer.ranked_intents(server.clone(), pid, candidates)
	if options.size() <= 1:
		return options[0] if not options.is_empty() else BotPlayer.fallback_intent(server, pid)
	var pick := _search(server, pid, options.map(func(o): return [o]), budget_ms, seed, max_rounds)
	searches += 1
	if pick != 0:
		deviations += 1
	return options[pick]


## Номер лучшего варианта. Круги: в каждом круге каждый живой вариант
## проверяется на одной общей догадке; после каждого раунда отсева худшая
## половина выбывает. Минимум 2 круга, даже если время вышло.
static func _search(server: GameServer, me: String, candidates: Array, budget_ms: int, seed: int, max_rounds: int = 0) -> int:
	var start := Time.get_ticks_msec()
	var alive: Array[int] = []
	for i in range(candidates.size()):
		alive.append(i)
	var sums := []
	sums.resize(candidates.size())
	sums.fill(0.0)
	var counts := []
	counts.resize(candidates.size())
	counts.fill(0)
	var rounds := 0
	var rng := RandomNumberGenerator.new()
	# Сид по открытому (RNG партии — скрытое, его не трогаем).
	rng.seed = seed if seed != 0 else hash([me, server.state.market.display, server.state.troops, server.state.players[me].deck.hand, candidates.size()])
	var workers := worker_count()
	# Сколько кругов до следующего отсева: растёт, чтобы оставшимся досталось
	# больше проверок.
	var next_cut := 2
	while alive.size() > 1:
		# Пачка кругов разом — столько, чтобы занять все ядра (Bot-4).
		var batch := maxi(1, ceili(float(workers) / alive.size()))
		if max_rounds > 0:
			batch = mini(batch, max_rounds - rounds)
		var seeds: Array[int] = []
		for r in range(batch):
			seeds.append(rng.randi())
		var tasks: Array = []  # [номер варианта, сид]
		for s: int in seeds:
			for i: int in alive:
				tasks.append([i, s])
		var results := _run_tasks(server, me, candidates, tasks, workers)
		# Складываем в одном и том же порядке — итог не зависит от того,
		# какой поток закончил первым.
		for t in range(tasks.size()):
			sums[tasks[t][0]] += results[t]
			counts[tasks[t][0]] += 1
		rounds += batch
		var spent := Time.get_ticks_msec() - start
		if max_rounds > 0:
			if rounds >= max_rounds:
				break
		elif rounds >= 2 and spent >= budget_ms:
			break
		if rounds >= next_cut and alive.size() > 2:
			alive.sort_custom(func(a, b): return sums[a] / counts[a] > sums[b] / counts[b])
			alive = alive.slice(0, maxi(2, (alive.size() + 1) / 2))
			next_cut = rounds * 2
	var best := 0
	var best_mean := -INF
	for i: int in alive:
		var mean: float = sums[i] / maxi(1, counts[i])
		# Выбор Bot-1 (номер 0) выигрывает при равенстве — он идёт первым.
		if mean > best_mean + 1e-9:
			best = i
			best_mean = mean
	return best


## Сколько проверок вести одновременно: threads, а 0 — по числу физических
## ядер (логических / 2), не больше 8. Больше не надо: создание объектов в
## Godot идёт через общую блокировку, и при 15 потоках поиск медленнее, чем
## на одном (замер на Ryzen 7 5700X: 4 потока — x2.9, 8 — x3.5, 15 — x1.2).
static func worker_count() -> int:
	if threads > 0:
		return threads
	return clampi(OS.get_processor_count() / 2, 1, 8)


## Проверки tasks ([номер варианта, сид]) — в пуле потоков движка, каждая
## на своей копии партии. Результат — в том же порядке, что tasks.
static func _run_tasks(server: GameServer, me: String, candidates: Array, tasks: Array, workers: int) -> Array:
	var results := []
	results.resize(tasks.size())
	if workers <= 1 or tasks.size() == 1:
		for t in range(tasks.size()):
			results[t] = simulate(server, me, candidates[tasks[t][0]], tasks[t][1])
		return results
	var lock := Mutex.new()
	var one := func(t: int) -> void:
		var v := simulate(server, me, candidates[tasks[t][0]], tasks[t][1])
		lock.lock()
		results[t] = v
		lock.unlock()
	var group := WorkerThreadPool.add_group_task(one, tasks.size(), workers, true)
	WorkerThreadPool.wait_for_group_task_completion(group)
	return results


## Одна проверка плана (ходы plan подряд) в одной догадке о скрытом (seed):
## 0..1. Вопросы, которые план вызвал у других (Shield Guardian), решают
## быстрые боты; если план перестал подходить (ход отклонён, ход ушёл),
## остаток хода доигрывает быстрый бот. Первый ход плана невозможен — 0.
static func simulate(server: GameServer, me: String, plan: Array, seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var sim := BotSim.determinize(server, me, rng)
	for k in range(plan.size()):
		if k > 0:
			_settle(sim, me)
			if sim.state.game_over or sim.state.current_player() != me or sim.resolver.is_waiting():
				break
		if int(sim.apply_intent(plan[k])["error"]) != GameServer.Error.OK:
			if k == 0:
				return 0.0
			break
	BotSim.rollout_to_my_turn(sim, me, horizon)
	return BotSim.value(sim, me)


## Ответить быстрыми ботами на вопросы других игроков, пока они есть.
static func _settle(sim: GameServer, me: String) -> void:
	var guard := 0
	while sim.resolver.is_waiting() and sim.resolver.pending.player_id != me and guard < 50:
		guard += 1
		var who: String = sim.resolver.pending.player_id
		var res := sim.apply_intent(BotPlayer.next_intent(sim, who, true))
		if int(res["error"]) != GameServer.Error.OK:
			sim.apply_intent(BotPlayer.fallback_intent(sim, who))
