extends SceneTree
const L10n := preload("res://scenes/localization.gd")
var failed := 0
var passed := 0
var game_seed := 122319638
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): game_seed = int(arg.get_slice("=", 1))
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(message)
func settle() -> void:
	for i in 12: await process_frame
func run() -> void:
	for language in ["en", "ru"]:
		L10n.set_locale(language)
		for count in [2, 4]:
			var screen := GameScreen.new(game_seed, [], GameScreen.player_ids_for(count))
			root.add_child(screen)
			await settle()
			var panel := screen._board_panel
			panel._ensure_view()
			var zoom := panel._zoom
			check(zoom == 1.0, "Board always uses native 1:1 pixels")
			var centre := panel._view_centre()
			var rect := panel.get_global_rect()
			var world := panel._board_rect()
			var drawn := Rect2(panel.global_position + panel.local_of_world(world.position), world.size * zoom)
			check(rect.grow(1).encloses(drawn), "Whole generated board fits its fixed rectangle")
			check(screen._players_panel.get_global_rect().end.y + GameScreen.GAP <= screen._market_panel.global_position.y, "Players clear market")
			for pid: String in screen._players_panel._rows:
				var row: Dictionary = screen._players_panel._rows[pid]
				check(row.name.get_global_rect().end.y <= row.values.hand_size.global_position.y, "Name clears numeric row")
			screen._deploy_vp_button.show()
			screen._layout()
			check(panel.get_global_rect() == rect, "Empty barracks button keeps fixed board rectangle")
			screen._deploy_vp_button.hide()
			screen._layout()
			var view := screen._view.duplicate(true)
			var source := String(screen.server.state.players[screen.viewer_id].deck.hand[0])
			for kind in ["target_slot", "confirm", "choose", "target_card", "waiting", "none"]:
				var pd := {"player_id": screen.viewer_id, "source_card": source, "prompt": "Choose a target or skip this effect.", "choice_type": kind, "legal_options": [""], "tag": ""}
				if kind == "confirm": pd.legal_options = [true, false]
				if kind == "choose":
					pd.choice_type = "choose_option"
					pd.legal_options = [0, 1]
					pd.option_labels = ["+2 Power", "Place a spy"]
				if kind == "target_card": pd.legal_options = [source]
				if kind == "waiting": pd.player_id = screen.player_ids.filter(func(p): return p != screen.viewer_id)[0]
				view.pending_decision = {} if kind == "none" else pd
				screen.refresh(view)
				screen._turn_banner.hide()
				await settle()
				panel._ensure_view()
				check(is_equal_approx(zoom, panel._zoom) and centre.is_equal_approx(panel._view_centre()), "Question keeps board transform: " + kind)
				if screen._decision_dialog.visible and screen._decision_dialog.at_top:
					check(screen._decision_dialog.global_position.y >= rect.end.y, "Question clears fixed board: " + kind)
			# Full-size Choose one is a modal, with Hide returning to the lower strip.
			view.pending_decision = {"player_id": screen.viewer_id, "source_card": source, "prompt": "Choose one:", "choice_type": "choose_option", "legal_options": [0, 1], "option_labels": ["+2 Power", "Place a spy"]}
			screen.refresh(view)
			await settle()
			check(not screen._decision_dialog.at_top and screen._decision_dialog.find_children("*", "OptionCard", true, false).size() == 2, "Choose one keeps full-size option cards")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://fixed_choose_%s_%dp.png" % [language, count])
			screen._decision_dialog.toggle_cards()
			await settle()
			check(screen._decision_dialog.at_top and panel.get_global_rect() == rect, "Hide restores strip without moving board")
			view.pending_decision = {"player_id": screen.viewer_id, "source_card": source, "prompt": "You may promote a card from your hand.", "choice_type": "confirm", "legal_options": [true, false]}
			screen.refresh(view)
			screen._turn_banner.hide()
			await settle()
			var cards_top := screen._hand_panel.global_position.y + screen._hand_panel.size.y - HandPanel.BOTTOM_MARGIN - HandPanel.CARD_SIZE.y
			var resources := screen._res_frame.get_global_rect()
			check(resources.end.y <= cards_top - HandPanel.HOVER_LIFT, "Hovered card clears resources")
			check(is_equal_approx(cards_top - resources.end.y, resources.position.y - screen._decision_dialog.get_global_rect().end.y), "Resources have equal gaps above and below")
			var token_index := 0
			for slot_id: String in panel._slots():
				var at: Vector2 = panel._slot_world(slot_id)
				var texture_corner := panel._to_screen(at - Vector2.ONE * 6.5)
				check(panel._token_corner(panel._to_screen(at)).is_equal_approx(texture_corner), "Troop samples exactly the same grid as its circle")
			for site_id: String in screen.board_data.schematic.sites:
				var spy: Vector2 = panel._spy_spot(site_id, 0, 4)
				check(panel.global_position.y + spy.y - panel.spy_half() >= screen._end_turn_area.get_global_rect().end.y + 4, "Top spies clear End Turn")
				var members: Array = screen.board_data.sites[site_id].slots
				if not members.is_empty():
					view.troops[members[0]] = screen.player_ids[token_index % count]
					token_index += 1
				view.spies[site_id] = screen.player_ids.duplicate()
			screen.refresh(view)
			screen._turn_banner.hide()
			panel._shake_left = 0
			await settle()
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://fixed_layout_%s_%dp.png" % [language, count])
			view.pending_decision.prompt = "A long question with many words. ".repeat(30)
			screen.refresh(view)
			await settle()
			check(screen._decision_dialog.global_position.y >= rect.end.y, "Long question scrolls inside the strip")
			screen._decision_dialog.hide()
			screen._piles_window.show_decision({"tag": "explore", "source_card": source, "player_id": screen.viewer_id, "data": {"cards": [source, source, source, source], "take_left": 1}}, screen.viewer_id)
			await settle()
			check(screen._piles_window._frame.global_position.y >= rect.end.y, "Explore clears fixed board")
			check(screen._piles_window._frame.get_global_rect().end.x <= screen._board_area.get_global_rect().end.x, "Explore scrolls inside board column")
			screen._piles_window.close()
			var card := String(screen.server.state.players[screen.viewer_id].deck.hand[0])
			var flight := screen._launch_play(card, Rect2(), CardView.pixel_texture(card), false)
			for i in 24:
				await process_frame
				check(not panel.get_global_rect().intersects(flight.get_global_rect()), "Remote played card stays below board")
			flight.queue_free()
			screen.queue_free()
			await process_frame
	print("fixed layout: passed=", passed, ", failed=", failed)
	quit(1 if failed else 0)
