class_name ShurimaCards
extends RefCounted

## Полуколода Shurima (New Era) — способности карт Shurima из фан-мода
## Runeterra Reforged на существах пустыни (CALIMSHAN): латунные драконы,
## мефиты, чудища песков (без зверей — правило владельца). Таблица id -> существо -> карта мода —
## Claude outputs/new_era_shurima.md.
##
## Перевод на правила этой игры:
##   Valor   -> MALICE;
##   Execute -> Devour.
## Владелец (2026-10-16): вместо Azir — Naafiri (Extra Champions мода), в колоде
## все 45 карт мода (21 уникальная), урезать до 40/20 владелец решит сам.
##
## Devotion (правило мода): "You may activate a card's Devotion ability when it is
## either recruited or promoted". Срабатывает у игрока, который карту нанял (покупка
## на рынке, бесплатный найм) или продвинул во Внутренний круг (любой путь promote).
## Все пути зовут on_recruit / on_promote. Эффекты Devotion выгодны всегда, поэтому
## применяются без вопроса; вопрос только у Deva ("put this card on top").
##
## Счётчики хода — state.turn_flags (сбрасываются в start_turn):
##   "devotion_power" — {id игрока: +Power за каждое срабатывание Devotion} (Goblin Warrior);
##   "naafiri"        — id игрока, у которого действует Roper;
##   "naafiri_from"   — сколько карт было сыграно до Roper;
##   "naafiri_used"   — сколько раз Deploy уже вернул 1 Power;
##   "no_recruit"     — карты рынка, которые нельзя нанять в этот ход (Tough).

const ZOMBIE := "49700"  # Voice of the Risen
const COCKATRICE := "49701"  # Baccai Witherclaw
const WYRMLING := "49702"  # Sandcrafter
const STEAM_MEPHIT := "49703"  # Reaper of the Sands
const COMMONER := "49704"  # Dunekeeper
const TOUGH := "49705"  # Inspiring Marshal
const INCUBUS := "49706"  # Darkinthrall
const GOBLIN_WARRIOR := "49707"  # Rampaging Baccai
const GOBLIN_MINION := "49708"  # Baccai Reaper
const DRAGON_TURTLE := "49709"  # Bloodthirsty Marauder
const MAGMA_MEPHIT := "49710"  # Priestess of Desert Light
const ROPER := "49711"  # Naafiri
const ANCIENT_BRASS := "49712"  # Xerath
const PURPLE_WORM := "49713"  # Renekton
const NAGA := "49714"  # Nasus
const ADULT_BRASS := "49715"  # Sivir
const STONE_GIANT := "49716"  # Taliyah
const GORGON := "49717"  # K'Sante
const ANKHEG := "49718"  # Rammus: реакция из руки — ShieldGuard
const DUST_MEPHIT := "49719"  # Amumu
const DEVA := "49720"  # Akshan


