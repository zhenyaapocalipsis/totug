class_name MoveTroop
extends CardEffect

## "Move an enemy troop" / "Move up to N enemy troops" — двухшаговый выбор на
## каждую единицу: сначала вражеское войско (любое на доске, без Presence —
## это не действие владельца войска), затем любой пустой слот на доске.
## Единственный примитив, который переиспользует один и тот же экземпляр как
## pd.target_effect несколько решений подряд (сам себе "reset" _answered), а
## не создаёт новый объект на каждый шаг — задокументированное исключение из
## общего правила "не пушить self до request_decision" (double-push касается
## push() ДО request_decision, а не переиспользования как target_effect).

var remaining: int
var up_to: bool
var _stage: String = "pick_source"
var _picked_source: String = ""


func _init(count: int = 1, allow_fewer: bool = false) -> void:
	remaining = count
	up_to = allow_fewer


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var value = answer()
		_answered = false
		_answer = null
		if _stage == "pick_source":
			if value == null or value == "":
				return
			_picked_source = value
			_stage = "pick_dest"
			_request_dest(state, player_id, resolver)
			return
		else:
			if value != null and value != "":
				var owner: String = state.troops.get(_picked_source, "")
				state.troops[_picked_source] = ""
				state.troops[value] = owner
				resolver.log_event("move_troop", {"player_id": player_id, "from": _picked_source, "to": value, "owner": owner})
			remaining -= 1
			_stage = "pick_source"
			_continue(state, player_id, resolver)
			return
	_continue(state, player_id, resolver)


func _continue(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if remaining <= 0:
		return
	var legal: Array = []
	for slot_id: String in state.graph.slots.keys():
		var owner: String = state.troops.get(slot_id, "")
		if owner != "" and owner != player_id:
			legal.append(slot_id)
	if legal.is_empty():
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Move an enemy troop"
	pd.choice_type = "target_slot"
	pd.legal_options = legal.duplicate()
	if up_to:
		pd.legal_options.append("")
	pd.target_effect = self
	resolver.request_decision(pd)


func _request_dest(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	var empties: Array = []
	for slot_id: String in state.graph.slots.keys():
		if slot_id != _picked_source and state.troops.get(slot_id, "") == "":
			empties.append(slot_id)
	if empties.is_empty():
		# Некуда переместить — откатываемся, войско остаётся на месте.
		remaining -= 1
		_stage = "pick_source"
		_continue(state, player_id, resolver)
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Move troop to"
	pd.choice_type = "target_slot"
	pd.legal_options = empties
	pd.target_effect = self
	resolver.request_decision(pd)
