extends SceneTree

## Карта ровно по арту печатного поля, вписанная в зону доски: локации и
## кольца на местах арта, связи прямыми. Это рисунок без пересечений — на нём
## проверяем, сколько работы остаётся (наложения рамок, углы связей).
## Run: ... --script res://tools/art_preview.gd -- <куда.png> <игроков> <сид>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "C:/art.png"
	var players := int(args[1]) if args.size() > 1 else 4
	var seed_value := int(args[2]) if args.size() > 2 else 3
	var use_tiles := args.size() > 3 and args[3] == "tiles"
	var target := Vector2(472, 252)
	var state := GameSetup.new_game(GameScreen.player_ids_for(players), seed_value)
	var g := state.graph
	var geo := BoardGeometry.build(state)
	var slots: Dictionary = geo["slots"]
	var at := {}
	var count := {}
	for slot_id: String in slots:
		var site := g.site_of_slot(slot_id)
		var key := site if site != "" else slot_id
		var p := Vector2(float(slots[slot_id]["x"]), float(slots[slot_id]["y"]))
		at[key] = (at.get(key, Vector2.ZERO) as Vector2) + p
		count[key] = int(count.get(key, 0)) + 1
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for key: String in at:
		at[key] = (at[key] as Vector2) / float(count[key])
		lo = lo.min(at[key])
		hi = hi.max(at[key])
	# вписываем в зону по каждой оси, с полями под полрамки
	var margin := Vector2(26, 18)
	var fit := (target - margin * 2.0) / (hi - lo)
	for key: String in at:
		at[key] = margin + ((at[key] as Vector2) - lo) * fit

	# Разведение рамок без единого пересечения: узел сдвигается, только если
	# после сдвига ни одна его связь не пересекает чужую.
	var half := {}
	for key: String in at:
		if g.sites.has(key):
			var bx := BoardSchematic.site_box(String(g.sites[key]["name"]), g.slots_of_site(key).size())
			half[key] = Vector2(float(bx["w"]), float(bx["h"])) * 0.5
		else:
			half[key] = Vector2(4, 4)
	var edges: Array = []
	var incident := {}
	var seen0 := {}
	for slot_id: String in g.slots.keys():
		var sa0 := g.site_of_slot(slot_id)
		var a0 := sa0 if sa0 != "" else slot_id
		for other in g.adjacent_slots(slot_id):
			var sb0 := g.site_of_slot(other)
			var b0 := sb0 if sb0 != "" else other
			if a0 == b0 or not at.has(a0) or not at.has(b0):
				continue
			var k0 := a0 + "|" + b0 if a0 < b0 else b0 + "|" + a0
			if seen0.has(k0):
				continue
			seen0[k0] = true
			edges.append([a0, b0])
			for x in [a0, b0]:
				var l: Array = incident.get(x, [])
				l.append(edges.size() - 1)
				incident[x] = l
	var keys: Array = at.keys()

	# Тесные тайлы раздвигаем ЦЕЛИКОМ: на арте локации одного тайла стоят
	# вплотную, и по одному узлу их не развести — соседи держат. Тайл
	# растягивается вокруг своей середины, шаг за шагом, пока его рамки
	# налезают друг на друга; каждый шаг принимается, только если ни одна
	# связь не пересекла чужую. Расположение ВНУТРИ тайла при этом то же,
	# что на арте, — меняется только его размер.
	var tile_of := {}
	var tiles := {}
	for key: String in keys:
		var tile := key.get_slice(":", 0)
		tile_of[key] = tile
		var list: Array = tiles.get(tile, [])
		list.append(key)
		tiles[tile] = list
	for _round in (30 if use_tiles else 0):
		var grew := 0
		for tile: String in tiles:
			var members: Array = tiles[tile]
			if not _inner_overlap(members, at, half):
				continue
			var mid := Vector2.ZERO
			for m: String in members:
				mid += at[m]
			mid /= float(members.size())
			var was_pos := {}
			for m: String in members:
				was_pos[m] = at[m]
				at[m] = mid + ((at[m] as Vector2) - mid) * 1.05
			var broken := false
			# растянутый тайл не должен вылезать за зону: тогда карту не
			# придётся потом ужимать обратно, и теснота не вернётся в другом месте
			for m: String in members:
				var r := Rect2((at[m] as Vector2) - half[m], (half[m] as Vector2) * 2.0)
				if not Rect2(Vector2.ZERO, target).encloses(r):
					broken = true
					break
				if _crosses(m, at, edges, incident):
					broken = true
					break
			if broken:
				for m: String in members:
					at[m] = was_pos[m]
			else:
				grew += 1
		if grew == 0:
			break
	# Тайлы расходятся как жёсткие блоки: внутри тайла всё как на арте, а
	# место берётся из пустот между тайлами. Тайл отталкивается от соседа
	# ровно на величину наложения их рамок; шаг принимается, только если ни
	# одна связь не пересекла чужую.
	for _round in (200 if use_tiles else 0):
		var moved_tiles := 0
		for tile: String in tiles:
			var members: Array = tiles[tile]
			var push := Vector2.ZERO
			for m: String in members:
				var rm := Rect2((at[m] as Vector2) - half[m] - Vector2(1.5, 1.5), (half[m] as Vector2) * 2.0 + Vector2(3, 3))
				for o: String in keys:
					if tile_of[o] == tile:
						continue
					var ro := Rect2((at[o] as Vector2) - half[o] - Vector2(1.5, 1.5), (half[o] as Vector2) * 2.0 + Vector2(3, 3))
					var cut := rm.intersection(ro)
					if cut.size.x <= 0.0 or cut.size.y <= 0.0:
						continue
					var d: Vector2 = (at[m] as Vector2) - (at[o] as Vector2)
					if cut.size.x <= cut.size.y:
						push.x += cut.size.x * (signf(d.x) if d.x != 0.0 else 1.0)
					else:
						push.y += cut.size.y * (signf(d.y) if d.y != 0.0 else 1.0)
			if push == Vector2.ZERO:
				continue
			var step := push * 0.5
			if step.length() > 3.0:
				step = step.normalized() * 3.0
			var was_pos := {}
			for m: String in members:
				was_pos[m] = at[m]
				var p: Vector2 = (at[m] as Vector2) + step
				at[m] = Vector2(clampf(p.x, (half[m] as Vector2).x, target.x - (half[m] as Vector2).x),
					clampf(p.y, (half[m] as Vector2).y, target.y - (half[m] as Vector2).y))
			var broken := false
			for m: String in members:
				if _crosses(m, at, edges, incident):
					broken = true
					break
			if broken:
				for m: String in members:
					at[m] = was_pos[m]
			else:
				moved_tiles += 1
		if moved_tiles == 0:
			break


	for _pass in 400:
		var moved := 0
		var any_overlap := false
		for k: String in keys:
			var push := Vector2.ZERO
			var rk := Rect2((at[k] as Vector2) - half[k] - Vector2(1.5, 1.5), (half[k] as Vector2) * 2.0 + Vector2(3, 3))
			for o: String in keys:
				if o == k:
					continue
				var ro := Rect2((at[o] as Vector2) - half[o] - Vector2(1.5, 1.5), (half[o] as Vector2) * 2.0 + Vector2(3, 3))
				var cut := rk.intersection(ro)
				if cut.size.x <= 0.0 or cut.size.y <= 0.0:
					continue
				any_overlap = true
				var d: Vector2 = (at[k] as Vector2) - (at[o] as Vector2)
				if cut.size.x <= cut.size.y:
					push.x += cut.size.x * (signf(d.x) if d.x != 0.0 else 1.0)
				else:
					push.y += cut.size.y * (signf(d.y) if d.y != 0.0 else 1.0)
			if push == Vector2.ZERO:
				continue
			var step := push * 0.5
			if step.length() > 3.0:
				step = step.normalized() * 3.0
			var was: Vector2 = at[k]
			var want: Vector2 = was + step
			at[k] = Vector2(clampf(want.x, (half[k] as Vector2).x, target.x - (half[k] as Vector2).x),
				clampf(want.y, (half[k] as Vector2).y, target.y - (half[k] as Vector2).y))
			if _crosses(k, at, edges, incident):
				at[k] = was
			else:
				moved += 1
		if moved == 0 or not any_overlap:
			break

	# Связи к 45 градусам. Узел пробует сдвинуться на шаг в каждую из восьми
	# сторон и остаётся там, где его связи ближе всего к кратным 45 углам.
	# Шаг принимается, только если не рождает ни пересечения, ни наложения
	# рамок и не выводит рамку за зону — то есть всё, чего уже добились,
	# сохраняется. Кольца двигаются охотнее рамок: они мелкие и на карте
	# служат изломами линии.
	var octo_dirs: Array[Vector2] = [Vector2(1,0), Vector2(1,1), Vector2(0,1), Vector2(-1,1),
		Vector2(-1,0), Vector2(-1,-1), Vector2(0,-1), Vector2(1,-1)]
	for _pass in OCTO_PASSES:
		var improved := 0
		for k: String in keys:
			var was: Vector2 = at[k]
			var best_cost := _angle_cost(k, at, edges, incident)
			if best_cost < 0.01:
				continue
			var best_at := was
			for step_len: float in [2.0, 4.0, 6.0]:
				for dir: Vector2 in octo_dirs:
					var p: Vector2 = was + dir * step_len
					var r := Rect2(p - half[k], (half[k] as Vector2) * 2.0)
					if not Rect2(Vector2.ZERO, target).encloses(r):
						continue
					at[k] = p
					var cost := _angle_cost(k, at, edges, incident)
					if cost >= best_cost - 0.01:
						continue
					if _crosses(k, at, edges, incident) or _overlaps_any(k, at, half, keys):
						continue
					best_cost = cost
					best_at = p
			at[k] = best_at
			if best_at != was:
				improved += 1
		if improved == 0:
			break

	var sites := {}
	var rects: Array = []
	for site_id: String in g.sites:
		if not at.has(site_id):
			continue
		var box := BoardSchematic.site_box(String(g.sites[site_id]["name"]), g.slots_of_site(site_id).size())
		var hs := Vector2(float(box["w"]), float(box["h"])) * 0.5
		var corner: Vector2 = (at[site_id] as Vector2) - hs
		var site_slots := {}
		var members := g.slots_of_site(site_id)
		for i in members.size():
			var sp: Vector2 = corner + ((box["slots"] as Array)[i] as Vector2)
			site_slots[members[i]] = [sp.x, sp.y]
		sites[site_id] = {"rect": [corner.x, corner.y, hs.x * 2.0, hs.y * 2.0],
			"name": g.sites[site_id]["name"], "vp": g.sites[site_id]["vp"],
			"starting": false, "marker": false, "slots": site_slots}
		rects.append(Rect2(corner, hs * 2.0))
	var rings := {}
	for key: String in at:
		if not g.sites.has(key):
			rings[key] = [(at[key] as Vector2).x, (at[key] as Vector2).y]
			rects.append(Rect2((at[key] as Vector2) - Vector2(4, 4), Vector2(8, 8)))
	# Сначала все связи прямыми; потом те, что не кратны 45 градусам, получают
	# один излом в 45 — с той стороны, где излом никого не пересекает и не
	# лезет в чужую рамку. Если обе стороны заняты, связь остаётся прямой: она
	# чуть косая, зато ничего не ломает.
	var poly := {}
	var ends := {}
	var box_of := {}
	for key: String in keys:
		box_of[key] = Rect2((at[key] as Vector2) - half[key], (half[key] as Vector2) * 2.0)
	for e: Array in edges:
		var k3: String = e[0] + "|" + e[1]
		poly[k3] = PackedVector2Array([at[e[0]], at[e[1]]])
		ends[k3] = e
	for k3: String in poly.keys():
		var pts: PackedVector2Array = poly[k3]
		var d: Vector2 = pts[1] - pts[0]
		var off := fposmod(rad_to_deg(atan2(d.y, d.x)), 45.0)
		if minf(off, 45.0 - off) <= 3.0:
			continue
		var run := minf(absf(d.x), absf(d.y))
		var diag := Vector2(signf(d.x), signf(d.y)) * run
		var e3: Array = ends[k3]
		for corner: Vector2 in [pts[0] + diag, pts[1] - diag]:
			var cand := PackedVector2Array([pts[0], corner, pts[1]])
			if _bend_ok(cand, k3, e3, poly, ends, box_of):
				poly[k3] = cand
				break
	var traces: Array = []
	for k3: String in poly.keys():
		var flat: Array = []
		for p: Vector2 in (poly[k3] as PackedVector2Array):
			flat.append(p.x)
			flat.append(p.y)
		traces.append(flat)
	var overlaps := 0
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).intersects(rects[j]):
				overlaps += 1
	# Проверка по ГОТОВЫМ трассам (с изломами), а не по прямым связям.
	var crossings := 0
	var plist: Array = poly.keys()
	for i in plist.size():
		for j in range(i + 1, plist.size()):
			var ea: Array = ends[plist[i]]
			var eb: Array = ends[plist[j]]
			var shares: bool = ea[0] == eb[0] or ea[0] == eb[1] or ea[1] == eb[0] or ea[1] == eb[1]
			var pa2: PackedVector2Array = poly[plist[i]]
			var pb2: PackedVector2Array = poly[plist[j]]
			var hit_any := false
			for s in pa2.size() - 1:
				for t in pb2.size() - 1:
					var hit: Variant = Geometry2D.segment_intersects_segment(pa2[s], pa2[s + 1], pb2[t], pb2[t + 1])
					if hit == null:
						continue
					var hp: Vector2 = hit
					if shares and (hp.is_equal_approx(pa2[0]) or hp.is_equal_approx(pa2[pa2.size() - 1])):
						continue
					hit_any = true
			if hit_any:
				crossings += 1
	var straight := 0
	for k4: String in poly.keys():
		var pp: PackedVector2Array = poly[k4]
		var all_ok := true
		for s in pp.size() - 1:
			var dd := pp[s + 1] - pp[s]
			var off := fposmod(rad_to_deg(atan2(dd.y, dd.x)), 45.0)
			if minf(off, 45.0 - off) > 3.0:
				all_ok = false
		if all_ok:
			straight += 1
	print("%dp сид %d: наложений %d, пересечений %d, связей %d, под 45° %d" % [players, seed_value, overlaps, crossings, traces.size(), straight])
	var schematic := {"size": [target.x, target.y], "traces": traces, "rings": rings,
		"sites": sites, "slots": {}}
	var img := SchematicPainter.paint(schematic)
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	quit()


