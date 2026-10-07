class_name DeployTroop
extends CardEffect

## "Deploy N troop(s)" как эффект карты — в отличие от базового действия
## Actions.deploy(), НЕ стоит 1 Power. Решение владельца (2026-09-28): как и
## базовое действие, при пустом бараке каждое неразмещённое войско карты даёт
## 1 VP взамен (Neogi с пустым бараком = 4 VP). Если войска в бараке есть, но
## ставить некуда — ничего (мягкий отказ, партия не блокируется).
##
## remaining — сколько войск ещё нужно развернуть в этой цепочке вызовов;
## каждый вызов apply() либо запрашивает один слот, либо (remaining <= 0 /
## неоткуда разворачивать) завершается без действия.

var remaining: int
var up_to: bool
## "deploy ... there" — локацию назвала карта: только её пустые слоты, без
## проверки Присутствия (как у других эффектов с названной локацией).
var site: String = ""


func _init(count: int = 1, allow_fewer: bool = false, at_site: String = "") -> void:
	remaining = count
	up_to = allow_fewer
	site = at_site


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var slot_id = answer()
		if slot_id == null or slot_id == "":
			return  # игрок остановился ("up to N") — дальше не спрашиваем
		_deploy_at(state, player_id, slot_id, resolver)
		_continue(state, player_id, resolver)
		return
	_continue(state, player_id, resolver)


func _continue(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if remaining <= 0:
		return
	var p: PlayerState = state.players[player_id]
	if p.troops_in_barracks <= 0:
		var granted: int = state.vp_bank.grant(remaining)
		p.vp_tokens += granted
		resolver.log_event("gain_vp", {"player_id": player_id, "amount": granted})
		return
	var legal: PackedStringArray = state.presence.deployable_slots(player_id, state.troops, state.spies)
	if site != "":
		legal = PackedStringArray()
		for slot_id: String in state.graph.slots_of_site(site):
			if state.troops.get(slot_id, "") == "":
				legal.append(slot_id)
	if legal.is_empty():
		return

	var next := DeployTroop.new(remaining - 1, up_to, site)
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Deploy a troop"
	pd.choice_type = "target_slot"
	pd.legal_options = Array(legal)
	if up_to:
		pd.legal_options.append("")
	pd.target_effect = next
	resolver.request_decision(pd)


func _deploy_at(state: GameState, player_id: String, slot_id: String, resolver: EffectResolver) -> void:
	var p: PlayerState = state.players[player_id]
	state.troops[slot_id] = player_id
	p.troops_in_barracks -= 1
	if p.troops_in_barracks == 0:
		GameEnd.trigger(state, "last_troop")
	resolver.log_event("deploy_troop", {"player_id": player_id, "slot_id": slot_id})
