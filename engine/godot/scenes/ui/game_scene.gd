extends Control

## Тонкая обёртка: сначала меню хотсита (сколько человек за экраном), потом
## сам GameScreen. Оба экрана собираются кодом (см. пояснение в
## scenes/ui/game_screen.gd — .tscn в этом проекте плохо править вслепую,
## без редактора).
##
## Параметры запуска:
##   godot47 --path . res://scenes/ui/game_scene.tscn -- --seed=123 --players=4 --mode=random4
## --players=2..4 пропускает меню и сразу раздаёт столько цветов.

## Файлом, а не глобальным именем класса: так экран виден и без кэша редактора.
const HowToPlayScreen := preload("res://scenes/ui/how_to_play_screen.gd")
const TutorialOfferScreen := preload("res://scenes/ui/tutorial_offer_screen.gd")
const CardLibraryScreen := preload("res://scenes/ui/card_library_screen.gd")


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
			_show_how_to_play(game_seed)
		else:
			_show_setup(game_seed))
	add_child(offer)


## Главное меню. Сюда же возвращает кнопка MAIN MENU из меню по Esc; новая
## партия получает новый сид. page — какую страницу меню открыть (возврат
## из обучения, библиотеки карт и лобби — туда, откуда пришли).
func _show_setup(game_seed: int, page: String = SetupScreen.PAGE_MAIN) -> void:
	_close_net()
	PlayerProfile.seats = {}
	_clear()
	var setup := SetupScreen.new(page)
	setup.started.connect(func(ids: Array[String], m: String): _start_game(ids, game_seed, m))
	setup.online_requested.connect(_show_lobby)
	setup.profile_requested.connect(func(): _show_profile(game_seed))
	setup.how_to_play_requested.connect(func(): _show_how_to_play(game_seed, SetupScreen.PAGE_LIBRARY))
	setup.cards_requested.connect(func():
		_clear()
		var cards: Control = CardLibraryScreen.new()
		cards.closed.connect(func(): _show_setup(game_seed, SetupScreen.PAGE_LIBRARY))
		add_child(cards))
	add_child(setup)


## Профиль из главного меню. Рисовалки рубашки и фона открываются из него и
## возвращают обратно в профиль.
func _show_profile(game_seed: int) -> void:
	_clear()
	var profile := ProfileScreen.new()
	profile.closed.connect(func(): _show_setup(game_seed))
	profile.card_back_requested.connect(func():
		_clear()
		var back := CardBackScreen.new()
		back.closed.connect(func(): _show_profile(game_seed))
		add_child(back))
	profile.background_requested.connect(func():
		_clear()
		var bg := BackgroundScreen.new()
		bg.closed.connect(func(): _show_profile(game_seed))
		add_child(bg))
	add_child(profile)


func _show_how_to_play(game_seed: int, back_page: String = SetupScreen.PAGE_MAIN) -> void:
	_clear()
	var learn: Control = HowToPlayScreen.new()
	learn.closed.connect(func(): _show_setup(game_seed, back_page))
	add_child(learn)


func _clear() -> void:
	for child in get_children():
		child.queue_free()


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
	var back_page: String = {"find": SetupScreen.PAGE_MATCHMAKING, "resume": SetupScreen.PAGE_MAIN}.get(
		kind, SetupScreen.PAGE_LOBBY)
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
	# За одним экраном профиль на компьютере один — он у первого цвета, и этот
	# цвет — любимый цвет профиля, если он выбран.
	var local := PlayerProfile.load_local()
	player_ids = PlayerProfile.seat_first(player_ids, String(local["colour"]))
	PlayerProfile.seats = {player_ids[0]: local}
	var screen := GameScreen.new(game_seed, [], player_ids, mode)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.main_menu_requested.connect(func():
		_show_setup.call_deferred(int(Time.get_unix_time_from_system())))
	add_child(screen)
