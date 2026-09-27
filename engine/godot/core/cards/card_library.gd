class_name CardLibrary
extends RefCounted

## Кодирование эффектов всех 125 карт (этап 5) поверх примитивов/обёрток
## core/effects/. Источник текста — engine/data/cards.json (уже вычитанный,
## значки расшифрованы в слова, флейвор-текст отделён — см. claude/progress.md,
## этап 4). Копия лежит в data/cards/cards.json, чтобы Godot мог её
## res://-загрузить в собранном билде.
##
## get_effect(card_id) возвращает НОВЫЙ экземпляр дерева эффектов при каждом
## вызове (эффекты хранят состояние ответа в себе, повторно использовать
## нельзя).
##
## Отмеченные ниже карты реализованы с ЯВНО задокументированным упрощением
## относительно буквального текста — см. комментарий у каждой. Ни одно из
## упрощений не читерит в пользу игрока и не блокирует партию.

const CARDS_JSON_PATH := "res://data/cards/cards.json"
const INSANE_OUTCAST_ID := "48341"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	var f := FileAccess.open(CARDS_JSON_PATH, FileAccess.READ)
	if f == null:
		push_error("CardLibrary: не удалось открыть %s" % CARDS_JSON_PATH)
		_loaded = true
		return
	var parsed = JSON.parse_string(f.get_as_text())
	for c: Dictionary in parsed:
		# JSON.parse_string разбирает числа как float — без int() ключ станет
		# "48342.0" вместо "48342" и перестанет совпадать с литералами в match.
		_data[str(int(c["card_id"]))] = c
	_loaded = true


static func card_data(card_id: String) -> Dictionary:
	_ensure_loaded()
	return _data.get(card_id, {})


static func card_aspect(card_id: String) -> String:
	var c := card_data(card_id)
	var a = c.get("aspect")
	return String(a) if a != null else ""


static func card_type(card_id: String) -> String:
	var c := card_data(card_id)
	var t = c.get("type")
	return String(t) if t != null else ""


static func card_cost(card_id: String) -> int:
	var c := card_data(card_id)
	var cost = c.get("cost")
	return int(cost) if cost != null else -1


static func _aspect_filter(aspect: String) -> Callable:
	return func(cid: String) -> bool:
		return card_aspect(cid) == aspect


static func _type_filter(type_name: String) -> Callable:
	return func(cid: String) -> bool:
		return card_type(cid) == type_name


## "if another player's troop is at that site" — общий предикат для эффектов
## вида PlaceSpy.on_placed.
static func _site_has_enemy_troop(state: GameState, player_id: String, site_id: String) -> bool:
	for slot_id: String in state.graph.slots_of_site(site_id):
		var owner: String = state.troops.get(slot_id, "")
		if owner != "" and owner != player_id and owner != "white":
			return true
	return false


static func _site_has_enemy_spy(state: GameState, player_id: String, site_id: String) -> bool:
	for owner: String in state.spies.get(site_id, []):
		if owner != player_id:
			return true
	return false


## Все РАЗНЫЕ соперники с войском на сайте, в порядке очереди хода — не
## только первый найденный (баг из audit.md, "поправим к этапу 4 игрока":
## на двоих соперник всегда один, поэтому раньше это не проявлялось).
static func _enemy_troop_owners_at_site(state: GameState, player_id: String, site_id: String) -> Array[String]:
	var owners: Array[String] = []
	for slot_id: String in state.graph.slots_of_site(site_id):
		var owner: String = state.troops.get(slot_id, "")
		if owner != "" and owner != player_id and owner != "white" and not owners.has(owner):
			owners.append(owner)
	owners.sort_custom(func(a, b): return state.turn_order.find(a) < state.turn_order.find(b))
	return owners


## ---- нестандартные one-off эффекты, у которых нет обобщённого примитива ----

class _MindwitnessEffect extends CardEffect:
	## "Assassinate a troop. If that troop belonged to another player and
	## they have more than 3 cards, they must discard a card."
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var inner := AssassinateTroop.new(1)
		resolver.push(_MindwitnessFollowUp.new(), player_id)
		resolver.push(inner, player_id)

