class_name RemoveSelfFromPlay
extends CardEffect

## Insane Outcast: "Return Insane Outcast to the supply" — карта покидает игру
## навсегда (не в сброс, не promote). Технически кладём в devoured_pile
## (общая открытая стопка "вне игры") — семантически то же самое: карта
## больше не участвует ни в одном подсчёте очков.

var card_id: String


func _init(cid: String) -> void:
	card_id = cid


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	var p: PlayerState = state.players[player_id]
	var idx := p.deck.played_pile.find(card_id)
	if idx != -1:
		p.deck.played_pile.remove_at(idx)
		state.devoured_pile.append(card_id)
		resolver.log_event("removed_to_supply", {"player_id": player_id, "card_id": card_id})
