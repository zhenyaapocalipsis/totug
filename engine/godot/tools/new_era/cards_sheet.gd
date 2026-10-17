extends SceneTree

# Sheet of finished cards (assets/cards_pixel/<id>.png, x2, 6 per row) for the owner
# to pick what to cut: IDS="49700 49701 ..." OUT=<file.png>. Order = by cost, then by id
# (owner, 2026-10-17: как во вкладке CARDS).
func _init() -> void:
	var root := "C:/tyrants of the underdark godot/"
	var ids: PackedStringArray = OS.get_environment("IDS").split(" ")
	var cost := {}
	for c in JSON.parse_string(FileAccess.get_file_as_string(root + "engine/godot/data/cards/cards.json")):
		var v = c.get("cost")
		cost[str(int(c["card_id"]))] = int(v) if v != null else 0
	var sorted := Array(ids)
	sorted.sort_custom(func(a, b):
		var ca := int(cost.get(a, 0))
		var cb := int(cost.get(b, 0))
		return ca < cb if ca != cb else String(a).to_int() < String(b).to_int())
	ids = PackedStringArray(sorted)
	var cols := 6
	var first := Image.load_from_file(root + "engine/godot/assets/cards_pixel/%s.png" % ids[0])
	var w := first.get_width() * 2
	var h := first.get_height() * 2
	var gap := 8
	var rows := int(ceil(ids.size() / float(cols)))
	var sheet := Image.create(cols * (w + gap) + gap, rows * (h + gap) + gap, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1a1024"))
	for i in ids.size():
		var img := Image.load_from_file(root + "engine/godot/assets/cards_pixel/%s.png" % ids[i])
		img.convert(Image.FORMAT_RGBA8)
		img.resize(w, h, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()),
			Vector2i(gap + (i % cols) * (w + gap), gap + (i / cols) * (h + gap)))
	sheet.save_png(OS.get_environment("OUT"))
	quit()