static func build(card_id: String) -> CardEffect:
	match card_id:
		ZOMBIE:
			return SequenceEffect.new([DeployTroop.new(2), ReturnTroopOrSpy.new(1)])
		COCKATRICE:
			return ChooseEffect.new([_TriggerAnother.new(), _InnerToHand.new(), GainPower.new(2)],
				["Trigger the Devotion of another card you played this turn",
					"Return a card from your inner circle to your hand, draw a card", "+2 Power"])
		WYRMLING:
			return PiltoverCards._AfterTroops.new(DeployTroop.new(3), func(state, pid, before):
				if PiltoverCards._moved_next_to_other(state, pid, before):
					return PromoteCard.new("hand_or_discard", "", Callable(), 1, true)
				return null)
		STEAM_MEPHIT:
			return ChooseEffect.new([
				SequenceEffect.new([PlaceSpy.new(1), ScryCards.new(3)]),
				ReturnOwnSpy.new(_TopPick.new(3)),
			], ["Place a spy, scry 3",
				"Return one of your spies -> look at the top 3 cards of your deck, put 1 in your hand, discard the rest"])
		COMMONER:
			return ChooseEffect.new([GainInfluence.new(2), AtEndOfTurn.new(PromoteCard.new("played_other", COMMONER))],
				["+2 Influence", "At end of turn, promote another card played this turn"])
		TOUGH:
			return SequenceEffect.new([GainInfluence.new(2), _Marshal.new()])
		INCUBUS:
			return ChooseEffect.new([
				PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
					func(state, _pid): return ShurimaCards._site_full(state, site), GainPower.new(3))),
				ReturnOwnSpy.new(null, func(site): return SequenceEffect.new([
					SupplantTroop.new(1, false, false, false, Callable(), site), GainPower.new(2)])),
			], ["Place a spy (site full: +3 Power)",
				"Return one of your spies -> supplant a troop at that site, +2 Power"])
		GOBLIN_WARRIOR:
			return SequenceEffect.new([
				_AddDevotionPower.new(),
				ChooseEffect.new([DeployTroop.new(3), SupplantTroop.new(1, true)],
					["Deploy 3 troops", "Supplant a white troop"]),
			])
		GOBLIN_MINION:
			return ChooseEffect.new([
				PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
					func(state, _pid): return ShurimaCards._site_full(state, site),
					AtEndOfTurn.new(PromoteCard.new("played_other", GOBLIN_MINION)))),
				ReturnOwnSpy.new(null, func(site): return SupplantTroop.new(1, false, false, false, Callable(), site)),
			], ["Place a spy (site full: at end of turn, promote another card played this turn)",
				"Return one of your spies -> supplant a troop at that site"])
		DRAGON_TURTLE:
			return ChooseEffect.new([DevourCard.new("hand", "", DrawCards.new(1), false), SupplantTroop.new(1)],
				["Devour a card in your hand -> draw a card", "Supplant a troop"])
		MAGMA_MEPHIT:
			var parts: Array = [
				["+1 Influence", func(): return GainInfluence.new(1)],
				["+1 Power", func(): return GainPower.new(1)],
				["Place a spy", func(): return PlaceSpy.new(1)],
				["Deploy 2 troops", func(): return DeployTroop.new(2)],
			]
			var opts: Array[CardEffect] = []
			var labels: Array[String] = []
			for i in range(parts.size()):
				for j in range(i + 1, parts.size()):
					opts.append(SequenceEffect.new([parts[i][1].call(), parts[j][1].call()]))
					labels.append("%s, %s" % [parts[i][0], parts[j][0]])
			return ChooseEffect.new(opts, labels, "Choose two:")
		ROPER:
			return SequenceEffect.new([GainPower.new(3), _SetNaafiri.new()])
		ANCIENT_BRASS:
			return _Xerath.new()
		PURPLE_WORM:
			return SequenceEffect.new([SupplantTroop.new(1), CallbackEffect.new(func(s: GameState, pid: String, r: EffectResolver):
				var n: int = ShurimaCards.kills_this_turn(s, pid)
				if n > 0:
					r.push(DrawCards.new(n), pid))])
		NAGA:
			return SequenceEffect.new([AssassinateTroop.new(1), CallbackEffect.new(func(s: GameState, pid: String, r: EffectResolver):
				var n: int = 3 + floori(s.stock(pid).trophy_hall_count / 3.0)
				s.players[pid].power += n
				r.log_event("gain_power", {"player_id": pid, "amount": n}))])
		ADULT_BRASS:
			return CallbackEffect.new(func(s: GameState, pid: String, r: EffectResolver):
				var costs := {}
				for cid: String in s.players[pid].deck.played_pile:
					costs[maxi(0, CardLibrary.card_cost(cid))] = true
				var n := costs.size()
				s.players[pid].power += n
				s.players[pid].influence += n
				r.log_event("gain_power", {"player_id": pid, "amount": n})
				r.log_event("gain_influence", {"player_id": pid, "amount": n}))
		STONE_GIANT:
			return SequenceEffect.new([
				DrawCards.new(1),
				ChooseEffect.new([MoveTroop.new(3, true, true), MoveTroop.new(1)],
					["Move up to 3 of your troops", "Move an enemy troop"]),
			])
		GORGON:
			return _MoveThenSupplant.new()
		ANKHEG:
			return SequenceEffect.new([MoveTroop.new(1), DeployTroop.new(3)])
		DUST_MEPHIT:
			return ChooseEffect.new([RecruitFree.new("", 5), RecruitFree.new("", 3, 2)],
				["Recruit a card that costs 5 or less for free", "Recruit 2 cards that cost 3 or less for free"])
		DEVA:
			return PiltoverCards._AfterTroops.new(SupplantTroop.new(1), func(state, pid, before):
				for victim: String in PiltoverCards._victims(state, before):
					if victim != "white" and state.is_enemy(pid, victim):
						return TakeFromTrophyHall.new(1, true, false, victim, false)
				return ScryCards.new(2))
	return null


