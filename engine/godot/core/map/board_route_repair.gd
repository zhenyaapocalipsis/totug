extends RefCounted

const Quality = preload("res://core/map/board_quality.gd")
const STEPS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

## Last pass on the exported pixels: reroute edges and, when necessary, move
## drawing nodes. Their IDs, troop slots and game graph remain unchanged.
static func repair(s: Dictionary) -> Dictionary:
	var result := s.duplicate(true)
	for _round in 8:
		var quality := Quality.inspect(result)
		if quality["overlaps"] > 0:
			var separated := _separate_nodes(result, quality)
			if not separated.is_empty():
				result = separated
				continue
		if quality["bad_traces"].is_empty():
			break
		var before := _score(quality)
		var improved := false
		for edge: int in quality["bad_traces"]:
			var path := _route(result, edge)
			if path.is_empty():
				continue
			var old: Array = result["traces"][edge]
			result["traces"][edge] = path
			if _score(Quality.inspect(result)) < before:
				improved = true
				break
			result["traces"][edge] = old
		if not improved:
			# Two crossing edges can trap each other. Rip up the faulty group
			# together, trying both orders, before deciding it cannot fit.
			var attached := {}
			for edge: int in quality["bad_traces"]:
				for id: String in result["trace_ends"][edge]:
					attached[id] = true
			var group: Array = quality["bad_traces"].duplicate()
			for edge in result["trace_ends"].size():
				for id: String in result["trace_ends"][edge]:
					if attached.has(id) and not group.has(edge):
						group.append(edge)
			for reverse_order in [false, true]:
				var candidate := result.duplicate(true)
				var order: Array = group.duplicate()
				if reverse_order:
					order.reverse()
				var remaining := order.duplicate()
				var complete := true
				for edge: int in order:
					var path := _route(candidate, edge, remaining)
					if path.is_empty():
						complete = false
						break
					candidate["traces"][edge] = path
					remaining.erase(edge)
				if complete and _score(Quality.inspect(candidate)) < before:
					result = candidate
					improved = true
					break
			if not improved:
				var swapped := _swap_ring_order(result, quality)
				if not swapped.is_empty():
					result = swapped
					improved = true
				else:
					break
	return result


## Fixed ring order can force two paths to cross. Exchange two ring positions
## within the same hex and reroute every incident edge, preserving their IDs.
static func _swap_ring_order(s: Dictionary, quality: Dictionary) -> Dictionary:
	var rings := []
	for edge: int in quality["bad_traces"]:
		for id: String in s["trace_ends"][edge]:
			if s["rings"].has(id) and not rings.has(id):
				rings.append(id)
	for i in rings.size():
		for j in range(i + 1, rings.size()):
			var a: String = rings[i]
			var b: String = rings[j]
			if a.get_slice(":", 0) != b.get_slice(":", 0):
				continue
			for reverse_order in [false, true]:
				var candidate := s.duplicate(true)
				candidate["rings"][a] = s["rings"][b].duplicate()
				candidate["rings"][b] = s["rings"][a].duplicate()
				for id: String in [a, b]:
					var p: Array = candidate["rings"][id]
					if candidate.has("slots"):
						candidate["slots"][id] = {"x": p[0], "y": p[1]}
				var group := []
				for edge in candidate["trace_ends"].size():
					var ends: Array = candidate["trace_ends"][edge]
					for endpoint in 2:
						if ends[endpoint] != a and ends[endpoint] != b:
							continue
						var p: Array = candidate["rings"][ends[endpoint]]
						var flat: Array = candidate["traces"][edge]
						var at := 0 if endpoint == 0 else flat.size() - 2
						flat[at] = p[0]
						flat[at + 1] = p[1]
						if not group.has(edge):
							group.append(edge)
				if reverse_order:
					group.reverse()
				var remaining := group.duplicate()
				var complete := true
				for edge: int in group:
					var path := _route(candidate, edge, remaining)
					if path.is_empty():
						complete = false
						break
					candidate["traces"][edge] = path
					remaining.erase(edge)
				if complete and _score(Quality.inspect(candidate)) < _score(quality):
					return candidate
	return {}


static func _score(q: Dictionary) -> int:
	return int(q["crossings"]) * 10000 + int(q["overlaps"]) * 1000 + int(q["foreign_hits"])


