class_name IxtalCards
extends RefCounted

## Полуколода Ixtal (New Era) — способности карт Ixtal из фан-мода Runeterra
## Reforged на существах CHULT: люди-ящеры, юань-ти, ааракокры, Sarrukh Tyrant
## (без зверей и динозавров — у особенных динозавров нет арта со сценой,
## владелец 2026-10-18). Таблица id -> существо -> карта мода —
## Claude outputs/new_era_ixtal.md. Nidalee владелец велел не делать (50109 свободен).
##
## Перевод на правила этой игры: Valor -> MALICE.
##
## Explore (правило мода): "Look at the top 2 cards of your deck. Reveal up to one
## card that matches terms that you're searching for. Put the rest of the cards
## onto the top or bottom of your deck in any order." Открытая карта идёт в руку
## (так читает Milio: "put all cards matching ... into your hand").
##
## Счётчики хода — state.turn_flags (сбрасываются в start_turn):
##   "milio"     — Chwinga: Explore берёт в руку все подходящие карты;
##   "ezreal"    — Knight of Eldraine: Explore смотрит 4 карты;
##   "landing"   — Aarakocra Aeromancer: после каждого Explore — столько войск;
##   "rengar"    — Troglodyte: верхняя карта колоды открыта, с Power — можно в руку;
##   "skarner"   — Lizardfolk Sovereign: маркеры контроля считаются тотальным контролем;
##   "zyra"      — Lizardfolk Geomancer: войска можно ставить за Influence, 7-е войско — карта;
##   "aspect_discount" — Minotaur Archaeologist: {аспект: скидка} карт рынка;
##   "spy_done", "promoted" — цели Dao (шпион поставлен/возвращён, карта продвинута).
##
## Войска на картах рынка (Performer Maestro): state.market_troops —
## "индекс" -> {"card": id, "troops": {игрок: число}}. Карта ушла из слота —
## войска возвращаются в бараки (sync_market_troops).

const NEEKO := "50100"  # Yuan-ti Infiltrator
const MALPHITE := "50101"  # Galeb Duhr
const ZILEAN := "50102"  # Sarrukh Tyrant
const SKARNER := "50103"  # Lizardfolk Sovereign
const MILIO := "50104"  # Chwinga
const RENGAR := "50105"  # Troglodyte
const ZYRA := "50106"  # Lizardfolk Geomancer
const QIYANA := "50107"  # Dao
const EZREAL := "50108"  # Knight of Eldraine
const SEEKER := "50110"  # Bandit Deceiver (Treasure Seeker)
const TROOPER := "50111"  # Lizardfolk Warden (All Terrain Trooper)
const VASTAYA := "50112"  # Yuan-ti Abomination (Avenging Vastaya)
const TYCOON := "50113"  # Performer Maestro (Big Game Tycoon)
const ARCHAEOLOGIST := "50114"  # Minotaur Archaeologist (Intrepid Archaeologist)
const SKY_SQUAD := "50115"  # Living Gust of Wind (Sky Squad)
const ECOLOGIST := "50116"  # Bullywug Bog Sage (Curious Ecologist)
const MONK := "50117"  # Cyclops Oracle (Axiomata Monk)
const KEEPER := "50118"  # Kenku (Secret Keeper)
const LANDING := "50119"  # Aarakocra Aeromancer (Landing Party)
const INITIATE := "50120"  # Bone Naga (Yun Tal Initiate)

const EXPLORE_LOOK := 2
const EZREAL_LOOK := 4
const ZYRA_DRAW_AT := 7


