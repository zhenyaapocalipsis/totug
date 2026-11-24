extends RefCounted

const Metrics = preload("res://core/map/board_metrics.gd")

const Quality = preload("res://core/map/board_quality.gd")
const STEPS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

## Last pass on the exported pixels: reroute edges and, when necessary, move
## drawing nodes. Their IDs, troop slots and game graph remain unchanged.
static func repair(s: Dictionary, allow_flatten := true) -> Dictionary:
	var result := _flatten_ports(s) if allow_flatten and (_buried_port(s) or (s.get("grid",false) and not s.get("grid_routed",true))) else s.duplicate(true)
	for _round in 24:
		var quality := Quality.inspect(result)
		if quality["overlaps"] > 0 or not quality.get("close_nodes",[]).is_empty():
			var contacts := quality.duplicate(true)
			contacts["overlap_nodes"].append_array(quality.get("close_nodes",[]))
			var separated := _separate_nodes(result, contacts)
			if not separated.is_empty():
				result = separated
				continue
		if quality["bad_traces"].is_empty():
			break
		var before := _score(quality)
		var improved := false
		for edge: int in quality["bad_traces"]:
			var path := _route(result,edge,[],2,1,50000,0,true)
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
			for id: String in _blocking_sites(result,quality): attached[id] = true
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
					var path := _route(candidate,edge,remaining,2,1,50000,0,true)
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
					var opened := _open_crossing(result,quality)
					if opened.is_empty(): break
					result = opened
	if allow_flatten and _score(Quality.inspect(result)) > 0:
		var flattened := _flatten_ports(result)
		if flattened["ports"].size() < result["ports"].size():
			flattened = repair(flattened,false)
			if _score(Quality.inspect(flattened)) < _score(Quality.inspect(result)): result = flattened
	return result


## A crossing can be trapped by valid but tightly packed endpoint positions.
## Open that corridor by moving an endpoint and its incident roads together.
static func _open_crossing(s: Dictionary, quality: Dictionary) -> Dictionary:
	if int(quality["crossings"]) == 0 and int(quality["foreign_hits"]) == 0: return {}
	var probe := quality.duplicate(true)
	probe["overlap_nodes"] = []
	var seen := {}
	for edge: int in quality["bad_traces"]:
		for id: String in s["trace_ends"][edge]:
			if (s["rings"].has(id) or s["sites"].has(id)) and not seen.has(id):
				probe["overlap_nodes"].append([id])
				seen[id] = true
	# Include the city obstructing a road, with all its incident roads.
	for id: String in _blocking_sites(s,quality):
		if not seen.has(id): probe["overlap_nodes"].append([id])
	return _separate_nodes(s,probe)


static func _blocking_sites(s: Dictionary, quality: Dictionary) -> Array:
	var blocked := {}
	for edge: int in quality["bad_traces"]:
		var path: Array = s["traces"][edge]
		for id: String in s["sites"]:
			if blocked.has(id) or s["trace_ends"][edge].has(id): continue
			var margin := _node_rect(s,id).grow(1)
			margin.position -= Vector2(0.5,0.5)
			for k in range(0,path.size()-2,2):
				var segment := Rect2(Vector2(path[k],path[k+1]),Vector2.ZERO).expand(Vector2(path[k+2],path[k+3])).grow(0.01)
				if segment.intersects(margin):
					blocked[id] = true
					break
	return blocked.keys()


static func _buried_port(s: Dictionary) -> bool:
	for edge in s["trace_ends"].size():
		for port: String in s["trace_ends"][edge]:
			if not s["ports"].has(port): continue
			var p: Array = s["ports"][port]
			for city: String in s["sites"]:
				if not s["trace_ends"][edge].has(city) and _node_rect(s,city).has_point(Vector2(p[0],p[1])): return true
	return false


