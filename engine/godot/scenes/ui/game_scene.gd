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
	for child in get_children():
		child.queue_free()
	var setup := SetupScreen.new()
	setup.started.connect(func(ids: Array[String], m: String): _start_game(ids, game_seed, m))
	add_child(setup)


func _start_game(player_ids: Array[String], game_seed: int, mode: String) -> void:
	for child in get_children():
		child.queue_free()
	var screen := GameScreen.new(game_seed, [], player_ids, mode)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.main_menu_requested.connect(func():
		_show_setup.call_deferred(int(Time.get_unix_time_from_system())))
	add_child(screen)
