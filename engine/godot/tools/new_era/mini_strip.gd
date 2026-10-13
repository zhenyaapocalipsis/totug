extends SceneTree

# Mini cards (assets/cards_mini/<id>.png) of IDS ("49203 49205 ...") in one strip, x4 — to check mini faces.
func _init() -> void:
	var ids: Array = Array(OS.get_environment("IDS").split(" ")).map(func(s): return int(s))
	var sheet := Image.create(58 * 4 * ids.size(), 84 * 4, false, Image.FORMAT_RGBA8)
	for i in ids.size():
		var img := Image.load_from_file("C:/tyrants of the underdark godot/engine/godot/assets/cards_mini/%d.png" % ids[i])
		img.convert(Image.FORMAT_RGBA8)
		img.resize(58 * 4, 84 * 4, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(img, Rect2i(0, 0, 232, 336), Vector2i(i * 232, 0))
	sheet.save_png(OS.get_environment("OUT"))
	quit()
