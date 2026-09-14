class_name TakeFromTrophyHall
extends CardEffect

## "Take a white troop from any trophy hall and deploy it anywhere on the
## board" / "take up to N troops from any trophy halls and deploy them" /
## "take up to N troops from THEIR trophy hall and deploy them" (Lich, "their"
## = specific_player_id resuelto por card_library en el momento de construir
## el efecto).
##
## Собственная трактовка (мод/рулбук не разбирают детально): трофи-холл в
## этом движке — просто счётчик (PlayerState.trophy_hall_count /
## white_trophy_count), а не список конкретных фигур с исходным цветом.
## "Взять войско из трофи-холла и развернуть" реализовано как: уменьшить
## счётчик у выбранного трофи-холла на 1, затем игрок разворачивает СВОЁ
## войско из своего барака (обычный DeployTroop) — то есть троп-холл здесь
## выступает лимитирующим ресурсом действия, а не источником конкретной
## фигуры. Если владелец игры хочет другую трактовку — поправить здесь.

var remaining: int
var up_to: bool
var white_only: bool
var specific_player_id: String  # "" = "any trophy hall" (выбор игрока)


func _init(count: int = 1, allow_fewer: bool = false, is_white_only: bool = false, specific_id: String = "") -> void:
	remaining = count
	up_to = allow_fewer
	white_only = is_white_only
	specific_player_id = specific_id


func _eligible_players(state: GameState) -> Array:
	var result: Array = []
	for pid: String in state.turn_order:
		var p: PlayerState = state.players[pid]
		var has_some: bool = (p.white_trophy_count > 0) if white_only else (p.trophy_hall_count > 0)
		if has_some:
			result.append(pid)
	return result


func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if is_answered():
		var target = answer()
		_answered = false
		_answer = null
		if target != null and target != "":
			_take_one(state, String(target))
			resolver.push(DeployTroop.new(1, false), player_id)
			remaining -= 1
		else:
			remaining = 0
		_continue(state, player_id, resolver)
		return
	_continue(state, player_id, resolver)


func _take_one(state: GameState, from_player: String) -> void:
	var p: PlayerState = state.players[from_player]
	if white_only:
		p.white_trophy_count = maxi(0, p.white_trophy_count - 1)
	p.trophy_hall_count = maxi(0, p.trophy_hall_count - 1)


func _continue(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if remaining <= 0:
		return
	if specific_player_id != "":
		var p: PlayerState = state.players[specific_player_id]
		var has_some: bool = (p.white_trophy_count > 0) if white_only else (p.trophy_hall_count > 0)
		if not has_some:
			return
		_take_one(state, specific_player_id)
		resolver.push(DeployTroop.new(1, false), player_id)
		remaining -= 1
		_continue(state, player_id, resolver)
		return

	var options: Array = _eligible_players(state)
	if options.is_empty():
		return
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = "Take a troop from a trophy hall"
	pd.choice_type = "target_player"
	pd.legal_options = options
	if up_to:
		pd.legal_options.append("")
	pd.target_effect = self
	resolver.request_decision(pd)
