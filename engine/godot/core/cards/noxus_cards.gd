class_name NoxusCards
extends RefCounted

## Полуколода Noxus (New Era) — способности карт Noxus из фан-мода Runeterra
## Reforged на существах Аверна (Avernus, первый слой Девяти Преисподних):
## дьяволы, хобгоблины и наёмники Кровавой войны. Таблица id -> существо ->
## карта мода — Claude outputs/new_era_noxus.md.
##
## Перевод на правила этой игры:
##   Execute       -> Devour (стопка state.devoured_pile);
##   Execute pile  -> devoured pile;
##   Valor         -> MALICE;
##   Might         -> эффект срабатывает, если в этот ход текущий игрок что-то
##                    сожрал; вторая Might на карте требует второго пожирания
##                    (правила мода). Проверяется в момент розыгрыша карты.
##
## Счётчики хода — state.turn_flags (сбрасываются в start_turn):
##   "devours"        — сколько карт текущий игрок сожрал в этот ход (note_devour);
##   "trophy_start"   — трофеи игрока в начале хода (Azer Sentinel, TurnEngine.start_turn);
##   "might_twice"    — Troll: каждая Might срабатывает дважды;
##   "might_supplant" — Horned Devil: каждое срабатывание Might ещё и supplant;
##   "devour_promote" — Efreeti: сожранную из руки/сброса карту можно продвинуть;
##   "no_deploy"      — Weretiger: {site: player} — туда нельзя ставить войска.

const HALF_DRAGON := "49521"
const BLADE_FRAGMENT := "49523"
const BLADE_OF_EXILE := "49524"
const FRAGMENT_SUPPLY := 3