static func build(card_id: String) -> CardEffect:
	match card_id:
		NEEKO:
			return _choose(NEEKO, [_CopyPrevious.new(NEEKO), _CopyMarket.new()],
				["Copy the previous card you played", "Copy a market card"])
		MALPHITE:
			return GainPower.new(8)
		ZILEAN:
			return SequenceEffect.new([DrawCards.new(5), _FullExtraTurn.new(),
				AtEndOfTurn.new(PromoteCard.new("this", ZILEAN))])
		SKARNER:
			return SequenceEffect.new([SupplantTroop.new(1), ShadowCards._SetFlag.new("skarner"), _MarkerAgain.new()])
		MILIO:
			return SequenceEffect.new([GainInfluence.new(4), ShadowCards._SetFlag.new("milio")])
		RENGAR:
			return SequenceEffect.new([ShadowCards._SetFlag.new("rengar"), _RengarTop.new(),
				explore(RENGAR, "a card that gives Power", func(cid): return IxtalCards.gives_power(cid)),
				AssassinateTroop.new(1)])
		ZYRA:
			return SequenceEffect.new([ReturnTroopOrSpy.new(3, true), ShadowCards._SetFlag.new("zyra"), _ZyraCheck.new()])
		QIYANA:
			return VoidCards._PerCount.new(func(s, p): return IxtalCards.objectives(s, p), 1,
				func(n): return AssassinateTroop.new(n))
		EZREAL:
			return SequenceEffect.new([AssassinateTroop.new(2, false, true, true),
				ShadowCards._SetFlag.new("ezreal"), _NameRegion.new()])
		SEEKER:
			return SequenceEffect.new([GainInfluence.new(2), _choose(SEEKER, [
				explore(SEEKER, "a card that costs 3 or less", func(cid): return IxtalCards._cost_in(cid, 0, 3)),
				explore(SEEKER, "a card that costs 6 or more", func(cid): return IxtalCards._cost_in(cid, 6, 99)),
			], ["Explore for a card that costs 3 or less", "Explore for a card that costs 6 or more"])])
		TROOPER:
			return _choose(TROOPER, [_DeployNearPlayer.new(), SupplantTroop.new(1, true)],
				["Deploy 3 troops (next to another player's troop: Explore for \"Deploy\")", "Supplant a white troop"])
		VASTAYA:
			return SequenceEffect.new([
				_choose(VASTAYA, [
					explore(VASTAYA, "an odd cost card", func(cid): return IxtalCards._cost_parity(cid, 1)),
					explore(VASTAYA, "an even cost card", func(cid): return IxtalCards._cost_parity(cid, 0)),
				], ["Explore for an odd cost card", "Explore for an even cost card"]),
				_choose(VASTAYA, [DeployTroop.new(2), AssassinateTroop.new(1, true)],
					["Deploy 2 troops", "Assassinate a white troop"])])
		TYCOON:
			return SequenceEffect.new([GainInfluence.new(2), _TroopOnMarket.new()])
		ARCHAEOLOGIST:
			return SequenceEffect.new([GainInfluence.new(2), _RevealDiscount.new()])
		SKY_SQUAD:
			return MoveTroop.new(1)
		ECOLOGIST:
			return SequenceEffect.new([GainInfluence.new(1), _Peek.new(ECOLOGIST, "promote", "", Callable())])
		MONK:
			return _choose(MONK, [GainPower.new(2),
				_TopFromHand.new(MONK, SequenceEffect.new([SupplantTroop.new(1), DeployTroop.new(1)])),
				SequenceEffect.new([OptionalEffect.new(_ShuffleDiscard.new(), "Shuffle your discard pile into your deck?"),
					ScryCards.new(3)]),
			], ["+2 Power", "Put a card from your hand on top of your deck: supplant a troop and deploy a troop",
				"You may shuffle your discard pile into your deck, then Scry 3"])
		KEEPER:
			return _choose(KEEPER, [
				PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
					func(state, _pid): return ShurimaCards._site_full(state, site),
					SequenceEffect.new([GainPower.new(1), GainInfluence.new(1)]))),
				ReturnOwnSpy.new(SequenceEffect.new([DrawCards.new(2), _TopFromHand.new(KEEPER, null)])),
			], ["Place a spy (site full: +1 Power and +1 Influence)",
				"Return one of your spies, draw 2 cards, put a card from your hand on top of your deck"])
		LANDING:
			return SequenceEffect.new([ShadowCards._AddFlag.new("landing"),
				_choose(LANDING, [DeployTroop.new(3), SupplantTroop.new(1, true)], ["Deploy 3 troops", "Supplant a white troop"]),
				ConditionalEffect.new(func(state, _pid): return VoidCards.deploys(state) >= 4, ScryCards.new(2))])
		INITIATE:
			return _PreviousAspect.new()
	return null


