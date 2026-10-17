extends SceneTree

# Sheet of finished cards (assets/cards_pixel/<id>.png, x2, 6 per row) for the owner
# to pick what to cut: IDS="49700 49701 ..." OUT=<file.png>. Order = order of IDS.
func _init() -> void:
	var root := "C:/tyrants of the underdark godot/"
	var ids: PackedStringArray = OS.get_environment("IDS").split(" ")
	var cols := 6
	var first := Image.load_from_file(root + "engine/godot/assets/cards_pixel/%s.png" % ids[0])
	var w := first.get_width() * 2
	var h := first.get_height() * 2
	var gap := 8
	var rows := int(ceil(ids.size() / float(cols)))
	var sheet := Image.create(cols * (w + gap) + gap, rows * (h + gap) + gap, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1a1024"))
	for i in ids.size():
		var img := Image.load_from_file(root + "engine/godot/assets/cards_pixel/%s.png" % ids[i])
		img.convert(Image.FORMAT_RGBA8)
		img.resize(w, h, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()),
			Vector2i(gap + (i % cols) * (w + gap), gap + (i / cols) * (h + gap)))
	sheet.save_png(OS.get_environment("OUT"))
	quit()
