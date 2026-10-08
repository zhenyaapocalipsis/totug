class_name ShadowCards
extends RefCounted

## Полуколода Shadow Isles (New Era) — способности карт Shadow Isles из
## фан-мода Runeterra Reforged на существах-нежити D&D (решения владельца
## 2026-10-08, см. Claude outputs/new_era_shadow_isles.md).
##
## Перевод на правила этой игры:
##   Cursed Wanderer -> Insane Outcast (тот же текст, та же стопка из 30);
##   Execute         -> Devour (стопка state.devoured_pile);
##   Sapling         -> Twig Blight (запас из 4 карт у доски);
##   Valor           -> MALICE;
##   Cursed Affinity -> скидка 1 за каждый Insane Outcast, сыгранный в этот ход
##                      (Actions.market_cost).
##
## Счётчики хода лежат в state.turn_flags (сбрасываются в start_turn):
##   "outcasts"       — сколько Insane Outcast текущий игрок сыграл в этот ход;
##   "outcast_bonus"  — Shadow: +2 Power и карта за каждый Outcast;
##   "echo"           — Shambling Mound: следующая карта разыгрывается дважды;
##   "market_affinity"— Drider: скидка за Outcast и у всех карт рынка.

const OUTCAST := "48341"
const SPECTER := "49100"
const SHAMBLING_MOUND := "49103"
const GARGOYLE := "49108"
const CRAWLING_CLAWS := "49109"
const WISP := "49111"
const RAKSHASA := "49113"
const NIGHTMARE := "49114"
const CHAIN_DEVIL := "49115"
const BONE_DEVIL := "49119"
const DRIDER := "49120"
const SHADOW := "49122"
const PHASE_SPIDER := "49123"
const TWIG_BLIGHT := "49124"

## Cursed Affinity: дешевле на 1 за каждый сыгранный в этот ход Insane Outcast.
const AFFINITY := [RAKSHASA, NIGHTMARE, BONE_DEVIL, DRIDER]
## "Insane Outcasts in your deck are worth 0 VP".
const OUTCASTS_WORTHLESS := [CHAIN_DEVIL, SHADOW]
const TWIG_SUPPLY := 4


static func is_outcast(card_id: String) -> bool:
	return card_id == OUTCAST


