extends "res://tests/board_pixel_spacing.gd"

func _initialize() -> void:
	test_space_pixels()
	test_thin_trace()
	var token := SchematicPainter.token(Color.RED)
	check_eq(token.get_width(),13,"troop width is exactly 13 pixels")
	check_eq(token.get_height(),13,"troop height is exactly 13 pixels")
	check_eq(BoardSchematic.SLOT_PITCH,14,"13 pixel spaces have a one-pixel gap")
	var box := BoardSchematic.site_box("TEST",6,false)
	check(int(box["h"]) >= 40,"two-row city grows to fit 13 pixel troops")
	var emblem: Array[Color] = []
	emblem.resize(PlayerProfile.SIZE*PlayerProfile.SIZE)
	emblem.fill(Color.TRANSPARENT)
	emblem[4*PlayerProfile.SIZE+3] = Color.WHITE
	var saved := PlayerProfile.emblem_from_pixels(emblem)
	var marked := SchematicPainter.token(Color.RED,saved)
	check(marked.get_pixel(5,6) == Color.WHITE,"saved 9 pixel emblem is centred inside 13 pixel troop")
	print("board13 pixels: passed=",_passed,", failed=",_failed)
	quit(1 if _failed > 0 else 0)
