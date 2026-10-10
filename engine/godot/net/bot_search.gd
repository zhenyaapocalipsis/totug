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

const DEFAULT_BUDGET_MS := 400
const CANDIDATES := 4

## Сколько своих следующих ходов доигрывать в уме (1 — до начала следующего).
## 2 заметно сильнее 1: 88% побед у Bot-1 против 63% (24 партии на двоих).
static var horizon := 2
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
	# Варианты — на копии: оценка Bot-1 на миг переставляет войска, а поиск
	# может идти в отдельном потоке, пока экран читает настоящую партию.
	var candidates := BotPlayer.ranked_intents(server.clone(), pid, CANDIDATES)
	if candidates.size() <= 1:
		return candidates[0] if not candidates.is_empty() else BotPlayer.fallback_intent(server, pid)
	var pick := _search(server, pid, candidates, budget_ms, seed, max_rounds)
	searches += 1
	if pick != 0:
		deviations += 1
	return candidates[pick]


## Номер лучшего варианта. Круги: в каждом круге каждый живой вариант
## проверяется на одной общей догадке; после каждого раунда отсева худшая
## половина выбывает. Минимум 2 круга, даже если время вышло.
static func _search(server: GameServer, me: String, candidates: Array[Intent], budget_ms: int, seed: int, max_rounds: int = 0) -> int:
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
	# Сколько кругов до следующего отсева: растёт, чтобы оставшимся досталось
	# больше проверок.
	var next_cut := 2
	while alive.size() > 1:
		var round_seed := rng.randi()
		for i: int in alive:
			sums[i] += simulate(server, me, candidates[i], round_seed)
			counts[i] += 1
		rounds += 1
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


## Одна проверка хода intent в одной догадке о скрытом (seed): 0..1.
## Ход, который в этой догадке невозможен, — 0.
static func simulate(server: GameServer, me: String, intent: Intent, seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var sim := BotSim.determinize(server, me, rng)
	if int(sim.apply_intent(intent)["error"]) != GameServer.Error.OK:
		return 0.0
	BotSim.rollout_to_my_turn(sim, me, horizon)
	return BotSim.value(sim, me)