## Эффект Devotion карты (null — у карты его нет).
static func devotion_effect(card_id: String) -> CardEffect:
	match card_id:
		ZOMBIE:
			return ReturnTroopOrSpy.new(1)
		WYRMLING:
			return DrawCards.new(1)
		STEAM_MEPHIT:
			return ScryCards.new(3)
		COMMONER:
			return SequenceEffect.new([DrawCards.new(1), DiscardCardEffect.new(1)])
		INCUBUS:
			return GainPower.new(2)
		GOBLIN_WARRIOR:
			return DeployTroop.new(3)
		GOBLIN_MINION:
			return PlaceSpy.new(1)
		DRAGON_TURTLE:
			return SupplantTroop.new(1)
		MAGMA_MEPHIT:
			return GainInfluence.new(1)
		ANCIENT_BRASS:
			return PiltoverCards._strike_anywhere()
		PURPLE_WORM:
			return SupplantTroop.new(1)
		NAGA:
			return AssassinateTroop.new(1)
		ADULT_BRASS:
			return SequenceEffect.new([ScryCards.new(2), DrawCards.new(1)])
		STONE_GIANT:
			return MoveTroop.new(2)
		GORGON:
			return GainPower.new(3)
		DUST_MEPHIT:
			return RecruitFree.new("", 3)
		DEVA:
			var ask := OptionalEffect.new(_ToTopOfDeck.new(DEVA), "Devotion: put Deva on top of your deck?")
			ask.source_card = DEVA
			return ask
	return null


static func has_devotion(card_id: String) -> bool:
	return devotion_effect(card_id) != null


## Карту наняли (покупка на рынке, бесплатный найм). immediate — зовёт GameServer
## вне розыгрыша карты: эффект прогоняется сразу (или после уже заданного вопроса).
static func on_recruit(state: GameState, player_id: String, card_id: String, resolver: EffectResolver, immediate: bool = false) -> void:
	_devotion(state, player_id, card_id, resolver, immediate)


## Карту продвинули во Внутренний круг (любой путь promote).
static func on_promote(state: GameState, player_id: String, card_id: String, resolver: EffectResolver) -> void:
	_devotion(state, player_id, card_id, resolver, false)


static func _devotion(state: GameState, player_id: String, card_id: String, resolver: EffectResolver, immediate: bool) -> void:
	if not has_devotion(card_id):
		return
	var eff := _TriggerDevotion.new(card_id)
	if not immediate:
		resolver.push(eff, player_id, card_id)
	elif resolver.pending != null:
		# Уже есть вопрос (например, Harpy после покупки): Devotion — после него.
		resolver.pending.stack.push_front({"effect": eff, "player_id": player_id, "card": card_id})
	else:
		resolver.apply(eff, player_id, state, card_id)


## Сработать Devotion карты card_id (Cockatrice зовёт напрямую).
static func trigger(state: GameState, player_id: String, card_id: String, resolver: EffectResolver) -> void:
	var eff := devotion_effect(card_id)
	if eff == null:
		return
	resolver.log_event("devotion", {"player_id": player_id, "card_id": card_id})
	var bonus := int((state.turn_flags.get("devotion_power", {}) as Dictionary).get(player_id, 0))
	if bonus > 0:
		state.players[player_id].power += bonus
		resolver.log_event("gain_power", {"player_id": player_id, "amount": bonus})
	resolver.push(eff, player_id, card_id)


