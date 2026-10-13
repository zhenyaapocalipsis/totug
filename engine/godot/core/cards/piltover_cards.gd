class_name PiltoverCards
extends RefCounted

## Полуколода Piltover & Zaun (New Era) — способности карт Piltover & Zaun из
## фан-мода Runeterra Reforged на существах D&D: големы, слизи и жители
## города (этап NE-6, 2026-10-11, см. Claude outputs/new_era_piltover.md).
##
## Перевод на правила этой игры:
##   Valor (аспект мода)   -> MALICE;
##   "neutral troop"       -> белое войско;
##   "Double <X> Focus"    -> FocusEffect с need = 2: две ДРУГИЕ карты аспекта,
##                            сыгранные в этот ход и/или показанные из руки.
##
## Флаги хода (state.turn_flags, сбрасываются в start_turn):
##   "choose_all"  — Homunculus: в "Choose one" есть вариант "All of them";
##   "focus_extra" — Homunculus: каждый Focus срабатывает ещё раз;
##   "spy_move"    — Manticore: после каждого шпиона можно подвинуть войско;
##   "buy_echo"    — Harpy: после покупки можно бесплатно взять карту дешевле.
## Лишний ход Basilisk — state.extra_turn_for / in_extra_turn (GameEnd).

const BASILISK := "49218"
const HARPY := "49220"
const MAX_SPIES := 10


