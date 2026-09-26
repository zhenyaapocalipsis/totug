class_name DevourCard
extends CardEffect

## "Devour a card in your hand/the market/your inner circle" / "Devour this
## card" — убирает карту из игры в state.devoured_pile (общая для всех
## игроков открытая стопка "сожранных" карт — нужна как минимум для Ghost,
## который её читает; остальным картам достаточно, что карта пропадает).
##
## then_effect, если задан, пушится ПОСЛЕ успешного пожирания. Карта со
## then_effect — это плата со стрелкой "Devour ... ► X": по решению владельца
## игры она НЕОБЯЗАТЕЛЬНА, игрок может отказаться и не получить X. Для
## "hand"/"inner_circle" отказ — пустой ответ "", для "this" — confirm.
## ask_confirm=false — когда игрок уже выбрал этот вариант в "Choose one"
## (Cultist of Myrkul, Minotaur Skeleton) и второй вопрос не нужен.
##
## Insane Outcast не пожирается, а возвращается в запас (текст карты).

var source: String  # "hand" | "market" | "inner_circle" | "this"
var card_id: String
var then_effect: CardEffect = null
var ask_confirm: bool = true


func _init(src: String, cid: String = "", then: CardEffect = null, confirm: bool = true) -> void:
	source = src
	card_id = cid
	then_effect = then
	ask_confirm = confirm


func is_available(state: GameState, player_id: String) -> bool:
	var p: PlayerState = state.players[player_id]
	match source:
		"hand": return not p.deck.hand.is_empty()
		"inner_circle": return not p.deck.inner_circle.is_empty()
		"this": return p.deck.played_pile.has(card_id)
	return true


func _is_optional() -> bool:
	return then_effect != null


func _devour(state: GameState, player_id: String, chosen: String, src: String, resolver: EffectResolver) -> void:
	if not Supplies.redirect_outcast(state, player_id, chosen, resolver):
		state.devoured_pile.append(chosen)
		resolver.log_event("devour", {"player_id": player_id, "card_id": chosen, "source": src})
	if then_effect != null:
		resolver.push(then_effect, player_id)


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if source == "this":
		var p: PlayerState = state.players[player_id]
		if not p.deck.played_pile.has(card_id):
			return
		if _is_optional() and ask_confirm and not is_answered():
			var pd0 := PendingDecision.new()
			pd0.player_id = player_id
			pd0.prompt = "Devour this card?"
			pd0.choice_type = "confirm"
			pd0.source_card = card_id
			pd0.legal_options = [true, false]
			pd0.target_effect = self
			resolver.request_decision(pd0)
			return
		if is_answered() and not bool(answer()):
			return
		p.deck.played_pile.remove_at(p.deck.played_pile.find(card_id))
		_devour(state, player_id, card_id, "this", resolver)
		return

	if source == "market":
		if is_answered():
			var index = answer()
			_answered = false
			_answer = null
			if index != null and index != -1:
				var devoured: String = state.market.recruit_at(int(index))
				if devoured != "":
					if state.market.is_deck_empty():
						GameEnd.trigger(state, "market_empty")
					_devour(state, player_id, devoured, "market", resolver)
			return
		var options: Array = []
		for i in range(state.market.display.size()):
			if state.market.display[i] != "":
				options.append(i)
		if options.is_empty():
			return
		if _is_optional():
			options.append(-1)
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
				_devour(state, player_id, String(chosen), source, resolver)
		return

	var p: PlayerState = state.players[player_id]
	var pool: Array = (p.deck.hand if source == "hand" else p.deck.inner_circle).duplicate()
	if pool.is_empty():
		return
	if _is_optional():
		pool.append("")
	var pd2 := PendingDecision.new()
	pd2.player_id = player_id
	pd2.prompt = "Devour a card (or skip)" if _is_optional() else "Devour a card"
	pd2.choice_type = "target_card"
	pd2.legal_options = pool
	pd2.target_effect = self
	resolver.request_decision(pd2)
