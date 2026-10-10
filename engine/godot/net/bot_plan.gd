class_name BotPlan
extends RefCounted

## Планирование хода целиком (этап Bot-5). Когда карты разыграны и вопросов
## нет, остаётся главная фаза: на что потратить Power и что купить. Раньше
## каждое такое действие искалось отдельно, а остаток хода в проверке
## доигрывал простой бот. Теперь бот сравнивает ПОЛНЫЕ планы ("2 Deploy сюда,
## убить там, купить X") — так видны сочетания, которые по одному шагу не
## разглядеть: копить Power на убийство или развернуть три войска, одна
## дорогая карта или две дешёвых.
##
## Планы строятся лучом (beam search) на копии с догадкой о скрытом: на
## каждом шаге — BRANCH лучших продолжений Bot-1, остаются BEAM лучших
## частичных планов по быстрой оценке. Всегда есть и план самого Bot-1.
## Затем лучшие PLANS планов проверяются как обычно (BotSearch._search:
## целиком в каждой догадке, ответ соперников, оценка), лучший выполняется
## по шагу. Перед каждым следующим шагом состояние сверяется с ожидаемым
## (signature); не совпало (соперник ответил Shield Guardian и т.п.) —
## новый план.
##
## Без подглядывания: после покупки на освободившееся место рынка выходит
## карта, которой бот ещё не видел, — план это место больше не покупает.

const BEAM := 4
const BRANCH := 3
const MAX_STEPS := 14
const PLANS := 5
## Сколько стоит в быстрой оценке оставшийся на потом ресурс: частичный
## план, ещё не потративший Power, не должен проигрывать уже потратившему.
const POWER_LEFT := 0.6
const INFLUENCE_LEFT := 0.4

## Текущий план каждого бота: pid -> {"intents", "sigs", "k"}.
static var _current := {}
## Статистика: сколько планов искали.
static var plans_searched := 0
## Сколько раз план пришлось строить заново посреди хода (партия пошла не так).
static var replans := 0


## Сейчас главная фаза хода me: его ход, вопросов нет, рука пуста.
static func is_plan_phase(server: GameServer, me: String) -> bool:
	var state := server.state
	return not state.game_over and state.current_player() == me and not server.resolver.is_waiting() \
		and state.players[me].deck.hand.is_empty()


## Следующий шаг плана; новый план — если старого нет или партия пошла не
## так, как он ожидал.
static func next_step(server: GameServer, me: String, budget_ms: int, seed: int = 0, max_rounds: int = 0) -> Intent:
	var cur: Dictionary = _current.get(me, {})
	if not cur.is_empty():
		var k: int = cur["k"]
		if k < (cur["intents"] as Array).size() and String(cur["sigs"][k - 1]) == signature(server.state, me):
			cur["k"] = k + 1
			return cur["intents"][k]
	if not cur.is_empty() and int(cur["k"]) < (cur["intents"] as Array).size():
		replans += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else hash([me, server.state.market.display, server.state.troops,
		server.state.players[me].power, server.state.players[me].influence])
	var plans := generate(server, me, rng)
	var pick := 0
	if plans.size() > 1:
		pick = BotSearch._search(server, me, plans.map(func(p): return p["intents"]), budget_ms, rng.randi(), max_rounds)
		plans_searched += 1
	_current[me] = {"intents": plans[pick]["intents"], "sigs": plans[pick]["sigs"], "k": 1}
	return plans[pick]["intents"][0]


## Подпись того, что план меняет: по ней видно, что шаг прошёл как ожидалось.
static func signature(state: GameState, me: String) -> String:
	var p: PlayerState = state.players[me]
	return str([p.power, p.influence, p.troops_in_barracks, p.trophy_hall_count, p.vp_tokens,
		p.deck.discard_pile.size(), state.troops.hash(), state.spies.hash()])


## Кандидаты-планы: [{intents, sigs}], первый — план Bot-1. sigs[k] —
## подпись после шага k ("" после конца хода).
static func generate(server: GameServer, me: String, rng: RandomNumberGenerator) -> Array:
	var root := BotSim.determinize(server, me, rng)
	var out: Array = []
	var seen := {}
	for plan: Dictionary in _beam(root, me, 1, 1) + _beam(root, me, BEAM, BRANCH):
		var key := str((plan["intents"] as Array).map(func(i: Intent): return i.to_dict()))
		if seen.has(key):
			continue
		seen[key] = true
		out.append(plan)
		if out.size() >= PLANS:
			break
	return out


