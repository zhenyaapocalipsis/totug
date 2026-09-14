class_name FocusEffect
extends CardEffect

## "<Aspect> Focus > effect". Rulebook (Demonweb v2): "Whenever you play a card
## with Focus, if you played another card of that card's aspect this turn or if
## you reveal a card of that aspect from your hand, you get the Focus effect."
## TurnEngine.play_card() adds the card's own aspect to played_aspects_this_turn
## BEFORE applying its effect, hence "more than one" below. Revealing from hand
## costs nothing, so it is applied automatically when possible.

var aspect: String
var inner: CardEffect


func _init(asp: String, effect: CardEffect) -> void:
	aspect = asp
	inner = effect


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	var count := 0
	for a: String in state.played_aspects_this_turn:
		if a == aspect:
			count += 1
	if count > 1 or _hand_has_aspect(state, player_id):
		resolver.push(inner, player_id)


func _hand_has_aspect(state: GameState, player_id: String) -> bool:
	for card_id: String in state.players[player_id].deck.hand:
		if CardLibrary.card_aspect(card_id) == aspect:
			return true
	return false
