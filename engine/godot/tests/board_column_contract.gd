extends SceneTree
const Quality = preload("res://core/map/board_quality.gd")
const Cleanup = preload("res://core/map/board_route_cleanup.gd")
var passed := 0
var failed := 0
func _initialize() -> void:
	for pair in [[4,3812116763],[4,122319638],[4,1795618768],[2,3812116763],[3,3812116763]]:
		print("COLUMN_CASE ",pair)
		var state := GameSetup.new_game(GameScreen.player_ids_for(pair[0]),pair[1])
		var drawing := BoardSchematic.build(state)
		verify(BoardSchematic._drawing_score(drawing,Quality.inspect(drawing)) == 0,"valid geometry: "+str(pair))
		verify(drawing.slots.size() == state.graph.slots.size(),"all troop spaces survive")
		if pair[0] == 4 and not drawing.fixed_sites.is_empty():
			verify(drawing.column_axes.size() == 5,"five explicit column axes")
			verify(Quality.layout_issues(drawing).is_empty(),"uniform columns and centred Web")
			var web: Array = drawing.sites["a:A3_site6"].rect
			verify(web[0]+web[2]*0.5 == drawing.size[0]*0.5,"Web has the exact board centre")
			verify(drawing.size[0]-8 <= 647 and drawing.size[1]-8 <= 316,"native 1:1 drawing fits the fixed UI")
			var drift := drawing.duplicate(true)
			drift.column_axes[1] += 2
			verify(Quality.layout_issues(drift).has("unequal_step"),"validator rejects unequal column spacing")
			drift = drawing.duplicate(true)
			drift.sites["a:A3_site6"].rect[0] += 2
			verify(Quality.layout_issues(drift).has("web_not_centred"),"validator rejects shifted Web")
		if pair == [4,3812116763]:
			var id := "corner180:B3_route0"
			verify(Cleanup._excess(Cleanup._joined(drawing,id,Cleanup._incident(drawing,id))) == 0,"reported hook is absent")
	print("column contract: passed=",passed,", failed=",failed)
	quit(1 if failed else 0)
func verify(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(message)
