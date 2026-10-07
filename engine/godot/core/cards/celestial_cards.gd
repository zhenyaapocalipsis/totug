class_name CelestialCards
extends RefCounted

## Полуколода Celestial Order (New Era) — способности карт Demacia из фан-мода
## Runeterra Reforged, перенесённые на существ D&D (решения владельца
## 2026-10-07, см. Claude outputs/new_era_dnd_mapping.md).
##
## Карты мода переведены на правила этой игры:
##   Vanguard Cavalry   -> House Guard (+2 Power, цена 3, запас у доски);
##   Battlefield Sergeant -> Priestess of Lolth (+2 Influence, цена 2);
##   Valor (аспект мода) -> MALICE;
##   "Scry N"           -> ScryCards (посмотреть N верхних, сбросить любые).
##
## Упрощения (не в пользу игрока, партию не блокируют):
##   Djinni — "spend 2 Influence: draw" предлагается сразу при розыгрыше
##     (сколько угодно раз подряд), а не в любой момент хода;
##   (Shield Guardian: +5 Power при розыгрыше; реакция из руки — ShieldGuard).

const HOUSE_GUARD := "48340"
const PRIESTESS := "48343"
const SCOUT := "49019"
const GOLD_DRAGON := "49022"
const GIANT_EAGLE := "49023"
const ANCIENT_GOLD_DRAGON := "49024"


