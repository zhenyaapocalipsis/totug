extends SceneTree

## Предпросмотр свободной упаковки карты (BoardSchematic._pack): рисует схему
## в PNG и печатает размер, наложения рамок и время сборки.
## Run: ... --script res://tools/pack_preview.gd -- <куда.png> <игроков> <сид>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "C:/pack.png"
	var players := int(args[1]) if args.size() > 1 else 4
	var seed_value := int(args[2]) if args.size() > 2 else 3
	var zone: Vector2 = GameScreen.board_zone_rect().size
	BoardSchematic.pack_into = zone - Vector2(BoardSchematic.IMAGE_MARGIN, BoardSchematic.IMAGE_MARGIN) * 2.0
	var state := GameSetup.new_game(GameScreen.player_ids_for(players), seed_value)
	var started := Time.get_ticks_msec()
	var s := BoardSchematic.build(state)
	var took := Time.get_ticks_msec() - started
	var rects: Array = []
	for site_id: String in (s["sites"] as Dictionary):
		var r: Array = s["sites"][site_id]["rect"]
		rects.append(Rect2(r[0], r[1], r[2], r[3]))
	for ring_id: String in (s["rings"] as Dictionary):
		var q: Array = s["rings"][ring_id]
		rects.append(Rect2(q[0] - BoardSchematic.RING_R, q[1] - BoardSchematic.RING_R,
			BoardSchematic.RING_R * 2, BoardSchematic.RING_R * 2))
	var overlaps := 0
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).intersects(rects[j]):
				overlaps += 1
	print("%dp seed %d: %dx%d (зона %dx%d), наложений %d, %d мс" % [players, seed_value,
		int(s["size"][0]), int(s["size"][1]), int(zone.x), int(zone.y), overlaps, took])
	var img := SchematicPainter.paint(s)
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	quit()
