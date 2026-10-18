extends SceneTree

## Аудит карт New Era: каждая карта колоды (и её жетоны) разыгрывается в
## настоящей партии через GameServer, на вопросы отвечает автоответчик, в
## консоль идут текст карты, заданные вопросы и что изменилось (ресурсы,
## руки, войска, шпионы, рынок, журнал) — после розыгрыша, в конце хода и в
## начале следующего хода. Сверка с текстом карты — глазами.
##   DECKS="ixtal void" Godot --headless --path engine/godot --script res://tools/new_era/card_audit.gd
## LAST=1 — второй проход: в вопросах выбирается последний вариант, confirm=false.
## IDS="50101 50102" — только эти карты.

const NOISE := ["draw", "draw_card", "shuffle", "end_turn", "start_turn", "turn_start", "play_card"]

var _last := false


func _initialize() -> void:
	_last = OS.get_environment("LAST") == "1"
	var decks: Array = Array(OS.get_environment("DECKS").split(" ", false))
	if decks.is_empty():
		decks = Array(GameSetup.NEW_ERA_DECKS)
	var only: Array = Array(OS.get_environment("IDS").split(" ", false))
	for deck: String in decks:
		_audit_deck(deck, only)
	quit()


func _audit_deck(deck: String, only: Array) -> void:
	var cards := GameSetup.expand_half_deck(deck)
	var uniq: Array[String] = []
	for cid: String in cards:
		if not uniq.has(cid):
			uniq.append(cid)
	var prefix: int = uniq[0].to_int() / 100
	var extra: Array[String] = []
	for cid: String in CardLibrary.all_ids():
		var n := cid.to_int()
		if (n / 100 == prefix or (prefix == 496 and n >= 49634 and n <= 49636)) and not uniq.has(cid):
			extra.append(cid)
	extra.sort()
	print("\n==================== DECK ", deck, " (", cards.size(), " cards, ", uniq.size(), " unique; outside market: ", extra.size(), ")")
	var all: Array[String] = uniq.duplicate()
	all.sort_custom(func(a, b): return a.to_int() < b.to_int())
	all.append_array(extra)
	for cid: String in all:
		if not only.is_empty() and not only.has(cid):
			continue
		_audit_card(deck, cid, cards.count(cid), uniq)


func _nm(cid: String) -> String:
	if cid == "":
		return "-"
	var d := CardLibrary.card_data(cid)
	if d.is_empty():
		return cid
	return String(d.get("name", cid))


func _audit_card(deck: String, cid: String, copies: int, deck_cards: Array[String]) -> void:
	var d := CardLibrary.card_data(cid)
	var text := String(d.get("ability_text", "")).replace("\n", " ")
	print("\n--- #", cid, " ", d.get("name"), " [cost ", d.get("cost"), ", ", d.get("aspect"), ", vp ",
		d.get("deck_vp"), "/", d.get("inner_circle_vp"), "] x", copies, (" (NOT IN MARKET)" if copies == 0 else ""))
	print("    TEXT: ", text)
	var partner := "shadow" if deck == "celestial" else "celestial"
	var mode := GameSetup.new_era_mode([deck, partner])
	var state := GameSetup.new_game(["red", "blue", "green"] as Array[String], 4242, [], false, false, false, mode)
	var server := GameServer.new(state, false)
	if server.resolver.is_waiting():
		_answer_all(server, [])
	_prepare(state, cid, deck_cards)
	var before := _snap(state)
	var res := server.apply_intent(Intent.play_card("red", cid))
	if int(res["error"]) != 0:
		print("    !! PLAY REFUSED, error ", res["error"])
		return
	var events: Array = res["events"].duplicate()
	_answer_all(server, events)
	print("    EVENTS: ", _events(events))
	_print_diff(before, _snap(state), state)

	# конец хода
	before = _snap(state)
	res = server.apply_intent(Intent.end_turn("red"))
	events = res["events"].duplicate()
	_answer_all(server, events)
	var ev := _events(events)
	var diff := _diff(before, _snap(state), state, true)
	if ev != "" or not diff.is_empty():
		print("    END OF TURN: ", ev)
		for line in diff:
			print("      ", line)
	# соперники заканчивают ходы — начало следующего хода red
	var guard := 0
	before = _snap(state)
	events = []
	while state.current_player() != "red" and guard < 6 and not state.game_over:
		guard += 1
		res = server.apply_intent(Intent.end_turn(state.current_player()))
		events.append_array(res["events"])
		_answer_all(server, events)
	ev = _events(events.filter(func(e): return String(e.get("kind", "")) not in ["end_turn", "turn_end"]))
	diff = _diff(before, _snap(state), state, true).filter(func(l: String): return l.begins_with("red"))
	if not diff.is_empty():
		print("    NEXT TURN (red): ", ev)
		for line in diff:
			print("      ", line)