static func build(card_id: String) -> CardEffect:
	match card_id:
		"49500":  # Bandit (Armed Acquisitioner)
			return SequenceEffect.new([GainInfluence.new(2), devour(["market"], true, Callable(), "pick3")])
		"49501":  # Wereboar (Legion Marauder)
			return PiltoverCards._AfterTroops.new(ChooseEffect.new([
				DeployTroop.new(3),
				AssassinateTroop.new(1),
			], ["Deploy 3 troops", "Assassinate a troop"]), func(state, pid, before):
				if PiltoverCards._moved_next_to_other(state, pid, before) or _hit_player(state, pid, before):
					return devour(["hand", "market"], true)
				return null)
		"49502":  # Goblin Boss (Crimson Disciple)
			return ChooseEffect.new([
				PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
					func(state, _pid): return CelestialCards.site_is_full(state, site),
					devour(["hand", "discard"], true))),
				ReturnOwnSpy.new(GainPower.new(4)),
			], ["Place a spy (full site: you may devour a card in your hand or discard pile)",
				"Return one of your spies -> +4 Power"])
		"49503":  # Hell Hound (Thorn of the Rose)
			return ChooseEffect.new([
				GainPower.new(3),
				SequenceEffect.new([GainPower.new(1), devour(["market", "hand", "discard"], false)]),
			], ["+3 Power", "+1 Power, devour a card in the market, your hand or discard pile"])
		"49504":  # Pseudodragon (Crimson Aristocrat)
			return PlaceSpy.new(1, false, func(site): return _AristocratBonus.new(site))
		"49505":  # Medusa (Lady of Blood)
			return SequenceEffect.new([
				GainPower.new(3),
				Might.new(1, func(): return SupplantTroop.new(1, true)),
				Might.new(2, func(): return AssassinateTroop.new(1)),
			])
		"49506":  # Bugbear Stalker (Black Rose Spy)
			return ChooseEffect.new([
				SequenceEffect.new([PlaceSpy.new(1), devour(["market"], false, Callable(), "discount3")]),
				ReturnOwnSpy.new(GainInfluence.new(4)),
			], ["Place a spy, devour a card in the market (its replacement costs 3 less)",
				"Return one of your spies -> +4 Influence"])
		"49507":  # Guard Captain (Legion Veteran)
			return SequenceEffect.new([
				GainInfluence.new(3),
				Might.new(1, func(): return ReturnTroopOrSpy.new(1)),
				Might.new(2, func(): return DrawCards.new(1)),
			])
		"49508":  # Bugbear Warrior (Reckless Trifarian)
			return SequenceEffect.new([AssassinateTroop.new(1), _TrophyPower.new()])
		"49509":  # Mummy (Grave Physician)
			return SequenceEffect.new([
				GainInfluence.new(2),
				CardLibrary._GhostDevouredPileEffect.new(),
				Might.new(1, func(): return GainInfluence.new(1)),
			])
		"49510":  # Ogre (Legion General)
			return SequenceEffect.new([
				devour(["hand", "discard"], true, func(_cid): return ScryCards.new(1)),
				ChooseEffect.new([SupplantTroop.new(1, true), DeployTroop.new(3)],
					["Supplant a white troop", "Deploy 3 troops"]),
			])
		"49511":  # Minotaur of Baphomet (Minotaur Reckoner)
			return SequenceEffect.new([
				GainPower.new(3),
				Might.new(1, func(): return GainPower.new(1)),
				_TrophyPower.new(),
			])
		"49512":  # Hobgoblin Captain (Incisive Tactician)
			return SequenceEffect.new([
				ChooseEffect.new([MoveTroop.new(1), DeployTroop.new(3)], ["Move a troop", "Deploy 3 troops"]),
				Might.new(1, func(): return GainInfluence.new(2)),
				Might.new(2, func(): return DrawCards.new(1)),
			])
		"49513":  # Weretiger (Katarina)
			return ChooseEffect.new([
				PlaceSpy.new(1, false, func(site): return PiltoverCards._AfterTroops.new(
					AssassinateTroop.new(3, false, true, false, 0, 0, site), func(state, pid, before):
						if not PiltoverCards._victims(state, before).is_empty():
							return _BlockDeploy.new(site)
						return null)),
				SequenceEffect.new([MoveTroop.new(2, true, true), DrawCards.new(1)]),
			], ["Place a spy, you may assassinate up to 3 troops there (then no deploying there this turn)",
				"Move up to 2 of your troops and draw a card"])
		"49514":  # Lamia (Leblanc)
			return _Lamia.new()
		"49515":  # Horned Devil (Mordekaiser)
			return ChooseEffect.new([
				_DevourHalfMarket.new(),
				_PlayFromDevoured.new(2),
				ShadowCards._SetFlag.new("might_supplant"),
			], ["Devour half the market deck (if it is already empty, you win)",
				"Play up to 2 cards from the devoured pile",
				"Each time you trigger Might this turn, supplant a troop"])
		"49516":  # Efreeti (Vladimir)
			return SequenceEffect.new([
				AssassinateTroop.new(2),
				ShadowCards._SetFlag.new("devour_promote"),
				GainVpPerN.new("power", "inner_circle", 4, 1),
			])
		"49517":  # Azer Sentinel (Draven)
			return SequenceEffect.new([
				PiltoverCards._strike_anywhere(),
				AtEndOfTurn.new(_VpPerKill.new()),
				Might.new(1, func(): return AssassinateTroop.new(1)),
				Might.new(2, func(): return GainPower.new(2)),
			])
		"49518":  # Ice Devil (Swain)
			return ChooseEffect.new([
				SequenceEffect.new([PlaceSpy.new(2), DrawCards.new(1)]),
				ReturnOwnSpy.new(null, Callable(), true, func(sites): return SequenceEffect.new([
					GainInfluence.new(sites.size()), ShadowCards._SupplantAtSites.new(sites)])),
			], ["Place 2 spies and draw a card",
				"Return any number of your spies -> +1 Influence and supplant a troop at each of those sites"])
		"49519":  # Troll (Sion)
			return SequenceEffect.new([
				ShadowCards._SetFlag.new("might_twice"),
				DrawCards.new(1),
				devour(["hand", "market", "discard"], false),
				Might.new(1, func(): return DeployTroop.new(4)),
				Might.new(2, func(): return SupplantTroop.new(1)),
			])
		"49520":  # Fire Giant (Darius)
			return _GiantStrike.new()
		"49521":  # Half-Dragon (Riven)
			return SequenceEffect.new([GainPower.new(4), _GainFragment.new(), AtEndOfTurn.new(_Reforge.new())])
		"49522":  # Wyvern (Samira)
			return ChooseEffect.new([
				devour(["hand"], false, func(cid): return DrawCards.new(Scoring._card_vp(cid, "inner_circle_vp"))),
				devour(["market"], false, func(cid): return GainVP.new(Scoring._card_vp(cid, "deck_vp"))),
				AssassinateTroop.new(2, false, false, true),
			], ["Devour a card in your hand -> draw cards equal to its inner circle VP",
				"Devour a card in the market -> gain VP equal to its deck VP",
				"Assassinate 2 troops at a site"])
		"49523":  # Blade Fragment
			return ChooseEffect.new([
				GainPower.new(3),
				DrawCards.new(1),
				_FetchBlade.new(),
			], ["+3 Power", "Draw a card",
				"Blade Fragments and Half-Dragons from your top 5 cards into your hand, discard the rest"])
		"49524":  # Blade of Exile
			return SequenceEffect.new([
				FetchFromTop.new(5, func(c): return c == HALF_DRAGON),
				GainPower.new(3),
				DrawCards.new(3),
			])
	return null


