class_name VoidCards
extends RefCounted

## Полуколода Void (New Era) — способности карт Void из фан-мода Runeterra
## Reforged на существах FAR REALM: звёздные порождения, слаады, гит, три-крины
## (без зверей — правило владельца). Таблица id -> существо -> карта мода —
## Claude outputs/new_era_void.md.
##
## Перевод на правила этой игры: Valor -> MALICE.
## Правило мода: "40 (50 if you play with void half-deck) cubes" — с этой
## полуколодой у каждого игрока 50 войск (setup_troops, GameState.starting_troops).
##
## Счётчики хода — state.turn_flags (сбрасываются в start_turn):
##   "kassadin"    — Githzerai Zerth: убивать войска можно где угодно;
##   "kogmaw"      — Red Slaad: deploy / assassinate / supplant до 3 мест от своих войск;
##   "malzahar"    — Inquisitor of the Mind Fire: другая карта поставила войска -> ещё 2;
##   "undertitan"  — Elder Thing: "deploy X troops" карты можно заменить на +X Power;
##   "hive_herald" — Carrion Stalker: свой шпион к чужому -> вернуть чужого;
##   "deploys"     — сколько войск игрок поставил в этот ход (Lesser Star Spawn Emissary).
##
## Шпион на карте рынка (Blue Slaad): state.market_spies — "индекс" ->
## {"owner", "card"}. Соперник покупает такую карту, только заплатив 3 Power
## (шпион уходит хозяину), и тогда она стоит ему на 6 дешевле. Карта ушла из
## слота — шпион возвращается хозяину (sync_market_spies).
##
## Eye Monger (Vel'Koz): Deck.set_aside = [Eye Monger, отложенная карта]; в
## начале каждого своего хода отложенная карта разыгрывается (on_start_turn).

const KAISA := "50000"  # Githyanki Knight
const BELVETH := "50001"  # Greater Star Spawn Emissary
const CHOGATH := "50002"  # Froghemoth Elder
const KASSADIN := "50003"  # Githzerai Zerth
const KHAZIX := "50004"  # Thri-kreen Marauder
const KOGMAW := "50005"  # Red Slaad
const MALZAHAR := "50006"  # Inquisitor of the Mind Fire
const REKSAI := "50007"  # Groundling Stalker
const VELKOZ := "50008"  # Eye Monger
const HATCHLING := "50010"  # Lesser Star Spawn Emissary (Xer'Sai Hatchling)
const ELDER := "50011"  # Githzerai Monk (Belvethi Elder)
const CALLER := "50012"  # Thri-kreen Psion (Xer'Sai Caller)
const SWALLOWER := "50013"  # Hook Horror (Dune Swallower)
const UNDERTITAN := "50014"  # Elder Thing (Xerxa'Reth Undertitan)
const HERALD := "50015"  # Carrion Stalker (Hive Herald)
const DUNEBREAKER := "50016"  # Gray Slaad (Xer'Sai Dunebreaker)
const HORROR := "50017"  # Green Slaad (Camouflaged Horror)
const ABOMINATION := "50018"  # Blue Slaad (Void Abomination)
const BLASTER := "50019"  # Githyanki Dracomancer (Void Blaster)
const VOIDLING := "50020"  # Githyanki Warrior (Voidling)

const DECK_KEY := "void"
const TROOPS_WITH_VOID := 50
const REACH := 3
const SPY_RETURN_POWER := 3
const SPY_DISCOUNT := 6

## Thri-kreen Marauder (Kha'Zix): способности, которые карта копит навсегда.
const EVOLUTIONS := ["power", "kill", "spies", "draw"]
const EVOLUTION_LABELS := ["+2 Power", "Assassinate a troop", "Place 2 spies", "Draw a card"]


