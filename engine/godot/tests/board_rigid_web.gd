extends SceneTree
const Q = preload("res://core/map/board_quality.gd")
var passed := 0
var failed := 0
class PixelPanel extends BoardPanel:
	func window_scale() -> float: return 2.0
	func _board_rect() -> Rect2: return Rect2(0,0,646,352)
	func _fit_zoom() -> float: return 1.0
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(message)
func _init() -> void:
	var offsets := {"A3_site6":Vector2.ZERO,"A3_site0":Vector2(-20,-34),"A3_site1":Vector2(20,-34),"A3_site4":Vector2(50,0),"A3_site5":Vector2(20,34),"A3_site3":Vector2(-20,34),"A3_site2":Vector2(-50,0)}
	for seed_value in [1795524757,1795524668]:
		var state := GameSetup.new_game(["red","blue","green","purple"],seed_value)
		var s := BoardSchematic.build(state)
		check(s.get("grid",false) and not s.has("quality_issues"),"reported seed must have an accepted grid")
		check(BoardSchematic._quality_score(Q.inspect(s)) == 0,"reported seed has valid geometry")
		check(s.get("fixed_sites",[]).size() == 7,"all seven Web cities are fixed")
		var centre: Array = s["sites"]["a:A3_site6"]["rect"]
		var origin := Vector2(centre[0]+floorf(centre[2]/2),centre[1]+floorf(centre[3]/2))
		for id: String in offsets:
			var r: Array = s["sites"]["a:"+id]["rect"]
			check(offsets.values().has(Vector2(r[0]+floorf(r[2]/2),r[1]+floorf(r[3]/2))-origin),"Web city stays in one of the fixed template positions: "+id)
		check(preload("res://core/map/board_spacing.gd")._move(s,"a:A3_site0",Vector2(12,0)).is_empty(),"optimizer cannot move one Web city")
		check(s["slots"].size() == state.graph.slots.size(),"all troop slots remain present")
	var panel := PixelPanel.new()
	panel.size = Vector2(655,456)
	panel._ensure_view()
	check(is_equal_approx(panel._zoom*2,roundf(panel._zoom*2)),"fixed board viewport preserves whole physical pixels")
	panel._board = {"seed":123,"schematic":{"quality_issues":{"crossings":1}}}
	panel._rebuild_schematic_texture()
	check(panel._schematic_texture == null and panel._schematic_error.contains("123"),"invalid board is rejected before painting")
	panel._board = {"seed":456,"schematic":{"grid":false}}
	panel._rebuild_schematic_texture()
	check(panel._schematic_texture == null and panel._schematic_error.contains("456"),"legacy non-grid drawing is also rejected")
	panel.free()
	print("rigid web: passed=",passed,", failed=",failed)
	quit(1 if failed > 0 else 0)
