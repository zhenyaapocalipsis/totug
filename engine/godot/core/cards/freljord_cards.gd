class_name FreljordCards
extends RefCounted

## Полуколода Freljord (New Era) — способности карт Freljord из фан-мода
## Runeterra Reforged на существах ледяного Севера (ICEWIND DALE): великаны,
## звери тундры и племена. Таблица id -> существо -> карта мода —
## Claude outputs/new_era_freljord.md.
##
## Перевод на правила этой игры:
##   Valor  -> MALICE;
##   Execute -> Devour;
##   Cursed Wanderer -> Insane Outcast.
##
## Frostbite (правило мода): срабатывает у карты, когда её сбрасывают из руки —
## в свой или в чужой ход. Решение владельца (2026-10-14): сброс руки в конце
## хода Frostbite НЕ вызывает, только сброс эффектом ("discard a card", "draw
## then discard", соперник заставил сбросить). Все пути сброса зовут on_discard.
##
## Счётчики хода — state.turn_flags (сбрасываются в start_turn):
##   "frostbite_any" — в этот ход кто-то активировал Frostbite (Werewolf);
##   "other_discard" — в этот ход сбросил карту не текущий игрок (Giant Hyena);
##   "deck_frostbite" — id игрока: его сброс с верха колоды (scry) тоже Frostbite (Skeleton);
##   "frost_copy"    — id игрока: получает Frostbite соперников (Bulette);
##   "frost_shield"  — id игрока: его соперники Frostbite не активируют (Mammoth);
##   "frost_twice"   — id игрока: его Frostbite срабатывает дважды (Storm Giant).
##   "gained"        — {id игрока: true}: получил карту в этот ход (Pirate Captain);
##   "olaf"          — id игрока: карты, ставящие войска, дают ему +1 Power за войско
##                     (Young White Dragon);
##   "olaf_locked"   — сколько из его Power нельзя тратить на войска (Young White Dragon).
##
## 2026-10-14 владелец убрал Roc (Anivia), Stone Giant (Ornn) и Giant Ape (Trundle)
## вместе с Glacial Storm, Ice Pillar, Roc Egg и колодой Masterwork; вместо них —
## Pirate Captain (Gragas), Blink Dog (Aurora), Young White Dragon (Olaf).

const GUARD := "49600"
const SKELETON := "49601"
const WEREWOLF := "49602"
const MAGMIN := "49603"
const CENTAUR := "49604"
const BULETTE := "49605"
const MEPHIT := "49606"
const STALKER := "49607"
const ETTERCAP := "49608"
const XORN := "49609"
const OWL := "49610"
const WINTER_WOLF := "49611"
const HYENA := "49612"
const OWLBEAR := "49613"
const HILL_GIANT := "49614"
const CLOUD_GIANT := "49615"
const REMORHAZ := "49616"
const MAMMOTH := "49617"
const STORM_GIANT := "49618"
const FROST_GIANT := "49620"
const PIRATE_CAPTAIN := "49634"
const BLINK_DOG := "49635"
const WHITE_DRAGON := "49636"

const FROSTBITE: Array[String] = [GUARD, MAGMIN, CENTAUR, MEPHIT, XORN, OWL, HYENA, MAMMOTH]


