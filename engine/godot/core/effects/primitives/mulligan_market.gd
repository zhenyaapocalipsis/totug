class_name MulliganMarket
extends CardEffect

## Муллиган рынка перед стартовой расстановкой (решение владельца,
## 2026-10-08): каждый игрок по очереди хода, начиная с первого, может
## заменить одну любую карту рынка или пропустить. Один экземпляр — одно
## решение одного игрока; GameServer пушит цепочку (см. game_server.gd,
## _start_setup_if_needed). finish=true — замыкающий эффект цепочки без
## вопроса: вмешивает убранные карты обратно в колоду (Market.finish_mulligan).

var finish: bool = false


func _init(is_finish: bool = false) -> void:
	finish = is_finish


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if finish:
		state.market.finish_mulligan(state.rng)
		return

	if is_answered():
		var index = answer()
		_answered = false
		_answer = null
		if index != null and int(index) != -1:
			var removed := state.market.mulligan_replace(int(index))
			if removed != "":
				resolver.log_event("market_mulligan", {"player_id": player_id, "card_id": removed,
					"new_card_id": state.market.display[int(index)]})
		return

	var options: Array = []
	for i in range(state.market.display.size()):
		if state.market.display[i] != "":
			options.append(i)
	if options.is_empty():
		return
	options.append(-1)
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "You may replace one market card"
	pd.choice_type = "target_market_index"
	pd.tag = "market"  # выбор прямо на рынке справа
	pd.setup = true
	pd.legal_options = options
	pd.target_effect = self
	resolver.request_decision(pd)
