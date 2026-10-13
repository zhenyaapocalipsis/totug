class_name MercenaryCards
extends RefCounted

## Полуколода Mercenaries — фанатская колода для Tyrants of the Underdark
## (cards/Mercenaries_-_Full_deck.pdf), карты 49400-49419, тип MERCENARY
## (этап Merc-1, 2026-10-13). Пока "wip": режим NEW ERA, кнопка MERCENARIES.
##
## Правила владельца (2026-10-13):
##   Bribe ► X — отдать 1 жетон VP сопернику на выбор (числа на картах нет,
##       значит 1); без жетона подкупить нельзя. В "Choose one" это вариант,
##       отдельной строкой — вопрос "подкупить?".
##   Steal N VP — забрать до N жетонов VP у соперника; жетонов нет — ничего.
## Толкования:
##   Sylgar — "put it back where it was": карта остаётся на месте, VP получает
##       хозяин карты (на рынке — тот, кто сожрал);
##   Jarlaxle — карта соперника идёт в его сброс, её эффект работает на него,
##       а все её вопросы задают разыгравшему Jarlaxle (EffectResolver.deciders);
##   Nar'l Xibrindas — взятая карта ложится в твой сброс, Nar'l — в чужой;
##   "adjacent" — соседний слот или та же локация (как в Waterdeep).

const SYLGAR := "49416"
const ZUSHAXX := "49418"


static func build(card_id: String) -> CardEffect:
	match card_id:
		"49400":  # Goblinoid Ambushers
			return ChooseEffect.new([GainPower.new(1), StealVP.new(1), Bribe.new(GainPower.new(3))],
				["+1 Power", "Steal 1 VP", "Bribe -> +3 Power"])
		"49401":  # Hobgoblin Warlord
			return SequenceEffect.new([GainPower.new(3),
				maybe_bribe(CelestialCards.TurnDiscount.new("assassinate", 1), "Assassinate costs 2 Power this turn")])
		"49402":  # Artemis Entreri
			return PiltoverCards._AfterTroops.new(AssassinateTroop.new(3, false, false, true),
				func(s, _pid, before): return MercenaryCards._entreri_vp(s, before))
		"49403":  # Goblin Swarm
			return SequenceEffect.new([DeployTroop.new(1), maybe_bribe(DeployTroop.new(2), "Deploy 2 troops")])
		"49404":  # Bugbear
			return SequenceEffect.new([DeployTroop.new(1), AssassinateTroop.new(1, true), GainVP.new(1)])
		"49405":  # Dragonborn Hireling
			return SequenceEffect.new([AssassinateTroop.new(1), ConditionalEffect.new(
				func(s, pid): return s.stock(pid).player_trophy_count() >= 3, GainVP.new(1))])
		"49406":  # Bregan D'aerthe Agents
			var picks: Array[CardEffect] = []
			for i in range(3):
				picks.append(ChooseEffect.new([
					TakeFromTrophyHall.new(1, false, true, "", false),
					Bribe.new(SupplantTroop.new(1, true)),
				], ["Take a white troop from any trophy hall and deploy it", "Bribe -> Supplant a white troop"]))
			return SequenceEffect.new(picks)
		"49407":  # Nihiloor
			return _Nihiloor.new()
		"49408":  # Goblin Thief
			return PlaceSpy.new(1, false, func(site): return MercenaryCards.StealVP.new(1, site))
		"49409":  # Bazaar Trader
			return ChooseEffect.new([
				_DiscardThen.new(SequenceEffect.new([GainVP.new(1), DrawCards.new(1)])),
				Bribe.new(SequenceEffect.new([PlaceSpy.new(1), DrawCards.new(2)])),
				ReturnOwnSpy.new(StealVP.new(3)),
			], ["Discard a card -> Gain 1 VP and draw a card", "Bribe -> Place a spy and draw 2 cards",
				"Return one of your spies -> Steal 3 VP"])
		"49410":  # Security Guard
			return _SecurityGuard.new()
		"49411":  # Bregan D'aerthe Spy
			return ChooseEffect.new([
				PlaceSpy.new(1),
				ReturnOwnSpy.new(null, func(site): return MercenaryCards._StealMarker.new(site)),
			], ["Place a spy", "Return one of your spies -> Steal that site's control marker until your next turn"])
		"49412":  # Nar'l Xibrindas
			return ChooseEffect.new([
				PlaceSpy.new(1),
				ReturnOwnSpy.new(null, func(site): return MercenaryCards._NarlSwap.new(site, card_id)),
			], ["Place a spy", "Return one of your spies -> Swap this card with a card in a rival's discard pile"])
		"49413":  # Jarlaxle
			return _Jarlaxle.new()
		"49414":  # Xanathar Smuggler
			return SequenceEffect.new([GainInfluence.new(1),
				maybe_bribe(AtEndOfTurn.new(PromoteCard.new("played_other", card_id)), "At end of turn, promote another card played this turn")])
		"49415":  # Shady Merchant
			return SequenceEffect.new([
				ReturnTroopOrSpy.new(1, false, true),
				SiegeCards.MoveSpy.new(false),
				maybe_bribe(_GiftPlayed.new(card_id), "Put another card played this turn on top of an opponent's deck"),
			])
		"49416":  # Sylgar — своего эффекта нет: sylgar_saves
			return SequenceEffect.new([])
		"49417":  # Ahmaergo
			var twice: Array[CardEffect] = []
			for i in range(2):
				twice.append(ChooseEffect.new([
					SequenceEffect.new([MoveTroop.new(1, false, true), GainInfluence.new(1)]),
					Bribe.new(_SwapTroops.new()),
				], ["Move one of your troops and gain 1 Influence", "Bribe -> Swap 2 troops anywhere on the board"]))
			return SequenceEffect.new(twice)
		"49418":  # Xanathar Zushaxx — кража после покупки: after_buy
			return SequenceEffect.new([GainInfluence.new(4), ShadowCards._SetFlag.new("recruit_steal")])
		"49419":  # Xanathar Surveillance
			return _Surveillance.new()
	return null


