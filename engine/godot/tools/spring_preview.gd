extends SceneTree

## Предпросмотр раскладки из графа (BoardSchematic._spring_layout).
## Run: ... --script res://tools/spring_preview.gd -- <куда.png> <игроков> <сид>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "C:/spring.png"
	var players := int(args[1]) if args.size() > 1 else 4
	var seed_value := int(args[2]) if args.size() > 2 else 3
	BoardSchematic.layout_mode = BoardSchematic.Layout.TREE
	for a in OS.get_cmdline_user_args():
		if a == "spring":
			BoardSchematic.layout_mode = BoardSchematic.Layout.SPRING
	var state := GameSetup.new_game(GameScreen.player_ids_for(players), seed_value)
	var started := Time.get_ticks_msec()
	var s := BoardSchematic.build(state)
	var took := Time.get_ticks_msec() - started
	print("%dp сид %d: %dx%d, %d мс" % [players, seed_value,
		int(s["size"][0]), int(s["size"][1]), took])
	var img := SchematicPainter.paint(s)
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	quit()