static func build(card_id: String) -> CardEffect:
	match card_id:
		"49200":  # Tough Boss (Officer Squad)
			return SequenceEffect.new([
				_AfterTroops.new(ChooseEffect.new([DeployTroop.new(3), MoveTroop.new(1)],
					["Deploy 3 troops", "Move a troop"]),
					func(s, pid, before): return ScryCards.new(1) if _moved_next_to_other(s, pid, before) else null),
				FocusEffect.new("CONQUEST", DrawCards.new(1)),
			])
		"49201":  # Wererat (Zaun Diva)
			return SequenceEffect.new([
				ChooseEffect.new([GainPower.new(2), GainInfluence.new(2)], ["+2 Power", "+2 Influence"]),
				FocusEffect.new("MALICE", SequenceEffect.new([DrawCards.new(1), DiscardCardEffect.new(1)])),
			])
		"49202":  # Bandit Captain (Midenstokke Henchmen)
			return SequenceEffect.new([
				ChooseEffect.new([AssassinateTroop.new(1), SupplantTroop.new(1, true)],
					["Assassinate a troop", "Supplant a white troop"]),
				FocusEffect.new("MALICE", GainPower.new(2)),
			])
		"49203":  # Rust Monster (Chief Mechanist)
			return SequenceEffect.new([
				ChooseEffect.new([
					DeployTroop.new(2),
					MoveTroop.new(1, false, true),
					ReturnOwnTroops.new(2, true, func(_k): return DrawCards.new(1)),
				], ["Deploy 2 troops", "Move one of your troops", "Return 2 of your troops -> Draw a card"]),
				FocusEffect.new("CONQUEST", DrawCards.new(1)),
			])
		"49204":  # Black Pudding (Augmented Experimenter)
			return SequenceEffect.new([
				AtEndOfTurn.new(PromoteCard.new("played_other", card_id)),
				FocusEffect.new("AMBITION", GainInfluence.new(2)),
			])
		"49205":  # Spy (Chembaron)
			return SequenceEffect.new([
				ChooseEffect.new([
					PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
						func(state, _pid): return CelestialCards.site_is_full(state, site), DeployTroop.new(2))),
					ReturnOwnSpy.new(GainInfluence.new(3)),
				], ["Place a spy (full site: deploy 2 troops)", "Return one of your spies -> +3 Influence"]),
				FocusEffect.new("GUILE", GainPower.new(2)),
			])
		"49206":  # Otyugh (Chump Whump)
			return SequenceEffect.new([
				_AfterTroops.new(AssassinateTroop.new(1),
					func(s, _pid, before): return GainPower.new(1) if _victims(s, before).has("white") else null),
				_promote_obedience(card_id),
				FocusEffect.new("CONQUEST", MoveTroop.new(1)),
			])
		"49207":  # Clay Golem (Plaza Guardian)
			return SequenceEffect.new([GainPower.new(2), _promote_obedience(card_id)])
		"49208":  # Gelatinous Cube (Patrol Wardens)
			return _BothIfFocus.new("AMBITION",
				ChooseEffect.new([GainInfluence.new(2), ReturnTroopOrSpy.new(1, false, false, true)],
					["+2 Influence", "Return a spy"]),
				SequenceEffect.new([GainInfluence.new(2), ReturnTroopOrSpy.new(1, false, false, true)]))
		"49209":  # Ochre Jelly (Dropboarder)
			return SequenceEffect.new([PlaceSpy.new(1), GainPower.new(1), _promote_obedience(card_id)])
		"49210":  # Mimic (Ferros Elite)
			return SequenceEffect.new([GainInfluence.new(2), _promote_obedience(card_id)])
		"49211":  # Stone Golem (Vi)
			return SequenceEffect.new([
				_AfterTroops.new(AssassinateTroop.new(1), func(s, pid, before): return PiltoverCards._vi_follow(s, pid, before)),
				FocusEffect.new("CONQUEST", ChooseEffect.new([DeployTroop.new(4), DrawCards.new(1)],
					["Deploy 4 troops", "Draw a card"])),
			])
		"49212":  # Assassin (Caitlyn)
			return SequenceEffect.new([
				_strike_anywhere(),
				_TopTwoPeek.new(),
				FocusEffect.new("MALICE", ChooseEffect.new([_strike_anywhere(), DrawCards.new(1)],
					["Assassinate a troop anywhere", "Draw a card"])),
			])
		"49213":  # Iron Golem (Jayce)
			return SequenceEffect.new([
				ChooseEffect.new([
					SequenceEffect.new([GainInfluence.new(2), AtEndOfTurn.new(PromoteCard.new("played_other"))]),
					SequenceEffect.new([AssassinateTroop.new(1), ReturnTroopOrSpy.new(1, false, false, true)]),
				], ["+2 Influence, at end of turn promote a card you played", "Assassinate a troop and return a spy"]),
				FocusEffect.new("AMBITION", ChooseEffect.new([GainInfluence.new(3), DrawCards.new(1)],
					["+3 Influence", "Draw a card"])),
			])
		"49214":  # Manticore (Jinx) — ход шпиона: PlaceSpy._place_at
			return SequenceEffect.new([
				ShadowCards._SetFlag.new("spy_move"),
				PlaceSpy.new(2),
				FocusEffect.new("GUILE", ChooseEffect.new([PlaceSpy.new(2), DrawCards.new(1)],
					["Place 2 spies", "Draw a card"])),
			])
		"49215":  # Homunculus (Heimerdinger)
			return SequenceEffect.new([
				DrawCards.new(1),
				ChooseEffect.new([ShadowCards._SetFlag.new("choose_all"), ShadowCards._AddFlag.new("focus_extra")],
					["This turn you may choose all options instead of one", "This turn Focus effects trigger an additional time"]),
			])
		"49216":  # Chimera (Warwick)
			return SequenceEffect.new([
				_AfterTroops.new(DeployTroop.new(4),
					func(s, pid, before): return SupplantTroop.new(1) if _moved_next_to_other(s, pid, before) else null),
				FocusEffect.new("CONQUEST", SequenceEffect.new([
					MoveTroop.new(1, false, true),
					SupplantTroop.new(1),
					_PowerToTroops.new(),
				]), 2),
			])
		"49217":  # Archmage (Viktor)
			return SequenceEffect.new([
				PlaceSpy.new(1, false, func(site): return AssassinateTroop.new(1, false, false, false, 0, 0, site)),
				DrawCards.new(1),
				FocusEffect.new("GUILE", SequenceEffect.new([
					_GainSpy.new(),
					PlaceSpy.new(2, false, func(site): return AssassinateTroop.new(1, false, false, false, 0, 0, site)),
				]), 2),
			])
		"49218":  # Basilisk (Ekko)
			return SequenceEffect.new([GainPower.new(4), FocusEffect.new("MALICE", _ExtraTurn.new(), 2)])
		"49219":  # Behir (Janna)
			return ChooseEffect.new([_FocusFromTop.new(6), _RecruitFreeVp.new("", 999)],
				["Focus cards from your top 6 into your hand, discard the rest",
					"Recruit a market card for free, gain VP equal to its deck VP"])
		"49220":  # Harpy (Seraphine; до 2026-10-13 — Hydra, имя ушло карте Siege) — бесплатная карта после покупки: after_buy
			return SequenceEffect.new([
				GainInfluence.new(5),
				FocusEffect.new("AMBITION", SequenceEffect.new([GainInfluence.new(4), ShadowCards._SetFlag.new("buy_echo")]), 2),
			])
	return null


