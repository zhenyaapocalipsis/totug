extends RefCounted

const Quality = preload("res://core/map/board_quality.gd")
const Repair = preload("res://core/map/board_route_repair.gd")
## Clearance targets in board pixels (the 1920x1080 view uses scale 2).
const NODE_GAP := 6
const TRACE_GAP := 4
const MAX_ATTEMPTS := 64
const MAX_PASSES := 16
const SEARCH_LIMIT := 20000
const SHIFTS := [Vector2(0,12),Vector2(12,0),Vector2(0,-12),Vector2(-12,0),
	Vector2(12,12),Vector2(-12,12),Vector2(12,-12),Vector2(-12,-12),
	Vector2(0,24),Vector2(24,0),Vector2(0,-24),Vector2(-24,0)]


## Clearance is a separate objective from topology: a near miss can still
## look like a junction. Distances count empty pixels, not centre distances.
static func inspect(s: Dictionary) -> Dictionary:
	var nodes := {}
	for id: String in s["sites"]:
		var r: Array = s["sites"][id]["rect"]
		nodes[id] = Rect2(r[0],r[1],r[2],r[3])
	for id: String in s["rings"]:
		var p: Array = s["rings"][id]
		nodes[id] = Rect2(p[0]-5,p[1]-5,11,11)
	var score := 0
	var crowded := {}
	var bad := {}
	var ids: Array = nodes.keys()
	for i in ids.size():
		for j in range(i+1,ids.size()):
			var gap := _gap(nodes[ids[i]],nodes[ids[j]])
			if gap < NODE_GAP:
				var penalty := int(pow(NODE_GAP-gap,2))
				score += penalty
				_add(crowded,ids[i],penalty)
				_add(crowded,ids[j],penalty)
	var segments := []
	for edge in s["traces"].size():
		var f: Array = s["traces"][edge]
		var line := []
		for k in range(0,f.size()-2,2):
			var a := Vector2(f[k],f[k+1])
			var b := Vector2(f[k+2],f[k+3])
			var rect := Rect2(a.min(b),(a-b).abs()+Vector2.ONE)
			line.append(rect)
			segments.append([rect,edge,k/2])
		for id: String in nodes:
			if (s["trace_ends"][edge] as Array).has(id):
				continue
			var gap := float(NODE_GAP)
			for rect: Rect2 in line:
				gap = minf(gap,_gap(rect,nodes[id]))
			if gap < NODE_GAP:
				var penalty := int(pow(NODE_GAP-gap,2)) * 8
				score += penalty
				_add(crowded,id,penalty)
				_add(bad,edge,penalty)
	for i in segments.size():
		for j in range(i+1,segments.size()):
			var a: Array = segments[i]
			var b: Array = segments[j]
			if a[1] == b[1] and absi(a[2]-b[2]) <= 1:
				continue
			var gap := _gap(a[0],b[0])
			if gap >= TRACE_GAP:
				continue
			var contact := (a[0] as Rect2).grow(TRACE_GAP/2.0).intersection((b[0] as Rect2).grow(TRACE_GAP/2.0))
			var common := false
			for id: String in s["trace_ends"][a[1]]:
				if not (s["trace_ends"][b[1]] as Array).has(id):
					continue
				if nodes.has(id) and (nodes[id] as Rect2).grow(TRACE_GAP).encloses(contact):
					common = true
				elif s["ports"].has(id):
					var p: Array = s["ports"][id]
					if Rect2(p[0]-TRACE_GAP,p[1]-TRACE_GAP,TRACE_GAP*2+1,TRACE_GAP*2+1).encloses(contact):
						common = true
			if common:
				continue
			var penalty := int(pow(TRACE_GAP-gap,2)) * 8
			score += penalty
			_add(bad,a[1],penalty)
			_add(bad,b[1],penalty)
	return {"score":score,"crowded_nodes":crowded,"bad_traces":bad}


## Bounded local search. Accept only less crowding with valid geometry;
## logical IDs stay fixed while drawing coordinates and hit targets move.
static func optimise(s: Dictionary) -> Dictionary:
	var result := s
	var metric := inspect(result)
	var original: int = metric["score"]
	var attempts := 0
	var moved_nodes := []
	var tried := {}
	for _round in MAX_PASSES:
		var improved := false
		var nodes: Array = metric["crowded_nodes"].keys()
		nodes.sort_custom(func(a,b): return metric["crowded_nodes"][a] > metric["crowded_nodes"][b])
		for id: String in nodes.slice(0,12):
			var node_attempts := 0
			for shift: Vector2 in SHIFTS:
				var signature := str([id,Repair._node_rect(result,id).position,shift])
				if tried.has(signature):
					continue
				var moved := Rect2(Repair._node_rect(result,id).position+shift,Repair._node_rect(result,id).size)
				if not _fits(result,id,moved):
					continue
				tried[signature] = true
				var candidate := result.duplicate(true)
				var group := _move(candidate,id,shift)
				_add_affected(candidate,id,group)
				node_attempts += 1
				attempts += 1
				if _reroute(candidate,group):
					var next := inspect(candidate)
					if next["score"] < metric["score"] and _valid(candidate):
						result = candidate
						if not moved_nodes.has(id):
							moved_nodes.append(id)
						metric = next
						improved = true
						break
				if attempts >= MAX_ATTEMPTS or node_attempts >= 4:
					break
			if improved or attempts >= MAX_ATTEMPTS:
				break
		if not improved and attempts < MAX_ATTEMPTS:
			var edges: Array = metric["bad_traces"].keys()
			edges.sort_custom(func(a,b): return metric["bad_traces"][a] > metric["bad_traces"][b])
			for edge: int in edges.slice(0,4):
				var candidate := result.duplicate(true)
				attempts += 1
				if not _reroute(candidate,[edge]):
					continue
				var next := inspect(candidate)
				if next["score"] < metric["score"] and _valid(candidate):
					result = candidate
					metric = next
					improved = true
					break
		if not improved or attempts >= MAX_ATTEMPTS or metric["score"] == 0:
			break
	result["spacing"] = {"before":original,"after":metric["score"],"attempts":attempts,"moved_nodes":moved_nodes}
	return result


