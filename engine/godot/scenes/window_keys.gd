extends Node

## Общие клавиши окна, одни на все экраны игры (автозагрузка в project.godot).
##
## Игра запускается во весь экран: 960x540 умещается на мониторе 1920x1080
## ровно два раза, и пиксель остаётся квадратным. F11 (или Alt+Enter)
## переключает на окно и обратно — иначе из полноэкранного режима не выйти.


func _shortcut_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var toggle := key.keycode == KEY_F11 \
		or (key.keycode == KEY_ENTER and key.alt_pressed)
	if not toggle:
		return
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_viewport().set_input_as_handled()
