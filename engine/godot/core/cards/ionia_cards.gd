class_name IoniaCards
extends RefCounted

## Полуколода Ionia (New Era) — способности карт Ionia из фан-мода Runeterra
## Reforged на существах KARA-TUR: металлические и древние драконы, Oni, Kraken,
## Tarrasque, феи и грибы (без зверей — правило владельца). Таблица id -> существо
## -> карта мода — Claude outputs/new_era_ionia.md.
##
## Перевод на правила этой игры: Valor -> MALICE.
## Владелец (2026-10-17): вместо Jhin — Hwei (Extra Champions мода). В колоде все
## 45 карт мода (23 уникальные), урезать до 40/20 владелец решит сам.
##
## Retain (правило мода): "Allows you to keep cards in your hand after the end of
## turn. Some cards have bonus effects that go off when you Retain them. When you
## draw your hand of cards, draw back up to 5 cards (not including the cards you
## Retained), then add your Retained cards into your hand."
## Здесь: карту со словом Retain в свой ход можно не сыграть, а удержать — при
## щелчке по ней вопрос "сыграть или удержать" (GameServer, PLAY_CARD). Удержанная
## уходит из руки в Deck.retained, её бонус "Retain: ..." срабатывает сразу, в конце
## хода после добора до 5 она возвращается в руку (TurnEngine.finish_end_of_turn).
## Любое удержание (своё, Ancient Silver Dragon, Adult Silver Dragon, верхняя карта
## колоды) считается "Retain a card": бонус карты и счётчики хода срабатывают.
##
## Счётчики хода — state.turn_flags (сбрасываются в start_turn):
##   "retains"        — сколько карт удержано в этот ход (Ancient Black Dragon);
##   "retain_power" / "retain_influence" / "retain_deploy" — "Whenever you Retain a
##                      card this turn" (Adult Copper Dragon, Merfolk Skirmisher,
##                      Silver Dragon Wyrmling);
##   "witness"        — сколько раз сыграть ещё раз следующую карту ценой <= 5 (Mage);
##   "ahri"           — "Whenever you recruit a card, you may Assassinate a troop";
##   "yi"             — "Whenever you Assassinate or Supplant a troop, gain 1 Power";
##   "all_white"      — Tarrasque: войска других игроков считаются белыми (SiegeCards).

const AKALI := "49800"  # Ancient Green Dragon
const SHEN := "49801"  # Oni: реакция из руки — ShieldGuard.ONI
const WAYFINDER := "49802"  # Adult Bronze Dragon (Kinkou Wayfinder)
const ZED := "49803"  # Ancient Black Dragon
const AIRIS := "49804"  # Sprite
const BLADE := "49805"  # Dryad (Blossoming Blade)
const HWEI := "49806"  # Ancient Copper Dragon
const YASUO := "49807"  # Ancient Blue Dragon
const WITNESS := "49808"  # Mage (The Witness)
const CONSPIRATOR := "49809"  # Violet Fungus (Navori Conspirator)
const RIVERSHAPER := "49810"  # Merfolk Skirmisher
const LEE_SIN := "49811"  # Tarrasque
const HIGHWAYMAN := "49812"  # Copper Dragon Wyrmling (Navori Highwayman)
const GREENGLADE := "49813"  # Silver Dragon Wyrmling (Greenglade Duo)
const SQUIRREL := "49814"  # Young Brass Dragon (Swole Squirrel)
const IRELIA := "49815"  # Ancient Bronze Dragon
const PATHLESS := "49816"  # Adult Copper Dragon (Pathless Ancient)
const LIFEBLADE := "49817"  # Merrow (Kinkou Lifeblade)
const SCHEMER := "49818"  # Adult Silver Dragon (The Schemer)
const SHADOWBLADE := "49819"  # Shrieker Fungus (Shadowblade Fanatic)
const AHRI := "49820"  # Adult Gold Dragon
const KARMA := "49821"  # Ancient Silver Dragon
const MASTER_YI := "49822"  # Kraken