static func _choose(card_id: String, opts: Array[CardEffect], labels: Array[String]) -> ChooseEffect:
	var c := ChooseEffect.new(opts, labels)
	c.source_card = card_id
	return c


## Explore for <what>: fn(card_id) -> подходит ли карта.
static func explore(source: String, what: String, fn: Callable) -> CardEffect:
	return _Peek.new(source, "explore", what, fn)


static func gives_power(card_id: String) -> bool:
	return String(CardLibrary.card_data(card_id).get("ability_text", "")).contains("Power")


static func _cost_in(card_id: String, lo: int, hi: int) -> bool:
	var cost := CardLibrary.card_cost(card_id)
	return cost >= lo and cost <= hi


static func _cost_parity(card_id: String, parity: int) -> bool:
	var cost := CardLibrary.card_cost(card_id)
	return cost >= 0 and cost % 2 == parity


static func _has_word(card_id: String, word: String) -> bool:
	return String(CardLibrary.card_data(card_id).get("ability_text", "")).to_lower().contains(word.to_lower())


## Пустая колода перед просмотром верха замешивается из сброса, как при доборе.
static func refill(state: GameState, d: Deck) -> void:
	if d.draw_pile.is_empty() and not d.discard_pile.is_empty():
		d.draw_pile = d.discard_pile.duplicate()
		d.discard_pile.clear()
		d.shuffle_draw_pile(state.rng)


## Предыдущая сыгранная в этот ход карта перед последним розыгрышем card_id.
static func previous_played(state: GameState, player_id: String, card_id: String) -> String:
	var pile: Array[String] = state.players[player_id].deck.played_pile
	var idx := pile.rfind(card_id)
	if idx <= 0:
		return ""
	return pile[idx - 1]


# --- Dao (Qiyana): цели хода --------------------------------------------------------

static func objectives(state: GameState, player_id: String) -> int:
	var n := 0
	if state.stock(player_id).trophy_hall_count > int(state.turn_flags.get("trophy_start", 0)):
		n += 1
	if VoidCards.deploys(state) >= 3:
		n += 1
	if state.turn_flags.get("spy_done", false):
		n += 1
	if (state.turn_flags.get("gained", {}) as Dictionary).has(player_id) or state.turn_flags.get("promoted", false):
		n += 1
	return n


## Шпион поставлен или свой возвращён (PlaceSpy, ReturnOwnSpy).
static func note_spy(state: GameState) -> void:
	state.turn_flags["spy_done"] = true


## Карту продвинули во Внутренний круг (ShurimaCards.on_promote — любой путь promote).
static func note_promote(state: GameState) -> void:
	state.turn_flags["promoted"] = true


# --- Lizardfolk Sovereign (Skarner): маркеры контроля --------------------------------

## Маркеры игрока в этот ход считаются тотальным контролем (ControlMarkers.evaluate).
static func markers_total(state: GameState, player_id: String) -> bool:
	return player_id == state.current_player() and state.turn_flags.get("skarner", false)


# --- Lizardfolk Geomancer (Zyra): войска за Influence ------------------------------

## Базовое действие Deploy можно оплатить 1 Influence (Actions.deploy, StateView).
static func deploy_by_influence(state: GameState, player_id: String) -> bool:
	return player_id == state.current_player() and state.turn_flags.get("zyra", false) \
		and state.players[player_id].influence >= 1