## Позиция: у red войска и шпион, соперники рядом, рука с картой и картой того
## же аспекта, сброс, трофеи, жетоны VP.
func _prepare(state: GameState, cid: String, deck_cards: Array[String]) -> void:
	var red: PlayerState = state.players["red"]
	var slots := state.deployable_slots("red")
	var placed := 0
	var owners := ["red", "red", "red", "blue", "blue", "green", "white"]
	for slot: String in slots:
		if placed >= owners.size():
			break
		if state.troops.get(slot, "") != "":
			continue
		var owner: String = owners[placed]
		state.troops[slot] = owner
		if owner != "white":
			state.stock(owner).troops_in_barracks -= 1
		placed += 1
	var sites := state.presence.sites_with_presence("red", state.troops, state.spies)
	if sites.size() >= 2:
		for pair in [[sites[0], "blue"], [sites[1], "red"]]:
			var arr: Array = state.spies.get(pair[0], [])
			arr.append(pair[1])
			state.spies[pair[0]] = arr
			state.stock(pair[1]).spies_in_barracks -= 1
	var green_site := ""
	for s: String in state.graph.sites.keys():
		if not sites.has(s):
			green_site = s
			break
	if green_site != "":
		state.spies[green_site] = (state.spies.get(green_site, []) as Array) + ["green"]
		state.stock("green").spies_in_barracks -= 1
	red.power = 4
	red.influence = 4
	red.vp_tokens = 2
	red.add_trophy("blue")
	red.add_trophy("white")
	# трофеи положены после начала хода — для карт "убитые в этот ход" (Azer
	# Sentinel, Purple Worm, Dao) счёт хода начинается с них
	state.turn_flags["trophy_start"] = state.stock("red").trophy_hall_count
	# рука: карта + карта того же аспекта + две стартовые
	var aspect := CardLibrary.card_aspect(cid)
	var mate := ""
	for other: String in deck_cards:
		if other != cid and CardLibrary.card_aspect(other) == aspect and CardLibrary.card_cost(other) <= 4:
			mate = other
			break
	var hand: Array[String] = [cid]
	if mate != "":
		hand.append(mate)
	for c: String in red.deck.hand:
		if hand.size() >= 5:
			break
		hand.append(c)
	red.deck.hand = hand
	red.deck.discard_pile.append_array([deck_cards[deck_cards.size() - 1], deck_cards[2]])
	red.deck.draw_pile.append_array([deck_cards[1], deck_cards[3]])
	red.deck.inner_circle.append(red.deck.draw_pile.pop_front())


