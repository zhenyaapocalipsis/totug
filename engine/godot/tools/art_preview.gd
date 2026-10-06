extends SceneTree

## Проверка Stage 0 фонового арта (SchematicPainter._paint_background):
## перебирает сиды, ищет партии, где среди гексов есть A1, и рисует схему с
## show_art=true — чтобы увидеть плитку под всеми её поворотами вживую.
## Run: Godot..._console.exe --headless --path engine/godot --script res://tools/art_preview.gd

const OUT := "C:/tyrants of the underdark godot/Claude outputs/"
const WANT := 4   # сколько разных поворотов A1 поймать
const MAX_SEED := 200


func _init() -> void:
	var found := {}   # rotation_key -> true
	for seed in range(1, MAX_SEED):
		if found.size() >= WANT:
			break
		var ids: Array[String] = ["red", "blue", "green", "purple"]
		var state := GameSetup.new_game(ids, seed)
		var hex_by_slot: Dictionary = state.layout.get("hex_by_slot", {})
		var slot := ""
		for s: String in hex_by_slot.keys():
			if String(hex_by_slot[s]) == "A1":
				slot = s
				break
		if slot == "":
			continue
		var rot: float = float((state.layout.get("rotations", {}) as Dictionary).get(slot, 0.0))
		var key := str(int(rot))
		if found.has(key):
			continue
		found[key] = true

		var schematic := BoardSchematic.build(state)
		var img := SchematicPainter.paint(schematic, true)
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		var path := OUT + "art_preview_seed%d_rot%s.png" % [seed, key]
		img.save_png(path)
		print("seed=%d rot=%s slot=%s -> %s" % [seed, key, slot, path])

	print("done, rotations found: ", found.keys())
	quit()
