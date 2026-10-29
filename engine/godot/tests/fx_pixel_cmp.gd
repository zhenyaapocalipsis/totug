extends SceneTree
## Проба размера кадров эффектов (владелец 2026-10-29): кадр HsPlay рисуется настоящим слоем
## HsPlay._FrameLayer (шейдер пиксель-арта) на видеокарте в трёх вариантах — 960x540 как сейчас,
## 480x270 выбором пикселя (2i+1, 2j+1), 480x270 средним 2x2 — поверх снимка доски.
##   Godot --path engine/godot --script res://tests/fx_pixel_cmp.gd -- <out.png> <фон.png> <папка@кадр@cx@cy> ...
## Строка на эффект: вырезка 320x180 вокруг (cx, cy) x2, три столбца; печатает отличия во всём экране.
const CW := 320
const CH := 180

func _initialize() -> void:
	_run()

func _load(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var im := Image.load_from_file(path)
	im.convert(Image.FORMAT_RGBA8)
	return im

func _pick(im: Image, ox := 1, oy := 1) -> Image:
	var src := im.get_data()
	var out := PackedByteArray()
	out.resize(480 * 270 * 4)
	for j in 270:
		var so := ((2 * j + oy) * 960 + ox) * 4
		var dst := j * 480 * 4
		for i in 480:
			for c in 4:
				out[dst + c] = src[so + c]
			so += 8
			dst += 4
	return Image.create_from_data(480, 270, false, Image.FORMAT_RGBA8, out)

func _box(im: Image) -> Image:
	var b := im.duplicate() as Image
	b.shrink_x2()
	return b

func _shot(vp: SubViewport, layers: Array, imgs: Array) -> Image:
	for i in layers.size():
		var im: Image = imgs[i]
		layers[i].visible = im != null
		if im != null:
			layers[i].show_frame(ImageTexture.create_from_image(im))
	for k in 4:
		await process_frame
	return vp.get_texture().get_image()

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var vp := SubViewport.new()
	vp.size = Vector2i(960, 540)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(_load(a[1]))
	vp.add_child(bg)
	var layers := []
	for i in 2:
		var l := HsPlay._FrameLayer.new()
		l.size = Vector2(960, 540)
		vp.add_child(l)
		layers.append(l)
	var rows := a.slice(2)
	var gap := 6
	var out := Image.create(CW * 2 * 3 + gap * 2, (CH * 2 + gap) * rows.size(), false, Image.FORMAT_RGBA8)
	out.fill(Color(0.85, 0.85, 0.85))
	for r in rows.size():
		var p: PackedStringArray = rows[r].split("@")
		var u := _load("%s/u%s.png" % [p[0], p[1]])
		var f := _load("%s/f%s.png" % [p[0], p[1]])
		var shots := []
		shots.append(await _shot(vp, layers, [u, f]))
		var best := 1
		var best_n := 1 << 30
		var picks := []
		for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var sh: Image = await _shot(vp, layers, [_pick(u, off.x, off.y) if u else null, _pick(f, off.x, off.y) if f else null])
			var nn := _diff(shots[0], sh)
			print("  смещение %s: отличается %d" % [off, nn])
			if nn < best_n:
				best_n = nn
				best = picks.size()
			picks.append(sh)
		shots.append(picks[best])
		shots.append(await _shot(vp, layers, [_box(u) if u else null, _box(f) if f else null]))
		var msg := "%s f%s:  лучший выбор отличается в %d пикселях, среднее — в %d (из 518400)" % [p[0].get_file(), p[1], best_n, _diff(shots[0], shots[2])]
		print(msg)
		var cx := int(p[2]) - CW / 2
		var cy := int(p[3]) - CH / 2
		for v in 3:
			var crop: Image = shots[v].get_region(Rect2i(cx, cy, CW, CH))
			crop.convert(Image.FORMAT_RGBA8)
			crop.resize(CW * 2, CH * 2, Image.INTERPOLATE_NEAREST)
			out.blit_rect(crop, Rect2i(0, 0, CW * 2, CH * 2), Vector2i(v * (CW * 2 + gap), r * (CH * 2 + gap)))
	out.save_png(a[0])
	quit()

func _diff(a: Image, b: Image) -> int:
	var da := a.get_data()
	var db := b.get_data()
	var px := a.get_width() * a.get_height()
	var ch := da.size() / px
	var n := 0
	for k in px:
		var o := k * ch
		if absi(da[o] - db[o]) > 2 or absi(da[o + 1] - db[o + 1]) > 2 or absi(da[o + 2] - db[o + 2]) > 2:
			n += 1
	return n