## A drawing join has no game identity. When a compact layout is trapped,
## remove these artificial routing anchors and repair the actual node graph.
static func _flatten_ports(s: Dictionary) -> Dictionary:
	var result := s.duplicate(true)
	for port: String in result["ports"].keys():
		var edges := []
		for edge in result["trace_ends"].size():
			if result["trace_ends"][edge].has(port): edges.append(edge)
		if edges.size() != 2: continue
		var e: int = edges[0]
		var other: int = edges[1]
		var a: Array = result["trace_ends"][e]
		var b: Array = result["trace_ends"][other]
		var from: String = a[1] if a[0] == port else a[0]
		var to: String = b[1] if b[0] == port else b[0]
		if from == to: continue
		var left: Array = result["traces"][e].duplicate()
		var right: Array = result["traces"][other].duplicate()
		if a[0] == port: left = _reverse_path(left)
		if b[1] == port: right = _reverse_path(right)
		left.append_array(right.slice(2))
		result["traces"][e] = _simplify_path(left)
		result["trace_ends"][e] = [from,to]
		result["traces"].remove_at(other)
		result["trace_ends"].remove_at(other)
		result["ports"].erase(port)
	return result


static func _simplify_path(path: Array) -> Array:
	var result := []
	for k in range(0,path.size(),2):
		var point := Vector2(path[k],path[k+1])
		if result.size() >= 2 and point == Vector2(result[-2],result[-1]): continue
		while result.size() >= 4:
			var a := Vector2(result[-4],result[-3])
			var b := Vector2(result[-2],result[-1])
			if not is_zero_approx((b-a).cross(point-b)): break
			result.resize(result.size()-2)
		result.append_array([point.x,point.y])
	return result


static func _reverse_path(path: Array) -> Array:
	var result := []
	for k in range(path.size()-2,-1,-2): result.append_array([path[k],path[k+1]])
	return result


## Fixed ring order can force two paths to cross. Exchange two ring positions
## within the same hex and reroute every incident edge, preserving their IDs.
static func _swap_ring_order(s: Dictionary, quality: Dictionary) -> Dictionary:
	var rings := []
	for edge: int in quality["bad_traces"]:
		for id: String in s["trace_ends"][edge]:
			if s["rings"].has(id) and not rings.has(id):
				rings.append(id)
	var blocked := rings.duplicate()
	# A single trapped ring may need to exchange order with a neighbour
	# whose own road is currently valid.
	for id: String in s["rings"]:
		for endpoint: String in blocked:
			if id.get_slice(":",0) == endpoint.get_slice(":",0) and not rings.has(id): rings.append(id)
	for i in rings.size():
		for j in range(i + 1, rings.size()):
			if not blocked.has(rings[i]) and not blocked.has(rings[j]): continue
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
					var path := _route(candidate,edge,remaining,2,1,50000,0,true)
					if path.is_empty():
						complete = false
						break
					candidate["traces"][edge] = path
					remaining.erase(edge)
				if complete and _score(Quality.inspect(candidate)) < _score(quality):
					return candidate
	return {}


static func _score(q: Dictionary) -> int:
	return int(q["crossings"]) * 10000 + int(q["overlaps"]) * 1000 + int(q["foreign_hits"]) + q.get("close_nodes",[]).size()*100


static func _node_rect(s: Dictionary, id: String) -> Rect2:
	if s["sites"].has(id):
		var r: Array = s["sites"][id]["rect"]
		return Rect2(r[0], r[1], r[2], r[3])
	var p: Array = s["rings"][id]
	return Rect2(p[0] - Metrics.RADIUS, p[1] - Metrics.RADIUS, Metrics.DIAMETER, Metrics.DIAMETER)


static func _separate_nodes(s: Dictionary, quality: Dictionary) -> Dictionary:
	var all: Array = s["sites"].keys() + s["rings"].keys()
	var best := {}
	var best_score := _score(quality)
	var blockers := _blocking_sites(s,quality)
	for pair: Array in quality["overlap_nodes"]:
		for id: String in pair:
			if s.get("fixed_sites",[]).has(id): continue
			var rect := _node_rect(s, id)
			for distance in range(2, 66 if Metrics.DIAMETER >= 13 else 26, 2):
				for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP, Vector2(1,1), Vector2(-1,1), Vector2(1,-1), Vector2(-1,-1)]:
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
					if blockers.has(id): group.append_array(quality["bad_traces"])
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
						var path := _route(candidate, edge, remaining,2,1,50000,0,true)
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


