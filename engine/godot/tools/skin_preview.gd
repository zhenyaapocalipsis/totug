extends SceneTree

## Снимок образов карт (SkinCollection, шейдер card_skin.gdshader): одна карта
## во всех ступенях — мелкое и полное лицо (окно игры само рисует x2). Запуск (с окном):
##   Godot --path . --script res://tools/skin_preview.gd -- --card=48314 --out=C:/path/skins.png
## Снимок — на CAPTURE_FRAME кадре: к нему шейдер точно собран и нарисован.

const CAPTURE_FRAME := 20
const TIERS := ["", "epic", "legendary", "ultra"]

var _frame := 0
var _out := "res://skin_preview.png"


func _initialize() -> void:
	var card := "48314"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--card="):
			card = arg.get_slice("=", 1)
		elif arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)

	var bg := ColorRect.new()
	bg.color = Color("0e0a16")
	bg.size = Vector2(960, 540)
	root.add_child(bg)
	for i in TIERS.size():
		var mini := CardView.new(card, 80, 76)
		mini.set_skin(TIERS[i])
		mini.position = Vector2(10 + i * 90, 4)
		mini.size = Vector2(80, 76)

		root.add_child(mini)
		var full := CardView.new(card, 176, 254)
		full.set_skin(TIERS[i])
		full.position = Vector2(10 + i * 186, 90)
		full.size = Vector2(176, 254)

		root.add_child(full)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == CAPTURE_FRAME:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		return true
	return false
