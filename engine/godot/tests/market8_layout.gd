extends SceneTree

const L10n := preload("res://scenes/localization.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	for language in ["en", "ru"]:
		L10n.set_locale(language)
		for count in [2, 4]:
			var screen := GameScreen.new(7, [], GameScreen.player_ids_for(count))
			root.add_child(screen)
			for frame in 20:
				await process_frame
			var panel: MarketPanel = screen._market_panel
			check(panel._cards.size() == 8, "Eight visible market slots")
			check(screen._players_panel.size.y >= screen._players_panel.get_combined_minimum_size().y, "Player table fits")
			for card: CardView in panel._cards:
				check(card.size == CardView.MINI_SIZE, "Market face keeps native size")
			check(panel.get_global_rect().end.y < screen._end_turn_area.position.y, "Market stays above End Turn")
			check(not screen._pause_button.visible and not screen._menu_button.visible, "Side buttons removed")
			check(screen._timer_label.position.y < panel.position.y, "Timer above board")
			var supply: CardView = panel._supply_cards[0]
			supply._on_mouse_entered()
			await process_frame
			check(CardPreview.active.has_preview(), "Supply full preview appears")
			check(CardPreview.active._card.card_id == supply.card_id, "Preview is the right supply card")
			supply._on_mouse_exited()
			check(not CardPreview.active.has_preview(), "Supply preview closes")
			if language == "en":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://market8_%dp_en.png" % count)
			var selected: Array = []
			panel.supply_card_clicked.disconnect(screen._on_supply_clicked)
			panel.supply_card_clicked.connect(func(cid: String): selected.append(cid))
			supply.set_clickable(true)
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			supply._gui_input(click)
			check(selected == [supply.card_id], "Supply click reaches market signal")
			supply.set_clickable(false)
			supply._gui_input(click)
			check(selected.size() == 1 and supply.is_shaking(), "Unavailable supply refuses purchase")
			await process_frame
			screen.queue_free()
			await process_frame
	print("market8 layout failures: %d" % failures)
	quit(1 if failures else 0)
