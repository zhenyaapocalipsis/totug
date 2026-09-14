class_name ReturnOwnSpy
extends CardEffect

## "Return one of your spies ► <effect>" — распространённый второй вариант в
## Choose one на картах с Guile/шпионской темой. Возвращает СВОЙ шпион в
## барак и (если задан) применяет then_effect; then_site_effect, если задан,
## получает site_id, где стоял возвращённый шпион ("Supplant a troop at that
## spy's site"). is_available() говорит ChooseEffect не предлагать этот
## вариант, если шпионов на доске нет вообще — игроку нечего выбрать.
##
## multi: true — "Return any number of your spies" (Graz'zt): повторяет
## выбор, пока игрок не остановится, затем применяет then_multi_effect с
## массивом site_id всех возвращённых на этот ход шпионов.

var then_effect: CardEffect = null
var then_site_effect: Callable = Callable()      # func(site_id: String) -> CardEffect
var multi: bool = false
var then_multi_effect: Callable = Callable()     # func(site_ids: Array) -> CardEffect
var _collected: Array = []


func _init(effect: CardEffect = null, site_callback: Callable = Callable(),
		allow_multi: bool = false, multi_callback: Callable = Callable()) -> void:
	then_effect = effect
	then_site_effect = site_callback
	multi = allow_multi
	then_multi_effect = multi_callback


func is_available(state: GameState, player_id: String) -> bool:
	return not _own_spy_sites(state, player_id).is_empty()


func _own_spy_sites(state: GameState, player_id: String) -> Array:
	var result: Array = []
	for site_id: String in state.spies.keys():
		if state.spies[site_id].has(player_id):
			result.append(site_id)
	return result


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var site_id = answer()
		_answered = false
		_answer = null
		if site_id == null or site_id == "":
			if multi and not _collected.is_empty() and then_multi_effect.is_valid():
				resolver.push(then_multi_effect.call(_collected.duplicate()), player_id)
			return
		var spies: Array = state.spies.get(site_id, [])
		var idx: int = spies.find(player_id)
		if idx != -1:
			spies.remove_at(idx)
			state.spies[site_id] = spies
			state.players[player_id].spies_in_barracks += 1
			resolver.log_event("return_own_spy", {"player_id": player_id, "site_id": site_id})
		_collected.append(site_id)
		if multi:
			_continue(state, player_id, resolver)
			return
		if then_effect != null:
			resolver.push(then_effect, player_id)
		if then_site_effect.is_valid():
			resolver.push(then_site_effect.call(site_id), player_id)
		return
	_continue(state, player_id, resolver)


func _continue(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	var sites: Array = _own_spy_sites(state, player_id)
	if sites.is_empty():
		if multi and not _collected.is_empty() and then_multi_effect.is_valid():
			resolver.push(then_multi_effect.call(_collected.duplicate()), player_id)
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Return one of your spies"
	pd.choice_type = "target_site"
	pd.legal_options = sites
	if multi:
		pd.legal_options.append("")
	pd.target_effect = self
	resolver.request_decision(pd)