static func build(card_id: String) -> CardEffect:
	var outcast_filter := func(c): return c == OUTCAST
	match card_id:
		"49100":  # Specter (Wraithcaller) — при Devour: on_devour
			return SequenceEffect.new([GainPower.new(3), _PerOutcast.new("power")])
		"49101":  # Vampire Familiar (Soulspinner)
			return ChooseEffect.new([
				PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
					func(state, _pid): return CelestialCards.site_is_full(state, site),
					GiveInsaneOutcast.new("each_opponent"))),
				ReturnOwnSpy.new(SequenceEffect.new([FetchFromTop.new(5, outcast_filter), DrawCards.new(1)])),
			], ["Place a spy (full site: each opponent recruits an Insane Outcast)",
				"Return one of your spies -> Insane Outcasts from your top 5 cards into your hand, draw a card"])
		"49102":  # Death Dog (Duskrider)
			return ConditionalEffect.new(func(state, _pid): return state.supplies.is_available(OUTCAST),
				OptionalEffect.new(SequenceEffect.new([
					GainSupplyToHand.new([OUTCAST] as Array[String]),
					ChooseEffect.new([
						SupplantTroop.new(1),
						SequenceEffect.new([DeployTroop.new(3), GiveInsaneOutcast.new("each_opponent")]),
					], ["Supplant a troop", "Deploy 3 troops, each opponent recruits an Insane Outcast"]),
				]), "Put an Insane Outcast into your hand to choose an effect?"))
		"49103":  # Shambling Mound (Invasive Hydravine)
			return _SetFlag.new("echo")
		"49104":  # Awakened Tree (Moonlit Glenkeeper)
			return ChooseEffect.new([
				FetchFromTop.new(6, outcast_filter),
				GainInfluence.new(3),
			], ["Insane Outcasts from your top 6 cards into your hand", "+3 Influence"])
		"49105":  # Grick (The Sunderer)
			return ChooseEffect.new([
				SequenceEffect.new([DevourCard.new("hand"), DrawCards.new(1)]),
				SequenceEffect.new([ScryCards.new(1), _PerOutcast.new("draw")]),
			], ["Devour a card in your hand, then draw a card",
				"Scry 1, then draw a card per Insane Outcast played this turn"])
		"49106":  # Bearded Devil (Deathless Knight)
			return ChooseEffect.new([
				SequenceEffect.new([DeployTroop.new(3), FetchFromTop.new(6, outcast_filter)]),
				SupplantTroop.new(1, true),
			], ["Deploy 3 troops, Insane Outcasts from your top 6 cards into your hand", "Supplant a white troop"])
		"49107":  # Sea Hag (Spectral Matron)
			return SequenceEffect.new([
				_PerOutcast.new("spy"),
				ChooseEffect.new([
					SequenceEffect.new([PlaceSpy.new(1), DrawCards.new(1)]),
					ReturnOwnSpy.new(null, Callable(), true, func(sites): return AssassinateTroop.new(sites.size(), false, true)),
				], ["Place a spy and draw a card", "Return any number of your spies -> assassinate a troop for each"]),
			])
		"49108":  # Gargoyle (The Etherfiend) — при Devour: on_devour
			return SequenceEffect.new([GainInfluence.new(2), _PerOutcast.new("influence")])
		"49109":  # Swarm of Crawling Claws (Corpse Commander) — реакция из руки: ClawsReaction
			return _SupplantPlayerBonus.new()
		"49110":  # Lemure (Camavoran Soldier)
			return SequenceEffect.new([
				_PerOutcast.new("deploy"),
				ChooseEffect.new([
					_DeployNearEnemy.new(),
					MoveTroop.new(1),
				], ["Deploy 3 troops (next to another player's troop: each opponent recruits an Insane Outcast)",
					"Move a troop"]),
			])
		"49111":  # Will-o'-Wisp (Soul Shepherd) — при Devour: on_devour
			return SequenceEffect.new([GainInfluence.new(2), _OutcastUnlessHolding.new()])
		"49112":  # Spirit Naga (Ethereal Remitter)
			return SequenceEffect.new([
				ConditionalEffect.new(func(state, pid): return state.players[pid].deck.discard_pile.has(OUTCAST),
					OptionalEffect.new(CelestialCards._AllFromDiscardToHand.new(OUTCAST),
						"Put the Insane Outcasts from your discard pile into your hand?")),
				ChooseEffect.new([
					SequenceEffect.new([PlaceSpy.new(1), ScryCards.new(3)]),
					ReturnOwnSpy.new(GainPower.new(3)),
				], ["Place a spy, then scry 3", "Return one of your spies -> +3 Power"]),
			])
		"49113":  # Rakshasa (Viego)
			return SequenceEffect.new([
				GainInfluence.new(2),
				AtEndOfTurn.new(PromoteCard.new("played_other", card_id, Callable(), 2, true)),
				GainVpPerN.new("vp", "inner_circle", 3, 1),
			])
		"49114":  # Nightmare (Hecarim)
			return SequenceEffect.new([DeployTroop.new(4), GainVpPerN.new("vp", "sites_controlled", 2, 1)])
		"49115":  # Chain Devil (Thresh) — 0 VP за Outcast: Scoring.card_bonus_vp
			return SequenceEffect.new([_CycleHand.new(), _PowerPerDiscardedOutcast.new(3)])
		"49116":  # Barbed Devil (Vex)
			return ChooseEffect.new([
				_ShadowSplit.new(),
				SupplantTroop.new(1, false, true),
			], ["An opponent splits your top 5 cards into two piles, keep one", "Supplant a troop anywhere"])
		"49117":  # Ghast (Yorick)
			return ChooseEffect.new([
				GainPower.new(4),
				_RecruitFromDevoured.new(3),
			], ["+4 Power", "Recruit one of the top 3 devoured cards for free"])
		"49118":  # Treant (Maokai)
			return SequenceEffect.new([
				_GainTwigBlight.new(),
				GainVpPerN.new("vp", "sites_controlled_total", 1, 1),
				AtEndOfTurn.new(PromoteCard.new("played_other", card_id)),
			])
		"49119":  # Bone Devil (Karthus)
			var strike := AssassinateTroop.new(2, false, true)
			strike.site_given_by_card = true  # "anywhere": без Присутствия
			return SequenceEffect.new([strike, GainVpPerN.new("vp", "trophy_hall", 3, 1)])
		"49120":  # Drider (Elise)
			return SequenceEffect.new([
				PlaceSpy.new(2),
				CelestialCards._InfluencePerSpy.new(),
				_SetFlag.new("market_affinity"),
				OptionalEffect.new(CelestialCards._Transform.new(DRIDER, PHASE_SPIDER), "Transform into Phase Spider?"),
			])
		"49121":  # Green Hag (Gwen)
			return SequenceEffect.new([GainPower.new(3), _HagDevour.new(), _OpponentsMayDevour.new()])
		"49122":  # Shadow (Kalista) — 0 VP за Outcast: Scoring.card_bonus_vp
			return SequenceEffect.new([_CycleHand.new(), _AddFlag.new("outcast_bonus")])
		"49123":  # Phase Spider (Spider Elise)
			return SequenceEffect.new([
				_PowerPerSpy.new(),
				GiveInsaneOutcast.new("each_opponent"),
				ReturnOwnSpy.new(null, Callable(), true, func(sites): return _SupplantAtSites.new(sites)),
				OptionalEffect.new(CelestialCards._Transform.new(PHASE_SPIDER, DRIDER), "Transform into Drider?"),
			])
		"49124":  # Twig Blight (Sapling) — Promote/Devour: Supplies.redirect_outcast
			return SequenceEffect.new([DeployTroop.new(1), DrawCards.new(1)])
	return null


