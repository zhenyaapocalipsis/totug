class_name GainVP
extends CardEffect

## Гейн VP через физический банк токенов (VPBank.grant может отдать меньше
## запрошенного, если токены кончились — см. vp_bank.gd).

var amount: int


func _init(n: int) -> void:
	amount = n


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if amount <= 0:
		return
	var p: PlayerState = state.players[player_id]
	var granted: int = state.vp_bank.grant(amount)
	p.vp_tokens += granted
	resolver.log_event("gain_vp", {"player_id": player_id, "amount": granted})