static func build(card_id: String) -> CardEffect:
	match card_id:
		GUARD:  # Avarosan Sentry
			return SequenceEffect.new([
				GainInfluence.new(2),
				ConditionalEffect.new(func(state, pid):
					return int(state.turn_flags.get("cards_played", 0)) == 1 and state.players[pid].deck.hand.size() <= 3,
					GainInfluence.new(1)),
			])
		SKELETON:  # Bone Scryer
			return SequenceEffect.new([
				_SetPidFlag.new("deck_frostbite"),
				ChooseEffect.new([
					SequenceEffect.new([PlaceSpy.new(1), ScryCards.new(2)]),
					ReturnOwnSpy.new(SequenceEffect.new([_DiscardDownTo.new(4), ScryCards.new(4)])),
				], ["Place a spy and scry 2 cards",
					"Return one of your spies -> each opponent discards down to 4 cards, scry 4 cards"]),
			])
		WEREWOLF:  # Ruthless Raider
			return SequenceEffect.new([
				GainPower.new(2),
				ForceDiscard.new("each_opponent", 3),
				ConditionalEffect.new(func(state, _pid): return state.turn_flags.get("frostbite_any", false),
					GainPower.new(1)),
			])
		MAGMIN:  # Lorekeeper
			return ChooseEffect.new([DeployTroop.new(2), AssassinateTroop.new(1, true)],
				["Deploy 2 troops", "Assassinate a white troop"])
		CENTAUR:  # Icevale Archer
			return PiltoverCards._AfterTroops.new(AssassinateTroop.new(1), func(state, pid, before):
				if NoxusCards._hit_player(state, pid, before):
					return ForceDiscard.new("each_opponent", 2)
				return null)
		BULETTE:  # Troll Scout
			return SequenceEffect.new([
				_SetPidFlag.new("frost_copy"),
				PiltoverCards._AfterTroops.new(DeployTroop.new(3), func(state, pid, before):
					if PiltoverCards._moved_next_to_other(state, pid, before):
						return ForceDiscard.new("each_opponent", 0)
					return null),
			])
		MEPHIT:  # Rimetusk Shaman
			return ChooseEffect.new([GainInfluence.new(3), ReturnTroopOrSpy.new(1)],
				["+3 Influence", "Return a troop or spy"])
		STALKER:  # Valhir's Prophet
			return ChooseEffect.new([
				SequenceEffect.new([PlaceSpy.new(1), ForceDiscard.new("each_opponent", 2), GainInfluence.new(1)]),
				ReturnOwnSpy.new(SequenceEffect.new([ForceDiscard.new("each_opponent", 3), GainPower.new(2)])),
			], ["Place a spy, each opponent with 3+ cards in hand discards a card, +1 Influence",
				"Return one of your spies -> each opponent with 4+ cards in hand discards a card, +2 Power"])
		ETTERCAP:  # Avarosan Trapper
			return ChooseEffect.new([
				PlaceSpy.new(1, false, func(site): return _TrapperEcho.new(site)),
				ReturnOwnSpy.new(GainPower.new(3)),
			], ["Place a spy (another player's troop there: trigger the Frostbite of another card you played)",
				"Return one of your spies -> +3 Power"])
		XORN:  # Avarosan Hearthguard
			return AtEndOfTurn.new(PromoteCard.new("played_other", XORN))
		OWL:  # Starlit Seer
			return SequenceEffect.new([
				PlaceSpy.new(1, false, func(site): return _OwlDiscard.new(site)),
				DeployTroop.new(1),
			])
		WINTER_WOLF:  # Murkwolf Shaman
			return ChooseEffect.new([
				SupplantTroop.new(1, true),
				SequenceEffect.new([DeployTroop.new(2), DrawCards.new(1), DiscardCardEffect.new(1)]),
			], ["Supplant a white troop", "Deploy 2 troops, draw a card, then discard a card"])
		HYENA:  # Scarmother
			return SequenceEffect.new([
				DeployTroop.new(3),
				ConditionalEffect.new(func(state, _pid): return state.turn_flags.get("other_discard", false),
					GainPower.new(2)),
			])
		OWLBEAR:  # Nunu & Willump
			return SequenceEffect.new([
				DrawCards.new(4),
				DiscardCardEffect.new(4),
				AtEndOfTurn.new(PromoteCard.new("discard_or_played", OWLBEAR)),
			])
		HILL_GIANT:  # Braum: реакция из руки — guard()
			return GainPower.new(5)
		CLOUD_GIANT:  # Lissandra
			return ChooseEffect.new([
				SequenceEffect.new([PlaceSpy.new(2), DrawCards.new(1)]),
				ReturnOwnSpy.new(null, Callable(), true, func(sites): return SequenceEffect.new([
					GainPower.new(2 * sites.size()), DrawCards.new(sites.size())])),
			], ["Place 2 spies and draw a card",
				"Return any number of your spies -> +2 Power and draw a card for each"])
		REMORHAZ:  # Ashe
			return SequenceEffect.new([_AsheVolley.new(), PiltoverCards._strike_anywhere()])
		MAMMOTH:  # Sejuani
			return SequenceEffect.new([
				_SetPidFlag.new("frost_shield"),
				ChooseEffect.new([
					_DiscardDownTo.new(3),
					ConditionalEffect.new(func(state, pid): return _all_opponents_at_most(state, pid, 4),
						SupplantTroop.new(2)),
				], ["Each opponent discards down to 3 cards",
					"If each opponent has 4 or fewer cards in hand, supplant 2 troops"]),
			])
		STORM_GIANT:  # Volibear
			return SequenceEffect.new([_SetPidFlag.new("frost_twice"), _Avalanche.new(), SupplantTroop.new(2)])
		FROST_GIANT:  # Tryndamere
			return SequenceEffect.new([
				PromoteCard.new("top_of_deck"),
				ChooseEffect.new([GainPower.new(2), PlayCardFromZone.new("inner_circle")],
					["+2 Power", "Play a card from your inner circle as if from your hand (it stays there)"]),
			])
		PIRATE_CAPTAIN:  # Gragas
			return SequenceEffect.new([GainPower.new(4), AtEndOfTurn.new(_BackOnTop.new(PIRATE_CAPTAIN))])
		BLINK_DOG:  # Aurora
			return ChooseEffect.new([
				_ScatterSite.new(),
				PiltoverCards._AfterTroops.new(MoveTroop.new(3, true, true), func(state, pid, before):
					var n := _moved_next_to_enemy(state, pid, before)
					return GainPower.new(n) if n > 0 else null),
			], ["Choose a site with your troop: move other troops there to empty spaces next to it",
				"Move up to 3 of your troops: +1 Power for each one moved next to another player's troop"])
		WHITE_DRAGON:  # Olaf
			return SequenceEffect.new([_SetPidFlag.new("olaf"), DeployTroop.new(3)])
	return null


