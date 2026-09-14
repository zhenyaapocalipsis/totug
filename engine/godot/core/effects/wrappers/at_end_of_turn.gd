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
	state.players[player_id].pending_end_of_turn.append(inner)
	resolver.log_event("queued_end_of_turn", {"player_id": player_id})