static func build(card_id: String) -> CardEffect:
	match card_id:
		"49000":  # Warrior Infantry (Laurent Protégé)
			return ChooseEffect.new([
				GainPower.new(3),
				FetchFromTop.new(6, func(c): return c == HOUSE_GUARD),
			], ["+3 Power", "Look at the top 6 cards: House Guards into your hand"])
		"49001":  # Priest (Dawnspeakers)
			return SequenceEffect.new([
				ConditionalEffect.new(func(state, pid): return state.players[pid].deck.inner_circle.size() >= 6, GainInfluence.new(2)),
				AtEndOfTurn.new(PromoteCard.new("played_other", card_id)),
			])
		"49002":  # Sphinx of Wonder (Insightful Investigator)
			return PlaceSpy.new(1, false, func(site): return SequenceEffect.new([
				ConditionalEffect.new(func(state, pid): return CardLibrary._site_has_enemy_troop(state, pid, site), GainPower.new(1)),
				ConditionalEffect.new(func(state, _pid): return site_is_full(state, site), GainPower.new(1)),
				ConditionalEffect.new(func(state, pid): return CardLibrary._site_has_enemy_spy(state, pid, site), GainPower.new(1)),
			]))
		"49003":  # Sphinx of Valor (Garen)
			return ChooseEffect.new([
				SequenceEffect.new([GainSupplyToHand.new([HOUSE_GUARD, PRIESTESS] as Array[String]), GainPower.new(4)]),
				PromoteCard.new("hand_or_discard", "", func(c): return CardLibrary.card_aspect(c) == "OBEDIENCE", 2, true),
			], ["House Guard or Priestess into your hand, +4 Power", "Promote up to 2 Obedience cards from hand or discard"])
		"49004":  # Djinni (Lux)
			return SequenceEffect.new([GainInfluence.new(5), _DevaDrawLoop.new()])
		"49005":  # Satyr (Durand Architect)
			return ChooseEffect.new([
				GainInfluence.new(2),
				AtEndOfTurn.new(PromoteCard.new("played_other", card_id)),
			], ["+2 Influence", "At end of turn, promote another card played this turn"])
		"49006":  # Couatl (Mageseeker Conservator) — VP считает Scoring.card_bonus_vp
			return PlaceSpy.new(2)
		"49007":  # Hippogriff (Zealous Ranger-Knight)
			return SequenceEffect.new([
				AtEndOfTurn.new(PromoteCard.new("played_other", card_id)),
				ReturnOwnTroops.new(2, true, func(_k): return ChooseEffect.new([
					ReturnTroopOrSpy.new(1),
					SequenceEffect.new([GainInfluence.new(2), TurnDiscount.new("supply:" + HOUSE_GUARD, 1)]),
				], ["Return another player's troop or spy", "+2 Influence, House Guards cost 1 less this turn"])),
			])
		"49008":  # Pegasus (Silverwing Diver)
			return SequenceEffect.new([
				_PerPlayed.new(HOUSE_GUARD, "power"),
				ChooseEffect.new([
					AssassinateTroop.new(2, true),
					PromoteCard.new("hand"),
					MoveTroop.new(1, false, true),
				], ["Assassinate 2 white troops", "Promote a card in your hand", "Move one of your troops"]),
			])
		"49009":  # Druid (Greenfang Warden) — бонус в конце партии: Scoring.card_bonus_vp
			return SupplantTroop.new(1, true)
		"49010":  # Planetar (Radiant Guardian)
			return ChooseEffect.new([
				SequenceEffect.new([DeployTroop.new(2), DrawCards.new(1)]),
				ReturnOwnTroops.new(2, true, func(_k): return SupplantTroop.new(1, true, true)),
				_PerPlayed.new(HOUSE_GUARD, "draw"),
			], ["Deploy 2 troops and draw a card", "Return 2 of your troops -> Supplant a white troop anywhere",
				"Draw a card per House Guard played this turn"])
		"49011":  # Sphinx of Lore (Mageseeker Inquisitor)
			return ChooseEffect.new([
				PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
					func(state, _pid): return site_is_full(state, site), DrawCards.new(1))),
				ReturnOwnSpy.new(SequenceEffect.new([DrawCards.new(1), GainPower.new(3)])),
			], ["Place a spy (full site: draw a card)", "Return one of your spies -> Draw a card, +3 Power"])
		"49012":  # Griffon (Dauntless Reinforcements)
			return ChooseEffect.new([
				_PromoteHandDeployIc.new(),
				SupplantTroop.new(1, true),
				MoveTroop.new(1, false, true),
			], ["Promote a card in your hand, deploy troops equal to its inner circle VP",
				"Supplant a white troop", "Move one of your troops"])
		"49013":  # Unicorn (Mageseeker Investigator)
			return ChooseEffect.new([
				PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
					func(state, _pid): return site_is_full(state, site), DrawCards.new(1))),
				ReturnOwnSpy.new(null, func(site): return SupplantTroop.new(1, false, true, false, Callable(), site)),
				_InfluencePerSpy.new(),
			], ["Place a spy (full site: draw a card)", "Return one of your spies -> Supplant a troop at that spy's site",
				"+1 Influence per spy you have on the board"])
		"49014":  # Werebear (Grizzled Ranger)
			return ChooseEffect.new([
				GainPower.new(2),
				AssassinateTroop.new(1, true),
				ReturnTroopOrSpy.new(1),
				GainSupplyToHand.new([HOUSE_GUARD] as Array[String]),
			], ["+2 Power", "Assassinate a white troop", "Return a troop or spy", "Put a House Guard into your hand"])
		"49015":  # Solar (Kayle)
			var left := func(state, pid, n):
				return PlayerState.STARTING_TROOPS - state.players[pid].troops_in_barracks >= n
			return SequenceEffect.new([
				DeployTroop.new(3),
				ConditionalEffect.new(func(state, pid): return left.call(state, pid, 10), AssassinateTroop.new(1)),
				ConditionalEffect.new(func(state, pid): return left.call(state, pid, 20), DrawCards.new(1)),
				ConditionalEffect.new(func(state, pid): return left.call(state, pid, 30), GainPower.new(4)),
			])
		"49016":  # Erinyes (Morgana)
			return ChooseEffect.new([
				PlaceSpy.new(1, false, func(site): return ReturnTroopOrSpy.new(2, true, true, false, site)),
				ReturnOwnSpy.new(null, func(site): return SequenceEffect.new([
					ReturnTroopOrSpy.new(3, true, true, false, site),
					DeployTroop.new(3, true, site),
				])),
			], ["Place a spy and return up to 2 troops at that site",
				"Return one of your spies -> return up to 3 troops there, then deploy up to 3 troops there"])
		"49017":  # Warrior Veteran (Poppy)
			return SequenceEffect.new([
				MoveTroop.new(2, true, false, true, "", func(site): return _veteran_extra_move(site)),
				_AllFromDiscardToHand.new(HOUSE_GUARD),
			])
		"49018":  # Berserker (Fiora)
			return SequenceEffect.new([
				ScryCards.new(2),
				DrawCards.new(1),
				ReturnOwnTroops.new(40, false, func(k): return GainPower.new(k)),
				TurnDiscount.new("assassinate", 1),
				TurnDiscount.new("return_spy", 2),
			])
		"49019":  # Scout (Quinn) — Giant Eagle приходит в сброс при получении (on_gain)
			return SequenceEffect.new([
				ConditionalEffect.new(func(state, pid): return state.players[pid].deck.discard_pile.has(GIANT_EAGLE),
					SequenceEffect.new([PlaceSpy.new(2), AssassinateTroop.new(1)])),
				ConditionalEffect.new(func(state, pid): return state.players[pid].deck.draw_pile.has(GIANT_EAGLE),
					SequenceEffect.new([DrawCards.new(3), DiscardCardEffect.new(3), GainPower.new(2)])),
			])
		"49020":  # Silver Dragon (Jarvan IV)
			return ChooseEffect.new([
				SequenceEffect.new([PutDeckIntoDiscard.new(), PromoteCard.new("discard")]),
				GainPower.new(3),
			], ["Put your deck into your discard pile, then promote a card from it", "+3 Power"])
		"49021":  # Shield Guardian (Galio) — реакция из руки: core/effects/primitives/shield_guard.gd
			return GainPower.new(5)
		"49022":  # Gold Dragon (Shyvana)
			var pick := func(): return ChooseEffect.new([GainPower.new(2), MoveTroop.new(1, false, true)],
				["+2 Power", "Move one of your troops"])
			return SequenceEffect.new([pick.call(), pick.call(), pick.call(), pick.call(),
				_Transform.new(GOLD_DRAGON, ANCIENT_GOLD_DRAGON)])
		"49023":  # Giant Eagle (Valor)
			return SequenceEffect.new([
				DrawCards.new(1),
				ReturnOwnSpy.new(null, Callable(), true, func(sites): return _EagleStrike.new(sites)),
			])
		"49024":  # Ancient Gold Dragon (Dragon Shyvana)
			return SequenceEffect.new([
				ChooseEffect.new([
					AssassinateTroop.new(4, false, true, true),
					ReturnOwnTroops.new(4, false, func(k): return SupplantTroop.new(k, false, false, true, Callable(), "", true)),
				], ["Assassinate up to 4 troops at one site", "Return troops -> supplant that many at one site"]),
				_Transform.new(ANCIENT_GOLD_DRAGON, GOLD_DRAGON),
			])
	return null