## Сколько войск игрок убил или вытеснил в этот ход (трофеи с начала хода).
static func kills_this_turn(state: GameState, player_id: String) -> int:
	if player_id != state.current_player():
		return 0
	return maxi(0, state.stock(player_id).trophy_hall_count - int(state.turn_flags.get("trophy_start", 0)))


## "If the site is full": свободных мест для войск в локации нет.
static func _site_full(state: GameState, site_id: String) -> bool:
	for slot_id: String in state.graph.slots_of_site(site_id):
		if String(state.troops.get(slot_id, "")) == "":
			return false
	return true


## Tough: эту карту рынка нельзя нанять в этот ход.
static func recruit_banned(state: GameState, card_id: String) -> bool:
	return (state.turn_flags.get("no_recruit", []) as Array).has(card_id)


# --- Roper (Naafiri) ---------------------------------------------------------

## Карта поставила войска (первое войско цепочки DeployTroop): "Whenever you
## deploy troops from a card effect, Assassinate a troop".
static func on_card_deploy(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if String(state.turn_flags.get("naafiri", "")) != player_id:
		return
	resolver.push(AssassinateTroop.new(1), player_id, ROPER)


## Базовое действие Deploy: "Whenever you deploy troops using Power from a card,
## gain up to 1 additional Power per card" — 1 Power назад, раз на каждую карту,
## сыгранную начиная с Roper.
static func on_deploy_action(state: GameState, player_id: String) -> void:
	if String(state.turn_flags.get("naafiri", "")) != player_id:
		return
	var cards := int(state.turn_flags.get("cards_played", 0)) - int(state.turn_flags.get("naafiri_from", 0))
	var used := int(state.turn_flags.get("naafiri_used", 0))
	if used >= cards:
		return
	state.turn_flags["naafiri_used"] = used + 1
	state.players[player_id].power += 1


# --- Эффекты ---------------------------------------------------------------

class _TriggerDevotion extends CardEffect:
	var card: String
	func _init(c: String) -> void:
		card = c
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		ShurimaCards.trigger(state, player_id, card, resolver)


## Goblin Warrior: "Whenever you trigger Devotion this turn, gain 1 Power".
class _AddDevotionPower extends CardEffect:
	func apply(state: GameState, player_id: String, _resolver: EffectResolver) -> void:
		var d: Dictionary = (state.turn_flags.get("devotion_power", {}) as Dictionary).duplicate()
		d[player_id] = int(d.get(player_id, 0)) + 1
		state.turn_flags["devotion_power"] = d


class _SetNaafiri extends CardEffect:
	func apply(state: GameState, player_id: String, _resolver: EffectResolver) -> void:
		if String(state.turn_flags.get("naafiri", "")) == player_id:
			return
		state.turn_flags["naafiri"] = player_id
		state.turn_flags["naafiri_from"] = int(state.turn_flags.get("cards_played", 1)) - 1
		state.turn_flags["naafiri_used"] = 0


## Cockatrice: Devotion другой карты, сыгранной в этот ход.
class _TriggerAnother extends CardEffect:
	func _options(state: GameState, player_id: String) -> Array:
		var out: Array = []
		for cid: String in state.players[player_id].deck.played_pile:
			if ShurimaCards.has_devotion(cid) and not out.has(cid):
				out.append(cid)
		return out
	func is_available(state: GameState, player_id: String) -> bool:
		return not _options(state, player_id).is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var chosen = answer()
			if chosen != null and _options(state, player_id).has(String(chosen)):
				ShurimaCards.trigger(state, player_id, String(chosen), resolver)
			return
		var options := _options(state, player_id)
		if options.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Trigger the Devotion of a card you played this turn"
		pd.choice_type = "target_card"
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)


