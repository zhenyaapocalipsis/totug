class_name DrawCards
extends CardEffect

var amount: int


func _init(n: int = 1) -> void:
	amount = n


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	var p: PlayerState = state.players[player_id]
	var drawn: int = 0
	for i in range(amount):
		if not p.deck.draw_one(state.rng):
			break
		drawn += 1
	resolver.log_event("draw_cards", {"player_id": player_id, "amount": drawn})
