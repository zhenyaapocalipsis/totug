extends SceneTree

## Свои замены текстур Hearthstone, нарисованных под макет HS (портрет героя — арка):
## у нас героя нет, поэтому в эффектах HsPlay они заменяются (HsPlay.OWN_TEXTURES).
##   Godot --path . --script res://tools/hs_own_textures.gd
## Пишет в res://assets/hs_fx/own/:
##   ring.png   вместо GenFX_HeroGlow_Soft_TransparentCenter — мягкое кольцо;
##   disc.png   вместо GenFX_HeroShadow_Internal — мягкий круг;
##   cracks.png вместо Cracks_HeroSocket_FriendlySide — те же трещины без арки гнезда.

const OUT := "res://assets/hs_fx/own/"
## Исходники HS — из выгрузки (Claude outputs/hs_fx, утилита hsx extract).
const SRC := "res://../../Claude outputs/hs_fx/CATA_190h_DeathwingWorldbreaker/24_CATAFX_Deathwing_CustomSummon_Spell/textures/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_radial(func(d: float) -> float: return 0.78 * exp(-pow((d - 0.62) / 0.17, 2.0))).save_png(_out("ring"))
	_radial(func(d: float) -> float: return 1.0 - smoothstep(0.5, 0.86, d)).save_png(_out("disc"))
	_cracks().save_png(_out("cracks"))
	print("готово: ", OUT)
	quit()


func _out(name: String) -> String:
	return ProjectSettings.globalize_path(OUT + name + ".png")


## Серая текстура по расстоянию от центра (d = 1 у края).
func _radial(f: Callable) -> Image:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			var v := clampf(float(f.call(d)), 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return img


## Трещины гнезда героя без самой арки и без пустого места героя: середина с аркой (у
## текстуры 512 — около (255, 275), полуширина арки 70, полувысота 80) отбрасывается, а
## остальное стягивается к центру (радиус r берётся из HOLE + r * (R - HOLE) / R) —
## трещины расходятся прямо из точки удара.
const HOLE := 112.0


func _cracks() -> Image:
	var src := Image.load_from_file(ProjectSettings.globalize_path(SRC + "Cracks_HeroSocket_FriendlySide.png"))
	src.convert(Image.FORMAT_RGBA8)
	var n := src.get_width()
	var k := n / 512.0
	var c := Vector2(255, 275) * k
	var big := 256.0 * k
	var hole := HOLE * k
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x, y) - c
			var r := d.length()
			var r0 := hole + r * (big - hole) / big
			var p := c + (d.normalized() * r0 if r > 0.0 else Vector2.ZERO)
			var v := 0.0
			if p.x >= 0.0 and p.y >= 0.0 and p.x < n - 1 and p.y < n - 1:
				v = src.get_pixelv(Vector2i(p)).r
			# у самого центра трещины сходятся в точку — гасим, чтобы не было пятна
			v *= smoothstep(2.0 * k, 14.0 * k, r)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return img
