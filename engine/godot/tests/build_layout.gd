extends SceneTree

## Сборка раскладки Demonweb на 2, 3 или 4 игроков по правилам мода
## (generateDemonwebMap*Player из main_lua_script.lua) и выгрузка её
## в data/board/board_layout.json для tools/render_board.py.
##
## godot --headless --path godot --script res://tests/build_layout.gd -- --players=4 --seed=7
##
## Состав раскладки:
##   центр      — случайный из A1..A9
##   кольцо C   — 6 случайных из C1..C6 (и X1..X4, если включены X-гексы)
##   b1         — всегда B1 (Menzoberranzan); закреплено только МЕСТО, поворот
##                подбирается как всем остальным (владелец игры подтвердил, что
##                якоря на 240 быть не должно — claude/progress.md, правило 4)
##   2 игрока   — плюс B2 в противоположном углу
##   3 игрока   — плюс B2, B3 в двух других углах
##   4 игрока   — все 6 углов (B2..B6 вперемешку) плюс C7 и C8 на двух лучах


func _initialize() -> void:
	var players := 2
	var seed_value := 12345
	var with_x := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players="):
			players = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.get_slice("=", 1))
		elif arg == "--x-hexes":
			with_x = true

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var data := BoardData.load_all()
	# Выбор гексов живёт в GameSetup: у игры и у этой диагностики должна быть
	# ОДНА реализация раскладки (claude/progress.md, ошибка 9 — алгоритм,
	# написанный дважды, разошёлся).
	var hex_by_slot := GameSetup.pick_hexes(players, rng, with_x)
	var layout: Dictionary = (data["layouts"] as Dictionary)[str(players)]
	var adjacency: Array = layout["adjacency"]
	var rotations := RotationOptimizer.optimize(
		hex_by_slot, adjacency, {}, data["edges"], rng)
	var graph := BoardData.make_builder().build(players, hex_by_slot, rotations)

	print("\n=== РАСКЛАДКА НА %d ИГРОКОВ (сид %d) ===\n" % [players, seed_value])
	var slot_names: Array = hex_by_slot.keys()
	slot_names.sort()
	for slot_name: String in slot_names:
		print("  %-9s %-2s  поворот %3d" % [slot_name, hex_by_slot[slot_name], int(rotations[slot_name])])

	var links := RotationOptimizer.count_connections(hex_by_slot, adjacency, rotations, data["edges"])
	print("\n  сомкнувшихся рёбер раскладки: %d из %d" % [links, adjacency.size()])
	print("  тайлов:      %d" % hex_by_slot.size())
	print("  локаций:     %d" % graph.site_count())
	print("  троп-слотов: %d" % graph.slot_count())

	# компоненты связности с расшифровкой: изолированные локации (те, которых
	# не касается ни один туннель) — законны, доска не обязана быть одним куском
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
	print("  компонент связности: %d" % components.size())
	for members: Array in components:
		var site_names := {}
		var routes := 0
		for slot_id: String in members:
			var site := graph.site_of_slot(slot_id)
			if site == "":
				routes += 1
			else:
				site_names[graph.sites[site]["name"]] = true
		print("     слотов %2d  локации: %-44s маршрутных: %d"
			% [members.size(), ", ".join(site_names.keys()), routes])

	_export_layout("res://data/board/board_layout.json", players, hex_by_slot, rotations)
	quit(0)


## Раскладку выгружает САМ движок — рендерер её читает, а не пересчитывает
## своей копией алгоритма (две реализации одного алгоритма разошлись однажды,
## см. claude/progress.md, ошибка 9).
static func _export_layout(path: String, player_count: int,
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
	print("\nраскладка выгружена: " + path)
