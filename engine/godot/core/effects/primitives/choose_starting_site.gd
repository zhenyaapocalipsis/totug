class_name ChooseStartingSite
extends CardEffect

## Стартовая расстановка (рулбук стр. 4, шаг 11): "each player places one
## troop on an unclaimed starting site" — сайт выбирает САМ игрок, а не
## движок по порядку хода. Один экземпляр — одно решение одного игрока;
## GameServer при создании пушит по одному такому эффекту на каждого игрока
## в порядке хода (см. game_server.gd, _start_setup_if_needed).
##
## Кандидаты берутся из state.starting_site_candidates (заполняет
## GameSetup.new_game при interactive_start=true), а не хранятся в самом
## эффекте — так каждый следующий игрок в цепочке сразу видит сайты, уже
## занятые предыдущими.


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var site_id = answer()
		_answered = false
		_answer = null
		if site_id != null and site_id != "":
			state.setup_deploy_starting_troop(player_id, String(site_id))
			resolver.log_event("choose_starting_site", {"player_id": player_id, "site_id": String(site_id)})
		return

	var legal: Array = _legal_sites(state)
	if legal.is_empty():
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Choose your starting site"
	pd.tag = "starting_site"
	pd.setup = true
	pd.choice_type = "target_site"
	pd.legal_options = legal
	pd.target_effect = self
	resolver.request_decision(pd)


## Рулбук стр. 4: "any starting site on the game map not already taken by
## another player". Раньше годился любой стартовый сайт со свободным слотом —
## второй игрок мог встать в тот же сайт, что и первый. Теперь сайт с войском
## любого игрока занят; белые войска сайт не занимают.
func _legal_sites(state: GameState) -> Array:
	var result: Array = []
	for site_id: String in state.starting_site_candidates:
		var free := false
		var taken := false
		for slot_id: String in state.graph.slots_of_site(site_id):
			var owner: String = state.troops.get(slot_id, "")
			if owner == "":
				free = true
			elif owner != GameState.WHITE:
				taken = true
		if free and not taken:
			result.append(site_id)
	return result
