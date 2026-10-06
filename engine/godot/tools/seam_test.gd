extends SceneTree

## Кладёт два фона тайлов рядом, программно затемняя края к общему цвету
## (виньетка), и проверяет на глаз, сливается ли стык. Не относится к
## игровому пайплайну, только проверка гипотезы.
## Run: Godot..._console.exe --headless --path engine/godot --script res://tools/seam_test.gd

const BORDER := Color("0a0918")
const MARGIN := 34.0


func _vignette(img: Image) -> Image:
	var out := img.duplicate() as Image
	var w := out.get_width()
	var h := out.get_height()
	for y in h:
		for x in w:
			var dist: float = minf(minf(x, w - 1 - x), minf(y, h - 1 - y))
			if dist >= MARGIN:
				continue
			var t: float = 1.0 - clampf(dist / MARGIN, 0.0, 1.0)
			var c := out.get_pixel(x, y)
			out.set_pixel(x, y, c.lerp(BORDER, t))
	return out


func _init() -> void:
	var a := _vignette(Image.load_from_file("C:/tyrants of the underdark godot/Claude outputs/tile_A1_great_web_v2.png"))
	var b := _vignette(Image.load_from_file("C:/tyrants of the underdark godot/Claude outputs/tile_A2_gallenghast.png"))
	a.save_png("C:/tyrants of the underdark godot/Claude outputs/tile_A1_great_web_v2_vig.png")
	b.save_png("C:/tyrants of the underdark godot/Claude outputs/tile_A2_gallenghast_vig.png")

	var out := Image.create(a.get_width() * 2, a.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(BORDER)
	out.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i(0, 0))
	out.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(a.get_width(), 0))
	out.save_png("C:/tyrants of the underdark godot/Claude outputs/seam_test.png")
	print("saved seam_test.png ", out.get_size())
	quit()
