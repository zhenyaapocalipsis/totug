class_name BandleCards
extends RefCounted

## Полуколода Bandle City (New Era) — способности карт Bandle City из фан-мода
## Runeterra Reforged на существах FEYWILD: феи, гномы, мелкий волшебный народ
## (без зверей — правило владельца). Таблица id -> существо -> карта мода —
## Claude outputs/new_era_bandle.md.
##
## Перевод на правила этой игры: Valor -> MALICE.
## Владелец (2026-10-17): Rumble и Lulu убраны, вместо них Norra (Extra Champions
## мода, картинка PDF 457) — id 49905; 49907 свободен.
##
## Glamour (правило мода): "spend 1 VP token (return it to the supply) to enable
## the ability; only one Glamour per card". Здесь: после основного эффекта карты
## вопрос "Glamour?" со списком её Glamour-способностей и вариантом "No Glamour";
## у карт с "instead" (Leprechaun, Pixie Wonderbringer) Glamour-варианты стоят рядом с
## основным эффектом. Без VP-жетонов вопроса нет.
##
## Счётчики хода — state.turn_flags (сбрасываются в start_turn):
##   "teemo"            — Satyr Thornbearer: каждый шпион -> ещё шпион и 1 VP; возврат
##                        своего шпиона -> supplant в той локации;
##   "teemo_busy"       — ставится дополнительный шпион Satyr Thornbearer (он не цепляет ещё один);
##   "tristana_vp"      — High Fae Noble: убил или вытеснил войско -> 1 VP;
##   "tristana_supplant" — High Fae Noble: убил войско -> можно вытеснить его вместо этого;
##   "yuumi_top"        — Silverquill Apprentice: купленную карту можно положить на верх колоды;
##   "yuumi_vp"         — Silverquill Apprentice: +1 VP за каждую купленную карту;
##   "recruits"         — сколько карт куплено в этот ход (Silverquill Apprentice, High Fae Mage);
##   "power_spent"      — сколько Power потрачено в этот ход (Faerie Dragon Youth:
##                        "gained 6 or more Power this turn" = потрачено + осталось);
##   "control_start"    — локации, которые игрок контролировал в начале хода (Yeti Tyke).

const TEEMO := "49900"  # Satyr Thornbearer
const KENNEN := "49901"  # High Fae Kindguard
const TRISTANA := "49902"  # High Fae Noble
const ZIGGS := "49903"  # Lorehold Apprentice
const YUUMI := "49904"  # Silverquill Apprentice
const NORRA := "49905"  # Faerie Pathlighter
const GNAR := "49906"  # Faerie Dragon Youth
const VEIGAR := "49908"  # Witherbloom Apprentice
const CORKI := "49909"  # Witchkite
const GUNNERS := "49910"  # Modron Monodrone (Bandle Gunners)
const CARETAKER := "49911"  # High Fae Mage (Realm Caretaker)
const EXPLORER := "49912"  # Icewind Kobold (Yordle Explorer)
const MAYOR := "49913"  # Leprechaun (Bandle City Mayor)
const PAINTER := "49914"  # Faerie Pest (Bandle Painter)
const BANANA := "49915"  # Quandrix Apprentice (Banana Blaster)
const SWOLE := "49916"  # Yeti Tyke (Swole Scout)
const KINGPIN := "49917"  # Faerie Borrower (Arena Kingpin)
const BLADETWIRLER := "49918"  # High Fae Impostor (Carved Bladetwirler)
const TORNADO := "49919"  # Pixie Wonderbringer (Tornado Warrior)
const CAPTAIN := "49920"  # Ogre Chitterlord (Yordle Captain)
const PORTAL := "49921"  # Goblin Hexer (Portal Scholar)
const MEGA_GNAR := "49922"  # Faerie Dragon Adult (Mega Gnar, не в рынке)

const NO_GLAMOUR := "No Glamour"


