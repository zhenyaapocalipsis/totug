extends SceneTree

const Spacing = preload("res://core/map/board_spacing.gd")
const Quality = preload("res://core/map/board_quality.gd")
var passed := 0
var failed := 0

func _init() -> void:
	var source := {"size":[120,100],"sites":{},"rings":{"ring":[60,40]},
		"slots":{"ring":{"x":60,"y":40}},"ports":{"left":[20,40],"up":[68,5],"down":[68,95]},
		"traces":[[20,40,60,40],[68,5,68,95]],"trace_ends":[["left","ring"],["up","down"]]}
	var original := source.duplicate(true)
	verify(Quality.inspect(source)["crossings"] == 0,"near miss is topologically valid")
	verify(Spacing.inspect(source)["score"] > 0,"near miss is visually ambiguous")
	var fixed := Spacing.optimise(source)
	verify(fixed["spacing"]["after"] < fixed["spacing"]["before"],"spacing objective improves")
	verify(fixed["rings"]["ring"] != original["rings"]["ring"],"crowded ring actually moves")
	verify(fixed["trace_ends"] == original["trace_ends"],"logical connections stay unchanged")
	verify(fixed["slots"]["ring"]["x"] == fixed["rings"]["ring"][0] and fixed["slots"]["ring"]["y"] == fixed["rings"]["ring"][1],"troop and hit target follow the ring")
	verify(Spacing._valid(fixed),"spacing does not introduce geometry defects")
	verify(source["rings"] == original["rings"],"candidate search preserves input coordinates")
	var legend_board := {"size":[120,100],"a2_legend":[50,30,20,20],"sites":{},"rings":{"ring":[20,20]},"slots":{"ring":{"x":20,"y":20}},"ports":{"a":[10,40],"b":[100,40]},"traces":[[10,40,100,40]],"trace_ends":[["a","b"]]}
	verify(not Spacing._fits(legend_board,"ring",Rect2(52,32,11,11)),"moved nodes cannot cover A2 legend")
	var routed := Spacing._reroute(legend_board,[0])
	var clear := routed
	var path: Array = legend_board["traces"][0]
	for k in range(0,path.size()-2,2):
		var a := Vector2(path[k],path[k+1])
		var b := Vector2(path[k+2],path[k+3])
		if Rect2(a.min(b),(a-b).abs()+Vector2.ONE).intersects(Rect2(50,30,20,20)):
			clear = false
	verify(clear,"rerouted roads avoid A2 legend")
	var state := GameSetup.new_game(["red","blue","green","purple"],23)
	var started := Time.get_ticks_msec()
	var drawing := BoardSchematic.build(state)
	var metric := Spacing.inspect(drawing)
	verify(drawing["spacing"]["after"] < drawing["spacing"]["before"] / 4,"Caer Sidi board is substantially less crowded")
	verify(not metric["bad_traces"].has(11) and not metric["bad_traces"].has(38) and not metric["bad_traces"].has(39),"marked roads have clear gutters")
	verify(Spacing._valid(drawing),"Caer Sidi keeps all geometry constraints")
	verify(drawing["slots"].size() == state.graph.slots.size(),"all troop spaces remain present")
	print("SPACING seed23 ",drawing["spacing"]," ms=",Time.get_ticks_msec()-started)
	print("board spacing: passed=",passed,", failed=",failed)
	quit(1 if failed > 0 else 0)


func verify(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error(message)
