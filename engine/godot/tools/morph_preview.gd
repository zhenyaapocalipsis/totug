extends SceneTree

## Кадры превращения карты в альтернативный арт (CardShowcase, фаза morph):
##   Godot --path . --script res://tools/morph_preview.gd -- --out=C:/path/morph.png
## Верхний ряд — EPIC (Blackguard), нижний — LEGENDARY (Blue Dragon): оригинал,
## три момента распада, итог со вспышкой/обводкой.

var _frame := 0
var _out := "res://morph_preview.png"
var _show: CardShowcase
var _sheet: Image
var _row := 0
var _step := 0
const STEPS := [["morph", 0.0], ["morph", 0.3], ["morph", 0.6], ["hold", 0.05], ["hold", 0.35]]
const ROWS := [["48310", "48310_1"], ["48403", "48403_2"]]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
	var bg := ColorRect.new()
	bg.color = Color("0e0a16")
	bg.size = Vector2(960, 540)
	root.add_child(bg)
	_sheet = Image.create(STEPS.size() * 460, ROWS.size() * 580, false, Image.FORMAT_RGBA8)
	_start_row()


func _start_row() -> void:
	if _show != null:
		_show.queue_free()
	_show = CardShowcase.new()
	_show.size = Vector2(960, 540)
	root.add_child(_show)
	_show.show_card(ROWS[_row][0], "RED RECRUITS", Color.RED, null, Vector2(10, 10), false, "", ROWS[_row][1], true)
	_show.set_process(false)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame % 3 == 1:
		# выставить фазу и время
		var st: Array = STEPS[_step]
		_show._phase = st[0]
		_show._t = float(st[1]) * (_show._morph_time() if st[0] == "morph" else 1.0)
		_show._flash = CardShowcase.FLASH_TIME * 0.6 if st[0] == "hold" and float(st[1]) < 0.1 else 0.0
		_show._flash_tint = _show._tier_colour().lerp(Color.WHITE, 0.55)
		_show._dim = 1.0
		_show.queue_redraw()
	elif _frame % 3 == 0:
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var k := img.get_width() / 960
		_sheet.blit_rect(img, Rect2i(img.get_width() / 2 - 115 * k, img.get_height() / 2 - 145 * k, 230 * k, 290 * k), Vector2i(_step * 230 * k, _row * 290 * k))
		_step += 1
		if _step >= STEPS.size():
			_step = 0
			_row += 1
			if _row >= ROWS.size():
				_sheet.save_png(_out)
				print("saved ", _out)
				return true
			_start_row()
	return false