## Harpy: после покупки (рынок или запас) — бесплатно карта рынка дешевле купленной.
static func after_buy(state: GameState, player_id: String, bought: String, resolver: EffectResolver) -> void:
	if player_id != state.current_player() or not state.turn_flags.get("buy_echo", false):
		return
	var limit := CardLibrary.card_cost(bought) - 1
	if limit < 0:
		return
	var free := RecruitFree.new("", limit, 1, true)
	if free._eligible_indices(state).is_empty():
		return
	resolver.apply(free, player_id, state, HARPY)


## Stone Golem: "If it was a player troop, +3 Power. Otherwise, deploy a troop."
static func _vi_follow(state: GameState, player_id: String, before: Dictionary) -> CardEffect:
	for victim: String in _victims(state, before):
		if victim != "white" and state.is_enemy(player_id, victim):
			return GainPower.new(3)
	return DeployTroop.new(1)


static func _promote_obedience(card_id: String) -> CardEffect:
	return AtEndOfTurn.new(PromoteCard.new("played_other", card_id, CardLibrary._aspect_filter("OBEDIENCE")))


## "Assassinate a troop anywhere" — без Присутствия.
static func _strike_anywhere() -> AssassinateTroop:
	var strike := AssassinateTroop.new(1)
	strike.site_given_by_card = true
	return strike