## Карты со словом Retain: их можно удержать вместо розыгрыша.
const RETAINABLE := [AKALI, AIRIS, BLADE, YASUO, HIGHWAYMAN, SQUIRREL, LIFEBLADE, KARMA, MASTER_YI]
const ASPECTS := ["AMBITION", "CONQUEST", "GUILE", "MALICE"]
const PLAY_LABEL := "Play this card now"
const RETAIN_LABEL := "Retain it: keep it for your next hand"


static func build(card_id: String) -> CardEffect:
	match card_id:
		AKALI:
			return SequenceEffect.new([_PowerPerSpy.new(), ReturnOwnSpy.new(null, Callable(), true,
				func(sites: Array) -> CardEffect:
					var hits: Array[CardEffect] = []
					for site in sites:
						hits.append(SupplantTroop.new(1, false, false, false, Callable(), String(site)))
					return SequenceEffect.new(hits))])
		SHEN:
			return SequenceEffect.new([GainInfluence.new(2), GainPower.new(2)])
		WAYFINDER:
			return _Wayfinder.new()
		ZED:
			return _Zed.new()
		AIRIS:
			return _name_aspect(AIRIS, "influence")
		BLADE:
			return AtEndOfTurn.new(PromoteCard.new("played_other", BLADE))
		HWEI:
			return _Hwei.new()
		YASUO:
			return CallbackEffect.new(func(s: GameState, pid: String, r: EffectResolver):
				var n: int = maxi(0, int(s.turn_flags.get("cards_played", 1)) - 1)
				if n > 0:
					s.players[pid].power += n
					r.log_event("gain_power", {"player_id": pid, "amount": n}))
		WITNESS:
			return ShadowCards._AddFlag.new("witness")
		CONSPIRATOR:
			return SequenceEffect.new([
				_NeighbourHand.new(),
				ChooseEffect.new([
					PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
						func(state, _pid): return ShurimaCards._site_full(state, site), GainPower.new(2))),
					_spy_supplant(),
				], ["Place a spy (site full: +2 Power)", "Return one of your spies -> supplant a troop at that site"]),
			])
		RIVERSHAPER:
			return SequenceEffect.new([GainInfluence.new(2), ShadowCards._AddFlag.new("retain_influence")])
		LEE_SIN:
			return SequenceEffect.new([
				ShadowCards._SetFlag.new("all_white"),
				AssassinateTroop.new(2, true),
				ConditionalEffect.new(func(state, pid): return state.stock(pid).trophy_hall_count >= 10, DrawCards.new(1)),
			])
		HIGHWAYMAN:
			return ChooseEffect.new([_DeployPerAspect.new(), MoveTroop.new(1), AssassinateTroop.new(1, true)],
				["Deploy a troop for each different Aspect you played this turn", "Move a troop", "Assassinate a white troop"])
		GREENGLADE:
			return SequenceEffect.new([
				ShadowCards._AddFlag.new("retain_deploy"),
				ChooseEffect.new([AssassinateTroop.new(1, true), DeployTroop.new(2)],
					["Assassinate a white troop", "Deploy 2 troops"]),
			])
		SQUIRREL:
			return CallbackEffect.new(func(s: GameState, pid: String, r: EffectResolver):
				var n: int = 2 + s.players[pid].acorns
				s.players[pid].power += n
				r.log_event("gain_power", {"player_id": pid, "amount": n}))
		IRELIA:
			# "Choose 2 times" (владелец, 2026-10-18): два вопроса по одному
			# варианту, как у Mummy Lord; порядок (когда удваивать Power) — за игроком.
			var step := func(): return ChooseEffect.new([
				_DoublePower.new(), _ReturnAllSpies.new(), SupplantTroop.new(1, true), DeployTroop.new(3),
			], ["Double your Power", "Return all enemy spies from a site", "Supplant a white troop", "Deploy 3 troops"])
			return SequenceEffect.new([step.call(), step.call()])
		PATHLESS:
			return SequenceEffect.new([GainPower.new(2), ShadowCards._AddFlag.new("retain_power")])
		LIFEBLADE:
			return _name_aspect(LIFEBLADE, "power")
		SCHEMER:
			return ChooseEffect.new([
				PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
					func(state, _pid): return ShurimaCards._site_full(state, site), _may_retain_top())),
				_ReturnTwoRetain.new(),
			], ["Place a spy (site full: you may Retain the top card of your deck)",
				"Return two of your spies -> Retain a card you played this turn"])
		SHADOWBLADE:
			return ChooseEffect.new([
				PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
					func(state, pid): return IoniaCards._other_troop_at(state, pid, site), _may_retain_top())),
				_spy_supplant(),
			], ["Place a spy (another player's troop there: you may Retain the top card of your deck)",
				"Return one of your spies -> supplant a troop at that site"])
		AHRI:
			return SequenceEffect.new([GainInfluence.new(4), ChooseEffect.new([
				_RecruitDiscount.new(), ShadowCards._AddFlag.new("ahri"),
			], ["This turn, cards cost 1 less to recruit", "This turn, whenever you recruit a card, you may assassinate a troop"])])
		KARMA:
			return AtEndOfTurn.new(_KarmaPromote.new())
		MASTER_YI:
			return SequenceEffect.new([ShadowCards._AddFlag.new("yi"), _StrikersFromTop.new(5)])
	return null


