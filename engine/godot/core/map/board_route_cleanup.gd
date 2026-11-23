extends RefCounted

const Metrics = preload("res://core/map/board_metrics.gd")

const Repair = preload("res://core/map/board_route_repair.gd")
const Spacing = preload("res://core/map/board_spacing.gd")
const SEARCH_LIMIT := 20000
const MAX_EDGES := 12
const MAX_RINGS := 8
const WORK_LIMIT := 1000000


## Remove geometric backtracking without deleting troop spaces or links.
## A degree-two ring is a movable marker on its road, not a required detour.
static func simplify(s: Dictionary) -> Dictionary:
	var work_budget := {"left":WORK_LIMIT}
	var result := s.duplicate(true)
	var before := inspect(result)
	var shape := before
	var clearance: int = _spacing(result)["score"]
	var changed := 0
	var failed_cities := {}
	var edges := []
	for edge in result["traces"].size():
		var excess := _excess(_visible_route(result,edge))
		var bad := _bad_entries(result,edge)
		if excess > 0 or bad > 0:
			edges.append([edge,bad*1000+excess])
	edges.sort_custom(func(a,b): return a[1] > b[1])
	for entry: Array in edges.slice(0,MAX_EDGES):
		if int(work_budget["left"]) <= 0: break
		var edge: int = entry[0]
		var candidate := result.duplicate(true)
		var routed := Spacing._reroute(candidate,[edge],true,work_budget)
		var next: Dictionary = inspect(candidate) if routed else {}
		if not routed or not _improves(shape,next) or not _acceptable(candidate,clearance,result):
			candidate = _fix_entry(result,edge,clearance,failed_cities,work_budget)
			if candidate.is_empty(): continue
			next = inspect(candidate)
		# Both branches have already checked the candidate against result.
		result = candidate
		shape = next
		clearance = _spacing(result)["score"]
		changed += 1
		failed_cities.clear()
	var failed_regions := {}
	var dirty_regions := []
	for _pass in 2:
		var accepted := false
		var protected := {}
		for link: Dictionary in Spacing._straight_links(result):
			for id: String in link["rings"]: protected[id] = true
		var rings := []
		for id: String in result["rings"]:
			if protected.has(id): continue
			var incident := _incident(result,id)
			if incident.size() != 2: continue
			var excess := _excess(_joined(result,id,incident))
			if excess > 0: rings.append([id,excess])
		rings.sort_custom(func(a,b): return a[1] > b[1])
		for entry: Array in rings.slice(0,MAX_RINGS):
			if int(work_budget["left"]) <= 0: break
			var id: String = entry[0]
			if _pass > 0:
				var affected := false
				for region: Rect2 in dirty_regions:
					if failed_regions.has(id) and (failed_regions[id] as Rect2).intersects(region): affected = true
				if not affected: continue
			failed_regions[id] = _path_bounds(_joined(result,id,_incident(result,id))).grow(16)
			var candidate := _shorten_ring(result,entry[0],work_budget)
			if candidate.is_empty(): continue
			# _shorten_ring returns only an improving, validated candidate.
			dirty_regions.append(_changed_bounds(result,candidate).grow(6))
			failed_regions.erase(id)
			result = candidate
			shape = inspect(candidate)
			clearance = _spacing(result)["score"]
			changed += 1
			accepted = true
		if not accepted: break
	result["route_cleanup"] = {"before":before,"after":shape,"changed":changed,"work":WORK_LIMIT-int(work_budget["left"]),"budget_exhausted":int(work_budget["left"]) <= 0}
	if result.has("spacing"): result["spacing"]["after"] = clearance
	result.erase("__spacing_metrics")
	return result