static func build(card_id: String) -> CardEffect:
	match card_id:
		TEEMO:
			return SequenceEffect.new([_FromTopWithWord.new(6, ["spy", "spies"]), ShadowCards._SetFlag.new("teemo")])
		KENNEN:
			return _choose(KENNEN, [
				SequenceEffect.new([PlaceSpy.new(1), DrawCards.new(1)]),
				ReturnOwnSpy.new(null, func(site): return AssassinateTroop.new(3, false, true, false, 0, 0, site)),
			], ["Place a spy and draw a card", "Return one of your spies -> assassinate up to 3 troops at that site"])
		TRISTANA:
			return SequenceEffect.new([GainPower.new(3), _choose(TRISTANA, [
				ShadowCards._SetFlag.new("tristana_vp"), ShadowCards._SetFlag.new("tristana_supplant"),
			], ["This turn, whenever you assassinate or supplant a troop, gain 1 VP",
				"This turn, whenever you assassinate a troop, you may supplant it instead"])])
		ZIGGS:
			return SequenceEffect.new([
				AssassinateTroop.new(2),
				glamours(ZIGGS, [AtEndOfTurn.new(PromoteCard.new("played_other", ZIGGS, CardLibrary._aspect_filter("OBEDIENCE")))],
					["At end of turn, promote an Obedience card you played this turn"]),
				FocusEffect.new("AMBITION", DrawCards.new(1)),
			])
		YUUMI:
			return SequenceEffect.new([GainInfluence.new(5), _choose(YUUMI, [
				ShadowCards._SetFlag.new("yuumi_top"), _YuumiVP.new(),
			], ["This turn, you may put cards you recruit on top of your deck",
				"Gain 1 VP for each card you recruit this turn"])])
		NORRA:
			return SequenceEffect.new([_NorraTokens.new(), MoveTroop.new(1), DeployTroop.new(2)])
		GNAR:
			return SequenceEffect.new([GainPower.new(2), DrawCards.new(1),
				ConditionalEffect.new(func(state, pid): return power_gained(state, pid) >= 6,
					CelestialCards._Transform.new(GNAR, MEGA_GNAR))])
		MEGA_GNAR:
			return SequenceEffect.new([GainPower.new(6), ForceDiscard.new("each_opponent"),
				CelestialCards._Transform.new(MEGA_GNAR, GNAR)])
		VEIGAR:
			return SequenceEffect.new([AssassinateTroop.new(1), GainPower.new(1), _PowerPerTrophies.new(3)])
		CORKI:
			return _choose(CORKI, [
				SequenceEffect.new([PlaceSpy.new(1), DeployTroop.new(4)]),
				ReturnOwnSpy.new(GainVP.new(1), func(site): return SupplantTroop.new(1, false, false, false, Callable(), site)),
			], ["Place a spy and deploy 4 troops", "Return one of your spies -> supplant a troop at that site and gain 1 VP"])
		GUNNERS:
			return _choose(GUNNERS, [
				SequenceEffect.new([DrawCards.new(1), DiscardCardEffect.new(1), GainVP.new(1)]),
				GainPower.new(2), GainInfluence.new(2),
			], ["Draw a card, then discard a card and gain 1 VP", "+2 Power", "+2 Influence"])
		CARETAKER:
			return SequenceEffect.new([
				AtEndOfTurn.new(PromoteCard.new("played_other", CARETAKER)),
				glamours(CARETAKER, [GainInfluence.new(2)], ["+2 Influence"]),
				AtEndOfTurn.new(ConditionalEffect.new(func(state, _pid): return recruits(state) >= 3, GainVP.new(1))),
			])
		EXPLORER:
			return SequenceEffect.new([GainInfluence.new(2), ConditionalEffect.new(
				func(state, pid): return state.players[pid].vp_tokens == 0,
				SequenceEffect.new([GainVP.new(1), PlaceSpy.new(1)]))])
		MAYOR:
			return SequenceEffect.new([_DiscardMarket.new(3), instead(MAYOR, RecruitFree.new("", 3, 1, true),
				"Gain a card that costs up to 3",
				[GainInfluence.new(3), RecruitFree.new("", 5, 1, true)],
				["+3 Influence instead", "Gain a card that costs up to 5 instead"])])
		PAINTER:
			return _choose(PAINTER, [
				PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
					func(state, _pid): return ShurimaCards._site_full(state, site), GainVP.new(1))),
				ReturnOwnSpy.new(SequenceEffect.new([GainInfluence.new(2), DrawCards.new(1)])),
			], ["Place a spy (site full: gain 1 VP)", "Return one of your spies -> +2 Influence and draw a card"])
		BANANA:
			return _choose(BANANA, [
				PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
					func(state, pid): return IoniaCards._other_troop_at(state, pid, site), GainVP.new(1))),
				ReturnOwnSpy.new(null, func(site): return _StealAtSite.new(2, site)),
			], ["Place a spy (another player's troop there: gain 1 VP)",
				"Return one of your spies -> take 2 VP from each other player with a troop at that site"])
		SWOLE:
			return SequenceEffect.new([
				_choose(SWOLE, [DeployTroop.new(3), SupplantTroop.new(1, true)], ["Deploy 3 troops", "Supplant a white troop"]),
				AtEndOfTurn.new(ConditionalEffect.new(func(state, pid): return gained_control(state, pid), GainVP.new(1))),
			])
		KINGPIN:
			return _choose(KINGPIN, [
				PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
					func(state, _pid): return ShurimaCards._site_full(state, site),
					NoxusCards.devour(["hand", "discard"], true, func(_cid): return GainVP.new(1)))),
				ReturnOwnSpy.new(SequenceEffect.new([
					NoxusCards._Devour.new(["market"], false, Callable(), "discount2"),
					NoxusCards._Devour.new(["market"], false, Callable(), "discount2"),
				])),
			], ["Place a spy (site full: you may devour a card in your hand or discard pile to gain 1 VP)",
				"Return one of your spies -> devour 2 cards in the market, their replacements cost 2 less this turn"])
		BLADETWIRLER:
			return SequenceEffect.new([AssassinateTroop.new(1), glamours(BLADETWIRLER,
				[DeployTroop.new(3), ReturnTroopOrSpy.new(1), GainPower.new(2)],
				["Deploy 3 troops", "Return a troop or spy", "+2 Power"])])
		TORNADO:
			return instead(TORNADO, SupplantTroop.new(1, true), "Supplant a white troop",
				[SupplantTroop.new(1), SupplantTroop.new(1, true, true)],
				["Supplant any troop instead", "Supplant a white troop anywhere instead"])
		CAPTAIN:
			return SequenceEffect.new([GainInfluence.new(3), glamours(CAPTAIN,
				[AtEndOfTurn.new(PromoteCard.new("played_other", CAPTAIN))],
				["At end of turn, promote another card you played this turn"])])
		PORTAL:
			return _choose(PORTAL, [
				PlaceSpy.new(1, false, func(site): return _MoveOwnTo.new(site)),
				ReturnOwnSpy.new(null, func(site): return SequenceEffect.new([
					MoveTroop.new(1, true, false, true, site), MoveTroop.new(1, true, true)])),
			], ["Place a spy -> move one of your troops to that site",
				"Return one of your spies -> move up to one enemy troop at that site and one of your troops"])
	return null