## Бонус "Retain: ..." карты (null — у карты его нет).
static func retain_effect(card_id: String) -> CardEffect:
	match card_id:
		AKALI:
			return PlaceSpy.new(2)
		BLADE:
			return _LookAtHand.new()
		YASUO:
			return GainPower.new(1)
		SQUIRREL:
			return CallbackEffect.new(func(s: GameState, pid: String, r: EffectResolver):
				s.players[pid].acorns += 1
				r.log_event("acorn", {"player_id": pid, "total": s.players[pid].acorns}))
		KARMA:
			return _RetainOthers.new(2)
	return null


## Можно ли сейчас удержать эту карту из руки вместо розыгрыша.
static func can_retain(state: GameState, player_id: String, card_id: String) -> bool:
	if not (RETAINABLE.has(card_id) or card_id == BandleCards.KENNEN) or player_id != state.current_player():
		return false
	var hand: Array = state.players[player_id].deck.hand
	if not hand.has(card_id):
		return false
	# Young Brass Dragon: "Discard a card to Retain" — нужна ещё карта в руке.
	return card_id != SQUIRREL or hand.size() >= 2


## Вопрос "сыграть или удержать" при щелчке по карте с Retain.
static func play_or_retain(card_id: String) -> CardEffect:
	var choose := ChooseEffect.new([_PlayFromHand.new(card_id), _RetainFromHand.new(card_id)],
		[PLAY_LABEL, RETAIN_LABEL], "Play this card, or Retain it?")
	choose.source_card = card_id
	return choose


## Удержать карту card_id из from ("hand" | "played" | "deck"; карту колоды
## вызывающий код уже снял сверху, остальные снимаются здесь).
static func retain(state: GameState, player_id: String, card_id: String, resolver: EffectResolver, from: String) -> void:
	var d: Deck = state.players[player_id].deck
	var pile: Array = d.hand if from == "hand" else (d.played_pile if from == "played" else [])
	if from != "deck":
		var idx := pile.rfind(card_id)
		if idx == -1:
			return
		pile.remove_at(idx)
	d.retained.append(card_id)
	state.turn_flags["retains"] = int(state.turn_flags.get("retains", 0)) + 1
	# Верхняя карта колоды — тайная: её имя в журнал не пишем.
	resolver.log_event("retain", {"player_id": player_id, "card_id": card_id if from != "deck" else "", "from": from})
	var p: PlayerState = state.players[player_id]
	var inf := int(state.turn_flags.get("retain_influence", 0))
	var pw := int(state.turn_flags.get("retain_power", 0))
	if inf > 0:
		p.influence += inf
		resolver.log_event("gain_influence", {"player_id": player_id, "amount": inf})
	if pw > 0:
		p.power += pw
		resolver.log_event("gain_power", {"player_id": player_id, "amount": pw})
	var bonus := retain_effect(card_id) if card_id != BandleCards.KENNEN else BandleCards.retain_effect(card_id)
	if bonus != null:
		resolver.push(bonus, player_id, card_id)
	var deploy := int(state.turn_flags.get("retain_deploy", 0))
	if deploy > 0:
		resolver.push(DeployTroop.new(deploy), player_id)


