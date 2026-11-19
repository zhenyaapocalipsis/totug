extends SceneTree

const IDS := ["49803", "49804", "49808", "49813", "49816"]
const OUT := "C:/tyrants of the underdark godot/Codex outputs/"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for locale: String in ["en", "ru"]:
		preload("res://scenes/localization.gd").set_locale(locale)
		var sheet := Image.create(5 * 250, 278, false, Image.FORMAT_RGBA8)
		sheet.fill(PixelTheme.BG)
		for i in IDS.size():
			var cid: String = IDS[i]
			for small: bool in [false, true]:
				var texture := CardView.mini_texture(cid) if small else CardView.pixel_texture(cid)
				var image := texture.get_image()
				if image.is_compressed(): image.decompress()
				image.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(i * 250 + (184 if small else 4), 4))
		assert(sheet.save_png(OUT + "kara_ne62_" + locale + ".png") == OK)
	quit()
