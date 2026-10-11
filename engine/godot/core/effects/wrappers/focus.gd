class_name FocusEffect
extends CardEffect

## "<Aspect> Focus > effect". Rulebook (Demonweb v2): "Whenever you play a card
## with Focus, if you played another card of that card's aspect this turn or if
## you reveal a card of that aspect from your hand, you get the Focus effect."
## TurnEngine.play_card() adds the card's own aspect to played_aspects_this_turn
## BEFORE applying its effect, hence "minus one" below. Revealing from hand
## costs nothing, so it is applied automatically when possible.
##
## New Era (Piltover & Zaun): "Double <Aspect> Focus" needs TWO other cards of
## that aspect — played this turn and/or revealed from hand (need = 2).
## Homunculus: state.turn_flags["focus_extra"] — every Focus effect of the
## current player triggers one more time.

var aspect: String
var inner: CardEffect
var need: int = 1


func _init(asp: String, effect: CardEffect, needed: int = 1) -> void:
	aspect = asp
	inner = effect
	need = needed
	_register()


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if not is_met(state, player_id, aspect, need):
		return
	var times := 1
	if player_id == state.current_player():
		times += int(state.turn_flags.get("focus_extra", 0))
	for i in range(times):
		# The inner effect keeps its answers, so each extra trigger gets a fresh copy.
		resolver.push(inner if i == 0 else _fresh_copy(), player_id)


## How many OTHER cards of the aspect count for Focus: played this turn (the
## card itself excluded) plus cards of that aspect in hand.
static func support(state: GameState, player_id: String, asp: String) -> int:
	var played := 0
	for a: String in state.played_aspects_this_turn:
		if a == asp:
			played += 1
	var in_hand := 0
	for card_id: String in state.players[player_id].deck.hand:
		if CardLibrary.card_aspect(card_id) == asp:
			in_hand += 1
	return maxi(0, played - 1) + in_hand


static func is_met(state: GameState, player_id: String, asp: String, needed: int = 1) -> bool:
	return support(state, player_id, asp) >= needed


## Effects keep their answers inside, so a repeated trigger needs a new copy of
## the inner effect: the card is built again and the Focus with the same
## number (in build order) gives it. CardLibrary.get_effect fills the registry.
static var registry: Array = []
static var last_built: Array = []
var _source_card: String = CardLibrary.building_card
var _source_index: int = -1


func _register() -> void:
	if _source_card != "":
		_source_index = registry.size()
		registry.append(self)


func _fresh_copy() -> CardEffect:
	if _source_card == "" or _source_index < 0:
		return inner
	CardLibrary.get_effect(_source_card)
	if _source_index < last_built.size():
		return (last_built[_source_index] as FocusEffect).inner
	return inner