## Вызывается TurnEngine.play_card до запуска эффекта карты: считает сыгранные
## Insane Outcast, добавляет бонус Shadow и повтор Shambling Mound.
static func on_play(state: GameState, player_id: String, card_id: String, effect: CardEffect) -> CardEffect:
	var plays := 1
	if state.turn_flags.get("echo", false):
		state.turn_flags.erase("echo")
		plays = 2
		effect = SequenceEffect.new([effect, CardLibrary.get_effect(card_id),
			AtEndOfTurn.new(DevourCard.new("this", card_id, null, false))])
	if card_id == OUTCAST:
		state.turn_flags["outcasts"] = outcasts_played(state) + plays
		var bonus: int = int(state.turn_flags.get("outcast_bonus", 0)) * plays
		if bonus > 0:
			effect = SequenceEffect.new([GainPower.new(2 * bonus), DrawCards.new(bonus), effect])
	return effect


## "If this card is devoured" — DevourCard и Green Hag после того, как карта ушла
## в devoured_pile.
static func on_devour(state: GameState, player_id: String, card_id: String, resolver: EffectResolver) -> void:
	match card_id:
		SPECTER:
			resolver.push(AssassinateTroop.new(1), player_id)
		GARGOYLE:
			state.players[player_id].start_of_turn_influence += 3
		WISP:
			resolver.push(PromoteCard.new("hand_or_discard", "", Callable(), 1, true), player_id)


static func outcasts_played(state: GameState) -> int:
	return int(state.turn_flags.get("outcasts", 0))


## Скидка Cursed Affinity на карту рынка в текущем ходу.
static func affinity_discount(state: GameState, card_id: String) -> int:
	if AFFINITY.has(card_id) or state.turn_flags.get("market_affinity", false):
		return outcasts_played(state)
	return 0


