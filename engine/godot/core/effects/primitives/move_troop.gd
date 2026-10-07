class_name MoveTroop
extends CardEffect

## "Move an enemy troop" / "Move up to N enemy troops" — двухшаговый выбор на
## каждую единицу: сначала вражеское войско в Присутствии игрока (подтвердил
## владелец игры), затем любой пустой слот на доске — Присутствие там не нужно.
## Единственный примитив, который переиспользует один и тот же экземпляр как
## pd.target_effect несколько решений подряд (сам себе "reset" _answered), а
## не создаёт новый объект на каждый шаг — задокументированное исключение из
## общего правила "не пушить self до request_decision" (double-push касается
## push() ДО request_decision, а не переиспользования как target_effect).
##
## New Era (Celestial Order):
##   own=true      — "Move one of your troops": свои войска, где угодно на доске;
##   single_site   — "from one site": все перемещения из той же локации, что и
##                   первое (или из preset_site, если её назвала карта);
##   on_done(site) — вызывается, когда перемещения закончились (site — локация,
##                   откуда двигали, "" если ничего не двигали).

var remaining: int
var up_to: bool
var own: bool
var single_site: bool
var locked_site: String = ""
var on_done: Callable = Callable()
var _stage: String = "pick_source"
var _picked_source: String = ""
var _done_called := false


func _init(count: int = 1, allow_fewer: bool = false, own_troops: bool = false,
		restrict_single_site: bool = false, preset_site: String = "", done_cb: Callable = Callable()) -> void:
	remaining = count
	up_to = allow_fewer
	own = own_troops
	single_site = restrict_single_site or preset_site != ""
	locked_site = preset_site
	on_done = done_cb


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var value = answer()
		_answered = false
		_answer = null
		if _stage == "pick_source":
			if value == null or value == "":
				_finish(player_id, resolver)
				return
			_picked_source = value
			if single_site and locked_site == "":
				locked_site = state.graph.site_of_slot(_picked_source)
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
		_finish(player_id, resolver)
		return
	var legal := _legal_sources(state, player_id)
	if legal.is_empty():
		_finish(player_id, resolver)
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Move one of your troops" if own else "Move an enemy troop"
	pd.choice_type = "target_slot"
	pd.legal_options = legal.duplicate()
	if up_to:
		pd.legal_options.append("")
	pd.target_effect = self
	resolver.request_decision(pd)


func _finish(player_id: String, resolver: EffectResolver) -> void:
	if _done_called or not on_done.is_valid():
		return
	_done_called = true
	var next = on_done.call(locked_site)
	if next != null:
		resolver.push(next, player_id)


func is_available(state: GameState, player_id: String) -> bool:
	return not _legal_sources(state, player_id).is_empty()


func _legal_sources(state: GameState, player_id: String) -> Array:
	var legal: Array = []
	for slot_id: String in state.graph.slots.keys():
		var owner: String = state.troops.get(slot_id, "")
		if owner == "":
			continue
		if single_site and locked_site != "" and state.graph.site_of_slot(slot_id) != locked_site:
			continue
		if own:
			if owner == player_id:
				legal.append(slot_id)
			continue
		if owner == player_id:
			continue
		if state.presence.has_presence_at_slot(player_id, slot_id, state.troops, state.spies):
			legal.append(slot_id)
	return legal


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
