extends SceneTree

## Диагностика сборки доски: где рвётся граф.
## godot --headless --path godot --script res://tests/diagnose_board.gd

func _initialize() -> void:
	var hex_by_slot := {
		"a": "A1",
		"c_n1": "C1", "c_n2": "C2", "c_n3": "C3",
		"c_s1": "C4", "c_s2": "C5", "c_s3": "C6",
		"b1": "B1", "b2": "B2",
	}
	var data := BoardData.load_all()
	var hex_edges: Dictionary = data["edges"]
	var layout: Dictionary = (data["layouts"] as Dictionary)["2"]
	var adjacency: Array = layout["adjacency"]
	var builder := BoardBuilder.new(data["sites"], data["routes"], hex_edges, data["layouts"])

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# --- сравнение: нулевые повороты против оптимизированных -------------
	var zero_rot := {}
	for k: String in hex_by_slot.keys():
		zero_rot[k] = 0.0

	# поворот B1 не фиксируется — см. RotationOptimizer и claude/progress.md
	var fixed := {}
	var opt_rot := RotationOptimizer.optimize(hex_by_slot, adjacency, fixed, hex_edges, rng)

	print("\n=== ДИАГНОСТИКА СБОРКИ ДОСКИ (2 игрока) ===\n")

	for label: String in ["нулевые повороты", "оптимизированные повороты"]:
		var rot: Dictionary = zero_rot if label.begins_with("нулевые") else opt_rot
		var graph := builder.build(2, hex_by_slot, rot)
		var links := RotationOptimizer.count_connections(hex_by_slot, adjacency, rot, hex_edges)
		var cross := 0
		for slot_id: String in graph.slots.keys():
			for nb in graph.adjacent_slots(slot_id):
				if slot_id.split(":")[0] != nb.split(":")[0]:
					cross += 1
		print("%s:" % label)
		print("   сомкнувшихся рёбер раскладки: %d из %d" % [links, adjacency.size()])
		print("   межгексовых связей в графе:   %d" % (cross / 2))
		print("   компонент связности:          %d" % graph.connected_component_count())
		print("   изолированных слотов:         %d\n" % graph.isolated_slots().size())

	# --- детальный разбор по рёбрам при оптимизированных поворотах -------
	print("--- рёбра раскладки при оптимизированных поворотах ---")
	for edge: Dictionary in adjacency:
		var a: String = edge["a"]
		var b: String = edge["b"]
		if not (hex_by_slot.has(a) and hex_by_slot.has(b)):
			continue
		var dir: String = edge["dir"]
		var back: String = BoardBuilder.OPPOSITE_DIR[dir]
		var a_open := builder.hex_has_connection_facing(hex_by_slot[a], dir, opt_rot[a])
		var b_open := builder.hex_has_connection_facing(hex_by_slot[b], back, opt_rot[b])
		print("  %-6s(%-2s @%3d) -%-2s-> %-6s(%-2s @%3d)   %s"
			% [a, hex_by_slot[a], int(opt_rot[a]), dir,
			   b, hex_by_slot[b], int(opt_rot[b]),
			   "сомкнуто" if (a_open and b_open) else ("тупик у " + (b if a_open else a))])

	# --- внутренняя связность каждого гекса ------------------------------
	var graph_opt := builder.build(2, hex_by_slot, opt_rot)
	print("\n--- внутренняя связность гексов ---")
	for layout_slot: String in hex_by_slot.keys():
		var prefix := layout_slot + ":"
		var own: Array[String] = []
		for slot_id: String in graph_opt.slots.keys():
			if slot_id.begins_with(prefix):
				own.append(slot_id)
		var seen := {}
		var comps := 0
		for start in own:
			if seen.has(start):
				continue
			comps += 1
			var queue: Array[String] = [start]
			seen[start] = true
			while not queue.is_empty():
				var cur: String = queue.pop_back()
				for nb in graph_opt.adjacent_slots(cur):
					if own.has(nb) and not seen.has(nb):
						seen[nb] = true
						queue.append(nb)
		print("  %-6s %-2s  слотов=%2d  компонент=%d" % [layout_slot, hex_by_slot[layout_slot], own.size(), comps])

	export_layout("res://data/board/board_layout.json", 2, hex_by_slot, opt_rot)

	quit(0)


## Выгружает раскладку, которую собрал движок, в JSON — чтобы инструмент
## отрисовки доски (tools/render_board.py) показывал ИМЕННО её, а не свою
## копию алгоритма. Две реализации одного алгоритма неизбежно расходятся:
## первая версия рендерера давала 13 состыковок там, где движок давал 12.
static func export_layout(path: String, player_count: int,
		hex_by_slot: Dictionary, rotations: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("не удалось записать " + path)
		return
	file.store_string(JSON.stringify({
		"player_count": player_count,
		"hex_by_slot": hex_by_slot,
		"rotations": rotations,
	}, "  "))
	file.close()
	print("раскладка выгружена: " + path)
