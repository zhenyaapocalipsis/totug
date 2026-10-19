class_name SiegeCards
extends RefCounted

## Полуколода Siege — фанатская колода для Tyrants of the Underdark (cards/
## Siege_Deck.pdf), карты 49300-49319, тип SIEGE (этап Siege-1, 2026-10-13).
## Пока "wip": играется в режиме NEW ERA кнопкой SIEGE.
##
## Толкования:
##   "distinct card aspect you played this turn" — разные аспекты в
##       state.played_aspects_this_turn (сама карта тоже считается, Obedience тоже);
##   Relentless Siege — флаг хода "all_white": эффекты "a white troop" принимают
##       и войска соперников (counts_as_white);
##   Guardian Brute — реакция из руки: соперник заставил взять Insane Outcast,
##       сбросить карту или вернул твоего шпиона — за каждый Guardian Brute в
##       руке +1 VP (brute_reaction, без вопроса: отказываться незачем).

const HYDRA := "49307"
const PLUNDER := "49314"
const BALLISTA := "49315"
const SPOILS := "49306"
const BRUTE := "49318"


static func build(card_id: String) -> CardEffect:
	match card_id:
		"49300":  # Avatar of Lolth
			return ChooseEffect.new([
				SequenceEffect.new([PlaceSpy.new(1), DrawCards.new(1)]),
				ReturnOwnSpy.new(_ToTopOfDeck.new(card_id)),
			], ["Place a spy, then draw a card",
				"Return one of your spies -> Put a played card or a card from your discard pile on top of your deck"])
		"49301":  # Converter
			return PiltoverCards._AfterTroops.new(AssassinateTroop.new(1),
				func(s, pid, before): return SiegeCards._convert(s, pid, before))
		"49302":  # Relentless Siege
			return SequenceEffect.new([GainPower.new(3), ShadowCards._SetFlag.new("all_white")])
		"49303":  # Beast Tamer
			return SequenceEffect.new([GainInfluence.new(2), CelestialCards.TurnDiscount.new("recruit", 1)])
		"49304":  # Warlord
			return ChooseEffect.new([
				PlaceSpy.new(1),
				ReturnOwnSpy.new(SequenceEffect.new([GainInfluence.new(2), PromoteFromMarket.new()])),
			], ["Place a spy", "Return one of your spies -> +2 Influence, you may promote a market card for its cost"])
		"49305":  # Siege Beast
			return ChooseEffect.new([
				SequenceEffect.new([GainPower.new(1), GainInfluence.new(2)]),
				GainVP.new(1),
			], ["+1 Power, +2 Influence", "Gain 1 VP"])
		"49306":  # Spoils of War
			return _PerAspect.new(card_id)
		"49307":  # Hydra
			return SequenceEffect.new([AssassinateTroop.new(1), AtEndOfTurn.new(PromoteCard.new("played_other", card_id))])
		"49308":  # Scout Leader
			return _DeployPerAspect.new()
		"49309":  # Siege Tower
			return ChooseEffect.new([DrawCards.new(1), AtEndOfTurn.new(PromoteCard.new("played_other", card_id))],
				["Draw a card", "At end of turn, promote another card played this turn"])
		"49310":  # Shade Lingerer
			return PlaceSpy.new(1, false, func(site): return SiegeCards._MarkerEffect.new(site))
		"49311":  # Chieftain
			return SequenceEffect.new([SupplantTroop.new(1, true), if_four(GainVP.new(1))])
		"49312":  # Privateers
			return SequenceEffect.new([_inf_or_power(), _inf_or_power(), if_four(DrawCards.new(1))])
		"49313":  # Trebuchet
			var strike := ReturnTroopOrSpy.new(1, false, true)
			strike.anywhere = true
			return strike
		"49314":  # Plunder
			return _CopyPlayed.new(card_id, 4)
		"49315":  # Dread Ballista
			return SequenceEffect.new([GainPower.new(1), _Convert.new()])
		"49316":  # Ramming Beast
			return SequenceEffect.new([GainPower.new(1), GainInfluence.new(1),
				if_four(PromoteCard.new("played_other", card_id))])
		"49317":  # Underdark Champion
			return SequenceEffect.new([AssassinateTroop.new(1, true), if_four(SupplantTroop.new(1, true))])
		"49318":  # Guardian Brute — реакция: brute_reaction
			return DrawCards.new(1)
		"49319":  # Schemer
			return ChooseEffect.new([MoveSpy.new(true), MoveTroop.any(1)],
				["Move an enemy spy to another site", "Move a troop"])
	return null


