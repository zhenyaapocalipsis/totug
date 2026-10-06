extends SceneTree

## Полная доска со всеми 27 фонами (Stage 1: все тайлы). x2.
## Run: Godot..._console.exe --headless --path engine/godot --script res://tools/full_art_preview.gd

const OUT := "C:/tyrants of the underdark godot/Claude outputs/"
const RUNS := [[4, 3], [4, 11], [2, 7], [3, 5]]


func _init() -> void:
	for run: Array in RUNS:
		var ids: Array[String] = []
		ids.assign(["red", "blue", "green", "purple"].slice(0, int(run[0])))
		var state := GameSetup.new_game(ids, int(run[1]))
		var schematic := BoardSchematic.build(state)
		var img := SchematicPainter.paint(schematic, true)
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		var path := OUT + "full_art_%dp_seed%d.png" % [run[0], run[1]]
		img.save_png(path)
		print(path, "  ", img.get_size())
	quit()
