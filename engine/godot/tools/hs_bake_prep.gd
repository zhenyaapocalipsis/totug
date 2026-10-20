extends SceneTree

## Подготовка к запеканию эффекта HS в Unity (hs_unity, HsRender): «горящая копия»
## нашей мелкой карты для Choice_Reveal вместо GenFX_AbilityCard_Echo_BW (рамки карты HS).
##   Godot --headless --path . --script res://tools/hs_bake_prep.gd -- --card=48426
##     --frac=0.519,0.761 --out=<файл.png>
## frac — доля квада Quad_CardGlow, которую занимает карта (ширина, высота): по замеру
## квада в кадре (HsRender measure) и размеру миниатюры на экране.
## Светлые линии по макету мини-карты (рамка, окно арта, черта у цены, буквы имени и
## цена) с ореолом и серой серединой — как устроена текстура HS (RGBR: яркость = альфа).


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return fallback


func _initialize() -> void:
	var cid := _arg("card", "48426")
	var f := _arg("frac", "0.55,0.76").split(",")
	var img := echo_image(CardView.mini_texture(cid), Vector2(float(f[0]), float(f[1])))
	img.save_png(_arg("out", "echo.png"))
	print("echo: ", _arg("out", "echo.png"), " ", img.get_size())
	quit()


static func echo_image(face: Texture2D, frac: Vector2) -> Image:
	var w := int(CardView.MINI_SIZE.x)
	var h := int(CardView.MINI_SIZE.y)
	var lines := PackedFloat32Array()
	lines.resize(w * h)
	var mark := func(x: int, y: int) -> void:
		if x >= 0 and y >= 0 and x < w and y < h:
			lines[y * w + x] = 1.0
	for x in w:
		mark.call(x, 0)
		mark.call(x, h - 1)
	for y in h:
		mark.call(0, y)
		mark.call(w - 1, y)
	# окно арта (tools/pixel_cards.gd render_mini: обводка от y=27, ширина 54)
	for x in range(2, 56):
		mark.call(x, 27)
		mark.call(x, 82)
	for y in range(27, 83):
		mark.call(2, y)
		mark.call(55, y)
	# черта между именем и ценой
	for y in range(2, 18):
		mark.call(50, y)
	# буквы имени и цена — светлые пиксели шапки
	if face != null:
		var src := face.get_image()
		src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		if src.get_size() == Vector2i(w, h):
			for y in range(1, 27):
				for x in range(1, w - 1):
					if src.get_pixel(x, y).get_luminance() > 0.7:
						mark.call(x, y)
	# сетка вдвое мельче пикселя карты: линии, ореол (размытие) и серая середина
	var k := 2
	var pad := Vector2i(roundi(w * k * (1.0 / frac.x - 1.0) * 0.5), roundi(h * k * (1.0 / frac.y - 1.0) * 0.5))
	var gw := w * k + pad.x * 2
	var gh := h * k + pad.y * 2
	var base := PackedFloat32Array()
	base.resize(gw * gh)
	for y in h * k:
		for x in w * k:
			base[(y + pad.y) * gw + x + pad.x] = lines[(y / k) * w + x / k]
	var glow := _box_blur(_box_blur(base, gw, gh, 3), gw, gh, 3)
	var out := Image.create(gw, gh, false, Image.FORMAT_RGBA8)
	for y in gh:
		for x in gw:
			var i := y * gw + x
			var inside := x >= pad.x and y >= pad.y and x < pad.x + w * k and y < pad.y + h * k
			var v := maxf(base[i], minf(glow[i] * 1.6, 0.85))
			if inside:
				v = maxf(v, 0.32)
			out.set_pixel(x, y, Color(v, v, v, 1.0))
	out.resize(gw * 4, gh * 4, Image.INTERPOLATE_BILINEAR)
	return out


## Размытие окном (2r+1) по строкам и столбцам.
static func _box_blur(src: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	var n := float(2 * r + 1)
	for y in h:
		for x in w:
			var s := 0.0
			for d in range(-r, r + 1):
				s += src[y * w + clampi(x + d, 0, w - 1)]
			tmp[y * w + x] = s / n
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in h:
		for x in w:
			var s := 0.0
			for d in range(-r, r + 1):
				s += tmp[clampi(y + d, 0, h - 1) * w + x]
			out[y * w + x] = s / n
	return out
