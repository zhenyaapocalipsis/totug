extends SceneTree

## Кадры эффектов 960x540 -> 480x270 средним 2x2 (владелец 2026-10-29, HsFx-82): шейдер HsPlay
## рисует блоком 2x2 пикселя экрана, вид не меняется, кадры в игре в ~2.7 раза легче.
## Premultiplied: каналы усредняются как есть; пиксель чистого света (цвет есть, альфа
## округлилась до 0) получает альфу 1/255 — HsPlay не рисует пиксели с нулевой альфой.
##   Godot --headless --path . --script res://tools/bake_half.gd -- <папка> [<папка> ...]
## Кадры не 960x540 пропускаются — запускать повторно безопасно.


func _initialize() -> void:
	var n := 0
	for d in OS.get_cmdline_user_args():
		var dir := ProjectSettings.globalize_path(d)
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".png") or not (f.begins_with("u") or f.begins_with("f")):
				continue
			var path := dir.path_join(f)
			var img := Image.load_from_file(path)
			if img == null or img.get_width() != 960 or img.get_height() != 540:
				continue
			img.convert(Image.FORMAT_RGBA8)
			_half(img).save_png(path)
			n += 1
		print("%s: готово" % d.get_file())
	print("ужато кадров: ", n)
	quit()


func _half(img: Image) -> Image:
	var src := img.get_data()
	var out := PackedByteArray()
	out.resize(480 * 270 * 4)
	for j in 270:
		var r0 := j * 2 * 3840
		var r1 := r0 + 3840
		var o := j * 1920
		for i in 480:
			var k0 := r0 + i * 8
			var k1 := r1 + i * 8
			# пустой блок (частый случай) — пропуск
			if src[k0 + 3] == 0 and src[k0 + 7] == 0 and src[k1 + 3] == 0 and src[k1 + 7] == 0 \
					and src[k0] == 0 and src[k0 + 4] == 0 and src[k1] == 0 and src[k1 + 4] == 0 \
					and src[k0 + 1] == 0 and src[k0 + 5] == 0 and src[k1 + 1] == 0 and src[k1 + 5] == 0 \
					and src[k0 + 2] == 0 and src[k0 + 6] == 0 and src[k1 + 2] == 0 and src[k1 + 6] == 0:
				o += 4
				continue
			var r := (src[k0] + src[k0 + 4] + src[k1] + src[k1 + 4] + 2) >> 2
			var g := (src[k0 + 1] + src[k0 + 5] + src[k1 + 1] + src[k1 + 5] + 2) >> 2
			var b := (src[k0 + 2] + src[k0 + 6] + src[k1 + 2] + src[k1 + 6] + 2) >> 2
			var a := (src[k0 + 3] + src[k0 + 7] + src[k1 + 3] + src[k1 + 7] + 2) >> 2
			if a == 0 and (r | g | b) != 0:
				a = 1
			out[o] = r
			out[o + 1] = g
			out[o + 2] = b
			out[o + 3] = a
			o += 4
	return Image.create_from_data(480, 270, false, Image.FORMAT_RGBA8, out)