## Mage (The Witness): следующая карта ценой <= 5 разыгрывается ещё раз.
static func on_play(state: GameState, _player_id: String, card_id: String, effect: CardEffect) -> CardEffect:
	var n := int(state.turn_flags.get("witness", 0))
	if n <= 0 or CardLibrary.card_cost(card_id) > 5:
		return effect
	state.turn_flags.erase("witness")
	var all: Array[CardEffect] = [effect]
	for i in range(n):
		all.append(CardLibrary.get_effect(card_id))
	return SequenceEffect.new(all)


## Adult Gold Dragon (Ahri): "Whenever you recruit a card, you may Assassinate a
## troop". immediate — зовёт GameServer вне розыгрыша карты.
static func on_recruit(state: GameState, player_id: String, resolver: EffectResolver, immediate: bool = false) -> void:
	var n := int(state.turn_flags.get("ahri", 0))
	if n <= 0 or player_id != state.current_player():
		return
	var eff := AssassinateTroop.new(n, false, true)
	if not immediate:
		resolver.push(eff, player_id, AHRI)
	elif resolver.pending != null:
		resolver.pending.stack.push_front({"effect": eff, "player_id": player_id, "card": AHRI})
	else:
		resolver.apply(eff, player_id, state, AHRI)


## Kraken (Master Yi): "+1 Power whenever you Assassinate or Supplant a troop".
static func on_kill(state: GameState, player_id: String) -> void:
	var n := int(state.turn_flags.get("yi", 0))
	if n > 0 and player_id == state.current_player():
		state.players[player_id].power += n


static func _other_troop_at(state: GameState, player_id: String, site_id: String) -> bool:
	for slot_id: String in state.graph.slots_of_site(site_id):
		var owner := String(state.troops.get(slot_id, ""))
		if owner != "" and owner != "white" and owner != player_id:
			return true
	return false


static func _spy_supplant() -> CardEffect:
	return ReturnOwnSpy.new(null, func(site): return SupplantTroop.new(1, false, false, false, Callable(), site))


static func _may_retain_top() -> CardEffect:
	return OptionalEffect.new(_RetainTop.new(), "Retain the top card of your deck?")


static func _name_aspect(card_id: String, resource: String) -> CardEffect:
	var opts: Array[CardEffect] = []
	var labels: Array[String] = []
	for asp: String in ASPECTS:
		opts.append(_BecomeAspect.new(card_id, asp, resource))
		labels.append("Become %s: +1 %s per %s card played" % [asp.capitalize(), resource.capitalize(), asp.capitalize()])
	return ChooseEffect.new(opts, labels, "Name an Aspect:")


static func _spy_count(state: GameState, player_id: String) -> int:
	var n := 0
	for site_id: String in state.spies.keys():
		if (state.spies[site_id] as Array).has(player_id):
			n += 1
	return n


# --- Retain -------------------------------------------------------------------

class _PlayFromHand extends CardEffect:
	var card: String
	func _init(c: String) -> void:
		card = c
	func is_available(state: GameState, player_id: String) -> bool:
		return TurnEngine.can_play_card(state, player_id)
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if not state.players[player_id].deck.hand.has(card):
			return
		resolver.log_event("play_card", {"player_id": player_id, "card_id": card})
		var eff: CardEffect = TurnEngine.begin_play(state, player_id, card)
		if eff != null:
			resolver.push(eff, player_id, card)


class _RetainFromHand extends CardEffect:
	var card: String
	func _init(c: String) -> void:
		card = c
	func _discard_options(state: GameState, player_id: String) -> Array:
		var rest: Array = state.players[player_id].deck.hand.duplicate()
		rest.erase(card)
		var out: Array = []
		for cid in rest:
			if not out.has(cid):
				out.append(cid)
		return out
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		if card != IoniaCards.SQUIRREL:
			IoniaCards.retain(state, player_id, card, resolver, "hand")
			return
		# Young Brass Dragon: сначала сбросить другую карту из руки.
		var options := _discard_options(state, player_id)
		if is_answered():
			var chosen := String(answer()) if answer() != null else ""
			if not options.has(chosen):
				return
			d.hand.remove_at(d.hand.find(chosen))
			d.discard_pile.append(chosen)
			resolver.log_event("discard", {"player_id": player_id, "card_id": chosen})
			IoniaCards.retain(state, player_id, card, resolver, "hand")
			FreljordCards.on_discard(state, player_id, chosen, resolver)
			return
		if options.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Discard a card to Retain Young Brass Dragon"
		pd.choice_type = "target_card"
		pd.tag = "hand"
		pd.legal_options = options
		pd.source_card = card
		pd.target_effect = self
		resolver.request_decision(pd)