## "When you gain this card" — вызывается Actions.recruit / RecruitFree.
static func on_gain(state: GameState, player_id: String, card_id: String) -> void:
	if card_id == SCOUT:
		state.players[player_id].deck.discard_pile.append(GIANT_EAGLE)


## Warrior Veteran: "Return 3 of your troops ► move 1 more troop from that site".
static func _veteran_extra_move(site: String) -> CardEffect:
	if site == "":
		return null
	return ReturnOwnTroops.new(3, true, func(_k): return MoveTroop.new(1, true, false, true, site))


static func site_is_full(state: GameState, site_id: String) -> bool:
	for slot_id: String in state.graph.slots_of_site(site_id):
		if state.troops.get(slot_id, "") == "":
			return false
	return true


static func _own_spies(state: GameState, player_id: String) -> int:
	var n := 0
	for owners: Array in state.spies.values():
		n += owners.count(player_id)
	return n


## Скидка до конца хода (state.turn_discounts, см. GameState).
class TurnDiscount extends CardEffect:
	var key: String
	var amount: int
	func _init(k: String, n: int) -> void:
		key = k
		amount = n
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		state.turn_discounts[key] = int(state.turn_discounts.get(key, 0)) + amount
		resolver.log_event("turn_discount", {"player_id": player_id, "key": key, "amount": amount})


