extends SceneTree

## Лист кадров запечённого эффекта HS (PNG с premultiplied-альфой) поверх снимка экрана:
## так же, как их кладёт игра (смешивание One, OneMinusSrcAlpha в гамме).
##   Godot --headless --path . --script res://tools/bake_sheet.gd -- --dir=<папка кадров>
##     --frames=0,6,12 --bg=<снимок 960x540.png> --out=<лист.png> [--cols=3] [--scale=1]


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return fallback


func _initialize() -> void:
	var dir := _arg("dir", "")
	var bg := Image.load_from_file(_arg("bg", ""))
	bg.convert(Image.FORMAT_RGBA8)
	var scale := float(_arg("scale", "1"))
	var shots: Array[Image] = []
	# --card=ID --card-at=x,y --card-from=N [--mini-scale=1]: миниатюра между дорожками u (под картой) и f
	var mini: Image = null
	if _arg("card", "") != "":
		mini = CardView.mini_texture(_arg("card", "")).get_image()
		mini.convert(Image.FORMAT_RGBA8)
		var ms := int(_arg("mini-scale", "1"))
		mini.resize(mini.get_width() * ms, mini.get_height() * ms, Image.INTERPOLATE_NEAREST)
	var at := _arg("card-at", "422,163").split(",")
	for s in _arg("frames", "0").split(","):
		var f := Image.load_from_file(dir.path_join("f%03d.png" % int(s)))
		if f == null:
			continue
		var out := bg.duplicate() as Image
		out.resize(f.get_width(), f.get_height(), Image.INTERPOLATE_NEAREST)
		if FileAccess.file_exists(dir.path_join("u%03d.png" % int(s))):
			_over(out, Image.load_from_file(dir.path_join("u%03d.png" % int(s))))
		if mini != null and int(s) >= int(_arg("card-from", "43")):
			out.blend_rect(mini, Rect2i(Vector2i.ZERO, mini.get_size()), Vector2i(int(at[0]), int(at[1])))
		_over(out, f)
		if scale != 1.0:
			out.resize(int(out.get_width() * scale), int(out.get_height() * scale), Image.INTERPOLATE_NEAREST)
		shots.append(out)
	var cols := mini(int(_arg("cols", "3")), shots.size())
	var sw := shots[0].get_width()
	var sh := shots[0].get_height()
	var sheet := Image.create_empty(sw * cols, sh * ceili(float(shots.size()) / cols), false, Image.FORMAT_RGBA8)
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, sw, sh), Vector2i((i % cols) * sw, (i / cols) * sh))
	sheet.save_png(_arg("out", "sheet.png"))
	print("лист: ", _arg("out", "sheet.png"))
	quit()


## Кадр с premultiplied-альфой поверх out.
func _over(out: Image, f: Image) -> void:
	f.convert(Image.FORMAT_RGBA8)
	for y in f.get_height():
		for x in f.get_width():
			var c := f.get_pixel(x, y)
			if c.a == 0.0 and c.r + c.g + c.b == 0.0:
				continue
			var b := out.get_pixel(x, y)
			out.set_pixel(x, y, Color(minf(c.r + b.r * (1.0 - c.a), 1.0), minf(c.g + b.g * (1.0 - c.a), 1.0),
				minf(c.b + b.b * (1.0 - c.a), 1.0), 1.0))
