extends Control

## Тонкая обёртка: сначала меню хотсита (сколько человек за экраном), потом
## сам GameScreen. Оба экрана собираются кодом (см. пояснение в
## scenes/ui/game_screen.gd — .tscn в этом проекте плохо править вслепую,
## без редактора).
##
## Параметры запуска:
##   godot47 --path . res://scenes/ui/game_scene.tscn -- --seed=123 --players=4 --mode=random4
## --players=2..4 пропускает меню и сразу раздаёт столько цветов; --god — режим бога.

## Файлом, а не глобальным именем класса: так экран виден и без кэша редактора.
const TutorialOfferScreen := preload("res://scenes/ui/tutorial_offer_screen.gd")


func _ready() -> void:
	var game_seed := int(Time.get_unix_time_from_system())
	var players := 0
	var mode := GameSetup.MODE_STANDARD
	var bots := false
	var teams := false
	var god := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			game_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--players="):
			players = int(arg.get_slice("=", 1))
		elif arg.begins_with("--mode="):
			mode = arg.get_slice("=", 1)
		elif arg == "--teams":
			teams = true
		elif arg == "--god":
			god = true
		elif arg == "--bots":
			bots = true

	if players >= GameScreen.MIN_PLAYERS:
		_start_game(GameScreen.player_ids_for(players), game_seed, mode, bots, teams, god)
		return

	# Первый запуск: профиля ещё нет — сначала создать его, потом спросить,
	# нужно ли обучение, и только затем главное меню.
	if not PlayerProfile.has_local():
		_show_first_profile(game_seed)
		return

	_show_setup(game_seed)


func _show_first_profile(game_seed: int) -> void:
	_clear()
	var profile := ProfileScreen.new(true)
	profile.closed.connect(func(): _show_tutorial_offer(game_seed))
	add_child(profile)


func _show_tutorial_offer(game_seed: int) -> void:
	_clear()
	var offer: Control = TutorialOfferScreen.new()
	offer.answered.connect(func(wants: bool):
		if wants:
			_show_setup(game_seed, SetupScreen.PAGE_HOW_TO_PLAY)
		else:
			_show_setup(game_seed))
	add_child(offer)


## Главное меню. Сюда же возвращает кнопка MAIN MENU из меню по Esc; новая
## партия получает новый сид. page — какую страницу меню открыть (возврат
## из лобби — туда, откуда пришли; новичку — сразу обучение).
func _show_setup(game_seed: int, page: String = SetupScreen.PAGE_ONLINE) -> void:
	_close_net()
	PlayerProfile.seats = {}
	BoardPanel.team_of = {}
	_clear()
	var setup := SetupScreen.new(page)
	# Пока открыто меню, игра на связи с сервером: она видна в ONLINE, по этой
	# связи приходит LEADERBOARD (владелец, 2026-10-11).
	setup.presence = _open_net()
	setup.presence.watch(SetupScreen.LeaderboardPage.server_address(), NetSession.SERVER_PORT)
	setup.started.connect(func(ids: Array[String], m: String, bots: bool, teams: bool, god: bool):
		_start_game(ids, game_seed, m, bots, teams, god))
	setup.online_requested.connect(func(k: String, c: int, m: String, a: String):
		_show_lobby(k, c, m, a, "", setup.wants_teams(k)))
	setup.replay_requested.connect(_start_replay)
	setup.friend_invite_requested.connect(func(fname: String, count: int, m: String):
		_show_lobby("create", count, m, "", fname, setup.wants_teams("invite")))
	setup.friend_watch_requested.connect(_watch_friend)
	add_child(setup)


func _clear() -> void:
	for child in get_children():
		child.queue_free()


## Сетевая игра: лобби хоста или входа по IP. Связь (NetSession) живёт в
## /root/Net — по одному и тому же пути у всех, иначе RPC не найдут узел.
## address — код комнаты или IP, набранные в меню (вход сразу, без второго
## вопроса).
func _show_lobby(kind: String, count: int = 2, mode: String = GameSetup.MODE_STANDARD,
		address: String = "", invite: String = "", teams: bool = false) -> void:
	for child in get_children():
		child.queue_free()
	_close_net()
	var net := _open_net()
	net.game_started.connect(_start_net_game)
	var lobby := LobbyScreen.new(net, kind, count, mode, address, invite, teams)
	var back_page: String = SetupScreen.PAGE_ONLINE if kind in ["find", "resume"] else SetupScreen.PAGE_LOBBY
	lobby.back_requested.connect(func(): _show_setup(int(Time.get_unix_time_from_system()), back_page))
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


## Новый узел связи в /root/Net (прежний должен быть уже закрыт: _close_net).
func _open_net() -> NetSession:
	var net := NetSession.new()
	net.name = "Net"
	net.profile = PlayerProfile.load_local()
	net.invite_received.connect(_on_invite)
	net.watch_started.connect(_start_watch)
	get_tree().root.add_child(net)
	return net


