class_name RemoveSelfFromPlay
extends CardEffect

## Insane Outcast: "Discard a card from your hand ► Return Insane Outcast to
## the supply". Стрелка — необязательная плата (решение владельца игры):
## игрок выбирает карту для сброса или отказывается (""). Только после
## сброса Outcast уходит из сыгранных карт обратно в общую стопку.

var card_id: String


func _init(cid: String) -> void:
	card_id = cid


func is_available(state: GameState, player_id: String) -> bool:
	return not state.players[player_id].deck.hand.is_empty()


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	var p: PlayerState = state.players[player_id]
	if is_answered():
		var chosen = answer()
		if chosen == null or chosen == "":
			return
		var hand_idx: int = p.deck.hand.find(String(chosen))
		var played_idx: int = p.deck.played_pile.find(card_id)
		if hand_idx == -1 or played_idx == -1:
			return
		p.deck.hand.remove_at(hand_idx)
		p.deck.discard_pile.append(String(chosen))
		resolver.log_event("discard", {"player_id": player_id, "card_id": chosen})
		p.deck.played_pile.remove_at(played_idx)
		Supplies.redirect_outcast(state, player_id, card_id, resolver)
		return
	if not is_available(state, player_id) or not p.deck.played_pile.has(card_id):
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Discard a card to return Insane Outcast to the supply?"
	pd.choice_type = "target_card"
	pd.legal_options = p.deck.hand.duplicate()
	pd.legal_options.append("")
	pd.target_effect = self
	resolver.request_decision(pd)
