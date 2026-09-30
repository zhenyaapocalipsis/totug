extends SceneTree
## Превью подземелья (CavePainter) со схемой поверх тёмного фона, x2 —
## в "Claude outputs/cave_<N>p_seed<S>.png"; --crop=x,y,w,h — ещё и кусок x5.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path engine/godot --script res://tools/cave_preview.gd -- --players=4 --seed=1
func _init() -> void:
	var players := 4
	var s := 1
	var crop := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players="): players = int(arg.trim_prefix("--players="))
		if arg.begins_with("--seed="): s = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--crop="): crop = arg.trim_prefix("--crop=")
	var ids: Array[String] = []
	ids.assign(["red", "blue", "green", "purple"].slice(0, players))
	var sch := BoardSchematic.build(GameSetup.new_game(ids, s))
	var t := Time.get_ticks_msec()
	var cave := CavePainter.paint(sch)
	var t2 := Time.get_ticks_msec()
	var img := SchematicPainter.paint(sch)
	print("cave %d ms, paint %d ms" % [t2 - t, Time.get_ticks_msec() - t2])
	var out := Image.create(cave.get_width(), cave.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.09, 0.08, 0.16))
	out.blend_rect(cave, Rect2i(Vector2i.ZERO, cave.get_size()), Vector2i.ZERO)
	var m := CavePainter.CAVE_MARGIN
	out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(m, m))
	if crop != "":
		var c := crop.split(",")
		var z := out.get_region(Rect2i(int(c[0]), int(c[1]), int(c[2]), int(c[3])))
		z.resize(z.get_width() * 5, z.get_height() * 5, Image.INTERPOLATE_NEAREST)
		z.save_png("C:/tyrants of the underdark godot/Claude outputs/cave_crop.png")
	out.resize(out.get_width() * 2, out.get_height() * 2, Image.INTERPOLATE_NEAREST)
	out.save_png("C:/tyrants of the underdark godot/Claude outputs/cave_%dp_seed%d.png" % [players, s])
	quit()
