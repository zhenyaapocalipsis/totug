extends SceneTree
func _init() -> void:
	var dir := OS.get_cmdline_user_args()[0]
	var n := int(OS.get_cmdline_user_args()[1])
	var s := int(OS.get_cmdline_user_args()[2])
	var cols := 8
	var cell := s + 10
	var img := Image.create(cols * cell, int(ceil(n / float(cols))) * cell, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.05, 0.07))
	for i in n:
		var a := Image.load_from_file(dir + "/%d.png" % i)
		a.convert(Image.FORMAT_RGBA8)
		var at := Vector2i((i % cols) * cell, (i / cols) * cell)
		img.blend_rect(a, Rect2i(0, 0, s, s), at + Vector2i(0, 9))
		PixelFont.draw_text(img, at.x + 1, at.y + 1, str(i), Color.WHITE)
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(dir + "/sheet.png")
	quit()
