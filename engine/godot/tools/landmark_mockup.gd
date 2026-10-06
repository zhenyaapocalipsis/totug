extends SceneTree

## Макет: достопримечательности вместо коробок городов (seed 3, 4 игрока).
const DIR := "C:/Users/JEKADI~1/AppData/Local/Temp/claude/C--tyrants-of-the-underdark-godot/2f4258b8-3262-4b88-b3fd-b37db5f04fc2/scratchpad/landmarks/"
const PICK := {
	"Fogtown": "small/2", "Gallenghast": "small/3", "Darkflame": "small/7", "Red Forest": "small/9",
	"Xal Veldrin": "small/13", "Iron Wastes": "small/15", "Araumycos": "small/19", "Black Gate": "small/22",
	"Zi'Xzolca": "small/24", "Ath-Qua": "small/27", "Red Gate": "small/30", "Kulggen": "small/34",
	"Iblith": "small/38", "Caer Sidi": "small/41", "The Twilight": "small/43", "Spiral Desert": "small/46",
	"Magma Gate": "small/49", "Vrith": "small/53", "Enzithir": "small/55", "Xelathir": "small/56",
	"Venathir": "small/58",
	"Menzoberranzan": "big/0", "Spiderhome": "big/1", "Thanatos Gate": "big/2", "Erelhei-Cinlu": "big/3",
	"Lolth Shrine": "big/14", "Council Chamber": "big/5", "Darklight Realm": "big/6", "Xith Idrana": "big/7",
	"Faerholme": "big/8", "Shedaklah": "big/9",
}
const SEATS := [Color("d04040"), Color("4070d8"), Color("40a050"), Color("9050c0")]
const PLATE := Color(0.06, 0.05, 0.09)
const RIM := Color("8a7aa8")
const GOLD := Color("e0a820")
const INK := Color("e6e0f0")
const PAD := 30

func _init() -> void:
	var sch := BoardSchematic.build(GameSetup.new_game(["red", "blue", "green", "purple"], 3))
	var size: Array = sch["size"]
	var w := int(size[0]) + 2 * PAD
	var h := int(size[1]) + 2 * PAD
	# как сейчас
	var now := _bg(w, h)
	now.blend_rect(SchematicPainter.paint(sch), Rect2i(0, 0, w - 2 * PAD, h - 2 * PAD), Vector2i(PAD, PAD))
	# с достопримечательностями: сначала трассы и кольца, потом здания, потом таблички
	var bare := sch.duplicate(true)
	bare["sites"] = {}
	var img := _bg(w, h)
	img.blend_rect(SchematicPainter.paint(bare), Rect2i(0, 0, w - 2 * PAD, h - 2 * PAD), Vector2i(PAD, PAD))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var sites: Dictionary = sch["sites"]
	var order: Array = sites.keys()
	order.sort_custom(func(a, b): return (sites[a]["rect"][1] + sites[a]["rect"][3]) < (sites[b]["rect"][1] + sites[b]["rect"][3]))
	for id: String in order:
		_landmark(img, sites[id], rng)
	_save(now, "mock_now.png", 2)
	_save(img, "mock_landmarks.png", 2)
	var zoom := Rect2i(130 + PAD, 140 + PAD, 270, 100)
	_save(now.get_region(zoom), "mock_zoom_now.png", 4)
	_save(img.get_region(zoom), "mock_zoom_landmarks.png", 4)
	quit()


func _bg(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(SchematicPainter.BG)
	return img


func _save(img: Image, name: String, scale: int) -> void:
	var out := img.duplicate() as Image
	out.resize(out.get_width() * scale, out.get_height() * scale, Image.INTERPOLATE_NEAREST)
	out.save_png(DIR + name)


func _landmark(img: Image, site: Dictionary, rng: RandomNumberGenerator) -> void:
	var r: Array = site["rect"]
	var rect := Rect2i(roundi(r[0]) + PAD, roundi(r[1]) + PAD, roundi(r[2]), roundi(r[3]))
	var name := String(site["name"])
	var slots := (site["slots"] as Dictionary).size()
	var marker := bool(site.get("marker", false))
	var art := Image.load_from_file(DIR + String(PICK.get(name, "small/36")) + ".png")
	art.convert(Image.FORMAT_RGBA8)
	var used := art.get_used_rect()
	art = art.get_region(used)
	# табличка внизу: гнёзда под войска + очки
	var cols := mini(slots, 6 if slots > 4 else 3)
	var rows := int(ceil(slots / float(cols)))
	var vp_w := PixelFont.ADVANCE + 4
	var plate_w := cols * BoardSchematic.SLOT_PITCH + 3 + vp_w
	var plate_h := rows * BoardSchematic.SLOT_PITCH + 3
	var centre := rect.get_center()
	# здание и табличка вместе встают по центру старой коробки
	var total_h := art.get_height() - 4 + plate_h
	var top := centre.y - total_h / 2
	var art_at := Vector2i(centre.x - art.get_width() / 2, top)
	img.blend_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), art_at)
	var plate := Rect2i(centre.x - plate_w / 2, top + art.get_height() - 4, plate_w, plate_h)
	img.fill_rect(plate.grow(1), Color(0, 0, 0))
	img.fill_rect(plate, GOLD if marker else RIM)
	img.fill_rect(plate.grow(-1), PLATE)
	for i in slots:
		var c := plate.position + Vector2i(2 + (i % cols) * BoardSchematic.SLOT_PITCH + BoardSchematic.SLOT_R,
			2 + (i / cols) * BoardSchematic.SLOT_PITCH + BoardSchematic.SLOT_R)
		if rng.randf() < 0.35:
			var t := SchematicPainter.token(SEATS[rng.randi() % 4])
			img.blend_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), c - Vector2i(BoardSchematic.SLOT_R, BoardSchematic.SLOT_R))
		else:
			SchematicPainter.disc(img, c, BoardSchematic.SLOT_R, Color("5a4e70"))
			SchematicPainter.disc(img, c, BoardSchematic.SLOT_R - 1, Color(0.02, 0.02, 0.03))
	var vp_x := plate.end.x - vp_w + 1
	var vp_y := plate.position.y + (plate_h - PixelFont.HEIGHT) / 2
	PixelFont.draw_text(img, vp_x, vp_y, str(site["vp"]), GOLD if marker else INK)
