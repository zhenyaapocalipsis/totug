class_name GameState
extends RefCounted

## Состояние партии целиком. Сериализуемо: только встроенные типы Godot и
## RefCounted-объекты этого модуля — ни Node, ни сцен, как требует
## claude/architecture.md, раздел 2.
##
## troops: slot_id -> owner ("" пусто, "white" нейтральное войско, иначе id игрока)
## spies:  site_id -> Array[String] (id игроков с шпионом на этом сайте)
##
## Этап 2 не даёт способа поставить шпиона: "Place a Spy" — карточное
## действие (рулбук стр. 12), не одно из четырёх базовых (стр. 8). Структура
## здесь уже готова для этапа 5, когда появятся карты с этим эффектом.

const WHITE := "white"

var graph: MapGraph
var presence: Presence
var control: SiteControl
var troops: Dictionary = {}
var spies: Dictionary = {}
var players: Dictionary = {}  # player_id -> PlayerState
var turn_order: Array[String] = []
var current_player_index: int = 0
## Раскладка доски: какой гекс на каком месте и как повёрнут. Правилам это не
## нужно (им хватает графа), но интерфейсу — чтобы нарисовать тайлы, а
## BoardGeometry — чтобы посчитать мировые координаты слотов.
## Заполняет GameSetup; {} у синтетических досок в тестах.
var layout: Dictionary = {}

var market: Market
var supplies: Supplies
var vp_bank: VPBank
var rng: RandomNumberGenerator

var game_end_triggered: bool = false
var game_end_reason: String = ""  # "last_troop" | "market_empty" | "abandoned"
var final_round_ends_after_index: int = -1
var game_over: bool = false
## Сетевая партия кончилась досрочно: этот игрок отключился и не вернулся
## (GameEnd.abandon). Пусто — партия кончилась по правилам.
var abandoned_by: String = ""
## Horned Devil (New Era, Avernus): игрок сыграл его при пустой колоде рынка и побеждает
## (Scoring.winners), партия кончается после его хода.
var instant_winner: String = ""

## Этап 5: аспекты карт, сыгранных (или сожранных) в этот ход — используется
## FocusEffect ("<Aspect> Focus ► ..."). Сбрасывается в TurnEngine.start_turn().
var played_aspects_this_turn: Array[String] = []
## Локации с маркером контроля, за которые текущий игрок уже получил Influence
## в этом ходу (TurnEngine.grant_marker_influence). Сбрасывается в start_turn.
var marker_influence_paid: Array[String] = []
## Power/Influence бонуса A2, уже выданные текущему игроку в этом ходу
## (TurnEngine.grant_control_income): ярус вырос посреди хода — доплачивается
## только разница. Сбрасывается в start_turn.
var a2_paid := {"power": 0, "influence": 0}

## New Era: скидки текущего хода от сыгранных карт (сбрасываются в start_turn).
##   "assassinate"  — на сколько дешевле базовое Assassinate (Gladiator);
##   "return_spy"   — на сколько дешевле базовый возврат шпиона (Gladiator);
##   "supply:<id>"  — скидка на карту из запаса (Hippogriff: House Guard).
## Цены считает Actions.*_cost(); интерфейс видит их через StateView.
var turn_discounts: Dictionary = {}
## New Era: счётчики и флаги текущего хода от карт Shadow Isles (сколько
## сыграно Insane Outcast, повтор Vine Blight и т.п., см. ShadowCards).
## Сбрасываются в start_turn.
var turn_flags: Dictionary = {}
## New Era, Basilisk (Ekko): этот игрок после своего хода ходит ещё раз
## (GameEnd.advance_turn). in_extra_turn — идёт такой лишний ход: в нём можно
## сыграть не больше 3 карт (TurnEngine.start_turn ставит turn_flags["card_limit"]).
var extra_turn_for: String = ""
var in_extra_turn: bool = false
## Siege/Mercenaries, Bregan D'aerthe Spy: украденные маркеры контроля
## (id локации -> вор). Вор держит маркер до начала своего следующего хода
## (TurnEngine.start_turn), пока маркер приносит доход только ему.
var stolen_markers: Dictionary = {}

