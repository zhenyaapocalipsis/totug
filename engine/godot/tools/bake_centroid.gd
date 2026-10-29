extends SceneTree

## Где в запечённых кадрах огонь: центр яркости и строка с самой большой яркостью по
## кадрам from..to (каждый 4-й). По нему ставят якорь эффекта действия на цель (HsPlay
## SCRIPTS actions anchor) — точка префаба HS часто не там, где виден огонь.
##   Godot --headless --path . --script res://tools/bake_centroid.gd -- <папка кадров> <from> <to>


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var dir := ProjectSettings.globalize_path(a[0])
	var from := int(a[1])
	var to := int(a[2])
	var sx := 0.0
	var sy := 0.0
	var sw := 0.0
	var rows := PackedFloat32Array()
	rows.resize(540)
	for i in range(from, to, 4):
		var img := Image.load_from_file(dir.path_join("f%03d.png" % i))
		img.convert(Image.FORMAT_RGBA8)
		# кадр 480x270 (HsFx-82) или старый 960x540: координаты — экрана 960x540
		var k := 960 / img.get_width()
		var st := maxi(1, 2 / k)
		for y in range(0, img.get_height(), st):
			for x in range(0, img.get_width(), st):
				var c := img.get_pixel(x, y)
				var w := c.a * (c.r + c.g)
				sx += x * k * w
				sy += y * k * w
				sw += w
				rows[y * k] += w
	var best := 0
	for y in 540:
		if rows[y] > rows[best]:
			best = y
	print("centroid (%.0f, %.0f), peak row %d" % [sx / sw, sy / sw, best])
	quit()