## Войско встало на доску (VoidCards.note_deploy): 7-е за ход при Zyra — карта.
static func on_deploy_count(state: GameState) -> void:
	if not state.turn_flags.get("zyra", false) or state.turn_flags.get("zyra_drawn", false):
		return
	if VoidCards.deploys(state) < ZYRA_DRAW_AT:
		return
	state.turn_flags["zyra_drawn"] = true
	state.players[state.current_player()].deck.draw_one(state.rng)


# --- Performer Maestro (Big Game Tycoon): войска на картах рынка ----------------------

static func market_troops_at(state: GameState, index: int) -> Dictionary:
	var entry: Dictionary = state.market_troops.get(str(index), {})
	return entry.get("troops", {})


## Цена карты рынка для текущего игрока: свои войска на ней — дешевле, чужие —
## дороже; скидка аспекта Minotaur Archaeologist. -1 (купить нельзя) не трогаем.
static func market_cost(state: GameState, index: int, cost: int) -> int:
	if cost < 0:
		return cost
	var buyer := state.current_player()
	var troops := market_troops_at(state, index)
	for pid: String in troops.keys():
		if pid == buyer or not state.is_enemy(buyer, pid):
			cost -= int(troops[pid])
		else:
			cost += int(troops[pid])
	var cid := String(state.market.display[index]) if index >= 0 and index < state.market.display.size() else ""
	var aspect := CardLibrary.card_aspect(cid) if cid != "" else ""
	if aspect != "" and aspect != "OBEDIENCE":
		cost -= int((state.turn_flags.get("aspect_discount", {}) as Dictionary).get(aspect, 0))
	return maxi(0, cost)


## Карта ушла из слота (куплена, сожрана, под низ колоды) — войска с неё хозяевам.
static func sync_market_troops(state: GameState) -> void:
	for key: String in state.market_troops.keys():
		var i := key.to_int()
		var entry: Dictionary = state.market_troops[key]
		if i < state.market.display.size() and String(state.market.display[i]) == String(entry.get("card", "")):
			continue
		var troops: Dictionary = entry.get("troops", {})
		for pid: String in troops.keys():
			if state.players.has(pid):
				state.stock(pid).troops_in_barracks += int(troops[pid])
		state.market_troops.erase(key)


# --- Классы эффектов -------------------------------------------------------------