class _MindwitnessFollowUp extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		# Определяем жертву по последнему событию assassinate в логе резолвера.
		for i in range(resolver.events.size() - 1, -1, -1):
			var evt: Dictionary = resolver.events[i]
			if evt.get("type") == "assassinate" and evt.get("player_id") == player_id:
				var victim: String = evt.get("victim", "")
				if victim != "" and victim != "white" and victim != player_id and state.players.has(victim):
					resolver.push(ForceDiscard.new("victim", 3, victim), player_id)
				break


class _ChuulDiscardEffect extends CardEffect:
	var site_id: String
	func _init(s: String) -> void:
		site_id = s
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		# Каждый такой соперник сбрасывает ОДИН раз, сколько бы его войск тут ни стояло.
		var victims: Array[String] = []
		for slot_id: String in state.graph.slots_of_site(site_id):
			var owner: String = state.troops.get(slot_id, "")
			if owner != "" and owner != player_id and owner != "white":
				if not victims.has(owner):
					victims.append(owner)
		for pid: String in victims:
			resolver.push(ForceDiscard.new("victim", 3, pid), player_id)


class _CarrionCrawlerDevour extends CardEffect:
	## "Devour a card in the market. Instead of replacing it with the top
	## card from the market deck, replace it with this card."
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var index = answer()
			if index != null and index != -1:
				var devoured: String = state.market.display[int(index)]
				var refill: String = state.market.recruit_at(int(index))  # обычный рефилл...
				if refill != "":
					state.market.deck.append(refill)  # ...откатываем обратно в колоду маркета
				state.devoured_pile.append(devoured)
				var p: PlayerState = state.players[player_id]
				var idx: int = p.deck.played_pile.find("48737")
				if idx != -1:
					p.deck.played_pile.remove_at(idx)
				state.market.display[int(index)] = "48737"
				resolver.log_event("devour", {"player_id": player_id, "card_id": devoured, "source": "market"})
			return
		var options: Array = []
		for i in range(state.market.display.size()):
			if state.market.display[i] != "":
				options.append(i)
		if options.is_empty():
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Devour a card in the market"
		pd.choice_type = "target_market_index"
		pd.legal_options = options
		pd.target_effect = self
		resolver.request_decision(pd)


class _GhostDevouredPileEffect extends CardEffect:
	## "For the rest of your turn treat the top card of the devoured deck as if
	## it was in the market" — до конца хода верхнюю карту devoured_pile можно
	## купить обычным recruit (Market.DEVOURED_TOP_INDEX, см. Actions.recruit).
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		state.ghost_market_player = player_id
		resolver.log_event("ghost_market", {"player_id": player_id})


class _DrawPerSpy extends CardEffect:
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var count := 0
		for owners: Array in state.spies.values():
			count += owners.count(player_id)
		resolver.push(DrawCards.new(count), player_id)


class _QuaggothEffect extends CardEffect:
	## "Assassinate one white troop for each site you control."
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		var count := 0
		for site_id: String in state.graph.sites.keys():
			if state.control.controller_of(site_id, state.troops) == player_id:
				count += 1
		if count > 0:
			resolver.push(AssassinateTroop.new(count, true, true), player_id)


class _LichEffect extends CardEffect:
	## "Take up to 2 troops from THEIR trophy hall" — "their" — соперника с
	## войском на сайте шпиона. С несколькими соперниками там (3-4 игрока)
	## игрок сам выбирает, чей зал — раньше эффект молча брал первого
	## найденного (audit.md, поправлено на этапе 4 игрока).
	var site_id: String
	var _owners: Array[String] = []
	func _init(s: String) -> void:
		site_id = s
	func apply(state: GameState, player_id: String, resolver: EffectResolver) -> void:
		if is_answered():
			var chosen = answer()
			if chosen != null and String(chosen) != "" and _owners.has(String(chosen)):
				resolver.push(TakeFromTrophyHall.new(2, true, false, String(chosen), false), player_id)
			return
		_owners = CardLibrary._enemy_troop_owners_at_site(state, player_id, site_id)
		if _owners.is_empty():
			return
		if _owners.size() == 1:
			resolver.push(TakeFromTrophyHall.new(2, true, false, _owners[0], false), player_id)
			return
		var pd := PendingDecision.new()
		pd.player_id = player_id
		pd.prompt = "Whose trophy hall?"
		pd.choice_type = "target_player"
		pd.legal_options = Array(_owners)
		pd.target_effect = self
		resolver.request_decision(pd)


