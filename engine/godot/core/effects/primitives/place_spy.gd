class_name PlaceSpy
extends CardEffect

## "Place a spy" (рулбук стр. 12) — карточный эффект, доступный на ЛЮБОЙ сайт
## без требования Присутствия (шпион сам даёт Присутствие). last_site_id
## устанавливается на выбранный сайт, если вызывающему коду (card_library)
## нужно связать последующий эффект с местом постановки шпиона
## ("assassinate a troop at that spy's site" и т.п.) — через колбэк
## on_placed(site_id) -> CardEffect, который, если задан, пушится в стек.

var remaining: int
var up_to: bool
var on_placed: Callable = Callable()  # func(site_id: String) -> CardEffect


func _init(count: int = 1, allow_fewer: bool = false, placed_callback: Callable = Callable()) -> void:
	remaining = count
	up_to = allow_fewer
	on_placed = placed_callback


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var site_id = answer()
		if site_id == null or site_id == "":
			return
		_place_at(state, player_id, site_id, resolver)
		if on_placed.is_valid():
			resolver.push(on_placed.call(site_id), player_id)
		_continue(state, player_id, resolver)
		return
	_continue(state, player_id, resolver)


func _continue(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if remaining <= 0:
		return
	var p: PlayerState = state.players[player_id]
	if p.spies_in_barracks <= 0:
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Place a spy"
	pd.choice_type = "target_site"
	pd.legal_options = Array(state.graph.sites.keys())
	if up_to:
		pd.legal_options.append("")
	pd.target_effect = PlaceSpy.new(remaining - 1, up_to, on_placed)
	resolver.request_decision(pd)


func _place_at(state: GameState, player_id: String, site_id: String, resolver: EffectResolver) -> void:
	var p: PlayerState = state.players[player_id]
	p.spies_in_barracks -= 1
	var site_spies: Array = state.spies.get(site_id, [])
	site_spies.append(player_id)
	state.spies[site_id] = site_spies
	resolver.log_event("place_spy", {"player_id": player_id, "site_id": site_id})