## Удержать верхнюю карту колоды (Adult Silver Dragon, Shrieker Fungus).
class _RetainTop extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		if d.draw_pile.is_empty():
			if d.discard_pile.is_empty():
				return
			d.draw_pile = d.discard_pile.duplicate()
			d.discard_pile.clear()
			d.shuffle_draw_pile(state.rng)
		IoniaCards.retain(state, player_id, d.draw_pile.pop_back(), resolver, "deck")


## Ancient Silver Dragon (Karma), Retain: "You may also Retain 2 other cards".
class _RetainOthers extends CardEffect:
	var left: int
	func _init(n: int) -> void:
		left = n
	func _options(state: GameState, player_id: String) -> Array:
		var out: Array = []
		for cid in state.players[player_id].deck.hand:
			if not out.has(cid):
				out.append(cid)
		return out
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var chosen := String(answer()) if answer() != null else ""
			_answered = false
			_answer = null
			if chosen == "" or not _options(state, player_id).has(chosen):
				return
			left -= 1
			if left > 0:
				resolver.push(self, player_id)
			IoniaCards.retain(state, player_id, chosen, resolver, "hand")
			return
		var options := _options(state, player_id)
		if left <= 0 or options.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "You may Retain another card (%d left)" % left
		pd.choice_type = "target_card"
		pd.tag = "hand"
		pd.legal_options = options
		pd.legal_options.append("")
		pd.source_card = IoniaCards.KARMA
		pd.target_effect = self
		resolver.request_decision(pd)


## Adult Silver Dragon (The Schemer): "You may return two of your spies to Retain
## a card you've played this turn".
class _ReturnTwoRetain extends CardEffect:
	func is_available(state: GameState, player_id: String) -> bool:
		return IoniaCards._spy_count(state, player_id) >= 2 \
			and not state.players[player_id].deck.played_pile.is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if not is_available(state, player_id):
			return
		resolver.push(SequenceEffect.new([ReturnOwnSpy.new(), ReturnOwnSpy.new(), IoniaCards._RetainPlayed.new()]), player_id)


class _RetainPlayed extends CardEffect:
	func _options(state: GameState, player_id: String) -> Array:
		var out: Array = []
		for cid in state.players[player_id].deck.played_pile:
			if not out.has(cid):
				out.append(cid)
		return out
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var options := _options(state, player_id)
		if is_answered():
			var chosen := String(answer()) if answer() != null else ""
			if options.has(chosen):
				IoniaCards.retain(state, player_id, chosen, resolver, "played")
			return
		if options.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Retain a card you played this turn"
		pd.choice_type = "target_card"
		pd.legal_options = options
		pd.source_card = IoniaCards.SCHEMER
		pd.target_effect = self
		resolver.request_decision(pd)


## Dryad (Blossoming Blade), Retain: "Choose another player, you may look at their hand".
class _LookAtHand extends CardEffect:
	var _who := ""
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var rivals: Array = []
		for pid: String in state.turn_order:
			if pid != player_id and state.is_opponent(player_id, pid):
				rivals.append(pid)
		if is_answered():
			if _who != "":
				return  # рука показана, ответ — "дальше"
			_answered = false
			var chosen := String(_answer) if _answer != null else ""
			_answer = null
			if not rivals.has(chosen):
				return
			_show(state, player_id, chosen, resolver)
			return
		if rivals.is_empty():
			return
		if rivals.size() == 1:
			_show(state, player_id, String(rivals[0]), resolver)
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Look at whose hand?"
		pd.choice_type = "target_player"
		pd.legal_options = rivals
		pd.source_card = IoniaCards.BLADE
		pd.target_effect = self
		resolver.request_decision(pd)
	func _show(state: GameState, player_id: String, who: String, resolver: EffectResolver) -> void:
		_who = who
		var hand: Array = state.players[who].deck.hand
		resolver.log_event("look_at_hand", {"player_id": player_id, "target": who})
		var options: Array = []
		for cid in hand:
			if not options.has(cid):
				options.append(cid)
		options.append("")
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "%s's hand (%d cards)" % [who.capitalize(), hand.size()]
		pd.choice_type = "target_card"
		pd.legal_options = options
		pd.source_card = IoniaCards.BLADE
		pd.target_effect = self
		resolver.request_decision(pd)


