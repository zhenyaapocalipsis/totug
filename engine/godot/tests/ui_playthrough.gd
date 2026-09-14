extends SceneTree

## Автопрогон целой партии ЧЕРЕЗ ИНТЕРФЕЙС.
##
## Смысл теста: интерфейс подсвечивает игроку действия по подсказкам сервера
## (view["legal"]). Если подсказка врёт — предлагает слот, который сервер потом
## отвергнет, — играть будет невозможно, а обычные юнит-тесты этого не увидят:
## они зовут правила напрямую, минуя подсказки. Поэтому здесь бот тыкает
## ТОЛЬКО в то, что подсветил интерфейс, и любой отказ сервера считается
## провалом.
##
##   godot47 --headless --path . --script res://tests/ui_playthrough.gd -- --games=5
##
## Гоняется headless: узлы и сигналы работают без экрана, не рисуется только
## картинка, а она здесь не нужна.

const MAX_TURNS := 240
const MAX_STEPS_PER_TURN := 60

var _failures: Array[String] = []
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var games := 5
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--games="):
			games = int(arg.get_slice("=", 1))

	print("\n=== автопрогон партий через интерфейс ===\n")
	for i in range(games):
		_play_one(1000 + i * 37)

	print("")
	if _failures.is_empty():
		print("=== все %d партий доиграны через интерфейс без единого отказа сервера ===\n" % games)
		quit(0)
	else:
		for line in _failures:
			print("  ПРОВАЛ %s" % line)
		print("\n=== провалов: %d ===\n" % _failures.size())
		quit(1)


func _play_one(game_seed: int) -> void:
	_rng.seed = game_seed
	var screen := GameScreen.new(game_seed)
	root.add_child(screen)

	var turns := 0
	var decisions := 0
	var actions := 0
	var rejected := 0

	# Перехватываем отказы сервера: интерфейс их только печатает в журнал,
	# а для теста каждый отказ — дефект подсказок.
	while not screen.server.state.game_over and turns < MAX_TURNS:
		var steps := 0
		var turn_owner: String = screen.server.state.current_player()
		while steps < MAX_STEPS_PER_TURN:
			steps += 1
			var pending: PendingDecision = screen.server.resolver.pending
			var view: Dictionary = StateView.for_player_with_pending(
				screen.server.state, screen.viewer_id, pending)

			if pending != null:
				var answer = _pick_answer(pending)
				var before_pending := pending
				var res: Dictionary = screen.server.apply_intent(
					Intent.make_decision(pending.player_id, answer))
				if int(res["error"]) != GameServer.Error.OK:
					rejected += 1
					_failures.append("сид %d: сервер отверг ответ на решение '%s' (%s)"
						% [game_seed, before_pending.prompt, res["error"]])
					break
				decisions += 1
				continue

			var legal: Dictionary = view.get("legal", {})
			if legal.is_empty():
				break
			var intent := _pick_action(legal, screen.viewer_id)
			if intent == null:
				break
			var result: Dictionary = screen.server.apply_intent(intent)
			if int(result["error"]) != GameServer.Error.OK:
				rejected += 1
				_failures.append("сид %d: сервер отверг действие типа %d, которое интерфейс показал доступным (ошибка %s)"
					% [game_seed, intent.type, result["error"]])
				break
			actions += 1
			if intent.type == Intent.Type.END_TURN:
				break
			# следуем за ходом/решением так же, как это делает интерфейс
			screen.viewer_id = screen.server.resolver.pending.player_id if screen.server.resolver.pending != null \
				else screen.server.state.current_player()

		if screen.server.state.current_player() == turn_owner and not screen.server.state.game_over \
				and screen.server.resolver.pending == null:
			# страховка от зацикливания: если ход почему-то не сменился, завершаем принудительно
			screen.server.apply_intent(Intent.end_turn(turn_owner))
		screen.viewer_id = screen.server.state.current_player()
		turns += 1

	var status := "партия окончена (%s)" % screen.server.state.game_end_reason if screen.server.state.game_over \
		else "упёрлись в предел %d ходов" % MAX_TURNS
	print("  сид %5d: ходов %3d, действий %3d, решений %3d, отказов %d — %s"
		% [game_seed, turns, actions, decisions, rejected, status])

	if not screen.server.state.game_over:
		_failures.append("сид %d: партия не закончилась за %d ходов" % [game_seed, MAX_TURNS])
	_check_invariants(game_seed, screen.server.state)
	screen.queue_free()


## Выбор действия из того, что подсветил интерфейс. Розыгрыш карт и покупки
## предпочитаем завершению хода, иначе партия никогда не сдвинется.
func _pick_action(legal: Dictionary, pid: String) -> Intent:
	var choices: Array = []
	for cid in (legal.get("play_card", []) as Array):
		choices.append(Intent.play_card(pid, String(cid)))
	for slot in (legal.get("deploy_slots", []) as Array):
		choices.append(Intent.deploy(pid, String(slot)))
	for slot2 in (legal.get("assassinate_slots", []) as Array):
		choices.append(Intent.assassinate(pid, String(slot2)))
	for idx in (legal.get("recruit_market", []) as Array):
		choices.append(Intent.recruit(pid, int(idx)))
	for card in (legal.get("recruit_supply", []) as Array):
		choices.append(Intent.recruit_supply(pid, String(card)))
	for target in (legal.get("return_spy", []) as Array):
		var t: Dictionary = target
		choices.append(Intent.return_spy(pid, String(t["site_id"]), String(t["spy_owner"])))
	if bool(legal.get("deploy_for_vp", false)):
		choices.append(Intent.deploy(pid, ""))

	if choices.is_empty():
		return Intent.end_turn(pid) if bool(legal.get("end_turn", false)) else null
	# в 1 случае из 6 заканчиваем ход, даже если есть что делать
	if bool(legal.get("end_turn", false)) and _rng.randi_range(0, 5) == 0:
		return Intent.end_turn(pid)
	return choices[_rng.randi_range(0, choices.size() - 1)]


func _pick_answer(pd: PendingDecision):
	if pd.legal_options.is_empty():
		return null
	return pd.legal_options[_rng.randi_range(0, pd.legal_options.size() - 1)]


## Инварианты, которые должны держаться в любой партии независимо от того,
## что именно натыкал бот.
func _check_invariants(game_seed: int, state: GameState) -> void:
	for pid: String in state.turn_order:
		var p: PlayerState = state.players[pid]
		if p.power < 0 or p.influence < 0:
			_failures.append("сид %d: у %s ушли в минус ресурсы (%d/%d)" % [game_seed, pid, p.power, p.influence])
		if p.troops_in_barracks < 0 or p.spies_in_barracks < 0:
			_failures.append("сид %d: у %s отрицательный барак" % [game_seed, pid])
		var on_board := 0
		for slot_id: String in state.troops.keys():
			if state.troops[slot_id] == pid:
				on_board += 1
		if on_board + p.troops_in_barracks > PlayerState.STARTING_TROOPS:
			_failures.append("сид %d: у %s войск больше, чем было в начале (%d на доске + %d в бараке)"
				% [game_seed, pid, on_board, p.troops_in_barracks])
	for slot_id: String in state.troops.keys():
		if not state.graph.slots.has(slot_id):
			_failures.append("сид %d: войско на несуществующем слоте %s" % [game_seed, slot_id])
			break
	for card_id: String in state.supplies.counts.keys():
		if int(state.supplies.counts[card_id]) < 0:
			_failures.append("сид %d: стопка %s ушла в минус" % [game_seed, card_id])
