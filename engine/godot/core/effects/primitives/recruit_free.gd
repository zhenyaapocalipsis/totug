class_name RecruitFree
extends CardEffect

## "Recruit a <Aspect> card that costs N or less without paying its cost" /
## "Recruit up to K cards that each cost N or less without paying its cost".
## Похоже на Actions.recruit, но без Influence и без ограничения на аспект,
## если aspect_filter == "".

var aspect_filter: String
var max_cost: int
var remaining: int
var up_to: bool


func _init(asp: String, cost_limit: int, count: int = 1, allow_fewer: bool = false) -> void:
	aspect_filter = asp
	max_cost = cost_limit
	remaining = count
	up_to = allow_fewer


func _eligible_indices(state: GameState) -> Array:
	var result: Array = []
	for i in range(state.market.display.size()):
		var cid: String = state.market.display[i]
		if cid == "":
			continue
		var cost: int = CardLibrary.card_cost(cid)
		if cost < 0 or cost > max_cost:
			continue
		if aspect_filter != "" and CardLibrary.card_aspect(cid) != aspect_filter:
			continue
		result.append(i)
	return result


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var index = answer()
		_answered = false
		_answer = null
		if index != null and index != -1:
			var card_id: String = state.market.recruit_at(int(index))
			if card_id != "":
				state.players[player_id].deck.discard_pile.append(card_id)
				resolver.log_event("recruit_free", {"player_id": player_id, "card_id": card_id})
				if state.market.is_deck_empty():
					GameEnd.trigger(state, "market_empty")
			remaining -= 1
		else:
			remaining = 0
		_continue(state, player_id, resolver)
		return
	_continue(state, player_id, resolver)


func _continue(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if remaining <= 0:
		return
	var options: Array = _eligible_indices(state)
	if options.is_empty():
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Recruit a card without paying its cost"
	pd.choice_type = "target_market_index"
	pd.legal_options = options
	if up_to:
		pd.legal_options.append(-1)
	pd.target_effect = self
	resolver.request_decision(pd)
