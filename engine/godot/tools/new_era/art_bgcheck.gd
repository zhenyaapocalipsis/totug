extends SceneTree

# Which arts have a real background: DIR=<folder>. Samples the image border; if
# most of it is white or transparent, the art is a cut-out figure ("CUT"),
# otherwise a scene ("BG"). Prints "BG|CUT <share of plain border> <file>".
func _init() -> void:
	var dir := OS.get_environment("DIR")
	var files := DirAccess.get_files_at(dir)
	for f in files:
		if not (f.ends_with(".png") or f.ends_with(".jpeg") or f.ends_with(".jpg")):
			continue
		var img := Image.load_from_file(dir + "/" + f)
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()
		var plain := 0
		var total := 0
		for i in range(40):
			var t := i / 39.0
			for p: Vector2i in [Vector2i(int(t * (w - 1)), 2), Vector2i(int(t * (w - 1)), h - 3),
					Vector2i(2, int(t * (h - 1))), Vector2i(w - 3, int(t * (h - 1)))]:
				var c := img.get_pixelv(p)
				total += 1
				if c.a < 0.5 or (c.r > 0.88 and c.g > 0.88 and c.b > 0.88):
					plain += 1
		var share := plain / float(total)
		print("%s %.2f %s" % ["CUT" if share > 0.5 else "BG", share, f])
	quit()