## Сколько разных аспектов сыграно в этот ход.
static func distinct_aspects(state: GameState) -> int:
	var seen: Array[String] = []
	for aspect: String in state.played_aspects_this_turn:
		if not seen.has(aspect):
			seen.append(aspect)
	return seen.size()


## "If you played 4 distinct card aspects this turn ► X".
static func if_four(effect: CardEffect) -> CardEffect:
	return ConditionalEffect.new(func(state, _pid): return SiegeCards.distinct_aspects(state) >= 4, effect)


static func _inf_or_power() -> ChooseEffect:
	return ChooseEffect.new([GainInfluence.new(1), GainPower.new(1)], ["+1 Influence", "+1 Power"])


## Белое ли это войско для эффектов "a white troop" (Relentless Siege: и чужие).
static func counts_as_white(state: GameState, player_id: String, owner: String) -> bool:
	if owner == "white":
		return true
	return owner != "" and state.turn_flags.get("all_white", false) and player_id == state.current_player() \
		and state.is_enemy(player_id, owner)


## Guardian Brute: соперник by заставил victim взять Outcast, сбросить карту
## или вернул его шпиона — +1 VP за каждый Guardian Brute в руке victim.
static func brute_reaction(state: GameState, victim: String, by: String, resolver: EffectResolver = null) -> void:
	if by == "" or not state.players.has(victim) or not state.players.has(by) or not state.is_opponent(victim, by):
		return
	var p: PlayerState = state.players[victim]
	var shown: int = p.deck.hand.count(BRUTE)
	if shown == 0:
		return
	var granted: int = state.vp_bank.grant(shown)
	p.vp_tokens += granted
	if resolver != null:
		resolver.log_event("brute_reveal", {"player_id": victim, "card_id": BRUTE, "amount": granted})


## Converter: убитое войско соперника заменяется белым из его трофейного зала.
static func _convert(state: GameState, player_id: String, before: Dictionary) -> CardEffect:
	for slot_id: String in before.keys():
		var victim: String = before[slot_id]
		if victim == "" or victim == "white" or String(state.troops.get(slot_id, "")) != "":
			continue
		if state.is_enemy(player_id, victim) and state.players.has(victim) and state.stock(victim).take_trophy("white"):
			state.troops[slot_id] = "white"
	return null


## Spoils of War: столько выборов "+1 Influence / +1 Power", сколько разных аспектов.
class _PerAspect extends CardEffect:
	var card: String
	func _init(cid: String) -> void:
		card = cid
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		for i in range(SiegeCards.distinct_aspects(state)):
			var pick := SiegeCards._inf_or_power()
			pick.source_card = card
			resolver.push(pick, player_id)


class _DeployPerAspect extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var n := SiegeCards.distinct_aspects(state)
		if n > 0:
			resolver.push(DeployTroop.new(n), player_id)


