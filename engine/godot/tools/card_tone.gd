extends SceneTree

## Основной тон карты — для цвета выжигания карты в эффектах HS (рецепт hs_unity,
## "tint"): самый частый оттенок арта миниатюры среди заметно цветных пикселей (серое,
## тёмное и рамка не в счёт), вес — насыщенность × яркость.
##   Godot --headless --path . --script res://tools/card_tone.gd -- --cards=48426,48400
## Печатает: id, оттенок 0..1 (HSV), цвет пика в hex; --debug — вес каждого оттенка.
## Это подсказка, не закон: у Black Dragon самое цветное — багровые крылья, а владелец
## выбрал чёрный (насыщенность 0).

const BINS := 36


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return fallback


static func tone(img: Image) -> Color:
	var w := PackedFloat32Array()
	w.resize(BINS)
	var sum: Array[Color] = []
	sum.resize(BINS)
	for i in BINS:
		sum[i] = Color(0, 0, 0, 0)
	# окно арта миниатюры: без полосы имени сверху и края рамки
	var h := img.get_height()
	for y in range(int(h * 0.3), h - 2):
		for x in range(2, img.get_width() - 2):
			var c := img.get_pixel(x, y)
			if c.a < 0.5 or c.s < 0.2 or c.v < 0.15:
				continue
			var b := int(c.h * BINS) % BINS
			var k := c.s * c.v
			w[b] += k
			sum[b] += c * k
	if OS.get_cmdline_user_args().has("--debug"):
		for i in BINS:
			if w[i] > 0.5:
				print("  %.2f  %6.1f" % [float(i) / BINS, w[i]])
	var best := 0
	for i in BINS:
		# пик со сглаживанием по соседним корзинам
		if w[i] + 0.5 * (w[(i + 1) % BINS] + w[(i + BINS - 1) % BINS]) > w[best] + 0.5 * (w[(best + 1) % BINS] + w[(best + BINS - 1) % BINS]):
			best = i
	return sum[best] / w[best] if w[best] > 0.0 else Color.GRAY


func _initialize() -> void:
	for cid in _arg("cards", "48426").split(","):
		var tex := CardView.mini_texture(cid)
		if tex == null:
			print(cid, " no art")
			continue
		var c := tone(tex.get_image())
		print("%s %.3f #%s" % [cid, c.h, c.to_html(false)])
	quit()
