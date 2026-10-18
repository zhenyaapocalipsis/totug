extends SceneTree

## Превью постановки уникальной карты (UniqueFx) без запуска партии: кадры собираются
## тем же шейдером обводки и тем же смешением света, что в витрине, на затемнённом
## снимке доски, и пишутся в GIF и лист кадров.
##   Godot --path . --script res://tools/fx_preview.gd -- --card=48426 --out=fx_red_dragon
## --sheet=0,5,10 — какие кадры положить в лист (увеличение x2); без него — каждый 4-й.
## Результат: res://<out>.gif и res://<out>_sheet.png (в корне проекта Godot).

const BG_SHOT := "res://fx_bg.png"
const CARD_POS := Vector2(402, 103)

var _port: SubViewport
var _bg: TextureRect
var _back: UniqueFx.Stage
var _card: TextureRect
var _front: UniqueFx.Stage
var _flash: ColorRect


func _initialize() -> void:
	_run.call_deferred()


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.get_slice("=", 1)
	return fallback


func _rect(parent: Node) -> TextureRect:
	var r := TextureRect.new()
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_KEEP
	parent.add_child(r)
	return r


func _run() -> void:
	var cid := _arg("card", "48426")
	var out := _arg("out", "fx_%s" % cid)
	_port = SubViewport.new()
	_port.size = Vector2i(960, 540)
	_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_port)
	_bg = _rect(_port)
	var bg := Image.load_from_file(ProjectSettings.globalize_path(BG_SHOT)) if FileAccess.file_exists(BG_SHOT) \
		else Image.create_empty(960, 540, false, Image.FORMAT_RGBA8)
	bg.convert(Image.FORMAT_RGBA8)
	var dim := Image.create_empty(bg.get_width(), bg.get_height(), false, Image.FORMAT_RGBA8)
	dim.fill(PixelTheme.DIM)
	bg.blend_rect(dim, Rect2i(Vector2i.ZERO, dim.get_size()), Vector2i.ZERO)
	_bg.texture = ImageTexture.create_from_image(bg)
	_back = UniqueFx.Stage.new("back")
	_port.add_child(_back)
	_card = _rect(_port)
	var face_path := "res://assets/cards_pixel/%s.png" % cid
	if ResourceLoader.exists(face_path):
		_card.texture = load(face_path)
	_flash = ColorRect.new()
	_flash.size = CardView.PIXEL_SIZE
	_port.add_child(_flash)
	_front = UniqueFx.Stage.new("front")
	_port.add_child(_front)

	var n := ceili(UniqueFx.hold_end(cid) * UniqueFx.FPS)
	var sheet_idx: Array[int] = []
	var sheet_arg := _arg("sheet", "")
	if sheet_arg != "":
		for s in sheet_arg.split(","):
			sheet_idx.append(int(s))
	else:
		for i in range(0, n, 4):
			sheet_idx.append(i)
	var crop := Rect2i(0, 0, 960, 540)
	crop = crop.intersection(Rect2i(0, 0, 960, 540))
	var gif := GifWriter.new(crop.size.x, crop.size.y)
	var shots: Array[Image] = []
	var t0 := Time.get_ticks_msec()
	var worst := 0
	for f in n:
		var raw := float(f) / UniqueFx.FPS
		var shift := UniqueFx.card_shift(cid, raw)
		var card := Rect2(CARD_POS + shift, CardView.PIXEL_SIZE)
		var tf := Time.get_ticks_usec()
		var L := UniqueFx.frame(cid, card, raw, Vector2(960, 540))
		_back.show_frame(L)
		_front.show_frame(L)
		worst = maxi(worst, Time.get_ticks_usec() - tf)
		_card.position = card.position
		_flash.position = card.position
		_flash.color = Color(1, 1, 1, UniqueFx.flash_alpha(cid, raw))
		await process_frame
		await RenderingServer.frame_post_draw
		var img := _port.get_texture().get_image()
		var part := img.get_region(crop)
		gif.add_frame(part, int(round(100.0 / UniqueFx.FPS)))
		if f in sheet_idx:
			shots.append(part)
	gif.save(ProjectSettings.globalize_path("res://%s.gif" % out))
	# лист кадров: в ряд по 3, увеличение x2
	var cols := 3
	var rows := ceili(float(shots.size()) / cols)
	var sheet := Image.create_empty(crop.size.x * cols, crop.size.y * rows, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var s := shots[i]
		s.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), Vector2i((i % cols) * crop.size.x, (i / cols) * crop.size.y))
	sheet.save_png(ProjectSettings.globalize_path("res://%s_sheet.png" % out))
	print("кадров %d, худший кадр %.1f мс, всего %.1f с -> %s.gif" % [n, worst / 1000.0,
		(Time.get_ticks_msec() - t0) / 1000.0, out])
	quit()
