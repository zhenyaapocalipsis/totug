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
##   "deck_frostbite" — id игрока: его сброс с верха колоды (scry) тоже Frostbite (Cultist Fanatic);
##   "frost_copy"    — id игрока: получает Frostbite соперников (Bulette);
##   "frost_shield"  — id игрока: его соперники Frostbite не активируют (Mammoth);
##   "frost_twice"   — id игрока: его Frostbite срабатывает дважды (Storm Giant).
##
## На доске (state.wards, до начала следующего хода владельца):
##   {"kind": "storm"|"pillar", "owner", "site"} — Glacial Storm (Roc), Ice Pillar
##       (Giant Ape): соперники владельца платят там +2 Power, чтобы поставить
##       войско, шпиона, вытеснить войско или убить войско владельца;
##   {"kind": "scarab", "owner"} — Scarab of Protection: войска владельца нельзя
##       убить или вытеснить;
##   {"kind": "ice", "owner", "slot"} — лёд на войске (Roc): в начале хода, если
##       войско стоит, Roc возвращается в руку (Roc Egg).
## Перед игроком (state.front[pid]): Roc Egg и предметы Masterwork (Stone Giant).

const GUARD := "49600"
const CULTIST := "49601"
const WEREWOLF := "49602"
const GOAT := "49603"
const CENTAUR := "49604"
const BULETTE := "49605"
const MEPHIT := "49606"
const ELK := "49607"
const BADGER := "49608"
const BOAR := "49609"
const OWL := "49610"
const WINTER_WOLF := "49611"
const HYENA := "49612"
const OWLBEAR := "49613"
const HILL_GIANT := "49614"
const CLOUD_GIANT := "49615"
const REMORHAZ := "49616"
const MAMMOTH := "49617"
const STORM_GIANT := "49618"
const ROC := "49619"
const FROST_GIANT := "49620"
const STONE_GIANT := "49621"
const GIANT_APE := "49622"
const ROC_EGG := "49623"

## Колода Masterwork (Stone Giant): 10 предметов, один экземпляр каждого.
const FROST_BRAND := "49624"
const ROD := "49625"
const HAT := "49626"
const SWORD := "49627"
const ARMOR := "49628"
const BOOTS := "49629"
const HORN := "49630"
const CLOAK := "49631"
const DEMON_ARMOR := "49632"
const SCARAB := "49633"
const MASTERWORK: Array[String] = [FROST_BRAND, ROD, HAT, SWORD, ARMOR, BOOTS, HORN, CLOAK, DEMON_ARMOR, SCARAB]

const FROSTBITE: Array[String] = [GUARD, GOAT, CENTAUR, MEPHIT, BOAR, OWL, HYENA, MAMMOTH]
const WARD_TAX := 2


