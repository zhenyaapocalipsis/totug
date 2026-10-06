extends SceneTree

## Собирает данные всех кусков доски (сайты, кольца, трассы) на всех 6
## поворотах из precomputed tools/build_schematic_tiles.gd таблицы, для показа
## владельцу в HTML. Не меняет игровые данные, только читает.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path engine/godot
##      --script res://tools/export_tile_pieces.gd -- "C:/out.json"

const ROTATIONS := [0, 60, 120, 180, 240, 300]


func _init() -> void:
	var out_path := "C:/tyrants of the underdark godot/Claude outputs/tile_pieces.json"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_path = args[0]

	var builder := BoardData.make_builder()
	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(BoardSchematic.TILES_PATH))
	var tiles: Dictionary = table.get("tiles", {})
	var ids: Array = tiles.keys()
	ids.sort()

	var out := {}
	for tile_id: String in ids:
		var per_rot := {}
		for rot in ROTATIONS:
			var graph := builder.build(2, {"a": tile_id}, {"a": float(rot)}, false)
			var stored: Dictionary = (tiles[tile_id] as Dictionary).get(str(rot), {})
			var nodes: Dictionary = stored.get("nodes", {})
			var routes: Dictionary = stored.get("routes", {})

			var sites := {}
			for site_id: String in graph.sites.keys():
				var local: String = site_id.get_slice(":", 1)
				if not nodes.has(local):
					continue
				var site: Dictionary = graph.sites[site_id]
				var members := graph.slots_of_site(site_id)
				var box := BoardSchematic.site_box(String(site["name"]), members.size())
				var p: Array = nodes[local]
				var w := float(box["w"])
				var h := float(box["h"])
				var corner := Vector2(float(p[0]) - w / 2.0, float(p[1]) - h / 2.0)
				var slot_positions := []
				for s: Vector2 in box["slots"]:
					slot_positions.append([corner.x + s.x, corner.y + s.y])
				sites[local] = {
					"rect": [corner.x, corner.y, w, h],
					"name": site["name"], "vp": site["vp"],
					"starting": GameSetup.STARTING_SITE_NAMES.has(String(site["name"])),
					"slots": slot_positions,
				}

			var rings := {}
			for slot_id: String in graph.slots.keys():
				if not graph.is_route_slot(slot_id):
					continue
				var local2: String = slot_id.get_slice(":", 1)
				if nodes.has(local2):
					rings[local2] = nodes[local2]

			var traces: Array = []
			for key: String in routes.keys():
				traces.append(routes[key])

			per_rot[str(rot)] = {"sites": sites, "rings": rings, "traces": traces}
		out[tile_id] = per_rot
		print(tile_id, " done")

	var dir := out_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("saved ", out_path)
	quit()