static func build(card_id: String) -> CardEffect:
	match card_id:
		KAISA:
			return _choose(KAISA, [
				SupplantTroop.new(1, false, true),
				_PerCount.new(func(state, pid): return state.players[pid].deck.hand.size(), 1,
					func(n): return GainPower.new(n)),
				SequenceEffect.new([DrawCards.new(2), DiscardCardEffect.new(1)]),
				AssassinateTroop.new(2),
			], ["Supplant a troop anywhere on the board", "+1 Power for each card in your hand",
				"Draw 2 cards, then discard a card", "Assassinate 2 troops"])
		BELVETH:
			return SequenceEffect.new([DeployTroop.new(4),
				_PerCount.new(func(s, p): return VoidCards.total_control_count(s, p), 1, func(n): return GainVP.new(n))])
		CHOGATH:
			return _DevourHex.new()
		KASSADIN:
			return SequenceEffect.new([ShadowCards._SetFlag.new("kassadin"),
				_PerCount.new(func(s, p): return VoidCards.controlled_count(s, p), 2, func(n): return AssassinateTroop.new(n))])
		KHAZIX:
			return _Evolve.new()
		KOGMAW:
			return SequenceEffect.new([GainPower.new(4), ShadowCards._SetFlag.new("kogmaw")])
		MALZAHAR:
			return SequenceEffect.new([ShadowCards._SetFlag.new("malzahar"), _choose(MALZAHAR, [
				ReturnTroopOrSpy.new(2, true), SupplantTroop.new(2, true),
			], ["Return up to 2 troops or spies", "Supplant 2 white troops"])])
		REKSAI:
			return _choose(REKSAI, [
				_PerCount.new(func(s, p): return VoidCards.total_control_count(s, p), 2, func(n): return DrawCards.new(n)),
				SequenceEffect.new([SupplantTroop.new(1), DeployTroop.new(2)]),
				SequenceEffect.new([_move_unit(), _move_unit()]),
			], ["Draw a card for every 2 sites under your total control",
				"Supplant a troop and deploy 2 troops", "Move up to 2 troops or spies"])
		VELKOZ:
			return _SetAside.new()
		HATCHLING:
			return SequenceEffect.new([GainPower.new(2), _DevourTop.new(),
				AtEndOfTurn.new(ConditionalEffect.new(func(state, _pid): return deploys(state) == 0,
					_DevourSelf.new(HATCHLING)))])
		ELDER:
			return _choose(ELDER, [
				_PerCount.new(func(s, p): return VoidCards.controlled_count(s, p), 2, func(n): return GainInfluence.new(n)),
				AtEndOfTurn.new(PromoteCard.new("played_other", ELDER)),
			], ["+1 Influence for every 2 sites you control", "At end of turn, promote another card you played this turn"])
		CALLER:
			return _choose(CALLER, [_TopCheap.new(5, 2, 2), AssassinateTroop.new(1, true)],
				["Look at the top 5 cards of your deck: up to 2 that cost 2 or less to your hand",
					"Assassinate a white troop"])
		SWALLOWER:
			return _choose(SWALLOWER, [
				_PerCount.new(func(s, p): return VoidCards.controlled_count(s, p), 2, func(n): return GainPower.new(n)),
				DeployTroop.new(3), SupplantTroop.new(1, true),
			], ["+1 Power for every 2 sites you control", "Deploy 3 troops", "Supplant a white troop"])
		UNDERTITAN:
			return SequenceEffect.new([ShadowCards._SetFlag.new("undertitan"), DeployTroop.new(3)])
		HERALD:
			return SequenceEffect.new([ShadowCards._SetFlag.new("hive_herald"), _choose(HERALD, [
				PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
					func(state, _pid): return ShurimaCards._site_full(state, site), DeployTroop.new(2))),
				ReturnOwnSpy.new(null, func(site): return SupplantTroop.new(1, true, false, false, Callable(), site)),
			], ["Place a spy (site full: deploy 2 troops)", "Return one of your spies -> supplant a white troop at that site"])])
		DUNEBREAKER:
			return _choose(DUNEBREAKER, [GainInfluence.new(2), ReturnTroopOrSpy.new(1, false, true)],
				["+2 Influence", "Return a troop"])
		HORROR:
			return _MarketReveal.new(3, 5)
		ABOMINATION:
			return _choose(ABOMINATION, [PlaceSpy.new(1), _MarketSpy.new()],
				["Place a spy at a site", "Place a spy on a market card"])
		BLASTER:
			return _choose(BLASTER, [GainPower.new(2), _GainSameName.new(), ReturnTroopOrSpy.new(1)],
				["+2 Power", "Gain a market card with the same name as a card you played this turn", "Return a troop or spy"])
		VOIDLING:
			var all: Array[CardEffect] = [MoveTroop.new(1, false, true), DeployTroop.new(2), AssassinateTroop.new(1, true)]
			return BandleCards._Branch.new(func(state, pid): return total_control_count(state, pid) >= 4,
				SequenceEffect.new(all),
				_choose(VOIDLING, [MoveTroop.new(1, false, true), DeployTroop.new(2), AssassinateTroop.new(1, true)],
					["Move one of your troops", "Deploy 2 troops", "Assassinate a white troop"]))
	return null