# --- Карты -------------------------------------------------------------------

## Ancient Green Dragon (Akali): "+1 Power for each spy you have on the board".
class _PowerPerSpy extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var n := IoniaCards._spy_count(state, player_id)
		if n > 0:
			state.players[player_id].power += n
			resolver.log_event("gain_power", {"player_id": player_id, "amount": n})


## Adult Bronze Dragon (Kinkou Wayfinder): deploy 3; рука 5+ — ещё +2 Power; 7+ — карта.
class _Wayfinder extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var n: int = state.players[player_id].deck.hand.size()
		var all: Array[CardEffect] = [DeployTroop.new(3)]
		if n >= 5:
			all.append(GainPower.new(2))
		if n >= 7:
			all.append(DrawCards.new(1))
		resolver.push(SequenceEffect.new(all), player_id)


## Ancient Black Dragon (Zed): выбор повторяется ещё раз за каждую удержанную в
## этот ход карту (не больше 2 раз).
class _Zed extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var times: int = 1 + mini(2, int(state.turn_flags.get("retains", 0)))
		var all: Array[CardEffect] = []
		for i in range(times):
			all.append(ChooseEffect.new([
				PlaceSpy.new(1, false, func(site): return AssassinateTroop.new(1, false, false, false, 0, 0, site)),
				ReturnOwnSpy.new(null, func(site): return SupplantTroop.new(1, false, false, false, Callable(), site)),
			], ["Place a spy -> assassinate a troop at that site", "Return one of your spies -> supplant a troop at that site"]))
		resolver.push(SequenceEffect.new(all), player_id)


## Sprite (Airis) / Merrow (Kinkou Lifeblade): карта становится названным Аспектом,
## +1 ресурс за каждую сыгранную в этот ход карту этого Аспекта (и её саму).
class _BecomeAspect extends CardEffect:
	var card: String
	var aspect: String
	var resource: String
	func _init(c: String, a: String, r: String) -> void:
		card = c
		aspect = a
		resource = r
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var played: Array = state.played_aspects_this_turn
		var idx := played.rfind(CardLibrary.card_aspect(card))
		if idx != -1:
			played[idx] = aspect
		var n := played.count(aspect)
		if resource == "power":
			state.players[player_id].power += n
			resolver.log_event("gain_power", {"player_id": player_id, "amount": n})
		else:
			state.players[player_id].influence += n
			resolver.log_event("gain_influence", {"player_id": player_id, "amount": n})


## Ancient Copper Dragon (Hwei): по двум Аспектам, сыгранным перед ней.
class _Hwei extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var played: Array = state.played_aspects_this_turn
		var before: Array = played.slice(maxi(0, played.size() - 3), maxi(0, played.size() - 1))
		var all: Array[CardEffect] = []
		for asp in before:
			match String(asp):
				"MALICE":
					all.append(AssassinateTroop.new(1))
				"GUILE":
					all.append(PlaceSpy.new(2))
					all.append(GainPower.new(1))
				"CONQUEST":
					all.append(SupplantTroop.new(1, true))
				"AMBITION":
					all.append(GainInfluence.new(3))
		if not all.is_empty():
			resolver.push(SequenceEffect.new(all), player_id)


## Violet Fungus (Navori Conspirator): у соседа слева или справа больше 5 карт — +1 Power.
class _NeighbourHand extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var order: Array[String] = state.turn_order
		var i := order.find(player_id)
		var n := order.size()
		if n < 2 or i == -1:
			return
		for other: String in [order[(i + 1) % n], order[(i - 1 + n) % n]]:
			if other != player_id and state.players[other].deck.hand.size() > 5:
				state.players[player_id].power += 1
				resolver.log_event("gain_power", {"player_id": player_id, "amount": 1})
				return


