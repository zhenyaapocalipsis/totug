extends SceneTree

# Contact sheet of every image in DIR on a magenta backdrop (transparency shows).
func _init() -> void:
	var dir := OS.get_environment("DIR")
	var files: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png") or f.ends_with(".jpeg") or f.ends_with(".jpg"):
			files.append(f)
	files.sort()
	var cell := 240
	var cols := 6
	var rows := int(ceil(files.size() / float(cols)))
	var sheet := Image.create(cell * cols, cell * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(1, 0, 1))
	for i in files.size():
		var img := Image.load_from_file(dir + "/" + files[i])
		img.convert(Image.FORMAT_RGBA8)
		var s: float = float(cell - 8) / maxf(img.get_width(), img.get_height())
		img.resize(int(img.get_width() * s), int(img.get_height() * s), Image.INTERPOLATE_BILINEAR)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * cell + 4, (i / cols) * cell + 4))
		print(i, " ", files[i])
	sheet.save_jpg(OS.get_environment("OUT"), 0.85)
	quit()
