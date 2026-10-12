extends SceneTree
## Партии ботов глазами СЕТЕВЫХ клиентов: у каждого игрока свой экран партии в
## сетевом режиме, срезы приходят так же, как от сервера (GameScreen._on_result).
## По ходу партии случайный игрок «переподключается» (экран собирается заново
## из текущего среза, как game_scene._start_net_game), а зритель то приходит,
## то уходит. В собранной игре (release) ошибка скрипта может быть вылетом,
## поэтому в выводе не должно быть ни одного SCRIPT ERROR.
## Запуск: --script res://tests/net_ui_sweep.gd [-- games=6 seed=500]
## Игроков по кругу 2, 3, 4, 4 командами. Медленно: партия вдвоём ~5 минут, втроём дольше.

const MAX_STEPS := 6000

var _games := 6
var _seed := 500
var _game := -1
var _net: NetSession
var _server: GameServer
var _screens: Dictionary = {}    # pid -> GameScreen
var _watcher: GameScreen
var _watch_seat := ""
var _steps := 0
var _rng := RandomNumberGenerator.new()
var _reconnects := 0
var _watches := 0
var _after_end := 0


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("games="):
			_games = int(a.get_slice("=", 1))
		elif a.begins_with("seed="):
			_seed = int(a.get_slice("=", 1))
	_net = NetSession.new()
	_net.name = "Net"
	root.add_child(_net)
	_next_game()


func _next_game() -> bool:
	for s: GameScreen in _screens.values():
		s.free()
	_screens.clear()
	if _watcher != null:
		_watcher.free()
		_watcher = null
	_game += 1
	if _game >= _games:
		return false
	var players: int = [2, 3, 4, 4][_game % 4]
	var teams := _game % 4 == 3
	var ids := GameScreen.player_ids_for(players)
	_rng.seed = _seed + _game
	var state := GameSetup.new_game(ids, _seed + _game, [], false, true, true,
		GameSetup.MODE_STANDARD, teams)
	_server = GameServer.new(state)
	_steps = 0
	_after_end = 0
	var board := StateView.board_snapshot(state)
	for pid: String in ids:
		_screens[pid] = _make_screen(pid, board, _view(pid), false)
	print("партия %d: %d игроков%s" % [_game + 1, players, ", команды" if teams else ""])
	return true


func _view(pid: String) -> Dictionary:
	return StateView.for_player_with_pending(_server.state, pid, _server.resolver.pending)


func _make_screen(pid: String, board: Dictionary, view: Dictionary, watch: bool) -> GameScreen:
	var online := {"session": _net, "seat": pid, "board": board, "view": view}
	if watch:
		online["watch"] = true
	var s := GameScreen.new(0, [], [], GameSetup.MODE_STANDARD, online)
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(s)
	return s


func _process(_delta: float) -> bool:
	var state := _server.state
	if state.game_over or _steps >= MAX_STEPS:
		# Пусть доиграют анимации и экран конца партии.
		_after_end += 1
		if _after_end < 30:
			return false
		print("  ходов-действий %d, переподключений %d, зрителей %d%s" % [
			_steps, _reconnects, _watches, "" if state.game_over else " — НЕ ДОИГРАНА"])
		if not _next_game():
			print("net_ui_sweep: готово")
			return true
		return false
	_steps += 1
	var intent := BotPlayer.next_intent(_server, BotPlayer.acting_player(_server), true)
	var result := _server.apply_intent(intent)
	var views: Dictionary = result["views"]
	for pid: String in _screens:
		(_screens[pid] as GameScreen)._on_result(int(result["error"]), result["events"], views[pid])
	if _watcher != null:
		_watcher._on_result(GameServer.Error.OK, result["events"], views[_watch_seat])
	var board := StateView.board_snapshot(state)
	# Переподключение: экран игрока собирается заново посреди партии.
	if _rng.randf() < 0.02:
		var ids: Array = _screens.keys()
		var pid: String = ids[_rng.randi() % ids.size()]
		(_screens[pid] as GameScreen).free()
		_screens[pid] = _make_screen(pid, board, views[pid], false)
		_reconnects += 1
	# Зритель приходит и уходит.
	if _rng.randf() < 0.01:
		if _watcher != null:
			_watcher.free()
			_watcher = null
		else:
			var ids2: Array = _screens.keys()
			_watch_seat = ids2[_rng.randi() % ids2.size()]
			_watcher = _make_screen(_watch_seat, board, views[_watch_seat], true)
			_watches += 1
	return false