static func inspect(s: Dictionary) -> Dictionary:
	var bends := 0
	var length := 0.0
	var detour := 0.0
	var bad_entries := 0
	for edge in s["traces"].size():
		var f: Array = _visible_route(s,edge)
		bad_entries += _bad_entries(s,edge)
		detour += _excess(f)
		for k in range(0,f.size()-2,2):
			length += Vector2(f[k],f[k+1]).distance_to(Vector2(f[k+2],f[k+3]))
		for k in range(2,f.size()-2,2):
			if not _hidden(s,edge,Vector2(f[k],f[k+1])):
				bends += 1
	for id: String in s["rings"]:
		var incident := _incident(s,id)
		if incident.size() == 2:
			detour += _excess(_joined(s,id,incident))
	return {"bends":bends,"length":length,"detour":detour,"bad_entries":bad_entries,
		"cost":bad_entries*1000.0+detour*10.0+bends*30.0+length*0.01}


static func _acceptable(s: Dictionary, _clearance: int, before: Dictionary = {}) -> bool:
	if not Spacing._valid(s) or (not before.is_empty() and not Spacing._keeps_straight_links(before,s)): return false
	if before.is_empty(): return true
	for edge in s["traces"].size():
		if _bad_entries(s,edge) > _bad_entries(before,edge): return false
	var old: Dictionary = _spacing(before)["tight"]
	var next: Dictionary = _spacing(s)["tight"]
	for key: String in next:
		if float(next[key]) > float(old.get(key,0)):
			return false
	return true



## If the clean road is blocked by another movable ring, open that corridor
## jointly rather than keeping a hook around the old marker location.
static func _shorten_ring(s: Dictionary, id: String, work_budget: Dictionary = {}) -> Dictionary:
	var baseline := inspect(s)
	var clearance: int = _spacing(s)["score"]
	var simple := _place_ring(s,id,work_budget)
	if not simple.is_empty() and _improves(baseline,inspect(simple)):
		return simple
	var incident := _incident(s,id)
	for edge: int in incident:
		for city: String in s["trace_ends"][edge]:
			if not s["sites"].has(city) or _bad_entries(s,edge) == 0: continue
			var refreshed := s.duplicate(true)
			var group := _incident(refreshed,city)
			if Spacing._reroute(refreshed,group,true,work_budget) and Spacing._valid(refreshed):
				var placed := _place_ring(refreshed,id,work_budget)
				if not placed.is_empty() and _improves(baseline,inspect(placed)) and _acceptable(placed,clearance,s): return placed
	var whole := _joined(s,id,incident)
	var start := Vector2(whole[0],whole[1])
	var finish := Vector2(whole[-2],whole[-1])
	var corridor := Rect2(start.min(finish),(start-finish).abs())
	var blockers := []
	for other: String in s["rings"]:
		if other == id:
			continue
		var p: Array = s["rings"][other]
		var at := Vector2(p[0],p[1])
		var nearest := at.clamp(corridor.position,corridor.end)
		if at.distance_to(nearest) <= 18:
			blockers.append([other,at-nearest,1])
	for edge: int in incident:
		for endpoint: String in s["trace_ends"][edge]:
			if not s["sites"].has(endpoint):
				continue
			var rect := Repair._node_rect(s,endpoint)
			var away := rect.get_center() - (finish if edge == incident[0] else start)
			blockers.append([endpoint,away,0])
	blockers.sort_custom(func(a,b): return a[2] < b[2] if a[2] != b[2] else (a[1] as Vector2).length_squared() < (b[1] as Vector2).length_squared())
	var tried := 0
	for blocker: Array in blockers:
		var shifts := [Vector2(-6,0),Vector2(6,0),Vector2(0,-6),Vector2(0,6),Vector2(-12,0),Vector2(12,0),Vector2(0,-12),Vector2(0,12)]
		shifts.sort_custom(func(a,b):
			var x := (a as Vector2).normalized().dot((blocker[1] as Vector2).normalized())
			var y := (b as Vector2).normalized().dot((blocker[1] as Vector2).normalized())
			return x > y if not is_equal_approx(x,y) else (a as Vector2).length_squared() < (b as Vector2).length_squared())
		for shift: Vector2 in shifts:
			var other: String = blocker[0]
			var rect := Repair._node_rect(s,other)
			if not Spacing._fits(s,other,Rect2(rect.position+shift,rect.size)):
				continue
			var moved := s.duplicate(true)
			var group := Spacing._move(moved,other,shift)
			if group.is_empty(): continue
			Spacing._add_affected(moved,other,group,s)
			tried += 1
			if Spacing._reroute(moved,group,true,work_budget) and Spacing._valid(moved):
				var candidate := _place_ring(moved,id,work_budget)
				if not candidate.is_empty() and _improves(baseline,inspect(candidate)) and _acceptable(candidate,clearance,s):
					return candidate
			if tried >= 2:
				return {}
	return {}


