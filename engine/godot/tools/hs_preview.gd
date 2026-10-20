extends SceneTree

## Превью розыгрыша с эффектом Hearthstone (HsPlay) без партии: кадры в заданные секунды
## на тёмном фоне с рамкой доски, лист кадров в res://<out>.png.
##   Godot --path . --script res://tools/hs_preview.gd -- --card=48426 --times=0.3,0.6,1.2 --out=hs_prev
## --only=узел,узел — рисовать только эти узлы (и их потомков); --bg=res://... — фон.

const BOARD := Rect2(160, 40, 640, 400)


func _initialize() -> void:
	_run.call_deferred()


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.get_slice("=", 1)
	return fallback


func _run() -> void:
	var port := SubViewport.new()
	port.size = Vector2i(960, 540)
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(port)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.12)
	bg.size = Vector2(960, 540)
	port.add_child(bg)
	var bg_path := _arg("bg", "")
	if bg_path != "" and FileAccess.file_exists(bg_path):
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(bg_path)))
		port.add_child(tr)
	var board := Control.new()
	board.position = BOARD.position
	board.size = BOARD.size
	port.add_child(board)
	var frame := ReferenceRect.new()
	frame.border_color = Color(0.4, 0.4, 0.5)
	frame.editor_only = false
	frame.position = BOARD.position
	frame.size = BOARD.size
	port.add_child(frame)
	var hs := HsPlay.new()
	hs.size = Vector2(960, 540)
	hs.board_area = board
	port.add_child(hs)
	HsPlay.debug_only = _arg("only", "")
	var cid := _arg("card", "48426")
	await process_frame
	await process_frame
	hs.play(cid, CardView.mini_texture(cid), true)
	# эффект берёт снимок экрана под себя — ждём его
	while not hs.is_ready():
		await process_frame
	hs.set_process(false)
	var times: Array[float] = []
	for s in _arg("times", "0.2,0.5,0.8,1.1,1.4,1.7,2.0,2.4,2.8").split(","):
		times.append(float(s))
	var shots: Array[Image] = []
	for t in times:
		hs.debug_seek(t)
		await process_frame
		await RenderingServer.frame_post_draw
		var img := port.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		shots.append(img)
	var cols := mini(3, shots.size())
	var sheet := Image.create_empty(960 * cols, 540 * ceili(float(shots.size()) / cols), false, Image.FORMAT_RGBA8)
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, 960, 540), Vector2i((i % cols) * 960, (i / cols) * 540))
	var out := _arg("out", "hs_prev")
	sheet.save_png(ProjectSettings.globalize_path("res://%s.png" % out))
	print("превью: %s.png, кадров %d" % [out, shots.size()])
	quit()
