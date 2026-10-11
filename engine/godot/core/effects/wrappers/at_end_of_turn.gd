class_name AtEndOfTurn
extends CardEffect

## "At end of turn, ..." — откладывает внутренний эффект до конца хода игрока.
## Складывается в PlayerState.pending_end_of_turn; TurnEngine.end_turn()
## прогоняет их все ПЕРЕД обычными шагами конца хода (см. turn.gd).
##
## Начисление VP/Deploy/Promote отложенным эффектом безопасно — эти эффекты
## не используют Power/Influence. Если бы отложенный эффект начислял
## Power/Influence, они сгорели бы тут же тем же end_turn (см. progress.md,
## этап 5) — на практике ни у одной карты так не сделано.

var inner: CardEffect


func _init(effect: CardEffect) -> void:
	inner = effect


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	# С картой: вопрос в конце хода (promote...) покажет, чья он.
	state.players[player_id].pending_end_of_turn.append(_FromCard.new(inner, resolver.current_card()))
	resolver.log_event("queued_end_of_turn", {"player_id": player_id})


## Отложенный эффект вместе с картой, которая его отложила.
class _FromCard extends CardEffect:
	var inner: CardEffect
	var card: String

	func _init(effect: CardEffect, from_card: String) -> void:
		inner = effect
		card = from_card

	func apply(_state: GameState, player_id: String, resolver: EffectResolver) -> void:
		resolver.push(inner, player_id, card)
