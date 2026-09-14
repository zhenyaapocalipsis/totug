extends Control

## Тонкая обёртка над GameScreen: сам экран собирается кодом (см. пояснение
## в scenes/ui/game_screen.gd — .tscn в этом проекте плохо править вслепую,
## без редактора).
##
## Сид партии можно задать при запуске:
##   godot47 --path . res://scenes/ui/game_scene.tscn -- --seed=123

func _ready() -> void:
	var game_seed := int(Time.get_unix_time_from_system())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			game_seed = int(arg.get_slice("=", 1))
	var screen := GameScreen.new(game_seed)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
