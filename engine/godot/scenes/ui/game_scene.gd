extends Control

## Тонкая обёртка: сначала меню хотсита (сколько человек за экраном), потом
## сам GameScreen. Оба экрана собираются кодом (см. пояснение в
## scenes/ui/game_screen.gd — .tscn в этом проекте плохо править вслепую,
## без редактора).
##
## Параметры запуска:
##   godot47 --path . res://scenes/ui/game_scene.tscn -- --seed=123 --players=4 --mode=random4
## --players=2..4 пропускает меню и сразу раздаёт столько цветов.

func _ready() -> void:
	var game_seed := int(Time.get_unix_time_from_system())
	var players := 0
	var mode := GameSetup.MODE_STANDARD
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			game_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--players="):
			players = int(arg.get_slice("=", 1))
		elif arg.begins_with("--mode="):
			mode = arg.get_slice("=", 1)

	if players >= GameScreen.MIN_PLAYERS:
		_start_game(GameScreen.player_ids_for(players), game_seed, mode)
		return

	_show_setup(game_seed)


## Главное меню: выбор режима и числа игроков. Сюда же возвращает кнопка
## MAIN MENU из меню по Esc; новая партия получает новый сид.
func _show_setup(game_seed: int) -> void:
	_close_net()
	PlayerProfile.seats = {}
	for child in get_children():
		child.queue_free()
	var setup := SetupScreen.new()
	setup.started.connect(func(ids: Array[String], m: String): _start_game(ids, game_seed, m))
	setup.online_requested.connect(_show_lobby)
	setup.profile_requested.connect(func():
		for child in get_children():
			child.queue_free()
		var profile := ProfileScreen.new()
		profile.closed.connect(func(): _show_setup(game_seed))
		add_child(profile))
	add_child(setup)


## Сетевая игра: лобби хоста или входа по IP. Связь (NetSession) живёт в
## /root/Net — по одному и тому же пути у всех, иначе RPC не найдут узел.
func _show_lobby(kind: String, count: int = 2, mode: String = GameSetup.MODE_STANDARD) -> void:
	for child in get_children():
		child.queue_free()
	_close_net()
	var net := NetSession.new()
	net.name = "Net"
	net.profile = PlayerProfile.load_local()
	get_tree().root.add_child(net)
	net.game_started.connect(_start_net_game)
	var lobby := LobbyScreen.new(net, kind, count, mode)
	lobby.back_requested.connect(func(): _show_setup(int(Time.get_unix_time_from_system())))
	add_child(lobby)


func _start_net_game(seat: String, board: Dictionary, view: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	var net: NetSession = get_tree().root.get_node("Net")
	PlayerProfile.seats = net.profiles
	var screen := GameScreen.new(0, [], [], GameSetup.MODE_STANDARD,
		{"session": net, "seat": seat, "board": board, "view": view})
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.main_menu_requested.connect(func():
		_show_setup.call_deferred(int(Time.get_unix_time_from_system())))
	add_child(screen)


## Закрыть связь. Узел снимаем с дерева сразу: новый NetSession должен
## получить то же имя "Net", а занятое имя движок молча переименует.
func _close_net() -> void:
	var old := get_tree().root.get_node_or_null("Net")
	if old == null:
		return
	(old as NetSession).close()
	get_tree().root.remove_child(old)
	old.queue_free()


func _start_game(player_ids: Array[String], game_seed: int, mode: String) -> void:
	for child in get_children():
		child.queue_free()
	# За одним экраном профиль на компьютере один — он у первого цвета.
	PlayerProfile.seats = {player_ids[0]: PlayerProfile.load_local()}
	var screen := GameScreen.new(game_seed, [], player_ids, mode)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.main_menu_requested.connect(func():
		_show_setup.call_deferred(int(Time.get_unix_time_from_system())))
	add_child(screen)