## Игроки по часовой стрелке, начиная с текущего (как GiveInsaneOutcast).
static func _opponents_clockwise(state: GameState, player_id: String) -> Array[String]:
	var order: Array[String] = []
	var n: int = state.turn_order.size()
	for i in range(n):
		var pid: String = state.turn_order[(state.current_player_index + i) % n]
		if pid != player_id:
			order.append(pid)
	return order


class _SetFlag extends CardEffect:
	var key: String
	func _init(k: String) -> void:
		key = k
	func apply(state: GameState, _player_id: String, _resolver: EffectResolver) -> void:
		state.turn_flags[key] = true


class _AddFlag extends CardEffect:
	var key: String
	func _init(k: String) -> void:
		key = k
	func apply(state: GameState, _player_id: String, _resolver: EffectResolver) -> void:
		state.turn_flags[key] = int(state.turn_flags.get(key, 0)) + 1


## "+1 X per Insane Outcast you played this turn".
class _PerOutcast extends CardEffect:
	var what: String
	func _init(w: String) -> void:
		what = w
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var n := ShadowCards.outcasts_played(state)
		if n <= 0:
			return
		match what:
			"power": resolver.push(GainPower.new(n), player_id)
			"influence": resolver.push(GainInfluence.new(n), player_id)
			"draw": resolver.push(DrawCards.new(n), player_id)
			"deploy": resolver.push(DeployTroop.new(n, true), player_id)
			"spy": resolver.push(PlaceSpy.new(n, true), player_id)


class _PowerPerSpy extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var n := CelestialCards._own_spies(state, player_id)
		if n > 0:
			resolver.push(GainPower.new(n), player_id)


class _PowerPerDiscardedOutcast extends CardEffect:
	var per: int
	func _init(k: int) -> void:
		per = k
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var n: int = state.players[player_id].deck.discard_pile.count(ShadowCards.OUTCAST)
		if n > 0:
			resolver.push(GainPower.new(n * per), player_id)


## Swarm of Crawling Claws: "Supplant a troop. If it was a player troop, +1 Power" — чужое
## войско игрока попадает в трофеи как player troop.
class _SupplantPlayerBonus extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var before: int = state.players[player_id].player_trophy_count()
		resolver.push(CallbackEffect.new(func(s: GameState, pid: String, r: EffectResolver):
			if s.players[pid].player_trophy_count() > before:
				r.push(GainPower.new(1), pid)), player_id)
		resolver.push(SupplantTroop.new(1), player_id)


## Lemure: "Deploy 3 troops. If you deployed next to a player
## troop this way, each opponent gains an Insane Outcast". "Рядом" — соседняя
## клетка пути или та же локация.
class _DeployNearEnemy extends CardEffect:
	func is_available(state: GameState, player_id: String) -> bool:
		return DeployTroop.new(3).is_available(state, player_id)
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var before := {}
		for slot_id: String in state.troops.keys():
			if state.troops[slot_id] == player_id:
				before[slot_id] = true
		resolver.push(CallbackEffect.new(func(s: GameState, pid: String, r: EffectResolver):
			for slot_id: String in s.troops.keys():
				if s.troops[slot_id] == pid and not before.has(slot_id) and ShadowCards._next_to_enemy(s, pid, slot_id):
					r.push(GiveInsaneOutcast.new("each_opponent"), pid)
					return), player_id)
		resolver.push(DeployTroop.new(3), player_id)


static func _next_to_enemy(state: GameState, player_id: String, slot_id: String) -> bool:
	var near: Array = Array(state.graph.adjacent_slots(slot_id))
	var site: String = state.graph.site_of_slot(slot_id)
	if site != "":
		near.append_array(state.graph.slots_of_site(site))
	for other: String in near:
		var owner: String = state.troops.get(other, "")
		if owner != "" and owner != "white" and owner != player_id:
			return true
	return false