static func _node_rect(s: Dictionary, id: String) -> Rect2:
	if s["sites"].has(id):
		var r: Array = s["sites"][id]["rect"]
		return Rect2(r[0], r[1], r[2], r[3])
	var p: Array = s["rings"][id]
	return Rect2(p[0] - 5, p[1] - 5, 11, 11)


static func _separate_nodes(s: Dictionary, quality: Dictionary) -> Dictionary:
	var all: Array = s["sites"].keys() + s["rings"].keys()
	var best := {}
	var best_score := _score(quality)
	for pair: Array in quality["overlap_nodes"]:
		for id: String in pair:
			var rect := _node_rect(s, id)
			for distance in range(2, 26, 2):
				for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
					var shift: Vector2 = direction * distance
					var moved := Rect2(rect.position + shift, rect.size)
					if not Rect2(0, 0, s["size"][0], s["size"][1]).encloses(moved):
						continue
					var free := true
					for other: String in all:
						if other != id and moved.grow(2).intersects(_node_rect(s, other)):
							free = false
					if not free:
						continue
					var candidate := s.duplicate(true)
					if candidate["sites"].has(id):
						var site: Dictionary = candidate["sites"][id]
						site["rect"][0] += shift.x
						site["rect"][1] += shift.y
						if site.has("icons_at"):
							site["icons_at"][0] += shift.x
							site["icons_at"][1] += shift.y
						for slot: String in site["slots"]:
							site["slots"][slot][0] += shift.x
							site["slots"][slot][1] += shift.y
							candidate["slots"][slot]["x"] += shift.x
							candidate["slots"][slot]["y"] += shift.y
					else:
						candidate["rings"][id][0] += shift.x
						candidate["rings"][id][1] += shift.y
						candidate["slots"][id]["x"] += shift.x
						candidate["slots"][id]["y"] += shift.y
					var group := []
					for edge in candidate["trace_ends"].size():
						for endpoint in 2:
							if candidate["trace_ends"][edge][endpoint] != id:
								continue
							var flat: Array = candidate["traces"][edge]
							var at := 0 if endpoint == 0 else flat.size() - 2
							flat[at] += shift.x
							flat[at + 1] += shift.y
							group.append(edge)
					var remaining := group.duplicate()
					var complete := true
					for edge: int in group:
						var path := _route(candidate, edge, remaining)
						if path.is_empty():
							complete = false
							break
						candidate["traces"][edge] = path
						remaining.erase(edge)
					if complete:
						var score := _score(Quality.inspect(candidate))
						if score < best_score:
							best_score = score
							best = candidate
							if score == 0:
								return candidate
	return best