static func _crosses(k: String, at: Dictionary, edges: Array, incident: Dictionary) -> bool:
	for ei: int in (incident.get(k, []) as Array):
		var e1: Array = edges[ei]
		for j in edges.size():
			if j == ei:
				continue
			var e2: Array = edges[j]
			if e1[0] == e2[0] or e1[0] == e2[1] or e1[1] == e2[0] or e1[1] == e2[1]:
				continue
			if Geometry2D.segment_intersects_segment(at[e1[0]], at[e1[1]], at[e2[0]], at[e2[1]]) != null:
				return true
	return false


## Налезают ли рамки внутри одной группы узлов друг на друга.
static func _inner_overlap(members: Array, at: Dictionary, half: Dictionary) -> bool:
	for i in members.size():
		for j in range(i + 1, members.size()):
			var a: String = members[i]
			var b: String = members[j]
			if Rect2((at[a] as Vector2) - half[a], (half[a] as Vector2) * 2.0).intersects(
					Rect2((at[b] as Vector2) - half[b], (half[b] as Vector2) * 2.0)):
				return true
	return false


const OCTO_PASSES := 60

## Насколько связи узла отклоняются от кратных 45 градусов (в градусах,
## сумма по связям).
static func _angle_cost(k: String, at: Dictionary, edges: Array, incident: Dictionary) -> float:
	var total := 0.0
	for ei: int in (incident.get(k, []) as Array):
		var e: Array = edges[ei]
		var d: Vector2 = (at[e[1]] as Vector2) - (at[e[0]] as Vector2)
		if d.length() < 0.5:
			continue
		var deg := rad_to_deg(atan2(d.y, d.x))
		var off := fposmod(deg, 45.0)
		total += minf(off, 45.0 - off)
	return total


