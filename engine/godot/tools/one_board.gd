extends SceneTree

## Схема одной партии в PNG (x2). --players=4 --seed=3 --out=board.png
func _init() -> void:
	var players := 4
	var game_seed := 3
	var out := "res://one_board.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players="):
			players = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="):
			game_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--out="):
			out = "res://" + arg.get_slice("=", 1)
	var ids: Array[String] = []
	ids.assign(["red", "blue", "green", "purple"].slice(0, players))
	var img := SchematicPainter.paint(BoardSchematic.build(GameSetup.new_game(ids, game_seed)))
	print("%dx%d (пропорция %.2f)" % [img.get_width(), img.get_height(),
		float(img.get_width()) / float(img.get_height())])
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	quit()
