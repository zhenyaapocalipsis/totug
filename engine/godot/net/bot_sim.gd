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
		if pid == viewer:
			Deck.shuffle_array(d.draw_pile, rng)
			continue
		var pool: Array[String] = []
		pool.append_array(d.hand)
		pool.append_array(d.draw_pile)
		pool.append_array(d.discard_pile)
		Deck.shuffle_array(pool, rng)
		var h := d.hand.size()
		var n := d.draw_pile.size()
		d.hand = pool.slice(0, h)
		d.draw_pile = pool.slice(h, h + n)
		d.discard_pile = pool.slice(h + n)
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
	var ev := BotPlayer.evaluate(state, BotPlayer._context(state, me))
	return 1.0 / (1.0 + exp(-ev / 10.0))
