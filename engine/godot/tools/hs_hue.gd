extends SceneTree

## Основной оттенок эффекта в кадре запекания — для тона выжигания «в цвет анимации»
## (рецепт tintHue). Считает яркие насыщенные пиксели по оттенку (шаг 0.02).
##   Godot --headless --path . --script res://tools/hs_hue.gd -- <кадр.png>
## Брать кадр, где эффект в силе (u### — если эффект под картой, f### — если поверх).


func _initialize() -> void:
	var img := Image.load_from_file(OS.get_cmdline_user_args()[0])
	var hs := {}
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.a < 0.3 or c.v < 0.25 or c.s < 0.3:
				continue
			var k := int(c.h * 50)
			hs[k] = hs.get(k, 0) + 1
	var ks := hs.keys()
	ks.sort_custom(func(a, b): return hs[a] > hs[b])
	for k in ks.slice(0, 5):
		print("hue %.2f  %d" % [k / 50.0, hs[k]])
	quit()
