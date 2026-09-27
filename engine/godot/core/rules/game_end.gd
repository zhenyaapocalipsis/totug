class_name GameEnd
extends RefCounted

## Конец партии (рулбук, стр. 14).
##
## Триггер срабатывает при первом из двух событий:
##   • игрок развернул своё последнее войско (барак дошёл до 0 именно ЭТИМ
##     развёртыванием — не путать с "барак уже был пуст", это отдельный
##     случай, дающий 1 VP вместо развёртывания, см. core/rules/actions.gd);
##   • колода маркета опустела.
## После триггера "play proceeds until the end of the round" — доигрывается
## круг до игрока перед тем, кто вызвал триггер.


static func trigger(state: GameState, reason: String) -> void:
	if state.game_end_triggered:
		return
	state.game_end_triggered = true
	state.game_end_reason = reason
	var last_index: int = state.current_player_index - 1
	if last_index < 0:
		last_index = state.turn_order.size() - 1
	state.final_round_ends_after_index = last_index


## Не правило игры, а сетевой случай: игрок отключился и не вернулся —
## партия кончается сразу, без последнего круга; счёт — текущий.
static func abandon(state: GameState, player_id: String) -> void:
	state.game_over = true
	state.game_end_reason = "abandoned"
	state.abandoned_by = player_id


## Вызывать сразу после того, как текущий игрок закончил ход (после
## TurnEngine.end_turn), ДО передачи хода следующему. Возвращает true, если
## партия на этом закончилась (следующего хода не будет).
static func advance_turn(state: GameState) -> bool:
	if state.game_over:
		return true
	var just_finished: int = state.current_player_index
	if state.game_end_triggered and just_finished == state.final_round_ends_after_index:
		state.game_over = true
		return true
	state.current_player_index = (state.current_player_index + 1) % state.turn_order.size()
	return false
