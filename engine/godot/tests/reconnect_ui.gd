extends SceneTree
## Экран партии, собранный так же, как при переподключении (game_scene._start_net_game),
## когда у вернувшегося игрока висит вопрос карты. Перебирает все карты, которые
## при розыгрыше о чём-то спрашивают; ошибки скриптов видны в выводе.
## Запуск: --script res://tests/reconnect_ui.gd [-- --card=ID] [--played]
## В собранной игре (release) вызов метода у null не ошибка, а вылет — поэтому
## в выводе не должно быть ни одного SCRIPT ERROR.

const FRAMES_PER_CARD := 20

var _frame := 0
var _cards: Array[String] = []
var _screen: GameScreen
var _net: NetSession
var _shown := 0
## --played: не переподключение, а обычный розыгрыш у клиента.
var _played := OS.get_cmdline_user_args().has("--played")


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--card="):
			_cards.append(arg.get_slice("=", 1))
	if _cards.is_empty():
		_cards = CardLibrary.all_ids()
	_net = NetSession.new()
	_net.name = "Net"
	root.add_child(_net)


func _next_screen() -> bool:
	if _screen != null:
		_screen.free()
		_screen = null
	while not _cards.is_empty():
		var card: String = _cards.pop_front()
		var ids: Array[String] = ["red", "green"]
		var state := GameSetup.new_game(ids, 1, [], false, true, true, GameSetup.MODE_STANDARD, false)
		var server := GameServer.new(state)
		while server.resolver.is_waiting():
			var pd: PendingDecision = server.resolver.pending
			server.apply_intent(Intent.make_decision(pd.player_id, pd.legal_options[0]))
		var pid: String = state.current_player()
		state.players[pid].deck.hand.append(card)
		var before := StateView.for_player_with_pending(state, pid, null)
		server.apply_intent(Intent.play_card(pid, card))
		var pending: PendingDecision = server.resolver.pending
		var seat := pid if pending == null else pending.player_id
		var view := StateView.for_player_with_pending(state, seat, pending)
		var board := StateView.board_snapshot(state)
		if _played:
			# Обычный путь клиента: экран уже в окне, приходит срез после розыгрыша.
			_screen = GameScreen.new(0, [], [], GameSetup.MODE_STANDARD,
				{"session": _net, "seat": pid, "board": board, "view": before})
			root.add_child(_screen)
			_screen.refresh(StateView.for_player_with_pending(state, pid, pending))
		else:
			if pending == null:
				continue
			_screen = GameScreen.new(0, [], [], GameSetup.MODE_STANDARD,
				{"session": _net, "seat": seat, "board": board, "view": view})
			root.add_child(_screen)
		_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		_shown += 1
		return true
	return false


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame % FRAMES_PER_CARD == 1:
		if not _next_screen():
			print("reconnect_ui: карт с вопросом: %d" % _shown)
			return true
	return false