func _answer_all(server: GameServer, events: Array) -> void:
	var guard := 0
	while server.resolver.is_waiting() and guard < 40:
		guard += 1
		var pd: PendingDecision = server.resolver.pending
		var opts: Array = pd.legal_options
		var labels: Array = []
		var market_q := pd.choice_type.contains("market")
		for i in range(opts.size()):
			if i < pd.option_labels.size() and pd.option_labels[i] != "":
				labels.append(pd.option_labels[i])
			elif market_q and typeof(opts[i]) == TYPE_INT and opts[i] >= 0 and opts[i] < server.state.market.display.size():
				labels.append("%d:%s" % [opts[i], _nm(server.state.market.display[opts[i]])])
			else:
				labels.append(_opt_name(server.state, opts[i]))
		var ans = null
		if opts.is_empty():
			print("    ?? [", pd.player_id, "] ", pd.choice_type, " '", pd.prompt, "' — NO OPTIONS")
			break
		match pd.choice_type:
			"confirm":
				ans = not _last
			"choose_option":
				ans = opts[opts.size() - 1] if _last else opts[0]
			_:
				var real := opts.filter(func(o): return not ((typeof(o) == TYPE_STRING and o == "") or (typeof(o) == TYPE_INT and o == -1)))
				if real.is_empty():
					ans = opts[0]
				else:
					ans = real[real.size() - 1] if _last else real[0]
		var shown: Array = labels.slice(0, 6)
		print("    ? [", pd.player_id, "] ", pd.choice_type, " '", pd.prompt, "' n=", opts.size(), " ", shown,
			(" ..." if labels.size() > 6 else ""), " -> ", _opt_name(server.state, ans))
		var res := server.apply_intent(Intent.make_decision(pd.player_id, ans))
		if int(res["error"]) != 0:
			print("    !! DECISION REFUSED ", res["error"])
			break
		events.append_array(res["events"])
	if server.resolver.is_waiting():
		print("    !! STILL WAITING after ", guard, " answers")


func _opt_name(state: GameState, o) -> String:
	if typeof(o) == TYPE_STRING:
		var s := String(o)
		if s == "":
			return "<none>"
		if state.graph.slots.has(s):
			return "slot@" + _place(state, s)
		if state.graph.sites.has(s):
			return "site:" + String(state.graph.sites[s]["name"])
		if not CardLibrary.card_data(s).is_empty():
			return _nm(s)
		return s
	return str(o)


func _place(state: GameState, slot: String) -> String:
	var site := state.graph.site_of_slot(slot)
	return String(state.graph.sites[site]["name"]) if site != "" else "route"


func _events(events: Array) -> String:
	var out: Array[String] = []
	for e: Dictionary in events:
		var kind := String(e.get("kind", e.get("type", "?")))
		if kind in NOISE:
			continue
		var parts: Array[String] = []
		for k in e.keys():
			if k in ["kind", "type"]:
				continue
			var v = e[k]
			if typeof(v) == TYPE_STRING and not CardLibrary.card_data(v).is_empty() and String(v).length() == 5:
				v = _nm(v)
			parts.append("%s=%s" % [k, v])
		out.append("%s{%s}" % [kind, ", ".join(parts)])
	return "; ".join(out)


func _snap(state: GameState) -> Dictionary:
	var d := {}
	for pid: String in state.turn_order:
		var p: PlayerState = state.players[pid]
		var on_board := 0
		for s in state.troops:
			if state.troops[s] == pid:
				on_board += 1
		var spies := 0
		for s in state.spies:
			spies += (state.spies[s] as Array).count(pid)
		d[pid] = {
			"power": p.power, "influence": p.influence, "vp_tokens": p.vp_tokens,
			"hand": p.deck.hand.duplicate(), "discard": p.deck.discard_pile.duplicate(),
			"draw": p.deck.draw_pile.duplicate(), "inner": p.deck.inner_circle.duplicate(),
			"played": p.deck.played_pile.duplicate(), "retained": p.deck.retained.duplicate(),
			"set_aside": p.deck.set_aside.duplicate(),
			"troops_board": on_board, "spies_board": spies,
			"barracks": state.stock(pid).troops_in_barracks, "spy_barracks": state.stock(pid).spies_in_barracks,
			"trophies": p.trophies.duplicate(), "acorns": p.acorns, "evolutions": p.evolutions.duplicate(),
			"promotions": p.pending_promotions.duplicate(), "start_inf": p.start_of_turn_influence,
			"end_of_turn": p.pending_end_of_turn.size(),
		}
	d["troops"] = state.troops.duplicate()
	d["spies"] = state.spies.duplicate(true)
	d["market"] = state.market.display.duplicate()
	d["market_deck"] = state.market.deck.size()
	d["devoured"] = state.devoured_pile.duplicate()
	d["supplies"] = state.supplies.counts.duplicate() if state.supplies != null else {}
	d["flags"] = state.turn_flags.duplicate(true)
	d["discounts"] = state.turn_discounts.duplicate(true)
	d["market_troops"] = state.market_troops.duplicate()
	d["market_spies"] = state.market_spies.duplicate()
	d["board_vp"] = state.board_vp.duplicate()
	d["removed_hexes"] = state.removed_hexes.duplicate()
	d["extra_turn"] = state.extra_turn_for
	d["winner"] = state.instant_winner
	return d


