extends SceneTree

## Кусок схемы вокруг названной локации, крупно. --site=REDGA
func _init() -> void:
	var want := "REDGA"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--site="):
			want = arg.get_slice("=", 1)
	var ids: Array[String] = ["red", "blue", "green", "purple"]
	var sch := BoardSchematic.build(GameSetup.new_game(ids, 3))
	var img := SchematicPainter.paint(sch)
	var at := Rect2()
	for site_id: String in (sch["sites"] as Dictionary).keys():
		if BoardSchematic.short_name(String(sch["sites"][site_id]["name"])).begins_with(want):
			var r: Array = sch["sites"][site_id]["rect"]
			at = Rect2(r[0], r[1], r[2], r[3])
	print("%s: %s" % [want, at])
	var region := Rect2i(at.grow(35))
	region = region.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var cut := img.get_region(region)
	cut.resize(cut.get_width() * 6, cut.get_height() * 6, Image.INTERPOLATE_NEAREST)
	cut.save_png("res://crop.png")
	quit()
