extends SceneTree

## Разбор одной конкретной раскладки: что попало в каждую компоненту связности.
## godot --headless --path godot --script res://tests/diagnose_seed.gd -- --players=4 --seed=45 [--x-hexes]

func _initialize() -> void:
	var players := 4
	var s := 45
	var with_x := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players="): players = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="): s = int(arg.get_slice("=", 1))
		elif arg == "--x-hexes": with_x = true

	var data := BoardData.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = s * 7919 + players
	var sweep_script: GDScript = load("res://tests/sweep_layouts.gd")
	var sweep: Object = sweep_script.new()
	var hexes: Dictionary = sweep._pick(players, rng, with_x)
	var rot := RotationOptimizer.optimize(
		hexes, (data["layouts"] as Dictionary)[str(players)]["adjacency"],
		{}, data["edges"], rng)
	var g := BoardData.make_builder().build(players, hexes, rot)

	print("раскладка: %s" % str(hexes))
	var seen := {}
	var comps: Array = []
	for start: String in g.slots.keys():
		if seen.has(start): continue
		var members: Array[String] = []
		for slot_id in g.reachable_slots(start):
			seen[slot_id] = true
			members.append(slot_id)
		comps.append(members)
	comps.sort_custom(func(a, b): return a.size() > b.size())
	print("компонент: %d" % comps.size())
	for members: Array in comps:
		var names := {}
		var tiles := {}
		var routes := 0
		for slot_id: String in members:
			tiles[slot_id.split(":")[0]] = true
			var site := g.site_of_slot(slot_id)
			if site == "": routes += 1
			else: names[g.sites[site]["name"]] = true
		print("  слотов %3d  тайлы: %-28s локации: %s (маршрутных %d)"
			% [members.size(), ", ".join(tiles.keys()), ", ".join(names.keys()), routes])
	quit(0)
