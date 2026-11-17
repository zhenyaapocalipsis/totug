extends SceneTree

## Снимок образов карт (SkinCollection, шейдер card_skin.gdshader): одна карта
## со всеми образами — мелкое и полное лицо (окно игры само рисует x2). Запуск (с окном):
##   Godot --path . --script res://tools/skin_preview.gd -- --card=48314 --out=C:/path/skins.png
## --screen=foil — четыре фольги при двух фиксированных наклонах.
## --page=2 — вторая страница каталога или второй набор в режиме foil.
## Снимок — на CAPTURE_FRAME кадре: к нему шейдер точно собран и нарисован.

const CAPTURE_FRAME := 20
const COLUMNS := 4
const PAGE_SIZE := COLUMNS * 2
const PageText := preload("res://scenes/page_text.gd")

var _frame := 0
var _out := "res://skin_preview.png"


func _initialize() -> void:
	var card := "48314"
	var page := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--card="):
			card = arg.get_slice("=", 1)
		elif arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--page="):
			page = maxi(1, int(arg.get_slice("=", 1)))

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
		cfg.set_value("collection", "owned", ["shader:faerie", "shader:gilded", "alt:48403_1"])
		cfg.set_value("collection", "arts", {"48403": "48403_1"})
		cfg.set_value("collection", "shader", "gilded")
		cfg.save(PlayerProfile.path())
		var screen := ProfileScreen.new()
		screen._page = "COLLECTION"
		root.add_child(screen)
		screen._show_tab("COLLECTION")
		# --section=CARD BACKS / BACKGROUNDS — другой раздел коллекции.
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--section="):
				screen._collection.show_section(arg.get_slice("=", 1))
		# --card=ID — выбрать карту в CARDS (у 48403 два арта, один открыт).
		if OS.get_cmdline_user_args().has("--card=48403"):
			screen._collection.show_faction(CollectionPage.faction_of(card))
			screen._collection.select(card)
			screen._collection.select_art("48403_2")
		return
	var foil := OS.get_cmdline_user_args().has("--screen=foil")
	var skins: Array[String] = [""]
	skins.append_array(SkinCollection.SHADERS)
	var entries := COLUMNS if foil else PAGE_SIZE
	var first := (page - 1) * entries + (4 if foil else 0)
	skins = skins.slice(first, first + entries)
	if foil:
		skins = skins + skins
	for i in skins.size():
		var skin := skins[i]
		var at := Vector2(6 + (i % COLUMNS) * 238, 15 + (i / COLUMNS) * 266)
		var title := Label.new()
		title.theme = PixelTheme.theme()
		title.position = at - Vector2(0, 13)
		title.add_theme_color_override("font_color", Color(SkinCollection.SHADER_COLOURS.get(skin, "ffffff")))
		PageText.bind(title, String(SkinCollection.SHADER_TITLES.get(skin, "PLAIN")))
		root.add_child(title)

		var mini := CardView.new(card, int(CardView.MINI_SIZE.x), int(CardView.MINI_SIZE.y))
		mini.set_skin(skin)
		mini.position = at + Vector2(179, 0)
		mini.size = CardView.MINI_SIZE
		root.add_child(mini)

		var full := CardView.new(card, 176, 254)
		full.set_skin(skin)
		full.position = at
		full.size = Vector2(176, 254)
		root.add_child(full)
		if foil:
			var turn := -0.65 if i < COLUMNS else 0.65
			for view in [mini, full]:
				view.mouse_filter = Control.MOUSE_FILTER_IGNORE
				view.set_process(false)
				var mat := view.material as ShaderMaterial
				mat.set_shader_parameter("idle_amp", 0.0)
				mat.set_shader_parameter("foil_turn", turn)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == CAPTURE_FRAME:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		return true
	return false