## "Devour a card in <zones>". zones — из "hand", "discard", "market"; если
## есть и рынок, и карты игрока, сначала выбирается, откуда. then — Callable
## (card_id) -> CardEffect, что дать за сожранную карту. market_mode:
##   "refill"    — слот рынка пополняется как обычно;
##   "pick3"     — Bandit: из 3 верхних карт колоды рынка игрок выбирает замену;
##   "discount3" — Bugbear Stalker: замена в этот ход на 3 дешевле.
static func devour(zones: Array, optional: bool, then: Callable = Callable(), market_mode: String = "refill") -> CardEffect:
	var own: Array = zones.filter(func(z): return z != "market")
	if not zones.has("market"):
		return _Devour.new(own, optional, then)
	if own.is_empty():
		return _Devour.new(["market"], optional, then, market_mode)
	var parts := PackedStringArray()
	for z: String in own:
		parts.append("your " + ("discard pile" if z == "discard" else z))
	var where := " or ".join(parts)
	return ChooseEffect.new([
		_Devour.new(own, optional, then),
		_Devour.new(["market"], optional, then, market_mode),
	], ["Devour a card in " + where, "Devour a card in the market"], "Devour a card from:")


## Сожрать одну карту (общий путь для всех карт с Devour): учёт для Might
## и Efreeti. src — откуда карта ("hand", "discard", "market", ...).
static func on_devour(state: GameState, player_id: String, card_id: String, src: String, resolver: EffectResolver) -> void:
	if player_id != state.current_player():
		return
	state.turn_flags["devours"] = devours(state) + 1
	if state.turn_flags.get("devour_promote", false) and src in ["hand", "discard", "hand_or_discard", "deck"]:
		var name := String(CardLibrary.card_data(card_id).get("name", card_id))
		var ask := OptionalEffect.new(_PromoteDevoured.new(card_id), "Promote %s instead of devouring it?" % name)
		ask.source_card = card_id
		resolver.push(ask, player_id)


static func devours(state: GameState) -> int:
	return int(state.turn_flags.get("devours", 0))


## Weretiger: можно ли игроку ставить войска в эту локацию в этот ход.
static func deploy_blocked(state: GameState, player_id: String, site_id: String) -> bool:
	var blocked: Dictionary = state.turn_flags.get("no_deploy", {})
	return site_id != "" and String(blocked.get(site_id, "")) == player_id


## Войско игрока-соперника (не белое) убито с момента снимка before.
static func _hit_player(state: GameState, player_id: String, before: Dictionary) -> bool:
	for victim: String in PiltoverCards._victims(state, before):
		if victim != "white" and state.is_enemy(player_id, victim):
			return true
	return false


