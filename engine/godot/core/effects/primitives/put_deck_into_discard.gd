class_name PutDeckIntoDiscard
extends CardEffect

## "Put your deck into your discard pile." (Matron Mother) — весь draw_pile
## переходит в discard_pile (рука не трогается).

func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	var p: PlayerState = state.players[player_id]
	p.deck.discard_pile.append_array(p.deck.draw_pile)
	p.deck.draw_pile.clear()
	resolver.log_event("put_deck_into_discard", {"player_id": player_id})
