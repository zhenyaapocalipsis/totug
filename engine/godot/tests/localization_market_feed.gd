extends SceneTree
const L10n := preload("res://scenes/localization.gd")
const Settings := preload("res://scenes/game_settings.gd")
var passed := 0
var failed := 0
func _initialize() -> void:
	Settings.path_override = "res://.godot/localization_market_feed.cfg"
	Settings._cfg = null
	PlayerProfile.path_override = "res://.godot/localization_market_feed_profile.cfg"
	_run.call_deferred()
func check(ok: bool, why: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		printerr("FAIL: ", why)
func _run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(960, 540))
	L10n.set_locale("en")
	var screen := GameScreen.new(7, ["drow", "dragons"], ["red", "blue"])
	root.add_child(screen)
	screen.set_process(false)
	var guard := 0
	while screen.server.resolver.is_waiting() and guard < 20:
		guard += 1
		var pd: PendingDecision = screen.server.resolver.pending
		screen.server.apply_intent(Intent.make_decision(pd.player_id, pd.legal_options[0]))
	PlayerProfile.seats = {"red": {"name": "START"}, "blue": {"name": "Watcher"}}
	var pid := screen.server.state.current_player()
	var view := StateView.for_player_with_pending(screen.server.state, pid, screen.server.resolver.pending)
	view.market_spies = {0: "blue"}
	view.market_troops = {1: {"red": 2}}
	view.market.display[5] = ""
	screen.viewer_id = pid
	screen.refresh(view)
	var market := screen._market_panel
	market.set_half_decks(["drow", "drow", "dragons"])
	var feed := screen._feed
	feed.clear()
	feed.add_mulligan("red", "", "")
	feed.add_played("red", "48306")
	feed.add("red", "48320", "BOUGHT")
	var place := "site:" + str(screen.board_data.sites.keys()[0])
	feed.add_stat("red", "kill", 3, "blue", [place])
	feed.add_stat("red", "supplant", 2, "green", [place])
	feed.add_stat("red", "vp", 12)
	await create_timer(1.6).timeout
	for i in 4: await process_frame
	feed.set_process(false)
	feed._scroll.scroll_vertical = 0
	var block: TurnFeed.Block = feed._blocks.back()
	feed._hover_row(block, "kill", true)
	var hovered := feed._hovered.duplicate()
	var pin := feed._pin_frames
	var scroll := feed._scroll.scroll_vertical
	var block_id := block.get_instance_id()
	var card_ids := (block.groups.PLAYED as Control).get_children().map(func(c): return c.get_instance_id())
	var dots := (block._rows.kill[1] as Control).get_children().map(func(c): return c.get_instance_id())
	var market_ids := market._cards.map(func(c): return c.get_instance_id() if c != null else 0)
	var market_state := market._cards.map(func(c): return [c.card_id, c.cost_now, c.clickable] if c != null else [])
	var before := JSON.stringify(view)
	var state_before := StateSerializer.to_json(screen.server.state, pid, screen.server.resolver.pending)
	var hover_events: Array = []
	feed.places_hovered.connect(func(p): hover_events.append(p))
	L10n.set_locale("ru")
	check(market._title.text == "РЫНОК" and market._deck_label.text.begins_with("КОЛОДА "), "market headings translated")
	check(market._title.tooltip_text == "Полуколоды рынка:\nДРОУ ×2\nДРАКОНЫ", "market composition, order and multiplicity")
	check(market._cards.map(func(c): return c.get_instance_id() if c != null else 0) == market_ids and market._cards.map(func(c): return [c.card_id, c.cost_now, c.clickable] if c != null else []) == market_state, "market controls, costs and legal clicks preserved")
	check(market._boxes[0].get_node("MarketSpy").tooltip_text.contains("Watcher") and market._boxes[0].get_node("MarketSpy").tooltip_text.contains("3 силы"), "spy owner literal and surcharge translated")
	check(market._boxes[1].get_node("MarketTroops").get_meta("owners") == ["red", "red"] and market._boxes[1].get_node("MarketTroops").tooltip_text.contains("удешевляет"), "troop markers and price explanation preserved")
	check(feed.last_block_tags() == ["PLAYED", "BOUGHT"] and block._labels.PLAYED.text == "СЫГРАНО 1" and block._labels.BOUGHT.text == "НАНЯТО 1", "stable group keys and translated labels")
	check(block.get_instance_id() == block_id and (block.groups.PLAYED as Control).get_children().map(func(c): return c.get_instance_id()) == card_ids and (block._rows.kill[1] as Control).get_children().map(func(c): return c.get_instance_id()) == dots, "feed blocks, cards and colour dots preserved")
	check(feed.last_stat("kill") == 3 and feed.last_places("kill") == [place] and feed._hovered == hovered and hover_events.is_empty(), "counts, places and hovered row preserved")
	check(feed._scroll.scroll_vertical == scroll and feed._pin_frames == pin, "history scroll does not jump")
	check(block._rows.kill[0].text == "УНЧ. 3" and block.row("kill").tooltip_text == "Уничтожено войск: 3" and feed._blocks[0].title.tooltip_text.contains("ЗАМЕНА"), "action and mulligan explanations translated")
	check(JSON.stringify(view) == before and StateSerializer.to_json(screen.server.state, pid, screen.server.resolver.pending) == state_before, "view and real game state unchanged")
	if DisplayServer.get_name() != "headless":
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/localization_market_feed_ru.png")
	L10n.set_locale("en")
	check(block._labels.PLAYED.text == "PLAYED 1" and block._rows.kill[0].text == "KILL 3" and market._title.tooltip_text == "Market half-decks:\nDROW ×2\nDRAGONS", "English presentation restored")
	for key: String in TurnFeed.STATS:
		check(L10n.catalog("en").has("feed.stat_" + key) and L10n.catalog("ru").has("feed.tip_" + key), "action coverage " + key)
	screen.hide()
	var choice_market := MarketPanel.new()
	choice_market.theme = PixelTheme.theme()
	root.add_child(choice_market)
	var choosing := view.duplicate(true)
	choosing.pending_decision = {"tag": "market", "legal_options": [1]}
	choice_market.update_from_view(choosing)
	var answers: Array = []
	choice_market.choice_clicked.connect(func(i): answers.append(i))
	L10n.set_locale("ru")
	check(choice_market._choosing and choice_market._cards[1].clickable and not choice_market._cards[0].clickable and answers.is_empty(), "market choice legality preserved")
	choice_market._cards[1].pressed.emit(choice_market._cards[1].card_id)
	check(answers == [1], "market answer keeps original slot index")
	choice_market.free()
	var hand := HandPanel.new()
	hand.theme = PixelTheme.theme()
	hand.size = Vector2(600, 100)
	root.add_child(hand)
	var hv := {"players": {"red": {"hand": ["48306"], "discard_pile": ["48320"], "set_aside": ["49120"]}}, "legal": {},
		"pending_decision": {"player_id": "red", "tag": "hand_or_discard", "legal_options": ["48306", "48320"]}}
	hand.update_from_view(hv, "red")
	hand.set_process(false)
	hand._hovered_card = hand._cards[0]
	var ids := hand._cards.map(func(c): return c.get_instance_id())
	var positions := hand._pos.duplicate()
	var velocities := hand._vel.duplicate()
	var aside_id := hand._aside[0].get_instance_id()
	var hand_answers: Array = []
	hand.choice_clicked.connect(func(id): hand_answers.append(id))
	L10n.set_locale("en")
	L10n.set_locale("ru")
	check(hand._cards.map(func(c): return c.get_instance_id()) == ids and hand._pos == positions and hand._vel == velocities and hand._hovered_card == hand._cards[0] and hand._both and hand._choosing, "hand selection, hover and spring positions preserved")
	check(hand._label.tr(hand._label.text) == "СБРОС" and hand._aside[0].get_instance_id() == aside_id and hand._aside[0].tooltip_text.contains("в начале каждого вашего хода"), "hand zone and set-aside description translated")
	hand._cards[1].pressed.emit("48320")
	check(hand_answers == ["discard:48320"], "zone-qualified card ID preserved")
	hand.free()
	screen.free()
	await process_frame
	PlayerProfile.seats = {}
	L10n.set_locale("en")
	print("market/feed localization: passed %d, failed %d" % [passed, failed])
	quit(1 if failed else 0)
