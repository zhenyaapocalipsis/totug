extends SceneTree

## Lays out every tile at every rotation for the schematic board and writes
## data/board/schematic_tiles.json (see BoardSchematic.layout_tile). Re-run after
## changing tile data or the layout rules in core/map/board_schematic.gd.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path engine/godot --script res://tools/build_schematic_tiles.gd
## Optional: --tiles=C1,A4 to rebuild only some tiles (others are kept).


func _init() -> void:
	var only: Array[String] = []
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--tiles="):
			only.assign(arg.trim_prefix("--tiles=").split(","))
	var builder := BoardData.make_builder()
	var data := BoardData.load_all()
	var names := {}
	for tile: String in (data["sites"] as Dictionary).keys():
		names[tile] = true
	for tile: String in (data["routes"] as Dictionary).keys():
		names[tile] = true
	var ids: Array = names.keys()
	ids.sort()

	var table := {}
	var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(BoardSchematic.TILES_PATH))
	if typeof(old) == TYPE_DICTIONARY and not only.is_empty():
		table = old
	table["K"] = BoardSchematic.K
	var tiles: Dictionary = table.get("tiles", {})
	for tile: String in ids:
		if not only.is_empty() and not only.has(tile):
			continue
		var started := Time.get_ticks_msec()
		var per_rotation := {}
		for step in 6:
			per_rotation[str(step * 60)] = BoardSchematic.layout_tile(builder, tile, step * 60)
		tiles[tile] = per_rotation
		print("%s  %d ms" % [tile, Time.get_ticks_msec() - started])
	table["tiles"] = tiles
	var file := FileAccess.open(BoardSchematic.TILES_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(table))
	file.close()
	quit()
