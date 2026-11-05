extends RefCounted

## Render semantic events locally; never write translated text to game state/replays.
const L10n := preload("res://scenes/localization.gd")
const GameText := preload("res://scenes/game_text.gd")
const CardText := preload("res://scenes/card_text.gd")
const SiteText := preload("res://scenes/site_text.gd")
const DecisionText := preload("res://scenes/decision_text.gd")

static func player_name(pid: String) -> String:
	return GameText.player_name(pid)

static func card_name(cid: String) -> String:
	var name := CardText.field(cid, "name")
	return name if name != "" else cid

static func site_name(sid: String, board: Dictionary) -> String:
	return SiteText.name_of(EventLogPanel.site_name(sid, board))

static func slot_place(slot: String, board: Dictionary) -> String:
	var slots: Dictionary = board.get("slots", {})
	if not slots.has(slot):
		return slot
	var sid := String(slots[slot].get("site_id", ""))
	return L10n.text("event.tunnel") if sid == "" else site_name(sid, board)

static func resource_name(source: String) -> String:
	var key := "event.resource_" + source.to_lower()
	return L10n.text(key) if L10n.catalog("en").has(key) else source

static func describe(e: Dictionary, board: Dictionary = {}) -> String:
	if L10n.locale() == "en":
		return EventLogPanel.describe(e, board)
	var who := player_name(String(e.get("player_id", "")))
	var amount := int(e.get("amount", 0))
	var card := card_name(String(e.get("card_id", "")))
	var slot := slot_place(String(e.get("slot_id", "?")), board)
	var site := site_name(String(e.get("site_id", "?")), board)
	match String(e.get("type", "")):
		"play_card":
			return L10n.text("event.play_card") % [who, card]
		"gain_power":
			return L10n.text("event.power") % [who, amount]
		"gain_influence":
			return L10n.text("event.influence") % [who, amount]
		"vp_income":
			var parts: Array[String] = []
			if int(e.get("markers", 0)) > 0:
				var marked: Array = e.get("marker_sites", [])
				parts.append(L10n.text("event.income_markers") % [
					int(e["markers"]), ", ".join(PackedStringArray(marked.map(func(s): return SiteText.name_of(String(s)))))])
			if int(e.get("cluster_bonus", 0)) > 0:
				parts.append(L10n.text("event.income_cluster") % int(e.get("cluster_bonus", 0)))
			if parts.is_empty():
				parts.append(L10n.text("event.unknown_source"))
			return L10n.text("event.income_end") % [
				who, int(e.get("granted", 0)), ", ".join(parts), int(e.get("total_vp", 0))]
		"gain_vp":
			return L10n.text("event.vp") % [who, amount]
		"gain_per_n":
			return L10n.text("event.gain_resource") % [who, amount, resource_name(String(e.get("resource", "")))]
		"bribe":
			return L10n.text("event.bribe") % [who, player_name(String(e.get("to", ""))), amount]
		"draw_cards":
			return L10n.text("event.draw_cards", {"who": who, "cards": GameText.card_count_message(amount)})
		"discard":
			return L10n.text("event.discard") % [who, card]
		"force_discard":
			return L10n.text("event.force_discard") % [who, card]
		"deploy_troop":
			return L10n.text("event.deploy_effect") % [who, slot]
		"place_spy":
			return L10n.text("event.place_spy") % [who, site]
		"move_troop":
			return L10n.text("event.move_troop") % [who,
				slot_place(String(e.get("from", "?")), board), slot_place(String(e.get("to", "?")), board)]
		"supplant":
			return L10n.text("event.supplant") % [who, player_name(String(e.get("victim", "?"))), slot]
		"return_troop":
			var owner := String(e.get("owner", ""))
			if owner == "":
				return L10n.text("event.return_troop_unknown") % [who, slot]
			return L10n.text("event.return_troop") % [who, player_name(owner), slot]
		"return_own_spy":
			return L10n.text("event.return_own_spy") % [who, site]
		"removed_to_supply":
			return L10n.text("event.removed_to_supply") % [who, card]
		"queued_end_of_turn":
			return L10n.text("event.queued_end") % who
		"ghost_recruit":
			return L10n.text("event.ghost_recruit") % [who, card]
		"ghost_market":
			return L10n.text("event.ghost_market") % who
		"put_deck_into_discard":
			return L10n.text("event.put_deck_discard") % who
		"assassinate":
			var victim := String(e.get("victim", ""))
			if victim == "":
				return L10n.text("event.assassinate_unknown") % [who, slot]
			return L10n.text("event.assassinate") % [who, player_name(victim), slot]
		"deploy":
			return L10n.text("event.deploy") % [who, slot]
		"recruit":
			if e.has("card_id"):
				return L10n.text("event.recruit") % [who, card]
			return L10n.text("event.recruit_index") % [who, e.get("market_index", "?")]
		"recruit_supply":
			return L10n.text("event.recruit") % [who, card]
		"recruit_free":
			return L10n.text("event.recruit_free") % [who, card]
		"return_spy":
			return L10n.text("event.return_spy") % [who, player_name(String(e.get("spy_owner", "?"))), site]
		"take_trophy":
			# Чей зал — главное, о чём спрашивали игроки: "у кого взяли войско".
			var hall := String(e.get("hall", ""))
			var colour := player_name(String(e.get("color", "?")))
			if hall == "":
				return L10n.text("event.trophy_unknown") % [who, colour]
			return L10n.text("event.trophy") % [who, colour, player_name(hall)]
		"choose_starting_site":
			return L10n.text("event.starting_site") % [who, site]
		"market_mulligan":
			var new_card := String(e.get("new_card_id", ""))
			return L10n.text("event.market_replace") % [who, card,
				card_name(new_card) if new_card != "" else L10n.text("event.nothing")]
		"market_mulligan_skip":
			return L10n.text("event.market_keep") % who
		"turn_income":
			var parts: Array[String] = []
			if int(e.get("a2_power", 0)) + int(e.get("a2_influence", 0)) > 0:
				parts.append(L10n.text("event.turn_cluster") % [int(e.get("a2_power", 0)), int(e.get("a2_influence", 0))])
			if int(e.get("marker_influence", 0)) > 0:
				parts.append(L10n.text("event.turn_markers") % int(e.get("marker_influence", 0)))
			return L10n.text("event.turn_income") % [who, "; ".join(parts)]
		"turn_ended":
			return L10n.text("event.turn_ended") % [who, L10n.text("event.over_suffix") if bool(e.get("game_over", false)) else ""]
		"promote":
			return L10n.text("event.promote") % [who, card]
		"devour":
			return L10n.text("event.devour") % [who, card]
		"game_abandoned":
			return L10n.text("event.abandoned") % who
		"give_insane_outcast":
			return L10n.text("event.insane_outcast") % [who, card_name(CardLibrary.INSANE_OUTCAST_ID), e.get("count", 1)]
		# Icewind Dale (New Era Freljord)
		"frostbite":
			var twice := "" if int(e.get("times", 1)) < 2 else L10n.text("event.twice")
			return L10n.text("event.frostbite") % [who, card, twice]
		"hill_giant_block":
			return L10n.text("event.hill_giant") % [who, card_name(FreljordCards.HILL_GIANT)]
		"discard_to_hand":
			return L10n.text("event.discard_to_hand") % [who, card]
		"reveal_hand":
			var shown: Array = e.get("cards", [])
			return L10n.text("event.reveal_hand") % [who, ", ".join(PackedStringArray(shown.map(func(c): return card_name(String(c)))))]
		"card_on_top":
			return L10n.text("event.card_top") % [who, card]
		# Calimshan (New Era Shurima)
		"devotion":
			return L10n.text("event.devotion") % [who, card]
		"ankheg_block":
			return L10n.text("event.ankheg_block") % [who, card_name(ShieldGuard.ANKHEG), DecisionText.text(String(e.get("what", L10n.text("event.it"))))]
		"name_card":
			return L10n.text("event.name_card") % [who, card]
		"inner_to_hand":
			return L10n.text("event.inner_to_hand") % [who, card]
		# Kara-Tur (New Era Ionia)
		"retain":
			if String(e.get("card_id", "")) == "":
				return L10n.text("event.retain_top") % who
			return L10n.text("event.retain") % [who, card]
		"oni_block":
			return L10n.text("event.oni_block") % [who, card_name(ShieldGuard.ONI), DecisionText.text(String(e.get("what", L10n.text("event.it"))))]
		"acorn":
			return L10n.text("event.acorn") % [who, int(e.get("total", 1))]
		"look_at_hand":
			return L10n.text("event.look_hand") % [who, player_name(String(e.get("target", "")))]
		# Feywild (New Era Bandle City)
		"glamour":
			return L10n.text("event.glamour") % who
		"market_discard":
			return L10n.text("event.market_discard") % [who, card]
		"board_vp":
			return L10n.text("event.board_vp") % [who, player_name(String(e.get("owner", ""))), site]
		"board_vp_claim":
			return L10n.text("event.board_vp_claim") % [who, site]
		# Far Realm (New Era Void)
		"devour_hex":
			return L10n.text("event.devour_hex") % [
				who, site, int(e.get("taken", 0)), int(e.get("returned", 0))]
		"evolve":
			return L10n.text("event.evolve") % [who, card_name(VoidCards.KHAZIX), L10n.text("event.evolution_" + String(e.get("ability", "")))]
		"set_aside":
			return L10n.text("event.set_aside") % [who, card, card_name(VoidCards.VELKOZ)]
		"set_aside_play":
			return L10n.text("event.set_aside_play") % [who, card]
		"reveal_top":
			return L10n.text("event.reveal_top") % [who, card]
		"market_reveal":
			return L10n.text("event.market_reveal") % who
		"rival_play":
			return L10n.text("event.rival_play") % [who, card, player_name(String(e.get("rival", "")))]
		"brute_reveal", "sylgar":
			return L10n.text("event.reveal_vp") % [who, card, int(e.get("amount", 0))]
		"steal_vp":
			return L10n.text("event.steal_vp") % [who, int(e.get("amount", 0)), player_name(String(e.get("from", "")))]
		"play_free":
			return L10n.text("event.play_free") % [who, card]
		"market_spy":
			return L10n.text("event.market_spy") % [who, card]
		# Chult (New Era Ixtal)
		"explore":
			return L10n.text("event.explore") % [who, int(e.get("looked", 2)), DecisionText.text(String(e.get("what", "a card")))]
		"explore_take":
			return L10n.text("event.explore_take") % [who, card]
		"copy_card":
			return L10n.text("event.copy_card") % [who, card]
		"marker_again":
			return L10n.text("event.marker_again") % [who, site]
		"market_troop":
			return L10n.text("event.market_troop") % [who, card]
		"shuffle_discard":
			return L10n.text("event.shuffle_discard") % who
		"extra_turn":
			if int(e.get("cards", 0)) > 0:
				return L10n.text("event.extra_turn_limit") % [who, int(e.get("cards", 0))]
			return L10n.text("event.extra_turn") % who
		_:
			var kind := String(e.get("type", "?"))
			var key := "event.type_" + kind
			return L10n.text("event.fallback") % [who, L10n.text(key) if L10n.catalog("en").has(key) else kind]
