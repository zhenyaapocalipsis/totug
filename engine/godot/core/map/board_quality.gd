extends RefCounted

## Geometry checks on the exported pixels, independent of the layout solver.
static func inspect(s: Dictionary, ring_radius := 5) -> Dictionary:
	var sites := {}
	var nodes := {}
	for id: String in s["sites"]:
		var r: Array = s["sites"][id]["rect"]
		sites[id] = Rect2(r[0], r[1], r[2], r[3])
		nodes[id] = sites[id]
	for id: String in s["rings"]:
		var p: Array = s["rings"][id]
		nodes[id] = Rect2(p[0] - ring_radius, p[1] - ring_radius,
			ring_radius * 2 + 1, ring_radius * 2 + 1)
	var overlaps := 0
	var overlap_nodes := []
	var ids: Array = nodes.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if (nodes[ids[i]] as Rect2).intersects(nodes[ids[j]]):
				overlaps += 1
				overlap_nodes.append([ids[i], ids[j]])
	var segments := []
	var foreign_hits := 0
	var bad_traces := {}
	for t in s["traces"].size():
		var f: Array = s["traces"][t]
		for k in range(0, f.size() - 2, 2):
			var a := Vector2(f[k], f[k + 1])
			var b := Vector2(f[k + 2], f[k + 3])
			segments.append([Rect2(a, Vector2.ZERO).expand(b).grow(0.01), t, k / 2])
		for id: String in sites:
			if (s["trace_ends"][t] as Array).has(id):
				continue
			var rect: Rect2 = sites[id]
			# One empty raster pixel between a 1px trace and the city frame.
			# Rect2.end is exclusive, so offset the pixel envelope by half a pixel.
			var margin := rect.grow(1)
			margin.position -= Vector2(0.5, 0.5)
			for k in range(0, f.size() - 2, 2):
				var a := Vector2(f[k], f[k + 1])
				var b := Vector2(f[k + 2], f[k + 3])
				var segment := Rect2(a, Vector2.ZERO).expand(b).grow(0.01)
				if segment.intersects(margin):
					if _port_contact(s, t, id, segment.intersection(margin)):
						continue
					foreign_hits += 1
					bad_traces[t] = true
					break
	var crossings := 0
	for i in segments.size():
		for j in range(i + 1, segments.size()):
			var a: Array = segments[i]
			var b: Array = segments[j]
			if a[1] == b[1] and absi(a[2] - b[2]) <= 1:
				continue
			if not (a[0] as Rect2).intersects(b[0]):
				continue
			var intersection := (a[0] as Rect2).intersection(b[0])
			var hidden := false
			for rect: Rect2 in sites.values():
				if rect.grow(0.02).encloses(intersection):
					hidden = true
			if hidden:
				continue
			var shared := false
			if a[1] != b[1]:
				for id: String in s["trace_ends"][a[1]]:
					if not (s["trace_ends"][b[1]] as Array).has(id):
						continue
					if nodes.has(id) and (nodes[id] as Rect2).grow(0.02).encloses(intersection):
						shared = true
					elif s["ports"].has(id):
						var p: Array = s["ports"][id]
						if Rect2(p[0] - 0.1, p[1] - 0.1, 0.2, 0.2).encloses(intersection):
							shared = true
			if not shared:
				crossings += 1
				bad_traces[a[1]] = true
				bad_traces[b[1]] = true
	return {"overlaps": overlaps, "crossings": crossings, "foreign_hits": foreign_hits,
		"bad_traces": bad_traces.keys(), "overlap_nodes": overlap_nodes}


## A city-to-city connection is split at a hex port. The second half may
## touch the first city's frame only at that shared port, never elsewhere.
static func _port_contact(s: Dictionary, edge: int, city: String, contact: Rect2) -> bool:
	for port: String in s["trace_ends"][edge]:
		if not s["ports"].has(port):
			continue
		var p: Array = s["ports"][port]
		if not Rect2(p[0] - 2, p[1] - 2, 4, 4).encloses(contact):
			continue
		for other in s["trace_ends"].size():
			var ends: Array = s["trace_ends"][other]
			if other != edge and ends.has(port) and ends.has(city):
				return true
	return false