## Друг зовёт в своё лобби: плашка сверху, JOIN — войти по коду его комнаты.
## Сервер не зовёт тех, кто в партии, так что партию плашка не прервёт.
func _on_invite(from_name: String, code: String) -> void:
	var old := get_node_or_null("Invite")
	if old != null:
		old.free()
	var layer := CanvasLayer.new()
	layer.name = "Invite"
	layer.layer = 50
	add_child(layer)
	var box := PanelContainer.new()
	box.theme = PixelTheme.theme()
	box.add_theme_stylebox_override("panel", PixelTheme.box(PixelTheme.PANEL, PixelTheme.GOLD, 1, 6, 3))
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.position.y = 4
	layer.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	var text := Label.new()
	text.text = "%s invites you to a lobby." % from_name
	text.add_theme_color_override("font_color", PixelTheme.GOLD)
	row.add_child(text)
	for choice: String in ["JOIN", "NO"]:
		var b := Button.new()
		b.text = choice
		b.custom_minimum_size = Vector2(40, 16)
		SetupScreen._style_button(b)
		b.pressed.connect(func():
			layer.queue_free()
			if choice == "JOIN":
				_show_lobby.call_deferred("join_code", 0, "", code))
		row.add_child(b)
	# Сама гаснет через полминуты.
	get_tree().create_timer(30.0).timeout.connect(func():
		if is_instance_valid(layer):
			layer.queue_free())


## Закрыть связь. Узел снимаем с дерева сразу: новый NetSession должен
## получить то же имя "Net", а занятое имя движок молча переименует.
func _close_net() -> void:
	var old := get_tree().root.get_node_or_null("Net")
	if old == null:
		return
	(old as NetSession).close()
	get_tree().root.remove_child(old)
	old.queue_free()


## Реплей из истории партий (Replay-2): тот же экран партии, но партию
## двигает полоса реплея. Выход — обратно в профиль.
func _start_replay(file: String) -> void:
	var replay := ReplayBook.load_replay(file)
	if replay.is_empty():
		return
	for child in get_children():
		child.queue_free()
	PlayerProfile.seats = ((replay["header"] as Dictionary).get("profiles", {}) as Dictionary).duplicate(true)
	var screen := GameScreen.new(0, [], [], GameSetup.MODE_STANDARD, {"replay": replay})
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.main_menu_requested.connect(func():
		_show_setup.call_deferred(int(Time.get_unix_time_from_system()), SetupScreen.PAGE_PROFILE))
	add_child(screen)


func _start_game(player_ids: Array[String], game_seed: int, mode: String, bots: bool = false,
		teams: bool = false, god: bool = false) -> void:
	for child in get_children():
		child.queue_free()
	# За одним экраном профиль на компьютере один — он у первого цвета, и этот
	# цвет — любимый цвет профиля, если он выбран.
	var local := PlayerProfile.load_local()
	# 2 на 2: места не переставляем — команды по местам (1+3 красные, 2+4 синие).
	if not teams:
		player_ids = PlayerProfile.seat_first(player_ids, String(local["colour"]))
	PlayerProfile.seats = {player_ids[0]: local}
	var bot_ids: Array[String] = []
	if bots:
		bot_ids = player_ids.slice(1)
		for pid: String in bot_ids:  # у ботов свои имена и гербы (BotNames)
			if BotNames.BOTS.has(pid):
				PlayerProfile.seats[pid] = BotNames.profile(pid)
	var screen := GameScreen.new(game_seed, [], player_ids, mode, {}, bot_ids, teams, god)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.main_menu_requested.connect(func():
		_show_setup.call_deferred(int(Time.get_unix_time_from_system())))
	add_child(screen)


## WATCH во вкладке FRIENDS — режим зрителя: просим сервер по связи меню,
## партия придёт сигналом watch_started (_start_watch).
func _watch_friend(friend_name: String) -> void:
	var net := get_tree().root.get_node_or_null("Net") as NetSession
	if net != null:
		net.friends_action("watch", [friend_name])


## Партия друга пришла — тот же экран партии, но только смотреть (от лица
## друга, без его руки). Выход — MAIN MENU в меню по Esc.
func _start_watch(friend_seat: String, board: Dictionary, view: Dictionary) -> void:
	var net: NetSession = get_tree().root.get_node("Net")
	for child in get_children():
		child.queue_free()
	PlayerProfile.seats = net.profiles
	var screen := GameScreen.new(0, [], [], GameSetup.MODE_STANDARD,
		{"session": net, "seat": friend_seat, "board": board, "view": view, "watch": true})
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.main_menu_requested.connect(func():
		_show_setup.call_deferred(int(Time.get_unix_time_from_system()), SetupScreen.PAGE_FRIENDS))
	add_child(screen)
