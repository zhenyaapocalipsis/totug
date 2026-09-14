class_name DevourCard
extends CardEffect

## "Devour a card in your hand/the market/your inner circle" / "Devour this
## card" — убирает карту из игры в state.devoured_pile (общая для всех
## игроков открытая стопка "сожранных" карт — нужна как минимум для Ghost,
## который её читает; остальным картам достаточно, что карта пропадает).
## "Devour a card in your hand/market/inner circle" — это ПЛАТА: если целей
## нет, эффект (и его then_effect) тихо не срабатывает — карту всё равно
## нельзя сыграть "в минус".
##
## then_effect, если задан, пушится ПОСЛЕ успешного пожирания.

var source: String  # "hand" | "market" | "inner_circle" | "this"
var card_id: String
var then_effect: CardEffect = null


func _init(src: String, cid: String = "", then: CardEffect = null) -> void:
	source = src
	card_id = cid
	then_effect = then


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if source == "this":
		var p: PlayerState = state.players[player_id]
		var idx := p.deck.played_pile.find(card_id)
		if idx != -1:
			p.deck.played_pile.remove_at(idx)
			state.devoured_pile.append(card_id)
			resolver.log_event("devour", {"player_id": player_id, "card_id": card_id, "source": "this"})
			if then_effect != null:
				resolver.push(then_effect, player_id)
		return

	if source == "market":
		if is_answered():
			var index = answer()
			_answered = false
			_answer = null
			if index != null and index != -1:
				var devoured: String = state.market.recruit_at(int(index))
				if devoured != "":
					state.devoured_pile.append(devoured)
					resolver.log_event("devour", {"player_id": player_id, "card_id": devoured, "source": "market"})
					if state.market.is_deck_empty():
						GameEnd.trigger(state, "market_empty")
					if then_effect != null:
						resolver.push(then_effect, player_id)
			return
		var options: Array = []
		for i in range(state.market.display.size()):
			if state.market.display[i] != "":
				options.append(i)
		if options.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Devour a card in the market"
		pd.choice_type = "target_market_index"
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)
		return

	# "hand" / "inner_circle"
	if is_answered():
		var chosen = answer()
		_answered = false
		_answer = null
		if chosen != null and chosen != "":
			var p: PlayerState = state.players[player_id]
			var pile: Array = p.deck.hand if source == "hand" else p.deck.inner_circle
			var idx: int = pile.find(chosen)
			if idx != -1:
				pile.remove_at(idx)
				state.devoured_pile.append(chosen)
				resolver.log_event("devour", {"player_id": player_id, "card_id": chosen, "source": source})
				if then_effect != null:
					resolver.push(then_effect, player_id)
		return

	var p: PlayerState = state.players[player_id]
	var pool: Array = (p.deck.hand if source == "hand" else p.deck.inner_circle).duplicate()
	if pool.is_empty():
		return
	var pd2 := PendingDecision.new()
	pd2.player_id = player_id
	pd2.prompt = "Devour a card"
	pd2.choice_type = "target_card"
	pd2.legal_options = pool
	pd2.target_effect = self
	resolver.request_decision(pd2)
