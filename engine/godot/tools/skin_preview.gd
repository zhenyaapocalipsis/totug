extends SceneTree

## Снимок образов карт (SkinCollection, шейдер card_skin.gdshader): одна карта
## во всех ступенях — мелкое и полное лицо (окно игры само рисует x2). Запуск (с окном):
##   Godot --path . --script res://tools/skin_preview.gd -- --card=48314 --out=C:/path/skins.png
## Снимок — на CAPTURE_FRAME кадре: к нему шейдер точно собран и нарисован.

const CAPTURE_FRAME := 20
const TIERS := ["", "faerie", "gilded", "prism"]

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
	# --screen=flip — карта, которую крутят (CardFlip): прямо, в повороте, лицом.
	if OS.get_cmdline_user_args().has("--screen=flip"):
		var angles := [0.0, 0.6, 1.2, 2.3, PI]
		for i in angles.size():
			var flip := CardFlip.new()
			flip.set_back(CardBack.CLASSIC)
			flip.set_face(card, "gilded")
			flip.position = Vector2(8 + i * 188, 100)
			flip.size = CardView.PIXEL_SIZE
			flip.angle = angles[i]
			flip._speed = 0.0
			flip._dragging = true
			root.add_child(flip)
		return
	# --screen=backs — все рубашки (CardBack.DESIGNS) 1:1, два ряда.
	if OS.get_cmdline_user_args().has("--screen=backs"):
		for i in CardBack.DESIGNS.size():
			var back := TextureRect.new()
			back.texture = CardBack.texture(CardBack.DESIGNS[i])
			back.position = Vector2(8 + (i % 5) * 188, 8 + (i / 5) * 266)
			root.add_child(back)
		return
	# --screen=collection — вкладка COLLECTION профиля на отдельном файле
	# профиля (настоящий не трогается): пара лутбоксов, пыль и открытые образы.
	if OS.get_cmdline_user_args().has("--screen=collection"):
		PlayerProfile.path_override = "user://profile_skin_shot.cfg"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProfile.path_override))
		PlayerProfile.save_local({"name": "Shot"})
		SkinCollection.grant({"boxes": 2, "dust": 450})
		var cfg := ConfigFile.new()
		cfg.load(PlayerProfile.path())
		cfg.set_value("collection", "owned", ["shader:faerie", "shader:gilded"])
		cfg.set_value("collection", "shader", "gilded")
		cfg.save(PlayerProfile.path())
		var screen := ProfileScreen.new()
		screen._page = "COLLECTION"
		root.add_child(screen)
		# --section=CARD BACKS / BACKGROUNDS — другой раздел коллекции.
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--section="):
				screen._collection.show_section(arg.get_slice("=", 1))
		return
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