## Avatar of Lolth: другая сыгранная карта или карта сброса — наверх колоды.
class _ToTopOfDeck extends CardEffect:
	var self_id: String
	func _init(cid: String) -> void:
		self_id = cid
	func _pool(state: GameState, player_id: String) -> Array:
		var deck: Deck = state.players[player_id].deck
		var pool: Array = deck.played_pile.duplicate()
		var own := pool.find(self_id)
		if own != -1:
			pool.remove_at(own)
		pool.append_array(deck.discard_pile)
		var unique: Array = []
		for cid in pool:
			if not unique.has(cid):
				unique.append(cid)
		return unique
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var deck: Deck = state.players[player_id].deck
		if is_answered():
			var chosen := String(answer())
			if chosen == "":
				return
			var idx := deck.played_pile.find(chosen)
			if chosen == self_id and deck.played_pile.count(chosen) < 2:
				idx = -1
			if idx != -1:
				deck.played_pile.remove_at(idx)
			else:
				idx = deck.discard_pile.find(chosen)
				if idx == -1:
					return
				deck.discard_pile.remove_at(idx)
			deck.draw_pile.append(chosen)
			resolver.log_event("to_top_of_deck", {"player_id": player_id, "card_id": chosen})
			return
		var pool := _pool(state, player_id)
		if pool.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Put a card on top of your deck"
		pd.choice_type = "target_card"
		pd.legal_options = pool
		pd.target_effect = self
		resolver.request_decision(pd)


## Warlord: "You may promote a card from the market for its cost".
class PromoteFromMarket extends CardEffect:
	func _options(state: GameState, player_id: String) -> Array:
		var out: Array = []
		var influence: int = state.players[player_id].influence
		for i in range(state.market.display.size()):
			var cid: String = state.market.display[i]
			if cid == "" or cid == MercenaryCards.SYLGAR:
				continue
			var cost := Actions.market_cost(state, i)
			if cost >= 0 and cost <= influence:
				out.append(i)
		return out
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var index = answer()
			if index == null or int(index) < 0 or not _options(state, player_id).has(int(index)):
				return
			var cost := Actions.market_cost(state, int(index))
			var card: String = state.market.recruit_at(int(index))
			if card == "":
				return
			state.players[player_id].influence -= cost
			state.stock(player_id).deck.inner_circle.append(card)
			resolver.log_event("promote", {"player_id": player_id, "card_id": card, "from": "market"})
			ShurimaCards.on_promote(state, player_id, String(card), resolver)
			if state.market.is_deck_empty():
				GameEnd.trigger(state, "market_empty")
			return
		var options := _options(state, player_id)
		if options.is_empty():
			return
		options.append(-1)
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "You may promote a market card for its cost"
		pd.choice_type = "target_market_index"
		pd.tag = "market"
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)


## Shade Lingerer: маркер локации шпиона твой — его доход ещё раз (Influence,
## при тотальном контроле и VP).
class _MarkerEffect extends CardEffect:
	var site: String
	func _init(s: String) -> void:
		site = s
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var marker := ControlMarkers.marker_for(state, site)
		if marker.is_empty() or not ControlMarkers.holds(state, player_id, site):
			return
		var influence := int(marker.get("control_influence", 0))
		state.players[player_id].influence += influence
		resolver.log_event("marker_effect", {"player_id": player_id, "site_id": site, "influence": influence})
		if state.control.has_total_control(player_id, site, state.troops, state.spies):
			resolver.push(GainVP.new(int(marker.get("total_control_vp", 0))), player_id)


## Plunder: повторить эффект другой сыгранной карты стоимостью до max_cost.
class _CopyPlayed extends CardEffect:
	var self_id: String
	var max_cost: int
	func _init(cid: String, limit: int) -> void:
		self_id = cid
		max_cost = limit
	func _pool(state: GameState, player_id: String) -> Array:
		var out: Array = []
		for cid: String in state.players[player_id].deck.played_pile:
			if cid == SiegeCards.PLUNDER or out.has(cid) or CardLibrary.card_cost(cid) > max_cost:
				continue
			out.append(cid)
		return out
	func is_available(state: GameState, player_id: String) -> bool:
		return not _pool(state, player_id).is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var chosen := String(answer())
			if _pool(state, player_id).has(chosen):
				resolver.log_event("copy_card", {"player_id": player_id, "card_id": chosen})
				resolver.push(CardLibrary.get_effect(chosen), player_id)
			return
		var pool := _pool(state, player_id)
		if pool.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Copy a played card (cost 4 or less)"
		pd.choice_type = "target_card"
		pd.legal_options = pool
		pd.target_effect = self
		resolver.request_decision(pd)