## "Bribe ► X" отдельной строкой: спросить, только если подкуп возможен.
static func maybe_bribe(effect: CardEffect, what: String) -> CardEffect:
	var bribe := Bribe.new(effect)
	return ConditionalEffect.new(func(s, pid): return bribe.is_available(s, pid),
		OptionalEffect.new(bribe, "Bribe (give 1 VP to an opponent): %s?" % what))


## Sylgar: его сожрали, продвинули или сбросили картой — он остаётся на месте,
## player_id получает 1 VP. true — карта спасена, удалять её не надо.
static func sylgar_saves(state: GameState, player_id: String, card_id: String, resolver: EffectResolver) -> bool:
	if card_id != SYLGAR or not state.players.has(player_id):
		return false
	var granted: int = state.vp_bank.grant(1)
	state.players[player_id].vp_tokens += granted
	if resolver != null:
		resolver.log_event("sylgar", {"player_id": player_id, "card_id": SYLGAR, "amount": granted})
	return true


## Xanathar Zushaxx: после каждой покупки в этот ход — кража 1 VP.
static func after_buy(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if player_id != state.current_player() or not state.turn_flags.get("recruit_steal", false):
		return
	var steal := StealVP.new(1)
	if not steal.is_available(state, player_id):
		return
	if resolver.is_waiting():
		resolver.pending.stack.insert(0, {"effect": steal, "player_id": player_id, "card": ZUSHAXX})
		return
	resolver.apply(steal, player_id, state, ZUSHAXX)


## Artemis Entreri: локация, где убивали, опустела — +1 VP.
static func _entreri_vp(state: GameState, before: Dictionary) -> CardEffect:
	for slot_id: String in before.keys():
		if String(before[slot_id]) == "" or String(state.troops.get(slot_id, "")) != "":
			continue
		var site := state.graph.site_of_slot(slot_id)
		if site == "":
			return null
		for other: String in state.graph.slots_of_site(site):
			if String(state.troops.get(other, "")) != "":
				return null
		return GainVP.new(1)
	return null


## Соседство для "adjacent": соседние слоты и слоты той же локации.
static func near_slots(state: GameState, slot_id: String) -> Array:
	var near: Array = Array(state.graph.adjacent_slots(slot_id))
	var site := state.graph.site_of_slot(slot_id)
	if site != "":
		for other: String in state.graph.slots_of_site(site):
			if other != slot_id and not near.has(other):
				near.append(other)
	return near


static func _ask(effect: CardEffect, player_id: String, resolver: EffectResolver, prompt: String,
		kind: String, options: Array, tag: String = "") -> void:
	var pd := PendingDecision.new()
	pd.player_id = player_id
	pd.prompt = prompt
	pd.choice_type = kind
	pd.legal_options = options
	pd.tag = tag
	pd.target_effect = effect
	resolver.request_decision(pd)


## Bribe ► then: отдать 1 VP сопернику на выбор, затем then.
class Bribe extends CardEffect:
	var then_effect: CardEffect
	func _init(effect: CardEffect) -> void:
		then_effect = effect
	func _rivals(state: GameState, player_id: String) -> Array:
		var out: Array = []
		for pid: String in state.turn_order:
			if state.is_opponent(player_id, pid):
				out.append(pid)
		return out
	func is_available(state: GameState, player_id: String) -> bool:
		return state.players[player_id].vp_tokens > 0 and not _rivals(state, player_id).is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if not is_available(state, player_id):
			return
		var rivals := _rivals(state, player_id)
		if is_answered():
			var to := String(answer())
			if rivals.has(to):
				_pay(state, player_id, to, resolver)
			return
		if rivals.size() == 1:
			_pay(state, player_id, rivals[0], resolver)
			return
		MercenaryCards._ask(self, player_id, resolver, "Bribe: give 1 VP to", "target_player", rivals)
	func _pay(state: GameState, player_id: String, to: String, resolver: EffectResolver) -> void:
		state.players[player_id].vp_tokens -= 1
		state.players[to].vp_tokens += 1
		resolver.log_event("bribe", {"player_id": player_id, "to": to, "amount": 1})
		resolver.push(then_effect, player_id)


## Steal N VP: у соперника на выбор (site — только с войском на этой локации).
class StealVP extends CardEffect:
	var amount: int
	var site: String
	func _init(n: int, at_site: String = "") -> void:
		amount = n
		site = at_site
	func _victims(state: GameState, player_id: String) -> Array:
		var pool: Array = []
		if site != "":
			pool = Array(CardLibrary._enemy_troop_owners_at_site(state, player_id, site))
		else:
			for pid: String in state.turn_order:
				if state.is_opponent(player_id, pid):
					pool.append(pid)
		return pool.filter(func(pid): return state.players[pid].vp_tokens > 0 and state.is_opponent(player_id, pid))
	func is_available(state: GameState, player_id: String) -> bool:
		return not _victims(state, player_id).is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var victims := _victims(state, player_id)
		if is_answered():
			var from := String(answer())
			if victims.has(from):
				MercenaryCards.steal(state, player_id, from, amount, resolver)
			return
		if victims.is_empty():
			return
		if victims.size() == 1:
			MercenaryCards.steal(state, player_id, victims[0], amount, resolver)
			return
		MercenaryCards._ask(self, player_id, resolver, "Steal %d VP from" % amount, "target_player", victims)


static func steal(state: GameState, player_id: String, from: String, amount: int, resolver: EffectResolver) -> void:
	var victim: PlayerState = state.players[from]
	var taken := mini(amount, victim.vp_tokens)
	if taken <= 0:
		return
	victim.vp_tokens -= taken
	state.players[player_id].vp_tokens += taken
	resolver.log_event("steal_vp", {"player_id": player_id, "from": from, "amount": taken})


## Security Guard: 2 войска, потом по 1 VP у каждого соперника с войском рядом.
class _SecurityGuard extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var deploy := DeployTroop.new(2)
		var placed: Array = deploy.deployed
		resolver.push(CallbackEffect.new(func(s: GameState, pid: String, r: EffectResolver):
			var robbed: Array[String] = []
			for slot_id: String in placed:
				for other: String in MercenaryCards.near_slots(s, slot_id):
					var owner: String = s.troops.get(other, "")
					if owner != "" and owner != "white" and s.is_opponent(pid, owner) and not robbed.has(owner):
						robbed.append(owner)
			for victim: String in robbed:
				MercenaryCards.steal(s, pid, victim, 1, r)), player_id)
		resolver.push(deploy, player_id)


## Nihiloor: 3 войска; Bribe — подвинуть их; белое войско рядом с каждым — убить.
class _Nihiloor extends CardEffect:
	func apply(_state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var deploy := DeployTroop.new(3)
		var placed: Array = deploy.deployed
		resolver.push(CallbackEffect.new(func(s: GameState, pid: String, r: EffectResolver):
			r.push(MercenaryCards._NihiloorStrike.new(placed), pid)
			if not placed.is_empty():
				var move := MoveTroop.new(placed.size(), true, true)
				move.only_slots = placed
				var ask := MercenaryCards.maybe_bribe(move, "Move the deployed troops")
				r.push(ask, pid)), player_id)
		resolver.push(deploy, player_id)


class _NihiloorStrike extends CardEffect:
	var placed: Array
	func _init(slots: Array) -> void:
		placed = slots
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		for i in range(placed.size() - 1, -1, -1):
			var near := MercenaryCards.near_slots(state, String(placed[i]))
			if near.is_empty():
				continue
			var strike := AssassinateTroop.new(1, true)
			strike.only_slots = near
			strike.site_given_by_card = true
			resolver.push(strike, player_id)


## "Discard a card ► X" вариантом выбора: нужна карта в руке.
class _DiscardThen extends CardEffect:
	var then_effect: CardEffect
	func _init(effect: CardEffect) -> void:
		then_effect = effect
	func is_available(state: GameState, player_id: String) -> bool:
		return not state.players[player_id].deck.hand.is_empty()
	func apply(_state: GameState, player_id: String, resolver: EffectResolver) -> void:
		resolver.push(then_effect, player_id)
		resolver.push(DiscardCardEffect.new(1), player_id)


## Bregan D'aerthe Spy: маркер локации — твой до начала твоего следующего хода.
class _StealMarker extends CardEffect:
	var site: String
	func _init(s: String) -> void:
		site = s
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if ControlMarkers.marker_for(state, site).is_empty():
			return
		state.stolen_markers[site] = player_id
		resolver.log_event("steal_marker", {"player_id": player_id, "site_id": site})


## Nar'l Xibrindas: карта из сброса соперника с войском на локации <-> Nar'l.
class _NarlSwap extends CardEffect:
	var site: String
	var self_id: String
	var _rival := ""
	func _init(s: String, cid: String) -> void:
		site = s
		self_id = cid
	func _rivals(state: GameState, player_id: String) -> Array:
		return Array(CardLibrary._enemy_troop_owners_at_site(state, player_id, site)).filter(
			func(pid): return not state.players[pid].deck.discard_pile.is_empty())
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var mine: Deck = state.players[player_id].deck
		if not mine.played_pile.has(self_id):
			return
		if is_answered():
			var value := String(answer())
			_answered = false
			_answer = null
			if _rival == "":
				if not _rivals(state, player_id).has(value):
					return
				_rival = value
				_ask_card(state, player_id, resolver)
				return
			var theirs: Deck = state.players[_rival].deck
			var idx := theirs.discard_pile.find(value)
			if idx == -1:
				return
			theirs.discard_pile.remove_at(idx)
			mine.played_pile.remove_at(mine.played_pile.find(self_id))
			theirs.discard_pile.append(self_id)
			mine.discard_pile.append(value)
			resolver.log_event("swap_card", {"player_id": player_id, "with": _rival, "card_id": value, "given": self_id})
			return
		var rivals := _rivals(state, player_id)
		if rivals.is_empty():
			return
		if rivals.size() == 1:
			_rival = rivals[0]
			_ask_card(state, player_id, resolver)
			return
		MercenaryCards._ask(self, player_id, resolver, "Whose discard pile?", "target_player", rivals)
	func _ask_card(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var pool: Array = []
		for cid: String in state.players[_rival].deck.discard_pile:
			if not pool.has(cid):
				pool.append(cid)
		MercenaryCards._ask(self, player_id, resolver, "Take a card from %s's discard pile" % _rival.capitalize(),
			"target_card", pool)


## Jarlaxle: карта из руки соперника играется за него, решает разыгравший.
class _Jarlaxle extends CardEffect:
	var _rival := ""
	func _rivals(state: GameState, player_id: String) -> Array:
		var out: Array = []
		for pid: String in state.turn_order:
			if state.is_opponent(player_id, pid) and not state.players[pid].deck.hand.is_empty():
				out.append(pid)
		return out
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var value := String(answer())
			_answered = false
			_answer = null
			if _rival == "":
				if not _rivals(state, player_id).has(value):
					return
				_rival = value
				_ask_card(state, player_id, resolver)
				return
			_play(state, player_id, value, resolver)
			return
		var rivals := _rivals(state, player_id)
		if rivals.is_empty():
			return
		if rivals.size() == 1:
			_rival = rivals[0]
			_ask_card(state, player_id, resolver)
			return
		MercenaryCards._ask(self, player_id, resolver, "Look at whose hand?", "target_player", rivals)
	func _ask_card(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var pool: Array = []
		for cid: String in state.players[_rival].deck.hand:
			if not pool.has(cid):
				pool.append(cid)
		MercenaryCards._ask(self, player_id, resolver, "%s plays a card of your choice" % _rival.capitalize(),
			"target_card", pool)
	func _play(state: GameState, player_id: String, card: String, resolver: EffectResolver) -> void:
		var theirs: Deck = state.players[_rival].deck
		var idx := theirs.hand.find(card)
		if idx == -1:
			return
		theirs.hand.remove_at(idx)
		theirs.played_pile.append(card)
		resolver.log_event("jarlaxle", {"player_id": player_id, "rival": _rival, "card_id": card})
		var rival := _rival
		resolver.push(MercenaryCards.maybe_bribe(MercenaryCards._PlayAs.new(card), "Copy that card's effect"), player_id, card)
		resolver.push(CallbackEffect.new(func(s: GameState, _pid: String, r: EffectResolver):
			r.deciders.erase(rival)
			var d: Deck = s.players[rival].deck
			var at := d.played_pile.find(card)
			if at != -1:
				d.played_pile.remove_at(at)
				d.discard_pile.append(card)), player_id)
		resolver.deciders[rival] = player_id
		resolver.push(CardLibrary.get_effect(card), rival, card)


class _PlayAs extends CardEffect:
	var card: String
	func _init(cid: String) -> void:
		card = cid
	func apply(_state: GameState, player_id: String, resolver: EffectResolver) -> void:
		resolver.push(CardLibrary.get_effect(card), player_id, card)


## Shady Merchant: другая сыгранная карта — наверх колоды соперника.
class _GiftPlayed extends CardEffect:
	var self_id: String
	var _card := ""
	func _init(cid: String) -> void:
		self_id = cid
	func _pool(state: GameState, player_id: String) -> Array:
		var played: Array = state.players[player_id].deck.played_pile.duplicate()
		var own := played.find(self_id)
		if own != -1:
			played.remove_at(own)
		var out: Array = []
		for cid in played:
			if not out.has(cid):
				out.append(cid)
		return out
	func _rivals(state: GameState, player_id: String) -> Array:
		var out: Array = []
		for pid: String in state.turn_order:
			if state.is_opponent(player_id, pid):
				out.append(pid)
		return out
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var value := String(answer())
			_answered = false
			_answer = null
			if _card == "":
				if not _pool(state, player_id).has(value):
					return
				_card = value
				var rivals := _rivals(state, player_id)
				if rivals.size() == 1:
					_give(state, player_id, rivals[0], resolver)
					return
				MercenaryCards._ask(self, player_id, resolver, "Put it on top of whose deck?", "target_player", rivals)
				return
			if _rivals(state, player_id).has(value):
				_give(state, player_id, value, resolver)
			return
		var pool := _pool(state, player_id)
		if pool.is_empty() or _rivals(state, player_id).is_empty():
			return
		MercenaryCards._ask(self, player_id, resolver, "Give a played card to an opponent", "target_card", pool)
	func _give(state: GameState, player_id: String, to: String, resolver: EffectResolver) -> void:
		var mine: Deck = state.players[player_id].deck
		var idx := mine.played_pile.find(_card)
		if _card == self_id:
			idx = mine.played_pile.rfind(_card)
			if mine.played_pile.count(_card) < 2:
				return
		if idx == -1:
			return
		mine.played_pile.remove_at(idx)
		state.players[to].deck.draw_pile.append(_card)
		resolver.log_event("gift_card", {"player_id": player_id, "to": to, "card_id": _card})


## Ahmaergo: поменять местами два войска разных цветов где угодно.
class _SwapTroops extends CardEffect:
	var _first := ""
	func _troops(state: GameState, other_than: String = "") -> Array:
		var out: Array = []
		for slot_id: String in state.graph.slots.keys():
			var owner: String = state.troops.get(slot_id, "")
			if owner == "" or slot_id == other_than:
				continue
			if other_than != "" and owner == String(state.troops.get(other_than, "")):
				continue
			out.append(slot_id)
		return out
	func is_available(state: GameState, _player_id: String) -> bool:
		var colours: Array = []
		for slot_id: String in state.graph.slots.keys():
			var owner: String = state.troops.get(slot_id, "")
			if owner != "" and not colours.has(owner):
				colours.append(owner)
		return colours.size() >= 2
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var value := String(answer())
			_answered = false
			_answer = null
			if _first == "":
				if not _troops(state).has(value):
					return
				_first = value
				MercenaryCards._ask(self, player_id, resolver, "Swap it with", "target_slot", _troops(state, _first))
				return
			if not _troops(state, _first).has(value):
				return
			var a: String = state.troops[_first]
			state.troops[_first] = state.troops[value]
			state.troops[value] = a
			resolver.log_event("swap_troops", {"player_id": player_id, "a": _first, "b": value})
			return
		if not is_available(state, player_id):
			return
		MercenaryCards._ask(self, player_id, resolver, "Swap 2 troops: pick the first", "target_slot", _troops(state))


## Xanathar Surveillance: 3 карты, 2 из них сбросить; Bribe — продвинуть одну из сброшенных.
class _Surveillance extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var before: Array = state.players[player_id].deck.hand.duplicate()
		resolver.push(CallbackEffect.new(func(s: GameState, pid: String, r: EffectResolver):
			var drawn: Array = s.players[pid].deck.hand.duplicate()
			for cid in before:
				var at := drawn.find(cid)
				if at != -1:
					drawn.remove_at(at)
			r.push(MercenaryCards._DiscardDrawn.new(drawn, mini(2, drawn.size())), pid)), player_id)
		resolver.push(DrawCards.new(3), player_id)


class _DiscardDrawn extends CardEffect:
	var drawn: Array
	var remaining: int
	var discarded: Array = []
	func _init(cards: Array, n: int) -> void:
		drawn = cards
		remaining = n
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var hand: Array = state.players[player_id].deck.hand
		if is_answered():
			var value := String(answer())
			_answered = false
			_answer = null
			var at := drawn.find(value)
			if at != -1 and hand.has(value):
				drawn.remove_at(at)
				remaining -= 1
				if not MercenaryCards.sylgar_saves(state, player_id, value, resolver):
					hand.remove_at(hand.find(value))
					state.players[player_id].deck.discard_pile.append(value)
					discarded.append(value)
					resolver.log_event("discard", {"player_id": player_id, "card_id": value})
		var options: Array = []
		for cid in drawn:
			if hand.has(cid) and not options.has(cid):
				options.append(cid)
		if remaining > 0 and not options.is_empty():
			MercenaryCards._ask(self, player_id, resolver, "Discard one of the drawn cards", "target_card", options, "hand")
			return
		if discarded.is_empty():
			return
		resolver.push(MercenaryCards.maybe_bribe(MercenaryCards._PromoteDiscarded.new(discarded),
			"Promote one of the discarded cards"), player_id)


## Xanathar Surveillance, Bribe: продвинуть одну из ТОЛЬКО ЧТО сброшенных карт —
## вариантов ровно столько, сколько сброшено (не все копии того же номера в сбросе).
class _PromoteDiscarded extends CardEffect:
	var cards: Array
	func _init(list: Array) -> void:
		cards = list
	func _options(state: GameState, player_id: String) -> Array:
		var pile: Array = state.players[player_id].deck.discard_pile.duplicate()
		var out: Array = []
		for cid in cards:
			var at := pile.find(cid)
			if at != -1:
				pile.remove_at(at)
				out.append(cid)
		return out
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var options := _options(state, player_id)
		if is_answered():
			var chosen := String(answer())
			if not options.has(chosen):
				return
			var deck: Deck = state.players[player_id].deck
			deck.discard_pile.remove_at(deck.discard_pile.rfind(chosen))
			if Supplies.redirect_outcast(state, player_id, chosen, resolver):
				return
			state.stock(player_id).deck.inner_circle.append(chosen)
			resolver.log_event("promote", {"player_id": player_id, "card_id": chosen})
			return
		if options.is_empty():
			return
		MercenaryCards._ask(self, player_id, resolver, "Promote one of the discarded cards", "target_card", options, "discard")
