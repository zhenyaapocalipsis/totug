extends SceneTree

func _init() -> void:
	for s in ([1, 3, 7, 11, 42, 99] if not "--wide" in OS.get_cmdline_user_args() else range(100, 120)):
		var ids: Array[String] = ["red", "blue", "green", "purple"]
		var state := GameSetup.new_game(ids, s)
		var sch := BoardSchematic.build(state)
		var rects := {}
		for site_id: String in (sch["sites"] as Dictionary).keys():
			var r: Array = sch["sites"][site_id]["rect"]
			rects[site_id] = Rect2(r[0], r[1], r[2], r[3])
		for slot_id: String in (sch["rings"] as Dictionary).keys():
			var p: Array = sch["rings"][slot_id]
			rects[slot_id] = Rect2(p[0] - 4, p[1] - 4, 8, 8)
		var keys := rects.keys()
		for i in keys.size():
			for j in range(i + 1, keys.size()):
				if (rects[keys[i]] as Rect2).intersects(rects[keys[j]]):
					print("seed %d: %s %s  x  %s %s" % [s, keys[i], rects[keys[i]], keys[j], rects[keys[j]]])
		var img := SchematicPainter.paint(sch)
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png("res://ov_%d.png" % s)
	quit()