## ---- главная таблица ----

## Карта, чьё дерево эффектов сейчас строится. ChooseEffect запоминает её при
## создании, чтобы интерфейс мог нарисовать варианты артом этой карты.
static var building_card := ""


static func get_effect(card_id: String) -> CardEffect:
	var outer := building_card
	building_card = card_id
	var effect := _build_effect(card_id)
	building_card = outer
	return effect


static func _build_effect(card_id: String) -> CardEffect:
	match card_id:
		"48342":  # Noble
			return GainInfluence.new(1)
		"48344":  # Soldier
			return GainPower.new(1)
		"48345":  # Conscription Officer (стартовая колода вместо одного Noble)
			return ChooseEffect.new([
				GainInfluence.new(1),
				PromoteCard.new("hand"),
			], ["+1 Influence", "Promote another card in your hand"])
		"48341":  # Insane Outcast
			return RemoveSelfFromPlay.new(card_id)
		"48343":  # Priestess of Lolth
			return GainInfluence.new(2)
		"48340":  # House Guard
			return GainPower.new(2)
		"48336":  # Spy Master
			return PlaceSpy.new(1)
		"48306":  # Advocate
			return ChooseEffect.new([
				GainInfluence.new(2),
				AtEndOfTurn.new(PromoteCard.new("played_other", card_id)),
			], ["+2 Influence", "At end of turn, promote another card played this turn"])
		"48334":  # Spellspinner
			return ChooseEffect.new([
				PlaceSpy.new(1),
				ReturnOwnSpy.new(null, func(site): return SupplantTroop.new(1, false, true, false, Callable(), site)),
			], ["Place a spy", "Return one of your spies -> Supplant a troop at that spy's site"])
		"48331":  # Mercenary Squad
			return DeployTroop.new(3)
		"48325":  # Inquisitor
			return ChooseEffect.new([GainInfluence.new(2), AssassinateTroop.new(1)], ["+2 Influence", "Assassinate a troop"])
		"48322":  # Infiltrator
			return PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
				func(state, pid): return CardLibrary._site_has_enemy_troop(state, pid, site), GainPower.new(1)))
		"48320":  # Drow Negotiator
			return SequenceEffect.new([
				ConditionalEffect.new(func(state, pid): return state.players[pid].deck.inner_circle.size() >= 4, GainInfluence.new(3)),
				AtEndOfTurn.new(PromoteCard.new("played_other", card_id)),
			])
		"48310":  # Blackguard
			return ChooseEffect.new([GainPower.new(2), AssassinateTroop.new(1)], ["+2 Power", "Assassinate a troop"])
		"48302":  # Advance Scout
			return SupplantTroop.new(1, true, false)
		"48338":  # Underdark Ranger
			return AssassinateTroop.new(2, true)
		"48314":  # Chosen of Lolth
			return SequenceEffect.new([ReturnTroopOrSpy.new(1), AtEndOfTurn.new(PromoteCard.new("played_other", card_id))])
		"48312":  # Bounty Hunter
			return GainPower.new(3)
		"48328":  # Masters of Sorcere
			return ChooseEffect.new([PlaceSpy.new(2), ReturnOwnSpy.new(GainPower.new(4))],
				["Place 2 spies", "Return one of your spies -> +4 Power"])
		"48327":  # Master of Melee-Magthere
			return ChooseEffect.new([DeployTroop.new(4), SupplantTroop.new(1, true, true)],
				["Deploy 4 troops", "Supplant a white troop anywhere on the board"])
		"48324":  # Information Broker
			return ChooseEffect.new([PlaceSpy.new(1), ReturnOwnSpy.new(DrawCards.new(3))],
				["Place a spy", "Return one of your spies -> Draw 3 cards"])
		"48318":  # Doppelganger
			return SupplantTroop.new(1, false, false)
		"48339":  # Weaponmaster
			var one := func(): return ChooseEffect.new([DeployTroop.new(1), AssassinateTroop.new(1, true)], ["Deploy a troop", "Assassinate a white troop"])
			return SequenceEffect.new([one.call(), one.call(), one.call()])
		"48315":  # Council Member
			return SequenceEffect.new([MoveTroop.new(2, true), AtEndOfTurn.new(PromoteCard.new("played_other", card_id))])
		"48316":  # Deathblade
			return AssassinateTroop.new(2)
		"48329":  # Matron Mother
			return SequenceEffect.new([PutDeckIntoDiscard.new(), PromoteCard.new("discard")])
		"48424":  # Kobold
			return ChooseEffect.new([DeployTroop.new(1), AssassinateTroop.new(1, true)], ["Deploy a troop", "Assassinate a white troop"])
		"48436":  # White Wyrmling
			return SequenceEffect.new([DeployTroop.new(2), DevourCard.new("market", "", null, true, true)])
		"48439":  # Wyrmspeaker
			return SequenceEffect.new([GainInfluence.new(1), AtEndOfTurn.new(PromoteCard.new("played_other", card_id))])
		"48432":  # Watcher of Thay
			return ChooseEffect.new([PlaceSpy.new(1), ReturnOwnSpy.new(GainInfluence.new(3))], ["Place a spy", "Return one of your spies -> +3 Influence"])
		"48413":  # Dragon Cultist
			return ChooseEffect.new([GainPower.new(2), GainInfluence.new(2)], ["+2 Power", "+2 Influence"])
		"48409":  # Cult Fanatic
			return SequenceEffect.new([GainInfluence.new(2), DevourCard.new("market", "", null, true, true)])
		"48402":  # Black Wyrmling
			return SequenceEffect.new([GainInfluence.new(1), AssassinateTroop.new(1, true)])
		"48421":  # Green Wyrmling
			return PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
				func(state, pid): return CardLibrary._site_has_enemy_troop(state, pid, site), GainInfluence.new(2)))
		"48418":  # Enchanter of Thay
			return ChooseEffect.new([PlaceSpy.new(1), ReturnOwnSpy.new(GainPower.new(4))], ["Place a spy", "Return one of your spies -> +4 Power"])
		"48415":  # Dragonclaw
			return SequenceEffect.new([
				AssassinateTroop.new(1),
				ConditionalEffect.new(func(state, pid): return state.players[pid].player_trophy_count() >= 5, GainPower.new(2)),
			])
		"48407":  # Cleric of Laogzed
			return SequenceEffect.new([MoveTroop.new(1), AtEndOfTurn.new(PromoteCard.new("played_other", card_id))])
		"48428":  # Red Wyrmling
			return SequenceEffect.new([GainPower.new(2), GainInfluence.new(2)])
		"48405":  # Blue Wyrmling
			return SequenceEffect.new([GainInfluence.new(3), ReturnTroopOrSpy.new(1)])
		"48425":  # Rath Modar
			return SequenceEffect.new([DrawCards.new(2), PlaceSpy.new(1)])
		"48429":  # Severin Silrajin
			return GainPower.new(5)
		"48433":  # White Dragon
			return SequenceEffect.new([DeployTroop.new(3), GainVpPerN.new("vp", "sites_controlled", 2, 1)])
		"48419":  # Green Dragon
			return ChooseEffect.new([
				PlaceSpy.new(1, false, func(site): return SupplantTroop.new(1, false, true, false, Callable(), site)),
				ReturnOwnSpy.new(null, func(site): return SequenceEffect.new([
					SupplantTroop.new(1, false, true, false, Callable(), site),
					GainVpPerN.new("vp", "control_markers", 1, 1),
				])),
			], ["Place a spy, then supplant a troop at that site", "Return one of your spies -> supplant a troop at that spy's site, then gain VP per site controlled"])
		"48400":  # Black Dragon
			return SequenceEffect.new([SupplantTroop.new(1, true, true), GainVpPerN.new("vp", "white_trophy", 3, 1)])
		"48403":  # Blue Dragon
			return AtEndOfTurn.new(SequenceEffect.new([
				PromoteCard.new("played_other", card_id, Callable(), 2, true),
				GainVpPerN.new("vp", "inner_circle", 3, 1),
			]))
		"48426":  # Red Dragon
			return SequenceEffect.new([
				SupplantTroop.new(1),
				ReturnTroopOrSpy.new(1, false, false, true),
				GainVpPerN.new("vp", "sites_controlled_total", 1, 1),
			])
		"48512":  # Gibbering Mouther
			return SequenceEffect.new([DeployTroop.new(2), GiveInsaneOutcast.new("choose_opponent_adjacent", 1)])
		"48534":  # Night Hag
			return ChooseEffect.new([PlaceSpy.new(1), ReturnOwnSpy.new(DrawCards.new(2))], ["Place a spy", "Return one of your spies -> Draw 2 cards"])
		"48527":  # Myconid Adult
			return SequenceEffect.new([GainInfluence.new(2), GiveInsaneOutcast.new("choose_opponent", 1)])
		"48524":  # Mind Flayer
			return DevourCard.new("hand", "", ChooseEffect.new([GainInfluence.new(3), AssassinateTroop.new(1)], ["+3 Influence", "Assassinate a troop"]))
		"48516":  # Hezrou
			return SequenceEffect.new([MoveTroop.new(1), PromoteCard.new("top_of_deck")])
		"48503":  # Derro
			return SequenceEffect.new([SupplantTroop.new(1, true, true), GiveInsaneOutcast.new("self", 1)])
		"48529":  # Myconid Sovereign
			return SequenceEffect.new([GiveInsaneOutcast.new("choose_opponent", 1), AtEndOfTurn.new(PromoteCard.new("played_other", card_id))])
		"48519":  # Jackalwere
			return ChooseEffect.new([PlaceSpy.new(1), ReturnOwnSpy.new(SequenceEffect.new([GainPower.new(2), GainInfluence.new(2)]))],
				["Place a spy", "Return one of your spies -> +2 Power +2 Influence"])
		"48509":  # Ghoul
			return SequenceEffect.new([GainPower.new(2), GiveInsaneOutcast.new("each_opponent", 1)])
		"48506":  # Ettin
			return ChooseEffect.new([DeployTroop.new(3), AssassinateTroop.new(2, true)], ["Deploy 3 troops", "Assassinate 2 white troops"])
		"48538":  # Vrock
			return ChooseEffect.new([PlaceSpy.new(1), ReturnOwnSpy.new(GainPower.new(5))], ["Place a spy", "Return one of your spies -> +5 Power"])
		"48537":  # Succubus
			return DevourCard.new("hand", "", PlaceSpy.new(1, false, func(site): return AssassinateTroop.new(1, false, false, false, 0, 0, site)))
		"48531":  # Nalfeshnee
			return SequenceEffect.new([GainInfluence.new(3), PromoteCard.new("top_of_deck")])
		"48513":  # Glabrezu
			return DevourCard.new("hand", "", AssassinateTroop.new(2))
		"48539":  # Zuggtmoy
			return DevourCard.new("inner_circle", "", SequenceEffect.new([
				GainInfluence.new(3), AtEndOfTurn.new(PromoteCard.new("played_other", card_id, Callable(), 2, true)),
			]))
		"48521":  # Marilith
			return DevourCard.new("hand", "", GainPower.new(5))
		"48514":  # Graz'zt
			return ChooseEffect.new([
				PlaceSpy.new(2),
				ReturnOwnSpy.new(null, Callable(), true, func(sites: Array):
					var effs: Array[CardEffect] = []
					for s in sites:
						effs.append(SupplantTroop.new(1, false, true, false, Callable(), s))
					return SequenceEffect.new(effs)),
			], ["Place 2 spies", "Return any number of your spies -> supplant a troop at each of those sites"])
		"48500":  # Balor
			return DevourCard.new("hand", "", SequenceEffect.new([SupplantTroop.new(1, true, true), DeployTroop.new(1)]))
		"48501":  # Demogorgon
			return DevourCard.new("hand", "", SequenceEffect.new([SupplantTroop.new(2, true, false), GiveInsaneOutcast.new("each_opponent", 2)]))
		"48535":  # Orcus
			return DevourCard.new("hand", "", SequenceEffect.new([AssassinateTroop.new(2), TakeFromTrophyHall.new(2, true, false)]))
		"48636":  # Water Elemental
			return SequenceEffect.new([DeployTroop.new(2), FocusEffect.new("CONQUEST", DrawCards.new(1))])
		"48610":  # Black Earth Cultist
			return SequenceEffect.new([AtEndOfTurn.new(PromoteCard.new("played_other", card_id)), FocusEffect.new("AMBITION", GainInfluence.new(2))])
		"48628":  # Howling Hatred Cultist
			return SequenceEffect.new([
				ChooseEffect.new([PlaceSpy.new(1), ReturnOwnSpy.new(GainInfluence.new(3))], ["Place a spy", "Return one of your spies -> +3 Influence"]),
				FocusEffect.new("GUILE", GainPower.new(1)),
			])
		"48623":  # Fire Elemental
			return SequenceEffect.new([
				ChooseEffect.new([GainPower.new(2), GainInfluence.new(2)], ["+2 Power", "+2 Influence"]),
				FocusEffect.new("MALICE", DrawCards.new(1)),
			])
		"48615":  # Earth Elemental
			return SequenceEffect.new([GainInfluence.new(1), ReturnTroopOrSpy.new(1), FocusEffect.new("AMBITION", DrawCards.new(1))])
		"48613":  # Crushing Wave Cultist
			return SequenceEffect.new([AssassinateTroop.new(1, true), FocusEffect.new("CONQUEST", DeployTroop.new(2))])
		"48604":  # Air Elemental
			return SequenceEffect.new([
				ChooseEffect.new([PlaceSpy.new(1), ReturnOwnSpy.new(DeployTroop.new(3))], ["Place a spy", "Return one of your spies -> Deploy 3 troops"]),
				FocusEffect.new("GUILE", DrawCards.new(1)),
			])
		"48638":  # Water Elemental Myrmidon
			return SequenceEffect.new([AssassinateTroop.new(1, true), AtEndOfTurn.new(PromoteCard.new("played_other", card_id, CardLibrary._aspect_filter("OBEDIENCE")))])
		"48625":  # Fire Elemental Myrmidon
			return SequenceEffect.new([GainPower.new(2), AtEndOfTurn.new(PromoteCard.new("played_other", card_id, CardLibrary._aspect_filter("OBEDIENCE")))])
		"48620":  # Eternal Flame Cultist
			return SequenceEffect.new([AssassinateTroop.new(1), FocusEffect.new("MALICE", GainPower.new(2))])
		"48617":  # Earth Elemental Myrmidon
			return SequenceEffect.new([GainInfluence.new(2), AtEndOfTurn.new(PromoteCard.new("played_other", card_id))])
		"48606":  # Air Elemental Myrmidon
			return SequenceEffect.new([PlaceSpy.new(1), AtEndOfTurn.new(PromoteCard.new("played_other", card_id, CardLibrary._aspect_filter("OBEDIENCE")))])
		"48633":  # Vanifer
			return SequenceEffect.new([AssassinateTroop.new(1), RecruitFree.new("MALICE", 4)])
		"48630":  # Marlos Urnrayle
			return SequenceEffect.new([GainInfluence.new(1), AtEndOfTurn.new(PromoteCard.new("played_other", card_id)), RecruitFree.new("AMBITION", 4)])
		"48626":  # Gar Shatterkeel
			return SequenceEffect.new([DeployTroop.new(3), RecruitFree.new("CONQUEST", 4)])
		"48600":  # Aerisi Kalinoth
			return SequenceEffect.new([GainPower.new(1), PlaceSpy.new(1), RecruitFree.new("GUILE", 4)])
		"48632":  # Olhydra
			return SequenceEffect.new([SupplantTroop.new(1, true, true), FocusEffect.new("CONQUEST", DeployTroop.new(2))])
		"48639":  # Yan-C-Bin
			return SequenceEffect.new([
				PlaceSpy.new(1, false, func(site): return AssassinateTroop.new(1, false, false, false, 0, 0, site)),
				FocusEffect.new("GUILE", PlaceSpy.new(1)),
			])
		"48631":  # Ogrémoch
			return SequenceEffect.new([
				GainInfluence.new(2), AtEndOfTurn.new(PromoteCard.new("played_other", card_id)),
				FocusEffect.new("AMBITION", AtEndOfTurn.new(PromoteCard.new("played_other", card_id))),
			])
		"48629":  # Imix
			return SequenceEffect.new([GainPower.new(4), FocusEffect.new("MALICE", GainPower.new(2))])
		"48712":  # Grimlock -- реакция на сброс: ForceDiscard.VictimDiscard
			return DeployTroop.new(1)
		"48714":  # Cranium Rats
			return SequenceEffect.new([DeployTroop.new(2), ForceDiscard.new("choose_opponent", 3)])
		"48709":  # Cloaker
			return ChooseEffect.new([
				PlaceSpy.new(1),
				ReturnOwnSpy.new(null, func(site): return AssassinateTroop.new(1, false, false, false, 0, 0, site)),
			], ["Place a spy", "Return one of your spies -> assassinate a troop at that spy's site"])
		"48717":  # Gauth
			return ChooseEffect.new([
				GainInfluence.new(2),
				SequenceEffect.new([DrawCards.new(1), ForceDiscard.new("choose_opponent", 3)]),
			], ["+2 Influence", "Draw a card, then choose an opponent with more than 3 cards to discard a card"])
		"48716":  # Mindwitness
			return _MindwitnessEffect.new()
		"48708":  # Nothic
			return ChooseEffect.new([
				PlaceSpy.new(1),
				ReturnOwnSpy.new(SequenceEffect.new([DrawCards.new(1), ForceDiscard.new("each_opponent", 3)])),
			], ["Place a spy", "Return one of your spies -> Draw a card; each opponent with more than 3 cards discards a card"])
		"48706":  # Chuul
			return PlaceSpy.new(1, false, func(site): return _ChuulDiscardEffect.new(site))
		"48704":  # Ambassador -- реакция на сброс: ForceDiscard.VictimDiscard
			return AtEndOfTurn.new(PromoteCard.new("played_other", card_id))
		"48739":  # Umber Hulk -- реакция на сброс: ForceDiscard.VictimDiscard
			return DeployTroop.new(3)
		"48718":  # Spectator
			return SequenceEffect.new([GainPower.new(2), GainInfluence.new(1)])
		"48707":  # Brainwashed Slave
			return ChooseEffect.new([PlaceSpy.new(1), ReturnOwnSpy.new(SequenceEffect.new([GainPower.new(2), GainInfluence.new(2)]))],
				["Place a spy", "Return one of your spies -> +2 Power +2 Influence"])
		"48703":  # Intellect Devourer
			return ChooseEffect.new([GainInfluence.new(3), ReturnTroopOrSpy.new(2, true)], ["+3 Influence", "Return up to two troops or spies"])
		"48715":  # Beholder
			return SequenceEffect.new([AssassinateTroop.new(1), GainVpPerN.new("power", "trophy_hall", 3, 1)])
		"48711":  # Quaggoth
			return _QuaggothEffect.new()
		"48702":  # Puppeteer
			return SequenceEffect.new([GainInfluence.new(2), AtEndOfTurn.new(PromoteCard.new("played_other", card_id))])
		"48701":  # Ulitharid
			return PlayCardFromZone.new("market", 4, "devour")
		"48705":  # Aboleth
			return ChooseEffect.new([PlaceSpy.new(2), _DrawPerSpy.new()], ["Place 2 spies", "Draw a card for each spy you have on the board"])
		"48710":  # Neogi
			return SequenceEffect.new([DeployTroop.new(4), AtEndOfTurn.new(ForceDiscard.new("each_opponent", 0))])
		"48700":  # Elder Brain
			return SequenceEffect.new([PromoteCard.new("top_of_deck"), PlayCardFromZone.new("inner_circle", 999, "keep")])
		"48713":  # Death Tyrant
			return AssassinateTroop.new(3, false, true, true, 1, 0)
		"48737":  # Carrion Crawler
			return SequenceEffect.new([GainPower.new(3), _CarrionCrawlerDevour.new()])
		"48730":  # Wraith
			return PlaceSpy.new(1, false, func(site): return DevourCard.new("this", "48730", AssassinateTroop.new(1, false, false, false, 0, 0, site)))
		"48729":  # Skeletal Horde
			return SequenceEffect.new([DeployTroop.new(2), DevourCard.new("this", "48729", DeployTroop.new(3))])
		"48727":  # Cultist of Myrkul
			return ChooseEffect.new([
				GainInfluence.new(2),
				DevourCard.new("this", "48727", AtEndOfTurn.new(PromoteCard.new("played_other", card_id, Callable(), 2, true)), false),
			], ["+2 Influence", "Devour this card -> at end of turn, promote up to 2 other cards played this turn"])
		"48720":  # Vampire Spawn
			return SequenceEffect.new([GainInfluence.new(1), ReturnTroopOrSpy.new(1)])
		"48735":  # Minotaur Skeleton
			return ChooseEffect.new([
				DeployTroop.new(3),
				DevourCard.new("this", "48735", AssassinateTroop.new(3, true, true, true), false),
			], ["Deploy three troops", "Devour this card -> assassinate up to three white troops at a single site"])
		"48736":  # Flesh Golem
			return SequenceEffect.new([GainPower.new(2), DevourCard.new("this", "48736", AssassinateTroop.new(1))])
		"48726":  # Ravenous Zombies
			return SequenceEffect.new([GainPower.new(1), AssassinateTroop.new(1, true)])
		"48724":  # Wight
			return ChooseEffect.new([GainPower.new(2), DevourCard.new("hand", "", SupplantTroop.new(1), false)],
				["+2 Power", "Devour a card in your hand -> Supplant a troop"])
		"48723":  # Ghost -- см. _GhostDevouredPileEffect: упрощение относительно RAW
			return ChooseEffect.new([PlaceSpy.new(1), ReturnOwnSpy.new(_GhostDevouredPileEffect.new())],
				["Place a spy", "Return one of your spies -> treat the top devoured card as if it was in the market this turn"])
		"48738":  # Revenant
			return SequenceEffect.new([
				AssassinateTroop.new(2),
				ConditionalEffect.new(func(state, pid): return state.players[pid].trophy_hall_count >= 8, PromoteCard.new("this", "48738")),
			])
		"48731":  # Ogre Zombie
			return SupplantTroop.new(1, true, true)
		"48719":  # Banshee
			return PlaceSpy.new(1, false, func(site): return ConditionalEffect.new(
				func(state, pid): return CardLibrary._site_has_enemy_spy(state, pid, site), GainInfluence.new(3)))
		"48734":  # Necromancer
			return ChooseEffect.new([GainInfluence.new(3), PromoteCard.new("hand_or_discard", "48734")],
				["+3 Influence", "Promote this card, or a card from your hand or discard pile"])
		"48722":  # Conjurer
			return ChooseEffect.new([PlaceSpy.new(1), ReturnOwnSpy.new(RecruitFree.new("", 3, 2, true))],
				["Place a spy", "Return one of your spies -> Recruit up to 2 cards that cost 3 or less"])
		"48721":  # Death Knight
			return SequenceEffect.new([SupplantTroop.new(1), GainVpPerN.new("vp", "player_trophy", 5, 1)])
		"48725":  # Mummy Lord
			var step := func(): return ChooseEffect.new([
				AssassinateTroop.new(1, true),
				TakeFromTrophyHall.new(1, false, true),
			], ["Assassinate a white troop", "Take a white troop from any trophy hall and deploy it"])
			return SequenceEffect.new([step.call(), step.call()])
		"48733":  # High Priest of Myrkul
			return SequenceEffect.new([
				ReturnTroopOrSpy.new(1),
				AtEndOfTurn.new(PromoteCard.new("played_other", card_id, CardLibrary._type_filter("UNDEAD"), 99, true)),
			])
		"48732":  # Lich
			return PlaceSpy.new(1, false, func(site): return _LichEffect.new(site))
		"48728":  # Vampire
			return ChooseEffect.new([
				SupplantTroop.new(1),
				SequenceEffect.new([PromoteCard.new("discard"), GainVpPerN.new("vp", "inner_circle", 3, 1)]),
			], ["Supplant a troop", "Promote a card from your discard pile, then gain VP per inner circle card"])
	push_error("CardLibrary: нет эффекта для card_id=%s" % card_id)
	return SequenceEffect.new([])
