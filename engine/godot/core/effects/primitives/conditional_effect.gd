class_name ConditionalEffect
extends CardEffect

## "If <condition>, <effect>" — условие как Callable(state, player_id) -> bool,
## оценивается в момент применения (не заранее).

var predicate: Callable
var then_effect: CardEffect


func _init(cond: Callable, effect: CardEffect) -> void:
	predicate = cond
	then_effect = effect


## Вариант "Choose one" с невыполненным условием не предлагается (Mammoth:
## "no opponent has 5+ cards: supplant 2 troops" — иначе карта уходила впустую).
func is_available(state: GameState, player_id: String) -> bool:
	return bool(predicate.call(state, player_id)) and then_effect.is_available(state, player_id)


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if predicate.call(state, player_id):
		resolver.push(then_effect, player_id)