static func _choose(card_id: String, opts: Array[CardEffect], labels: Array[String]) -> ChooseEffect:
	var c := ChooseEffect.new(opts, labels)
	c.source_card = card_id
	return c


## Groundling Stalker (Rek'Sai): "move up to 2 troops or spies" — дважды выбор.
static func _move_unit() -> ChooseEffect:
	var c := ChooseEffect.new([MoveTroop.new(1), SiegeCards.MoveSpy.new(false), SequenceEffect.new()],
		["Move a troop", "Move one of your spies", "Done"])
	c.source_card = REKSAI
	return c


static func controlled_count(state: GameState, player_id: String) -> int:
	return BandleCards._controlled(state, player_id).size()


static func total_control_count(state: GameState, player_id: String) -> int:
	var n := 0
	for site_id: String in state.graph.sites.keys():
		if state.control.has_total_control(player_id, site_id, state.troops, state.spies):
			n += 1
	return n


static func deploys(state: GameState) -> int:
	return int(state.turn_flags.get("deploys", 0))


## Войско игрока встало на доску (карта, базовое действие, supplant).
static func note_deploy(state: GameState) -> void:
	state.turn_flags["deploys"] = deploys(state) + 1


# --- 50 войск ------------------------------------------------------------------

## Полуколода Void в партии: по 50 войск на игрока (2 на 2 — по 50 на каждого в общий барак).
static func setup_troops(state: GameState) -> void:
	if not state.half_decks.has(DECK_KEY):
		return
	var extra := TROOPS_WITH_VOID - PlayerState.STARTING_TROOPS
	state.starting_troops = TROOPS_WITH_VOID
	for pid: String in state.players.keys():
		state.stock(pid).troops_in_barracks += extra


# --- Дальность (Red Slaad, Githzerai Zerth) --------------------------------------

## Может ли игрок действовать по слоту вне Присутствия: kind "deploy" | "kill" | "supplant".
static func reach(state: GameState, player_id: String, slot_id: String, kind: String) -> bool:
	if player_id != state.current_player():
		return false
	if kind == "kill" and state.turn_flags.get("kassadin", false):
		return true
	if not state.turn_flags.get("kogmaw", false):
		return false
	return _near_own_troop(state, player_id, slot_id, REACH)


## Своё войско не дальше depth мест: слоты одной локации — одно место.
static func _near_own_troop(state: GameState, player_id: String, slot_id: String, depth: int) -> bool:
	var seen := {slot_id: true}
	var frontier: Array = _with_site(state, slot_id)
	for s: String in frontier:
		seen[s] = true
	for step in range(depth + 1):
		for s: String in frontier:
			if String(state.troops.get(s, "")) == player_id:
				return true
		if step == depth:
			break
		var next: Array = []
		for s: String in frontier:
			var around: Array = Array(state.graph.adjacent_slots(s))
			var site := state.graph.site_of_slot(s)
			if site != "":
				around.append_array(Array(state.graph.slots_adjacent_to_site(site)))
				for other_site: String in state.graph.adjacent_sites(site):
					around.append_array(Array(state.graph.slots_of_site(other_site)))
			else:
				for other_site: String in state.graph.sites_adjacent_to_slot(s):
					around.append_array(Array(state.graph.slots_of_site(other_site)))
			for n: String in around:
				for m: String in _with_site(state, n):
					if not seen.has(m):
						seen[m] = true
						next.append(m)
		frontier = next
	return false


static func _with_site(state: GameState, slot_id: String) -> Array:
	var site := state.graph.site_of_slot(slot_id)
	if site == "":
		return [slot_id]
	return Array(state.graph.slots_of_site(site))