## Эффект Frostbite карты (null — у карты его нет).
static func frostbite_effect(card_id: String) -> CardEffect:
	match card_id:
		GUARD:
			return RecruitFree.new("", 3)
		MAGMIN:
			return DrawCards.new(1)
		CENTAUR:
			return GainVP.new(1)
		MEPHIT:
			return _DiscardToHand.new(2)
		XORN:
			return _PromoteAnother.new(XORN)
		OWL:
			return PlaceSpy.new(1)
		HYENA:
			return AssassinateTroop.new(1)
		MAMMOTH:
			return _ReturnToHand.new(MAMMOTH)
	return null


## Карту сбросили из руки (from_deck — с верха колоды, Scry). Зовут все пути
## сброса эффектом: DiscardCardEffect, ForceDiscard, ScryCards и карточные.
static func on_discard(state: GameState, player_id: String, card_id: String, resolver: EffectResolver, from_deck: bool = false) -> void:
	if not from_deck and player_id != state.current_player():
		state.turn_flags["other_discard"] = true
	if not FROSTBITE.has(card_id):
		return
	if from_deck and String(state.turn_flags.get("deck_frostbite", "")) != player_id:
		return
	var shield := String(state.turn_flags.get("frost_shield", ""))
	if shield != "" and state.is_opponent(shield, player_id):
		return
	trigger(state, player_id, card_id, resolver)


