class_name SupplantTroop
extends CardEffect

## "Supplant a troop" / "Supplant a white troop [anywhere on the board]" —
## убить вражеское (или строго белое) войско и сразу поставить своё в тот же
## слот. Собственная трактовка (нет отдельного базового действия Supplant в
## тексте рулбука этапов 1-4, только на картах): обычная версия требует
## Presence на слот-цель (как assassinate базовым действием), явная оговорка
## "anywhere on the board" эту проверку снимает. Если владелец игры уточнит
## правило иначе — поправить только здесь.
##
## count/up_to — для "Supplant 2 white troops" (Demogorgon) и подобных.

var remaining: int
var white_only: bool
var anywhere: bool
var up_to: bool
var _post_effect_factory: Callable  # func(slot_id: String) -> CardEffect, опционально
var preset_site: String = ""
var lock_after_first: bool = false  # "up to N troops at one site": локация фиксируется первым выбором


func _init(count: int = 1, is_white_only: bool = false, allow_anywhere: bool = false,
		allow_fewer: bool = false, post_factory: Callable = Callable(), site: String = "",
		restrict_single_site: bool = false) -> void:
	remaining = count
	white_only = is_white_only
	anywhere = allow_anywhere
	up_to = allow_fewer
	_post_effect_factory = post_factory
	preset_site = site
	lock_after_first = restrict_single_site and site == ""


func _legal_targets(state: GameState, player_id: String) -> Array:
	var result: Array = []
	for slot_id: String in state.graph.slots.keys():
		var owner: String = state.troops.get(slot_id, "")
		if owner == "" or owner == player_id:
			continue
		if white_only and owner != "white":
			continue
		if preset_site != "" and state.graph.site_of_slot(slot_id) != preset_site:
			continue
		if preset_site == "" and not anywhere and not state.presence.has_presence_at_slot(player_id, slot_id, state.troops, state.spies):
			continue
		result.append(slot_id)
	return result


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var slot_id = answer()
		_answered = false
		_answer = null
		if slot_id != null and slot_id != "":
			var owner: String = state.troops.get(slot_id, "")
			if ShieldGuard.can_react(state, player_id, owner):
				# Сначала вопрос жертве (Shield Guardian), потом продолжение.
				var me := self
				resolver.push(CallbackEffect.new(func(s, pid, r): me._after_hit(s, pid, r)), player_id)
				resolver.push(ShieldGuard.new(owner, CallbackEffect.new(
					func(s, pid, r): me._supplant(s, pid, r, slot_id)), "the supplant"), player_id)
				return
			_supplant(state, player_id, resolver, slot_id)
			_after_hit(state, player_id, resolver)
		else:
			remaining = 0
			_continue(state, player_id, resolver)
		return
	_continue(state, player_id, resolver)


func _after_hit(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	remaining -= 1
	_continue(state, player_id, resolver)


func _supplant(state: GameState, player_id: String, resolver: EffectResolver, slot_id: String) -> void:
	var p: PlayerState = state.players[player_id]
	var victim: String = state.troops.get(slot_id, "")
	p.add_trophy(victim)
	if p.troops_in_barracks > 0:
		state.troops[slot_id] = player_id
		p.troops_in_barracks -= 1
		if p.troops_in_barracks == 0:
			GameEnd.trigger(state, "last_troop")
	else:
		state.troops[slot_id] = ""
	resolver.log_event("supplant", {"player_id": player_id, "slot_id": slot_id, "victim": victim})
	if lock_after_first:
		preset_site = state.graph.site_of_slot(slot_id)
		lock_after_first = false
	if _post_effect_factory.is_valid():
		resolver.push(_post_effect_factory.call(slot_id), player_id)


func _continue(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if remaining <= 0:
		return
	var legal: Array = _legal_targets(state, player_id)
	if legal.is_empty():
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Supplant a troop"
	pd.choice_type = "target_slot"
	pd.legal_options = legal
	if up_to:
		pd.legal_options.append("")
	pd.target_effect = self
	resolver.request_decision(pd)
