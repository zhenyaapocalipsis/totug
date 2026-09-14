extends SceneTree

## Прогон многих случайных раскладок: не разваливается ли доска ни на одной
## комбинации тайлов и поворотов.
##
## Одной проверенной раскладки мало. Пока проверялась только одна фиксированная
## сборка на 2 игроков, движок выглядел исправным, а на случайных комбинациях
## целые тайлы оказывались оторванными от карты — жадный подбор поворотов решал
## тайлы по очереди и назад не смотрел. Отсюда доводочный проход в
## RotationOptimizer.
##
## godot --headless --path godot --script res://tests/sweep_layouts.gd [-- --anchor-b1]

func _initialize() -> void:
	var data := BoardData.load_all()
	var builder := BoardData.make_builder()
	# Поворот B1 не фиксируется: владелец игры подтвердил, что общее правило
	# поворота действует и на Menzoberranzan. Флаг --anchor-b1 возвращает
	# якорь мода (240°) — так проверялось, что разваливались именно из-за него.
	var FIXED := {"b1": 240.0} if "--anchor-b1" in OS.get_cmdline_user_args() else {}
	var bad := 0
	var runs := 0
	for players in [2, 3, 4]:
		var layout: Dictionary = (data["layouts"] as Dictionary)[str(players)]
		for s in range(1, 61):
			var rng := RandomNumberGenerator.new()
			rng.seed = s * 7919 + players
			var hexes := _pick(players, rng, s % 2 == 0)
			var rot := RotationOptimizer.optimize(
				hexes, layout["adjacency"], FIXED, data["edges"], rng)
			var g := builder.build(players, hexes, rot)
			runs += 1
			var suspect := _suspect_components(g)
			if not suspect.is_empty():
				bad += 1
				print("  ПРОБЛЕМА игроков=%d сид=%d  оторвано: %s  %s"
					% [players, s, ", ".join(suspect), str(hexes)])
	print("прогонов: %d, раскладок с оторванными локациями: %d" % [runs, bad])
	print("(одинокие кольца у края доски и локации без туннелей за дефект не считаются)")
	quit(1 if bad > 0 else 0)


## Компоненты, оторванные от карты НЕ по замыслу.
##
## Законная изоляция ровно одна: локация, которой не касается ни один туннель
## (The Barrens на X1, Indifference на X2). Такая компонента состоит из слотов
## одной локации и не содержит ни одного маршрутного слота — попасть туда можно
## только шпионом. Всё остальное — дефект сборки.
func _suspect_components(g: MapGraph) -> Array[String]:
	var seen := {}
	var components: Array = []
	for start: String in g.slots.keys():
		if seen.has(start):
			continue
		var members: Array[String] = []
		for slot_id in g.reachable_slots(start):
			seen[slot_id] = true
			members.append(slot_id)
		components.append(members)
	components.sort_custom(func(a, b): return a.size() > b.size())

	var suspect: Array[String] = []
	for i in range(1, components.size()):
		var members: Array = components[i]
		var sites := {}
		var routes := 0
		for slot_id: String in members:
			var site := g.site_of_slot(slot_id)
			if site == "":
				routes += 1
			else:
				sites[g.sites[site]["name"]] = true
		if routes == 0 and sites.size() == 1:
			continue   # локация без туннелей — так и задумано
		if sites.is_empty() and members.size() == 1:
			continue   # одинокое кольцо: туннель уходит на ребро гекса, а соседа
			           # с той стороны нет или его туннель не совпал. На настоящей
			           # доске это тупик у края — место есть, войти в него неоткуда.
		suspect.append("%s (слотов %d, маршрутных %d)" % [", ".join(sites.keys()), members.size(), routes])
	return suspect


func _pick(players: int, rng: RandomNumberGenerator, with_x: bool) -> Dictionary:
	var centre := ["A1","A2","A3","A4","A5","A6","A7","A8","A9"]
	var ring := ["C1","C2","C3","C4","C5","C6"]
	if with_x:
		ring.append_array(["X1","X2","X3","X4"])
	_shuffle(ring, rng)
	var r := {"a": centre[rng.randi_range(0, 8)], "b1": "B1",
		"c_n1": ring[0], "c_n2": ring[1], "c_n3": ring[2],
		"c_s1": ring[3], "c_s2": ring[4], "c_s3": ring[5]}
	if players == 2:
		r["b2"] = "B2"
	elif players == 3:
		r["b2"] = "B2"; r["b3"] = "B3"
	else:
		var b := ["B2","B3","B4","B5","B6"]
		_shuffle(b, rng)
		var corners := ["corner0","corner60","corner180","corner240","corner300"]
		for i in corners.size():
			r[corners[i]] = b[i]
		var extra := ["C7","C8"]
		if rng.randi_range(0, 1) == 1:
			extra.reverse()
		r["c7"] = extra[0]; r["c8"] = extra[1]
	return r


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = list[i]; list[i] = list[j]; list[j] = t