## Dread Ballista: "You may convert up to 3 Influence to Power".
class _Convert extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var most := mini(3, state.players[player_id].influence)
		if most <= 0:
			return
		var options: Array[CardEffect] = [SequenceEffect.new([])]
		var labels: Array[String] = ["Keep your Influence"]
		for k in range(1, most + 1):
			options.append(SiegeCards._ConvertN.new(k))
			labels.append("Convert %d Influence to Power" % k)
		var pick := ChooseEffect.new(options, labels, "Convert Influence to Power?")
		pick.source_card = SiegeCards.BALLISTA
		resolver.push(pick, player_id)


class _ConvertN extends CardEffect:
	var amount: int
	func _init(n: int) -> void:
		amount = n
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var p: PlayerState = state.players[player_id]
		var k := mini(amount, p.influence)
		p.influence -= k
		p.power += k
		resolver.log_event("convert", {"player_id": player_id, "amount": k})


## "Move an enemy spy to another site" (Schemer, enemy=true; нужно Присутствие
## на его локации) / "move one of your spies" — своего, где угодно (enemy=false) /
## "move a spy" (any_spy: Shady Merchant, Groundling Stalker) — своего где угодно
## или чужого в своём Присутствии (владелец, 2026-10-19: move — из зоны своего
## Присутствия в любое место).
class MoveSpy extends CardEffect:
	var enemy: bool
	var any_spy := false
	var _spy := ""
	func _init(of_enemy: bool, of_anyone: bool = false) -> void:
		enemy = of_enemy
		any_spy = of_anyone
	func _sources(state: GameState, player_id: String) -> Array:
		var out: Array = []
		for site_id: String in state.spies.keys():
			var present: bool = state.presence.has_presence_at_site(player_id, site_id, state.troops, state.spies)
			if enemy and not present:
				continue
			for owner: String in state.spies[site_id]:
				var movable := (enemy and state.is_opponent(player_id, owner)) or (not enemy and owner == player_id)
				if any_spy:
					movable = owner == player_id or (present and state.is_opponent(player_id, owner))
				if movable:
					var option := "spy%s%s%s%s" % [ReturnTroopOrSpy.SEP, site_id, ReturnTroopOrSpy.SEP, owner]
					if not out.has(option):
						out.append(option)
		return out
	func is_available(state: GameState, player_id: String) -> bool:
		return not _sources(state, player_id).is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var value := String(answer())
			_answered = false
			_answer = null
			if _spy == "":
				if value == "" or not _sources(state, player_id).has(value):
					return
				_spy = value
				var parts := _spy.split(ReturnTroopOrSpy.SEP)
				var dest: Array = []
				for site_id: String in state.graph.sites.keys():
					if site_id != parts[1] and not (state.spies.get(site_id, []) as Array).has(parts[2]):
						dest.append(site_id)
				if dest.is_empty():
					return
				_ask(player_id, resolver, "Move the spy to", "target_site", dest)
				return
			var parts := _spy.split(ReturnTroopOrSpy.SEP)
			var from: Array = state.spies.get(parts[1], [])
			var idx := from.find(parts[2])
			if idx == -1 or value == "":
				return
			from.remove_at(idx)
			state.spies[parts[1]] = from
			var to: Array = state.spies.get(value, [])
			to.append(parts[2])
			state.spies[value] = to
			resolver.log_event("move_spy", {"player_id": player_id, "from": parts[1], "to": value, "owner": parts[2]})
			return
		var sources := _sources(state, player_id)
		if sources.is_empty():
			return
		var prompt := "Move an enemy spy" if enemy else ("Move a spy" if any_spy else "Move one of your spies")
		_ask(player_id, resolver, prompt, "target_return", sources)
	func _ask(player_id: String, resolver: EffectResolver, prompt: String, kind: String, options: Array) -> void:
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = prompt
		pd.choice_type = kind
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)