static func _valid(s: Dictionary) -> bool:
	var q := Quality.inspect(s)
	return q["crossings"] == 0 and q["overlaps"] == 0 and q["foreign_hits"] == 0


static func _fits(s: Dictionary, id: String, rect: Rect2) -> bool:
	if not Rect2(2,2,s["size"][0]-4,s["size"][1]-4).encloses(rect):
		return false
	var legend: Array = s.get("a2_legend",[])
	if legend.size() == 4 and rect.grow(2).intersects(Rect2(legend[0],legend[1],legend[2],legend[3])):
		return false
	for other: String in s["sites"].keys()+s["rings"].keys():
		if other != id and rect.grow(2).intersects(Repair._node_rect(s,other)):
			return false
	return true


static func _move(s: Dictionary, id: String, shift: Vector2) -> Array:
	if s["sites"].has(id):
		var site: Dictionary = s["sites"][id]
		site["rect"][0] += shift.x
		site["rect"][1] += shift.y
		if site.has("icons_at"):
			site["icons_at"][0] += shift.x
			site["icons_at"][1] += shift.y
		for slot: String in site["slots"]:
			site["slots"][slot][0] += shift.x
			site["slots"][slot][1] += shift.y
			s["slots"][slot]["x"] += shift.x
			s["slots"][slot]["y"] += shift.y
	else:
		s["rings"][id][0] += shift.x
		s["rings"][id][1] += shift.y
		s["slots"][id]["x"] += shift.x
		s["slots"][id]["y"] += shift.y
	var group := []
	for edge in s["trace_ends"].size():
		for endpoint in 2:
			if s["trace_ends"][edge][endpoint] != id:
				continue
			var flat: Array = s["traces"][edge]
			var at := 0 if endpoint == 0 else flat.size()-2
			flat[at] += shift.x
			flat[at+1] += shift.y
			group.append(edge)
	return group


static func _add_affected(s: Dictionary, id: String, group: Array) -> void:
	var rect := Repair._node_rect(s,id).grow(NODE_GAP)
	for edge in s["traces"].size():
		if group.has(edge):
			continue
		var f: Array = s["traces"][edge]
		for k in range(0,f.size()-2,2):
			var a := Vector2(f[k],f[k+1])
			var b := Vector2(f[k+2],f[k+3])
			if rect.intersects(Rect2(a.min(b),(a-b).abs()+Vector2.ONE)):
				group.append(edge)
				break


static func _reroute(s: Dictionary, group: Array) -> bool:
	var remaining := group.duplicate()
	var route_view := s.duplicate()
	var legend: Array = s.get("a2_legend",[])
	if legend.size() == 4:
		route_view["sites"] = s["sites"].duplicate()
		route_view["sites"]["spacing_legend_obstacle"] = {"rect":legend}
	for edge: int in group:
		var flat: Array = s["traces"][edge]
		for endpoint in 2:
			var id: String = s["trace_ends"][edge][endpoint]
			if s["sites"].has(id):
				var r: Array = s["sites"][id]["rect"]
				var at := 0 if endpoint == 0 else flat.size()-2
				flat[at] = r[0]+floori(r[2]/2.0)
				flat[at+1] = r[1]+floori(r[3]/2.0)
		var path := Repair._route(route_view,edge,remaining,NODE_GAP,TRACE_GAP,SEARCH_LIMIT)
		if path.is_empty():
			# Open a crowded cluster incrementally: the next accepted move can
			# then give its neighbour enough room for the full target clearance.
			path = Repair._route(route_view,edge,remaining,2,2,SEARCH_LIMIT)
		if path.is_empty():
			return false
		s["traces"][edge] = path
		remaining.erase(edge)
	return true


static func _gap(a: Rect2, b: Rect2) -> float:
	return maxf(0,maxf(maxf(a.position.x-b.end.x,b.position.x-a.end.x),maxf(a.position.y-b.end.y,b.position.y-a.end.y)))


static func _add(values: Dictionary, key: Variant, amount: int) -> void:
	values[key] = int(values.get(key,0))+amount