## Red Slaad: пустые слоты в пределах досягаемости — к обычным слотам для войск.
static func add_reach_slots(state: GameState, player_id: String, legal: PackedStringArray) -> PackedStringArray:
	if player_id != state.current_player() or not state.turn_flags.get("kogmaw", false):
		return legal
	var out := legal.duplicate()
	for slot_id: String in state.graph.slots.keys():
		if String(state.troops.get(slot_id, "")) == "" and not out.has(slot_id) \
				and _near_own_troop(state, player_id, slot_id, REACH):
			out.append(slot_id)
	return out


## Базовое убийство (3 Power) по дальности Red Slaad / Githzerai Zerth.
static func can_kill_far(state: GameState, player_id: String, slot_id: String) -> bool:
	return state.is_enemy(player_id, String(state.troops.get(slot_id, ""))) and reach(state, player_id, slot_id, "kill")


# --- Хуки войск и шпионов ------------------------------------------------------

## DeployTroop перед первым войском цепочки. Elder Thing: вопрос "войска или
## Power". true — эффект заменён вопросом (DeployTroop сам ничего не делает).
static func before_deploy(state: GameState, player_id: String, eff: DeployTroop, resolver: EffectResolver) -> bool:
	eff.void_checked = true
	if eff.bonus or eff.remaining <= 0 or player_id != state.current_player() \
			or not state.turn_flags.get("undertitan", false):
		return false
	var n := eff.remaining
	var c := ChooseEffect.new([eff, GainPower.new(n)],
		["Deploy %d troop%s" % [n, "" if n == 1 else "s"], "+%d Power instead" % n], "Elder Thing:")
	c.source_card = UNDERTITAN
	resolver.push(c, player_id)
	return true


## Первое войско цепочки DeployTroop встало. Inquisitor of the Mind Fire: ещё 2.
static func on_card_deploy(state: GameState, player_id: String, eff: DeployTroop, resolver: EffectResolver) -> void:
	if eff.bonus or player_id != state.current_player() or not state.turn_flags.get("malzahar", false):
		return
	var more := DeployTroop.new(2)
	more.bonus = true
	resolver.push(more, player_id, MALZAHAR)


## Шпион поставлен. Carrion Stalker: у чужого шпиона там — вернуть одного из них.
static func on_place_spy(state: GameState, player_id: String, site_id: String, resolver: EffectResolver) -> void:
	if not state.turn_flags.get("hive_herald", false) or player_id != state.current_player():
		return
	for owner: String in (state.spies.get(site_id, []) as Array):
		if state.is_enemy(player_id, owner):
			resolver.push(ReturnTroopOrSpy.new(1, false, false, true, site_id), player_id, HERALD)
			return