## Активировать Frostbite карты card_id у игрока player_id (Avarosan Trapper
## зовёт напрямую — без сброса).
static func trigger(state: GameState, player_id: String, card_id: String, resolver: EffectResolver) -> void:
	state.turn_flags["frostbite_any"] = true
	var times := 2 if String(state.turn_flags.get("frost_twice", "")) == player_id else 1
	var copier := String(state.turn_flags.get("frost_copy", ""))
	resolver.log_event("frostbite", {"player_id": player_id, "card_id": card_id, "times": times})
	for t in range(times):
		if copier != "" and state.is_opponent(copier, player_id):
			resolver.push(frostbite_effect(card_id), copier, card_id)
		resolver.push(frostbite_effect(card_id), player_id, card_id)


## Hill Giant (Braum) в руке: "If an opponent would cause you to discard, devour
## a card or gain an Insane Outcast, you may reveal this card to negate that
## effect". inner применяется от имени жертвы, если она не откажется.
static func guard(victim: String, causer: String, what: String, inner: CardEffect) -> CardEffect:
	return _HillGiantGuard.new(victim, causer, what, inner)


static func _all_opponents_at_most(state: GameState, player_id: String, n: int) -> bool:
	for pid: String in state.turn_order:
		if state.is_opponent(player_id, pid) and state.players[pid].deck.hand.size() > n:
			return false
	return true


# --- Pirate Captain / Young White Dragon: счётчики хода ----------------------

## Игрок получил карту: покупка, бесплатный найм, Insane Outcast, карта из запаса.
## Pirate Captain возвращается на колоду, только если таких не было.
static func note_gain(state: GameState, player_id: String) -> void:
	var gained: Dictionary = (state.turn_flags.get("gained", {}) as Dictionary).duplicate()
	gained[player_id] = true
	state.turn_flags["gained"] = gained


## Сколько Power игрока нельзя тратить на войска (Young White Dragon: "You cannot
## deploy with Power gained this way").
static func locked_power(state: GameState, player_id: String) -> int:
	if String(state.turn_flags.get("olaf", "")) != player_id:
		return 0
	return mini(int(state.turn_flags.get("olaf_locked", 0)), state.players[player_id].power)


## Power потрачена не на войска (убийство, возврат шпиона) — первой уходит запертая.
static func spent_power(state: GameState, player_id: String, amount: int) -> void:
	BandleCards.spend(state, amount)
	if String(state.turn_flags.get("olaf", "")) != player_id:
		return
	state.turn_flags["olaf_locked"] = maxi(0, int(state.turn_flags.get("olaf_locked", 0)) - amount)


## Карта поставила войско (DeployTroop). Young White Dragon: "Whenever you play a
## card that deploys troops, gain Power equal to the number of troops deployed".
static func on_card_deploy(state: GameState, player_id: String) -> void:
	if String(state.turn_flags.get("olaf", "")) != player_id:
		return
	state.players[player_id].power += 1
	state.turn_flags["olaf_locked"] = int(state.turn_flags.get("olaf_locked", 0)) + 1


## Blink Dog: сколько своих войск встало рядом с войском другого игрока.
static func _moved_next_to_enemy(state: GameState, player_id: String, before: Dictionary) -> int:
	var n := 0
	for slot_id: String in state.troops.keys():
		if String(state.troops[slot_id]) == player_id and String(before.get(slot_id, "")) != player_id \
				and ShadowCards._next_to_enemy(state, player_id, slot_id):
			n += 1
	return n


# --- Эффекты ---------------------------------------------------------------

## Флаг хода = id игрока (у кого он действует).
class _SetPidFlag extends CardEffect:
	var key: String
	func _init(k: String) -> void:
		key = k
	func apply(state: GameState, player_id: String, _resolver: EffectResolver) -> void:
		state.turn_flags[key] = player_id


## "Each opponent discards down to N cards" — у каждого соперника с рукой больше N
## по одной карте до N (все сбросы одного соперника — одно действие для Hill Giant).
class _DiscardDownTo extends CardEffect:
	var limit: int
	func _init(n: int) -> void:
		limit = n
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var opps := ShadowCards._opponents_clockwise(state, player_id)
		opps.reverse()
		for opp: String in opps:
			var extra: int = state.players[opp].deck.hand.size() - limit
			if extra <= 0:
				continue
			var steps: Array[CardEffect] = []
			for i in range(extra):
				steps.append(ForceDiscard.VictimDiscard.new(player_id))
			resolver.push(FreljordCards.guard(opp, player_id, "discarding down to %d cards" % limit,
				SequenceEffect.new(steps)), opp)


