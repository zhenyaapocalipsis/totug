class_name GainPower
extends CardEffect

var amount: int


func _init(n: int) -> void:
	amount = n


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	state.players[player_id].power += amount
	resolver.log_event("gain_power", {"player_id": player_id, "amount": amount})