static func _improves(before: Dictionary, after: Dictionary) -> bool:
	return int(after["bad_entries"]) <= int(before["bad_entries"]) and (int(after["bad_entries"]) < int(before["bad_entries"]) or float(after["detour"]) <= float(before["detour"])) and float(after["cost"]) < float(before["cost"])-0.01


static func _place_ring(s: Dictionary, id: String, work_budget: Dictionary = {}) -> Dictionary:
	var incident := _incident(s,id)
	if incident.size() != 2:
		return {}
	var e: int = incident[0]
	var other: int = incident[1]
	var a := _outward(s,e,id)
	var b := _outward(s,other,id)
	var ends_a: Array = s["trace_ends"][e]
	var ends_b: Array = s["trace_ends"][other]
	var from: String = ends_a[1] if ends_a[0] == id else ends_a[0]
	var to: String = ends_b[1] if ends_b[0] == id else ends_b[0]
	var view := s.duplicate(true)
	view["rings"].erase(id)
	view["trace_ends"][e] = [from,to]
	view["trace_ends"][other] = []
	view["traces"][e] = [a[-2],a[-1],b[-2],b[-1]]
	view["traces"][other] = []
	var reserve := view.duplicate(true)
	for ring: String in view["rings"]:
		if ring == from or ring == to: continue
		var box := Repair._node_rect(view,ring).grow(maxi(1,Metrics.RADIUS-3))
		reserve["sites"]["marker_reserve:"+ring] = {"rect":[box.position.x,box.position.y,box.size.x,box.size.y]}
	if Spacing._reroute(reserve,[e],true,work_budget):
		view = reserve
	elif not Spacing._reroute(view,[e],true,work_budget):
		return {}
	var path: Array = view["traces"][e]
	var original: Array = s["rings"][id]
	var baseline := inspect(s)
	var positions := []
	for k in range(0,path.size()-2,2):
		var start := Vector2(path[k],path[k+1])
		var finish := Vector2(path[k+2],path[k+3])
		var distance := int(start.distance_to(finish))
		var direction := (finish-start).normalized()
		for step in range(0,distance+1):
			var p := start+direction*step
			# Put a turn inside the marker, or leave a visible straight stub.
			if (step > 0 and step < Metrics.RADIUS+5) or (step < distance and distance-step < Metrics.RADIUS+5):
				continue
			positions.append([p,k,p.distance_squared_to(Vector2(original[0],original[1]))])
	positions.sort_custom(func(x,y): return x[2] < y[2])
	# Test nearest positions first; stop after the same six valid options.
	var valid_options := 0
	for option: Array in positions:
		var p: Vector2 = option[0]
		var rect := Rect2(p-Vector2.ONE*Metrics.RADIUS,Vector2.ONE*Metrics.DIAMETER)
		if not Spacing._fits(s,id,rect) or not _clear_marker(view,e,rect): continue
		valid_options += 1
		if valid_options > 6: break
		var k: int = option[1]
		var left: Array = path.slice(0,k+2)
		if Vector2(left[-2],left[-1]) != p:
			left.append_array([p.x,p.y])
		var right: Array = [p.x,p.y]
		if Vector2(path[k+2],path[k+3]) != p:
			right.append_array(path.slice(k+2))
		else:
			right.append_array(path.slice(k+4))
		if left.size() < 4 or right.size() < 4:
			continue
		var candidate := s.duplicate(true)
		candidate["rings"][id] = [p.x,p.y]
		candidate["slots"][id] = {"x":p.x,"y":p.y}
		if ends_a[0] == id:
			left = _reverse(left)
		if ends_b[1] == id:
			right = _reverse(right)
		candidate["traces"][e] = left
		candidate["traces"][other] = right
		candidate.erase("__spacing_metrics")
		if not _improves(baseline,inspect(candidate)): continue
		if _acceptable(candidate,_spacing(s)["score"],s):
			return candidate
	return {}