## Starlit Seer: соперники с войском в локации шпиона и 3+ картами в руке сбрасывают карту.
class _OwlDiscard extends CardEffect:
	var site: String
	func _init(s: String) -> void:
		site = s
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var opps := ShadowCards._opponents_clockwise(state, player_id)
		opps.reverse()
		for opp: String in opps:
			if state.players[opp].deck.hand.size() < 3:
				continue
			var there := false
			for slot_id: String in state.graph.slots_of_site(site):
				if String(state.troops.get(slot_id, "")) == opp:
					there = true
					break
			if there:
				resolver.push(FreljordCards.guard(opp, player_id, "discarding",
					ForceDiscard.VictimDiscard.new(player_id)), opp)


## Avarosan Trapper: в локации шпиона войско другого игрока — можно активировать
## Frostbite другой карты, сыгранной в этот ход.
class _TrapperEcho extends CardEffect:
	var site: String
	func _init(s: String) -> void:
		site = s
	func _options(state: GameState, player_id: String) -> Array:
		var pile: Array = state.players[player_id].deck.played_pile.duplicate()
		var own := pile.find(FreljordCards.ETTERCAP)
		if own != -1:
			pile.remove_at(own)
		var out: Array = []
		for cid: String in pile:
			if FreljordCards.FROSTBITE.has(cid) and not out.has(cid):
				out.append(cid)
		return out
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var chosen = answer()
			if chosen != null and _options(state, player_id).has(String(chosen)):
				FreljordCards.trigger(state, player_id, String(chosen), resolver)
			return
		var other := false
		for slot_id: String in state.graph.slots_of_site(site):
			var owner := String(state.troops.get(slot_id, ""))
			if owner != "" and owner != "white" and owner != player_id:
				other = true
				break
		var options := _options(state, player_id)
		if not other or options.is_empty():
			return
		options.append("")
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "You may trigger the Frostbite of a card you played this turn"
		pd.choice_type = "target_card"
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)


## Rimetusk Shaman (Frostbite): карту ценой до N из сброса — в руку.
class _DiscardToHand extends CardEffect:
	var max_cost: int
	func _init(n: int) -> void:
		max_cost = n
	func _options(state: GameState, player_id: String) -> Array:
		var out: Array = []
		for cid: String in state.players[player_id].deck.discard_pile:
			var cost := CardLibrary.card_cost(cid)
			if cost <= max_cost and not out.has(cid):
				out.append(cid)
		return out
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		if is_answered():
			var chosen = answer()
			if chosen == null or String(chosen) == "" or not d.discard_pile.has(String(chosen)):
				return
			d.discard_pile.remove_at(d.discard_pile.rfind(String(chosen)))
			d.hand.append(String(chosen))
			resolver.log_event("discard_to_hand", {"player_id": player_id, "card_id": chosen})
			return
		var options := _options(state, player_id)
		if options.is_empty():
			return
		options.append("")
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Return a card that costs %d or less from your discard pile to your hand" % max_cost
		pd.choice_type = "target_card"
		pd.tag = "discard"
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)


## Avarosan Hearthguard (Frostbite): продвинуть ДРУГУЮ карту из руки или сброса
## (сама сброшенная карта лежит в сбросе — её копия годится, только если их две).
class _PromoteAnother extends CardEffect:
	var card: String
	func _init(c: String) -> void:
		card = c
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		var copies: int = d.hand.count(card) + d.discard_pile.count(card)
		var me := card
		resolver.push(PromoteCard.new("hand_or_discard", "", func(cid): return cid != me or copies > 1), player_id)


