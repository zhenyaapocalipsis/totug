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
##
## Jarlaxle: карту соперника разыграли за него, а решал разыгравший — тот же
## игрок решает и отложенный эффект в конце хода соперника (владелец,
## 2026-10-19), поэтому решающий (EffectResolver.deciders) запоминается.

var inner: CardEffect


func _init(effect: CardEffect) -> void:
	inner = effect


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	# С картой: вопрос в конце хода (promote...) покажет, чья он.
	var decider := String(resolver.deciders.get(player_id, ""))
	state.players[player_id].pending_end_of_turn.append(_FromCard.new(inner, resolver.current_card(), decider))
	resolver.log_event("queued_end_of_turn", {"player_id": player_id})


## Отложенный эффект вместе с картой, которая его отложила, и тем, кто решает
## его вопросы ("" — сам игрок).
class _FromCard extends CardEffect:
	var inner: CardEffect
	var card: String
	var decider: String

	func _init(effect: CardEffect, from_card: String, decided_by: String = "") -> void:
		inner = effect
		card = from_card
		decider = decided_by

	func apply(_state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if decider != "" and decider != player_id:
			var pid := player_id
			resolver.push(CallbackEffect.new(func(_s: GameState, _p: String, r: EffectResolver):
				r.deciders.erase(pid)), player_id)
			resolver.deciders[player_id] = decider
		resolver.push(inner, player_id, card)