## Explore / Bullywug Bog Sage: посмотреть верх колоды, одну карту взять
## (mode "explore" — подходящую в руку, "promote" — любую во Внутренний круг),
## остальные — под низ или наверх в выбранном порядке.
## Living Gust of Wind среди просмотренных можно взять в руку сверх того.
class _Peek extends CardEffect:
	var src: String
	var mode: String
	var what: String
	var match_fn: Callable
	var _shown: Array[String] = []
	var _stage := 0  # 0 — не начат, 1 — взять карту, 2 — под низ, 3 — порядок сверху
	var _taken := false
	var _top: Array[String] = []  # порядок наверху: первая — самая верхняя
	func _init(s: String, m: String, w: String, fn: Callable) -> void:
		src = s
		mode = m
		what = w
		match_fn = fn
	func _matches(cid: String) -> bool:
		return mode == "promote" or match_fn.call(cid)
	func _pickable() -> Array:
		var out: Array = []
		for cid: String in _shown:
			if out.has(cid):
				continue
			if (not _taken and _matches(cid)) or (mode == "explore" and cid == IxtalCards.SKY_SQUAD):
				out.append(cid)
		return out
	func _unique(cards: Array[String]) -> Array:
		var out: Array = []
		for cid: String in cards:
			if not out.has(cid):
				out.append(cid)
		return out
	func _ask(player_id: String, prompt: String, options: Array, resolver: EffectResolver) -> void:
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = prompt
		pd.choice_type = "target_card"
		pd.legal_options = options
		pd.source_card = src
		pd.target_effect = self
		resolver.request_decision(pd)
	func _take(state: GameState, player_id: String, cid: String, resolver: EffectResolver) -> void:
		_shown.remove_at(_shown.find(cid))
		# Living Gust of Wind сверх подходящей карты выбор не тратит.
		var sky_extra := mode == "explore" and cid == IxtalCards.SKY_SQUAD and (_taken or not _matches(cid))
		if not sky_extra:
			_taken = true
		if mode == "promote":
			state.stock(player_id).deck.inner_circle.append(cid)
			resolver.log_event("promote", {"player_id": player_id, "card_id": cid, "from": "top_of_deck"})
			ShurimaCards.on_promote(state, player_id, cid, resolver)
			return
		state.players[player_id].deck.hand.append(cid)
		resolver.log_event("explore_take", {"player_id": player_id, "card_id": cid})
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		if _stage == 0:
			_stage = 1
			IxtalCards.refill(state, d)
			var n := IxtalCards.EXPLORE_LOOK
			if mode == "explore" and state.turn_flags.get("ezreal", false):
				n = IxtalCards.EZREAL_LOOK
			for i in range(mini(n, d.draw_pile.size())):
				_shown.append(d.draw_pile.pop_back())
			if mode == "explore":
				resolver.log_event("explore", {"player_id": player_id, "looked": _shown.size(), "what": what})
				if state.turn_flags.get("milio", false):
					for cid: String in _shown.duplicate():
						if match_fn.call(cid) or cid == IxtalCards.SKY_SQUAD:
							_shown.remove_at(_shown.find(cid))
							d.hand.append(cid)
							resolver.log_event("explore_take", {"player_id": player_id, "card_id": cid})
					_taken = true
		elif is_answered():
			var chosen := String(answer()) if answer() != null else ""
			_answered = false
			_answer = null
			match _stage:
				1:
					if chosen == "" or not _pickable().has(chosen):
						_stage = 2
					else:
						_take(state, player_id, chosen, resolver)
				2:
					if chosen == "" or not _shown.has(chosen):
						_stage = 3
					else:
						_shown.remove_at(_shown.find(chosen))
						d.draw_pile.insert(0, chosen)  # низ колоды — начало массива
				3:
					if _shown.has(chosen):
						_shown.remove_at(_shown.find(chosen))
						_top.append(chosen)
		if _stage == 1:
			var options := _pickable()
			if not options.is_empty():
				options.append("")
				var verb := "Promote one of these cards" if mode == "promote" else "Explore for %s: put a card into your hand" % what
				_ask(player_id, verb, options, resolver)
				return
			_stage = 2
		if _stage == 2:
			if not _shown.is_empty():
				var options := _unique(_shown)
				options.append("")
				_ask(player_id, "Put a card on the bottom of your deck (or keep the rest on top)", options, resolver)
				return
			_stage = 3
		if _stage == 3 and _unique(_shown).size() >= 2:
			_ask(player_id, "Which card goes on top of your deck now?", _unique(_shown), resolver)
			return
		# Порядок сверху: _top[0] — самая верхняя, остальные под ней.
		_top.append_array(_shown)
		_shown.clear()
		for i in range(_top.size() - 1, -1, -1):
			d.draw_pile.append(_top[i])
		_top.clear()
		_stage = 4
		if mode != "explore":
			return
		var landing := int(state.turn_flags.get("landing", 0))
		if landing > 0:
			resolver.push(DeployTroop.new(landing), player_id)
		if state.turn_flags.get("rengar", false):
			resolver.push(IxtalCards._RengarTop.new(), player_id)


