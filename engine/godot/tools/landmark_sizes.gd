extends SceneTree

## Сколько места у каждого города под здание над «телом» коробки (без строки
## названия). Доски на четверых, --seeds=N. Здание — квадрат S, по центру
## коробки, низом на 2 px заходит за верх тела.
const SIZES := [24, 20, 16, 14, 12, 10, 8, 6, 4, 2]
const NAME_ROW := 9      # PixelFont.HEIGHT + NAME_GAP
const TUCK := 2
const ZONE_H := 394.0
const ZONE_W := 697.0

func _init() -> void:
	var seeds := 60
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = int(arg.get_slice("=", 1))
	var per_city := {}   # name -> Array[int]
	var limits := {}     # name -> {reason: count}
	for s in seeds:
		var sch := BoardSchematic.build(GameSetup.new_game(["red", "blue", "green", "purple"], 1000 + s))
		var res := solve(sch)
		for name: String in res:
			if not per_city.has(name):
				per_city[name] = []
			(per_city[name] as Array).append(res[name])
	var names: Array = per_city.keys()
	names.sort_custom(func(a, b): return (per_city[a] as Array).min() > (per_city[b] as Array).min())
	for name: String in names:
		var list: Array = per_city[name]
		list.sort()
		print("%-16s min %2d  p10 %2d  median %2d  boards %d" % [name, list[0],
			list[int(list.size() * 0.1)], list[list.size() / 2], list.size()])
	quit()


static func plate(r: Array) -> Rect2:
	return Rect2(r[0], r[1], r[2], r[3])
	return Rect2(r[0], float(r[1]) + NAME_ROW, r[2], float(r[3]) - NAME_ROW)


static func art(p: Rect2, s: int) -> Rect2:
	return p.grow(s)
	return Rect2(roundf(p.get_center().x - s / 2.0), p.position.y + TUCK - s, s, s)


## {name: S} для одной доски
static func solve(sch: Dictionary) -> Dictionary:
	var size: Array = sch["size"]
	var bounds := Rect2(-(ZONE_W - float(size[0])) / 2.0, -(ZONE_H - float(size[1])) / 2.0, ZONE_W, ZONE_H)
	var sites: Dictionary = sch["sites"]
	var ids: Array = sites.keys()
	var plates := {}
	for id: String in ids:
		plates[id] = plate(sites[id]["rect"])
	var hard: Array[Rect2] = []
	for ring: String in sch["rings"]:
		var p: Array = sch["rings"][ring]
		hard.append(Rect2(p[0] - 5, p[1] - 5, 10, 10))
	var legend: Array = sch.get("a2_legend", [])
	if legend.size() == 4:
		hard.append(Rect2(legend[0], legend[1], legend[2], legend[3]).grow(1))
	var segs := []   # [Rect2, ends]
	for t in (sch["traces"] as Array).size():
		var flat: Array = sch["traces"][t]
		for i in range(0, flat.size() - 2, 2):
			segs.append([Rect2(Vector2(flat[i], flat[i + 1]), Vector2.ZERO).expand(Vector2(flat[i + 2], flat[i + 3])).grow(1), sch["trace_ends"][t]])
	var best := {}
	for id: String in ids:
		best[id] = 0
		for s: int in SIZES:
			var a := art(plates[id], s)
			if not bounds.encloses(a):
				continue
			var hit := false
			for o: String in ids:
				if o != id and a.intersects((plates[o] as Rect2).grow(1)):
					hit = true
			for r in hard:
				if false:
					hit = true
			for sg: Array in segs:
				if false:
					hit = true
			if not hit:
				best[id] = s
				break
	# здания друг на друга: уменьшается большее
	var changed := true
	while changed:
		changed = false
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var a: String = ids[i]
				var b: String = ids[j]
				if best[a] == 0 or best[b] == 0:
					continue
				if art(plates[a], best[a]).intersects(art(plates[b], best[b])):
					var k: String = a if best[a] >= best[b] else b
					var idx := SIZES.find(best[k])
					best[k] = SIZES[idx + 1] if idx + 1 < SIZES.size() else 0
					changed = true
	var out := {}
	for id: String in ids:
		out[String(sites[id]["name"])] = best[id]
	return out