static func _route(s: Dictionary, edge: int, ignore: Array = [], node_gap := 2, trace_gap := 1, max_pops := 500000, entry_gap := 0, quick := false, work_budget: Dictionary = {}) -> Array:
	if not work_budget.is_empty() and int(work_budget["left"]) <= 0: return []
	var old: Array = s["traces"][edge]
	var a := Vector2(old[0], old[1])
	var b := Vector2(old[-2], old[-1])
	if not a.is_equal_approx(a.round()) or not b.is_equal_approx(b.round()):
		return []
	var size := Vector2i(int(s["size"][0]), int(s["size"][1]))
	var bounds := Rect2i(Vector2i.ZERO, size)
	var hard_grid := Image.create(size.x,size.y,false,Image.FORMAT_L8)
	var trace_grid := Image.create(size.x,size.y,false,Image.FORMAT_L8)
	hard_grid.fill(Color.BLACK)
	trace_grid.fill(Color.BLACK)
	var entry_grid: Image = null
	var hidden_grid: Image = null
	if entry_gap > 0:
		entry_grid = Image.create(size.x,size.y,false,Image.FORMAT_L8)
		hidden_grid = Image.create(size.x,size.y,false,Image.FORMAT_L8)
		entry_grid.fill(Color.BLACK)
		hidden_grid.fill(Color.BLACK)
	var ends: Array = s["trace_ends"][edge]
	var own: Array[Rect2] = []
	for id: String in s["sites"]:
		var r: Array = s["sites"][id]["rect"]
		var box := Rect2(r[0], r[1], r[2], r[3])
		if ends.has(id):
			own.append(box.grow(trace_gap))
			if entry_gap > 0:
				_mark(hidden_grid,size,Rect2(box.position,box.size-Vector2.ONE))
				_mark(entry_grid,size,box.grow(entry_gap))
				_mark(entry_grid,size,Rect2(box.position,box.size-Vector2.ONE),0)
				for x in range(int(box.position.x)+3,int(box.end.x)-3,2):
					_mark(entry_grid,size,Rect2(x,box.position.y-entry_gap,0,box.size.y+entry_gap*2),0)
				for y in range(int(box.position.y)+3,int(box.end.y)-3,2):
					_mark(entry_grid,size,Rect2(box.position.x-entry_gap,y,box.size.x+entry_gap*2,0),0)
				var reference := b if id == ends[0] else a
				var pin_x := clampi(roundi(reference.x),int(box.position.x)+3,int(box.end.x)-4)
				var pin_y := clampi(roundi(reference.y),int(box.position.y)+3,int(box.end.y)-4)
				_mark(entry_grid,size,Rect2(pin_x,box.position.y-entry_gap,0,box.size.y+entry_gap*2),0)
				_mark(entry_grid,size,Rect2(box.position.x-entry_gap,pin_y,box.size.x+entry_gap*2,0),0)
		else:
			_mark(hard_grid, size, box.grow(node_gap))
	for id: String in s["rings"]:
		var p: Array = s["rings"][id]
		var box := Rect2(p[0] - Metrics.RADIUS, p[1] - Metrics.RADIUS, Metrics.DIAMETER, Metrics.DIAMETER)
		if ends.has(id):
			own.append(box.grow(trace_gap))
		else:
			_mark(hard_grid, size, box.grow(node_gap))
	for id: String in ends:
		if s["ports"].has(id):
			var p: Array = s["ports"][id]
			own.append(Rect2(p[0] - trace_gap, p[1] - trace_gap, trace_gap * 2, trace_gap * 2))
	for t in s["traces"].size():
		if t == edge or ignore.has(t):
			continue
		var f: Array = s["traces"][t]
		for k in range(0, f.size() - 2, 2):
			_mark(trace_grid, size, Rect2(Vector2(f[k], f[k + 1]), Vector2.ZERO)
				.expand(Vector2(f[k + 2], f[k + 3])).grow(trace_gap))
	for rect in own:
		_mark(trace_grid, size, rect, 0)
	var hard := hard_grid.get_data()
	var traces := trace_grid.get_data()
	var entries := entry_grid.get_data() if entry_gap > 0 else PackedByteArray()
	var hidden := hidden_grid.get_data() if entry_gap > 0 else PackedByteArray()
	var start := Vector2i(a)
	var goal := Vector2i(b)
	var goal_box := Rect2i()
	if entry_gap > 0 and s["sites"].has(ends[1]):
		var r: Array = s["sites"][ends[1]]["rect"]
		goal_box = Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))
	if not bounds.has_point(start) or not bounds.has_point(goal):
		return []
	var start_cell := start.y*size.x+start.x
	var goal_cell := goal.y*size.x+goal.x
	if entry_gap > 0 and (entries[start_cell] != 0 or entries[goal_cell] != 0):
		return []
	# A point goal inside an obstacle cannot be reached. Avoid exhausting
	# the search budget on rejected entry/marker proposals.
	if not goal_box.has_area() and (hard[goal_cell] != 0 or traces[goal_cell] != 0):
		return []
	var first_dir := _port_direction(s, edge, ends[0], true, ignore)
	var last_dir := _port_direction(s, edge, ends[1], false, ignore)
	var reach_start := start_cell
	var reach_goal := goal_cell
	var excluded := -1
	if first_dir >= 0:
		var first_step: Vector2i = start+STEPS[first_dir]
		if not bounds.has_point(first_step): return []
		reach_start = first_step.y*size.x+first_step.x
		if hard[reach_start] != 0 or traces[reach_start] != 0 or (entry_gap > 0 and entries[reach_start] != 0): return []
		excluded = start_cell
	if last_dir >= 0:
		var final_step: Vector2i = goal-STEPS[last_dir]
		if not bounds.has_point(final_step): return []
		reach_goal = final_step.y*size.x+final_step.x
		if reach_goal != start_cell and (hard[reach_goal] != 0 or traces[reach_goal] != 0 or (entry_gap > 0 and entries[reach_goal] != 0)): return []
	var direct := reach_start == goal_cell and (last_dir < 0 or last_dir == first_dir)
	var reach_checked := direct
	if max_pops > 20000 and not direct:
		if not _reachable(reach_start,reach_goal,hard,traces,size,excluded,entries,goal_box,work_budget): return []
		reach_checked = true
	# Cleanup seeks a valid improvement, not a globally optimal path.
	# Weighted A* avoids broad exploration of speculative long detours.
	var heuristic_weight := 1.5 if entry_gap > 0 or quick else 1.0
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
		if not work_budget.is_empty() and not _take_work(work_budget): return []
		var item: Array = _pop(heap)
		var state: int = item[1]
		var d := state % 4
		var cell := state / 4
		var at := Vector2i(cell % size.x, cell / size.x)
		var h := _goal_distance(at,goal,goal_box) if goal_box.has_area() else absi(goal.x-at.x)+absi(goal.y-at.y)
		if float(item[0]) > costs[state] + h * heuristic_weight + 0.01:
			continue
		pops += 1
		if not reach_checked and pops >= 1024:
			if not _reachable(reach_start,reach_goal,hard,traces,size,excluded,entries,goal_box,work_budget): return []
			reach_checked = true
		if at != start and (at == goal or (goal_box.has_area() and goal_box.has_point(at))) and (last_dir < 0 or d == last_dir):
			reached = state
			break
		for nd in 4:
			if (nd + 2) % 4 == d or (at == start and first_dir >= 0 and nd != first_dir):
				continue
			var next: Vector2i = at + STEPS[nd]
			if not bounds.has_point(next):
				continue
			var index: int = next.y * size.x + next.x
			if hard[index] != 0 or traces[index] != 0 or (entry_gap > 0 and entries[index] != 0):
				continue
			var ns: int = index * 4 + nd
			var cost := costs[state] + 1.0 + (20.0 if d != nd and (entry_gap == 0 or hidden[cell] == 0) else 0.0)
			if cost >= costs[ns]:
				continue
			costs[ns] = cost
			parent[ns] = state
			var remaining := _goal_distance(next,goal,goal_box) if goal_box.has_area() else absi(goal.x-next.x)+absi(goal.y-next.y)
			_push(heap, [cost + remaining * heuristic_weight, ns])
	if reached < 0:
		return []
	var points: Array[Vector2i] = []
	while reached >= 0:
		var cell := reached / 4
		points.append(Vector2i(cell % size.x, cell / size.x))
		reached = parent[reached]
	points.reverse()
	if entry_gap > 0 and s["sites"].has(ends[0]):
		var r: Array = s["sites"][ends[0]]["rect"]
		var box := Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))
		var exit_index := 0
		while exit_index < points.size() and box.has_point(points[exit_index]): exit_index += 1
		if exit_index > 1:
			var last := points[exit_index-1]
			var prefix: Array[Vector2i] = [points[0]]
			if points[0].x != last.x: prefix.append(Vector2i(last.x,points[0].y))
			if prefix[-1] != last: prefix.append(last)
			prefix.append_array(points.slice(exit_index))
			points = prefix
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


