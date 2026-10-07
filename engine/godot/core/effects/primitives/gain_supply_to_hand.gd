class_name GainSupplyToHand
extends CardEffect

## "Put a House Guard [or Priestess of Lolth] into your hand" (New Era): карта
## берётся из запаса рядом с доской бесплатно и сразу в руку. Если вариантов
## несколько и оба есть в запасе — игрок выбирает картой на затемнённом экране.
## Пустой запас — ничего.

var options: Array[String]


func _init(card_ids: Array[String]) -> void:
	options = card_ids


func _available(state: GameState) -> Array:
	return options.filter(func(cid): return state.supplies.is_available(cid))


func is_available(state: GameState, _player_id: String) -> bool:
	return not _available(state).is_empty()


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	var avail := _available(state)
	var chosen := ""
	if is_answered():
		chosen = String(answer())
		if not avail.has(chosen):
			return
	elif avail.size() == 1:
		chosen = avail[0]
	elif avail.is_empty():
		return
	else:
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Put a card into your hand"
		pd.choice_type = "target_card"
		pd.legal_options = avail
		pd.target_effect = self
		resolver.request_decision(pd)
		return
	state.supplies.take(chosen)
	state.players[player_id].deck.hand.append(chosen)
	resolver.log_event("gain_card", {"player_id": player_id, "card_id": chosen, "to": "hand"})