func _print_diff(a: Dictionary, b: Dictionary, state: GameState) -> void:
	for line in _diff(a, b, state, false):
		print("      ", line)


func _cards_delta(a: Array, b: Array) -> String:
	var plus: Array[String] = []
	var minus: Array[String] = []
	var rest := a.duplicate()
	for c in b:
		var i := rest.find(c)
		if i >= 0:
			rest.remove_at(i)
		else:
			plus.append(_nm(c))
	for c in rest:
		minus.append(_nm(c))
	var s := ""
	if not plus.is_empty():
		s += "+" + str(plus)
	if not minus.is_empty():
		s += " -" + str(minus)
	return s


func _diff(a: Dictionary, b: Dictionary, state: GameState, brief: bool) -> Array[String]:
	var out: Array[String] = []
	for pid: String in state.turn_order:
		var pa: Dictionary = a[pid]
		var pb: Dictionary = b[pid]
		var parts: Array[String] = []
		for k in pa.keys():
			if pa[k] == pb[k]:
				continue
			if typeof(pa[k]) == TYPE_INT:
				parts.append("%s %+d" % [k, pb[k] - pa[k]])
			elif typeof(pa[k]) == TYPE_ARRAY and k in ["hand", "discard", "draw", "inner", "played", "retained", "set_aside"]:
				if brief and k in ["hand", "discard", "draw", "played"]:
					parts.append("%s %d->%d" % [k, (pa[k] as Array).size(), (pb[k] as Array).size()])
				else:
					parts.append("%s %s" % [k, _cards_delta(pa[k], pb[k])])
			else:
				parts.append("%s %s->%s" % [k, pa[k], pb[k]])
		if not parts.is_empty():
			out.append("%s: %s" % [pid, ", ".join(parts)])
	var tr: Array[String] = []
	var ta: Dictionary = a["troops"]
	var tb: Dictionary = b["troops"]
	var seen := {}
	for s in ta.keys() + tb.keys():
		if seen.has(s):
			continue
		seen[s] = true
		var x := String(ta.get(s, ""))
		var y := String(tb.get(s, ""))
		if x != y and state.graph.slots.has(s):
			tr.append("%s:%s->%s" % [_place(state, s), x if x != "" else "_", y if y != "" else "_"])
		elif x != y:
			tr.append("REMOVED slot %s (%s)" % [s, x])
	if not tr.is_empty():
		out.append("troops: " + ", ".join(tr))
	if a["spies"] != b["spies"]:
		var sp: Array[String] = []
		for s in (a["spies"] as Dictionary).keys() + (b["spies"] as Dictionary).keys():
			var x: Array = a["spies"].get(s, [])
			var y: Array = b["spies"].get(s, [])
			if x != y:
				var line := "%s:%s->%s" % [String(state.graph.sites[s]["name"]) if state.graph.sites.has(s) else s, x, y]
				if not sp.has(line):
					sp.append(line)
		out.append("spies: " + ", ".join(sp))
	if a["market"] != b["market"]:
		out.append("market: %s" % _cards_delta(a["market"], b["market"]))
	for k in ["market_deck", "flags", "discounts", "market_troops", "market_spies", "board_vp", "removed_hexes", "extra_turn", "winner"]:
		if a[k] != b[k] and not (brief and k == "flags"):
			out.append("%s: %s -> %s" % [k, a[k], b[k]])
	if a["devoured"] != b["devoured"]:
		out.append("devoured: %s" % _cards_delta(a["devoured"], b["devoured"]))
	if a["supplies"] != b["supplies"]:
		var sd: Array[String] = []
		for k in (b["supplies"] as Dictionary).keys():
			if a["supplies"].get(k) != b["supplies"][k]:
				sd.append("%s %s->%s" % [_nm(k), a["supplies"].get(k), b["supplies"][k]])
		out.append("supplies: " + ", ".join(sd))
	return out
