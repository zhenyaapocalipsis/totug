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
	var traces: Array = []
	var seen := {}
	for slot_id: String in g.slots.keys():
		var sa := g.site_of_slot(slot_id)
		var a := sa if sa != "" else slot_id
		for other in g.adjacent_slots(slot_id):
			var sb := g.site_of_slot(other)
			var b := sb if sb != "" else other
			if a == b or not at.has(a) or not at.has(b):
				continue
			var key2 := a + "|" + b if a < b else b + "|" + a
			if seen.has(key2):
				continue
			seen[key2] = true
			var pa: Vector2 = at[a]
			var pb: Vector2 = at[b]
			traces.append([pa.x, pa.y, pb.x, pb.y])
	var overlaps := 0
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).intersects(rects[j]):
				overlaps += 1
	print("%dp сид %d: наложений рамок %d, связей %d" % [players, seed_value, overlaps, traces.size()])
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
