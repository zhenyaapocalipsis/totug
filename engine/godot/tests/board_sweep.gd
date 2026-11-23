extends "res://tests/run_tests.gd"
const Quality = preload("res://core/map/board_quality.gd")

## Broad deterministic board geometry audit. --count=300 --start=1 --players=4
func _initialize() -> void:
	var count := 300
	var first := 1
	var players := 4
	var polish := true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="): count = int(arg.get_slice("=",1))
		elif arg.begins_with("--start="): first = int(arg.get_slice("=",1))
		elif arg.begins_with("--players="): players = int(arg.get_slice("=",1))
		elif arg == "--no-polish": polish = false
	var ids: Array[String] = []
	ids.assign(["red","blue","green","purple"].slice(0,players))
	var rows := []
	var bad := 0
	var grid_fallback := 0
	for seed_value in range(first,first+count):
		var state := GameSetup.new_game(ids,seed_value)
		print("BUILD_START ",players," ",seed_value)
		var started := Time.get_ticks_msec()
		var s := BoardSchematic.build(state,polish)
		var result := inspect(s)
		result["spacing"] = s.get("spacing",{})
		result["route_cleanup"] = s.get("route_cleanup",{})
		result.merge({"seed":seed_value,"players":players,"grid":s["grid"],"ms":Time.get_ticks_msec()-started,"rebuilt":s.get("quality_rebuilt",false)})
		rows.append(result)
		if not s["grid"]: grid_fallback += 1
		if result["overlaps"] > 0 or result["crossings"] > 0 or result["foreign_hits"] > 0 or result["ring_city_close"] > 0:
			bad += 1
			print("BAD ",result)
			if bad <= 12:
				FileAccess.open("res://../../engine/board-sweep-%d-%d.json" % [players,seed_value],FileAccess.WRITE).store_string(JSON.stringify(s))
		FileAccess.open("res://../../engine/board-sweep-results-%d-%d.json" % [players,first],FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
		if rows.size() % 10 == 0: print("PROGRESS ",players," ",rows.size(),"/",count," bad=",bad," fallback=",grid_fallback)
	FileAccess.open("res://../../engine/board-sweep-results-%d-%d.json" % [players,first],FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	print("SWEEP ",players," runs=",count," bad=",bad," fallback=",grid_fallback)
	quit(1 if bad > 0 else 0)

func inspect(s: Dictionary) -> Dictionary:
	var result := Quality.inspect(s,BoardSchematic.RING_R)
	var close := 0
	for p: Array in s["rings"].values():
		var ring := Rect2(p[0]-BoardSchematic.RING_R,p[1]-BoardSchematic.RING_R,BoardSchematic.RING_R*2+1,BoardSchematic.RING_R*2+1)
		for site: Dictionary in s["sites"].values():
			var r: Array = site["rect"]
			if ring.grow(2).intersects(Rect2(r[0],r[1],r[2],r[3])): close += 1
	result["ring_city_close"] = close
	return result
