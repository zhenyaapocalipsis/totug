extends SceneTree

## Замер схемы доски: размер картинки на 2, 3 и 4 игроков по нескольким сидам
## и во сколько раз её можно увеличить в зоне доски (целыми шагами 1/2).
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path engine/godot --script res://tools/measure_board.gd -- --zone=598x456

var PLAYERS := [2, 3, 4]
var SEEDS := [1, 3, 7, 11, 42, 99]


func _init() -> void:
	var zone := Vector2(598, 456)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--zone="):
			var p := arg.trim_prefix("--zone=").split("x")
			zone = Vector2(float(p[0]), float(p[1]))
		elif arg == "--wide":
			PLAYERS = [4]
			SEEDS = range(100, 120)
	for players in PLAYERS:
		for s in SEEDS:
			var ids: Array[String] = []
			ids.assign(["red", "blue", "green", "purple"].slice(0, players))
			var state := GameSetup.new_game(ids, s)
			var t := Time.get_ticks_msec()
			var img := SchematicPainter.paint(BoardSchematic.build(state))
			var fit := minf(zone.x / img.get_width(), zone.y / img.get_height())
			print("%dp seed %3d: %dx%d  fit %.2f  (%d ms)" % [players, s,
				img.get_width(), img.get_height(), fit, Time.get_ticks_msec() - t])
	quit()
