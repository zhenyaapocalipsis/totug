extends SceneTree
const Repair = preload("res://core/map/board_route_repair.gd")
const Quality = preload("res://core/map/board_quality.gd")
var failed := 0
var passed := 0
func _init() -> void:
	var base := {"sites":{},"rings":{},"ports":{"p":[0,0]},"traces":[[0,0,30,0],[0,0,0,30]],"trace_ends":[["p","a"],["p","b"]]}
	verify(Quality.inspect(base)["crossings"] == 0,"legal shared junction")
	base["traces"] = [[0,0,30,0,30,30],[0,0,10,0,10,40]]
	verify(Quality.inspect(base)["crossings"] > 0,"shared endpoint does not allow crossings elsewhere")
	base["traces"] = [[0,0,30,0,30,30,10,30,10,-10]]
	base["trace_ends"] = [["p","a"]]
	verify(Quality.inspect(base)["crossings"] > 0,"self-loop crossing")
	var crossing := {"size":[32,24],"sites":{},"rings":{},"ports":{},"traces":[[2,8,28,8],[14,2,14,20]],"trace_ends":[["a","b"],["c","d"]]}
	var fixed := Repair.repair(crossing)
	verify(Quality.inspect(fixed)["crossings"] == 0,"repair removes a real crossing")
	verify(fixed["trace_ends"] == crossing["trace_ends"],"repair preserves graph ends")
	verify(fixed["traces"][0][0] == 2 and fixed["traces"][0][-2] == 28,"repair preserves attachment points")
	var split := {"sites":{"city":{"rect":[10,10,10,10]}},"rings":{},"ports":{"port":[15,20]},"traces":[[15,15,15,20],[15,20,15,30]],"trace_ends":[["city","port"],["port","other"]]}
	verify(Quality.inspect(split)["foreign_hits"] == 0,"legal split connection at city boundary")
	split["traces"][1] = [15,20,15,5]
	verify(Quality.inspect(split)["foreign_hits"] > 0,"shared port cannot excuse crossing a foreign city")
	var spacing := {"sites":{"city":{"rect":[10,10,10,10]}},"rings":{},"ports":{},"traces":[[8,5,8,25],[21,5,21,25]],"trace_ends":[["a","b"],["c","d"]]}
	verify(Quality.inspect(spacing)["foreign_hits"] == 0,"one empty pixel on either side of city")
	spacing["traces"] = [[9,5,9,25],[20,5,20,25]]
	verify(Quality.inspect(spacing)["foreign_hits"] == 2,"adjacent pixels without a gap are rejected")
	var joined := {"sites":{"a":{"rect":[0,0,10,10]},"b":{"rect":[20,0,10,10]}},"rings":{},"ports":{"p":[15,5]},"slots":{"a0":{"x":5,"y":5},"b0":{"x":25,"y":5}},"traces":[[15,5,5,5],[15,5,25,5]],"trace_ends":[["p","a"],["p","b"]]}
	var flat := Repair._flatten_ports(joined)
	verify(flat["trace_ends"] == [["a","b"]],"removing a drawing join preserves the actual graph link")
	verify(flat["slots"] == joined["slots"],"removing a drawing join preserves every troop slot")
	verify(flat["traces"] == [[5.0,5.0,25.0,5.0]] and Quality.inspect(flat)["crossings"] == 0,"merged road has no artificial bend or intersection")
	var board := BoardSchematic.new()
	var index := board._add_node("odd",BoardSchematic.Kind.SITE,"a",Vector2(20,20),Vector2(22,12))
	board._node_size[index] = Vector2(45,25)
	verify(board._node_rect(index).size == Vector2(45,25),"full odd-sized pixel bounds")
	for pair in [[4,23],[4,34],[4,61],[4,69],[4,83],[4,94],[4,130],[4,139],[4,156],[4,158],[4,226],[4,286],[4,1],[4,9],[4,108],[4,203],[4,205],[4,257],[4,96],[4,147],[4,300],[4,220],[2,30],[2,9],[2,13],[2,25],[3,25]]:
		var ids: Array[String] = []
		ids.assign(["red","blue","green","purple"].slice(0,pair[0]))
		print("REGRESSION ",pair)
		var state := GameSetup.new_game(ids,pair[1])
		var drawing := BoardSchematic.build(state)
		var quality := Quality.inspect(drawing)
		verify(BoardSchematic._quality_score(quality) == 0,"regression %s: %s" % [pair,quality])
		verify(_slots_match(drawing,state),"slot identities and coordinates %s" % [pair])
		verify(_links_match(drawing,state),"drawing preserves every actual game link %s" % [pair])
	print("board quality: passed=",passed,", failed=",failed)
	quit(1 if failed > 0 else 0)


func verify(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error(message)


func _slots_match(drawing: Dictionary, state: GameState) -> bool:
	if drawing["slots"].size() != state.graph.slots.size():
		return false
	for id: String in state.graph.slots:
		if not drawing["slots"].has(id):
			return false
	for id: String in drawing["rings"]:
		var p: Array = drawing["rings"][id]
		if drawing["slots"][id]["x"] != p[0] or drawing["slots"][id]["y"] != p[1]:
			return false
	for site: Dictionary in drawing["sites"].values():
		var r: Array = site["rect"]
		for id: String in site["slots"]:
			var p: Array = site["slots"][id]
			if drawing["slots"][id]["x"] != p[0] or drawing["slots"][id]["y"] != p[1]:
				return false
			if not Rect2(r[0],r[1],r[2],r[3]).has_point(Vector2(p[0],p[1])):
				return false
	return true


func _links_match(drawing: Dictionary, state: GameState) -> bool:
	var links := {}
	for pair: Array in drawing["trace_ends"]:
		links[str(pair[0])+"|"+str(pair[1])] = true
		links[str(pair[1])+"|"+str(pair[0])] = true
	for slot: String in state.graph.slots:
		var a: String = state.graph.site_of_slot(slot)
		if a.is_empty(): a = slot
		for other: String in state.graph.adjacent_slots(slot):
			var b: String = state.graph.site_of_slot(other)
			if b.is_empty(): b = other
			if a == b or links.has(a+"|"+b): continue
			var joined := false
			for port: String in drawing["ports"]:
				if links.has(a+"|"+port) and links.has(b+"|"+port): joined = true
			if not joined: return false
	return true
