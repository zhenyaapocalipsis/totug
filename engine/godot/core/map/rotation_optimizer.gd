class_name RotationOptimizer
extends RefCounted

## Подбор поворотов гексов по правилу рулбука Demonweb:
## «каждый гекс поворачивается так, чтобы дать максимум соединений с другими гексами».
##
## Портировано с demonwebOptimizeRotations из Lua-скрипта мода TTS.
## Алгоритм жадный: на каждом шаге берётся слот, у которого больше всего уже
## решённых соседей (чтобы решать с максимумом информации), и ему выбирается
## поворот, дающий больше всего стыковок туннелей. Не глобальный оптимум,
## но быстрое и близкое приближение — раскладки маленькие (9-15 гексов).
##
## Разрешение спора из рулбука («если спор о соединениях — решает владелец,
## затем по часовой стрелке остальные») сведено к случайному выбору среди
## одинаково хороших поворотов: настоящий выбор игроками потребовал бы
## отдельного этапа хода и UI.
##
## Детерминированность: RNG передаётся снаружи. На сервере он сидится сидом
## партии, поэтому сборка доски воспроизводима и одинакова у всех клиентов.

const ROTATION_CHOICES: Array[float] = [0.0, 60.0, 120.0, 180.0, 240.0, 300.0]


## hex_by_slot:      имя слота раскладки -> id гекса
## adjacency:        [{a, b, dir}] из layouts.json
## fixed_rotations:  слоты с зафиксированным поворотом (B1 — якорь Menzoberranzan)
static func optimize(
	hex_by_slot: Dictionary,
	adjacency: Array,
	fixed_rotations: Dictionary,
	hex_edges: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	# соседи каждого слота с направлением от него к соседу
	var neighbours_of: Dictionary = {}
	for slot_name: String in hex_by_slot.keys():
		neighbours_of[slot_name] = []
	for edge: Dictionary in adjacency:
		var a: String = edge["a"]
		var b: String = edge["b"]
		if not (hex_by_slot.has(a) and hex_by_slot.has(b)):
			continue
		(neighbours_of[a] as Array).append({"other": b, "dir": edge["dir"]})
		(neighbours_of[b] as Array).append({
			"other": a, "dir": BoardBuilder.OPPOSITE_DIR[edge["dir"]]
		})

	var rotation_by_slot: Dictionary = {}
	var remaining: Array[String] = []
	for slot_name: String in hex_by_slot.keys():
		if fixed_rotations.has(slot_name):
			rotation_by_slot[slot_name] = float(fixed_rotations[slot_name])
		else:
			remaining.append(slot_name)

	while not remaining.is_empty():
		# слот с наибольшим числом уже решённых соседей
		var best_idx := 0
		var best_known := -1
		for i in remaining.size():
			var known := 0
			for nb: Dictionary in neighbours_of[remaining[i]]:
				if rotation_by_slot.has(nb["other"]):
					known += 1
			if known > best_known:
				best_known = known
				best_idx = i
		var slot_name: String = remaining[best_idx]
		var hex_id: String = hex_by_slot[slot_name]

		# поворот, дающий максимум стыковок с уже решёнными соседями
		var best_score := -1
		var best_rotations: Array[float] = []
		for rot in ROTATION_CHOICES:
			var score := 0
			for nb: Dictionary in neighbours_of[slot_name]:
				var other: String = nb["other"]
				if not rotation_by_slot.has(other):
					continue
				var dir: String = nb["dir"]
				var back_dir: String = BoardBuilder.OPPOSITE_DIR[dir]
				if _has_connection(hex_edges, hex_id, dir, rot) \
					and _has_connection(hex_edges, hex_by_slot[other], back_dir, rotation_by_slot[other]):
					score += 1
			if score > best_score:
				best_score = score
				best_rotations = [rot]
			elif score == best_score:
				best_rotations.append(rot)

		rotation_by_slot[slot_name] = best_rotations[rng.randi_range(0, best_rotations.size() - 1)]
		remaining.remove_at(best_idx)

	_polish(rotation_by_slot, hex_by_slot, neighbours_of, hex_edges, fixed_rotations, rng)
	return rotation_by_slot


## Во что обходится тайл, не сомкнувшийся ни с одним соседом.
##
## Жадный проход решает каждый тайл по очереди и назад не смотрит, поэтому
## тайл, которому дошла очередь последним, мог остаться вообще без связей —
## целый кусок карты (в найденном примере локация Shedaklah с семью троп-слотами)
## оказывался недостижим. Правило рулбука «поворачивай, чтобы дать максимум
## соединений» такого не подразумевает, поэтому оторванный тайл штрафуется
## сильнее, чем стоит одно потерянное ребро.
const ISOLATION_PENALTY := 4


## Доводка после жадного прохода: перебираем повороты каждого тайла заново, уже
## зная повороты всех остальных, и оставляем тот, что улучшает общую оценку.
## Повторяем, пока улучшения есть. Тайлы 15 штук, поворотов 6 — считается мгновенно.
static func _polish(
	rotation_by_slot: Dictionary,
	hex_by_slot: Dictionary,
	neighbours_of: Dictionary,
	hex_edges: Dictionary,
	fixed_rotations: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var order: Array[String] = []
	for slot_name: String in hex_by_slot.keys():
		if not fixed_rotations.has(slot_name):
			order.append(slot_name)

	for pass_index in 8:
		var improved := false
		for slot_name in order:
			var current: float = rotation_by_slot[slot_name]
			var best_score := _score(rotation_by_slot, hex_by_slot, neighbours_of, hex_edges)
			var best_rotations: Array[float] = [current]
			for rot in ROTATION_CHOICES:
				if is_equal_approx(rot, current):
					continue
				rotation_by_slot[slot_name] = rot
				var score := _score(rotation_by_slot, hex_by_slot, neighbours_of, hex_edges)
				if score > best_score:
					best_score = score
					best_rotations = [rot]
				elif score == best_score and not best_rotations.has(rot):
					best_rotations.append(rot)
			var chosen: float = best_rotations[rng.randi_range(0, best_rotations.size() - 1)]
			rotation_by_slot[slot_name] = chosen
			if not is_equal_approx(chosen, current):
				improved = true
		if not improved:
			return


## Оценка раскладки: сомкнувшиеся рёбра минус штраф за каждый оторванный тайл.
static func _score(
	rotation_by_slot: Dictionary,
	hex_by_slot: Dictionary,
	neighbours_of: Dictionary,
	hex_edges: Dictionary
) -> int:
	var joined := 0
	var lonely := 0
	for slot_name: String in hex_by_slot.keys():
		var own := 0
		for nb: Dictionary in neighbours_of[slot_name]:
			var other: String = nb["other"]
			var dir: String = nb["dir"]
			if _has_connection(hex_edges, hex_by_slot[slot_name], dir, rotation_by_slot[slot_name]) \
				and _has_connection(hex_edges, hex_by_slot[other], BoardBuilder.OPPOSITE_DIR[dir],
					rotation_by_slot[other]):
				own += 1
		joined += own
		if own == 0:
			lonely += 1
	# own считался с обеих сторон каждого ребра
	return joined / 2 - ISOLATION_PENALTY * lonely


static func _has_connection(hex_edges: Dictionary, hex_id: String, world_dir: String, rot: float) -> bool:
	if not hex_edges.has(hex_id):
		return false
	var open_edges: Array = hex_edges[hex_id]
	return open_edges.has(BoardBuilder.raw_edge_facing_world(world_dir, rot))


## Сколько рёбер раскладки реально сомкнулись туннелями при данных поворотах.
## Метрика качества сборки — используется в тестах и диагностике.
static func count_connections(
	hex_by_slot: Dictionary,
	adjacency: Array,
	rotation_by_slot: Dictionary,
	hex_edges: Dictionary
) -> int:
	var count := 0
	for edge: Dictionary in adjacency:
		var a: String = edge["a"]
		var b: String = edge["b"]
		if not (hex_by_slot.has(a) and hex_by_slot.has(b)):
			continue
		var dir: String = edge["dir"]
		var back_dir: String = BoardBuilder.OPPOSITE_DIR[dir]
		if _has_connection(hex_edges, hex_by_slot[a], dir, rotation_by_slot.get(a, 0.0)) \
			and _has_connection(hex_edges, hex_by_slot[b], back_dir, rotation_by_slot.get(b, 0.0)):
			count += 1
	return count