## Will-o'-Wisp: "Each opponent recruits an Insane Outcast unless they reveal
## one in their hand" — показать всегда выгодно, поэтому без вопроса.
class _OutcastUnlessHolding extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var opps := ShadowCards._opponents_clockwise(state, player_id)
		opps.reverse()  # стек: первым сработает ближайший по часовой
		for opp: String in opps:
			if not state.players[opp].deck.hand.has(ShadowCards.OUTCAST):
				resolver.push(GiveInsaneOutcast.new("self"), opp)


## Swarm of Crawling Claws в руке: "Whenever you would gain an Insane Outcast, you may reveal
## this card to gain it to your hand and scry 1". Вопрос задаётся получателю
## (как Shield Guardian) из GiveInsaneOutcast.
class ClawsReaction extends CardEffect:
	var target: String
	var count: int
	func _init(t: String, n: int) -> void:
		target = t
		count = n
	func apply(state: GameState, _player_id: String, resolver: EffectResolver) -> void:
		if not is_answered():
			var pd := PendingDecision.new()
			pd.player_id = target
			pd.prompt = "Reveal Swarm of Crawling Claws to take the Insane Outcast into your hand and scry 1?"
			pd.choice_type = "confirm"
			pd.source_card = ShadowCards.CRAWLING_CLAWS
			pd.legal_options = [true, false]
			pd.target_effect = self
			resolver.request_decision(pd)
			return
		var to_hand := bool(answer())
		var p: PlayerState = state.players[target]
		var given := 0
		for i in range(count):
			if not state.supplies.take(ShadowCards.OUTCAST):
				break
			if to_hand:
				p.deck.hand.append(ShadowCards.OUTCAST)
			else:
				p.deck.discard_pile.append(ShadowCards.OUTCAST)
			given += 1
		if given > 0:
			resolver.log_event("give_insane_outcast", {"player_id": target, "count": given, "to_hand": to_hand})
			if to_hand:
				resolver.push(ScryCards.new(1), target)


## "Discard any number of cards in your hand to draw that many cards".
class _CycleHand extends CardEffect:
	var discarded := 0
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var p: PlayerState = state.players[player_id]
		if is_answered():
			var chosen = answer()
			_answered = false
			_answer = null
			var idx := -1 if chosen == null else p.deck.hand.find(String(chosen))
			if idx == -1:
				_finish(player_id, resolver)
				return
			p.deck.hand.remove_at(idx)
			p.deck.discard_pile.append(String(chosen))
			discarded += 1
			resolver.log_event("discard", {"player_id": player_id, "card_id": chosen})
		if p.deck.hand.is_empty():
			_finish(player_id, resolver)
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Discard a card to draw a card (%d so far), or stop" % discarded
		pd.choice_type = "target_card"
		pd.tag = "hand"
		pd.legal_options = p.deck.hand.duplicate()
		pd.legal_options.append("")
		pd.target_effect = self
		resolver.request_decision(pd)
	func _finish(player_id: String, resolver: EffectResolver) -> void:
		if discarded > 0:
			resolver.push(DrawCards.new(discarded), player_id)


## Treant: "Gain a Sapling card" — Twig Blight из запаса в сброс.
class _GainTwigBlight extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if not state.supplies.take(ShadowCards.TWIG_BLIGHT):
			return
		state.players[player_id].deck.discard_pile.append(ShadowCards.TWIG_BLIGHT)
		resolver.log_event("gain_card", {"player_id": player_id, "card_id": ShadowCards.TWIG_BLIGHT})