## Troglodyte (Rengar): верхняя карта колоды открыта весь ход; если она даёт Power
## (или это Living Gust of Wind) — можно взять её в руку. Проверка — после
## розыгрыша Troglodyte, после каждого Explore и каждой следующей карты (on_play).
class _RengarTop extends CardEffect:
	var _top := ""
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		if is_answered():
			var chosen := String(answer()) if answer() != null else ""
			_answered = false
			_answer = null
			if chosen == "" or d.draw_pile.is_empty() or d.draw_pile.back() != _top:
				return
			d.draw_pile.pop_back()
			d.hand.append(_top)
			resolver.log_event("explore_take", {"player_id": player_id, "card_id": _top})
		if d.draw_pile.is_empty():
			return
		_top = d.draw_pile.back()
		var seen := String(state.turn_flags.get("rengar_seen", ""))
		var key := "%s#%d" % [_top, d.draw_pile.size()]
		if seen != key:
			state.turn_flags["rengar_seen"] = key
			resolver.log_event("reveal_top", {"player_id": player_id, "card_id": _top})
		if not IxtalCards.gives_power(_top) and _top != IxtalCards.SKY_SQUAD:
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Put the revealed top card into your hand?"
		pd.choice_type = "target_card"
		pd.legal_options = [_top, ""]
		pd.source_card = IxtalCards.RENGAR
		pd.target_effect = self
		resolver.request_decision(pd)


## Сыграна карта (TurnEngine.begin_play): при Troglodyte после неё — проверка верха.
static func on_play(state: GameState, _player_id: String, _card_id: String, effect: CardEffect) -> CardEffect:
	if effect == null or not state.turn_flags.get("rengar", false):
		return effect
	var all: Array[CardEffect] = [effect, _RengarTop.new()]
	return SequenceEffect.new(all)


## Yuan-ti Infiltrator (Neeko), вариант 1: копия предыдущей сыгранной карты.
class _CopyPrevious extends CardEffect:
	var self_id: String
	func _init(cid: String) -> void:
		self_id = cid
	func is_available(state: GameState, player_id: String) -> bool:
		return IxtalCards.previous_played(state, player_id, self_id) != ""
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var prev := IxtalCards.previous_played(state, player_id, self_id)
		if prev == "":
			return
		resolver.log_event("copy_card", {"player_id": player_id, "card_id": prev})
		resolver.push(CardLibrary.get_effect(prev), player_id, prev)


## Yuan-ti Infiltrator (Neeko), вариант 2: копия карты рынка; в конце хода эта
## карта уходит под низ колоды рынка (если ещё лежит в рынке).
class _CopyMarket extends CardEffect:
	func _options(state: GameState) -> Array:
		var out: Array = []
		for i in range(state.market.display.size()):
			if String(state.market.display[i]) != "":
				out.append(i)
		return out
	func is_available(state: GameState, _player_id: String) -> bool:
		return not _options(state).is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var index = answer()
			if index == null or not _options(state).has(int(index)):
				return
			var cid := String(state.market.display[int(index)])
			resolver.log_event("copy_card", {"player_id": player_id, "card_id": cid})
			resolver.push(AtEndOfTurn.new(IxtalCards._MarketToBottom.new(cid)), player_id)
			resolver.push(CardLibrary.get_effect(cid), player_id, cid)
			return
		var options := _options(state)
		if options.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Copy a card in the market"
		pd.choice_type = "target_market_index"
		pd.tag = "market"
		pd.legal_options = options
		pd.source_card = IxtalCards.NEEKO
		pd.target_effect = self
		resolver.request_decision(pd)


class _MarketToBottom extends CardEffect:
	var card: String
	func _init(c: String) -> void:
		card = c
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var i := state.market.display.find(card)
		if i == -1:
			return
		state.market.deck.insert(0, card)
		state.market.recruit_at(i)
		VoidCards.sync_market_spies(state)
		resolver.log_event("market_discard", {"player_id": player_id, "card_id": card, "market_index": i})


## Sarrukh Tyrant (Zilean): полный лишний ход (без лимита карт Basilisk).
class _FullExtraTurn extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if player_id != state.current_player():
			return
		state.extra_turn_for = player_id
		state.extra_turn_full = true
		resolver.log_event("extra_turn", {"player_id": player_id, "cards": 0})


