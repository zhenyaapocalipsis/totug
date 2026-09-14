extends SceneTree

## Что именно оказалось в каждой компоненте связности собранной доски.
## Нужен, чтобы отличить законную изоляцию (локации, доступные только шпионом)
## от дефекта сборки.
## godot --headless --path godot --script res://tests/diagnose_components.gd

const HEXES := {
	"a": "A1",
	"c_n1": "C1", "c_n2": "C2", "c_n3": "C3",
	"c_s1": "C4", "c_s2": "C5", "c_s3": "C6",
	"b1": "B1", "b2": "B2",
}


func _initialize() -> void:
	var data := BoardData.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var rotations := RotationOptimizer.optimize(
		HEXES, (data["layouts"] as Dictionary)["2"]["adjacency"],
		{}, data["edges"], rng)
	var graph := BoardData.make_builder().build(2, HEXES, rotations)

	# через reachable_slots — он учитывает и прямые связи локаций, иначе
	# соединённые напрямую локации выглядят оторванными
	var seen := {}
	var components: Array = []
	for start: String in graph.slots.keys():
		if seen.has(start):
			continue
		var members: Array[String] = []
		for slot_id in graph.reachable_slots(start):
			seen[slot_id] = true
			members.append(slot_id)
		components.append(members)

	components.sort_custom(func(a, b): return a.size() > b.size())
	print("\n=== компоненты связности: %d ===\n" % components.size())
	for members: Array in components:
		var site_names := {}
		var routes := 0
		for slot_id: String in members:
			var site := graph.site_of_slot(slot_id)
			if site == "":
				routes += 1
			else:
				site_names[graph.sites[site]["name"]] = true
		print("  слотов %2d  локации: %-46s маршрутных слотов: %d"
			% [members.size(), ", ".join(site_names.keys()), routes])

	print("\n=== прямые связи локация-локация ===")
	for site_id: String in graph.sites.keys():
		var neighbours := graph.adjacent_sites(site_id)
		if not neighbours.is_empty():
			var names: Array[String] = []
			for other in neighbours:
				names.append(str(graph.sites[other]["name"]))
			print("  %-20s -> %s" % [graph.sites[site_id]["name"], ", ".join(names)])

	quit(0)
