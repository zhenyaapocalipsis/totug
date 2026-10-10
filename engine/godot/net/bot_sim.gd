class_name BotSim
extends RefCounted

## "Партия в уме" для бота (этап Bot-2): копия партии, в которой скрытое
## заменено правдоподобной догадкой, и быстрая доигровка вперёд.
##
## Бот не должен знать чужие руки и порядок колод. Поэтому копия для него —
## не точная (GameServer.clone знает всё), а "детерминизация": всё, чего бот
## не видит, перемешано заново, но так, чтобы не противоречить видимому
## (StateView): размеры руки, колоды и сброса те же, карты те же, что у
## игрока вообще есть. Много таких копий с разными догадками — основа
## ISMCTS (Bot-3).

## Сколько намерений максимум на одну доигровку (защита от зацикливания).
const MAX_INTENTS := 4000


## Копия партии глазами viewer: скрытое перемешано rng, будущее (RNG партии)
## — тоже другое, чтобы бот не "знал" следующих добор и маркет.
static func determinize(server: GameServer, viewer: String, rng: RandomNumberGenerator) -> GameServer:
	var sim := server.clone()
	hide_hidden(sim.state, viewer, rng)
	return sim


## Скрытое от viewer: у соперников — какие из их карт в руке, в колоде и в
## сбросе (StateView показывает только числа), у всех — порядок колод добора,
## порядок колоды маркета и RNG партии.
static func hide_hidden(state: GameState, viewer: String, rng: RandomNumberGenerator) -> void:
	for pid: String in state.turn_order:
		var d: Deck = state.players[pid].deck
		# Перед перемешиванием — сортировка: иначе результат зависел бы от
		# настоящего (скрытого) порядка карт, и решение бота — тоже.
		if pid == viewer:
			d.draw_pile.sort()
			Deck.shuffle_array(d.draw_pile, rng)
			continue
		var pool: Array[String] = []
		pool.append_array(d.hand)
		pool.append_array(d.draw_pile)
		pool.append_array(d.discard_pile)
		pool.sort()
		Deck.shuffle_array(pool, rng)
		var h := d.hand.size()
		var n := d.draw_pile.size()
		d.hand = pool.slice(0, h)
		d.draw_pile = pool.slice(h, h + n)
		d.discard_pile = pool.slice(h + n)
	state.market.deck.sort()
	Deck.shuffle_array(state.market.deck, rng)
	state.rng.seed = rng.randi()


## Доиграть копию ботами за всех: turns ходов (0 — до конца партии); fast —
## боты в быстром режиме (BotPlayer.next_intent). Возвращает, сколько
## намерений применено.
static func rollout(sim: GameServer, turns: int = 0, fast: bool = true) -> int:
	var done_turns := 0
	var intents := 0
	var rejected_in_row := 0
	while not sim.state.game_over and intents < MAX_INTENTS:
		var pid := BotPlayer.acting_player(sim)
		var intent: Intent = BotPlayer.next_intent(sim, pid, fast) if rejected_in_row == 0 \
			else BotPlayer.fallback_intent(sim, pid)
		if rejected_in_row > 2:
			intent = Intent.end_turn(sim.state.current_player())
		var res: Dictionary = sim.apply_intent(intent)
		intents += 1
		if int(res["error"]) != GameServer.Error.OK:
			rejected_in_row += 1
			continue
		rejected_in_row = 0
		if _turn_ended(res["events"]):
			done_turns += 1
			if turns > 0 and done_turns >= turns:
				break
	return intents


static func _turn_ended(events: Array) -> bool:
	for e: Dictionary in events:
		if e["type"] == "turn_ended":
			return true
	return false


## Насколько хороша партия для me, от 0 до 1. Конец партии — победа 1
## (ничья делится), поражение 0; иначе — оценка позиции бота Bot-1,
## сжатая в (0, 1): разница в 10 VP с лидером ~ 0.73.
static func value(sim: GameServer, me: String) -> float:
	var state := sim.state
	if state.game_over:
		var vp := Scoring.library_card_vp(state)
		var winners := Scoring.winners(state, vp[0], vp[1])
		return 1.0 / winners.size() if winners.has(me) else 0.0
	var ctx := BotPlayer._context(state, me)
	var ev := BotPlayer.evaluate(state, ctx) + deck_edge(state, me, float(ctx["h"]))
	return 1.0 / (1.0 + exp(-ev / 10.0))


## Сила колоды против соперников, в VP-эквиваленте. Карта даёт примерно
## 1 + цена/2 ресурса (Noble — 1 Influence, карта за 4 — около 3 ресурсов);
## за ход тянется 5 карт; ресурс за ход стоит W_RESOURCE VP за круг до
## конца партии. Без этого поиск не видел пользы от покупки сильной карты,
## пока её не вытянули, и от чистки колоды.
static func deck_edge(state: GameState, me: String, h: float) -> float:
	var per_turn := {}
	for pid: String in state.turn_order:
		var cards: Array[String] = state.players[pid].deck.cards_outside_inner_circle()
		var sum := 0.0
		for cid: String in cards:
			sum += 1.0 + 0.5 * float(maxi(0, CardLibrary.card_cost(cid)))
		per_turn[pid] = GameSetup.HAND_SIZE * sum / maxf(1.0, float(cards.size()))
	var best := -INF
	var total := 0.0
	var opps := 0
	for pid: String in state.turn_order:
		if pid == me:
			continue
		best = maxf(best, per_turn[pid])
		total += per_turn[pid]
		opps += 1
	if opps == 0:
		return 0.0
	var rival: float = BotPlayer.W_LEADER * best + (1.0 - BotPlayer.W_LEADER) * total / opps
	return h * BotPlayer.W_RESOURCE * (float(per_turn[me]) - rival)


## Доиграть копию до начала следующего хода me (times-го по счёту; весь
## остаток своего хода и
## ходы соперников): так в оценку попадает и ответ соперников.
static func rollout_to_my_turn(sim: GameServer, me: String, times: int = 1) -> void:
	var reached := 0
	var intents := 0
	var left_mine := false
	var rejected_in_row := 0
	while not sim.state.game_over and intents < MAX_INTENTS:
		var pid := BotPlayer.acting_player(sim)
		if left_mine and pid == me and sim.state.current_player() == me and sim.is_quiet():
			reached += 1
			if reached < times:
				left_mine = false
				continue
			return
		var intent: Intent = BotPlayer.next_intent(sim, pid, true) if rejected_in_row == 0 \
			else BotPlayer.fallback_intent(sim, pid)
		if rejected_in_row > 2:
			intent = Intent.end_turn(sim.state.current_player())
		var res: Dictionary = sim.apply_intent(intent)
		intents += 1
		if int(res["error"]) != GameServer.Error.OK:
			rejected_in_row += 1
			continue
		rejected_in_row = 0
		if sim.state.current_player() != me:
			left_mine = true
