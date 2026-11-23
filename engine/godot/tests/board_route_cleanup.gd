extends SceneTree

const Cleanup = preload("res://core/map/board_route_cleanup.gd")
const Spacing = preload("res://core/map/board_spacing.gd")
var passed := 0
var failed := 0

func _init() -> void:
	var u := {"size":[120,100],"sites":{},"rings":{},"slots":{},
		"ports":{"a":[20,20],"b":[80,20]},"trace_ends":[["a","b"]],
		"traces":[[20,20,20,60,60,60,60,20,80,20]]}
	var original := u.duplicate(true)
	var direct := Cleanup.simplify(u)
	verify(direct["traces"][0] == [20,20,80,20],"empty-space U bend becomes a straight road")
	verify(direct["trace_ends"] == original["trace_ends"] and direct["ports"] == original["ports"],"connections and hex ports stay intact")
	verify(Spacing._valid(direct),"straightened route is valid")
	var blocked := original.duplicate(true)
	blocked["sites"] = {"obstacle":{"rect":[40,0,20,50]}}
	blocked["traces"] = [[20,20,20,60,80,60,80,20]]
	var around := Cleanup.simplify(blocked)
	verify(Cleanup._excess(around["traces"][0]) > 0,"necessary obstacle detour stays")
	verify(Spacing._valid(around),"obstacle detour stays outside foreign city")
	var bump := {"size":[120,100],"sites":{"city":{"rect":[10,20,30,24],"slots":{"unit":[20,36]}}},
		"rings":{"ring":[70,10]},"slots":{"ring":{"x":70,"y":10},"unit":{"x":20,"y":36}},
		"ports":{"p":[100,70]},"trace_ends":[["city","ring"],["ring","p"]],
		"traces":[[39,32,70,32,70,10],[70,10,100,10,100,70]]}
	var saved := bump.duplicate(true)
	var flat := Cleanup.simplify(bump)
	verify(flat["rings"]["ring"] != saved["rings"]["ring"],"ring moves onto the shorter road")
	verify(Cleanup.inspect(flat)["detour"] == 0,"marker no longer forces a spike")
	verify(flat["trace_ends"] == saved["trace_ends"],"moving a ring preserves logical links")
	verify(flat["slots"]["ring"]["x"] == flat["rings"]["ring"][0] and flat["slots"]["ring"]["y"] == flat["rings"]["ring"][1],"troop hit target follows relocated ring")
	verify(flat["slots"].size() == saved["slots"].size() and Spacing._valid(flat),"all troop spaces survive with valid geometry")
	verify(Spacing.inspect(flat)["score"] <= Spacing.inspect(saved)["score"],"clearance does not get worse")
	var touching := {"size":[30,30],"sites":{"city":{"rect":[5,5,20,20],"slots":{}}},"rings":{},"slots":{},"ports":{"a":[10,5],"b":[10,0]},"traces":[[10,5,10,15],[10,0,10,5]],"trace_ends":[["a","city"],["b","a"]]}
	verify(Spacing._reroute(touching,[0],true) and touching["traces"][0].size() >= 4,"port on city boundary keeps a complete trace")
	var started := Time.get_ticks_msec()
	var state := GameSetup.new_game(["red","blue","green","purple"],23)
	var s := BoardSchematic.build(state)
	verify(Cleanup._excess(s["traces"][41]) == 0,"marked Menzoberranzan U bend is removed")
	for id: String in ["c_n2:C4_route2","c_n2:C4_route3"]:
		verify(Cleanup._excess(Cleanup._joined(s,id,Cleanup._incident(s,id))) == 0,"marked Caer Sidi spike is removed: "+id+" "+str(Cleanup._joined(s,id,Cleanup._incident(s,id))))
	verify(Spacing._valid(s),"seed 23 has no crossings, overlaps or foreign city hits")
	verify(s["slots"].size() == state.graph.slots.size(),"seed 23 keeps every troop space")
	var pair_a: Array = s["rings"]["c_s2:C3_route0"]
	var pair_b: Array = s["rings"]["c_s3:C6_route3"]
	verify(pair_a[0] == pair_b[0],"Black Gate ring pair stays vertically aligned")
	var straight := true
	for edge in [66,67]:
		var path: Array = s["traces"][edge]
		for x in range(0,path.size(),2):
			if path[x] != pair_a[0]: straight = false
	verify(straight,"Black Gate pair keeps the straight shared road")
	verify(Cleanup._bad_entries(s,62) == 0,"Magma has a normal straight entry")
	verify(Cleanup._bad_entries(s,2) == 0,"Black Gate entry does not hug its corner")
	verify(int(StateView.board_snapshot(state,s)["seed"]) == 23,"board snapshot exposes its reproducible seed")
	print("CLEANUP seed23 ",s["route_cleanup"]," ms=",Time.get_ticks_msec()-started)
	print("board route cleanup: passed=",passed,", failed=",failed)
	quit(1 if failed > 0 else 0)


func verify(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error(message)
