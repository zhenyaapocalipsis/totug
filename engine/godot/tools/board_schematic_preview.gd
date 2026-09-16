extends SceneTree

## Renders the schematic board for a few game seeds into PNG files for review.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path engine/godot --script res://tools/board_schematic_preview.gd
## Output: Claude outputs/schematic_<players>p_seed<N>.png at x2.

const OUT := "C:/tyrants of the underdark godot/Claude outputs/"
const RUNS := [[2, 1], [2, 7], [2, 42], [4, 3], [4, 11]]


func _init() -> void:
	for run: Array in RUNS:
		var ids: Array[String] = []
		ids.assign(["red", "blue", "green", "purple"].slice(0, int(run[0])))
		var state := GameSetup.new_game(ids, int(run[1]))
		var started := Time.get_ticks_msec()
		var schematic := BoardSchematic.build(state)
		var took := Time.get_ticks_msec() - started
		var img := SchematicPainter.paint(schematic)
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		var path := OUT + "schematic_%dp_seed%d.png" % [run[0], run[1]]
		img.save_png(path)
		print("%s  %d ms  %s" % [path, took, state.layout["hex_by_slot"]])
	quit()
