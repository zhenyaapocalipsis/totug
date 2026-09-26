class_name TakeFromTrophyHall
extends CardEffect

## "Take a white troop from any trophy hall and deploy it anywhere on the
## board" (Mummy Lord) / "take up to N troops from any trophy halls and deploy
## them anywhere on the board" (Orcus) / "take up to N troops from THEIR trophy
## hall and deploy them" (Lich, specific_player_id).
##
## Решение владельца игры (2026-09-15): взятое войско выставляется СВОИМ
## цветом — белое остаётся белым, красное красным. Бараки никого не меняются:
## фигура приходит из трофейного зала. anywhere=false (Lich) — нужно
## Присутствие игрока, как у любого эффекта карты без "anywhere on the board".

var remaining: int
var _total: int  # сколько всего можно взять — для "(1 of 2)" в вопросе
var up_to: bool
var white_only: bool
var specific_player_id: String  # "" = "any trophy hall" (выбор игрока)
var anywhere: bool
var _options: Array[String] = []  # "hall_owner|color", параллельно индексам решения


func _init(count: int = 1, allow_fewer: bool = false, is_white_only: bool = false,
		specific_id: String = "", deploy_anywhere: bool = true) -> void:
	remaining = count
	_total = count
	up_to = allow_fewer
	white_only = is_white_only
	specific_player_id = specific_id
	anywhere = deploy_anywhere


func _collect(state: GameState, player_id: String) -> Array[String]:
	var result: Array[String] = []
	if DeployTrophyTroop.legal_slots(state, player_id, anywhere).is_empty():
		return result
	# "any trophy hall" — только залы соперников, свой не в счёт (решение
	# владельца, 2026-09-26).
	var halls: Array = [specific_player_id] if specific_player_id != "" \
		else state.turn_order.filter(func(pid): return pid != player_id)
	for hall: String in halls:
		var p: PlayerState = state.players[hall]
		var colors: Array = p.trophies.keys()
		colors.sort()
		for color: String in colors:
			if int(p.trophies[color]) > 0 and (not white_only or color == "white"):
				result.append("%s|%s" % [hall, color])
	return result


func is_available(state: GameState, player_id: String) -> bool:
	return not _collect(state, player_id).is_empty()


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var index = answer()
		_answered = false
		_answer = null
		if index == null or int(index) < 0 or int(index) >= _options.size():
			return  # игрок остановился
		var parts: PackedStringArray = _options[int(index)].split("|")
		if not state.players[parts[0]].take_trophy(parts[1]):
			return
		resolver.log_event("take_trophy", {"player_id": player_id, "hall": parts[0], "color": parts[1]})
		remaining -= 1
		# после выставления снова спросим (если ещё осталось что брать)
		resolver.push(self, player_id)
		resolver.push(DeployTrophyTroop.new(parts[1], anywhere), player_id)
		return
	if remaining <= 0:
		return
	_options = _collect(state, player_id)
	if _options.is_empty():
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Take a troop from a trophy hall"
	if _total > 1:
		pd.prompt += " (%d of %d)" % [_total - remaining + 1, _total]
	pd.tag = "trophy_hall"
	# "зал|цвет" по порядку вариантов — окно рисует фишку нужного цвета.
	pd.data = {"trophies": Array(_options)}
	pd.choice_type = "choose_option"
	for i in range(_options.size()):
		var parts: PackedStringArray = _options[i].split("|")
		pd.legal_options.append(i)
		pd.option_labels.append("%s troop from %s's trophy hall" % [parts[1].capitalize(), parts[0].capitalize()])
	if up_to:
		pd.legal_options.append(-1)
		pd.option_labels.append("Skip")
	pd.target_effect = self
	resolver.request_decision(pd)


## Выставить на доску войско цвета color, взятое из трофейного зала.
class DeployTrophyTroop extends CardEffect:
	var color: String
	var anywhere: bool

	func _init(c: String, a: bool) -> void:
		color = c
		anywhere = a

	static func legal_slots(state: GameState, player_id: String, any_site: bool) -> Array:
		if not any_site:
			return Array(state.presence.deployable_slots(player_id, state.troops, state.spies))
		var result: Array = []
		for slot_id: String in state.graph.slots.keys():
			if state.troops.get(slot_id, "") == "":
				result.append(slot_id)
		return result

	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var slot_id = answer()
			if slot_id != null and slot_id != "" and state.troops.get(slot_id, "") == "":
				state.troops[slot_id] = color
				resolver.log_event("deploy_troop", {"player_id": player_id, "slot_id": slot_id, "color": color})
			return
		var legal := legal_slots(state, player_id, anywhere)
		if legal.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Deploy the %s troop" % color
		pd.choice_type = "target_slot"
		pd.legal_options = legal
		pd.target_effect = self
		resolver.request_decision(pd)