static func build(card_id: String) -> CardEffect:
	match card_id:
		GUARD:  # Avarosan Sentry
			return SequenceEffect.new([
				GainInfluence.new(2),
				ConditionalEffect.new(func(state, pid):
					return int(state.turn_flags.get("cards_played", 0)) == 1 and state.players[pid].deck.hand.size() <= 3,
					GainInfluence.new(1)),
			])
		CULTIST:  # Bone Scryer
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
		GOAT:  # Lorekeeper
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
		ELK:  # Valhir's Prophet
			return ChooseEffect.new([
				SequenceEffect.new([PlaceSpy.new(1), ForceDiscard.new("each_opponent", 2), GainInfluence.new(1)]),
				ReturnOwnSpy.new(SequenceEffect.new([ForceDiscard.new("each_opponent", 3), GainPower.new(2)])),
			], ["Place a spy, each opponent with 3+ cards in hand discards a card, +1 Influence",
				"Return one of your spies -> each opponent with 4+ cards in hand discards a card, +2 Power"])
		BADGER:  # Avarosan Trapper
			return ChooseEffect.new([
				PlaceSpy.new(1, false, func(site): return _TrapperEcho.new(site)),
				ReturnOwnSpy.new(GainPower.new(3)),
			], ["Place a spy (another player's troop there: trigger the Frostbite of another card you played)",
				"Return one of your spies -> +3 Power"])
		BOAR:  # Avarosan Hearthguard
			return AtEndOfTurn.new(PromoteCard.new("played_other", BOAR))
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
		ROC:  # Anivia
			return SequenceEffect.new([
				DrawCards.new(1),
				_PlaceWard.new("storm"),
				_IceToken.new(),
				_GainFront.new(ROC_EGG),
			])
		FROST_GIANT:  # Tryndamere
			return SequenceEffect.new([
				PromoteCard.new("top_of_deck"),
				ChooseEffect.new([GainPower.new(2), PlayCardFromZone.new("inner_circle")],
					["+2 Power", "Play a card from your inner circle as if from your hand (it stays there)"]),
			])
		STONE_GIANT:  # Ornn
			return _Forge.new()
		GIANT_APE:  # Trundle
			return SequenceEffect.new([DeployTroop.new(4), _PlaceWard.new("pillar")])
		ROC_EGG:  # лежит перед игроком, не разыгрывается
			return SequenceEffect.new([])
		FROST_BRAND:  # Infinity Edge
			return GainPower.new(2)
		ROD:  # Rod of Ages
			return GainInfluence.new(2)
		HAT:  # Rabadon's Deathcap
			return DrawCards.new(1)
		SWORD:  # Blade of the Ruined King
			return AtEndOfTurn.new(PromoteCard.new("played_other", "", Callable(), 1, true))
		ARMOR:  # Warmog's Armor
			return GainVP.new(2)
		BOOTS:  # Shurelya's Reverie
			return MoveTroop.new(2, true)
		HORN:  # Trinity Force
			return DeployTroop.new(3)
		CLOAK:  # Bloodthirster
			return ChooseEffect.new([PlaceSpy.new(2, true), ReturnTroopOrSpy.new(2, true, false, true)],
				["Place up to 2 spies", "Return up to 2 spies"])
		DEMON_ARMOR:  # Thornmail
			return ChooseEffect.new([GiveInsaneOutcast.new("each_opponent"), ForceDiscard.new("each_opponent", 0)],
				["Each opponent gains an Insane Outcast", "Each opponent discards a card"])
		SCARAB:  # Zhonya's Hourglass
			return _Scarab.new()
	return null


## Эффект Frostbite карты (null — у карты его нет).
static func frostbite_effect(card_id: String) -> CardEffect:
	match card_id:
		GUARD:
			return RecruitFree.new("", 3)
		GOAT:
			return DrawCards.new(1)
		CENTAUR:
			return GainVP.new(1)
		MEPHIT:
			return _DiscardToHand.new(2)
		BOAR:
			return _PromoteAnother.new(BOAR)
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


# --- Glacial Storm / Ice Pillar / Scarab ------------------------------------

## Доплата Power для player_id в локации site: по WARD_TAX за каждый Glacial
## Storm / Ice Pillar соперника. victim_owner — только знаки этого владельца
## (убийство его войска); "" — любые (поставить войско, шпиона, вытеснить).
static func tax_at(state: GameState, player_id: String, site: String, victim_owner: String = "") -> int:
	if site == "" or state.wards.is_empty():
		return 0
	var tax := 0
	for w: Dictionary in state.wards:
		if not (w["kind"] in ["storm", "pillar"]) or String(w["site"]) != site:
			continue
		var owner := String(w["owner"])
		if not state.is_opponent(owner, player_id):
			continue
		if victim_owner != "" and owner != victim_owner:
			continue
		tax += WARD_TAX
	return tax


static func _scarab_shields(state: GameState, player_id: String, owner: String) -> bool:
	for w: Dictionary in state.wards:
		if w["kind"] == "scarab" and String(w["owner"]) == owner and state.is_opponent(owner, player_id):
			return true
	return false


## Доплата за убийство (supplant=false) или вытеснение войска в слоте.
static func hit_tax(state: GameState, player_id: String, slot_id: String, supplant: bool = false) -> int:
	var owner := String(state.troops.get(slot_id, ""))
	var site := state.graph.site_of_slot(slot_id)
	return tax_at(state, player_id, site, "" if supplant else owner)


## Можно ли игроку убить / вытеснить войско в слоте (Scarab, хватает ли Power
## на доплату). extra — сколько Power уходит ещё (базовое действие: 3).
static func can_hit(state: GameState, player_id: String, slot_id: String, supplant: bool = false, extra: int = 0) -> bool:
	if state.wards.is_empty():
		return true
	var owner := String(state.troops.get(slot_id, ""))
	if owner != "" and owner != "white" and _scarab_shields(state, player_id, owner):
		return false
	var tax := hit_tax(state, player_id, slot_id, supplant)
	return tax == 0 or state.players[player_id].power >= tax + extra