## Гибрид (Bot-6): k лучших первых шагов Bot-1, к каждому дописано
## продолжение хода полным Bot-1 (не быстрым, как в доигровке). Поиск
## сравнивает эти цепочки, а выполняется только первый шаг — на следующем
## шаге всё считается заново. Возвращает [Array[Intent]], первый — Bot-1.
static func rooted_plans(server: GameServer, me: String, rng: RandomNumberGenerator, k: int) -> Array:
	var root := BotSim.determinize(server, me, rng)
	var out: Array = []
	for o: Intent in BotPlayer.ranked_intents(root, me, k):
		if o.type == Intent.Type.END_TURN:
			out.append([o])
			continue
		var child := root.copy_now()
		if int(child.apply_intent(o)["error"]) != GameServer.Error.OK:
			continue
		BotSearch._settle(child, me)
		var plan: Array = [o]
		if is_plan_phase(child, me):
			var blocked := {}
			if o.type == Intent.Type.ACTION_RECRUIT:
				blocked[o.market_index] = true
			var rest: Array = _beam(child, me, 1, 1, blocked)
			if not rest.is_empty():
				plan.append_array(rest[0]["intents"])
		out.append(plan)
	return out


## Луч ширины width, на шаге — branch продолжений. Возвращает законченные
## планы, лучшие по быстрой оценке первыми.
static func _beam(root: GameServer, me: String, width: int, branch: int, start_blocked: Dictionary = {}) -> Array:
	var beams: Array = [{"sim": root, "intents": [], "sigs": [], "blocked": start_blocked.duplicate()}]
	var done: Array = []
	for step in range(MAX_STEPS):
		var grown: Array = []
		for b: Dictionary in beams:
			var sim: GameServer = b["sim"]
			var taken := 0
			for o: Intent in BotPlayer.ranked_intents(sim, me, branch + 2):
				if taken >= branch:
					break
				if o.type == Intent.Type.ACTION_RECRUIT and (b["blocked"] as Dictionary).has(o.market_index):
					continue
				taken += 1
				var intents: Array = (b["intents"] as Array) + [o]
				if o.type == Intent.Type.END_TURN:
					done.append({"intents": intents, "sigs": (b["sigs"] as Array) + [""], "score": _quick(sim, me)})
					continue
				var child := sim.copy_now()
				if int(child.apply_intent(o)["error"]) != GameServer.Error.OK:
					continue
				BotSearch._settle(child, me)
				var sigs: Array = (b["sigs"] as Array) + [signature(child.state, me)]
				if not is_plan_phase(child, me):
					done.append({"intents": intents, "sigs": sigs, "score": _quick(child, me)})
					continue
				var blocked: Dictionary = (b["blocked"] as Dictionary).duplicate()
				if o.type == Intent.Type.ACTION_RECRUIT:
					blocked[o.market_index] = true
				grown.append({"sim": child, "intents": intents, "sigs": sigs, "blocked": blocked, "score": _quick(child, me)})
		if grown.is_empty():
			beams = []
			break
		grown.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
		beams = grown.slice(0, width)
	# Не уложились в MAX_STEPS — дальше конец хода.
	for b: Dictionary in beams:
		done.append({"intents": (b["intents"] as Array) + [Intent.end_turn(me)],
			"sigs": (b["sigs"] as Array) + [""], "score": b["score"]})
	done.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	return done


## Быстрая оценка частичного плана: позиция + сила колоды + то, что ещё
## можно потратить.
static func _quick(sim: GameServer, me: String) -> float:
	var state := sim.state
	var ctx := BotPlayer._context(state, me)
	var p: PlayerState = state.players[me]
	var left := 0.0
	if state.current_player() == me and not state.game_over:
		left = POWER_LEFT * p.power + INFLUENCE_LEFT * p.influence
	return BotPlayer.evaluate(state, ctx) + BotSim.deck_edge(state, me, float(ctx["h"])) + left
