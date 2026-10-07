class_name PlayCardFromZone
extends CardEffect

## "Play a card in the market that costs N or less as if it was in your hand,
## then devour that card" (Ulitharid) / "Play a card from your inner-circle as
## if it were in your hand, then return it to your inner-circle" (Elder Brain).
##
## zone: "market" | "inner_circle"
## after: "devour" (market только) | "keep" (карта остаётся, где была —
##        для inner-circle это буквально "then return it", т.к. карту из
##        Внутреннего круга для этого эффекта не убирают вовсе)

var zone: String
var max_cost: int
var after: String
var _chosen_index: int = -1


func _init(z: String, cost_limit: int = 999, after_mode: String = "keep") -> void:
	zone = z
	max_cost = cost_limit
	after = after_mode


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var choice = answer()
		if choice == null:
			return
		if typeof(choice) == TYPE_STRING and choice == "":
			return
		if typeof(choice) == TYPE_INT and choice == -1:
			return
		var card_id: String
		if zone == "market":
			_chosen_index = int(choice)
			card_id = state.market.display[_chosen_index]
			# для анимации (щупальце Ulitharid тянется к выбранной карте рынка)
			resolver.log_event("play_from_market", {"player_id": player_id, "card_id": card_id,
				"market_index": _chosen_index})
		else:
			card_id = String(choice)
		var inner_card_effect: CardEffect = CardLibrary.get_effect(card_id)
		var finish := _FinishPlayFromZone.new(zone, after, card_id, _chosen_index)
		resolver.push(finish, player_id)
		resolver.push(inner_card_effect, player_id)
		return

	if zone == "market":
		var options: Array = []
		for i in range(state.market.display.size()):
			var cid: String = state.market.display[i]
			if cid != "" and CardLibrary.card_cost(cid) <= max_cost and CardLibrary.card_cost(cid) >= 0:
				options.append(i)
		if options.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Play a card from the market"
		pd.tag = "market"  # выбор прямо на рынке справа
		pd.choice_type = "target_market_index"
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)
	else:
		var ic: Array = state.players[player_id].deck.inner_circle
		if ic.is_empty():
			return
		var pd2 := PendingDecision.new()
		pd2.player_id = player_id
		pd2.prompt = "Play a card from your inner circle"
		# карты Inner Circle встают на время выбора на место руки внизу
		pd2.tag = "inner_circle"
		pd2.choice_type = "target_card"
		pd2.legal_options = ic.duplicate()
		pd2.target_effect = self
		resolver.request_decision(pd2)


class _FinishPlayFromZone extends CardEffect:
	var zone: String
	var after: String
	var card_id: String
	var index: int

	func _init(z: String, a: String, cid: String, idx: int) -> void:
		zone = z
		after = a
		card_id = cid
		index = idx

	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if zone == "market" and after == "devour":
			if index >= 0 and index < state.market.display.size() and state.market.display[index] == card_id:
				state.market.recruit_at(index)
				state.devoured_pile.append(card_id)
				if state.market.is_deck_empty():
					GameEnd.trigger(state, "market_empty")
				resolver.log_event("devour", {"player_id": player_id, "card_id": card_id, "source": "market"})
		# zone == "inner_circle": карта никогда не покидала inner_circle — ничего делать не нужно.