## "Might: X" — срабатывает, если в этот ход сожрано не меньше index карт.
## make — Callable() -> CardEffect: дерево эффекта пересобирается на каждое
## срабатывание (Troll — дважды).
class Might extends CardEffect:
	var index: int
	var make: Callable
	func _init(i: int, fn: Callable) -> void:
		index = i
		make = fn
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if NoxusCards.devours(state) < index:
			return
		var times := 2 if state.turn_flags.get("might_twice", false) else 1
		resolver.log_event("might", {"player_id": player_id, "times": times})
		for t in range(times):
			if state.turn_flags.get("might_supplant", false):
				resolver.push(SupplantTroop.new(1), player_id)
			resolver.push(make.call(), player_id)


## Сожрать карту из руки/сброса или с рынка.
class _Devour extends CardEffect:
	var zones: Array
	var optional: bool
	var then: Callable
	var market_mode: String
	func _init(z: Array, opt: bool, fn: Callable = Callable(), mode: String = "refill") -> void:
		zones = z
		optional = opt
		then = fn
		market_mode = mode
	func _options(state: GameState, player_id: String) -> Array:
		if zones.has("market"):
			var idx: Array = []
			for i in range(state.market.display.size()):
				if state.market.display[i] != "":
					idx.append(i)
			return idx
		var d: Deck = state.players[player_id].deck
		var out: Array = []
		if zones.has("hand"):
			out.append_array(d.hand)
		if zones.has("discard"):
			out.append_array(d.discard_pile)
		return out
	func is_available(state: GameState, player_id: String) -> bool:
		return not _options(state, player_id).is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var chosen = answer()
			_answered = false
			_answer = null
			if zones.has("market"):
				if chosen != null and int(chosen) != -1:
					_take_market(state, player_id, int(chosen), resolver)
			elif chosen != null and String(chosen) != "":
				_take_own(state, player_id, String(chosen), resolver)
			return
		var options := _options(state, player_id)
		if options.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.choice_type = "target_card"
		if zones.has("market"):
			pd.choice_type = "target_market_index"
			pd.tag = "market"
			pd.prompt = "Devour a card in the market"
			if optional:
				options.append(-1)
		else:
			pd.tag = "hand_or_discard" if zones.size() > 1 else String(zones[0])
			pd.prompt = "Devour a card"
			if optional:
				options.append("")
		if optional:
			pd.prompt = "You may " + pd.prompt.to_lower()
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)
	func _take_own(state: GameState, player_id: String, cid: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		var src := "hand"
		if zones.has("hand") and d.hand.has(cid):
			if MercenaryCards.sylgar_saves(state, player_id, cid, resolver):
				return
			d.hand.remove_at(d.hand.find(cid))
		elif zones.has("discard") and d.discard_pile.has(cid):
			if MercenaryCards.sylgar_saves(state, player_id, cid, resolver):
				return
			d.discard_pile.remove_at(d.discard_pile.find(cid))
			src = "discard"
		else:
			return
		_finish(state, player_id, cid, src, resolver)
	func _take_market(state: GameState, player_id: String, index: int, resolver: EffectResolver) -> void:
		if index < 0 or index >= state.market.display.size() or state.market.display[index] == "":
			return
		var cid: String = state.market.display[index]
		if MercenaryCards.sylgar_saves(state, player_id, cid, resolver):
			return
		match market_mode:
			"pick3":
				state.market.display[index] = ""
				var top: Array[String] = []
				for i in range(mini(3, state.market.deck.size())):
					top.append(state.market.deck.pop_back())
				if not top.is_empty():
					resolver.push(_PickReplacement.new(index, top), player_id)
			"discount3":
				state.market.recruit_at(index)
				var key := "slot:%d" % index
				state.turn_discounts[key] = int(state.turn_discounts.get(key, 0)) + 3
			_:
				state.market.recruit_at(index)
		if state.market.is_deck_empty() and market_mode != "pick3":
			GameEnd.trigger(state, "market_empty")
		_finish(state, player_id, cid, "market", resolver)
	func _finish(state: GameState, player_id: String, cid: String, src: String, resolver: EffectResolver) -> void:
		if then.is_valid():
			var next: CardEffect = then.call(cid)
			if next != null:
				resolver.push(next, player_id)
		if Supplies.redirect_outcast(state, player_id, cid, resolver):
			return
		state.devoured_pile.append(cid)
		resolver.log_event("devour", {"player_id": player_id, "card_id": cid, "source": src})
		ShadowCards.on_devour(state, player_id, cid, resolver)
		NoxusCards.on_devour(state, player_id, cid, src, resolver)


## Bandit: из верхних карт колоды рынка одна встаёт в пустой слот, остальные — вниз колоды.
class _PickReplacement extends CardEffect:
	var index: int
	var cards: Array[String]
	func _init(i: int, c: Array[String]) -> void:
		index = i
		cards = c
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var pick := cards[0]
		if cards.size() > 1 and not is_answered():
			var pd := PendingDecision.new()
			pd.player_id = player_id
			pd.prompt = "Choose the card that replaces the devoured one (the rest go to the bottom of the market deck)"
			pd.choice_type = "target_card"
			pd.legal_options = Array(cards)
			pd.target_effect = self
			resolver.request_decision(pd)
			return
		if is_answered() and cards.has(String(answer())):
			pick = String(answer())
		cards.remove_at(cards.find(pick))
		state.market.display[index] = pick
		for c: String in cards:
			state.market.deck.insert(0, c)
		resolver.log_event("market_pick", {"player_id": player_id, "card_id": pick, "market_index": index})


## Efreeti: сожранная карта вместо Devour уходит во Внутренний круг.
class _PromoteDevoured extends CardEffect:
	var card: String
	func _init(c: String) -> void:
		card = c
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var idx := state.devoured_pile.rfind(card)
		if idx == -1:
			return
		state.devoured_pile.remove_at(idx)
		state.stock(player_id).deck.inner_circle.append(card)
		resolver.log_event("promote", {"player_id": player_id, "card_id": card})
		ShurimaCards.on_promote(state, player_id, String(card), resolver)


## Pseudodragon: +1 Influence за чужое войско, полную локацию и чужого шпиона там.
class _AristocratBonus extends CardEffect:
	var site: String
	func _init(s: String) -> void:
		site = s
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var n := 0
		for slot_id: String in state.graph.slots_of_site(site):
			var owner: String = state.troops.get(slot_id, "")
			if owner != "" and owner != "white" and state.is_enemy(player_id, owner):
				n += 1
				break
		if CelestialCards.site_is_full(state, site):
			n += 1
		for owner: String in state.spies.get(site, []):
			if state.is_enemy(player_id, owner):
				n += 1
				break
		if n > 0:
			resolver.push(GainInfluence.new(n), player_id)


## "If you have 4 or more player troops in your trophy hall, +1 Power. 8 or more: +1 Power".
class _TrophyPower extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var t: int = state.stock(player_id).player_trophy_count()
		var n := (1 if t >= 4 else 0) + (1 if t >= 8 else 0)
		if n > 0:
			resolver.push(GainPower.new(n), player_id)


## Weretiger: в этой локации игрок до конца хода войска не ставит.
class _BlockDeploy extends CardEffect:
	var site: String
	func _init(s: String) -> void:
		site = s
	func apply(state: GameState, player_id: String, _resolver: EffectResolver) -> void:
		var blocked: Dictionary = state.turn_flags.get("no_deploy", {})
		blocked[site] = player_id
		state.turn_flags["no_deploy"] = blocked


## Azer Sentinel: в конце хода 1 VP за каждое войско, убитое или вытесненное в этот ход.
class _VpPerKill extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var n: int = state.stock(player_id).trophy_hall_count - int(state.turn_flags.get("trophy_start", 0))
		if n > 0:
			resolver.push(GainVP.new(n), player_id)


## Horned Devil: сожрать верхнюю половину колоды рынка (с округлением вверх).
## Колода рынка уже пуста — игрок побеждает (партия кончается после его хода).
class _DevourHalfMarket extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if state.market.deck.is_empty():
			GameEnd.trigger(state, "market_empty")
			state.instant_winner = player_id
			state.final_round_ends_after_index = state.current_player_index
			resolver.log_event("instant_win", {"player_id": player_id})
			return
		var n := ceili(state.market.deck.size() / 2.0)
		for i in range(n):
			var cid: String = state.market.deck.pop_back()
			state.devoured_pile.append(cid)
			resolver.log_event("devour", {"player_id": player_id, "card_id": cid, "source": "market_deck"})
		if player_id == state.current_player():
			state.turn_flags["devours"] = NoxusCards.devours(state) + n
		if state.market.is_deck_empty():
			GameEnd.trigger(state, "market_empty")


## Horned Devil: разыграть до N карт из стопки сожранных; они остаются вне игры.
class _PlayFromDevoured extends CardEffect:
	var remaining: int
	func _init(n: int) -> void:
		remaining = n
	func _options(state: GameState) -> Array:
		var out: Array = []
		for cid: String in state.devoured_pile:
			if not out.has(cid) and CardLibrary.card_cost(cid) >= 0:
				out.append(cid)
		return out
	func is_available(state: GameState, _player_id: String) -> bool:
		return not _options(state).is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var chosen = answer()
			_answered = false
			_answer = null
			if chosen == null or String(chosen) == "":
				return
			var idx := state.devoured_pile.rfind(String(chosen))
			if idx == -1:
				return
			state.devoured_pile.remove_at(idx)
			remaining -= 1
			resolver.log_event("play_from_devoured", {"player_id": player_id, "card_id": chosen})
			if remaining > 0:
				resolver.push(self, player_id)
			resolver.push(CardLibrary.get_effect(String(chosen)), player_id, String(chosen))
			return
		var options := _options(state)
		if remaining <= 0 or options.is_empty():
			return
		options.append("")
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Play a card from the devoured pile (it stays out of the game)"
		pd.choice_type = "target_card"
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)