## Kara-Tur Retain: бонус "Retain: Gain 1 VP" (High Fae Kindguard).
static func retain_effect(card_id: String) -> CardEffect:
	if card_id == KENNEN:
		return GainVP.new(1)
	return null


static func _choose(card_id: String, opts: Array[CardEffect], labels: Array[String]) -> ChooseEffect:
	var c := ChooseEffect.new(opts, labels)
	c.source_card = card_id
	return c


## "Glamour: X" (одна или несколько на карте) — после основного эффекта: можно
## заплатить 1 VP за одну из них. Без VP-жетонов вопроса нет.
static func glamours(card_id: String, effects: Array, labels: Array) -> CardEffect:
	var opts: Array[CardEffect] = [SequenceEffect.new()]
	var lbls: Array[String] = [NO_GLAMOUR]
	for i in range(effects.size()):
		opts.append(Glamour.new(effects[i]))
		lbls.append("Glamour (1 VP): " + String(labels[i]))
	var c := ChooseEffect.new(opts, lbls, "Glamour: spend 1 VP?")
	c.source_card = card_id
	return ConditionalEffect.new(func(state, pid): return state.players[pid].vp_tokens > 0, c)


## "X. Glamour: Y instead." — основной эффект или Glamour-замена за 1 VP.
static func instead(card_id: String, base: CardEffect, base_label: String, effects: Array, labels: Array) -> CardEffect:
	var opts: Array[CardEffect] = [base]
	var lbls: Array[String] = [base_label]
	for i in range(effects.size()):
		opts.append(Glamour.new(effects[i]))
		lbls.append("Glamour (1 VP): " + String(labels[i]))
	var c := ChooseEffect.new(opts, lbls, "Choose (Glamour costs 1 VP):")
	c.source_card = card_id
	return _Branch.new(func(state, pid): return state.players[pid].vp_tokens > 0, c, base)


