class_name AssassinateTroop
extends CardEffect

## "Assassinate N troop(s)" as a card effect (no 3 Power cost). Like the basic
## action, the target must be in the player's Presence (confirmed by the game
## owner). Exception: preset_site ("at that spy's site") — the card itself
## names the site, so Presence is not checked there. white_only ограничивает выбор
## белыми войсками. single_site: после первого выбора все следующие цели этой
## же цепочки ограничены тем же сайтом ("at a single site").
##
## gain_influence_per_removed / gain_power_per_removed — точечная поддержка
## карт вида "For each troop removed, gain 1 Influence" (Death Tyrant):
## начисляется сразу при каждом успешном убийстве, а не отдельным подсчётом.

var remaining: int
var total: int  ## исходное N — для подсказки "(N left)"
var white_only: bool
var up_to: bool
var single_site: bool
var locked_site: String = ""
var gain_influence_per_removed: int
var gain_power_per_removed: int
var site_given_by_card: bool = false


func _init(count: int = 1, is_white_only: bool = false, allow_fewer: bool = false,
		restrict_single_site: bool = false, inf_per_removed: int = 0, pow_per_removed: int = 0,
		preset_site: String = "") -> void:
	remaining = count
	total = count
	white_only = is_white_only
	up_to = allow_fewer
	single_site = restrict_single_site or preset_site != ""
	gain_influence_per_removed = inf_per_removed
	gain_power_per_removed = pow_per_removed
	locked_site = preset_site
	site_given_by_card = preset_site != ""


func _legal_targets(state: GameState, player_id: String) -> Array:
	var result: Array = []
	for slot_id: String in state.graph.slots.keys():
		var owner: String = state.troops.get(slot_id, "")
		if owner == "" or owner == player_id:
			continue
		if white_only and owner != "white":
			continue
		if single_site and locked_site != "":
			if state.graph.site_of_slot(slot_id) != locked_site:
				continue
		if not site_given_by_card and not state.presence.has_presence_at_slot(player_id, slot_id, state.troops, state.spies):
			continue
		result.append(slot_id)
	return result


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var slot_id = answer()
		if slot_id == null or slot_id == "":
			return
		var owner: String = state.troops.get(slot_id, "")
		if ShieldGuard.can_react(state, player_id, owner):
			# Сначала вопрос жертве (Shield Guardian), потом продолжение.
			var me := self
			resolver.push(CallbackEffect.new(func(s, pid, r): me._after_hit(s, pid, r, slot_id)), player_id)
			resolver.push(ShieldGuard.new(owner, CallbackEffect.new(
				func(s, pid, r): me._kill(s, pid, slot_id, r)), "the assassination"), player_id)
			return
		_kill(state, player_id, slot_id, resolver)
		_after_hit(state, player_id, resolver, slot_id)
		return
	_continue(state, player_id, resolver)


func _after_hit(state: GameState, player_id: String, resolver: EffectResolver, slot_id: String) -> void:
	if single_site and locked_site == "":
		locked_site = state.graph.site_of_slot(slot_id)
	_continue(state, player_id, resolver)


func _continue(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if remaining <= 0:
		return
	var legal: Array = _legal_targets(state, player_id)
	if legal.is_empty():
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Assassinate a white troop" if white_only else "Assassinate a troop"
	# Сколько ещё можно убить — видно, пока эффект убивает больше одного
	# (Quaggoth: по войску за каждый контролируемый сайт).
	if total > 1:
		pd.prompt += " (%d left)" % remaining
	pd.choice_type = "target_slot"
	pd.legal_options = legal
	if up_to:
		pd.legal_options.append("")
	var next := AssassinateTroop.new(remaining - 1, white_only, up_to, single_site,
		gain_influence_per_removed, gain_power_per_removed)
	next.total = total
	next.locked_site = locked_site
	next.site_given_by_card = site_given_by_card
	pd.target_effect = next
	resolver.request_decision(pd)


func _kill(state: GameState, player_id: String, slot_id: String, resolver: EffectResolver) -> void:
	var victim: String = state.troops.get(slot_id, "")
	state.troops[slot_id] = ""
	var p: PlayerState = state.players[player_id]
	p.add_trophy(victim)
	if gain_influence_per_removed > 0:
		p.influence += gain_influence_per_removed
	if gain_power_per_removed > 0:
		p.power += gain_power_per_removed
	resolver.log_event("assassinate", {"player_id": player_id, "slot_id": slot_id, "victim": victim})