## Copper Dragon Wyrmling (Navori Highwayman): войско за каждый разный Аспект хода.
class _DeployPerAspect extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var kinds := {}
		for asp in state.played_aspects_this_turn:
			if IoniaCards.ASPECTS.has(String(asp)):
				kinds[String(asp)] = true
		if kinds.size() > 0:
			resolver.push(DeployTroop.new(kinds.size()), player_id)


## Ancient Bronze Dragon (Irelia): "Double your Power".
class _DoublePower extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var n: int = state.players[player_id].power
		if n > 0:
			state.players[player_id].power += n
			resolver.log_event("gain_power", {"player_id": player_id, "amount": n})


## Ancient Bronze Dragon (Irelia): "Return all spies from a site" — все шпионы
## соперников в одной локации с Присутствием (каждый может ответить Oni).
class _ReturnAllSpies extends CardEffect:
	func _sites(state: GameState, player_id: String) -> Array:
		var out: Array = []
		for site_id: String in state.spies.keys():
			var enemy := false
			for owner in state.spies[site_id]:
				if state.is_opponent(player_id, String(owner)):
					enemy = true
			if enemy and state.presence.has_presence_at_site(player_id, site_id, state.troops, state.spies):
				out.append(site_id)
		return out
	func is_available(state: GameState, player_id: String) -> bool:
		return not _sites(state, player_id).is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var sites := _sites(state, player_id)
		if is_answered():
			var site := String(answer()) if answer() != null else ""
			if not sites.has(site):
				return
			for owner in (state.spies[site] as Array).duplicate():
				var who := String(owner)
				if not state.is_opponent(player_id, who):
					continue
				var hit := CallbackEffect.new(func(s, pid, r):
					Actions.remove_spy(s, site, who, pid)
					r.log_event("return_spy", {"player_id": pid, "site_id": site, "spy_owner": who}))
				if ShieldGuard.can_react(state, player_id, who):
					resolver.push(ShieldGuard.new(who, hit, "the spy's return"), player_id)
				else:
					resolver.push(hit, player_id)
			return
		if sites.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Return all enemy spies from a site"
		pd.choice_type = "target_site"
		pd.legal_options = sites
		pd.source_card = IoniaCards.IRELIA
		pd.target_effect = self
		resolver.request_decision(pd)


## Adult Gold Dragon (Ahri): "For the rest of your turn, cards in the Market cost 1 less".
class _RecruitDiscount extends CardEffect:
	func apply(state: GameState, _player_id: String, _resolver: EffectResolver) -> void:
		state.turn_discounts["recruit"] = int(state.turn_discounts.get("recruit", 0)) + 1


## Ancient Silver Dragon (Karma), в конце хода: "Promote a card you played to
## recruit a card from the market that costs up to 2 more".
class _KarmaPromote extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var circle: Array = state.stock(player_id).deck.inner_circle
		var before := circle.size()
		resolver.push(CallbackEffect.new(func(s: GameState, pid: String, r: EffectResolver):
			var c: Array = s.stock(pid).deck.inner_circle
			if c.size() <= before:
				return
			var cost: int = maxi(0, CardLibrary.card_cost(String(c[c.size() - 1])))
			r.push(RecruitFree.new("", cost + 2, 1, true), pid)), player_id)
		resolver.push(PromoteCard.new("played_other", "", Callable(), 1, true), player_id)


## Kraken (Master Yi): "Reveal the top 5 cards of your deck. Put all cards that
## have the word Assassinate or Supplant into your hand. Discard the rest."
class _StrikersFromTop extends CardEffect:
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
			var text := String(CardLibrary.card_data(card).get("ability_text", "")).to_lower()
			if text.contains("assassinate") or text.contains("supplant"):
				taken.append(card)
			else:
				dropped.append(card)
		deck.hand.append_array(taken)
		deck.discard_pile.append_array(dropped)
		resolver.log_event("fetch_from_top", {"player_id": player_id, "looked": taken.size() + dropped.size(), "cards": taken})
