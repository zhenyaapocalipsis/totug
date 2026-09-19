extends SceneTree

## Снимок игрового экрана в PNG на фиксированном сиде — чтобы смотреть раскладку
## зон, не открывая редактор и не играя руками.
##
## Run: Godot_v4.7.2-stable_win64.exe --path "<...>/engine/godot"
##      --script res://tools/screenshot_game.gd -- "C:/out.png" 2
##
## Второй аргумент — сколько игроков (по умолчанию 2). Кадр снимается не сразу:
## зоны получают настоящий размер только через несколько кадров после запуска.

const WARMUP_FRAMES := 40

var _out := "user://game.png"
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var players := 2
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		players = int(args[1])
	var screen := GameScreen.new(7, [], GameScreen.player_ids_for(players))
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	var img := root.get_texture().get_image()
	img.save_png(_out)
	print("saved ", _out, " ", img.get_size())
	return true
