extends SceneTree

# Art windows (6,34,164,100) of generated cards FROM..TO, x3 with a 10 px grid.
func _init() -> void:
	var dir := "C:/tyrants of the underdark godot/engine/godot/assets/cards_pixel/"
	var from := int(OS.get_environment("FROM"))
	var to := int(OS.get_environment("TO"))
	var cols := 3
	var cw := 164 * 3 + 8
	var ch := 100 * 3 + 8
	var n := to - from + 1
	var sheet := Image.create(cw * cols, ch * int(ceil(n / float(cols))), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(1, 0, 1))
	for i in n:
		var img := Image.load_from_file(dir + "%d.png" % (from + i))
		img.convert(Image.FORMAT_RGBA8)
		var art := img.get_region(Rect2i(6, 34, 164, 100))
		art.resize(164 * 3, 300, Image.INTERPOLATE_NEAREST)
		for g in range(0, 165, 10):
			for y in 300:
				art.set_pixel(mini(g * 3, 164 * 3 - 1), y, Color.YELLOW if g % 50 == 0 else Color(0, 1, 1, 0.6))
		for g in range(0, 101, 10):
			for x in 164 * 3:
				art.set_pixel(x, mini(g * 3, 299), Color.YELLOW if g % 50 == 0 else Color(0, 1, 1, 0.6))
		sheet.blit_rect(art, Rect2i(0, 0, 164 * 3, 300), Vector2i((i % cols) * cw + 4, (i / cols) * ch + 4))
	sheet.save_jpg(OS.get_environment("OUT"), 0.9)
	quit()
