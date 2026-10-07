class_name ReturnOwnTroops
extends CardEffect

## "Return N of your troops ► X" / "Return any number of your troops ► X each"
## (New Era, Celestial Order). Свои войска снимаются с доски откуда угодно и
## идут в барак (рулбук: свои фигуры возвращаются без Присутствия).
##
##   exact=true  — плата стрелкой: нужно ровно count войск. Если на доске их
##                 меньше, вариант недоступен. Первый выбор можно отклонить
##                 (стрелка необязательна — решение владельца), но начатую
##                 плату нужно довести до конца.
##   exact=false — "any number" / "up to count": остановиться можно в любой
##                 момент, then(k) получает фактическое число k (если k > 0).
##
## then_factory: func(k: int) -> CardEffect — что даёт оплата.

var count: int
var exact: bool
var then_factory: Callable
var returned := 0


func _init(n: int, must_be_exact: bool, factory: Callable) -> void:
	count = n
	exact = must_be_exact
	then_factory = factory


func _own_slots(state: GameState, player_id: String) -> Array:
	var result: Array = []
	for slot_id: String in state.graph.slots.keys():
		if state.troops.get(slot_id, "") == player_id:
			result.append(slot_id)
	return result


func is_available(state: GameState, player_id: String) -> bool:
	var have := _own_slots(state, player_id).size()
	return have >= count if exact else have > 0


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var slot_id = answer()
		_answered = false
		_answer = null
		if slot_id == null or String(slot_id) == "":
			_finish(player_id, resolver)
			return
		state.troops[slot_id] = ""
		state.players[player_id].troops_in_barracks += 1
		returned += 1
		resolver.log_event("return_troop", {"slot_id": slot_id, "owner": player_id})
	elif exact and not is_available(state, player_id):
		return
	_continue(state, player_id, resolver)


func _continue(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	var slots := _own_slots(state, player_id)
	if returned >= count or slots.is_empty():
		_finish(player_id, resolver)
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Return one of your troops (%d/%d)" % [returned + 1, count] if exact else "Return one of your troops"
	pd.choice_type = "target_slot"
	pd.legal_options = slots
	# exact: отказаться можно только до первого возврата.
	if not exact or returned == 0:
		pd.legal_options.append("")
	pd.target_effect = self
	resolver.request_decision(pd)


func _finish(player_id: String, resolver: EffectResolver) -> void:
	if returned <= 0:
		return
	if exact and returned < count:
		return
	var next = then_factory.call(returned)
	if next != null:
		resolver.push(next, player_id)