## Cockatrice: карту из Внутреннего круга — в руку, затем взять карту.
class _InnerToHand extends CardEffect:
	func is_available(state: GameState, player_id: String) -> bool:
		return not state.stock(player_id).deck.inner_circle.is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var circle: Array = state.stock(player_id).deck.inner_circle
		if is_answered():
			var chosen := String(answer()) if answer() != null else ""
			if circle.has(chosen):
				circle.remove_at(circle.rfind(chosen))
				state.players[player_id].deck.hand.append(chosen)
				resolver.log_event("inner_to_hand", {"player_id": player_id, "card_id": chosen})
				resolver.push(DrawCards.new(1), player_id)
			return
		if circle.is_empty():
			return
		var options: Array = []
		for cid in circle:
			if not options.has(cid):
				options.append(cid)
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Return a card from your inner circle to your hand"
		pd.choice_type = "target_card"
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)


## Cultist: посмотреть N верхних карт колоды, одну в руку, остальные в сброс.
class _TopPick extends CardEffect:
	var amount: int
	var _shown: Array[String] = []
	var _started := false
	func _init(n: int) -> void:
		amount = n
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var deck: Deck = state.players[player_id].deck
		if not _started:
			_started = true
			if deck.draw_pile.is_empty() and not deck.discard_pile.is_empty():
				deck.draw_pile = deck.discard_pile.duplicate()
				deck.discard_pile.clear()
				deck.shuffle_draw_pile(state.rng)
			for i in range(mini(amount, deck.draw_pile.size())):
				_shown.append(deck.draw_pile.pop_back())
			if _shown.is_empty():
				return
			var pd := PendingDecision.new()
			pd.player_id = player_id
			pd.prompt = "Put one card into your hand (the rest are discarded)"
			pd.choice_type = "target_card"
			pd.legal_options = Array(_shown)
			pd.target_effect = self
			resolver.request_decision(pd)
			return
		var chosen := String(answer()) if is_answered() and answer() != null else ""
		var idx := _shown.find(chosen)
		if idx == -1:
			idx = 0
		deck.hand.append(_shown[idx])
		_shown.remove_at(idx)
		resolver.log_event("fetch_from_top", {"player_id": player_id, "looked": amount, "cards": [chosen]})
		for cid: String in _shown:
			deck.discard_pile.append(cid)
			resolver.log_event("discard", {"player_id": player_id, "card_id": cid, "from": "scry"})
			FreljordCards.on_discard(state, player_id, cid, resolver, true)


## Tough: игрок выбирает, кого из соседей попросить назвать карту рынка.
class _Marshal extends CardEffect:
	func _neighbours(state: GameState, player_id: String) -> Array[String]:
		var order: Array[String] = state.turn_order
		var i := order.find(player_id)
		var n := order.size()
		var out: Array[String] = []
		if n < 2 or i == -1:
			return out
		out.append(order[(i + 1) % n])
		if order[(i - 1 + n) % n] != out[0]:
			out.append(order[(i - 1 + n) % n])
		return out
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var who := _neighbours(state, player_id)
		if who.is_empty():
			return
		var choose: ChooseEffect
		if who.size() == 1:
			choose = ChooseEffect.new([ShurimaCards._NameCard.new(player_id, who[0]), SequenceEffect.new([])],
				["Your opponent names a card", "Nobody names a card"], "You may let others name a card:")
		else:
			choose = ChooseEffect.new([
				ShurimaCards._NameCard.new(player_id, who[0]),
				ShurimaCards._NameCard.new(player_id, who[1]),
				SequenceEffect.new([ShurimaCards._NameCard.new(player_id, who[1]), ShurimaCards._NameCard.new(player_id, who[0])]),
				SequenceEffect.new([]),
			], ["The player to your left names a card", "The player to your right names a card",
				"Both of them name a card", "Nobody names a card"], "You may let others name a card:")
		choose.source_card = ShurimaCards.TOUGH
		resolver.push(choose, player_id)