## Ghast: "Look at the top 3 cards of the Execute pile. You may gain one of
## them for free."
class _RecruitFromDevoured extends CardEffect:
	var depth: int
	func _init(n: int) -> void:
		depth = n
	func _top(state: GameState) -> Array:
		var pile := state.devoured_pile
		return pile.slice(maxi(0, pile.size() - depth))
	func is_available(state: GameState, _player_id: String) -> bool:
		return not state.devoured_pile.is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var top := _top(state)
		if is_answered():
			var chosen = answer()
			if chosen == null or String(chosen) == "" or not top.has(String(chosen)):
				return
			var idx := state.devoured_pile.rfind(String(chosen))
			state.devoured_pile.remove_at(idx)
			state.players[player_id].deck.discard_pile.append(String(chosen))
			resolver.log_event("recruit_free", {"player_id": player_id, "card_id": chosen})
			CardLibrary.on_gain(state, player_id, String(chosen))
			return
		if top.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Recruit one of the top devoured cards for free"
		pd.choice_type = "target_card"
		pd.legal_options = top
		pd.legal_options.append("")
		pd.target_effect = self
		resolver.request_decision(pd)


## Green Hag: "You may Execute a card in your hand or discard pile. If you
## Executed a Cursed Wanderer, gain 2 Power. Otherwise, gain VP equal to the
## Executed card's deck VP."
class _HagDevour extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		if is_answered():
			var chosen = answer()
			if chosen == null or String(chosen) == "":
				return
			var cid := String(chosen)
			if d.hand.has(cid):
				d.hand.remove_at(d.hand.find(cid))
			elif d.discard_pile.has(cid):
				d.discard_pile.remove_at(d.discard_pile.find(cid))
			else:
				return
			if Supplies.redirect_outcast(state, player_id, cid, resolver):
				if cid == ShadowCards.OUTCAST:
					resolver.push(GainPower.new(2), player_id)
				return
			state.devoured_pile.append(cid)
			resolver.log_event("devour", {"player_id": player_id, "card_id": cid, "source": "hand_or_discard"})
			ShadowCards.on_devour(state, player_id, cid, resolver)
			var vp: int = Scoring._card_vp(cid, "deck_vp")
			if vp > 0:
				resolver.push(GainVP.new(vp), player_id)
			return
		var pool: Array = d.hand + d.discard_pile
		if pool.is_empty():
			return
		var options: Array = []
		for cid in pool:
			if not options.has(cid):
				options.append(cid)
		options.append("")
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "You may devour a card from your hand or discard pile"
		pd.choice_type = "target_card"
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)


## Green Hag: "Each other player may Execute a card from their hand" — вопрос
## каждому сопернику по очереди (как реакция Shield Guardian).
class _OpponentsMayDevour extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var opps := ShadowCards._opponents_clockwise(state, player_id)
		opps.reverse()
		for opp: String in opps:
			if not state.players[opp].deck.hand.is_empty():
				resolver.push(_OpponentDevour.new(opp), opp)