## Этап 5: открытая общая стопка карт, ушедших из игры через Devour. Видна
## всем игрокам (в отличие от played_pile) — нужна как минимум для Ghost.
var devoured_pile: Array[String] = []
## Ghost: id игрока, для которого до конца его хода верхняя карта devoured_pile
## считается частью маркета (пусто — эффект не действует).
var ghost_market_player: String = ""

## Стартовые сайты ("с чёрной рамкой"), из которых игроки ещё должны сами
## выбрать себе стартовый (рулбук стр. 4, шаг 11). Заполняет GameSetup.new_game
## только при interactive_start=true; GameServer видит непустой список при
## своём создании и запускает по одному PendingDecision на игрока (см.
## ChooseStartingSite) вместо автоматической расстановки по порядку хода.
## Пусто, если расстановка уже сделана синхронно (старое поведение, нужное
## тестам/sweep-прогонам) или для синтетических досок тестов.
var starting_site_candidates: Array[String] = []

## Какие две полуколоды собраны в маркет этой партии (ключи half_decks.json).
## Правилам они больше не нужны — маркет уже собран, — но интерфейсу нужны:
## по ним он красит фон экрана.
var half_decks: Array[String] = []
## Режим сборки маркета (GameSetup.MODE_*), чтобы интерфейс мог его показать.
var game_mode: String = "standard"
## Командная игра 2 на 2 (этап Team-1): player_id -> id команды ("red" /
## "blue"). Пусто — каждый сам за себя. Союзники вместе контролируют локации,
## дают друг другу Присутствие и не могут атаковать друг друга. Ставить через
## set_teams: Presence и SiteControl держат ссылку на тот же словарь.
var teams: Dictionary = {}


func _init(map_graph: MapGraph, seed_value: int = 0) -> void:
	graph = map_graph
	presence = Presence.new(map_graph)
	control = SiteControl.new(map_graph)
	supplies = Supplies.standard()
	vp_bank = VPBank.new()
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value


func add_player(player_id: String, starting_deck_cards: Array[String]) -> void:
	players[player_id] = PlayerState.new(player_id, starting_deck_cards)
	turn_order.append(player_id)


## Слоты, куда игрок может поставить войско: Присутствие (Presence) минус
## локации, закрытые для него в этот ход (Weretiger, NoxusCards).
func deployable_slots(player_id: String) -> PackedStringArray:
	var legal: PackedStringArray = presence.deployable_slots(player_id, troops, spies)
	if not turn_flags.has("no_deploy"):
		return legal
	var result := PackedStringArray()
	for slot_id: String in legal:
		if not NoxusCards.deploy_blocked(self, player_id, graph.site_of_slot(slot_id)):
			result.append(slot_id)
	return result


func current_player() -> String:
	return turn_order[current_player_index]


func set_teams(team_of: Dictionary) -> void:
	teams = team_of
	presence.sides = team_of
	control.sides = team_of
	pool_stocks()


func is_team_game() -> bool:
	return not teams.is_empty()


## Сторона владельца: команда в командной игре, иначе сам владелец
## ("white" и "" остаются как есть).
func side_of(owner: String) -> String:
	return String(teams.get(owner, owner))


## Союзник (или сам игрок): его войска и шпионы — не вражеские.
func is_ally(player_id: String, other: String) -> bool:
	return other != "" and other != WHITE and side_of(other) == side_of(player_id)


## Вражеский владелец войска или шпиона: не пусто, не свой и не союзный
## (белые войска — вражеские).
func is_enemy(player_id: String, owner: String) -> bool:
	return owner != "" and not is_ally(player_id, owner)


## Соперник-игрок (не союзник и не сам игрок).
func is_opponent(player_id: String, other: String) -> bool:
	return other != WHITE and other != "" and not is_ally(player_id, other)


## Игроки команды team в порядке хода (в обычной игре — сам игрок).
func members_of(side: String) -> Array[String]:
	var out: Array[String] = []
	for pid: String in turn_order:
		if side_of(pid) == side:
			out.append(pid)
	return out


## Запас игрока (этап Team-6): бараки (войска и шпионы), трофейный зал и
## внутренний круг. В 2v2 у команды один общий запас — он лежит у "хозяина",
## игрока с тем же id, что и команда (GameSetup.team_map: "red", "blue");
## у союзника эти поля пустые. В обычной игре — сам игрок.
func stock(player_id: String) -> PlayerState:
	var side := side_of(player_id)
	if players.has(side):
		return players[side]
	return players[player_id]


