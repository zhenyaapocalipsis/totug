extends "res://tests/run_tests.gd"

## Focused board checks, including the actual raster gap between troop spaces.
func _initialize() -> void:
	PlayerProfile.path_override = "user://profile_board_spacing_test.cfg"
	GameSettings.path_override = "user://settings_board_spacing_test.cfg"
	test_space_pixels()
	test_thin_trace()
	test_expanded_grid()
	test_board_schematic()
	test_player_profile()
	test_board_stock()
	print("board pixels: passed=%d, failed=%d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func test_space_pixels() -> void:
	section("Troop spaces: one free pixel and matching outlines")
	for count in range(1, 10):
		for marker: bool in [false, true]:
			var box := BoardSchematic.site_box("Wells of Darkness", count, marker)
			var slots := {}
			for i in count:
				var p: Vector2 = box["slots"][i]
				slots[str(i)] = [p.x, p.y]
			var city := {"rect": [0, 0, box["w"], box["h"]],
				"name": "Wells of Darkness", "vp": 3, "starting": false,
				"marker": marker, "slots": slots}
			var road := Vector2i(int(box["w"]) + 12, 12)
			var image := SchematicPainter.paint({"size": [road.x + 10, box["h"]],
				"sites": {"city": city}, "rings": {"road": [road.x, road.y]}})
			var fill := SchematicPainter.MARKER_FILL if marker else SchematicPainter.BOX_LIGHT
			var tag := "%d spaces, marker=%s" % [count, marker]
			for i in count:
				var p := Vector2i((box["slots"][i] as Vector2).round())
				check(p.x - 5 > 0 and p.x + 5 < int(box["w"]) - 1
					and p.y - 5 > 0 and p.y + 5 < int(box["h"]) - 1,
					"%s: circle stays inside its frame" % tag)
				if i % BoardSchematic.SLOT_COLS < BoardSchematic.SLOT_COLS - 1 and i + 1 < count:
					check(image.get_pixel(p.x + 6, p.y).is_equal_approx(fill),
						"%s: free pixel between columns" % tag)
				if i + BoardSchematic.SLOT_COLS < count:
					var below := Vector2i((box["slots"][i + BoardSchematic.SLOT_COLS] as Vector2).round())
					# A short last row can be centred between columns; test aligned rows.
					if p.x == below.x:
						check(image.get_pixel(p.x, p.y + 6).is_equal_approx(fill),
							"%s: free pixel between rows" % tag)
			var at := Vector2i((box["slots"][0] as Vector2).round())
			for dx in [5]:
				check(image.get_pixel(at.x + dx, at.y).is_equal_approx(SchematicPainter.INK)
					and image.get_pixel(road.x + dx, road.y).is_equal_approx(SchematicPainter.TRACE),
					"%s: city and road both have a one-pixel outline" % tag)
			check(image.get_pixel(at.x + 4, at.y).is_equal_approx(fill)
				and image.get_pixel(road.x + 4, road.y).is_equal_approx(image.get_pixel(road.x, road.y)),
				"%s: both outlines end after one pixel" % tag)


func test_thin_trace() -> void:
	var image := SchematicPainter.paint({"size": [32, 24], "traces": [[2, 12, 28, 12]]})
	check(image.get_pixel(15, 12).a > 0.9, "trace has one visible pixel")
	check(image.get_pixel(15, 11).a == 0.0 and image.get_pixel(15, 13).a == 0.0, "trace has no second pixel row")


func test_expanded_grid() -> void:
	for seed_value in [8, 17]:
		var state := GameSetup.new_game(["red", "blue", "green", "purple"], seed_value)
		var schematic := BoardSchematic.build(state)
		check(bool(schematic["grid"]), "expanded cities stay on grid, seed %d" % seed_value)
		var rects: Array[Rect2] = []
		for site: Dictionary in schematic["sites"].values():
			var r: Array = site["rect"]
			rects.append(Rect2(r[0], r[1], r[2], r[3]))
		var overlaps := 0
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				if rects[i].intersects(rects[j]):
					overlaps += 1
		check_eq(overlaps, 0, "expanded cities never overlap, seed %d" % seed_value)
		check_eq(_trace_crossings(schematic), 0, "expanded cities have no crossings, seed %d" % seed_value)
