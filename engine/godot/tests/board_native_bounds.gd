extends SceneTree
func _initialize() -> void:
	var failed := 0
	for item in [[2,1],[2,7],[2,42],[3,5],[3,9],[4,3],[4,11],[4,23]]:
		var state := GameSetup.new_game(GameScreen.player_ids_for(item[0]), item[1])
		var drawing := BoardSchematic.build(state)
		var sz: Array = drawing.size
		print("NATIVE_BOUNDS ",item," span=",sz[0]-8,"x",sz[1]-8)
		var panel := BoardPanel.new()
		panel.size = Vector2(647,322)
		panel._schematic_texture = ImageTexture.create_from_image(Image.create(sz[0],sz[1],false,Image.FORMAT_RGBA8))
		panel._ensure_view()
		var bounds := panel._board_rect()
		var drawn := Rect2(panel._to_screen(bounds.position), bounds.size)
		if not Rect2(Vector2.ZERO,panel.size).encloses(drawn): failed += 1
		panel.free()
	print("native bounds failed=",failed)
	quit(1 if failed else 0)
