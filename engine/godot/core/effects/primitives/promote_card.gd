class_name PromoteCard
extends CardEffect

## Promote во Внутренний круг (рулбук стр. 13) из разных источников:
##   "this"           — сама разыгранная/сжираемая карта (card_id обязателен)
##   "top_of_deck"    — верхняя карта колоды добора (не рука!), детерминировано
##   "played_other"   — выбор среди played_pile ЭТОГО хода, кроме самой этой
##                       карты (card_id — тот же card_id, что был передан в
##                       CardLibrary.get_effect(); без него self-исключение не
##                       работает). Карта продвигает саму себя, только если её
##                       текст прямо это говорит ("promote this card") — тогда
##                       используется source "this" или "hand_or_discard", а
##                       не "played_other".
##   "discard"        — выбор из сброса
##   "hand_or_discard"— выбор из руки ИЛИ сброса (плюс card_id как ещё один вариант "this")
##
## filter — необязательный Callable(card_id:String)->bool, чтобы отфильтровать
## played_pile по аспекту/типу ("promote an Obedience card played this turn",
## "promote any number of Undead cards played this turn").
## count/up_to — "promote up to 2 other cards" / "any number of".

var source: String
var card_id: String
var filter: Callable
var remaining: int
var up_to: bool


func _init(src: String, cid: String = "", flt: Callable = Callable(), count: int = 1, allow_fewer: bool = false) -> void:
	source = src
	card_id = cid
	filter = flt
	remaining = count
	up_to = allow_fewer


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	var p: PlayerState = state.players[player_id]
	match source:
		"this":
			var idx := p.deck.played_pile.find(card_id)
			if idx != -1:
				p.deck.played_pile.remove_at(idx)
				p.deck.inner_circle.append(card_id)
				resolver.log_event("promote", {"player_id": player_id, "card_id": card_id})
			return
		"top_of_deck":
			if p.deck.draw_pile.is_empty():
				if p.deck.discard_pile.is_empty():
					return
				p.deck.draw_pile = p.deck.discard_pile.duplicate()
				p.deck.discard_pile.clear()
				p.deck.shuffle_draw_pile(state.rng)
			var top: String = p.deck.draw_pile.pop_back()
			p.deck.inner_circle.append(top)
			resolver.log_event("promote", {"player_id": player_id, "card_id": top})
			return

	if is_answered():
		var chosen = answer()
		_answered = false
		_answer = null
		if chosen != null and chosen != "":
			_promote_from(state, player_id, String(chosen), resolver)
			remaining -= 1
		else:
			remaining = 0
		_continue(state, player_id, resolver)
		return
	_continue(state, player_id, resolver)


func _candidates(state: GameState, player_id: String) -> Array:
	var p: PlayerState = state.players[player_id]
	var pool: Array = []
	match source:
		"played_other":
			pool = p.deck.played_pile.duplicate()
			# "another card played this turn" — карта саму себя не считает,
			# пока разыгранная card_id всё ещё лежит в played_pile (сброс
			# происходит только в конце хода). Снимаем ровно один экземпляр,
			# чтобы вторая копия той же карты, сыгранная в этот же ход,
			# осталась допустимой целью.
			if card_id != "":
				var self_idx := pool.find(card_id)
				if self_idx != -1:
					pool.remove_at(self_idx)
		"discard":
			pool = p.deck.discard_pile.duplicate()
		"hand_or_discard":
			pool.append_array(p.deck.hand)
			pool.append_array(p.deck.discard_pile)
			if card_id != "" and p.deck.played_pile.has(card_id):
				pool.append(card_id)
	if filter.is_valid():
		pool = pool.filter(func(cid): return filter.call(cid))
	return pool


func _promote_from(state: GameState, player_id: String, chosen: String, resolver: EffectResolver) -> void:
	var p: PlayerState = state.players[player_id]
	var removed := false
	for pile in [p.deck.played_pile, p.deck.discard_pile, p.deck.hand]:
		var idx: int = pile.find(chosen)
		if idx != -1:
			pile.remove_at(idx)
			removed = true
			break
	if removed:
		p.deck.inner_circle.append(chosen)
		resolver.log_event("promote", {"player_id": player_id, "card_id": chosen})


func _continue(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if remaining <= 0:
		return
	var candidates: Array = _candidates(state, player_id)
	if candidates.is_empty():
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Promote a card"
	pd.choice_type = "target_card"
	pd.legal_options = candidates
	if up_to:
		pd.legal_options.append("")
	pd.target_effect = self
	resolver.request_decision(pd)