## Sejuani (Frostbite): сброшенная карта возвращается в руку.
class _ReturnToHand extends CardEffect:
	var card: String
	func _init(c: String) -> void:
		card = c
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		var idx := d.discard_pile.rfind(card)
		if idx == -1:
			return
		d.discard_pile.remove_at(idx)
		d.hand.append(card)
		resolver.log_event("discard_to_hand", {"player_id": player_id, "card_id": card})


## Hill Giant в руке жертвы: вопрос "раскрыть, чтобы отменить?".
class _HillGiantGuard extends CardEffect:
	var victim: String
	var causer: String
	var what: String
	var inner: CardEffect
	func _init(v: String, c: String, w: String, effect: CardEffect) -> void:
		victim = v
		causer = c
		what = w
		inner = effect
	func apply(state: GameState, _player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			if bool(answer()):
				resolver.log_event("hill_giant_block", {"player_id": victim, "by": causer})
			else:
				resolver.push(inner, victim)
			return
		if causer == victim or not state.is_opponent(causer, victim) \
				or not state.players[victim].deck.hand.has(FreljordCards.HILL_GIANT):
			resolver.push(inner, victim)
			return
		var pd := PendingDecision.new()
		pd.player_id = victim
		pd.prompt = "Reveal Hill Giant to prevent %s?" % what
		pd.choice_type = "confirm"
		pd.source_card = FreljordCards.HILL_GIANT
		pd.legal_options = [true, false]
		pd.target_effect = self
		resolver.request_decision(pd)


## Ashe: каждый соперник раскрывает 4 карты руки (лишние прячет сам), разыгравший
## выбирает из раскрытых одну, и тот её сбрасывает.
class _AsheVolley extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var opps := ShadowCards._opponents_clockwise(state, player_id)
		opps.reverse()
		for opp: String in opps:
			if not state.players[opp].deck.hand.is_empty():
				resolver.push(FreljordCards.guard(opp, player_id, "discarding",
					FreljordCards._AsheReveal.new(player_id, opp)), opp)


class _AsheReveal extends CardEffect:
	var owner: String
	var victim: String
	var hidden: Array = []
	var revealed := false
	func _init(o: String, v: String) -> void:
		owner = o
		victim = v
	func _shown(state: GameState) -> Array:
		var hand: Array = state.players[victim].deck.hand.duplicate()
		for cid in hidden:
			var idx := hand.find(cid)
			if idx != -1:
				hand.remove_at(idx)
		return hand
	func apply(state: GameState, _player_id: String, resolver: EffectResolver) -> void:
		var hand: Array = state.players[victim].deck.hand
		if is_answered():
			var chosen = answer()
			_answered = false
			_answer = null
			if not revealed:
				if chosen != null and hand.has(String(chosen)):
					hidden.append(String(chosen))
			else:
				var cid := String(chosen) if chosen != null else ""
				if not _shown(state).has(cid):
					return
				hand.remove_at(hand.find(cid))
				state.players[victim].deck.discard_pile.append(cid)
				resolver.log_event("force_discard", {"player_id": victim, "card_id": cid, "by": owner})
				FreljordCards.on_discard(state, victim, cid, resolver)
				return
		if not revealed:
			if hand.size() - hidden.size() > 4:
				var pd := PendingDecision.new()
				pd.player_id = victim
				pd.prompt = "Remorhaz: keep a card hidden (you reveal 4 cards)"
				pd.choice_type = "target_card"
				pd.tag = "hand"
				pd.source_card = FreljordCards.REMORHAZ
				pd.legal_options = _shown(state)
				pd.target_effect = self
				resolver.request_decision(pd)
				return
			revealed = true
			resolver.log_event("reveal_hand", {"player_id": victim, "cards": _shown(state), "by": owner})
		var options := _shown(state)
		if options.is_empty():
			return
		var pd2 := PendingDecision.new()
		pd2.player_id = owner
		pd2.prompt = "Choose a revealed card: the opponent discards it"
		pd2.choice_type = "target_card"
		pd2.source_card = FreljordCards.REMORHAZ
		pd2.legal_options = options
		pd2.target_effect = self
		resolver.request_decision(pd2)


## Volibear: "Discard any number of cards from your hand and draw that many. You may
## repeat this, but draw up to 1 less card each time."
class _Avalanche extends CardEffect:
	var cap: int
	var discarded := 0
	func _init(limit: int = 999) -> void:
		cap = limit
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		if is_answered():
			var chosen = answer()
			_answered = false
			_answer = null
			if chosen != null and String(chosen) != "" and d.hand.has(String(chosen)):
				var cid := String(chosen)
				d.hand.remove_at(d.hand.find(cid))
				d.discard_pile.append(cid)
				discarded += 1
				resolver.log_event("discard", {"player_id": player_id, "card_id": cid})
				resolver.push(self, player_id)
				FreljordCards.on_discard(state, player_id, cid, resolver)
				return
			var n := mini(discarded, cap)
			if n <= 0:
				return
			if n > 1:
				resolver.push(FreljordCards._Avalanche.new(n - 1), player_id)
			resolver.push(DrawCards.new(n), player_id)
			return
		if d.hand.is_empty():
			if discarded > 0:
				set_answer("")
				apply(state, player_id, resolver)
			return
		var options: Array = d.hand.duplicate()
		options.append("")
		var pd := PendingDecision.new()
		pd.player_id = player_id
		if discarded == 0:
			pd.prompt = "Discard a card to draw one later (up to %d)" % cap if cap < 999 else "Discard any number of cards, then draw that many"
		else:
			pd.prompt = "Discard another card, or stop to draw %d" % mini(discarded, cap)
		pd.choice_type = "target_card"
		pd.tag = "hand"
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)


