extends SceneTree

# Packs PDF card images FROM..TO into 2x2 sheets at half size.
func _init() -> void:
	var dir := OS.get_environment("PDF_DIR")
	var from := int(OS.get_environment("FROM"))
	var to := int(OS.get_environment("TO"))
	var w := 864
	var h := 1164
	var i := from
	var s := 0
	while i <= to:
		var sheet := Image.create(w * 2, h * 2, false, Image.FORMAT_RGB8)
		sheet.fill(Color.WHITE)
		for k in 4:
			if i + k > to:
				break
			var img := Image.load_from_file(dir + "/%04d.jpg" % (i + k))
			img.resize(w, h, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((k % 2) * w, (k / 2) * h))
		sheet.save_jpg(dir + "/../sheet_%04d.jpg" % i, 0.85)
		i += 4
		s += 1
	print("sheets: ", s)
	quit()