## Сколько игроков делят запас player_id (1 в обычной игре, 2 в 2v2):
## общие бараки вмещают STARTING_TROOPS и STARTING_SPIES на каждого.
func stock_share(player_id: String) -> int:
	var holder := stock(player_id)
	var n := 0
	for pid: String in players.keys():
		if stock(pid) == holder:
			n += 1
	return maxi(1, n)


## Сколько войск уже ушло из бараков игрока (в 2v2 — из общих бараков
## команды): Solar и живой текст "troops_left".
func troops_out(player_id: String) -> int:
	return PlayerState.STARTING_TROOPS * stock_share(player_id) - stock(player_id).troops_in_barracks


## Сложить запасы союзников у хозяина команды (повторный вызов ничего не
## меняет: у союзника всё уже нулевое).
func pool_stocks() -> void:
	for pid: String in players.keys():
		var p: PlayerState = players[pid]
		var holder := stock(pid)
		if holder == p:
			continue
		holder.troops_in_barracks += p.troops_in_barracks
		holder.spies_in_barracks += p.spies_in_barracks
		p.troops_in_barracks = 0
		p.spies_in_barracks = 0
		for color: String in p.trophies.keys():
			for i in range(int(p.trophies[color])):
				holder.add_trophy(color)
		p.trophies.clear()
		p.trophy_hall_count = 0
		p.white_trophy_count = 0
		holder.deck.inner_circle.append_array(p.deck.inner_circle)
		p.deck.inner_circle.clear()


## Расставляет нейтральные белые войска по данным сайтов (рулбук стр. 4, шаг
## 6): initial_white_troops штук на сайт, в первые по порядку троп-слоты.
## Какой именно слот получит белое войско, правилами не оговорено — порядок
## из данных детерминирован, этого достаточно.
##
## ВАЖНО про идентификаторы (здесь был баг, найденный на этапе 7 по картинке).
## В исходных данных слот называется "A3_0_0", но на СОБРАННОЙ доске тот же
## слот получает префикс места в раскладке — "a:A3_0_0" (см. BoardBuilder:
## один и тот же гекс может стоять в разных местах, поэтому сырые id не
## уникальны). Раньше эта функция писала сырые id, и все 56 белых войск
## оказывались на слотах, которых в графе не существует: их не было видно,
## они не мешали разворачиваться, их нельзя было убить и они не считались
## в контроле локаций. Поэтому расстановка идёт ПО ГРАФУ, а данные сайтов
## служат только источником числа войск.
func setup_white_troops(site_data: Dictionary) -> void:
	for site_id: String in graph.sites.keys():
		var hex_id: String = String(graph.sites[site_id].get("hex", ""))
		# "a:A3_site0" -> "A3_site0"; у сайтов без префикса (синтетические
		# графы в тестах) get_slice вернёт исходную строку целиком.
		var raw_site_id: String = site_id.get_slice(":", 1) if site_id.contains(":") else site_id
		var count := 0
		for site: Dictionary in (site_data.get(hex_id, []) as Array):
			if String(site.get("id", "")) == raw_site_id:
				count = int(site.get("initial_white_troops", 0))
				break
		if count <= 0:
			continue
		var slots: PackedStringArray = graph.slots_of_site(site_id)
		for i in range(mini(count, slots.size())):
			troops[slots[i]] = WHITE


## Стартовая расстановка (рулбук стр. 4, шаг 11): каждый игрок ставит одно
## войско на стартовом сайте, ещё не занятом другим игроком. Какие сайты
## являются стартовыми — решает вызывающий код (см. GameEnd/Setup notes в
## claude/stage2-start-here.md: список кандидатов не подтверждён владельцем
## игры). Возвращает false, если на сайте уже нет свободных слотов.
func setup_deploy_starting_troop(player_id: String, site_id: String) -> bool:
	var p: PlayerState = stock(player_id)
	if p.troops_in_barracks <= 0:
		return false
	for slot_id: String in graph.slots_of_site(site_id):
		if troops.get(slot_id, "") == "":
			troops[slot_id] = player_id
			p.troops_in_barracks -= 1
			return true
	return false
