extends SceneTree

const L10n := preload("res://scenes/localization.gd")
const Text := preload("res://scenes/card_text.gd")
const Settings := preload("res://scenes/game_settings.gd")
const IDS := ["48342", "48344", "48340", "48306", "48320", "48426", "48722", "49120"]
var passed := 0
var failed := 0


func _initialize() -> void:
	Settings.path_override = "res://.godot/localization_cards_test.cfg"
	Settings._cfg = null
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: ", description)


func _run() -> void:
	check(PixelFont.glyph("Й") != PixelFont.glyph("й"), "distinct Й and й")
	check(PixelFont.glyph("Й").slice(2) == PixelFont.glyph("И").slice(0, 7), "capital Й has full-height И body")
	check(PixelFont.y_offset("Й") == -2 and PixelFont.y_offset("й") == 0, "breve above capital body")
	var pending := PendingDecision.new()
	pending.player_id = "red"
	pending.prompt = "Сбросьте карту"
	pending.tag = "hand"
	pending.choice_type = "target_card"
	pending.legal_options = ["48342"]
	pending.data = {"presentation_action": "discard", "hand_slots": [0]}
	var public_view := StateView._decision_dict(pending, "blue")
	check(DecisionDialog.is_discard_choice(public_view), "discard style independent of translated prompt")
	check(public_view.data.is_empty() and public_view.legal_options.is_empty(), "public action does not reveal private choices")
	check(not DecisionDialog.is_discard_choice({"prompt": "Discard a card"}), "English wording does not determine action")
	var metrics := FileAccess.get_file_as_string("res://assets/font/pixel5.fnt")
	check(RegEx.create_from_string("char id=1049 .*yoffset=-2 ").search(metrics) != null, "BMFont capital bearing")
	for ch: String in "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ":
		check(PixelFontSmall.glyph(ch) != PixelFontSmall.FONT[" "], "small Cyrillic " + ch)
	var ids := {}
	for cid: String in CardLive.RULES:
		for rule: Array in CardLive.RULES[cid]:
			var id := CardLive.hint_id(cid, rule)
			check(not ids.has(id), "unique live identifier " + id)
			ids[id] = true
	L10n.set_locale("en")
	var originals := {}
	var mechanics := {}
	for cid: String in IDS:
		originals[cid] = CardView.pixel_texture(cid).get_image().get_data()
		mechanics[cid] = JSON.stringify(CardLibrary.card_data(cid))
	L10n.set_locale("ru")
	var sheet := Image.create(4 * 184, 2 * 350 + 36, false, Image.FORMAT_RGBA8)
	sheet.fill(PixelTheme.BG)
	PixelFont.draw_text(sheet, 8, 12, "ИЙй ЁЖЩЪ КРАСНЫЙ ДРАКОН / ПОЛНЫЙ ЭКРАН", PixelTheme.TEXT)
	for i in IDS.size():
		var cid: String = IDS[i]
		var full := CardView.pixel_texture(cid).get_image()
		var mini := CardView.mini_texture(cid).get_image()
		check(full.get_size() == Vector2i(176, 254) and mini.get_size() == Vector2i(58, 84), cid + " dimensions")
		check(not full.get_data() == originals[cid], cid + " translated face")
		check(JSON.stringify(CardLibrary.card_data(cid)) == mechanics[cid], cid + " unchanged rules data")
		var base := CardView.pixel_texture(cid, "", false).get_image()
		if base.is_compressed():
			base.decompress()
		base.convert(Image.FORMAT_RGBA8)
		check(full.get_region(Rect2i(10, 35, 150, 15)).get_data() == base.get_region(Rect2i(10, 35, 150, 15)).get_data(), cid + " artwork preserved")
		check(full.get_region(Rect2i(154, 235, 20, 17)).get_data() == base.get_region(Rect2i(154, 235, 20, 17)).get_data(), cid + " VP preserved")
		var box := CardLiveFace.text_layout(Text.ability(cid, true), [], 176, 254)
		check(box.top >= 34, cid + " text below header")
		for word: Array in box.words:
			check(word[0] + CardLiveFace.word_width(word[2]) <= 166, cid + " word fits")
		var origin := Vector2i((i % 4) * 184 + 4, (i / 4) * 350 + 36)
		sheet.blit_rect(full, Rect2i(Vector2i.ZERO, full.get_size()), origin)
		sheet.blit_rect(mini, Rect2i(Vector2i.ZERO, mini.get_size()), origin + Vector2i(0, 258))
	check(sheet.save_png("res://.godot/localization_cards_ru.png") == OK, "saved contact sheet")
	var note := {"id": "48320:need:inner_circle:4", "phrase": "irrelevant old phrase", "text": "(4/4)", "ok": true}
	var layout := CardLiveFace.layout(Text.ability("48320", true), [note])
	check(JSON.stringify(layout).contains("(4/4)") and not JSON.stringify(layout).contains("{LIVE:"), "stable anchor, independent of English phrase")
	var legacy := Text.notes("48320", [{"phrase": CardLive.RULES["48320"][0][0], "text": "(2/4)", "ok": false}])
	check(legacy[0].id == note.id, "legacy phrase upgraded at client edge")
	check(not Text.ability("48320").contains("{LIVE:"), "hidden markers not exposed as text")
	var discounted := CardLiveFace.full("49120", "", {"cost": 5, "notes": []})
	check(discounted != null, "Russian discounted face")
	var live_sheet := Image.create(3 * 184, 270, false, Image.FORMAT_RGBA8)
	live_sheet.fill(PixelTheme.BG)
	var examples := [
		["48320", {"notes": [note]}],
		["48426", {"notes": [{"id": "48426:per:sites_controlled_total:1", "text": "(+2)", "ok": true}]}],
		["49120", {"cost": 5, "notes": [
			{"id": "49120:less:outcasts_played", "text": "(-2)", "ok": true},
			{"id": "49120:per:spies_on_board:1", "text": "(+3)", "ok": true}]}]]
	for i in examples.size():
		var image := CardLiveFace.full(examples[i][0], "", examples[i][1]).get_image()
		live_sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(i * 184 + 4, 8))
	check(live_sheet.save_png("res://.godot/localization_live_ru.png") == OK, "saved live examples")
	var view := CardView.new("48426", 176, 254)
	view.set_live(false)
	check(view.tooltip_text.contains("Red Dragon"), "English original available")
	var russian_face: Texture2D = view._pixel
	L10n.set_locale("en")
	check(view._pixel != russian_face, "open card changes immediately to English")
	L10n.set_locale("ru")
	check(view._pixel == russian_face, "Russian cache reused after switch")
	view.free()
	var alt_base := AltArts.full_texture("48426_1")
	check(alt_base != null, "alternate art fixture")
	if alt_base != null:
		var alt := CardView.pixel_texture("48426", "48426_1").get_image()
		var raw_alt := alt_base.get_image()
		if raw_alt.is_compressed():
			raw_alt.decompress()
		raw_alt.convert(Image.FORMAT_RGBA8)
		check(alt.get_region(Rect2i(10, 35, 150, 15)).get_data() == raw_alt.get_region(Rect2i(10, 35, 150, 15)).get_data(), "alternate art preserved")
	for source: String in Text.OPTION_IDS:
		var option := OptionCard.new("48306", source)
		var english_source: String = option._source_text
		L10n.set_locale("en")
		var english_image: Texture2D = option._tex
		L10n.set_locale("ru")
		check(option._tex != english_image and option._source_text == english_source, "option changes presentation only")
		option.free()
	var spy_spots := CardLiveFace.keyword_spots("48722", [], 176, 254)
	check(spy_spots.any(func(spot): return spot[1] == "PLACE"), "spy keyword has spy tooltip")
	L10n.set_locale("en")
	for cid: String in IDS:
		check(CardView.pixel_texture(cid).get_image().get_data() == originals[cid], cid + " English raster unchanged")
	print("карты RU: пройдено %d, провалено %d" % [passed, failed])
	quit(1 if failed else 0)