## Начало хода: шпионы рынка и отложенная карта Eye Monger.
static func on_start_turn(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	sync_market_spies(state)
	if resolver == null or resolver.is_waiting():
		return
	var aside: Array = state.players[player_id].deck.set_aside
	for i in range(1, aside.size(), 2):
		var card := String(aside[i])
		var aspect := CardLibrary.card_aspect(card)
		if aspect != "":
			state.played_aspects_this_turn.append(aspect)
		resolver.log_event("set_aside_play", {"player_id": player_id, "card_id": card})
		resolver.apply(CardLibrary.get_effect(card), player_id, state, card)
		if resolver.is_waiting():
			return


# --- Съеденный гекс (Froghemoth Elder) ------------------------------------------

## Гекс раскладки уходит с доски: состояние получает новый граф без его
## локаций и мест (старый граф делят копии бота — его не трогаем), новые
## Presence и SiteControl. Шпионы на его локациях — в бараки хозяев.
static func remove_hex(state: GameState, hex: String) -> void:
	if hex == "" or state.removed_hexes.has(hex):
		return
	var g := state.graph.without_hex(hex)
	# Тупиков в игре нет (решение владельца 2026-09-22): кольца соседей, которые
	# вели только в съеденный гекс, уходят тоже; войска с них — хозяевам.
	for slot_id in g.prune_dead_ends():
		state.removed_slots.append(slot_id)
		var owner := String(state.troops.get(slot_id, ""))
		if state.players.has(owner):
			state.stock(owner).troops_in_barracks += 1
		state.troops.erase(slot_id)
	g.finalize()
	for site_id: String in state.spies.keys():
		if g.sites.has(site_id):
			continue
		for owner in (state.spies[site_id] as Array):
			state.stock(String(owner)).spies_in_barracks += 1
		state.spies.erase(site_id)
	for slot_id: String in state.troops.keys():
		if not g.slots.has(slot_id):
			state.troops.erase(slot_id)
	for site_id: String in state.board_vp.keys():
		if not g.sites.has(site_id):
			state.board_vp.erase(site_id)
	for site_id: String in state.stolen_markers.keys():
		if not g.sites.has(site_id):
			state.stolen_markers.erase(site_id)
	state.graph = g
	var presence := Presence.new(g)
	presence.sides = state.teams
	var control := SiteControl.new(g)
	control.sides = state.teams
	state.presence = presence
	state.control = control
	state.removed_hexes.append(hex)


# --- Шпион на рынке (Blue Slaad) --------------------------------------------------

## Хозяин шпиона на карте слота index ("" — нет шпиона).
static func market_spy_owner(state: GameState, index: int) -> String:
	var entry: Dictionary = state.market_spies.get(str(index), {})
	if entry.is_empty() or index < 0 or index >= state.market.display.size():
		return ""
	if String(state.market.display[index]) != String(entry.get("card", "")):
		return ""
	return String(entry.get("owner", ""))


## Карта ушла из слота — шпион возвращается в барак хозяина.
static func sync_market_spies(state: GameState) -> void:
	for key: String in state.market_spies.keys():
		var entry: Dictionary = state.market_spies[key]
		var i := key.to_int()
		if i >= 0 and i < state.market.display.size() and String(state.market.display[i]) == String(entry.get("card", "")):
			continue
		state.stock(String(entry.get("owner", ""))).spies_in_barracks += 1
		state.market_spies.erase(key)


## Чужой шпион на карте: чужак должен заплатить 3 Power (иначе -1 — не купить), карта на 6 дешевле.
static func market_cost(state: GameState, index: int, cost: int) -> int:
	var owner := market_spy_owner(state, index)
	var buyer := state.current_player()
	if owner == "" or not state.is_enemy(buyer, owner):
		return cost
	if state.players[buyer].power < SPY_RETURN_POWER:
		return -1
	return maxi(0, cost - SPY_DISCOUNT)


## Покупка карты со шпионом: соперник платит 3 Power, шпион уходит хозяину.
## false — купить нельзя (не хватает Power).
static func pay_market_spy(state: GameState, player_id: String, index: int) -> bool:
	var owner := market_spy_owner(state, index)
	if owner == "" or not state.is_enemy(player_id, owner):
		return true
	var p: PlayerState = state.players[player_id]
	if p.power < SPY_RETURN_POWER:
		return false
	p.power -= SPY_RETURN_POWER
	FreljordCards.spent_power(state, player_id, SPY_RETURN_POWER)
	state.market_spies.erase(str(index))
	state.stock(owner).spies_in_barracks += 1
	return true


## Бесплатный найм (RecruitFree и т.п.) чужой карты со шпионом нельзя.
static func free_recruit_blocked(state: GameState, player_id: String, index: int) -> bool:
	var owner := market_spy_owner(state, index)
	return owner != "" and state.is_enemy(player_id, owner)


# --- Классы -------------------------------------------------------------------

## "+1 X for every per <чего-то>": n = counter / per, эффект factory(n).
class _PerCount extends CardEffect:
	var counter: Callable
	var per: int
	var factory: Callable
	func _init(c: Callable, p: int, f: Callable) -> void:
		counter = c
		per = p
		factory = f
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var n: int = int(counter.call(state, player_id)) / per
		if n > 0:
			resolver.push(factory.call(n), player_id)


## Froghemoth Elder (Cho'Gath): "Remove a hex where you have presence" — гекс
## раскладки уходит с доски (решение владельца, 2026-10-17): все вражеские
## войска на нём (и белые) — в трофейный зал, свои — в барак, шпионы — хозяевам,
## его локации и места исчезают из игры (VoidCards.remove_hex). Выбор — любой
## локацией этого гекса.
class _DevourHex extends CardEffect:
	func _sites(state: GameState, player_id: String) -> Array:
		var hexes := {}
		for slot_id: String in state.graph.slots.keys():
			var hex := MapGraph.hex_of(slot_id)
			if hex != "" and not hexes.has(hex) \
					and state.presence.has_presence_at_slot(player_id, slot_id, state.troops, state.spies):
				hexes[hex] = true
		var out: Array = []
		for site_id: String in state.graph.sites.keys():
			if hexes.has(MapGraph.hex_of(site_id)):
				out.append(site_id)
		return out
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var site := String(answer()) if answer() != null else ""
			if not _sites(state, player_id).has(site):
				return
			var hex := MapGraph.hex_of(site)
			var taken := 0
			var back := 0
			var stock: PlayerState = state.stock(player_id)
			for slot_id: String in state.graph.slots.keys():
				if MapGraph.hex_of(slot_id) != hex:
					continue
				var owner := String(state.troops.get(slot_id, ""))
				if owner == "":
					continue
				if state.is_enemy(player_id, owner):
					stock.add_trophy(owner)
					taken += 1
				else:
					state.stock(owner).troops_in_barracks += 1
					back += 1
				state.troops[slot_id] = ""
			resolver.log_event("devour_hex", {"player_id": player_id, "site_id": site, "hex": hex,
				"name": String(state.graph.sites[site].get("name", "")), "taken": taken, "returned": back})
			VoidCards.remove_hex(state, hex)
			return
		var options := _sites(state, player_id)
		if options.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Choose a site: its whole hex is devoured and leaves the board"
		pd.choice_type = "target_site"
		pd.legal_options = options
		pd.source_card = VoidCards.CHOGATH
		pd.target_effect = self
		resolver.request_decision(pd)


## Thri-kreen Marauder (Kha'Zix): за каждые 4 войска в трофейном зале — ещё одна
## способность навсегда (PlayerState.evolutions); потом все накопленные.
class _Evolve extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var p: PlayerState = state.players[player_id]
		if is_answered():
			var idx := int(answer()) if answer() != null else -1
			_answered = false
			_answer = null
			if idx >= 0 and idx < VoidCards.EVOLUTIONS.size() and not p.evolutions.has(VoidCards.EVOLUTIONS[idx]):
				p.evolutions.append(VoidCards.EVOLUTIONS[idx])
				resolver.log_event("evolve", {"player_id": player_id, "ability": VoidCards.EVOLUTIONS[idx]})
		var target: int = mini(VoidCards.EVOLUTIONS.size(), state.stock(player_id).trophy_hall_count / 4)
		if p.evolutions.size() < target:
			var indices: Array = []
			var labels: Array[String] = []
			for i in range(VoidCards.EVOLUTIONS.size()):
				if not p.evolutions.has(VoidCards.EVOLUTIONS[i]):
					indices.append(i)
					labels.append(VoidCards.EVOLUTION_LABELS[i])
			var pd := PendingDecision.new()
			pd.player_id = player_id
			pd.prompt = "Thri-kreen Marauder keeps an ability for good:"
			pd.choice_type = "choose_option"
			pd.legal_options = indices
			pd.option_labels = labels
			pd.source_card = VoidCards.KHAZIX
			pd.target_effect = self
			resolver.request_decision(pd)
			return
		var all: Array[CardEffect] = []
		for key in p.evolutions:
			match String(key):
				"power":
					all.append(GainPower.new(2))
				"kill":
					all.append(AssassinateTroop.new(1))
				"spies":
					all.append(PlaceSpy.new(2))
				"draw":
					all.append(DrawCards.new(1))
		if not all.is_empty():
			resolver.push(SequenceEffect.new(all), player_id)


## Eye Monger (Vel'Koz): карта из руки (цена до 5) вместе с Eye Monger откладывается.
class _SetAside extends CardEffect:
	func _options(state: GameState, player_id: String) -> Array:
		var out: Array = []
		for cid: String in state.players[player_id].deck.hand:
			var cost := CardLibrary.card_cost(cid)
			if cost >= 0 and cost <= 5 and not out.has(cid):
				out.append(cid)
		return out
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		if is_answered():
			var cid := String(answer()) if answer() != null else ""
			var hand_idx := d.hand.find(cid)
			var self_idx := d.played_pile.rfind(VoidCards.VELKOZ)
			if cid == "" or hand_idx == -1 or self_idx == -1:
				return
			d.hand.remove_at(hand_idx)
			d.played_pile.remove_at(self_idx)
			d.set_aside.append(VoidCards.VELKOZ)
			d.set_aside.append(cid)
			resolver.log_event("set_aside", {"player_id": player_id, "card_id": cid})
			return
		var options := _options(state, player_id)
		if options.is_empty() or not d.played_pile.has(VoidCards.VELKOZ):
			return
		options.append("")
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Set aside a card that costs 5 or less: it is played at the start of each of your turns"
		pd.choice_type = "target_card"
		pd.tag = "hand"
		pd.legal_options = options
		pd.source_card = VoidCards.VELKOZ
		pd.target_effect = self
		resolver.request_decision(pd)


## Lesser Star Spawn Emissary: верхняя карта колоды открывается, её можно сожрать.
class _DevourTop extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		if d.draw_pile.is_empty() and not d.discard_pile.is_empty():
			d.draw_pile = d.discard_pile.duplicate()
			d.discard_pile.clear()
			d.shuffle_draw_pile(state.rng)
		if d.draw_pile.is_empty():
			return
		var top: String = d.draw_pile.back()
		resolver.log_event("reveal_top", {"player_id": player_id, "card_id": top})
		var name := String(CardLibrary.card_data(top).get("name", top))
		var ask := OptionalEffect.new(_DevourFromTop.new(top), "Devour %s from the top of your deck?" % name)
		ask.source_card = top
		resolver.push(ask, player_id)


class _DevourFromTop extends CardEffect:
	var card: String
	func _init(c: String) -> void:
		card = c
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		if d.draw_pile.is_empty() or d.draw_pile.back() != card:
			return
		d.draw_pile.pop_back()
		VoidCards._devoured(state, player_id, card, "deck", resolver)


## Lesser Star Spawn Emissary: "If you don't deploy any troops this turn, Execute this card".
class _DevourSelf extends CardEffect:
	var card: String
	func _init(c: String) -> void:
		card = c
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		var idx := d.played_pile.rfind(card)
		if idx == -1:
			return
		d.played_pile.remove_at(idx)
		VoidCards._devoured(state, player_id, card, "played", resolver)


static func _devoured(state: GameState, player_id: String, card: String, src: String, resolver: EffectResolver) -> void:
	state.devoured_pile.append(card)
	resolver.log_event("devour", {"player_id": player_id, "card_id": card, "source": src})
	NoxusCards.on_devour(state, player_id, card, src, resolver)


## Thri-kreen Psion (Xer'Sai Caller): top N карт колоды — до take карт ценой до
## max_cost в руку, остальные обратно наверх в том же порядке.
class _TopCheap extends CardEffect:
	var amount: int
	var take: int
	var max_cost: int
	var _shown: Array[String] = []
	var _started := false
	func _init(n: int, t: int, c: int) -> void:
		amount = n
		take = t
		max_cost = c
	func _eligible() -> Array:
		var out: Array = []
		for cid: String in _shown:
			var cost := CardLibrary.card_cost(cid)
			if cost >= 0 and cost <= max_cost and not out.has(cid):
				out.append(cid)
		return out
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		if not _started:
			_started = true
			if d.draw_pile.is_empty() and not d.discard_pile.is_empty():
				d.draw_pile = d.discard_pile.duplicate()
				d.discard_pile.clear()
				d.shuffle_draw_pile(state.rng)
			for i in range(mini(amount, d.draw_pile.size())):
				_shown.append(d.draw_pile.pop_back())
		elif is_answered():
			var cid := String(answer()) if answer() != null else ""
			_answered = false
			_answer = null
			if cid == "" or not _eligible().has(cid):
				take = 0
			else:
				_shown.remove_at(_shown.find(cid))
				d.hand.append(cid)
				take -= 1
				resolver.log_event("fetch_from_top", {"player_id": player_id, "looked": amount, "cards": [cid]})
		var options := _eligible()
		if take > 0 and not options.is_empty():
			options.append("")
			var pd := PendingDecision.new()
			pd.player_id = player_id
			pd.prompt = "Put a card that costs %d or less into your hand (%d left)" % [max_cost, take]
			pd.choice_type = "target_card"
			pd.legal_options = options
			pd.source_card = VoidCards.CALLER
			pd.target_effect = self
			resolver.request_decision(pd)
			return
		for i in range(_shown.size() - 1, -1, -1):
			d.draw_pile.append(_shown[i])
		_shown.clear()


## Green Slaad (Camouflaged Horror): 3 верхние карты колоды рынка — одну ценой до
## 5 можно сыграть бесплатно; все три уходят под низ колоды рынка.
class _MarketReveal extends CardEffect:
	var amount: int
	var max_cost: int
	var _shown: Array[String] = []
	var _started := false
	func _init(n: int, c: int) -> void:
		amount = n
		max_cost = c
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if not _started:
			_started = true
			for i in range(mini(amount, state.market.deck.size())):
				_shown.append(state.market.deck.pop_back())
			if _shown.is_empty():
				return
			resolver.log_event("market_reveal", {"player_id": player_id, "cards": _shown.duplicate()})
			var options: Array = []
			for cid: String in _shown:
				var cost := CardLibrary.card_cost(cid)
				if cost >= 0 and cost <= max_cost and not options.has(cid):
					options.append(cid)
			if options.is_empty():
				_to_bottom(state)
				return
			options.append("")
			var pd := PendingDecision.new()
			pd.player_id = player_id
			pd.prompt = "Play one of the top market cards for free"
			pd.choice_type = "target_card"
			pd.legal_options = options
			pd.source_card = VoidCards.HORROR
			pd.target_effect = self
			resolver.request_decision(pd)
			return
		var cid := String(answer()) if is_answered() and answer() != null else ""
		var played := _shown.has(cid)
		_to_bottom(state)
		if played:
			resolver.log_event("play_free", {"player_id": player_id, "card_id": cid})
			resolver.push(CardLibrary.get_effect(cid), player_id, cid)
	func _to_bottom(state: GameState) -> void:
		for cid: String in _shown:
			state.market.deck.insert(0, cid)
		_shown.clear()


## Blue Slaad (Void Abomination): шпион на карту рынка.
class _MarketSpy extends CardEffect:
	func _options(state: GameState) -> Array:
		var out: Array = []
		for i in range(state.market.display.size()):
			if String(state.market.display[i]) != "" and VoidCards.market_spy_owner(state, i) == "":
				out.append(i)
		return out
	func is_available(state: GameState, player_id: String) -> bool:
		return state.stock(player_id).spies_in_barracks > 0 and not _options(state).is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var i := int(answer()) if answer() != null else -1
			if not is_available(state, player_id) or not _options(state).has(i):
				return
			VoidCards.sync_market_spies(state)
			state.stock(player_id).spies_in_barracks -= 1
			state.market_spies[str(i)] = {"owner": player_id, "card": String(state.market.display[i])}
			resolver.log_event("market_spy", {"player_id": player_id, "market_index": i,
				"card_id": String(state.market.display[i])})
			return
		if not is_available(state, player_id):
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Place a spy on a market card"
		pd.choice_type = "target_market_index"
		pd.tag = "market"
		pd.legal_options = _options(state)
		pd.source_card = VoidCards.ABOMINATION
		pd.target_effect = self
		resolver.request_decision(pd)


## Githyanki Dracomancer (Void Blaster): бесплатно карта рынка с именем карты,
## сыгранной в этот ход.
class _GainSameName extends RecruitFree:
	func _init() -> void:
		super("", 999, 1, false)
	func _eligible_indices(state: GameState) -> Array:
		var names := {}
		for cid: String in state.players[state.current_player()].deck.played_pile:
			names[String(CardLibrary.card_data(cid).get("name", ""))] = true
		var out: Array = []
		for i: int in super._eligible_indices(state):
			if names.has(String(CardLibrary.card_data(String(state.market.display[i])).get("name", ""))):
				out.append(i)
		return out
	func is_available(state: GameState, _player_id: String) -> bool:
		return not _eligible_indices(state).is_empty()
