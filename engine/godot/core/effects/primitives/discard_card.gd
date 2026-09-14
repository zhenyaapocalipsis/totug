class_name DiscardCardEffect
extends CardEffect

## "Discard a card from your hand" — сам игрок выбирает, какую именно.

var remaining: int


func _init(count: int = 1) -> void:
	remaining = count


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var card_id = answer()
		_answered = false
		_answer = null
		if card_id != null and card_id != "":
			var p: PlayerState = state.players[player_id]
			var idx: int = p.deck.hand.find(String(card_id))
			if idx != -1:
				p.deck.hand.remove_at(idx)
				p.deck.discard_pile.append(String(card_id))
				resolver.log_event("discard", {"player_id": player_id, "card_id": card_id})
			remaining -= 1
		else:
			remaining = 0
		_continue(state, player_id, resolver)
		return
	_continue(state, player_id, resolver)


func _continue(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if remaining <= 0:
		return
	var hand: Array = state.players[player_id].deck.hand
	if hand.is_empty():
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Discard a card"
	pd.choice_type = "target_card"
	pd.legal_options = hand.duplicate()
	pd.target_effect = self
	resolver.request_decision(pd)
