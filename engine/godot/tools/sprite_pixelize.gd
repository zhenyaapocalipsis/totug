extends SceneTree

## Перевод покадровой анимации (рисованные PNG, например дракон Cethiel с OpenGameArt,
## CC0) в пиксель-арт для эффектов уникальных карт:
##   1) берётся каждый step-й кадр (60 к/с -> 20 к/с при step=3);
##   2) все кадры всех анимаций обрезаются одной общей рамкой (чтобы не прыгали);
##   3) уменьшение Lanczos до scale, альфа — жёстко по порогу (никакой полупрозрачности);
##   4) перекраска: яркость (растянутая по процентилям всех кадров) -> лесенка ramp;
##   5) чистка: пиксель, не похожий ни на одного из 4 соседей, берёт цвет соседей;
##   6) точка пасти на каждом кадре — самый дальний непрозрачный пиксель в сторону
##      морды (face: -1 влево) в верхней части силуэта.
## Результат: <out>.png (кадры сеткой, cols в ряд) и <out>.json (размер кадра, анимации, пасти).
##   Godot --headless --script res://tools/sprite_pixelize.gd -- --src=<папка с папками
##   анимаций> --anims="Idle Battle,Attack 2" --names=idle,attack --step=3 --scale=0.5
##   --ramp=0e0510,240a1a,... --out=res://assets/card_fx/48426/dragon

var _a := {}


func _initialize() -> void:
	for s in OS.get_cmdline_user_args():
		_a[s.get_slice("=", 0).trim_prefix("--")] = s.substr(s.find("=") + 1)
	var src: String = _a["src"]
	var anims: PackedStringArray = String(_a["anims"]).split(",")
	var names: PackedStringArray = String(_a.get("names", _a["anims"])).split(",")
	var step := int(_a.get("step", "3"))
	var scale := float(_a.get("scale", "0.5"))
	var face := int(_a.get("face", "-1"))
	var ramp: Array[Color] = []
	for h in String(_a["ramp"]).split(","):
		ramp.append(Color(h))
	# 1. кадры
	var frames: Array[Image] = []
	var meta := {}
	for ai in anims.size():
		var dir := src + "/" + anims[ai]
		var files := Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.ends_with(".png"))
		files.sort()
		var start := frames.size()
		for i in range(0, files.size(), step):
			var im := Image.load_from_file(dir + "/" + files[i])
			im.convert(Image.FORMAT_RGBA8)
			frames.append(im)
		meta[names[ai]] = [start, frames.size() - start]
	# 2. общая рамка по альфе
	var box := Rect2i()
	for im in frames:
		var u := im.get_used_rect()
		box = u if box.size == Vector2i.ZERO else box.merge(u)
	box = box.grow(2).intersection(Rect2i(Vector2i.ZERO, frames[0].get_size()))
	var fw := maxi(1, int(round(box.size.x * scale)))
	var fh := maxi(1, int(round(box.size.y * scale)))
	# 3. уменьшение и сбор яркостей для растяжки
	var small: Array[Image] = []
	var lums := PackedFloat32Array()
	for im in frames:
		var c := im.get_region(box)
		c.resize(fw, fh, Image.INTERPOLATE_LANCZOS)
		small.append(c)
		for y in range(0, fh, 2):
			for x in range(0, fw, 2):
				var p := c.get_pixel(x, y)
				if p.a > 0.5:
					lums.append(p.get_luminance())
	lums.sort()
	var lo := lums[int(lums.size() * 0.02)]
	var hi := lums[int(lums.size() * 0.995)]
	var gamma := float(_a.get("gamma", "0.85"))
	print("кадров %d, кадр %dx%d, яркость %.3f..%.3f" % [small.size(), fw, fh, lo, hi])
	# 4-5. перекраска и чистка
	# кадры сеткой по COLS в ряд (одна лента длиннее предела текстуры 16384)
	var cols := mini(int(_a.get("cols", "16")), small.size())
	var rows := ceili(float(small.size()) / cols)
	var sheet := Image.create_empty(fw * cols, fh * rows, false, Image.FORMAT_RGBA8)
	var mouths := []
	for fi in small.size():
		var c := small[fi]
		var idx := PackedInt32Array()
		idx.resize(fw * fh)
		for y in fh:
			for x in fw:
				var p := c.get_pixel(x, y)
				if p.a <= 0.5:
					idx[y * fw + x] = -1
					continue
				var l := pow(clampf((p.get_luminance() - lo) / (hi - lo), 0.0, 1.0), gamma)
				idx[y * fw + x] = clampi(int(l * ramp.size()), 0, ramp.size() - 1)
		var out := idx.duplicate()
		for y in range(1, fh - 1):
			for x in range(1, fw - 1):
				var b := idx[y * fw + x]
				var n := [idx[y * fw + x - 1], idx[y * fw + x + 1], idx[(y - 1) * fw + x], idx[(y + 1) * fw + x]]
				if b in n:
					continue
				var best: int = n[0]
				var cnt := 0
				for v: int in n:
					var k := n.count(v)
					if k > cnt:
						cnt = k
						best = v
				out[y * fw + x] = best
		for y in fh:
			for x in fw:
				var v := out[y * fw + x]
				if v >= 0:
					sheet.set_pixel((fi % cols) * fw + x, (fi / cols) * fh + y, ramp[v])
		# 6. пасть: в верхних 70% силуэта — крайний пиксель в сторону морды
		var top := fh
		var bottom := 0
		for y in fh:
			for x in fw:
				if out[y * fw + x] >= 0:
					top = mini(top, y)
					bottom = maxi(bottom, y)
					break
		var best_x := -1
		var best_y := 0
		for y in range(top, top + int((bottom - top) * 0.7)):
			for xi in fw:
				var x := xi if face < 0 else fw - 1 - xi
				if out[y * fw + x] >= 0:
					if best_x < 0 or (face < 0 and x < best_x) or (face > 0 and x > best_x):
						best_x = x
						best_y = y
					break
		mouths.append([best_x, best_y])
	var path: String = _a["out"]
	sheet.save_png(ProjectSettings.globalize_path(path + ".png"))
	var f := FileAccess.open(ProjectSettings.globalize_path(path + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"w": fw, "h": fh, "cols": cols, "fps": 60.0 / step, "anims": meta, "mouths": mouths}, "\t"))
	f.close()
	print("-> ", path, ".png")
	quit()