static func _clear_marker(s: Dictionary, own_edge: int, rect: Rect2) -> bool:
	for edge in s["traces"].size():
		if edge == own_edge:
			continue
		var f: Array = s["traces"][edge]
		for k in range(0,f.size()-2,2):
			var a := Vector2(f[k],f[k+1])
			var b := Vector2(f[k+2],f[k+3])
			if rect.grow(4).intersects(Rect2(a.min(b),(a-b).abs()+Vector2.ONE)):
				return false
	return true


static func _incident(s: Dictionary, id: String) -> Array:
	var edges := []
	for edge in s["trace_ends"].size():
		if (s["trace_ends"][edge] as Array).has(id):
			edges.append(edge)
	return edges


static func _outward(s: Dictionary, edge: int, id: String) -> Array:
	var f: Array = s["traces"][edge]
	return f.duplicate() if s["trace_ends"][edge][0] == id else _reverse(f)


static func _joined(s: Dictionary, id: String, incident: Array) -> Array:
	var a := _reverse(_outward(s,incident[0],id))
	a.append_array(_outward(s,incident[1],id).slice(2))
	for end in 2:
		var edge: int = incident[end]
		for node: String in s["trace_ends"][edge]:
			if not s["sites"].has(node): continue
			if end == 1: a = _reverse(a)
			a = _trim_city(a,Repair._node_rect(s,node))
			if end == 1: a = _reverse(a)
	return a


static func _reverse(f: Array) -> Array:
	var result := []
	for k in range(f.size()-2,-1,-2):
		result.append_array([f[k],f[k+1]])
	return result


static func _excess(f: Array) -> float:
	if f.size() < 4:
		return 0.0
	var distance := 0.0
	for k in range(0,f.size()-2,2):
		distance += absf(f[k+2]-f[k])+absf(f[k+3]-f[k+1])
	return distance-absf(f[-2]-f[0])-absf(f[-1]-f[1])


static func _hidden(s: Dictionary, edge: int, p: Vector2) -> bool:
	for id: String in s["trace_ends"][edge]:
		if s["sites"].has(id):
			if Repair._node_rect(s,id).has_point(p):
				return true
		elif s["rings"].has(id):
			var r: Array = s["rings"][id]
			if p.distance_squared_to(Vector2(r[0],r[1])) <= Metrics.RADIUS*Metrics.RADIUS+Metrics.RADIUS:
				return true
	return false


## A city is entered normally through a face, away from the corner, with
## a visible straight lead before the first outside bend.
static func _bad_entries(s: Dictionary, edge: int) -> int:
	var bad := 0
	for id: String in s["trace_ends"][edge]:
		if not s["sites"].has(id): continue
		var rect := Repair._node_rect(s,id)
		var f := _outward(s,edge,id)
		for k in range(0,f.size()-2,2):
			var a := Vector2(f[k],f[k+1])
			var b := Vector2(f[k+2],f[k+3])
			if rect.has_point(b): continue
			var horizontal := not is_zero_approx(a.x-b.x)
			var pin := a.y if horizontal else a.x
			var low := rect.position.y if horizontal else rect.position.x
			var high := rect.end.y-1 if horizontal else rect.end.x-1
			var border := (rect.end.x-1 if b.x > a.x else rect.position.x) if horizontal else (rect.end.y-1 if b.y > a.y else rect.position.y)
			var lead := absf((b.x if horizontal else b.y)-border)
			if pin < low+3 or pin > high-3 or lead < 6: bad += 1
			break
	return bad


