extends SceneTree

## Снимок гербов ботов (BotNames) на фишках: ряд своих цветов и ряд 2v2.
## godot --headless --path . --script res://tests/bot_emblems_shot.gd -- --out=file.png

func _initialize() -> void:
	var out := "user://bot_emblems.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
	var seats := ["red", "green", "blue", "purple"]
	var team := {"red": "red", "green": "red", "blue": "blue", "purple": "blue"}
	var cell := 11
	var img := Image.create(cell * 4 + 1, cell * 2 + 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.09, 0.12))
	for i in seats.size():
		var pid: String = seats[i]
		var e := BotNames.emblem(pid)
		check(PlayerProfile.clean_emblem(e) == e, pid)
		for row in 2:
			var colour: Color = BoardPanel.PLAYER_COLORS[pid if row == 0 else team[pid]]
			img.blend_rect(SchematicPainter.token(colour, e), Rect2i(0, 0, 9, 9), Vector2i(i * cell + 2, row * cell + 2))
	img.resize(img.get_width() * 16, img.get_height() * 16, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	print("saved ", out)
	quit()


func check(ok: bool, pid: String) -> void:
	if not ok:
		print("герб %s не прошёл clean_emblem (закрашено слишком много?)" % pid)