## Pirate Captain (Gragas): "If you don't gain any cards this turn, you may put
## this card on top of your deck before refilling your hand at the end of your turn".
class _BackOnTop extends CardEffect:
	var card: String
	func _init(c: String) -> void:
		card = c
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var p: PlayerState = state.players[player_id]
		if (state.turn_flags.get("gained", {}) as Dictionary).has(player_id):
			return
		if not p.deck.played_pile.has(card) or p.pending_promotions.has(card):
			return
		var c := card
		var ask := OptionalEffect.new(CallbackEffect.new(func(s: GameState, pid: String, r: EffectResolver):
			var d: Deck = s.players[pid].deck
			if d.played_pile.has(c):
				d.played_pile.erase(c)
				d.draw_pile.append(c)  # верх колоды — конец массива (Deck.draw_one)
				r.log_event("card_on_top", {"player_id": pid, "card_id": c})),
			"Put Pirate Captain on top of your deck?")
		ask.source_card = card
		resolver.push(ask, player_id)


## Blink Dog (Aurora), первый вариант. Решение владельца (2026-10-14): "hex" —
## локация, где есть твоё войско; чужие войска оттуда (других игроков и белые)
## можно переставить на свободные места рядом с этой локацией.
class _ScatterSite extends CardEffect:
	func is_available(state: GameState, player_id: String) -> bool:
		return not _sites(state, player_id).is_empty()

	static func _sites(state: GameState, player_id: String) -> Array:
		var result: Array = []
		for site_id: String in state.graph.sites.keys():
			var mine := false
			var other := false
			for slot_id: String in state.graph.slots_of_site(site_id):
				var owner := String(state.troops.get(slot_id, ""))
				if owner == player_id:
					mine = true
				elif owner != "" and not state.is_ally(player_id, owner):
					other = true
			if mine and other:
				result.append(site_id)
		return result

	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var site := String(answer())
			if site == "":
				return
			var move := MoveTroop.new(99, true, false, true, site)
			move.dest_near_site = site
			resolver.push(move, player_id)
			return
		var sites := _sites(state, player_id)
		if sites.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Choose a site with your troop"
		pd.choice_type = "target_site"
		pd.legal_options = sites
		pd.target_effect = self
		resolver.request_decision(pd)
