extends SceneTree

# Sheet of arts with a grid every 100 source px (cyan) and every 500 px (yellow).
func _init() -> void:
	var dir := OS.get_environment("DIR")
	var names: PackedStringArray = OS.get_environment("NAMES").split(" ")
	var cell := int(OS.get_environment("CELL")) if OS.get_environment("CELL") != "" else 300
	var cols := int(OS.get_environment("COLS"))
	var rows := int(ceil(names.size() / float(cols)))
	var sheet := Image.create(cell * cols, cell * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(1, 0, 1))
	for i in names.size():
		var img := Image.load_from_file(dir + "/" + names[i])
		img.convert(Image.FORMAT_RGBA8)
		var s: float = float(cell - 4) / maxf(img.get_width(), img.get_height())
		var w := int(img.get_width() * s)
		var h := int(img.get_height() * s)
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		for gx in range(0, 1001, 100):
			var x := int(gx * s)
			if x >= w:
				break
			for y in h:
				img.set_pixel(x, y, Color.YELLOW if gx % 500 == 0 else Color.CYAN)
		for gy in range(0, 1001, 100):
			var y := int(gy * s)
			if y >= h:
				break
			for x in w:
				img.set_pixel(x, y, Color.YELLOW if gy % 500 == 0 else Color.CYAN)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * cell + 2, (i / cols) * cell + 2))
	sheet.save_jpg(OS.get_environment("OUT"), 0.9)
	quit()