## Сосед называет карту рынка: её нельзя нанять в этот ход, хозяину Tough +1 Influence.
class _NameCard extends CardEffect:
	var owner: String
	var namer: String
	func _init(o: String, n: String) -> void:
		owner = o
		namer = n
	func _options(state: GameState) -> Array:
		var out: Array = []
		for i in range(state.market.display.size()):
			var cid := String(state.market.display[i])
			if cid != "" and not ShurimaCards.recruit_banned(state, cid):
				out.append(i)
		return out
	func apply(state: GameState, _player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var index = answer()
			if index == null or not _options(state).has(int(index)):
				return
			var cid := String(state.market.display[int(index)])
			var banned: Array = (state.turn_flags.get("no_recruit", []) as Array).duplicate()
			banned.append(cid)
			state.turn_flags["no_recruit"] = banned
			state.players[owner].influence += 1
			resolver.log_event("name_card", {"player_id": namer, "card_id": cid, "for": owner})
			return
		var options := _options(state)
		if options.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = namer
		pd.prompt = "Name a market card: %s can't recruit it this turn" % owner.capitalize()
		pd.choice_type = "target_market_index"
		pd.tag = "market"
		pd.source_card = ShurimaCards.TOUGH
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)


## Ancient Brass Dragon (Xerath): "Assassinate 3 troops anywhere. If you have
## presence to none of those troops, draw a card."
class _Xerath extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var before: Dictionary = state.troops.duplicate()
		var seen := {}
		for slot_id: String in state.graph.slots.keys():
			if state.is_enemy(player_id, String(state.troops.get(slot_id, ""))) \
					and state.presence.has_presence_at_slot(player_id, slot_id, state.troops, state.spies):
				seen[slot_id] = true
		resolver.push(CallbackEffect.new(func(s: GameState, pid: String, r: EffectResolver):
			var killed := 0
			for slot_id: String in before.keys():
				var was := String(before[slot_id])
				if was != "" and s.is_enemy(pid, was) and String(s.troops.get(slot_id, "")) != was:
					if seen.has(slot_id):
						return
					killed += 1
			if killed > 0:
				r.push(DrawCards.new(1), pid)), player_id)
		var strike := AssassinateTroop.new(3)
		strike.site_given_by_card = true
		resolver.push(strike, player_id)


## Gorgon (K'Sante): "Move an opponent troop then Supplant it" — войско другого
## игрока (не белое) в Присутствии; на новом месте оно вытесняется без Присутствия.
class _MoveThenSupplant extends CardEffect:
	func _slots(state: GameState, player_id: String) -> Array:
		var out: Array = []
		for slot_id: String in state.graph.slots.keys():
			var owner := String(state.troops.get(slot_id, ""))
			if owner != "" and owner != "white" and state.is_enemy(player_id, owner):
				out.append(slot_id)
		return out
	func is_available(state: GameState, player_id: String) -> bool:
		var move := MoveTroop.new(1)
		move.only_slots = _slots(state, player_id)
		return not move.only_slots.is_empty() and move.is_available(state, player_id)
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var move := MoveTroop.new(1)
		move.only_slots = _slots(state, player_id)
		if move.only_slots.is_empty():
			return
		var moved: Array = move._moved_to
		resolver.push(CallbackEffect.new(func(_s: GameState, pid: String, r: EffectResolver):
			if moved.is_empty():
				return
			var hit := SupplantTroop.new(1, false, true)
			hit.only_slots = [moved[0]]
			r.push(hit, pid)), player_id)
		resolver.push(move, player_id)


## Deva (Devotion): нанятая (в сбросе) или продвинутая карта — наверх колоды.
class _ToTopOfDeck extends CardEffect:
	var card: String
	func _init(c: String) -> void:
		card = c
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		var idx := d.discard_pile.rfind(card)
		if idx != -1:
			d.discard_pile.remove_at(idx)
		else:
			var circle: Array = state.stock(player_id).deck.inner_circle
			idx = circle.rfind(card)
			if idx == -1:
				return
			circle.remove_at(idx)
		d.draw_pile.append(card)  # верх колоды — конец массива (Deck.draw_one)
		resolver.log_event("card_on_top", {"player_id": player_id, "card_id": card})