## Заплатить 1 VP-жетон за Glamour: жетон уходит в общий запас.
static func pay_glamour(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	state.players[player_id].vp_tokens -= 1
	if state.vp_bank.extra > 0:
		state.vp_bank.extra -= 1
	else:
		state.vp_bank.ones += 1
	resolver.log_event("glamour", {"player_id": player_id})


static func recruits(state: GameState) -> int:
	return int(state.turn_flags.get("recruits", 0))


## Сколько Power игрок получил в этот ход: осталось + потрачено.
static func power_gained(state: GameState, player_id: String) -> int:
	return state.players[player_id].power + int(state.turn_flags.get("power_spent", 0))


## Power потрачена (базовые действия): учёт для Faerie Dragon Youth.
static func spend(state: GameState, amount: int) -> void:
	state.turn_flags["power_spent"] = int(state.turn_flags.get("power_spent", 0)) + amount


## Начало хода: какие локации игрок контролирует (Yeti Tyke).
static func on_start_turn(state: GameState, player_id: String) -> void:
	state.turn_flags["control_start"] = _controlled(state, player_id)


static func _controlled(state: GameState, player_id: String) -> Array:
	var out: Array = []
	for site_id: String in state.graph.sites.keys():
		if state.control.controls(player_id, site_id, state.troops):
			out.append(site_id)
	return out


## Yeti Tyke: "If you gained control of a site this turn" — сейчас контролирует
## локацию, которую не контролировал в начале хода.
static func gained_control(state: GameState, player_id: String) -> bool:
	var before: Array = state.turn_flags.get("control_start", [])
	for site_id in _controlled(state, player_id):
		if not before.has(site_id):
			return true
	return false


## Satyr Thornbearer: "Whenever you place a spy, place an additional spy and gain 1 VP".
static func on_place_spy(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	if not state.turn_flags.get("teemo", false) or state.turn_flags.get("teemo_busy", false) \
			or player_id != state.current_player():
		return
	resolver.push(SequenceEffect.new([
		ShadowCards._SetFlag.new("teemo_busy"),
		PlaceSpy.new(1),
		CallbackEffect.new(func(s: GameState, _pid: String, _r: EffectResolver): s.turn_flags.erase("teemo_busy")),
		GainVP.new(1),
	]), player_id, TEEMO)


## Satyr Thornbearer: "Whenever you return one of your spies, also Supplant a troop at that site".
static func on_return_spy(state: GameState, player_id: String, site_id: String, resolver: EffectResolver) -> void:
	if not state.turn_flags.get("teemo", false) or player_id != state.current_player():
		return
	resolver.push(SupplantTroop.new(1, false, false, false, Callable(), site_id), player_id, TEEMO)


## Войско убито (supplanted — вытеснено). High Fae Noble (Tristana).
## immediate — зовёт GameServer вне розыгрыша карты (базовое действие).
static func after_kill(state: GameState, player_id: String, slot_id: String, resolver: EffectResolver,
		supplanted: bool, immediate: bool = false) -> void:
	if player_id != state.current_player():
		return
	if state.turn_flags.get("tristana_vp", false):
		_run(state, player_id, resolver, GainVP.new(1), immediate)
	if state.turn_flags.get("tristana_supplant", false) and not supplanted \
			and state.stock(player_id).troops_in_barracks > 0 and String(state.troops.get(slot_id, "")) == "":
		var ask := OptionalEffect.new(_DeployAt.new(slot_id), "Supplant that troop instead (your troop takes its place)?")
		ask.source_card = TRISTANA
		_run(state, player_id, resolver, ask, immediate)


## Карта куплена (рынок, запас, бесплатный найм). Silverquill Apprentice (Yuumi).
static func on_recruit(state: GameState, player_id: String, card_id: String, resolver: EffectResolver, immediate: bool = false) -> void:
	if player_id != state.current_player():
		return
	state.turn_flags["recruits"] = recruits(state) + 1
	var vp := int(state.turn_flags.get("yuumi_vp", 0))
	if vp > 0:
		_run(state, player_id, resolver, GainVP.new(vp), immediate)
	if state.turn_flags.get("yuumi_top", false) and card_id != "":
		var name := String(CardLibrary.card_data(card_id).get("name", card_id))
		var ask := OptionalEffect.new(_ToTop.new(card_id), "Put %s on top of your deck?" % name)
		ask.source_card = card_id
		_run(state, player_id, resolver, ask, immediate)


## Faerie Pathlighter (Norra): жетоны 1 VP на доске забирает их хозяин, когда у
## него в той локации есть войско. Проверка — в конце его хода
## (TurnEngine.finish_end_of_turn) и сразу после розыгрыша Faerie Pathlighter.
static func claim_board_vp(state: GameState, player_id: String, resolver: EffectResolver) -> void:
	for site_id: String in state.board_vp.keys():
		if String(state.board_vp[site_id]) != player_id:
			continue
		var here := false
		for slot_id: String in state.graph.slots_of_site(site_id):
			if String(state.troops.get(slot_id, "")) == player_id:
				here = true
				break
		if not here:
			continue
		state.board_vp.erase(site_id)
		state.players[player_id].vp_tokens += state.vp_bank.grant(1)
		if resolver != null:
			resolver.log_event("board_vp_claim", {"player_id": player_id, "site_id": site_id})


static func _run(state: GameState, player_id: String, resolver: EffectResolver, eff: CardEffect, immediate: bool) -> void:
	if not immediate:
		resolver.push(eff, player_id)
	elif resolver.pending != null:
		resolver.pending.stack.push_front({"effect": eff, "player_id": player_id, "card": ""})
	else:
		resolver.apply(eff, player_id, state)


# --- Классы -------------------------------------------------------------------

## Glamour: заплатить 1 VP, затем эффект.
class Glamour extends CardEffect:
	var inner: CardEffect
	func _init(e: CardEffect) -> void:
		inner = e
	func is_available(state: GameState, player_id: String) -> bool:
		return state.players[player_id].vp_tokens > 0 and inner.is_available(state, player_id)
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if not is_available(state, player_id):
			return
		BandleCards.pay_glamour(state, player_id, resolver)
		resolver.push(inner, player_id)


## Faerie Pathlighter (Norra): "Choose another player. They place 3 1 VP tokens at
## any sites that don't have a 1 VP token." Решения задаёт выбранный соперник —
## владелец жетонов хранится в самом эффекте (resolver.resume зовёт эффект от
## имени ответившего).
class _NorraTokens extends CardEffect:
	var owner := ""
	var placer := ""
	var left := 3
	func _rivals(state: GameState, player_id: String) -> Array:
		var out: Array = []
		for pid: String in state.turn_order:
			if pid != player_id and state.is_opponent(player_id, pid):
				out.append(pid)
		return out
	func _free_sites(state: GameState) -> Array:
		var out: Array = []
		for site_id: String in state.graph.sites.keys():
			if not state.board_vp.has(site_id):
				out.append(site_id)
		return out
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if owner == "":
			owner = player_id
		if is_answered():
			var chosen := String(answer()) if answer() != null else ""
			_answered = false
			_answer = null
			if placer == "":
				if not _rivals(state, owner).has(chosen):
					return
				placer = chosen
			elif _free_sites(state).has(chosen):
				state.board_vp[chosen] = owner
				left -= 1
				resolver.log_event("board_vp", {"player_id": placer, "site_id": chosen, "owner": owner})
		if placer == "":
			var rivals := _rivals(state, owner)
			if rivals.is_empty():
				return
			if rivals.size() == 1:
				placer = String(rivals[0])
			else:
				_ask(resolver, owner, "Choose a player: they place three 1 VP tokens for you", "target_player", rivals)
				return
		var sites := _free_sites(state)
		if left <= 0 or sites.is_empty():
			resolver.push(CallbackEffect.new(func(s: GameState, _pid: String, r: EffectResolver):
				BandleCards.claim_board_vp(s, owner, r)), owner)
			return
		_ask(resolver, placer, "Place a 1 VP token for %s (%d left) at a site without one" % [owner.capitalize(), left],
			"target_site", sites)
	func _ask(resolver: EffectResolver, who: String, prompt: String, kind: String, options: Array) -> void:
		var pd := PendingDecision.new()
		pd.player_id = who
		pd.prompt = prompt
		pd.choice_type = kind
		pd.legal_options = options
		pd.source_card = BandleCards.NORRA
		pd.target_effect = self
		resolver.request_decision(pd)


## Условие проверяется в момент розыгрыша: yes или no.
class _Branch extends CardEffect:
	var cond: Callable
	var yes: CardEffect
	var no: CardEffect
	func _init(c: Callable, y: CardEffect, n: CardEffect) -> void:
		cond = c
		yes = y
		no = n
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		resolver.push(yes if cond.call(state, player_id) else no, player_id)


## Satyr Thornbearer (Teemo): верхние N карт колоды — карты с этими словами в руку, остальные в сброс.
class _FromTopWithWord extends CardEffect:
	var amount: int
	var words: Array
	func _init(n: int, w: Array) -> void:
		amount = n
		words = w
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
			var text := String(CardLibrary.card_data(card).get("ability_text", "")).to_lower()
			if words.any(func(w): return text.contains(String(w))):
				taken.append(card)
			else:
				dropped.append(card)
		deck.hand.append_array(taken)
		deck.discard_pile.append_array(dropped)
		resolver.log_event("fetch_from_top", {"player_id": player_id, "looked": taken.size() + dropped.size(), "cards": taken})


## Silverquill Apprentice (Yuumi): +1 VP за каждую уже купленную в этот ход карту и за каждую следующую.
class _YuumiVP extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		state.turn_flags["yuumi_vp"] = int(state.turn_flags.get("yuumi_vp", 0)) + 1
		var n := BandleCards.recruits(state)
		if n > 0:
			resolver.push(GainVP.new(n), player_id)


## Witherbloom Apprentice (Veigar): +1 Power за каждые per войск в трофейном зале.
class _PowerPerTrophies extends CardEffect:
	var per: int
	func _init(n: int) -> void:
		per = n
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var n: int = state.stock(player_id).trophy_hall_count / per
		if n > 0:
			resolver.push(GainPower.new(n), player_id)


## Quandrix Apprentice (Banana Blaster): по 2 VP у каждого другого игрока с войском в этой локации.
class _StealAtSite extends CardEffect:
	var amount: int
	var site: String
	func _init(n: int, s: String) -> void:
		amount = n
		site = s
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		for victim: String in CardLibrary._enemy_troop_owners_at_site(state, player_id, site):
			if victim != "white" and state.is_opponent(player_id, victim):
				MercenaryCards.steal(state, player_id, victim, amount, resolver)


## High Fae Noble (Tristana): своё войско в освободившийся слот убитого.
class _DeployAt extends CardEffect:
	var slot: String
	func _init(s: String) -> void:
		slot = s
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var stock: PlayerState = state.stock(player_id)
		if stock.troops_in_barracks <= 0 or String(state.troops.get(slot, "")) != "":
			return
		state.troops[slot] = player_id
		stock.troops_in_barracks -= 1
		if stock.troops_in_barracks == 0:
			GameEnd.trigger(state, "last_troop")
		resolver.log_event("deploy", {"player_id": player_id, "slot_id": slot})


## Silverquill Apprentice (Yuumi): купленная карта из сброса — на верх колоды.
class _ToTop extends CardEffect:
	var card: String
	func _init(c: String) -> void:
		card = c
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		var idx := d.discard_pile.rfind(card)
		if idx == -1:
			return
		d.discard_pile.remove_at(idx)
		d.draw_pile.append(card)
		resolver.log_event("card_on_top", {"player_id": player_id, "card_id": card})


## Leprechaun (Bandle City Mayor): "You may discard up to 3 cards in the market" —
## карта уходит под низ колоды рынка, слот пополняется сверху.
class _DiscardMarket extends CardEffect:
	var left: int
	func _init(n: int) -> void:
		left = n
	func _options(state: GameState) -> Array:
		var out: Array = []
		for i in range(state.market.display.size()):
			if state.market.display[i] != "":
				out.append(i)
		return out
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var chosen = answer()
			_answered = false
			_answer = null
			if chosen == null or int(chosen) == -1 or not _options(state).has(int(chosen)):
				return
			var i := int(chosen)
			var cid: String = state.market.display[i]
			state.market.deck.insert(0, cid)
			state.market.recruit_at(i)
			resolver.log_event("market_discard", {"player_id": player_id, "card_id": cid, "market_index": i})
			left -= 1
		var options := _options(state)
		if left <= 0 or options.is_empty():
			return
		options.append(-1)
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "You may discard a card in the market (%d left)" % left
		pd.choice_type = "target_market_index"
		pd.tag = "market"
		pd.legal_options = options
		pd.source_card = BandleCards.MAYOR
		pd.target_effect = self
		resolver.request_decision(pd)


## Goblin Hexer (Portal Scholar): "Move one of your troops to that site".
class _MoveOwnTo extends CardEffect:
	var site: String
	var _from := ""
	func _init(s: String) -> void:
		site = s
	func _empties(state: GameState) -> Array:
		var out: Array = []
		for slot_id: String in state.graph.slots_of_site(site):
			if String(state.troops.get(slot_id, "")) == "":
				out.append(slot_id)
		return out
	func _sources(state: GameState, player_id: String) -> Array:
		var here: Array = Array(state.graph.slots_of_site(site))
		var out: Array = []
		for slot_id: String in state.troops.keys():
			if String(state.troops[slot_id]) == player_id and not here.has(slot_id):
				out.append(slot_id)
		return out
	func is_available(state: GameState, player_id: String) -> bool:
		return not _empties(state).is_empty() and not _sources(state, player_id).is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var chosen := String(answer()) if answer() != null else ""
			_answered = false
			_answer = null
			if chosen == "":
				return
			if _from == "":
				if not _sources(state, player_id).has(chosen):
					return
				_from = chosen
			else:
				if not _empties(state).has(chosen) or String(state.troops.get(_from, "")) != player_id:
					return
				MoveTroop._do_move(state, player_id, resolver, _from, chosen)
				return
		if not is_available(state, player_id):
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.choice_type = "target_slot"
		pd.source_card = BandleCards.PORTAL
		pd.target_effect = self
		if _from == "":
			pd.prompt = "Move one of your troops to %s: choose the troop" % site
			pd.legal_options = _sources(state, player_id)
			pd.legal_options.append("")
		else:
			pd.prompt = "Choose where at %s" % site
			pd.legal_options = _empties(state)
		resolver.request_decision(pd)