## Налезает ли рамка узла k на чужую.
static func _overlaps_any(k: String, at: Dictionary, half: Dictionary, keys: Array) -> bool:
	var rk := Rect2((at[k] as Vector2) - half[k], (half[k] as Vector2) * 2.0)
	for o: String in keys:
		if o == k:
			continue
		if rk.intersects(Rect2((at[o] as Vector2) - half[o], (half[o] as Vector2) * 2.0)):
			return true
	return false


## Годится ли ломаная для связи k: ни один её отрезок не пересекает чужие
## трассы (кроме общих концов) и не заходит в чужую рамку.
static func _bend_ok(cand: PackedVector2Array, k: String, e: Array, poly: Dictionary,
		ends: Dictionary, box_of: Dictionary) -> bool:
	for i in cand.size() - 1:
		var a: Vector2 = cand[i]
		var b: Vector2 = cand[i + 1]
		for other: String in poly.keys():
			if other == k:
				continue
			var oe: Array = ends[other]
			var shares: bool = oe[0] == e[0] or oe[0] == e[1] or oe[1] == e[0] or oe[1] == e[1]
			var op: PackedVector2Array = poly[other]
			for j in op.size() - 1:
				var hit: Variant = Geometry2D.segment_intersects_segment(a, b, op[j], op[j + 1])
				if hit == null:
					continue
				var at_hit: Vector2 = hit
				if shares and (at_hit.is_equal_approx(cand[0]) or at_hit.is_equal_approx(cand[cand.size() - 1])):
					continue
				return false
		for node: String in box_of.keys():
			if node == e[0] or node == e[1]:
				continue
			var r: Rect2 = (box_of[node] as Rect2).grow(1.0)
			if _seg_hits(a, b, r):
				return false
	return true


static func _seg_hits(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[i], c[(i + 1) % 4]) != null:
			return true
	return false