static func _fix_entry(s: Dictionary, edge: int, clearance: int, failed_cities: Dictionary = {}, work_budget: Dictionary = {}) -> Dictionary:
	if _bad_entries(s,edge) == 0: return {}
	for city: String in s["trace_ends"][edge]:
		if not s["sites"].has(city): continue
		if failed_cities.has(city): continue
		var outward := _outward(s,edge,city)
		var outside := Vector2(outward[-2],outward[-1])
		var direction := outside-Repair._node_rect(s,city).get_center()
		var alignment := _entry_alignment(Repair._node_rect(s,city),outside)
		var shifts := [Vector2(6,0),Vector2(-6,0),Vector2(0,6),Vector2(0,-6)]
		shifts.sort_custom(func(a,b): return (a as Vector2).dot(direction) > (b as Vector2).dot(direction))
		for shift: Vector2 in shifts:
			var rect := Repair._node_rect(s,city)
			if not Spacing._fits(s,city,Rect2(rect.position+shift,rect.size)): continue
			if _entry_alignment(Rect2(rect.position+shift,rect.size),outside) >= alignment: continue
			var candidate := s.duplicate(true)
			var group := Spacing._move(candidate,city,shift)
			if group.is_empty(): continue
			Spacing._add_affected(candidate,city,group,s)
			if Spacing._reroute(candidate,group,true,work_budget) and _improves(inspect(s),inspect(candidate)) and _acceptable(candidate,clearance,s): return candidate
		failed_cities[city] = true
	return {}


## Only shift a city when it improves the available face/lead geometry.
## Otherwise retrying all four shifts just repeats the same blocked search.
static func _entry_alignment(rect: Rect2, p: Vector2) -> float:
	var dx := maxf(0,maxf(rect.position.x+3-p.x,p.x-rect.end.x+4))
	var dy := maxf(0,maxf(rect.position.y+3-p.y,p.y-rect.end.y+4))
	var vertical := maxf(p.y-rect.end.y+1,rect.position.y-p.y)
	var horizontal := maxf(p.x-rect.end.x+1,rect.position.x-p.x)
	return minf(dx*dx+pow(maxf(0,6-vertical),2),dy*dy+pow(maxf(0,6-horizontal),2))


static func _visible_route(s: Dictionary, edge: int) -> Array:
	var f: Array = (s["traces"][edge] as Array).duplicate()
	for end in 2:
		var node: String = s["trace_ends"][edge][end]
		if not s["sites"].has(node): continue
		if end == 1: f = _reverse(f)
		f = _trim_city(f,Repair._node_rect(s,node))
		if end == 1: f = _reverse(f)
	return f


static func _trim_city(f: Array, rect: Rect2) -> Array:
	for k in range(2,f.size(),2):
		var b := Vector2(f[k],f[k+1])
		if rect.has_point(b): continue
		var a := Vector2(f[k-2],f[k-1])
		if not rect.has_point(a): return f
		if a.x != b.x:
			a.x = rect.end.x-1 if b.x > a.x else rect.position.x
		else:
			a.y = rect.end.y-1 if b.y > a.y else rect.position.y
		var out := [a.x,a.y]
		out.append_array(f.slice(k))
		return out
	return f


static func _spacing(s: Dictionary) -> Dictionary:
	if not s.has("__spacing_metrics"):
		s["__spacing_metrics"] = Spacing.inspect(s)
	return s["__spacing_metrics"]


static func _path_bounds(f: Array) -> Rect2:
	var box := Rect2(Vector2(f[0],f[1]),Vector2.ZERO)
	for k in range(2,f.size(),2): box = box.expand(Vector2(f[k],f[k+1]))
	return box


static func _changed_bounds(before: Dictionary, after: Dictionary) -> Rect2:
	var area := Rect2()
	var first := true
	for edge in before["traces"].size():
		if before["traces"][edge] == after["traces"][edge]: continue
		var box := _path_bounds(before["traces"][edge]).merge(_path_bounds(after["traces"][edge]))
		area = box if first else area.merge(box)
		first = false
	return area