## Владельцы войск, убранных с доски с момента снимка before.
static func _victims(state: GameState, before: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for slot_id: String in before.keys():
		var owner: String = before[slot_id]
		if owner != "" and String(state.troops.get(slot_id, "")) == "":
			out.append(owner)
	return out


## "If you moved or deployed a troop next to another player's troop": войско,
## появившееся с момента снимка, стоит рядом (соседний слот или та же
## локация) с войском игрока — не своим и не белым.
static func _moved_next_to_other(state: GameState, player_id: String, before: Dictionary) -> bool:
	for slot_id: String in state.troops.keys():
		var owner: String = state.troops[slot_id]
		if owner == "" or owner == "white" or String(before.get(slot_id, "")) == owner:
			continue
		var near: Array = Array(state.graph.adjacent_slots(slot_id))
		var site: String = state.graph.site_of_slot(slot_id)
		if site != "":
			near.append_array(state.graph.slots_of_site(site))
		for other: String in near:
			if other == slot_id:
				continue
			var other_owner: String = state.troops.get(other, "")
			if other_owner != "white" and state.is_enemy(player_id, other_owner):
				return true
	return false


## Выполнить inner, потом спросить check(state, player_id, войска_до) — тот
## может вернуть эффект-продолжение или null.
class _AfterTroops extends CardEffect:
	var inner: CardEffect
	var check: Callable
	func _init(effect: CardEffect, fn: Callable) -> void:
		inner = effect
		check = fn
	func is_available(state: GameState, player_id: String) -> bool:
		return inner.is_available(state, player_id)
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var before: Dictionary = state.troops.duplicate()
		var fn := check
		resolver.push(CallbackEffect.new(func(s: GameState, pid: String, r: EffectResolver):
			var next: CardEffect = fn.call(s, pid, before)
			if next != null:
				r.push(next, pid)), player_id)
		resolver.push(inner, player_id)


## Gelatinous Cube: "Choose one ... Focus: choose both instead".
class _BothIfFocus extends CardEffect:
	var aspect: String
	var pick: CardEffect
	var both: CardEffect
	func _init(asp: String, one: CardEffect, every: CardEffect) -> void:
		aspect = asp
		pick = one
		both = every
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		resolver.push(both if FocusEffect.is_met(state, player_id, aspect) else pick, player_id)


## Chimera: "You may deploy 2 troops per Power" — сколько угодно раз подряд.
class _PowerToTroops extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var p: PlayerState = state.players[player_id]
		if p.power < 1 or state.stock(player_id).troops_in_barracks <= 0:
			return
		var ask := OptionalEffect.new(_PayPower.new(), "Spend 1 Power to deploy 2 troops?")
		ask.source_card = "49216"
		resolver.push(ask, player_id)


class _PayPower extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var p: PlayerState = state.players[player_id]
		if p.power < 1:
			return
		p.power -= 1
		resolver.push(_PowerToTroops.new(), player_id)
		resolver.push(DeployTroop.new(2), player_id)


## Archmage: "Gain a spy to your supply (you can hold up to 10 spies)".
## 2v2: общий запас команды — до 10 на каждого союзника (шпионы обоих).
class _GainSpy extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var stock: PlayerState = state.stock(player_id)
		var on_board := 0
		for pid: String in state.players.keys():
			if state.stock(pid) == stock:
				on_board += CelestialCards._own_spies(state, pid)
		if stock.spies_in_barracks + on_board >= PiltoverCards.MAX_SPIES * state.stock_share(player_id):
			return
		stock.spies_in_barracks += 1
		resolver.log_event("gain_spy", {"player_id": player_id})


## Basilisk: "Take another turn, but only play up to 3 cards on that turn".
## Из самого лишнего хода ещё один не берётся.
class _ExtraTurn extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if state.in_extra_turn or player_id != state.current_player():
			return
		state.extra_turn_for = player_id
		resolver.log_event("extra_turn", {"player_id": player_id, "cards": TurnEngine.EXTRA_TURN_CARDS})


## Behir: "Look at the top 6 cards of your deck. Put all cards with the Focus
## keyword into your hand. Discard the rest."
class _FocusFromTop extends CardEffect:
	var amount: int
	func _init(n: int) -> void:
		amount = n
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var deck: Deck = state.players[player_id].deck
		if deck.draw_pile.is_empty() and not deck.discard_pile.is_empty():
			deck.draw_pile = deck.discard_pile.duplicate()
			deck.discard_pile.clear()
			deck.shuffle_draw_pile(state.rng)
		var taken: Array[String] = []
		var dropped: Array[String] = []
		for i in range(mini(amount, deck.draw_pile.size())):
			var card: String = deck.draw_pile.pop_back()
			if PiltoverCards.has_focus(card):
				taken.append(card)
			else:
				dropped.append(card)
		deck.hand.append_array(taken)
		deck.discard_pile.append_array(dropped)
		resolver.log_event("fetch_from_top", {"player_id": player_id, "looked": taken.size() + dropped.size(), "cards": taken})


static func has_focus(card_id: String) -> bool:
	return String(CardLibrary.card_data(card_id).get("ability_text", "")).contains("Focus ►")


## Behir: бесплатная карта рынка + VP, равные её deck VP.
class _RecruitFreeVp extends RecruitFree:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var card := ""
		if is_answered():
			var index = answer()
			if index != null and int(index) >= 0 and int(index) < state.market.display.size():
				card = state.market.display[int(index)]
		super.apply(state, player_id, resolver)
		if card != "":
			var vp := Scoring._card_vp(card, "deck_vp")
			if vp > 0:
				resolver.push(GainVP.new(vp), player_id)


## Assassin: "Look at the top 2 cards of each player's deck. You may discard
## up to 1 of them" — по очереди от себя по часовой; одна карта на всех.
class _TopTwoPeek extends CardEffect:
	var _queue: Array[String] = []
	var _who := ""
	var _shown: Array[String] = []
	var _started := false
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if not _started:
			_started = true
			_queue = [player_id]
			_queue.append_array(ShadowCards._opponents_clockwise(state, player_id))
		elif is_answered():
			var chosen = answer()
			_answered = false
			_answer = null
			if chosen != null and String(chosen) != "" and _shown.has(String(chosen)):
				var deck: Deck = state.players[_who].deck
				for j in range(deck.draw_pile.size() - 1, maxi(-1, deck.draw_pile.size() - 3), -1):
					if deck.draw_pile[j] == String(chosen):
						deck.draw_pile.remove_at(j)
						break
				deck.discard_pile.append(String(chosen))
				resolver.log_event("discard", {"player_id": _who, "card_id": chosen, "from": "peek", "by": player_id})
				return
		while not _queue.is_empty():
			_who = _queue.pop_front()
			var deck: Deck = state.players[_who].deck
			if deck.draw_pile.is_empty() and not deck.discard_pile.is_empty():
				deck.draw_pile = deck.discard_pile.duplicate()
				deck.discard_pile.clear()
				deck.shuffle_draw_pile(state.rng)
			_shown.clear()
			for i in range(mini(2, deck.draw_pile.size())):
				_shown.append(deck.draw_pile[deck.draw_pile.size() - 1 - i])
			if _shown.is_empty():
				continue
			var pd := PendingDecision.new()
			pd.player_id = player_id
			var whose := "your" if _who == player_id else _who.capitalize() + "'s"
			pd.prompt = "Top 2 cards of %s deck: discard one?" % whose
			pd.choice_type = "target_card"
			pd.legal_options = Array(_shown)
			pd.legal_options.append("")
			pd.target_effect = self
			resolver.request_decision(pd)
			return
