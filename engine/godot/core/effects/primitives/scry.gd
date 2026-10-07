class_name ScryCards
extends CardEffect

## "Scry N" (New Era): посмотреть N верхних карт своей колоды и сбросить любые
## из них, остальные остаются сверху в прежнем порядке. Игроку по одной
## показываются открытые карты — он выбирает, какую сбросить, или "Skip".
## Пустая колода перед просмотром замешивается из сброса, как при добирании.

var amount: int
var _revealed: Array[String] = []
var _started := false


func _init(n: int) -> void:
	amount = n


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	var deck: Deck = state.players[player_id].deck
	if not _started:
		_started = true
		if deck.draw_pile.is_empty() and not deck.discard_pile.is_empty():
			deck.draw_pile = deck.discard_pile.duplicate()
			deck.discard_pile.clear()
			deck.shuffle_draw_pile(state.rng)
		var n := mini(amount, deck.draw_pile.size())
		for i in range(n):
			_revealed.append(deck.draw_pile[deck.draw_pile.size() - 1 - i])
		resolver.log_event("scry", {"player_id": player_id, "amount": n})
	elif is_answered():
		var chosen = answer()
		_answered = false
		_answer = null
		if chosen == null or String(chosen) == "":
			return
		var idx := _revealed.find(String(chosen))
		if idx != -1:
			_revealed.remove_at(idx)
			# Сверху колоды среди первых N — убираем ближайшую к верху копию.
			for j in range(deck.draw_pile.size() - 1, -1, -1):
				if deck.draw_pile[j] == String(chosen):
					deck.draw_pile.remove_at(j)
					break
			deck.discard_pile.append(String(chosen))
			resolver.log_event("discard", {"player_id": player_id, "card_id": chosen, "from": "scry"})
	if _revealed.is_empty():
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Scry: discard a card from the top of your deck"
	pd.choice_type = "target_card"
	pd.legal_options = Array(_revealed)
	pd.legal_options.append("")
	pd.target_effect = self
	resolver.request_decision(pd)