## "+1 Power / draw a card per <card> played this turn" (считая уже сыгранные).
class _PerPlayed extends CardEffect:
	var card: String
	var what: String
	func _init(c: String, w: String) -> void:
		card = c
		what = w
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var n: int = state.players[player_id].deck.played_pile.count(card)
		if n <= 0:
			return
		if what == "power":
			resolver.push(GainPower.new(n), player_id)
		else:
			resolver.push(DrawCards.new(n), player_id)


class _InfluencePerSpy extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var n := CelestialCards._own_spies(state, player_id)
		if n > 0:
			resolver.push(GainInfluence.new(n), player_id)


## Djinni: после +5 Influence сколько угодно раз "заплати 2 Influence — возьми карту".
class _DevaDrawLoop extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if state.players[player_id].influence < 2:
			return
		resolver.push(OptionalEffect.new(_DevaPay.new(), "Spend 2 Influence to draw a card?"), player_id)


class _DevaPay extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var p: PlayerState = state.players[player_id]
		if p.influence < 2:
			return
		p.influence -= 2
		resolver.push(_DevaDrawLoop.new(), player_id)
		resolver.push(DrawCards.new(1), player_id)


## Griffon: promote карту из руки и поставить столько войск, сколько она
## стоит VP во Внутреннем круге.
class _PromoteHandDeployIc extends CardEffect:
	func is_available(state: GameState, player_id: String) -> bool:
		return not state.players[player_id].deck.hand.is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var p: PlayerState = state.players[player_id]
		if is_answered():
			var chosen = answer()
			if chosen == null or String(chosen) == "":
				return
			var idx := p.deck.hand.find(String(chosen))
			if idx == -1:
				return
			p.deck.hand.remove_at(idx)
			if Supplies.redirect_outcast(state, player_id, String(chosen), resolver):
				return
			p.deck.inner_circle.append(String(chosen))
			resolver.log_event("promote", {"player_id": player_id, "card_id": chosen})
			var ic: int = Scoring._card_vp(String(chosen), "inner_circle_vp")
			if ic > 0:
				resolver.push(DeployTroop.new(ic), player_id)
			return
		if p.deck.hand.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Promote a card in your hand"
		pd.choice_type = "target_card"
		pd.tag = "hand"
		pd.legal_options = p.deck.hand.duplicate()
		pd.target_effect = self
		resolver.request_decision(pd)


## Warrior Veteran: все такие карты из сброса — в руку.
class _AllFromDiscardToHand extends CardEffect:
	var card: String
	func _init(c: String) -> void:
		card = c
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		var n: int = d.discard_pile.count(card)
		if n <= 0:
			return
		d.discard_pile = d.discard_pile.filter(func(c): return c != card)
		for i in range(n):
			d.hand.append(card)
		resolver.log_event("discard_to_hand", {"player_id": player_id, "card_id": card, "count": n})


## Transform: эта карта уходит из игры, её вторая форма — в сброс.
class _Transform extends CardEffect:
	var from_id: String
	var to_id: String
	func _init(f: String, t: String) -> void:
		from_id = f
		to_id = t
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		var idx := d.played_pile.find(from_id)
		if idx == -1:
			return
		d.played_pile.remove_at(idx)
		d.discard_pile.append(to_id)
		resolver.log_event("transform", {"player_id": player_id, "from": from_id, "to": to_id})


## Giant Eagle: по войску в каждой локации, откуда вернули шпиона; supplant
## вместо assassinate, если Scout сыгран в этот ход или есть в руке.
class _EagleStrike extends CardEffect:
	var sites: Array
	func _init(s: Array) -> void:
		sites = s
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		var with_scout: bool = d.played_pile.has(CelestialCards.SCOUT) or d.hand.has(CelestialCards.SCOUT)
		for i in range(sites.size() - 1, -1, -1):
			var site: String = sites[i]
			if with_scout:
				resolver.push(SupplantTroop.new(1, false, true, false, Callable(), site), player_id)
			else:
				resolver.push(AssassinateTroop.new(1, false, false, false, 0, 0, site), player_id)