static func pay_hit(state: GameState, player_id: String, slot_id: String, supplant: bool = false) -> void:
	var tax := hit_tax(state, player_id, slot_id, supplant)
	if tax > 0:
		state.players[player_id].power = maxi(0, state.players[player_id].power - tax)


static func deploy_tax(state: GameState, player_id: String, slot_id: String) -> int:
	return tax_at(state, player_id, state.graph.site_of_slot(slot_id))


static func pay_deploy(state: GameState, player_id: String, slot_id: String) -> void:
	var tax := deploy_tax(state, player_id, slot_id)
	if tax > 0:
		state.players[player_id].power = maxi(0, state.players[player_id].power - tax)


static func spy_allowed(state: GameState, player_id: String, site: String) -> bool:
	var tax := tax_at(state, player_id, site)
	return tax == 0 or state.players[player_id].power >= tax


static func pay_spy(state: GameState, player_id: String, site: String) -> void:
	var tax := tax_at(state, player_id, site)
	if tax > 0:
		state.players[player_id].power = maxi(0, state.players[player_id].power - tax)


# --- Начало хода: знаки, Roc Egg, предметы Masterwork ------------------------

## Зовёт TurnEngine.start_turn. resolver == null (тесты) — эффекты предметов
## не применяются, только снимаются знаки.
static func start_turn(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	var front: Array = state.front.get(player_id, [])
	if state.wards.is_empty() and front.is_empty():
		return
	var egg_hatches := false
	var kept: Array = []
	for w: Dictionary in state.wards:
		if String(w["owner"]) != player_id:
			kept.append(w)
		elif w["kind"] == "ice" and String(state.troops.get(String(w["slot"]), "")) == player_id:
			egg_hatches = front.has(ROC_EGG)
		elif w["kind"] == "scarab":
			front.erase(SCARAB)  # сработавший Scarab of Protection уходит из игры
	state.wards = kept
	if front.has(ROC_EGG):
		front.erase(ROC_EGG)
		if egg_hatches:
			_roc_to_hand(state, player_id, resolver)
	if resolver == null:
		return
	var effects: Array[CardEffect] = []
	for item: String in front:
		if item != SCARAB:
			effects.append(_ItemFromCard.new(build(item), item))
	if not effects.is_empty():
		resolver.log_event("masterwork", {"player_id": player_id, "count": effects.size()})
		resolver.apply(SequenceEffect.new(effects), player_id, state)


## Roc Egg: Roc "from anywhere" в руку — из колоды, сброса, Внутреннего круга,
## стопки сожранных или рынка.
static func _roc_to_hand(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	var d: Deck = state.players[player_id].deck
	var ic: Array = state.stock(player_id).deck.inner_circle
	var found := false
	for pile: Array in [d.draw_pile, d.discard_pile, ic, state.devoured_pile, state.market.deck]:
		var idx := pile.find(ROC)
		if idx != -1:
			pile.remove_at(idx)
			found = true
			break
	if not found:
		for opp: String in state.turn_order:
			var od: Deck = state.players[opp].deck
			for pile: Array in [od.draw_pile, od.discard_pile, od.hand, state.stock(opp).deck.inner_circle]:
				var idx2 := pile.find(ROC)
				if idx2 != -1:
					pile.remove_at(idx2)
					found = true
					break
			if found:
				break
	if not found:
		var slot := state.market.display.find(ROC)
		if slot != -1:
			state.market.recruit_at(slot)
			found = true
	if found:
		d.hand.append(ROC)
		if resolver != null:
			resolver.log_event("roc_reborn", {"player_id": player_id, "card_id": ROC})


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
		var own := pile.find(FreljordCards.BADGER)
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


## Glacial Storm (Roc, любая локация — шпионы оттуда уходят) / Ice Pillar (Giant
## Ape, локация с твоим Присутствием) до начала твоего следующего хода.
class _PlaceWard extends CardEffect:
	var kind: String
	func _init(k: String) -> void:
		kind = k
	func _options(state: GameState, player_id: String) -> Array:
		if kind == "storm":
			return Array(state.graph.sites.keys())
		return Array(state.presence.sites_with_presence(player_id, state.troops, state.spies))
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var site := String(answer())
			if not _options(state, player_id).has(site):
				return
			state.wards.append({"kind": kind, "owner": player_id, "site": site})
			resolver.log_event("ward", {"player_id": player_id, "kind": kind, "site_id": site})
			if kind == "storm":
				for owner: String in (state.spies.get(site, []) as Array).duplicate():
					Actions.remove_spy(state, site, owner, player_id)
					resolver.log_event("return_spy", {"player_id": player_id, "site_id": site, "spy_owner": owner})
			return
		var options := _options(state, player_id)
		if options.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Put a Glacial Storm on a site (its spies leave)" if kind == "storm" else "Put an Ice Pillar on a site where you have presence"
		pd.choice_type = "target_site"
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)


## Roc: лёд на одно своё войско в локации.
class _IceToken extends CardEffect:
	func _options(state: GameState, player_id: String) -> Array:
		var out: Array = []
		for slot_id: String in state.troops.keys():
			if String(state.troops[slot_id]) == player_id and state.graph.site_of_slot(slot_id) != "":
				out.append(slot_id)
		return out
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var slot := String(answer())
			if _options(state, player_id).has(slot):
				state.wards.append({"kind": "ice", "owner": player_id, "slot": slot})
				resolver.log_event("ward", {"player_id": player_id, "kind": "ice", "slot_id": slot})
			return
		var options := _options(state, player_id)
		if options.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Put Ice on one of your troops at a site (the Roc returns to your hand next turn while it stands)"
		pd.choice_type = "target_slot"
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)


