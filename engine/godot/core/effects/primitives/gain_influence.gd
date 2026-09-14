class_name GainInfluence
extends CardEffect

var amount: int


func _init(n: int) -> void:
	amount = n


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	state.players[player_id].influence += amount
	resolver.log_event("gain_influence", {"player_id": player_id, "amount": amount})
