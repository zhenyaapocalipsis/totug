class_name GameServer
extends RefCounted

## Авторитетный сервер партии (этап 6, host-authoritative модель).
##
## Клиент шлёт только Intent — GameServer его валидирует, применяет к
## GameState и возвращает события + персональные срезы (StateView) для
## каждого игрока. Весь RNG — на сервере (state.rng); клиент не знает и не
## должен знать содержимое колод/маркета до открытия.
##
## EffectResolver живёт здесь, а не в GameState: это единственный кусок
## состояния партии, который не сериализуется целиком между intent'ами —
## пока resolver ждёт решения (is_waiting()), сервер принимает только
## Intent.Type.MAKE_DECISION от того самого игрока, кому адресован prompt.

enum Error {
	OK,
	GAME_OVER,
	NOT_YOUR_TURN,
	AWAITING_DECISION,     # резолвер ждёт decision — годится только MAKE_DECISION
	NO_DECISION_PENDING,   # пришёл MAKE_DECISION, а решать сейчас нечего
	INVALID_ACTION,        # правило отказало (нет ресурсов, не та цель, и т.п.)
}

var state: GameState
var resolver: EffectResolver

## Если end_turn() приостановился на отложенном "at end of turn" эффекте —
## здесь хранится, чей это был ход, чтобы после resume() доиграть
## finish_end_of_turn() и передать ход дальше. Пусто, когда конец хода не
## обрабатывается прямо сейчас.
var _end_turn_pending_for: String = ""


func _init(game_state: GameState) -> void:
	state = game_state
	resolver = EffectResolver.new()
	_start_setup_if_needed()


## Если GameSetup.new_game был вызван с interactive_start=true, стартовые
## войска ещё не расставлены — вместо этого state.starting_site_candidates
## непустой. Заводим по одному ChooseStartingSite на игрока, в порядке хода:
## первый в очереди пушится последним (apply сам его пушит и сразу гоняет
## резолвер), поэтому решает первым turn_order[0], как и полагается первому
## ходящему. Дальше это обычный pending decision — MAKE_DECISION проходит тем
## же путём, что и любой карточный выбор (см. _apply).
func _start_setup_if_needed() -> void:
	if state.starting_site_candidates.is_empty():
		return
	var order: Array[String] = state.turn_order
	for i in range(order.size() - 1, 0, -1):
		resolver.push(ChooseStartingSite.new(), order[i])
	resolver.apply(ChooseStartingSite.new(), order[0], state)


## Точка входа для сети/тестов. Возвращает:
##   {error: GameServer.Error, events: Array[Dictionary], views: Dictionary[pid -> Dictionary]}
## events — только то, что породил ЭТОТ вызов (resolver.events очищается
## перед применением intent'а). views — персональный StateView каждого
## игрока, актуальный ПОСЛЕ применения (или без изменений, если intent
## был отклонён).
func apply_intent(intent: Intent) -> Dictionary:
	resolver.events.clear()
	var err: int = _apply(intent)
	return {
		"error": err,
		"events": resolver.events.duplicate(),
		"views": _build_views(),
	}


func _build_views() -> Dictionary:
	var views: Dictionary = {}
	for pid: String in state.players.keys():
		views[pid] = StateView.for_player_with_pending(state, pid, resolver.pending)
	return views


func _apply(intent: Intent) -> int:
	if state.game_over:
		return Error.GAME_OVER

	if resolver.is_waiting():
		if intent.type != Intent.Type.MAKE_DECISION:
			return Error.AWAITING_DECISION
		if intent.player_id != resolver.pending.player_id:
			return Error.NOT_YOUR_TURN
		resolver.resume(state, intent.answer)
		if not resolver.is_waiting() and _end_turn_pending_for != "":
			_finish_pending_end_turn()
		return Error.OK

	if intent.type == Intent.Type.MAKE_DECISION:
		return Error.NO_DECISION_PENDING

	if intent.player_id != state.current_player():
		return Error.NOT_YOUR_TURN

	match intent.type:
		Intent.Type.PLAY_CARD:
			if not TurnEngine.play_card(state, intent.player_id, intent.card_id, resolver):
				return Error.INVALID_ACTION
			return Error.OK

		Intent.Type.ACTION_ASSASSINATE:
			if not Actions.assassinate(state, intent.player_id, intent.slot_id):
				return Error.INVALID_ACTION
			resolver.log_event("assassinate", {"player_id": intent.player_id, "slot_id": intent.slot_id})
			return Error.OK

		Intent.Type.ACTION_DEPLOY:
			if not Actions.deploy(state, intent.player_id, intent.slot_id):
				return Error.INVALID_ACTION
			resolver.log_event("deploy", {"player_id": intent.player_id, "slot_id": intent.slot_id})
			return Error.OK

		Intent.Type.ACTION_RECRUIT:
			var cost: int = CardLibrary.card_cost(Actions.ghost_market_card(state, intent.player_id)) if intent.market_index == Market.DEVOURED_TOP_INDEX else state.market.card_cost(intent.market_index)
			if cost < 0:
				return Error.INVALID_ACTION
			if not Actions.recruit(state, intent.player_id, intent.market_index, cost):
				return Error.INVALID_ACTION
			resolver.log_event("recruit", {"player_id": intent.player_id, "market_index": intent.market_index})
			return Error.OK

		Intent.Type.ACTION_RECRUIT_SUPPLY:
			if not Actions.recruit_from_supply(state, intent.player_id, intent.card_id):
				return Error.INVALID_ACTION
			resolver.log_event("recruit_supply", {"player_id": intent.player_id, "card_id": intent.card_id})
			return Error.OK

		Intent.Type.ACTION_RETURN_SPY:
			if not Actions.return_enemy_spy(state, intent.player_id, intent.site_id, intent.spy_owner):
				return Error.INVALID_ACTION
			resolver.log_event("return_spy", {"player_id": intent.player_id, "site_id": intent.site_id, "spy_owner": intent.spy_owner})
			return Error.OK

		Intent.Type.END_TURN:
			var pid: String = intent.player_id
			TurnEngine.end_turn(state, pid, resolver)
			if resolver.is_waiting():
				_end_turn_pending_for = pid
				return Error.OK
			_advance_turn_and_log(pid)
			return Error.OK

	return Error.INVALID_ACTION


## Довести конец хода до конца после того, как последний "at end of turn"
## decision был разрешён через resume() внутри MAKE_DECISION.
func _finish_pending_end_turn() -> void:
	var pid: String = _end_turn_pending_for
	_end_turn_pending_for = ""
	TurnEngine.finish_end_of_turn(state, pid, resolver)
	_advance_turn_and_log(pid)


func _advance_turn_and_log(finished_player_id: String) -> void:
	var ended: bool = GameEnd.advance_turn(state)
	resolver.log_event("turn_ended", {"player_id": finished_player_id, "game_over": ended})
