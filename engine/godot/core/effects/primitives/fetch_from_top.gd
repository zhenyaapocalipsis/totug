class_name FetchFromTop
extends CardEffect

## "Look at the top N cards of your deck. Put every X among them into your
## hand and the rest back on top" (New Era). Выбора нет: подходящие карты
## уходят в руку, остальные остаются сверху в том же порядке.

var amount: int
var filter: Callable


func _init(n: int, flt: Callable) -> void:
	amount = n
	filter = flt


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	var deck: Deck = state.players[player_id].deck
	if deck.draw_pile.is_empty() and not deck.discard_pile.is_empty():
		deck.draw_pile = deck.discard_pile.duplicate()
		deck.discard_pile.clear()
		deck.shuffle_draw_pile(state.rng)
	var n := mini(amount, deck.draw_pile.size())
	var taken: Array[String] = []
	var top := deck.draw_pile.size() - 1
	for i in range(n):
		var idx := top - i
		if filter.call(deck.draw_pile[idx]):
			taken.append(deck.draw_pile[idx])
			deck.draw_pile[idx] = ""
	deck.draw_pile = deck.draw_pile.filter(func(c): return c != "")
	deck.hand.append_array(taken)
	resolver.log_event("fetch_from_top", {"player_id": player_id, "looked": n, "cards": taken})
