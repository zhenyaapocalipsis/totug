extends SceneTree

## Кадры раскрытия лутбокса (LootBoxReveal):
##   Godot --path . --script res://tools/loot_preview.gd -- --out=C:/path/loot.png
## Лист 3x2: тряска, рулетка, вспышка, EPIC-арт, ULTRA-шейдер, итог пачки.

const SIZE := Vector2i(960, 540)
const ART := {"tier": "legendary", "shader": "", "art": "48403_2", "duplicate": false, "dust": 0}
const SHADER := {"tier": "ultra", "shader": "gilded", "art": "", "duplicate": false, "dust": 0}
const DUST := {"tier": "epic", "shader": "", "art": "", "duplicate": true, "dust": 50}
## [результаты, фаза, время фазы]
const FRAMES := [
	[[ART], "shake", 0.6], [[ART], "roll", 0.5], [[ART], "flash", 0.06],
	[[ART], "show", 0.6], [[SHADER], "show", 0.8], [[ART, SHADER, DUST, ART, DUST], "summary", 0.0],
]

var _frame := 0
var _step := 0
var _out := "res://loot_preview.png"
var _sheet: Image
var _reveal: LootBoxReveal


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
	_sheet = Image.create(SIZE.x * 3 / 2, SIZE.y * 2 / 2, false, Image.FORMAT_RGBA8)
	_build()


func _build() -> void:
	if _reveal != null:
		_reveal.queue_free()
	var f: Array = FRAMES[_step]
	var results: Array[Dictionary] = []
	for r in f[0]:
		results.append(r)
	_reveal = LootBoxReveal.new()
	root.add_child(_reveal)
	_reveal.set_process(false)
	_reveal.setup(results, 2, "48310")
	_reveal._dim = 1.0
	_reveal._enter(f[1])
	_reveal._t = float(f[2])
	_reveal._tick = _reveal._roll_tick(_reveal._t) if f[1] == "roll" else 0
	if f[1] == "show" or f[1] == "flash":
		_reveal._burst = float(f[2])
	_reveal._flash = LootBoxReveal.FLASH_TIME * 0.5 if f[1] == "flash" else 0.0
	_reveal._refresh()
	_reveal.queue_redraw()
	_reveal._layer.queue_redraw()


func _process(_delta: float) -> bool:
	_frame += 1
	if _reveal != null:
		_reveal.queue_redraw()
		_reveal._layer.queue_redraw()
	if _frame % 6 == 0:
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(SIZE.x / 2, SIZE.y / 2, Image.INTERPOLATE_NEAREST)
		_sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()),
			Vector2i((_step % 3) * SIZE.x / 2, (_step / 3) * SIZE.y / 2))
		_step += 1
		if _step >= FRAMES.size():
			_sheet.save_png(_out)
			print("saved ", _out)
			return true
		_build()
	return false