static func _route(s: Dictionary, edge: int, ignore: Array = [], node_gap := 2, trace_gap := 1, max_pops := 500000) -> Array:
	var old: Array = s["traces"][edge]
	var a := Vector2(old[0], old[1])
	var b := Vector2(old[-2], old[-1])
	if not a.is_equal_approx(a.round()) or not b.is_equal_approx(b.round()):
		return []
	var size := Vector2i(int(s["size"][0]), int(s["size"][1]))
	var bounds := Rect2i(Vector2i.ZERO, size)
	var hard := PackedByteArray()
	var traces := PackedByteArray()
	hard.resize(size.x * size.y)
	traces.resize(hard.size())
	var ends: Array = s["trace_ends"][edge]
	var own: Array[Rect2] = []
	for id: String in s["sites"]:
		var r: Array = s["sites"][id]["rect"]
		var box := Rect2(r[0], r[1], r[2], r[3])
		if ends.has(id):
			own.append(box.grow(trace_gap))
		else:
			_mark(hard, size, box.grow(node_gap))
	for id: String in s["rings"]:
		var p: Array = s["rings"][id]
		var box := Rect2(p[0] - 5, p[1] - 5, 11, 11)
		if ends.has(id):
			own.append(box.grow(trace_gap))
		else:
			_mark(hard, size, box.grow(node_gap))
	for id: String in ends:
		if s["ports"].has(id):
			var p: Array = s["ports"][id]
			own.append(Rect2(p[0] - trace_gap, p[1] - trace_gap, trace_gap * 2, trace_gap * 2))
	for t in s["traces"].size():
		if t == edge or ignore.has(t):
			continue
		var f: Array = s["traces"][t]
		for k in range(0, f.size() - 2, 2):
			_mark(traces, size, Rect2(Vector2(f[k], f[k + 1]), Vector2.ZERO)
				.expand(Vector2(f[k + 2], f[k + 3])).grow(trace_gap))
	for rect in own:
		_mark(traces, size, rect, 0)
	var start := Vector2i(a)
	var goal := Vector2i(b)
	if not bounds.has_point(start) or not bounds.has_point(goal):
		return []
	var first_dir := _port_direction(s, edge, ends[0], true)
	var last_dir := _port_direction(s, edge, ends[1], false)
	var costs := PackedFloat32Array()
	var parent := PackedInt32Array()
	costs.resize(hard.size() * 4)
	parent.resize(costs.size())
	costs.fill(INF)
	parent.fill(-1)
	var heap: Array = []
	for d in 4:
		if first_dir >= 0 and d != first_dir:
			continue
		var state := (start.y * size.x + start.x) * 4 + d
		costs[state] = 0
		_push(heap, [0.0, state])
	var reached := -1
	var pops := 0
	while not heap.is_empty() and pops < max_pops:
		var item: Array = _pop(heap)
		var state: int = item[1]
		var d := state % 4
		var cell := state / 4
		var at := Vector2i(cell % size.x, cell / size.x)
		var h := absi(goal.x - at.x) + absi(goal.y - at.y)
		if float(item[0]) > costs[state] + h + 0.01:
			continue
		pops += 1
		if at == goal and (last_dir < 0 or d == last_dir):
			reached = state
			break
		for nd in 4:
			if (nd + 2) % 4 == d or (at == start and first_dir >= 0 and nd != first_dir):
				continue
			var next: Vector2i = at + STEPS[nd]
			if not bounds.has_point(next):
				continue
			var index: int = next.y * size.x + next.x
			if hard[index] != 0 or traces[index] != 0:
				continue
			var ns: int = index * 4 + nd
			var cost := costs[state] + 1.0 + (20.0 if d != nd else 0.0)
			if cost >= costs[ns]:
				continue
			costs[ns] = cost
			parent[ns] = state
			_push(heap, [cost + abs(goal.x - next.x) + abs(goal.y - next.y), ns])
	if reached < 0:
		return []
	var points: Array[Vector2i] = []
	while reached >= 0:
		var cell := reached / 4
		points.append(Vector2i(cell % size.x, cell / size.x))
		reached = parent[reached]
	points.reverse()
	var simple: Array[Vector2i] = []
	for p in points:
		if simple.size() >= 2 and (simple[-1] - simple[-2]) == (p - simple[-1]):
			simple[-1] = p
		elif simple.size() >= 2 and (Vector2(simple[-1] - simple[-2]).cross(Vector2(p - simple[-1]))) == 0.0:
			simple[-1] = p
		else:
			simple.append(p)
	var flat := []
	for p in simple:
		flat.append_array([p.x, p.y])
	return flat


static func _port_direction(s: Dictionary, edge: int, id: String, at_start: bool) -> int:
	if not s["ports"].has(id):
		return -1
	var neighbours := []
	for t in s["trace_ends"].size():
		if t != edge and (s["trace_ends"][t] as Array).has(id):
			neighbours.append(t)
	if neighbours.size() != 1:
		return -1
	var f: Array = s["traces"][neighbours[0]]
	var p := Vector2(f[0], f[1])
	var next := Vector2(f[2], f[3])
	if s["trace_ends"][neighbours[0]][1] == id:
		p = Vector2(f[-2], f[-1])
		next = Vector2(f[-4], f[-3])
	var direction := Vector2i((next - p).normalized()) * (-1 if at_start else 1)
	return STEPS.find(direction)


static func _mark(grid: PackedByteArray, size: Vector2i, rect: Rect2, value := 1) -> void:
	for y in range(maxi(0, ceili(rect.position.y)), mini(size.y, floori(rect.end.y) + 1)):
		for x in range(maxi(0, ceili(rect.position.x)), mini(size.x, floori(rect.end.x) + 1)):
			grid[y * size.x + x] = value


static func _push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if heap[p][0] <= item[0]:
			break
		heap[i] = heap[p]
		i = p
	heap[i] = item


static func _pop(heap: Array) -> Array:
	var first: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return first
	var i := 0
	while i * 2 + 1 < heap.size():
		var child := i * 2 + 1
		if child + 1 < heap.size() and heap[child + 1][0] < heap[child][0]:
			child += 1
		if heap[child][0] >= last[0]:
			break
		heap[i] = heap[child]
		i = child
	heap[i] = last
	return first
