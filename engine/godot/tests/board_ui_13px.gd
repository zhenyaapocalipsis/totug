extends SceneTree
const L10n := preload("res://scenes/localization.gd")
const Sites := preload("res://scenes/site_text.gd")
const Settings := preload("res://scenes/game_settings.gd")
const Quality := preload("res://core/map/board_quality.gd")
class GameRoot extends "res://scenes/ui/game_scene.gd":
	func _ready() -> void: pass
var passed := 0
var failed := 0
var shots := false
func check(ok: bool, why: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		printerr("FAIL: ",why)
func _initialize() -> void:
	Settings.path_override = "user://board_ui_13_settings.cfg"
	Settings._cfg = null
	PlayerProfile.path_override = "user://board_ui_13_profile.cfg"
	shots = OS.get_cmdline_user_args().has("--shots")
	_run.call_deferred()
func shot(name_value: String) -> void:
	if not shots or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../../Codex outputs/board_ui_13px_2026-11-24/"+name_value+".png")
func check_glyph_widths(panel: PlayersPanel) -> void:
	var labels: Array[Label] = []
	for item in panel._list.get_child(0).get_children():
		if item is Label: labels.append(item)
	for row: Dictionary in panel._rows.values():
		for value: Label in row.values.values(): labels.append(value)
	for label: Label in labels:
		var width := label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
		check(width <= label.size.x,"complete bitmap glyphs fit: "+label.text)

func _run() -> void:
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(Vector2i(1920,1080))
	L10n.set_locale("en")
	var legacy := PackedByteArray()
	legacy.resize(9*9*4)
	legacy[40*4] = 172
	legacy[40*4+1] = 50
	legacy[40*4+2] = 50
	legacy[40*4+3] = 255
	var migrated := PlayerProfile.clean_emblem(legacy.hex_encode())
	check(migrated.length() == 13*13*8,"legacy emblem upgrades to 13x13")
	check(PlayerProfile.emblem_pixels(migrated)[6*13+6].to_html(false) == "ac3232","legacy art stays centred without stretching")
	check(PlayerProfile.clean_emblem(migrated) == migrated,"emblem migration is idempotent")
	check(ReplayBook.same_rules(47),"old replay rules remain compatible")
	check(MarketPanel.TOKEN_PITCH == 14 and MarketPanel.TOKENS_PER_ROW*MarketPanel.TOKEN_PITCH-1 <= CardView.MINI_ART.w-2,"market troop markers use the new size and fit the card")
	var editor := ProfileScreen.new()
	root.add_child(editor)
	editor._show_tab("EMBLEM")
	editor.paint(10,6,Color.WHITE)
	check(PlayerProfile.emblem_pixels(editor.emblem())[6*13+10] == Color.WHITE,"new editor paints beyond the old 9x9 canvas")
	check(editor._previews[0].texture.get_size() == Vector2(13,13),"preview uses full troop image")
	for i in 8: await process_frame
	await shot("emblem-editor")
	editor.queue_free()
	L10n.set_locale("ru")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/board/site_data.json"))
	var accents := 0
	for tile: Array in source.values():
		for city: Dictionary in tile:
			if not Sites.short_name(city.name).contains("Й") and not Sites.short_name(city.name).contains("Ё"): continue
			for marker in [false,true]:
				var box := BoardSchematic.site_box(city.name,city.troop_slots.size(),marker)
				var spaces := {}
				var first := 10000
				for i in box.slots.size():
					var point: Vector2 = box.slots[i]
					spaces[str(i)] = [point.x,point.y]
					first = mini(first,int(point.y)-BoardSchematic.SLOT_R)
				var image := Image.create(box.w,box.h,false,Image.FORMAT_RGBA8)
				SchematicPainter._site(image,{"rect":[0,0,box.w,box.h],"name":city.name,"slots":spaces,"marker":marker,"vp":3})
				var last := 0
				for y in range(1,first):
					for x in range(1,int(box.w)-1):
						if image.get_pixel(x,y).is_equal_approx(SchematicPainter.INK): last = maxi(last,y)
				check(first-last >= 2,"one empty pixel below Russian caption: "+city.name)
				accents += 1
	check(accents > 0,"accented city names covered")
	L10n.set_locale("en")
	var host := GameRoot.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	host._start_game(GameScreen.player_ids_for(4),23,GameSetup.MODE_STANDARD,false,false,true)
	check(host._building and host.get_node_or_null("DealingOverlay") != null,"loading screen shown before board construction")
	var loading: Control = host.get_node("DealingOverlay")
	var start := Time.get_ticks_msec()
	var frames := 0
	var indicators := {}
	var captured := false
	while host._building and Time.get_ticks_msec()-start < 120000:
		await process_frame
		frames += 1
		if is_instance_valid(loading): indicators[loading._dots.text] = true
		if not captured and Time.get_ticks_msec()-start > 350:
			await shot("dealing")
			captured = true
	check(not host._building and frames > 10 and indicators.size() > 1,"board worker keeps frames and loading animation running")
	var screen: GameScreen
	for child in host.get_children():
		if child is GameScreen: screen = child
	check(screen != null,"prepared game replaces loading screen")
	if screen == null:
		host.queue_free()
		quit(1)
		return
	for i in 8: await process_frame
	check(screen.god and screen.board_data.seed == 23,"prepared God Mode game preserves seed and mode")
	for row: Dictionary in screen._players_panel._rows.values():
		var token: TextureRect = row.token
		check(token.texture.get_size() == Vector2(13,13) and token.size == Vector2(13,13),"table displays full 13x13 emblem")
		for value: Label in row.values.values():
			check(not token.get_global_rect().intersects(value.get_global_rect()),"emblem does not overlap numeric cell")
	print("RIGHT_LAYOUT players=",screen._players_panel.get_global_rect()," min=",screen._players_panel.get_combined_minimum_size()," market=",screen._market_panel.get_global_rect()," size=",screen.size)
	check(screen._players_panel.get_global_rect().end.y+GameScreen.GAP <= screen._market_panel.get_global_rect().position.y,"player table does not overlap market")
	check(Quality.inspect(screen.board_data.schematic).crossings == 0,"prepared board retains valid roads")
	if shots: await create_timer(1.3).timeout
	await shot("players-table")
	var crowded := screen._view.duplicate(true)
	for pid: String in screen.player_ids:
		var player: Dictionary = crowded.players[pid]
		player["trophies"] = {"white":39}
		for other: String in screen.player_ids:
			if other != pid: player.trophies[other] = 39
		for column: Array in PlayersPanel.COLUMNS: player[column[0]] = 39
	screen._players_panel.update_from_view(crowded)
	for i in 4: await process_frame
	for row: Dictionary in screen._players_panel._rows.values():
		for digit: Control in row.digits.values(): check(digit is Label,"four two-digit trophies retain the normal font")
		check(row.trophies.get_global_rect().end.x <= screen._players_panel.get_global_rect().end.x-1,"trophy counts remain inside player table")
	check_glyph_widths(screen._players_panel)
	await shot("players-table-crowded")
	screen._players_panel.update_from_view(screen._view)
	L10n.set_locale("ru")
	for i in 8: await process_frame
	check_glyph_widths(screen._players_panel)
	await shot("board-russian")
	seed(20261124)
	screen._god_panel._generate_button.pressed.emit()
	await process_frame
	check(host._building,"NEW BOARD button starts generation")
	start = Time.get_ticks_msec()
	while host._building and Time.get_ticks_msec()-start < 120000: await process_frame
	var next: GameScreen
	for child in host.get_children():
		if child is GameScreen and not child.is_queued_for_deletion(): next = child
	check(next != null and next.god and next.player_ids.size() == 4 and next.board_data.seed != 23,"regeneration produces a new seed and keeps God Mode settings")
	if next != null: check(not next.board_data.schematic.has("quality_issues"),"regenerated board passes geometry validation")
	host.queue_free()
	await process_frame
	print("board UI 13px: passed=",passed,", failed=",failed)
	quit(1 if failed else 0)