## Lizardfolk Sovereign (Skarner): "activate 1 of them an additional time" —
## лучший свой маркер (уже как тотальный контроль) даёт награду ещё раз сейчас.
class _MarkerAgain extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var best := {}
		var best_site := ""
		for site_id: String in ControlMarkers.marked_sites(state):
			if not ControlMarkers.holds(state, player_id, site_id):
				continue
			var m := ControlMarkers.marker_for(state, site_id)
			var value := int(m.get("control_influence", 0)) + int(m.get("total_control_vp", 0))
			if best.is_empty() or value > int(best.get("control_influence", 0)) + int(best.get("total_control_vp", 0)):
				best = m
				best_site = site_id
		if best.is_empty():
			return
		var p: PlayerState = state.players[player_id]
		p.influence += int(best.get("control_influence", 0))
		var vp := state.vp_bank.grant(int(best.get("total_control_vp", 0)))
		p.vp_tokens += vp
		resolver.log_event("marker_again", {"player_id": player_id, "site_id": best_site,
			"influence": int(best.get("control_influence", 0)), "vp": vp})


## Lizardfolk Geomancer: уже поставлено 7+ войск в этот ход — карта сразу.
class _ZyraCheck extends CardEffect:
	func apply(state: GameState, _player_id: String, _resolver: EffectResolver) -> void:
		IxtalCards.on_deploy_count(state)


## Knight of Eldraine (Ezreal): "Name a region. Explore for a card from that region".
## Регионы — типы карт рынка и своей колоды (CHULT, FAR REALM, DROW...).
class _NameRegion extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var regions: Array[String] = []
		var d: Deck = state.players[player_id].deck
		var pools: Array = [state.market.deck, state.market.display, d.draw_pile, d.discard_pile, d.hand, d.played_pile]
		for pool: Array in pools:
			for cid in pool:
				var t := CardLibrary.card_type(String(cid)) if String(cid) != "" else ""
				if t != "" and not regions.has(t):
					regions.append(t)
		regions.sort()
		if regions.is_empty():
			return
		var opts: Array[CardEffect] = []
		var labels: Array[String] = []
		for t: String in regions:
			var region := t
			opts.append(IxtalCards.explore(IxtalCards.EZREAL, "a %s card" % region,
				func(cid): return CardLibrary.card_type(cid) == region))
			labels.append(region)
		var c := ChooseEffect.new(opts, labels, "Name a region")
		c.source_card = ""
		resolver.push(c, player_id)


## Lizardfolk Warden (All Terrain Trooper): 3 войска; хоть одно рядом с войском
## другого игрока — Explore for a card with "Deploy".
class _DeployNearPlayer extends CardEffect:
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
					r.push(IxtalCards.explore(IxtalCards.TROOPER, "a card with \"Deploy\"",
						func(cid): return IxtalCards._has_word(cid, "deploy")), pid)
					return), player_id)
		resolver.push(DeployTroop.new(3), player_id)


## Performer Maestro (Big Game Tycoon): войско из барака на карту рынка.
class _TroopOnMarket extends CardEffect:
	func _options(state: GameState) -> Array:
		var out: Array = []
		for i in range(state.market.display.size()):
			if String(state.market.display[i]) != "":
				out.append(i)
		return out
	func is_available(state: GameState, player_id: String) -> bool:
		return state.stock(player_id).troops_in_barracks > 0 and not _options(state).is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if not is_available(state, player_id):
			return
		if is_answered():
			var index = answer()
			if index == null or not _options(state).has(int(index)):
				return
			var i := int(index)
			var cid := String(state.market.display[i])
			var key := str(i)
			var entry: Dictionary = state.market_troops.get(key, {})
			if String(entry.get("card", "")) != cid:
				entry = {"card": cid, "troops": {}}
			var troops: Dictionary = entry["troops"]
			troops[player_id] = int(troops.get(player_id, 0)) + 1
			state.market_troops[key] = entry
			state.stock(player_id).troops_in_barracks -= 1
			resolver.log_event("market_troop", {"player_id": player_id, "card_id": cid, "market_index": i})
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Put a troop on a card in the market"
		pd.choice_type = "target_market_index"
		pd.tag = "market"
		pd.legal_options = _options(state)
		pd.source_card = IxtalCards.TYCOON
		pd.target_effect = self
		resolver.request_decision(pd)