## Fire Giant (Darius): "Devour a card in your hand to assassinate a troop and
## draw a card. 15+ troops on the board: repeat any number of times. 30+:
## devour from your discard pile too, supplant instead of assassinate".
class _GiantStrike extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var on_board := 0
		for owner: String in state.troops.values():
			if owner == player_id:
				on_board += 1
		var zones := ["hand", "discard"] if on_board >= 30 else ["hand"]
		var repeat := on_board >= 15
		resolver.push(_Devour.new(zones, true, func(_cid):
			var hit: CardEffect = SupplantTroop.new(1) if on_board >= 30 else AssassinateTroop.new(1)
			var steps: Array[CardEffect] = [hit, DrawCards.new(1)]
			if repeat:
				steps.append(NoxusCards._GiantStrike.new())
			return SequenceEffect.new(steps)), player_id)


## Half-Dragon (Riven): взять Blade Fragment из запаса (их 3 на игру).
class _GainFragment extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if not state.supplies.take(NoxusCards.BLADE_FRAGMENT):
			return
		state.players[player_id].deck.discard_pile.append(NoxusCards.BLADE_FRAGMENT)
		FreljordCards.note_gain(state, player_id)
		resolver.log_event("gain_card", {"player_id": player_id, "card_id": NoxusCards.BLADE_FRAGMENT})


