extends Node

## Общие клавиши окна, одни на все экраны игры (автозагрузка в project.godot).
##
## Игра запускается во весь экран: 960x540 умещается на мониторе 1920x1080
## ровно два раза, и пиксель остаётся квадратным. F11 (переназначается в
## настройках) или Alt+Enter переключает на окно и обратно — иначе из
## полноэкранного режима не выйти; выбор запоминается.
##
## Здесь же при запуске применяются настройки (GameSettings) и рисуется
## счётчик кадров, если он включён (SHOW FPS).

const GameSettings := preload("res://scenes/game_settings.gd")

var _fps: Label


func _ready() -> void:
	GameSettings.apply_all()
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_fps = Label.new()
	_fps.theme = PixelTheme.theme()
	_fps.add_theme_color_override("font_color", PixelTheme.GOLD)
	_fps.position = Vector2(2, 0)
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fps)


func _process(_delta: float) -> void:
	_fps.visible = bool(GameSettings.value("show_fps"))
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()


func _shortcut_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var toggle := GameSettings.is_key(key, "fullscreen") \
		or (key.keycode == KEY_ENTER and key.alt_pressed)
	if not toggle:
		return
	var full := GameSettings.window_mode_now() != "window"
	GameSettings.set_value("window_mode", "window" if full else "full")
	get_viewport().set_input_as_handled()