## Minotaur Archaeologist: открыть верхнюю карту колоды; в этот ход карты рынка
## (не Obedience) с тем же аспектом на 1 дешевле. Living Gust of Wind — можно в руку.
class _RevealDiscount extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		IxtalCards.refill(state, d)
		if d.draw_pile.is_empty():
			return
		var top: String = d.draw_pile.back()
		resolver.log_event("reveal_top", {"player_id": player_id, "card_id": top})
		var aspect := CardLibrary.card_aspect(top)
		if aspect != "" and aspect != "OBEDIENCE":
			var disc: Dictionary = (state.turn_flags.get("aspect_discount", {}) as Dictionary).duplicate()
			disc[aspect] = int(disc.get(aspect, 0)) + 1
			state.turn_flags["aspect_discount"] = disc
		if top == IxtalCards.SKY_SQUAD:
			resolver.push(IxtalCards._SkySquadToHand.new(), player_id)


## Living Gust of Wind открыт сверху колоды эффектом карты — можно взять в руку.
class _SkySquadToHand extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		if d.draw_pile.is_empty() or d.draw_pile.back() != IxtalCards.SKY_SQUAD:
			return
		if is_answered():
			if String(answer()) == IxtalCards.SKY_SQUAD:
				d.draw_pile.pop_back()
				d.hand.append(IxtalCards.SKY_SQUAD)
				resolver.log_event("explore_take", {"player_id": player_id, "card_id": IxtalCards.SKY_SQUAD})
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Put the revealed Living Gust of Wind into your hand?"
		pd.choice_type = "target_card"
		pd.legal_options = [IxtalCards.SKY_SQUAD, ""]
		pd.source_card = IxtalCards.SKY_SQUAD
		pd.target_effect = self
		resolver.request_decision(pd)


## Cyclops Oracle / Kenku: карта из руки наверх колоды (then — эффект после этого).
class _TopFromHand extends CardEffect:
	var src: String
	var then_effect: CardEffect
	func _init(s: String, e: CardEffect) -> void:
		src = s
		then_effect = e
	func is_available(state: GameState, player_id: String) -> bool:
		return then_effect == null or not state.players[player_id].deck.hand.is_empty()
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		if is_answered():
			var cid := String(answer()) if answer() != null else ""
			if not d.hand.has(cid):
				return
			d.hand.remove_at(d.hand.find(cid))
			d.draw_pile.append(cid)  # верх колоды — конец массива
			resolver.log_event("card_on_top", {"player_id": player_id, "card_id": cid})
			if then_effect != null:
				resolver.push(then_effect, player_id)
			return
		if d.hand.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Put a card from your hand on top of your deck"
		pd.choice_type = "target_card"
		pd.tag = "hand"
		pd.legal_options = d.hand.duplicate()
		pd.source_card = src
		pd.target_effect = self
		resolver.request_decision(pd)


## Cyclops Oracle: "You may shuffle your discard pile into your deck".
class _ShuffleDiscard extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var d: Deck = state.players[player_id].deck
		if d.discard_pile.is_empty():
			return
		d.draw_pile.append_array(d.discard_pile)
		d.discard_pile.clear()
		d.shuffle_draw_pile(state.rng)
		resolver.log_event("shuffle_discard", {"player_id": player_id})


## Bone Naga (Yun Tal Initiate): эффект по аспекту предыдущей сыгранной карты.
class _PreviousAspect extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var prev := IxtalCards.previous_played(state, player_id, IxtalCards.INITIATE)
		if prev == "":
			return
		match CardLibrary.card_aspect(prev):
			"MALICE":
				resolver.push(GainPower.new(2), player_id)
			"AMBITION":
				resolver.push(PromoteCard.new("hand_or_discard"), player_id)
			"GUILE":
				resolver.push(PlaceSpy.new(2), player_id)
			"CONQUEST":
				resolver.push(DeployTroop.new(3), player_id)