## Half-Dragon: сыграны все 3 Blade Fragment и Half-Dragon в один ход —
## осколки уходят из игры, в сброс приходит Blade of Exile.
class _Reforge extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		if not d.played_pile.has(NoxusCards.HALF_DRAGON) or d.played_pile.count(NoxusCards.BLADE_FRAGMENT) < NoxusCards.FRAGMENT_SUPPLY:
			return
		for i in range(NoxusCards.FRAGMENT_SUPPLY):
			d.played_pile.remove_at(d.played_pile.find(NoxusCards.BLADE_FRAGMENT))
		d.discard_pile.append(NoxusCards.BLADE_OF_EXILE)
		resolver.log_event("transform", {"player_id": player_id, "from": NoxusCards.BLADE_FRAGMENT, "to": NoxusCards.BLADE_OF_EXILE})


## Blade Fragment: из 5 верхних карт — осколки и Half-Dragon в руку, остальное в сброс.
class _FetchBlade extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		if d.draw_pile.size() < 5 and not d.discard_pile.is_empty():
			var refill := d.discard_pile.duplicate()
			d.discard_pile.clear()
			Deck.shuffle_array(refill, state.rng)
			refill.append_array(d.draw_pile)
			d.draw_pile = refill
		var taken := 0
		for i in range(mini(5, d.draw_pile.size())):
			var cid: String = d.draw_pile.pop_back()
			if cid == NoxusCards.BLADE_FRAGMENT or cid == NoxusCards.HALF_DRAGON:
				d.hand.append(cid)
				taken += 1
			else:
				d.discard_pile.append(cid)
		resolver.log_event("fetch_blade", {"player_id": player_id, "count": taken})


