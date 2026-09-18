extends Control

## Тонкая обёртка: сначала меню хотсита (сколько человек за экраном), потом
## сам GameScreen. Оба экрана собираются кодом (см. пояснение в
## scenes/ui/game_screen.gd — .tscn в этом проекте плохо править вслепую,
## без редактора).
##
## Параметры запуска:
##   godot47 --path . res://scenes/ui/game_scene.tscn -- --seed=123 --players=4
## --players=2..4 пропускает меню и сразу раздаёт столько цветов.

func _ready() -> void:
	var game_seed := int(Time.get_unix_time_from_system())
	var players := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			game_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--players="):
			players = int(arg.get_slice("=", 1))

	if players >= GameScreen.MIN_PLAYERS:
		_start_game(GameScreen.player_ids_for(players), game_seed)
		return

	var setup := SetupScreen.new()
	setup.started.connect(func(ids: Array[String]): _start_game(ids, game_seed))
	add_child(setup)


func _start_game(player_ids: Array[String], game_seed: int) -> void:
	for child in get_children():
		child.queue_free()
	var screen := GameScreen.new(game_seed, [], player_ids)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