static func _port_direction(s: Dictionary, edge: int, id: String, at_start: bool, pending: Array = []) -> int:
	if not s["ports"].has(id):
		return -1
	var neighbours := []
	for t in s["trace_ends"].size():
		if t != edge and (s["trace_ends"][t] as Array).has(id):
			neighbours.append(t)
	if neighbours.size() != 1 or pending.has(neighbours[0]):
		return -1
	var f: Array = s["traces"][neighbours[0]]
	if f.size() < 4: return -1
	var p := Vector2(f[0], f[1])
	var next := Vector2(f[2], f[3])
	if s["trace_ends"][neighbours[0]][1] == id:
		p = Vector2(f[-2], f[-1])
		next = Vector2(f[-4], f[-3])
	var direction := Vector2i((next - p).normalized()) * (-1 if at_start else 1)
	return STEPS.find(direction)


## Rasterise in native code; doing every obstacle pixel in GDScript made
## repeated route proposals much slower than the path search itself.
static func _mark(grid: Image, size: Vector2i, rect: Rect2, value := 1) -> void:
	var left := maxi(0,ceili(rect.position.x))
	var top := maxi(0,ceili(rect.position.y))
	var right := mini(size.x,floori(rect.end.x)+1)
	var bottom := mini(size.y,floori(rect.end.y)+1)
	if right > left and bottom > top:
		grid.fill_rect(Rect2i(left,top,right-left,bottom-top),Color.WHITE if value != 0 else Color.BLACK)


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


