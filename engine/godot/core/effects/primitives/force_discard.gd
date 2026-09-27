class_name ForceDiscard
extends CardEffect

## "X must discard a card" — заставляет противника(ов) сбросить карту.
##
## Правила (подтверждены владельцем игры 2026-09-15):
##   • "more than N cards" — это карты В РУКЕ;
##   • какую карту сбросить, выбирает сам сбрасывающий игрок (отдельное
##     решение, адресованное ему);
##   • реакции "If an opponent causes you to discard this": Grimlock — взять
##     2 карты, Ambassador — можно повысить вместо сброса, Umber Hulk —
##     виновник сброса сам сбрасывает карту.
##
## mode:
##   "choose_opponent" — АКТИВНЫЙ игрок выбирает, какой оппонент (из тех, кто
##                       удовлетворяет min_cards) сбрасывает.
##   "each_opponent"   — сбрасывают ВСЕ оппоненты, удовлетворяющие min_cards.
##   "victim"          — сбрасывает конкретный victim_id (Mindwitness, Chuul).

const GRIMLOCK := "48712"
const AMBASSADOR := "48704"
const UMBER_HULK := "48739"

var mode: String
var min_cards: int
var victim_id: String


func _init(m: String, threshold: int = 0, victim: String = "") -> void:
	mode = m
	min_cards = threshold
	victim_id = victim


static func hand_size(state: GameState, pid: String) -> int:
	return state.players[pid].deck.hand.size()


func _eligible_opponents(state: GameState, player_id: String) -> Array:
	var result: Array = []
	for pid: String in state.turn_order:
		if pid != player_id and hand_size(state, pid) > min_cards:
			result.append(pid)
	return result


func is_available(state: GameState, player_id: String) -> bool:
	if mode == "victim":
		return victim_id != player_id and hand_size(state, victim_id) > min_cards
	return not _eligible_opponents(state, player_id).is_empty()


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if mode == "victim":
		if is_available(state, player_id):
			resolver.push(VictimDiscard.new(player_id), victim_id)
		return

	if mode == "each_opponent":
		var victims := _eligible_opponents(state, player_id)
		victims.reverse()  # стек LIFO: первым решает первый по порядку хода
		for pid: String in victims:
			resolver.push(VictimDiscard.new(player_id), pid)
		return

	# choose_opponent
	if is_answered():
		var victim = answer()
		if victim != null and victim != "":
			resolver.push(VictimDiscard.new(player_id), String(victim))
		return
	var options: Array = _eligible_opponents(state, player_id)
	if options.is_empty():
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Choose an opponent to discard a card"
	pd.choice_type = "target_player"
	pd.legal_options = options
	pd.target_effect = self
	resolver.request_decision(pd)


## Сброс одной карты игроком, которого к этому вынудил causer_id. Применяется
## с player_id = сбрасывающий игрок, решение адресовано ему же.
class VictimDiscard extends CardEffect:
	var causer_id: String
	var chosen_card: String = ""

	func _init(causer: String) -> void:
		causer_id = causer

	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var p: PlayerState = state.players[player_id]
		if is_answered():
			var ans = answer()
			_answered = false
			_answer = null
			if chosen_card == "":
				chosen_card = String(ans)
				if chosen_card == ForceDiscard.AMBASSADOR:
					_ask(player_id, resolver, "Promote Ambassador instead of discarding it?", "confirm", [true, false])
					return
				_finish(state, player_id, false, resolver)
			else:
				_finish(state, player_id, bool(ans), resolver)
			return
		if p.deck.hand.is_empty():
			return
		_ask(player_id, resolver, "Discard a card", "target_card", p.deck.hand.duplicate())

	func _ask(player_id: String, resolver: EffectResolver, prompt: String, kind: String, options: Array) -> void:
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = prompt
		pd.choice_type = kind
		if kind == "confirm":
			pd.source_card = chosen_card  # Ambassador: окно показывает саму карту
		else:
			pd.tag = "hand"  # выбор прямо в руке внизу экрана
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)

	func _finish(state: GameState, player_id: String, promote_instead: bool, resolver: EffectResolver) -> void:
		var p: PlayerState = state.players[player_id]
		var idx: int = p.deck.hand.find(chosen_card)
		if idx == -1:
			return
		p.deck.hand.remove_at(idx)
		if promote_instead:
			p.deck.inner_circle.append(chosen_card)
			resolver.log_event("promote", {"player_id": player_id, "card_id": chosen_card})
			return
		p.deck.discard_pile.append(chosen_card)
		resolver.log_event("force_discard", {"player_id": player_id, "card_id": chosen_card})
		match chosen_card:
			ForceDiscard.GRIMLOCK:
				resolver.push(DrawCards.new(2), player_id)
			ForceDiscard.UMBER_HULK:
				if causer_id != player_id:
					resolver.push(DiscardCardEffect.new(1), causer_id)