## Lamia (Leblanc): "Choose another player. Look at the top 5 cards of their
## deck and separate them into a face-up and a face-down pile. They choose a
## pile to put back on top of their deck. You play the other cards for free".
## Сыгранные чужие карты потом уходят в сброс хозяина.
class _Lamia extends CardEffect:
	var owner := ""
	var victim := ""
	var cards: Array[String] = []
	var face_up: Array[String] = []
	var stage := 0  # 0 — выбор соперника, 1 — делим, 2 — соперник выбирает стопку
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if owner == "":
			owner = player_id
		if stage == 0:
			var opps: Array[String] = []
			for o: String in ShadowCards._opponents_clockwise(state, owner):
				var od: Deck = state.players[o].deck
				if not (od.draw_pile.is_empty() and od.discard_pile.is_empty()):
					opps.append(o)
			if opps.is_empty():
				return
			if opps.size() > 1 and not is_answered():
				var pd0 := PendingDecision.new()
				pd0.player_id = owner
				pd0.prompt = "Choose an opponent: you look at the top 5 cards of their deck"
				pd0.choice_type = "target_player"
				pd0.legal_options = opps
				pd0.target_effect = self
				resolver.request_decision(pd0)
				return
			victim = String(answer()) if is_answered() else opps[0]
			_answered = false
			_answer = null
			var d: Deck = state.players[victim].deck
			if d.draw_pile.size() < 5 and not d.discard_pile.is_empty():
				var refill := d.discard_pile.duplicate()
				d.discard_pile.clear()
				Deck.shuffle_array(refill, state.rng)
				refill.append_array(d.draw_pile)
				d.draw_pile = refill
			for i in range(mini(5, d.draw_pile.size())):
				cards.append(d.draw_pile.pop_back())
			resolver.log_event("shadow_split", {"player_id": owner, "opponent": victim, "count": cards.size()})
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
				pd1.player_id = owner
				pd1.prompt = "Pick cards for the face-up pile (the rest stay face down), then stop"
				pd1.choice_type = "target_card"
				pd1.source_card = "49514"
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
			pd2.player_id = victim
			pd2.prompt = "Lamia: put one pile back on top of your deck, the opponent plays the other"
			pd2.choice_type = "choose_option"
			pd2.source_card = "49514"
			pd2.legal_options = [0, 1]
			pd2.option_labels = ["Keep the face-up pile: " + (", ".join(names) if not names.is_empty() else "empty"),
				"Keep the face-down pile (%d cards)" % cards.size()]
			pd2.target_effect = self
			resolver.request_decision(pd2)
			return
		var keep_up := int(answer()) == 0
		var kept: Array[String] = face_up if keep_up else cards
		var played: Array[String] = cards if keep_up else face_up
		var d2: Deck = state.players[victim].deck
		for i in range(kept.size() - 1, -1, -1):
			d2.draw_pile.append(kept[i])
		resolver.log_event("shadow_keep", {"player_id": victim, "face_up": keep_up, "kept": kept.size()})
		d2.discard_pile.append_array(played)
		for i in range(played.size() - 1, -1, -1):
			resolver.push(CardLibrary.get_effect(played[i]), owner, played[i])