class _OpponentDevour extends CardEffect:
	var victim: String
	func _init(v: String) -> void:
		victim = v
	func apply(state: GameState, _player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[victim].deck
		if is_answered():
			var chosen = answer()
			if chosen == null or String(chosen) == "" or not d.hand.has(String(chosen)):
				return
			var cid := String(chosen)
			d.hand.remove_at(d.hand.find(cid))
			if not Supplies.redirect_outcast(state, victim, cid, resolver):
				state.devoured_pile.append(cid)
				resolver.log_event("devour", {"player_id": victim, "card_id": cid, "source": "hand"})
				ShadowCards.on_devour(state, victim, cid, resolver)
			return
		if d.hand.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = victim
		pd.prompt = "Green Hag: you may devour a card from your hand"
		pd.choice_type = "target_card"
		pd.source_card = "49121"
		pd.legal_options = d.hand.duplicate()
		pd.legal_options.append("")
		pd.target_effect = self
		resolver.request_decision(pd)


## Barbed Devil (Vex): "Show an opponent the top 5 cards of your deck. They separate
## it into a faceup and facedown pile and you choose one to keep and one to
## discard." Соперник по одной отбирает карты в открытую стопку, остальные
## идут в закрытую; хозяин выбирает, какую взять в руку.
class _ShadowSplit extends CardEffect:
	var owner := ""
	var opponent := ""
	var cards: Array[String] = []
	var face_up: Array[String] = []
	var stage := 0  # 0 — выбор соперника, 1 — соперник делит, 2 — хозяин выбирает
	func is_available(state: GameState, player_id: String) -> bool:
		var d: Deck = state.players[player_id].deck
		return not (d.draw_pile.is_empty() and d.discard_pile.is_empty())
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if owner == "":
			owner = player_id
		var d: Deck = state.players[owner].deck
		if stage == 0:
			var opps := ShadowCards._opponents_clockwise(state, owner)
			if opps.is_empty():
				return
			if opps.size() > 1 and not is_answered():
				var pd0 := PendingDecision.new()
				pd0.player_id = owner
				pd0.prompt = "Choose an opponent to split your top 5 cards"
				pd0.choice_type = "target_player"
				pd0.legal_options = opps
				pd0.target_effect = self
				resolver.request_decision(pd0)
				return
			opponent = String(answer()) if is_answered() else opps[0]
			_answered = false
			_answer = null
			if d.draw_pile.size() < 5 and not d.discard_pile.is_empty():
				# как при добирании: недостающее — из перемешанного сброса снизу
				var refill := d.discard_pile.duplicate()
				d.discard_pile.clear()
				Deck.shuffle_array(refill, state.rng)
				refill.append_array(d.draw_pile)
				d.draw_pile = refill
			for i in range(mini(5, d.draw_pile.size())):
				cards.append(d.draw_pile.pop_back())
			resolver.log_event("shadow_split", {"player_id": owner, "opponent": opponent, "count": cards.size()})
			if cards.is_empty():
				return
			stage = 1
		if stage == 1:
			if is_answered():
				var chosen = answer()
				_answered = false
				_answer = null
				var idx := -1 if chosen == null else cards.find(String(chosen))
				if idx != -1:
					face_up.append(cards[idx])
					cards.remove_at(idx)
				else:
					stage = 2
			if stage == 1 and not cards.is_empty():
				var pd1 := PendingDecision.new()
				pd1.player_id = opponent
				pd1.prompt = "Pick cards for the face-up pile (the rest stay face down), then stop"
				pd1.choice_type = "target_card"
				pd1.source_card = "49116"
				pd1.legal_options = cards.duplicate()
				pd1.legal_options.append("")
				pd1.target_effect = self
				resolver.request_decision(pd1)
				return
			stage = 2
		if not is_answered():
			var names: Array[String] = []
			for cid: String in face_up:
				names.append(String(CardLibrary.card_data(cid).get("name", cid)))
			var pd2 := PendingDecision.new()
			pd2.player_id = owner
			pd2.prompt = "Keep one pile in your hand, discard the other"
			pd2.choice_type = "choose_option"
			pd2.legal_options = [0, 1]
			pd2.option_labels = ["Keep the face-up pile: " + (", ".join(names) if not names.is_empty() else "empty"),
				"Keep the face-down pile (%d cards)" % cards.size()]
			pd2.target_effect = self
			resolver.request_decision(pd2)
			return
		var keep_up := int(answer()) == 0
		d.hand.append_array(face_up if keep_up else cards)
		d.discard_pile.append_array(cards if keep_up else face_up)
		resolver.log_event("shadow_keep", {"player_id": owner, "face_up": keep_up,
			"kept": (face_up if keep_up else cards).size()})


## Phase Spider: "Supplant a troop at each of those sites".
class _SupplantAtSites extends CardEffect:
	var sites: Array
	func _init(s: Array) -> void:
		sites = s
	func apply(_state: GameState, player_id: String, resolver: EffectResolver) -> void:
		for i in range(sites.size() - 1, -1, -1):
			resolver.push(SupplantTroop.new(1, false, true, false, Callable(), String(sites[i])), player_id)