static func _goal_distance(at: Vector2i, goal: Vector2i, box: Rect2i) -> int:
	if box.has_area():
		return maxi(0,maxi(box.position.x-at.x,at.x-box.end.x+1))+maxi(0,maxi(box.position.y-at.y,at.y-box.end.y+1))
	return absi(goal.x-at.x)+absi(goal.y-at.y)


## Cheap connectivity check before the expensive direction/bend search.
## If even an unrestricted four-way walk cannot reach the point goal,
## A* cannot reach it either.
static func _reachable(start: int, goal: int, hard: PackedByteArray, traces: PackedByteArray, size: Vector2i, excluded := -1, entries := PackedByteArray(), goal_box := Rect2i(), work_budget: Dictionary = {}) -> bool:
	var region := goal_box.has_area()
	if (region and goal_box.has_point(Vector2i(start%size.x,start/size.x))) or (not region and start == goal): return true
	var with_entries := not entries.is_empty()
	var seen := PackedByteArray()
	seen.resize(hard.size())
	var queue := PackedInt32Array()
	queue.resize(hard.size())
	queue[0] = start
	seen[start] = 1
	var head := 0
	var tail := 1
	var steps := [1,size.x,-1,-size.x]
	while head < tail:
		if not work_budget.is_empty() and not _take_work(work_budget): return false
		var cell := queue[head]
		head += 1
		var x := cell % size.x
		for d in 4:
			if (d == 0 and x == size.x-1) or (d == 2 and x == 0): continue
			var next: int = cell+steps[d]
			if next < 0 or next >= hard.size() or next == excluded or seen[next] != 0 or hard[next] != 0 or traces[next] != 0 or (with_entries and entries[next] != 0): continue
			if (region and goal_box.has_point(Vector2i(next%size.x,next/size.x))) or (not region and next == goal): return true
			seen[next] = 1
			queue[tail] = next
			tail += 1
	return false


static func _take_work(budget: Dictionary) -> bool:
	budget["left"] = int(budget["left"])-1
	return int(budget["left"]) >= 0
