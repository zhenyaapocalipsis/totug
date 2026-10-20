extends SceneTree

## Кадры запечённого эффекта (premultiplied PNG): пиксель с цветом, но с нулевой альфой
## (чисто аддитивный) получает альфу 1/255. Кадры в игре сжаты WebP с потерями: цвет
## шумит, альфа — без потерь, и игра не рисует пиксели с нулевой альфой (HsPlay,
## _FrameLayer) — так шум сжатия в пустых местах не прибавляется к экрану. 1/255 альфы
## затемняет фон незаметно.
##   Godot --headless --path . --script res://tools/bake_alpha_fix.gd -- --dir=res://assets/hs_fx/baked/<имя>
## (новые запекания HsRender пишут кадры уже так.)


func _initialize() -> void:
	var dir := "res://assets/hs_fx/baked/worldbreaker"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			dir = a.substr(6)
	var files := 0
	var fixed := 0
	for name in DirAccess.get_files_at(dir):
		if not name.ends_with(".png"):
			continue
		var path := ProjectSettings.globalize_path(dir.path_join(name))
		var img := Image.load_from_file(path)
		img.convert(Image.FORMAT_RGBA8)
		var data := img.get_data()
		var n := 0
		for i in range(0, data.size(), 4):
			if data[i + 3] == 0 and (data[i] > 0 or data[i + 1] > 0 or data[i + 2] > 0):
				data[i + 3] = 1
				n += 1
		files += 1
		if n > 0:
			fixed += n
			Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data).save_png(path)
	print("кадров %d, исправлено пикселей %d" % [files, fixed])
	quit()
