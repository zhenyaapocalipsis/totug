extends SceneTree
const L10n := preload("res://scenes/localization.gd")
const Sites := preload("res://scenes/site_text.gd")
const Decisions := preload("res://scenes/decision_text.gd")
const Settings := preload("res://scenes/game_settings.gd")
var passed := 0
var failed := 0
func _initialize() -> void:
	Settings.path_override = "res://.godot/localization_board.cfg"
	Settings._cfg = null
	PlayerProfile.path_override = "res://.godot/localization_board_profile.cfg"
	_run.call_deferred()
func check(ok: bool, why: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		printerr("FAIL: ", why)
func _run() -> void:
	L10n.set_locale("en")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/board/site_data.json"))
	var originals := {}
	for tile: String in source:
		for site: Dictionary in source[tile]:
			originals[site.name] = true
			for marker in [false,true]:
				var box := BoardSchematic.site_box(site.name, site.troop_slots.size(), marker)
				check(PixelFont.text_width(String(Sites.translations()[site.name].short_name)) <= int(box.w) - 4, "caption fits original rectangle: " + site.name)
	check(Sites.translations().get("Blingdenstone", {}).get("name", "") == "Блингденстоун", "additional tutorial site covered")
	check(originals.size() == 45 and Sites.translations().size() >= originals.size(), "all 45 original site names covered")
	var screen := GameScreen.new(7,["drow","dragons"],["red","blue"])
	root.add_child(screen)
	screen.set_process(false)
	screen._decision_dialog.visible = false
	var board: BoardPanel = screen._board_panel
	for i in 4: await process_frame
	board.set_process(false)
	var schematic: Dictionary = screen.board_data.schematic
	var geometry := JSON.stringify(screen.board_data)
	var state := StateSerializer.to_json(screen.server.state,screen.viewer_id,screen.server.resolver.pending)
	var image_en := SchematicPainter.paint(schematic)
	var zoom := board._zoom
	var pan := board._pan
	var site_id := String(schematic.sites.keys()[0])
	var site: Dictionary = schematic.sites[site_id]
	var targets := board._focus.duplicate()
	var site_centres := {}
	for sid: String in schematic.sites:
		site_centres[sid] = board.site_global(sid)
	L10n.set_locale("ru")
	for i in 4: await process_frame
	board.set_process(false)
	check(JSON.stringify(screen.board_data) == geometry, "all site rectangles, troop positions, traces and board coordinates unchanged")
	check(StateSerializer.to_json(screen.server.state,screen.viewer_id,screen.server.resolver.pending) == state, "language does not change game state")
	check(board._zoom == zoom and board._pan == pan and board._focus == targets, "zoom, pan and target highlighting retained")
	for sid: String in site_centres:
		check(board.site_global(sid) == site_centres[sid], "same click/animation target: " + sid)
	var image_ru := SchematicPainter.paint(schematic)
	var changes := 0
	var outside := 0
	for y in image_en.get_height():
		for x in image_en.get_width():
			if image_en.get_pixel(x,y) == image_ru.get_pixel(x,y):
				continue
			changes += 1
			var header := false
			for item: Dictionary in schematic.sites.values():
				var r: Array = item.rect
				if Rect2i(int(r[0])+2,int(r[1])+2,int(r[2])-4,PixelFont.HEIGHT + BoardSchematic.NAME_GAP).has_point(Vector2i(x,y)):
					header = true
					break
			if not header:
				outside += 1
	check(changes > 0 and outside == 0, "only caption pixels change; frames, art, symbols, VP, troop circles and traces identical")
	check(board._site_hint(site_id,site).contains(site.name) and board._site_hint(site_id,site).contains(Sites.name_of(site.name).to_upper()), "full Russian name and English original in tooltip")
	check(Decisions.text("%s · space 2" % site.name) == "%s · место 2" % Sites.name_of(site.name), "decision target names translated without changing slot index")
	for original: String in originals:
		check(Sites.name_of(original) != original and Sites.short_name(original) != "", "translated full and short name: " + original)
	var saved_view := board._view
	board._view = saved_view.duplicate(true)
	var cluster := board._a2_sites()
	if cluster.size() == 3:
		board._view.site_control = {}
		board._view.site_total_control = []
		for sid: String in cluster: board._view.site_control[sid] = "red"
		check(board._a2_hint().contains("Красный — контроль всех трёх"), "A2 control tier translated")
		board._view.site_total_control = cluster
		check(board._a2_hint().contains("Красный — полный контроль всех трёх"), "A2 total control tier translated")
	PlayerProfile.seats = {"red": {"name":"VIEW BOARD"}}
	board._view.site_control[site_id] = "red"
	check(board._owner_hint(site_id).begins_with("VIEW BOARD:"), "literal nickname in board tooltip")
	PlayerProfile.seats = {}
	board._view = saved_view
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/localization_board_ru.png")
	L10n.set_locale("en")
	check(SchematicPainter.paint(schematic).get_data() == image_en.get_data(), "English board raster restored exactly")
	print("localized board: ",passed," checks, failed ",failed)
	quit(1 if failed else 0)