## Положить карту перед игроком (Roc Egg; предмет Masterwork — через _Forge).
class _GainFront extends CardEffect:
	var card: String
	func _init(c: String) -> void:
		card = c
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var front: Array = state.front.get(player_id, [])
		if front.has(card):
			return
		front.append(card)
		state.front[player_id] = front
		resolver.log_event("gain_front", {"player_id": player_id, "card_id": card})


## Ornn: из 2 верхних карт колоды Masterwork одна — перед тобой, другая — под низ;
## затем сработать эффект одного из твоих предметов.
class _Forge extends CardEffect:
	var stage := 0
	var top: Array = []
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if stage == 0:
			stage = 1
			for i in range(mini(2, state.masterwork.size())):
				top.append(state.masterwork.pop_back())
			if top.size() == 1:
				set_answer(top[0])
			elif top.size() == 2:
				var pd := PendingDecision.new()
				pd.player_id = player_id
				pd.prompt = "Gain a Masterwork item (the other goes to the bottom)"
				pd.choice_type = "target_card"
				pd.legal_options = top.duplicate()
				pd.target_effect = self
				resolver.request_decision(pd)
				return
		if stage == 1:
			stage = 2
			if is_answered() and top.has(String(answer())):
				var pick := String(answer())
				top.erase(pick)
				var front: Array = state.front.get(player_id, [])
				front.append(pick)
				state.front[player_id] = front
				resolver.log_event("gain_front", {"player_id": player_id, "card_id": pick})
				for rest in top:
					state.masterwork.insert(0, rest)
			_answered = false
			_answer = null
		if stage == 2:
			var items: Array = []
			for cid in state.front.get(player_id, []):
				if FreljordCards.MASTERWORK.has(cid) and not items.has(cid):
					items.append(cid)
			if items.is_empty():
				return
			if items.size() > 1 and not is_answered():
				var pd2 := PendingDecision.new()
				pd2.player_id = player_id
				pd2.prompt = "Trigger the effect of one of your Masterwork items"
				pd2.choice_type = "target_card"
				pd2.legal_options = items
				pd2.target_effect = self
				resolver.request_decision(pd2)
				return
			var item := String(answer()) if is_answered() and items.has(String(answer())) else String(items[0])
			resolver.log_event("masterwork", {"player_id": player_id, "card_id": item})
			resolver.push(FreljordCards.build(item), player_id, item)


## Scarab of Protection: до начала твоего следующего хода твои войска нельзя
## убить или вытеснить; затем предмет уходит из игры (start_turn).
class _Scarab extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		state.wards.append({"kind": "scarab", "owner": player_id})
		resolver.log_event("ward", {"player_id": player_id, "kind": "scarab"})


## Эффект предмета в начале хода — вопрос показывает сам предмет.
class _ItemFromCard extends CardEffect:
	var inner: CardEffect
	var card: String
	func _init(effect: CardEffect, c: String) -> void:
		inner = effect
		card = c
	func apply(_state: GameState, player_id: String, resolver: EffectResolver) -> void:
		resolver.push(inner, player_id, card)
