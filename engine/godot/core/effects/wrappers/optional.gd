class_name OptionalEffect
extends CardEffect

## "You may ..." — эффект применяется только если игрок согласился.

var inner: CardEffect
var prompt: String = "You may..."
## Карта, которой принадлежит "you may" (окно показывает её как вариант "да").
var source_card: String = CardLibrary.building_card


func _init(effect: CardEffect, p: String = "You may...") -> void:
	inner = effect
	prompt = p


func apply(_state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		if bool(answer()):
			resolver.push(inner, player_id)
		return

	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = prompt
	pd.choice_type = "confirm"
	pd.legal_options = [true, false]
	pd.source_card = source_card
	pd.target_effect = self
	resolver.request_decision(pd)
