extends SceneTree

## Минимальный раннер тестов ядра. Запуск:
##   godot --headless --path godot --script res://tests/run_tests.gd
##
## Умышленно без внешних зависимостей (GUT можно подключить позже) — ядро правил
## не тянет ни сцен, ни рендера, поэтому достаточно обычного скрипта.

var _passed := 0
var _failed := 0
var _current := ""


func _initialize() -> void:
	print("\n=== тесты ядра ===\n")

	test_rotation_math()
	test_edge_rotation()
	test_board_data_loads()
	test_graph_assembly()
	test_rotation_optimizer()
	test_presence_rules()
	test_direct_site_links()
	test_dead_ends_pruned()
	test_control_rules()

	# этап 2: базовый цикл хода
	test_vp_bank()
	test_deck()
	test_market()
	test_actions_deploy()
	test_actions_assassinate()
	test_actions_return_spy()
	test_actions_recruit()
	test_turn_engine()
	test_game_end()
	test_scoring()
	test_cluster_bonus()

	# этап 5: система эффектов карт
	test_effect_resolver_basics()
	test_choose_and_optional()
	test_focus_effect()
	test_deploy_and_assassinate_effects()
	test_devour_and_promote_effects()
	test_card_library_smoke_all_cards()

	# этап 6: сетевой слой
	test_intent_factories()
	test_state_view_hides_hidden_info()
	test_state_view_pending_decision_visibility()
	test_state_serializer_round_trip()
	test_game_server_turn_order_and_actions()
	test_game_server_play_card_with_decision()
	test_game_server_end_turn_advances()
	test_game_server_two_end_of_turn_promotes()
	test_game_server_end_of_game()
	test_game_server_grants_a2_bonus()


	# этап 7: настоящая партия и общие стопки
	test_half_deck_data()
	test_game_setup_real_game()
	test_hotseat_three_and_four_players()
	test_recruit_from_supply()
	test_insane_outcast_supply()
	test_state_view_legal_and_supplies()
	test_game_server_recruit_supply()
	test_white_troops_on_real_board()
	test_choose_option_answer_protocol()
	test_return_troop_on_real_board_ids()
	test_board_geometry_spreads_tiles()
	test_vp_income_is_explained()
	test_control_markers()
	test_presence_slots_explain_refusal()
	test_no_actions_while_decision_pending()
	test_cross_hex_site_to_site_presence()
	test_edge_ports_follow_art()

	# этап 2 доработки: исправления по аудиту карт
	test_audit_card_fixes()

	# схема доски (pixel art, без гексов)
	test_board_schematic()

	# оформление экрана
	test_background_palette()

	print("\n=== пройдено: %d, провалено: %d ===\n" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- инфраструктура ---------------------------------------------------------

func section(name: String) -> void:
	_current = name
	print("[ %s ]" % name)


func check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % description)
	else:
		_failed += 1
		print("  ПРОВАЛ %s" % description)


func check_eq(actual: Variant, expected: Variant, description: String) -> void:
	if actual == expected:
		_passed += 1
		print("  ok    %s" % description)
	else:
		_failed += 1
		print("  ПРОВАЛ %s  (получено %s, ожидалось %s)" % [description, actual, expected])


# --- тесты ------------------------------------------------------------------

func test_rotation_math() -> void:
	section("математика поворота")
	var p := Vector2(1.0, 0.0)
	var r90 := BoardBuilder.rotate_local(p, 90.0)
	check(r90.distance_to(Vector2(0.0, -1.0)) < 0.001, "поворот на 90° по часовой")
	var r360 := BoardBuilder.rotate_local(p, 360.0)
	check(r360.distance_to(p) < 0.001, "поворот на 360° возвращает исходное")
	check(
		BoardBuilder.rotate_local(Vector2(3.0, 4.0), 137.0).length() - 5.0 < 0.001,
		"поворот сохраняет длину"
	)


func test_edge_rotation() -> void:
	section("отображение рёбер при повороте")
	check_eq(BoardBuilder.world_dir_of_raw_edge("N", 0.0), "N", "0° не сдвигает ребро")
	check_eq(BoardBuilder.world_dir_of_raw_edge("N", 60.0), "NE", "60° сдвигает N -> NE")
	check_eq(BoardBuilder.world_dir_of_raw_edge("NW", 60.0), "N", "60° сдвигает NW -> N")
	check_eq(BoardBuilder.world_dir_of_raw_edge("N", 180.0), "S", "180° разворачивает N -> S")
	check_eq(BoardBuilder.world_dir_of_raw_edge("N", 360.0), "N", "полный оборот")


func test_board_data_loads() -> void:
	section("загрузка данных доски")
	var data := BoardData.load_all()
	check(data["sites"] != null, "site_data.json читается")
	check(data["routes"] != null, "route_slots.json читается")
	check(data["edges"] != null, "hex_edges.json читается")
	check(data["layouts"] != null, "layouts.json читается")

	var sites: Dictionary = data["sites"]
	check_eq(sites.size(), 21, "гексов с сайтами")

	var total_sites := 0
	var total_slots := 0
	for hex_id: String in sites.keys():
		for site: Dictionary in sites[hex_id]:
			total_sites += 1
			total_slots += (site["troop_slots"] as Array).size()
	check_eq(total_sites, 45, "всего сайтов")
	check_eq(total_slots, 137, "всего троп-слотов на сайтах")

	# контрольные значения против рулбука/арта
	var a1: Array = sites["A1"]
	check_eq(a1[0]["name"], "The Great Web", "A1 — The Great Web")
	check_eq(int(a1[0]["vp"]), 8, "The Great Web стоит 8 VP")
	check_eq((a1[0]["troop_slots"] as Array).size(), 6, "у The Great Web 6 троп-слотов")

	var edges: Dictionary = data["edges"]
	check_eq((edges["A1"] as Array).size(), 6, "A1 открыт на все 6 рёбер")
	# у C5 четыре выхода: N, NE, SE, S. Юго-восточный (туннель от Ath-Qua)
	# в таблице мода отмечен как отсутствующий — правка в HEX_EDGE_OVERRIDES,
	# проверка арта в tools/verify_hex_edges.py
	check_eq((edges["C5"] as Array).size(), 4, "C5 имеет 4 туннельных выхода")
	check(not (edges["B1"] as Array).has("S"), "у B1 на южном ребре карточка, туннеля нет")
	check((edges["X3"] as Array).has("SW"), "у X3 юго-западный туннель есть")


const TWO_PLAYER_HEXES := {
	"a": "A1",
	"c_n1": "C1", "c_n2": "C2", "c_n3": "C3",
	"c_s1": "C4", "c_s2": "C5", "c_s3": "C6",
	"b1": "B1", "b2": "B2",
}
## B1 (Menzoberranzan) — фиксированный якорь раскладки, как в моде TTS
## Поворот Menzoberranzan НЕ фиксируется.
##
## В моде TTS тайл B1 всегда клали повёрнутым на 240°. Владелец игры подтвердил,
## что в настоящей игре общее правило «поверни так, чтобы дать максимум
## соединений» действует и на него — фиксируется только МЕСТО (угол раскладки),
## а не поворот. С жёстким якорем 6 случайных раскладок из 180 разваливались:
## угловой тайл оставался вообще без стыковок. Без якоря — 0 из 180.
const FIXED_ROTATIONS := {}


func _optimized_rotations(seed_value: int = 12345) -> Dictionary:
	var data := BoardData.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return RotationOptimizer.optimize(
		TWO_PLAYER_HEXES,
		(data["layouts"] as Dictionary)["2"]["adjacency"],
		FIXED_ROTATIONS,
		data["edges"],
		rng
	)


func _build_two_player_board(seed_value: int = 12345) -> MapGraph:
	return BoardData.make_builder().build(2, TWO_PLAYER_HEXES, _optimized_rotations(seed_value))


func test_graph_assembly() -> void:
	section("сборка графа доски (2 игрока)")
	var graph := _build_two_player_board()

	check(graph.site_count() > 0, "сайты собраны: %d" % graph.site_count())
	check(graph.slot_count() > 0, "слоты собраны: %d" % graph.slot_count())

	var isolated := graph.isolated_slots()
	check(isolated.is_empty(), "нет изолированных слотов (найдено %d)" % isolated.size())

	# каждый сайт должен иметь хотя бы один слот
	var siteless := 0
	for site_id: String in graph.sites.keys():
		if graph.slots_of_site(site_id).is_empty():
			siteless += 1
	check_eq(siteless, 0, "у каждого сайта есть троп-слоты")

	# слоты одного сайта связаны между собой
	var great_web := ""
	for site_id: String in graph.sites.keys():
		if graph.sites[site_id]["name"] == "The Great Web":
			great_web = site_id
			break
	check(great_web != "", "The Great Web найден в собранном графе")
	if great_web != "":
		var gw_slots := graph.slots_of_site(great_web)
		check_eq(gw_slots.size(), 6, "у The Great Web 6 слотов на доске")
		var all_linked := true
		for slot_id in gw_slots:
			var linked_within := false
			for neighbour in graph.adjacent_slots(slot_id):
				if graph.site_of_slot(neighbour) == great_web:
					linked_within = true
					break
			if not linked_within:
				all_linked = false
		check(all_linked, "слоты The Great Web связаны между собой")

	# ГЛАВНАЯ проверка сборки: собранная доска должна быть единым связным графом.
	# Если компонент больше одной — часть карты недостижима и правила ломаются.
	check_eq(graph.connected_component_count(), 1,
		"собранная доска — один связный граф")

	# межгексовые связи существуют (иначе гексы просто лежат рядом)
	var cross := 0
	for slot_id: String in graph.slots.keys():
		for neighbour in graph.adjacent_slots(slot_id):
			if slot_id.split(":")[0] != neighbour.split(":")[0]:
				cross += 1
	check(cross / 2 >= 10, "гексы сшиты между собой (связей: %d)" % (cross / 2))

	# Проверка «каждый гекс внутри себя связен» удалена: она стала неверной
	# по смыслу. На части тайлов локация соединена с остальной картой ТОЛЬКО
	# прямой связью с соседней локацией (C4: Iblith через Kulggen; B2: Vrith
	# через Lolth Shrine), а на C5 у Ath-Qua вообще нет колец — она выходит
	# сразу на рёбра гекса. По слотам такие тайлы выглядят разорванными, хотя
	# карта связна. Связность целиком проверяется выше, с учётом связей локаций.

	# разметка смежности должна покрывать каждый использованный гекс
	var manual: Dictionary = BoardData.load_all()["manual"]
	var missing: Array[String] = []
	for hex_id: String in TWO_PLAYER_HEXES.values():
		if not manual.has(hex_id):
			missing.append(hex_id)
	check(missing.is_empty(), "разметка есть для всех гексов раскладки"
		+ ("" if missing.is_empty() else ": нет " + ", ".join(missing)))

	# каждое кольцо либо с чем-то связано, либо помечено как ведущее только к рёбрам
	var dangling: Array[String] = []
	for slot_id: String in graph.slots.keys():
		if not graph.is_route_slot(slot_id):
			continue
		if not graph.adjacent_slots(slot_id).is_empty():
			continue
		var hex_id: String = graph.slots[slot_id]["hex"]
		var bare := slot_id.split(":")[1]
		var edge_only: Array = (manual.get(hex_id, {}) as Dictionary).get("edge_only", [])
		if not edge_only.has(bare):
			dangling.append(slot_id)
	check(dangling.is_empty(), "нет незаявленных висящих колец"
		+ ("" if dangling.is_empty() else ": " + ", ".join(dangling)))

	# сборка воспроизводима при одном сиде и не разваливается на других
	for seed_value in [1, 7, 99, 2024]:
		var g := _build_two_player_board(seed_value)
		if g.connected_component_count() != 1:
			check(false, "доска связна при сиде %d" % seed_value)
			return
	check(true, "доска связна при разных сидах генерации")


func test_rotation_optimizer() -> void:
	section("оптимизатор поворотов")
	var data := BoardData.load_all()
	var adjacency: Array = (data["layouts"] as Dictionary)["2"]["adjacency"]
	var hex_edges: Dictionary = data["edges"]

	var rotations := _optimized_rotations()
	check_eq(rotations.size(), TWO_PLAYER_HEXES.size(), "поворот назначен каждому гексу")
	# поворот B1 больше не фиксируется, но механизм фиксации остался — им
	# пользуется рендерер и диагностика, когда надо воспроизвести раскладку
	var anchored := RotationOptimizer.optimize(
		TWO_PLAYER_HEXES, adjacency, {"b1": 240.0}, hex_edges, RandomNumberGenerator.new())
	check_eq(anchored["b1"], 240.0, "заданный поворот оптимизатор не трогает")

	var all_valid := true
	for slot_name: String in rotations.keys():
		var rot: float = rotations[slot_name]
		if not RotationOptimizer.ROTATION_CHOICES.has(rot):
			all_valid = false
	check(all_valid, "все повороты кратны 60°")

	# оптимизация должна давать не меньше стыковок, чем нулевые повороты
	var zero := {}
	for k: String in TWO_PLAYER_HEXES.keys():
		zero[k] = 0.0
	var zero_links := RotationOptimizer.count_connections(TWO_PLAYER_HEXES, adjacency, zero, hex_edges)
	var opt_links := RotationOptimizer.count_connections(TWO_PLAYER_HEXES, adjacency, rotations, hex_edges)
	check(opt_links >= zero_links,
		"оптимизация не хуже нулевых поворотов (%d против %d)" % [opt_links, zero_links])
	check(opt_links >= 12, "сомкнуто не меньше 12 рёбер из %d" % adjacency.size())

	# один сид -> один результат
	check_eq(_optimized_rotations(555), _optimized_rotations(555),
		"генерация детерминирована при одном сиде")


func test_presence_rules() -> void:
	section("правила Присутствия")

	# Ручной мини-граф — правило проверяется на понятной топологии,
	# независимо от того, что даст сборка реальной доски.
	#
	#   [site_a: a1 a2] --- r1 --- r2 --- [site_b: b1]
	#
	var graph := MapGraph.new()
	graph.add_site("site_a", "Сайт А", 4, "TEST")
	graph.add_site("site_b", "Сайт Б", 2, "TEST")
	graph.add_slot("a1", "TEST", Vector2(0, 0), "site_a")
	graph.add_slot("a2", "TEST", Vector2(1, 0), "site_a")
	graph.add_slot("b1", "TEST", Vector2(6, 0), "site_b")
	graph.add_slot("r1", "TEST", Vector2(2.5, 0), "")
	graph.add_slot("r2", "TEST", Vector2(4, 0), "")
	graph.connect_slots("a1", "a2")
	graph.connect_slots("a2", "r1")
	graph.connect_slots("r1", "r2")
	graph.connect_slots("r2", "b1")
	graph.finalize()

	var presence := Presence.new(graph)

	# 1. войско в самом сайте
	var troops := {"a1": "red"}
	var spies := {}
	check(presence.has_presence_at_site("red", "site_a", troops, spies),
		"войско в сайте даёт Присутствие на нём")
	check(not presence.has_presence_at_site("blue", "site_a", troops, spies),
		"чужое войско не даёт Присутствия сопернику")

	# 2. войско в смежном слоте
	troops = {"r1": "red"}
	check(presence.has_presence_at_site("red", "site_a", troops, spies),
		"войско в смежном маршрутном слоте даёт Присутствие на сайте")
	check(not presence.has_presence_at_site("red", "site_b", troops, spies),
		"войско через два слота Присутствия на дальнем сайте не даёт")

	# 3. шпион
	troops = {}
	spies = {"site_b": ["red"]}
	check(presence.has_presence_at_site("red", "site_b", troops, spies),
		"шпион даёт Присутствие на сайте")
	check(not presence.has_presence_at_site("red", "site_a", troops, spies),
		"шпион не даёт Присутствия на другом сайте")

	# 4. Присутствие в маршрутном слоте
	troops = {"a1": "red"}
	spies = {}
	check(presence.has_presence_at_slot("red", "r1", troops, spies),
		"маршрутный слот, смежный с сайтом со своим войском")
	check(not presence.has_presence_at_slot("red", "r2", troops, spies),
		"маршрутный слот через один — уже нет")

	troops = {"r1": "red"}
	check(presence.has_presence_at_slot("red", "r2", troops, spies),
		"маршрутный слот, смежный со своим войском")

	# 5. шпион НЕ даёт Присутствия в маршрутных слотах рядом с сайтом
	troops = {}
	spies = {"site_a": ["red"]}
	check(not presence.has_presence_at_slot("red", "r1", troops, spies),
		"шпион не распространяет Присутствие на маршрут")

	# 6. deploy: без войск на карте можно куда угодно
	troops = {}
	spies = {}
	var deployable := presence.deployable_slots("red", troops, spies)
	check_eq(deployable.size(), 5, "без войск на карте deploy доступен во все пустые слоты")

	troops = {"a1": "red"}
	deployable = presence.deployable_slots("red", troops, spies)
	check(deployable.has("a2"), "deploy в свободный слот своего сайта")
	check(deployable.has("r1"), "deploy в смежный маршрутный слот")
	check(not deployable.has("r2"), "deploy через два слота недоступен")
	check(not deployable.has("a1"), "занятый слот не предлагается")

	# 7. assassinate: только вражеские войска и только там, где есть Присутствие
	troops = {"a1": "red", "a2": "white", "b1": "blue"}
	var targets := presence.assassinatable_slots("red", troops, spies)
	check(targets.has("a2"), "белое войско в своём сайте — легальная цель")
	check(not targets.has("a1"), "своё войско целью быть не может")
	check(not targets.has("b1"), "войско вне зоны Присутствия недоступно")


func test_control_rules() -> void:
	section("правила контроля")

	var graph := MapGraph.new()
	graph.add_site("site", "Тест", 5, "TEST")
	graph.add_slot("s1", "TEST", Vector2(0, 0), "site")
	graph.add_slot("s2", "TEST", Vector2(1, 0), "site")
	graph.add_slot("s3", "TEST", Vector2(2, 0), "site")
	graph.finalize()

	var control := SiteControl.new(graph)

	check_eq(control.controller_of("site", {}), "", "пустой сайт никем не контролируется")
	check_eq(control.controller_of("site", {"s1": "red"}), "red", "одно войско даёт контроль")
	check_eq(control.controller_of("site", {"s1": "red", "s2": "blue"}), "",
		"равенство войск снимает контроль")
	check_eq(control.controller_of("site", {"s1": "red", "s2": "red", "s3": "blue"}), "red",
		"перевес даёт контроль")
	check_eq(control.controller_of("site", {"s1": "white", "s2": "white", "s3": "red"}), "",
		"белые войска мешают контролю, но сами не контролируют")

	check(control.has_total_control("red", "site", {"s1": "red", "s2": "red", "s3": "red"}, {}),
		"все слоты своими войсками = тотальный контроль")
	check(not control.has_total_control("red", "site", {"s1": "red", "s2": "red"}, {}),
		"незаполненный слот снимает тотальный контроль")
	check(not control.has_total_control(
			"red", "site", {"s1": "red", "s2": "red", "s3": "red"}, {"site": ["blue"]}),
		"вражеский шпион снимает тотальный контроль")
	check(control.has_total_control(
			"red", "site", {"s1": "red", "s2": "red", "s3": "red"}, {"site": ["red"]}),
		"свой шпион тотальному контролю не мешает")

	check_eq(control.map_score("red", {"s1": "red"}, {}), 5, "контроль = VP сайта")
	check_eq(control.map_score("red", {"s1": "red", "s2": "red", "s3": "red"}, {}), 7,
		"тотальный контроль = VP сайта + 2")


## Прямая связь локаций проверяется на ОТДЕЛЬНОМ графе: подмешивать её в общий
## мини-граф нельзя — она меняет достижимость и ломает более ранние проверки
## («войско вне зоны Присутствия недоступно» переставало быть верным).
func test_dead_ends_pruned() -> void:
	section("тупики: кольца, ведущие не дальше одного соседа, убраны")

	# Синтетика: A - r1 - B, и хвост A - r2 - r3 в никуда.
	var graph := MapGraph.new()
	graph.add_site("A", "A", 1, "T")
	graph.add_site("B", "B", 1, "T")
	for id in ["a0", "a1"]:
		graph.add_slot(id, "T", Vector2.ZERO, "A")
	graph.add_slot("b0", "T", Vector2.ZERO, "B")
	for id in ["r1", "r2", "r3"]:
		graph.add_slot(id, "T", Vector2.ZERO)
	graph.connect_slots("a0", "r1")
	graph.connect_slots("r1", "b0")
	# r2 касается двух мест одной локации — это всё равно один сосед
	graph.connect_slots("a0", "r2")
	graph.connect_slots("a1", "r2")
	graph.connect_slots("r2", "r3")
	var removed := graph.prune_dead_ends()
	removed.sort()
	check_eq(Array(removed), ["r2", "r3"], "хвост убран цепочкой, проходное кольцо осталось")
	check(not graph.adjacent_slots("a0").has("r2"), "у локации не осталось связи с удалённым кольцом")
	check(graph.slots.has("a1") and graph.slots.has("r1"), "места локаций и проходные кольца на месте")

	# Настоящие доски: ни одного тупика не осталось.
	for players in [2, 3, 4]:
		var ids: Array[String] = []
		ids.assign(["red", "blue", "green", "purple"].slice(0, players))
		var state := GameSetup.new_game(ids, 7)
		var dead := 0
		for slot_id: String in state.graph.slots:
			if not state.graph.is_route_slot(slot_id):
				continue
			var near := {}
			for other in state.graph.adjacent_slots(slot_id):
				var site := state.graph.site_of_slot(other)
				near[site if site != "" else other] = true
			if near.size() <= 1:
				dead += 1
		check_eq(dead, 0, "на %d игроков тупиков нет" % players)


func test_direct_site_links() -> void:
	section("прямая связь локаций (туннель без троп-слотов)")

	var graph := MapGraph.new()
	graph.add_site("site_a", "Локация А", 4, "TEST")
	graph.add_site("site_b", "Локация Б", 2, "TEST")
	graph.add_site("site_c", "Локация В", 3, "TEST")
	graph.add_slot("a1", "TEST", Vector2(0, 0), "site_a")
	graph.add_slot("b1", "TEST", Vector2(4, 0), "site_b")
	graph.add_slot("c1", "TEST", Vector2(9, 0), "site_c")
	graph.connect_sites("site_a", "site_b")
	graph.finalize()

	var presence := Presence.new(graph)
	var spies := {}

	check(presence.has_presence_at_site("red", "site_b", {"a1": "red"}, spies),
		"войско в соединённой локации даёт Присутствие")
	check(presence.has_presence_at_site("red", "site_a", {"b1": "red"}, spies),
		"связь работает в обе стороны")
	check(not presence.has_presence_at_site("red", "site_c", {"a1": "red"}, spies),
		"на несоединённую локацию Присутствие не распространяется")
	check(not presence.has_presence_at_site("red", "site_b", {}, spies),
		"без войск прямая связь Присутствия не даёт")
	check(not presence.has_presence_at_site("blue", "site_b", {"a1": "red"}, spies),
		"чужое войско Присутствия сопернику не даёт")

	# связь НЕ транзитивна: A-B и B-C не делают A смежной с C
	graph.connect_sites("site_b", "site_c")
	check(not presence.has_presence_at_site("red", "site_c", {"a1": "red"}, spies),
		"связь не транзитивна: через две локации Присутствия нет")

	# действия работают там же, где есть Присутствие
	var targets := presence.assassinatable_slots("red", {"a1": "red", "b1": "white"}, spies)
	check(targets.has("b1"), "войско в соединённой локации можно атаковать")
	var far := presence.assassinatable_slots("red", {"a1": "red", "c1": "white"}, spies)
	check(not far.has("c1"), "войско через две локации атаковать нельзя")

	# достижимость учитывает связь локаций
	check(graph.reachable_slots("a1").has("b1"),
		"слот соединённой локации достижим")
	check_eq(graph.connected_component_count(), 1,
		"связь локаций объединяет компоненты")


## Туннель с ребра гекса ведёт туда, куда нарисован, а не в ближайший к ребру
## узел. Найдено в партии: войско за SW-ребром C4 давало Присутствие на кольце
## между Red Gate и Caer Sidi, хотя туннель идёт прямо в Red Gate.
func test_edge_ports_follow_art() -> void:
	section("порты рёбер по арту (edge_ports)")
	var builder := BoardData.make_builder()
	check_eq(builder.port_name("C4", "SW"), "C4_0_0", "C4 SW ведёт в Red Gate")
	check_eq(builder.port_name("C4", "NW"), "C4_0_0", "C4 NW ведёт в Red Gate")
	check_eq(builder.port_name("X4", "S").begins_with("X4_route"), false, "X4 S ведёт в Fountain of Screams")

	var graph := builder.build(2, TWO_PLAYER_HEXES, _optimized_rotations(1))
	var ring := ""
	for slot_id: String in graph.slots.keys():
		if slot_id.ends_with(":C4_route0"):
			ring = slot_id
	check(ring != "", "кольцо C4_route0 есть на доске")
	for neighbour in graph.adjacent_slots(ring):
		check(graph.site_of_slot(neighbour) != "",
			"у C4_route0 соседи только слоты локаций (не кольцо соседнего гекса): " + neighbour)


# --- этап 2: базовый цикл хода ----------------------------------------------

## Общая мини-топология для тестов действий: сайт A (a1, a2) — маршрут (r1, r2)
## — сайт B (b1). Та же форма, что в test_presence_rules, переиспользуется
## здесь, чтобы не пересобирать граф в каждом тесте действий.
func _build_ab_graph() -> MapGraph:
	var graph := MapGraph.new()
	graph.add_site("site_a", "Сайт А", 4, "TEST")
	graph.add_site("site_b", "Сайт Б", 2, "TEST")
	graph.add_slot("a1", "TEST", Vector2(0, 0), "site_a")
	graph.add_slot("a2", "TEST", Vector2(1, 0), "site_a")
	graph.add_slot("b1", "TEST", Vector2(6, 0), "site_b")
	graph.add_slot("r1", "TEST", Vector2(2.5, 0), "")
	graph.add_slot("r2", "TEST", Vector2(4, 0), "")
	graph.connect_slots("a1", "a2")
	graph.connect_slots("a2", "r1")
	graph.connect_slots("r1", "r2")
	graph.connect_slots("r2", "b1")
	graph.finalize()
	return graph


func _build_two_player_state() -> GameState:
	var state := GameState.new(_build_ab_graph(), 777)
	state.add_player("red", [])
	state.add_player("blue", [])
	return state


func test_vp_bank() -> void:
	section("банк VP-токенов")
	var bank := VPBank.new(2, 1)  # 2×1 + 1×5 = 7 всего
	check_eq(bank.grant(6), 6, "6 = одна пятёрка плюс одна единица")
	check_eq(bank.fives, 0, "пятёрка потрачена")
	check_eq(bank.ones, 1, "одна единица осталась")

	var poor := VPBank.new(2, 0)  # только единицы
	check_eq(poor.grant(5), 2, "запрошено 5, а в банке только 2 единицы — выдано 2")
	check_eq(poor.ones, 0, "банк опустошён")
	check_eq(poor.grant(1), 0, "из пустого банка ничего не выдать")

	check_eq(VPBank.new().total_remaining(), 40 + 16 * 5, "полный банк = 120 VP")


func test_deck() -> void:
	section("колода игрока (Deck)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var cards: Array[String] = ["c0", "c1", "c2", "c3", "c4"]
	var deck := Deck.new(cards)
	check_eq(deck.draw_pile.size(), 5, "стартовая колода — 5 карт")

	var drawn := deck.draw_up_to(5, rng)
	check_eq(drawn, 5, "добрано 5 карт")
	check_eq(deck.hand.size(), 5, "рука — 5 карт")
	check(deck.draw_pile.is_empty(), "колода добора пуста")
	check(not deck.draw_one(rng), "добор из пустых колоды и сброса невозможен")

	check(deck.play_from_hand("c2"), "c2 разыграна из руки")
	check(not deck.hand.has("c2"), "c2 больше не в руке")
	check(deck.played_pile.has("c2"), "c2 в played_pile")
	check(not deck.play_from_hand("не в руке"), "нельзя разыграть карту, которой нет в руке")

	check(deck.promote("c2"), "c2 промоутирована")
	check(deck.inner_circle.has("c2"), "c2 во Внутреннем круге")
	check(not deck.played_pile.has("c2"), "c2 больше не в played_pile")
	check(not deck.promote("c2"), "повторный promote той же карты не проходит")

	deck.end_of_turn_discard()
	check_eq(deck.hand.size(), 0, "рука пуста после сброса")
	check_eq(deck.played_pile.size(), 0, "played_pile пуст после сброса")
	check_eq(deck.discard_pile.size(), 4, "в сбросе 4 карты (5 - промоутированная c2)")

	# reshuffle: добор снова наполняет колоду из сброса
	check(deck.draw_one(rng), "добор перетасовывает сброс в колоду")
	check_eq(deck.discard_pile.size(), 0, "сброс перешёл в колоду добора")
	check_eq(deck.hand.size(), 1, "в руке одна добранная карта")

	var outside := deck.cards_outside_inner_circle()
	check(not outside.has("c2"), "c2 (во Внутреннем круге) не считается по deck-VP")
	check_eq(outside.size(), 4, "вне Внутреннего круга — 4 карты")


func test_market() -> void:
	section("маркет")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5

	var half_a: Array[String] = []
	var half_b: Array[String] = []
	for i in range(10):
		half_a.append("a%d" % i)
		half_b.append("b%d" % i)

	var market := Market.build(half_a, half_b, rng)
	check_eq(market.display.size(), Market.DISPLAY_SIZE, "дисплей — 6 карт")
	check_eq(market.deck.size(), 20 - Market.DISPLAY_SIZE, "колода маркета = 20 - 6 открытых")
	var empty_slots := 0
	for c: String in market.display:
		if c == "":
			empty_slots += 1
	check_eq(empty_slots, 0, "в дисплее нет пустых слотов, пока колода не кончилась")

	var recruited := market.recruit_at(0)
	check(recruited != "", "recruit_at(0) вернул карту")
	check(market.display[0] != "", "слот 0 пополнен из колоды маркета")
	check_eq(market.deck.size(), 20 - Market.DISPLAY_SIZE - 1, "колода маркета уменьшилась на одну")

	check_eq(market.recruit_at(-1), "", "неверный индекс — пустая строка")
	check_eq(market.recruit_at(99), "", "индекс за пределами дисплея — пустая строка")

	# исчерпание колоды маркета
	var tiny := Market.build(["x0", "x1", "x2"], ["x3", "x4", "x5"], rng)
	check(tiny.is_deck_empty(), "колода маркета из 6 карт вся ушла на дисплей")
	var got := tiny.recruit_at(0)
	check(got != "", "рекрут ещё возможен из уже открытого дисплея")
	check_eq(tiny.display[0], "", "пополнить нечем — слот остаётся пустым")
	check_eq(tiny.recruit_at(0), "", "из пустого слота больше нечего рекрутировать")


func test_actions_deploy() -> void:
	section("действие: Deploy")
	var state := _build_two_player_state()
	var red: PlayerState = state.players["red"]

	red.power = 0
	check(not Actions.deploy(state, "red", "a1"), "без Power развернуть нельзя")

	red.power = 1
	check(Actions.deploy(state, "red", "a1"), "deploy в свободный слот (Присутствия ещё нет ни у кого)")
	check_eq(state.troops["a1"], "red", "войско встало в a1")
	check_eq(red.troops_in_barracks, PlayerState.STARTING_TROOPS - 1, "барак уменьшился на одно войско")
	check_eq(red.power, 0, "Power списан")

	red.power = 1
	check(not Actions.deploy(state, "red", "b1"), "deploy вне зоны Присутствия недоступен")

	# развёртывание последнего войска запускает конец игры
	red.troops_in_barracks = 1
	red.power = 1
	check(Actions.deploy(state, "red", "a2"), "разворачивает последнее войско")
	check_eq(red.troops_in_barracks, 0, "барак опустел")
	check(state.game_end_triggered, "конец игры запущен разворачиванием последнего войска")
	check_eq(state.game_end_reason, "last_troop", "причина конца игры — last_troop")

	# при пустом бараке deploy даёт 1 VP вместо развёртывания
	var vp_before := red.vp_tokens
	red.power = 1
	var troops_before := state.troops.duplicate()
	check(Actions.deploy(state, "red", "b1"), "deploy с пустым бараком проходит как действие")
	check_eq(red.vp_tokens, vp_before + 1, "вместо войска — 1 VP")
	check_eq(state.troops, troops_before, "доска не изменилась (b1 не занят)")


func test_actions_assassinate() -> void:
	section("действие: Assassinate")
	var state := _build_two_player_state()
	var red: PlayerState = state.players["red"]

	state.troops["r2"] = "red"
	state.troops["b1"] = "blue"

	red.power = 2
	check(not Actions.assassinate(state, "red", "b1"), "3 Power не хватает — только 2")

	red.power = 3
	check(not Actions.assassinate(state, "red", "a1"), "на a1 никого нет — нельзя ассасинировать пустой слот")

	check(Actions.assassinate(state, "red", "b1"),
		"red ассасинирует войско blue на b1 — Присутствие есть через r2")
	check_eq(state.troops["b1"], "", "b1 опустел")
	check_eq(red.trophy_hall_count, 1, "убитое войско в трофи-холле")
	check_eq(red.power, 0, "Power списан")

	# нельзя ассасинировать своё войско
	state.troops["a1"] = "red"
	red.power = 3
	check(not Actions.assassinate(state, "red", "a1"), "своё войско ассасинировать нельзя")

	# без Присутствия в зоне цели действие недоступно
	var fresh := _build_two_player_state()
	fresh.troops["b1"] = "blue"
	var red2: PlayerState = fresh.players["red"]
	red2.power = 3
	check(not Actions.assassinate(fresh, "red", "b1"), "без Присутствия рядом с b1 ассасинация недоступна")


func test_actions_return_spy() -> void:
	section("действие: Return an enemy spy")
	var state := _build_two_player_state()
	var red: PlayerState = state.players["red"]
	var blue: PlayerState = state.players["blue"]

	state.troops["r2"] = "red"  # Присутствие на site_b через смежный маршрутный слот
	state.spies["site_b"] = ["blue"]
	var blue_spies_before := blue.spies_in_barracks

	red.power = 2
	check(not Actions.return_enemy_spy(state, "red", "site_b", "blue"), "3 Power не хватает")

	red.power = 3
	check(not Actions.return_enemy_spy(state, "red", "site_b", "red"),
		"нельзя вернуть свой собственный шпион этим действием")
	check_eq(red.power, 3, "неудачная попытка не тратит Power")

	check(Actions.return_enemy_spy(state, "red", "site_b", "blue"),
		"red возвращает шпиона blue на site_b")
	check_eq((state.spies["site_b"] as Array).size(), 0, "шпион убран с сайта")
	check_eq(blue.spies_in_barracks, blue_spies_before + 1, "шпион вернулся в барак blue")
	check_eq(red.power, 0, "Power списан")

	# без Присутствия действие недоступно
	var fresh := _build_two_player_state()
	fresh.spies["site_b"] = ["blue"]
	var red2: PlayerState = fresh.players["red"]
	red2.power = 3
	check(not Actions.return_enemy_spy(fresh, "red", "site_b", "blue"),
		"без Присутствия на site_b шпиона не вернуть")


func test_actions_recruit() -> void:
	section("действие: Recruit")
	var state := _build_two_player_state()
	var red: PlayerState = state.players["red"]

	var half_a: Array[String] = []
	var half_b: Array[String] = []
	for i in range(10):
		half_a.append("m%d" % i)
		half_b.append("n%d" % i)
	state.market = Market.build(half_a, half_b, state.rng)

	red.influence = 2
	check(not Actions.recruit(state, "red", 0, 5), "не хватает Influence на карту стоимостью 5")

	red.influence = 5
	var target_card: String = state.market.display[0]
	check(Actions.recruit(state, "red", 0, 5), "рекрут карты стоимостью 5 при 5 Influence")
	check_eq(red.influence, 0, "Influence списан")
	check(red.deck.discard_pile.has(target_card), "рекрутированная карта — в сбросе игрока")
	check(state.market.display[0] != "", "слот дисплея пополнен")

	red.influence = 10
	check(not Actions.recruit(state, "red", 99, 1), "неверный индекс дисплея — отказ")

	# рекрут из уже опустевшего маркета не роняет игру и корректно завершает конец игры
	var tiny_state := _build_two_player_state()
	tiny_state.market = Market.build(["t0", "t1", "t2"], ["t3", "t4", "t5"], tiny_state.rng)
	var red3: PlayerState = tiny_state.players["red"]
	red3.influence = 100
	check(not tiny_state.game_end_triggered, "колода маркета из 6 карт ещё не считается пройденной до рекрута")
	check(Actions.recruit(tiny_state, "red", 0, 0), "рекрут проходит даже когда пополнять нечем")
	check(tiny_state.game_end_triggered, "рекрут из исчерпанного маркета запускает конец игры")
	check_eq(tiny_state.game_end_reason, "market_empty", "причина конца игры — market_empty")


func test_turn_engine() -> void:
	section("конец хода (TurnEngine)")
	var state := _build_two_player_state()
	var red: PlayerState = state.players["red"]

	# red тотально контролирует site_a (vp 4 + 2 за тотальный контроль = 6)
	state.troops["a1"] = "red"
	state.troops["a2"] = "red"

	var cards: Array[String] = []
	for i in range(10):
		cards.append("c%d" % i)
	red.deck = Deck.new(cards)
	red.deck.draw_up_to(5, state.rng)  # рука: 5 карт, в колоде осталось 5
	check(red.deck.play_from_hand(red.deck.hand[0]), "разыграна первая карта")
	var promoted_card: String = red.deck.hand[0]
	check(red.deck.play_from_hand(promoted_card), "разыграна вторая карта (её промоутируем)")
	red.pending_promotions = [promoted_card]

	red.power = 3
	red.influence = 2
	var vp_before := red.vp_tokens

	TurnEngine.end_turn(state, "red")

	check(red.deck.inner_circle.has(promoted_card), "карта из pending_promotions ушла во Внутренний круг")
	check(red.pending_promotions.is_empty(), "очередь promote очищена")
	# VP за контроль ОБЫЧНОЙ локации в течение партии не начисляются (правило
	# уточнено владельцем игры 2026-09-14) — они попадут в финальный подсчёт.
	check_eq(red.vp_tokens, vp_before, "за контроль обычной локации VP в ход НЕ начисляются")
	check_eq(state.control.map_score("red", state.troops, state.spies), 6,
		"но в финальном подсчёте тотальный контроль site_a даст 6 VP")
	check_eq(red.deck.hand.size(), 5, "рука снова добрана до 5")
	check_eq(red.deck.discard_pile.size(), 4, "в сбросе 2 разыгранные (минус промоутированная) + 3 оставшиеся в руке")
	check_eq(red.power, 0, "Power сгорел")
	check_eq(red.influence, 0, "Influence сгорел")


func test_game_end() -> void:
	section("конец партии: доигровка круга")
	var state := GameState.new(_build_ab_graph(), 1)
	state.add_player("p1", [])
	state.add_player("p2", [])
	state.add_player("p3", [])
	state.current_player_index = 1  # p2 запускает триггер прямо сейчас

	GameEnd.trigger(state, "market_empty")
	check_eq(state.final_round_ends_after_index, 0, "круг доигрывается до p1 (индекс перед p2)")

	GameEnd.trigger(state, "last_troop")
	check_eq(state.game_end_reason, "market_empty", "повторный триггер не переписывает причину")

	# p2 (индекс 1) заканчивает ход — это не последний ход круга
	check(not GameEnd.advance_turn(state), "после p2 партия ещё не закончена")
	check_eq(state.current_player_index, 2, "ход переходит к p3")

	check(not GameEnd.advance_turn(state), "после p3 партия ещё не закончена")
	check_eq(state.current_player_index, 0, "ход переходит к p1")

	check(GameEnd.advance_turn(state), "после p1 партия заканчивается")
	check(state.game_over, "game_over выставлен")


func test_scoring() -> void:
	section("финальный подсчёт")
	var state := _build_two_player_state()
	var red: PlayerState = state.players["red"]
	var blue: PlayerState = state.players["blue"]

	# red тотально контролирует site_a (4 + 2), blue контролирует site_b (2)
	state.troops["a1"] = "red"
	state.troops["a2"] = "red"
	state.troops["b1"] = "blue"

	red.trophy_hall_count = 2
	red.vp_tokens = 7
	red.deck = Deck.new(["c1", "c2"])
	red.deck.hand = ["c3"]
	red.deck.inner_circle = ["c9"]

	var deck_vp := {"c1": 3, "c2": 1, "c3": 0}
	var inner_vp := {"c9": 5}

	var red_score := Scoring.final_score(state, "red", deck_vp, inner_vp)
	check_eq(red_score, 6 + 2 + (3 + 1 + 0) + 5 + 7, "итог red = сайты + трофи + deck-VP + inner-VP + токены")

	blue.vp_tokens = 0
	var blue_score := Scoring.final_score(state, "blue", deck_vp, inner_vp)
	# site_b в этом мини-графе — один слот, так что контроль в нём автоматически
	# тотальный (2 VP + 2 за тотальный контроль)
	check_eq(blue_score, 4, "итог blue = VP site_b + тотальный контроль (единственный слот занят)")

	blue.vp_tokens = red_score - blue_score  # уравнять счёт
	var tied := Scoring.winners(state, deck_vp, inner_vp)
	check_eq(tied.size(), 2, "при равном счёте побеждают оба")

	blue.vp_tokens = 0
	var single := Scoring.winners(state, deck_vp, inner_vp)
	check_eq(single.size(), 1, "при разном счёте победитель один")
	check_eq(single[0], "red", "red набрал больше")


## Граф с тремя сайтами гекса A2 (по 3 слота, как на настоящем тайле —
## claude/progress.md, арт Demonweb v2.2) плюс контрольным "лишним" сайтом,
## чтобы отличать бонус A2 от обычного site-control.
func _build_a2_graph() -> MapGraph:
	var graph := MapGraph.new()
	graph.add_site("fogtown", "Fogtown", 4, "A2")
	graph.add_site("gallenghast", "Gallenghast", 4, "A2")
	graph.add_site("darkflame", "Darkflame", 4, "A2")
	graph.add_site("elsewhere", "Где-то ещё", 3, "TEST")
	for prefix in ["fogtown", "gallenghast", "darkflame"]:
		for i in range(3):
			graph.add_slot("%s_%d" % [prefix, i], "A2", Vector2(i, 0), prefix)
	graph.add_slot("else_0", "TEST", Vector2(9, 9), "elsewhere")
	graph.finalize()
	return graph


func test_cluster_bonus() -> void:
	section("региональный бонус гекса A2 (Demonweb)")

	# на доске без гекса A2 бонуса нет вообще
	var no_a2 := GameState.new(_build_ab_graph(), 1)
	no_a2.add_player("red", [])
	check_eq(ClusterBonus.find_site_ids(no_a2.graph).size(), 0,
		"без гекса A2 на столе find_site_ids пуст")
	var empty_reward: ClusterBonus.Reward = ClusterBonus.evaluate(no_a2, "red")
	check_eq(empty_reward.vp, 0, "без гекса A2 бонуса нет даже при полном совпадении имён по случайности")

	var state := GameState.new(_build_a2_graph(), 2)
	state.add_player("red", [])
	state.add_player("blue", [])
	var red: PlayerState = state.players["red"]
	var blue: PlayerState = state.players["blue"]

	check_eq(ClusterBonus.find_site_ids(state.graph).size(), 3, "гекс A2 найден по трём именам")

	# ничего ни у кого нет
	var r0: ClusterBonus.Reward = ClusterBonus.evaluate(state, "red")
	check_eq(r0.power, 0, "нет войск нигде — Power 0")
	check_eq(r0.influence, 0, "нет войск нигде — Influence 0")
	check_eq(r0.vp, 0, "нет войск нигде — VP 0")

	# ярус 1: войска (необязательно контроль) на всех трёх сразу — доступен
	# НЕСКОЛЬКИМ игрокам одновременно, если оба держат войска на каждом сайте
	state.troops["fogtown_0"] = "red"
	state.troops["gallenghast_0"] = "red"
	state.troops["darkflame_0"] = "red"
	state.troops["fogtown_1"] = "blue"
	state.troops["gallenghast_1"] = "blue"
	state.troops["darkflame_1"] = "blue"
	var r_troops: ClusterBonus.Reward = ClusterBonus.evaluate(state, "red")
	check_eq(r_troops.influence, 1, "тир 'troops in all 3': 1 Influence")
	check_eq(r_troops.power, 0, "тир 'troops in all 3' не даёт Power")
	check_eq(r_troops.vp, 0, "тир 'troops in all 3' не даёт VP")
	var b_troops: ClusterBonus.Reward = ClusterBonus.evaluate(state, "blue")
	check_eq(b_troops.influence, 1, "тир 'troops in all 3' доступен ОБОИМ игрокам одновременно")

	# войско хотя бы на одном сайте отсутствует — тир не выполнен
	state.troops.erase("darkflame_1")
	var b_missing: ClusterBonus.Reward = ClusterBonus.evaluate(state, "blue")
	check_eq(b_missing.influence, 0, "без войска хотя бы на одном из трёх — бонуса нет")
	state.troops["darkflame_1"] = "blue"

	# ярус 2: red контролирует все три (2 войска против 1 на каждом)
	state.troops["fogtown_2"] = "red"
	state.troops["gallenghast_2"] = "red"
	state.troops["darkflame_2"] = "red"
	var r_control: ClusterBonus.Reward = ClusterBonus.evaluate(state, "red")
	check_eq(r_control.influence, 1, "тир 'control all 3': 1 Influence")
	check_eq(r_control.power, 1, "тир 'control all 3': 1 Power")
	check_eq(r_control.vp, 1, "тир 'control all 3': 1 VP")
	var b_control: ClusterBonus.Reward = ClusterBonus.evaluate(state, "blue")
	check_eq(b_control.power, 0, "blue не контролирует все три — Power за 'control all 3' не получает")
	check_eq(b_control.influence, 1,
		"замена яруса — только у самого red (кто дотянулся до контроля); blue по-прежнему держит войска на всех трёх и получает свой отдельный тир 'troops in all 3'")

	# ярус 3: red занимает ВСЕ слоты всех трёх сайтов = тотальный контроль
	for prefix in ["fogtown", "gallenghast", "darkflame"]:
		for i in range(3):
			state.troops["%s_%d" % [prefix, i]] = "red"
	var r_total: ClusterBonus.Reward = ClusterBonus.evaluate(state, "red")
	check_eq(r_total.influence, 2, "тир 'total control of all 3': 2 Influence")
	check_eq(r_total.power, 2, "тир 'total control of all 3': 2 Power")
	check_eq(r_total.vp, 4, "тир 'total control of all 3': 4 VP (не 1+4 — тиры не складываются)")

	# интеграция с TurnEngine: Power/Influence — в начале хода, VP — в конце
	red.power = 0
	red.influence = 0
	var vp_before := red.vp_tokens
	TurnEngine.start_turn(state, "red")
	check_eq(red.power, 2, "start_turn начислил Power бонуса A2")
	check_eq(red.influence, 2, "start_turn начислил Influence бонуса A2")

	red.deck = Deck.new(["z0", "z1", "z2", "z3", "z4"])
	red.deck.draw_up_to(5, state.rng)
	TurnEngine.end_turn(state, "red")
	# Обычные локации кластера VP в ход не приносят — только бонус гекса A2 (4).
	check_eq(red.vp_tokens, vp_before + 4, "end_turn начислил только VP бонуса A2")
	check_eq(state.control.map_score("red", state.troops, state.spies), 18,
		"18 VP за эти три локации будут засчитаны в конце игры, а не каждый ход")


# --- этап 5: инфраструктура для тестов системы эффектов ---------------------

## Настоящая (не игрушечная) доска на 2 игроков + третий подключённый вручную
## игрок "green" (для карт с "each opponent"/"choose an opponent") — с плотно
## расставленными войсками/шпионами/картами, чтобы у большинства эффектов
## почти всегда нашлась легальная цель.
func _build_rich_state(seed_value: int = 99) -> GameState:
	var data := BoardData.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var layout: Dictionary = (data["layouts"] as Dictionary)["2"]
	var adjacency: Array = layout["adjacency"]

	var hex_by_slot := {}
	# небольшой детерминированный набор гексов на 2 игроков, без X-гексов
	var centers: Array = ["A1"]
	var ring: Array = ["C1", "C2", "C3", "C4", "C5", "C6"]
	hex_by_slot["center"] = centers[0]
	var ring_names: Array = ["c0", "c1", "c2", "c3", "c4", "c5"]
	for i in range(ring.size()):
		hex_by_slot[ring_names[i]] = ring[i]
	hex_by_slot["b1"] = "B1"
	hex_by_slot["b2"] = "B2"

	var rotations := RotationOptimizer.optimize(hex_by_slot, adjacency, {}, data["edges"], rng)
	var graph: MapGraph = BoardData.make_builder().build(2, hex_by_slot, rotations)

	var state := GameState.new(graph, seed_value)
	state.add_player("red", [])
	state.add_player("blue", [])
	state.add_player("green", [])

	var slot_ids: Array = graph.slots.keys()
	slot_ids.sort()

	# расставляем войска по кругу: red, blue, green, white, пусто, повтор...
	var owners: Array[String] = ["red", "blue", "green", "white", ""]
	for i in range(slot_ids.size()):
		var owner: String = owners[i % owners.size()]
		if owner != "":
			state.troops[slot_ids[i]] = owner

	var site_ids: Array = graph.sites.keys()
	site_ids.sort()
	for i in range(site_ids.size()):
		var site_id: String = site_ids[i]
		var spy_owner: String = ["red", "blue", "green"][i % 3]
		state.spies[site_id] = [spy_owner]

	# карточные пулы: набор реальных card_id, кроме карты, которая будет
	# подставлена в руку самим тестом.
	var sample_ids: Array[String] = ["48342", "48344", "48343", "48340", "48336", "48331"]
	for pid: String in state.turn_order:
		var p: PlayerState = state.players[pid]
		p.deck = Deck.new(sample_ids.duplicate())
		p.deck.hand = sample_ids.duplicate()
		p.deck.discard_pile = sample_ids.duplicate()
		p.deck.inner_circle = sample_ids.duplicate()
		p.power = 20
		p.influence = 20
		p.troops_in_barracks = 30
		p.spies_in_barracks = 3
		p.trophy_hall_count = 6
		p.white_trophy_count = 3

	var half_a: Array[String] = sample_ids.duplicate()
	var half_b: Array[String] = sample_ids.duplicate()
	half_a.append_array(sample_ids)
	half_b.append_array(sample_ids)
	state.market = Market.build(half_a, half_b, state.rng)

	return state


## Отвечает на pending_decision максимально "активно" (реальная цель вместо
## "" / -1, вторая ветка choose_one, true на confirm), чтобы прогнать как
## можно больше кода эффекта. Возвращает число прогонов (для контроля
## отсутствия зависаний).
func _auto_resolve(state: GameState, resolver: EffectResolver, prefer_last: bool) -> int:
	var steps := 0
	while resolver.is_waiting() and steps < 40:
		steps += 1
		var pd: PendingDecision = resolver.pending
		var options: Array = pd.legal_options
		var answer = null
		if options.is_empty():
			break
		match pd.choice_type:
			"confirm":
				answer = prefer_last
			"choose_option":
				answer = (options.size() - 1) if prefer_last else 0
			_:
				# ищем первый "настоящий" вариант (не "" и не -1)
				answer = options[0]
				for opt in options:
					var is_skip: bool = (typeof(opt) == TYPE_STRING and opt == "") or (typeof(opt) == TYPE_INT and opt == -1)
					if not is_skip:
						answer = opt
						if not prefer_last:
							break
		TurnEngine.resume_card(state, answer, resolver)
	return steps


func test_effect_resolver_basics() -> void:
	section("EffectResolver: базовый стек и pending_decision")
	var state := _build_rich_state()
	var resolver := EffectResolver.new()
	var red: PlayerState = state.players["red"]
	var before := red.power

	resolver.apply(GainPower.new(3), "red", state)
	check_eq(red.power, before + 3, "простой эффект применяется синхронно, без pending")
	check(not resolver.is_waiting(), "резолвер не ждёт решения после простого эффекта")

	var seq := SequenceEffect.new([GainPower.new(1), GainInfluence.new(2)])
	var inf_before := red.influence
	resolver.apply(seq, "red", state)
	check_eq(red.power, before + 3 + 1, "SequenceEffect применяет оба под-эффекта")
	check_eq(red.influence, inf_before + 2, "SequenceEffect сохраняет порядок")


func test_choose_and_optional() -> void:
	section("ChooseEffect / OptionalEffect")
	var state := _build_rich_state()
	var red: PlayerState = state.players["red"]
	var resolver := EffectResolver.new()

	var choose := ChooseEffect.new([GainPower.new(5), GainInfluence.new(5)], ["power", "influence"])
	resolver.apply(choose, "red", state)
	check(resolver.is_waiting(), "ChooseEffect останавливается и ждёт выбора")
	check_eq(resolver.pending.choice_type, "choose_option", "choice_type = choose_option")

	var power_before := red.power
	resolver.resume(state, 0)
	check_eq(red.power, power_before + 5, "выбор варианта 0 применяет первый эффект")
	check(not resolver.is_waiting(), "после ответа резолвер снова свободен")

	var opt := OptionalEffect.new(GainPower.new(7))
	var resolver2 := EffectResolver.new()
	resolver2.apply(opt, "red", state)
	var p2 := red.power
	resolver2.resume(state, false)
	check_eq(red.power, p2, "OptionalEffect с ответом false ничего не применяет")

	var opt2 := OptionalEffect.new(GainPower.new(7))
	var resolver3 := EffectResolver.new()
	resolver3.apply(opt2, "red", state)
	resolver3.resume(state, true)
	check_eq(red.power, p2 + 7, "OptionalEffect с ответом true применяет вложенный эффект")


func test_focus_effect() -> void:
	section("FocusEffect: бонус за повторный аспект в этот ход")
	var state := _build_rich_state()
	var resolver := EffectResolver.new()
	var red: PlayerState = state.players["red"]
	TurnEngine.start_turn(state, "red")
	check(state.played_aspects_this_turn.is_empty(), "played_aspects_this_turn сброшен в начале хода")

	var hand: Array[String] = ["48342", "48342"]  # Noble (Obedience) only
	red.deck.hand = hand
	var focus := FocusEffect.new("GUILE", GainPower.new(9))
	var before := red.power
	resolver.apply(focus, "red", state)
	check_eq(red.power, before, "Focus не срабатывает, если это первый Guile-эффект за ход")

	red.deck.hand.append("48336")  # Spy Master (Guile) — can be revealed from hand
	resolver.apply(focus, "red", state)
	check_eq(red.power, before + 9, "Focus triggers when a card of that aspect can be revealed from hand")
	red.deck.hand = hand.duplicate()

	state.played_aspects_this_turn.append("GUILE")
	state.played_aspects_this_turn.append("GUILE")
	resolver.apply(focus, "red", state)
	check_eq(red.power, before + 18, "Focus срабатывает, если Guile уже был в этот ход раньше")


func test_deploy_and_assassinate_effects() -> void:
	section("DeployTroop / AssassinateTroop / MoveTroop (примитивы)")
	var state := _build_rich_state()
	var red: PlayerState = state.players["red"]
	var resolver := EffectResolver.new()

	var barracks_before := red.troops_in_barracks
	resolver.apply(DeployTroop.new(2), "red", state)
	var deployed := 0
	var guard := 0
	while resolver.is_waiting() and guard < 10:
		guard += 1
		var opt = resolver.pending.legal_options[0]
		resolver.resume(state, opt)
		deployed += 1
	check_eq(deployed, 2, "DeployTroop(2) запросил ровно 2 решения")
	check_eq(red.troops_in_barracks, barracks_before - 2, "барак уменьшился на 2")

	var trophy_before := red.trophy_hall_count
	var resolver2 := EffectResolver.new()
	resolver2.apply(AssassinateTroop.new(1), "red", state)
	check(resolver2.is_waiting(), "AssassinateTroop запрашивает цель")
	var target = resolver2.pending.legal_options[0]
	var victim_owner: String = state.troops.get(target, "")
	resolver2.resume(state, target)
	check_eq(red.trophy_hall_count, trophy_before + 1, "трофи-холл вырос на 1")
	check_eq(state.troops.get(target, ""), "", "слот жертвы опустел")
	check(victim_owner != "red", "жертва не могла быть собственным войском")

	# PlaceSpy: два своих шпиона в одну локацию нельзя
	var ss := _build_two_player_state()
	ss.players["red"].spies_in_barracks = 5
	ss.spies = {"site_a": ["red"], "site_b": ["blue"]}
	var sr := EffectResolver.new()
	sr.apply(PlaceSpy.new(2), "red", ss)
	check_eq(sr.pending.legal_options, ["site_b"], "PlaceSpy: только локации без своего шпиона")
	sr.resume(ss, "site_b")
	check(not sr.is_waiting(), "PlaceSpy(2): после первого шпиона свободных локаций не осталось")
	check_eq(ss.spies["site_b"], ["blue", "red"], "шпион поставлен рядом с чужим")
	check(not PlaceSpy.new(1).is_available(ss, "red"), "PlaceSpy недоступен, если везде уже свой шпион")
	var sr2 := EffectResolver.new()
	var bogus := PlaceSpy.new(1)
	bogus.set_answer("site_a")
	sr2.apply(bogus, "red", ss)
	check_eq(ss.spies["site_a"], ["red"], "повторный шпион в ту же локацию отклоняется и в обход списка")

	# MoveTroop: брать можно только вражеское войско в своём Присутствии,
	# ставить — в любой пустой слот (Присутствие там не нужно)
	var ms := _build_two_player_state()
	ms.troops = {"a1": "red", "a2": "", "r1": "blue", "r2": "", "b1": "blue"}
	var mr := EffectResolver.new()
	mr.apply(MoveTroop.new(1), "red", ms)
	check(mr.is_waiting(), "MoveTroop запрашивает войско")
	check_eq(mr.pending.legal_options, ["r1"], "MoveTroop: только враг в Присутствии (не b1)")
	mr.resume(ms, "r1")
	check(mr.pending.legal_options.has("r2"), "MoveTroop: цель без Присутствия разрешена")
	mr.resume(ms, "r2")
	check_eq(ms.troops.get("r2", ""), "blue", "войско переехало")
	ms.troops = {"a1": "red", "a2": "", "r1": "", "r2": "", "b1": "blue"}
	check(not MoveTroop.new(1).is_available(ms, "red"), "MoveTroop недоступен без врагов в Присутствии")


func test_devour_and_promote_effects() -> void:
	section("DevourCard / PromoteCard (примитивы)")
	var state := _build_rich_state()
	var red: PlayerState = state.players["red"]
	var resolver := EffectResolver.new()

	var hand_before := red.deck.hand.size()
	var devoured_before := state.devoured_pile.size()
	resolver.apply(DevourCard.new("hand"), "red", state)
	check(resolver.is_waiting(), "DevourCard(hand) запрашивает, какую карту сожрать")
	var card_id = resolver.pending.legal_options[0]
	resolver.resume(state, card_id)
	check_eq(red.deck.hand.size(), hand_before - 1, "карта ушла из руки")
	check_eq(state.devoured_pile.size(), devoured_before + 1, "карта попала в devoured_pile")

	var ic_before := red.deck.inner_circle.size()
	var resolver2 := EffectResolver.new()
	resolver2.apply(PromoteCard.new("top_of_deck"), "red", state)
	check(not resolver2.is_waiting(), "promote верхней карты колоды не требует решения")
	check_eq(red.deck.inner_circle.size(), ic_before + 1, "Внутренний круг вырос на 1")


func test_card_library_smoke_all_cards() -> void:
	section("CardLibrary: все 125 карт разыгрываются без зависаний/ошибок")
	CardLibrary._ensure_loaded()
	var all_ids: Array = CardLibrary._data.keys()
	check_eq(all_ids.size(), 125, "cards.json содержит 125 карт")

	for prefer_last in [true, false]:
		var hung: Array[String] = []
		var failed_to_start: Array[String] = []
		for card_id: String in all_ids:
			var state := _build_rich_state(hash(card_id) % 1000)
			var red: PlayerState = state.players["red"]
			red.deck.hand.append(card_id)
			TurnEngine.start_turn(state, "red")
			var resolver := EffectResolver.new()
			var ok := TurnEngine.play_card(state, "red", card_id, resolver)
			if not ok:
				failed_to_start.append(card_id)
				continue
			var steps := _auto_resolve(state, resolver, prefer_last)
			if resolver.is_waiting():
				hung.append(card_id)
		check(failed_to_start.is_empty(), "play_card() успешен для всех карт (не смогли разыграть: %s)" % [failed_to_start])
		check(hung.is_empty(), "все карты полностью разрешаются за ≤40 решений, prefer_last=%s (зависли: %s)" % [prefer_last, hung])


# --- этап 6: сетевой слой (Intent / GameServer / StateView / StateSerializer) --

func test_intent_factories() -> void:
	section("Intent: фабрики")
	var i1 := Intent.play_card("red", "48342")
	check_eq(i1.type, Intent.Type.PLAY_CARD, "play_card строит правильный type")
	check_eq(i1.card_id, "48342", "card_id сохранён")

	var i2 := Intent.deploy("red", "a1")
	check_eq(i2.type, Intent.Type.ACTION_DEPLOY, "deploy строит правильный type")
	check_eq(i2.slot_id, "a1", "slot_id сохранён")

	var i3 := Intent.recruit("red", 2)
	check_eq(i3.type, Intent.Type.ACTION_RECRUIT, "recruit строит правильный type")
	check_eq(i3.market_index, 2, "market_index сохранён")

	var i4 := Intent.return_spy("red", "site_b", "blue")
	check_eq(i4.type, Intent.Type.ACTION_RETURN_SPY, "return_spy строит правильный type")
	check_eq(i4.site_id, "site_b", "site_id сохранён")
	check_eq(i4.spy_owner, "blue", "spy_owner сохранён")

	var i5 := Intent.make_decision("red", true)
	check_eq(i5.type, Intent.Type.MAKE_DECISION, "make_decision строит правильный type")
	check_eq(i5.answer, true, "answer сохранён")

	var i6 := Intent.end_turn("red")
	check_eq(i6.type, Intent.Type.END_TURN, "end_turn строит правильный type")


func test_state_view_hides_hidden_info() -> void:
	section("StateView: скрытая информация")
	var state := _build_rich_state(55)
	var red: PlayerState = state.players["red"]
	red.deck.hand = ["48342", "48344"]
	red.deck.discard_pile = ["48343"]

	var self_view: Dictionary = StateView.for_player(state, "red")
	var other_view: Dictionary = StateView.for_player(state, "blue")

	check_eq(self_view["players"]["red"]["hand"], red.deck.hand, "владелец видит свою руку целиком")
	check(not other_view["players"]["red"].has("hand"), "чужая рука скрыта целиком")
	check_eq(other_view["players"]["red"]["hand_size"], 2, "чужой игрок видит только размер руки")
	check_eq(other_view["players"]["red"]["discard_size"], 1, "чужой игрок видит только размер сброса")
	check(not other_view["players"]["red"].has("discard_pile"), "содержимое чужого сброса скрыто")

	check_eq(self_view["troops"], state.troops, "войска на доске — открытая информация")
	check_eq(self_view["market"]["display"], state.market.display, "маркет — открытая информация")
	check_eq(self_view["players"]["red"]["inner_circle"], red.deck.inner_circle, "Внутренний круг — открытая информация")


func test_state_view_pending_decision_visibility() -> void:
	section("StateView: legal_options решения видны только решающему")
	var pd := PendingDecision.new()
	pd.player_id = "red"
	pd.prompt = "тест"
	pd.choice_type = "target_slot"
	pd.legal_options = ["a1", "a2"]

	var state := _build_rich_state(66)
	var red_view: Dictionary = StateView.for_player_with_pending(state, "red", pd)
	var blue_view: Dictionary = StateView.for_player_with_pending(state, "blue", pd)

	check_eq(red_view["pending_decision"]["legal_options"], ["a1", "a2"], "решающий игрок видит варианты")
	check_eq(blue_view["pending_decision"]["legal_options"], [], "остальные не видят вариантов")
	check_eq(blue_view["pending_decision"]["prompt"], "тест", "но сам факт решения и prompt видны всем")


func test_state_serializer_round_trip() -> void:
	section("StateSerializer: JSON round-trip")
	var state := _build_rich_state(77)
	var json_text := StateSerializer.to_json(state, "red")
	check(json_text.length() > 0, "снимок сериализован в непустую строку")

	var parsed := StateSerializer.from_json(json_text)
	check_eq(parsed["current_player"], state.current_player(), "current_player пережил round-trip")
	check_eq((parsed["players"] as Dictionary)["red"]["power"], state.players["red"].power, "power red пережил round-trip")
	check_eq(StateSerializer.from_json("не json"), {}, "некорректный JSON даёт пустой Dictionary, не падение")


func test_game_server_turn_order_and_actions() -> void:
	section("GameServer: очередь ходов и базовые действия")
	var state := _build_rich_state(101)
	var server := GameServer.new(state)

	check_eq(state.current_player(), "red", "первый ход — red")
	var res := server.apply_intent(Intent.deploy("blue", "a1"))
	check_eq(res["error"], GameServer.Error.NOT_YOUR_TURN, "blue не может ходить в чужой ход")

	var legal: PackedStringArray = state.presence.deployable_slots("red", state.troops, state.spies)
	var target_slot := ""
	for slot in legal:
		if state.troops.get(slot, "") == "":
			target_slot = slot
			break
	check(target_slot != "", "нашли свободный слот для deploy")

	res = server.apply_intent(Intent.deploy("red", target_slot))
	check_eq(res["error"], GameServer.Error.OK, "red разворачивает войско")
	check_eq(state.troops[target_slot], "red", "войско встало в выбранный слот")

	res = server.apply_intent(Intent.deploy("red", "несуществующий_слот"))
	check_eq(res["error"], GameServer.Error.INVALID_ACTION, "неверный слот отклонён с INVALID_ACTION")

	var red_view: Dictionary = res["views"]["red"]
	var blue_view: Dictionary = res["views"]["blue"]
	check(red_view["players"]["red"].has("hand"), "red видит свою руку")
	check(not blue_view["players"]["red"].has("hand"), "blue не видит руку red")
	check_eq(blue_view["players"]["red"]["hand_size"], state.players["red"].deck.hand.size(),
		"blue видит только размер руки red")


func test_game_server_play_card_with_decision() -> void:
	section("GameServer: розыгрыш карты с decision через MAKE_DECISION")
	var state := _build_rich_state(202)
	var server := GameServer.new(state)
	var red: PlayerState = state.players["red"]
	if not red.deck.hand.has("48331"):
		red.deck.hand.append("48331")  # Mercenary Squad -> DeployTroop(3)

	var res := server.apply_intent(Intent.play_card("red", "48331"))
	check_eq(res["error"], GameServer.Error.OK, "розыгрыш карты начался")
	check(server.resolver.is_waiting(), "DeployTroop(3) остановился на первом решении")

	var blocked := server.apply_intent(Intent.end_turn("red"))
	check_eq(blocked["error"], GameServer.Error.AWAITING_DECISION, "END_TURN отклонён, пока ждём решения")

	var wrong_player := server.apply_intent(Intent.make_decision("blue", ""))
	check_eq(wrong_player["error"], GameServer.Error.NOT_YOUR_TURN, "чужой игрок не может ответить на чужое решение")

	var steps := 0
	while server.resolver.is_waiting() and steps < 10:
		steps += 1
		var pd: PendingDecision = server.resolver.pending
		var answer = pd.legal_options[0] if not pd.legal_options.is_empty() else null
		res = server.apply_intent(Intent.make_decision("red", answer))
		check_eq(res["error"], GameServer.Error.OK, "MAKE_DECISION #%d принят" % steps)
	check(not server.resolver.is_waiting(), "все decision'ы DeployTroop(3) разрешены")

	var after_all_resolved := server.apply_intent(Intent.make_decision("red", ""))
	check_eq(after_all_resolved["error"], GameServer.Error.NO_DECISION_PENDING,
		"MAKE_DECISION без активного pending отклонён")


func test_game_server_end_turn_advances() -> void:
	section("GameServer: END_TURN передаёт ход по кругу")
	var state := _build_rich_state(404)
	var server := GameServer.new(state)

	check_eq(state.current_player(), "red", "ход у red")
	var res := server.apply_intent(Intent.end_turn("red"))
	check_eq(res["error"], GameServer.Error.OK, "red завершил ход")
	check_eq(state.current_player(), "blue", "ход перешёл к blue")

	res = server.apply_intent(Intent.end_turn("blue"))
	check_eq(res["error"], GameServer.Error.OK, "blue завершил ход")
	check_eq(state.current_player(), "green", "ход перешёл к green")

	res = server.apply_intent(Intent.end_turn("green"))
	check_eq(res["error"], GameServer.Error.OK, "green завершил ход")
	check_eq(state.current_player(), "red", "ход вернулся к red по кругу")


func test_game_server_two_end_of_turn_promotes() -> void:
	section("GameServer: два отложенных promote в конце хода (Cultist + Myrmidon)")
	var state := _build_rich_state(505)
	var server := GameServer.new(state)
	var red: PlayerState = state.players["red"]
	red.deck.hand.append("48610")  # Black Earth Cultist
	red.deck.hand.append("48617")  # Earth Elemental Myrmidon
	server.apply_intent(Intent.play_card("red", "48610"))
	server.apply_intent(Intent.play_card("red", "48617"))
	check(not server.resolver.is_waiting(), "обе карты разыграны без решений")

	server.apply_intent(Intent.end_turn("red"))
	var promote_prompts := 0
	var steps := 0
	while server.resolver.is_waiting() and steps < 10:
		steps += 1
		var pd: PendingDecision = server.resolver.pending
		if pd.prompt == "Promote a card":
			promote_prompts += 1
		server.apply_intent(Intent.make_decision("red", pd.legal_options[0]))
	check_eq(promote_prompts, 2, "игроку предложены оба promote")
	check(red.deck.inner_circle.has("48610") and red.deck.inner_circle.has("48617"),
		"обе карты продвинуты во Внутренний круг")
	check_eq(state.current_player(), "blue", "ход перешёл к blue после всех promote")


## Настоящая партия идёт через GameServer: бонус A2 должен начисляться и там,
## а не только при прямом вызове TurnEngine.start_turn в тестах.
func test_game_server_grants_a2_bonus() -> void:
	section("GameServer: бонус гекса A2 в настоящей партии")
	for tier in [["troops", 0, 1, 0], ["control", 1, 1, 1], ["total", 2, 2, 4]]:
		var state := GameState.new(_build_a2_graph(), 5)
		state.add_player("red", [])
		state.add_player("blue", [])
		for prefix in ["fogtown", "gallenghast", "darkflame"]:
			match tier[0]:
				"troops":
					state.troops[prefix + "_0"] = "red"
					state.troops[prefix + "_1"] = "blue"
				"control":
					state.troops[prefix + "_0"] = "red"
					state.troops[prefix + "_1"] = "red"
					state.troops[prefix + "_2"] = "blue"
				"total":
					for i in range(3):
						state.troops["%s_%d" % [prefix, i]] = "red"
		var server := GameServer.new(state)
		var red: PlayerState = state.players["red"]
		check_eq([red.power, red.influence], [tier[1], tier[2]],
			"%s: первый ход red сразу получает Power/Influence" % tier[0])
		var vp_before := red.vp_tokens
		server._apply(Intent.end_turn("red"))  # без StateView: у мини-состояния нет маркета
		check_eq(red.vp_tokens - vp_before, tier[3], "%s: VP в конце хода" % tier[0])
		server._apply(Intent.end_turn("blue"))
		check_eq([red.power, red.influence], [tier[1], tier[2]],
			"%s: на следующем ходу бонус начислен снова (не накопился)" % tier[0])


func test_game_server_end_of_game() -> void:
	section("GameServer: конец партии по цепочке intent'ов")
	var state := _build_rich_state(303)
	state.players["red"].troops_in_barracks = 1
	state.players["red"].power = 5
	var server := GameServer.new(state)

	var legal: PackedStringArray = state.presence.deployable_slots("red", state.troops, state.spies)
	var target_slot := ""
	for slot in legal:
		if state.troops.get(slot, "") == "":
			target_slot = slot
			break
	check(target_slot != "", "нашли свободный слот для последнего Deploy")

	var res := server.apply_intent(Intent.deploy("red", target_slot))
	check_eq(res["error"], GameServer.Error.OK, "Deploy последнего войска прошёл")
	check(state.game_end_triggered, "конец партии запущен через GameServer")
	check(not state.game_over, "но партия ещё не закончилась — доигрывается круг")

	res = server.apply_intent(Intent.end_turn("red"))
	check_eq(res["error"], GameServer.Error.OK, "red завершил ход")
	check(not state.game_over, "red не последний перед собой — партия продолжается")

	res = server.apply_intent(Intent.end_turn("blue"))
	check_eq(res["error"], GameServer.Error.OK, "blue завершил ход")
	check(not state.game_over, "blue тоже не последний перед red")

	res = server.apply_intent(Intent.end_turn("green"))
	check_eq(res["error"], GameServer.Error.OK, "green завершил ход — последний перед red")
	check(state.game_over, "партия закончилась после green")

	res = server.apply_intent(Intent.end_turn("red"))
	check_eq(res["error"], GameServer.Error.GAME_OVER, "после конца партии сервер отклоняет новые intent'ы")


# --- этап 7: сборка настоящей партии и общие стопки --------------------------

func test_game_setup_real_game() -> void:
	section("GameSetup: настоящая партия на реальных данных")
	var pids: Array[String] = ["red", "blue"]
	var state := GameSetup.new_game(pids, 4242, ["drow", "demons"])

	check_eq(state.turn_order, pids, "оба игрока в очереди хода")
	# Точное число локаций зависит от того, какие тайлы выпали по сиду (таблица
	# в claude/progress.md — 26 локаций на 2 игроков — относится к сиду 7, это
	# не универсальное число). Проверяем, что доска вообще собралась целиком:
	# 9 тайлов на 2 игроков, у каждого свои локации и троп-слоты.
	check(state.graph.site_count() >= 15, "доска собрана: локаций %d" % state.graph.site_count())
	check(state.graph.slot_count() >= 80, "троп-слотов %d" % state.graph.slot_count())

	# маркет: 2 полуколоды по 40 = 80 карт, 6 из них открыты на дисплее
	check_eq(state.market.display.size(), 6, "на дисплее маркета 6 слотов")
	var empty_slots := 0
	for cid: String in state.market.display:
		if cid == "":
			empty_slots += 1
	check_eq(empty_slots, 0, "все 6 слотов дисплея заполнены")
	check_eq(state.market.deck_size(), 80 - 6, "в колоде маркета 74 карты (80 минус 6 открытых)")

	# все id маркета — настоящие карты из cards.json
	var unknown: Array[String] = []
	for cid: String in state.market.display:
		if CardLibrary.card_data(cid).is_empty():
			unknown.append(cid)
	check(unknown.is_empty(), "все карты дисплея есть в cards.json (неизвестные: %s)" % [unknown])

	# полуколода Demons в игре -> стопка Insane Outcast выложена (шаг 4 сетапа)
	check_eq(state.supplies.remaining(Supplies.HOUSE_GUARD), 15, "стопка House Guard — 15 карт")
	check_eq(state.supplies.remaining(Supplies.PRIESTESS_OF_LOLTH), 15, "стопка Priestess of Lolth — 15 карт")
	check_eq(state.supplies.remaining(Supplies.INSANE_OUTCAST), 30, "с полуколодой Demons выложены 30 Insane Outcast")

	var no_demons := GameSetup.new_game(pids, 4242, ["drow", "dragons"])
	check_eq(no_demons.supplies.remaining(Supplies.INSANE_OUTCAST), 0,
		"без полуколоды Demons стопки Insane Outcast на столе нет (рулбук, шаг 4)")

	# игроки: 7 Noble + 3 Soldier, из них 5 в руке
	for pid: String in pids:
		var p: PlayerState = state.players[pid]
		check_eq(p.deck.hand.size(), 5, "%s: в руке 5 карт" % pid)
		check_eq(p.deck.draw_pile.size(), 5, "%s: в колоде добора осталось 5" % pid)
		var all_cards: Array[String] = p.deck.cards_outside_inner_circle()
		check_eq(all_cards.size(), 10, "%s: всего 10 стартовых карт" % pid)
		var nobles := 0
		for cid: String in all_cards:
			if cid == "48342":
				nobles += 1
		check_eq(nobles, 7, "%s: из них 7 Noble" % pid)

	# белые войска и стартовые войска игроков на доске
	var white := 0
	var red_troops := 0
	for slot_id: String in state.troops.keys():
		if state.troops[slot_id] == GameState.WHITE:
			white += 1
		elif state.troops[slot_id] == "red":
			red_troops += 1
	check(white > 20, "белые войска расставлены (%d штук)" % white)
	check_eq(red_troops, 1, "у red одно стартовое войско на доске")
	check_eq(state.players["red"].troops_in_barracks, PlayerState.STARTING_TROOPS - 1,
		"стартовое войско ушло из барака red")

	# детерминированность: тот же сид -> та же партия
	var again := GameSetup.new_game(pids, 4242, ["drow", "demons"])
	check_eq(again.market.display, state.market.display, "тот же сид даёт тот же дисплей маркета")
	check_eq(again.players["red"].deck.hand, state.players["red"].deck.hand, "и ту же стартовую руку")


## Хотсит на 3 и 4 человек: раскладка доски, стартовые сайты и интерактивный
## сетап должны работать не только вдвоём. Раньше экран всегда собирал партию
## на red/blue, и эти ветки pick_hexes не проверялись ни одним тестом.
func test_hotseat_three_and_four_players() -> void:
	section("Хотсит: партии на 3 и 4 игроков")
	check_eq(GameScreen.player_ids_for(3), ["red", "blue", "green"] as Array[String],
		"на троих раздаются первые три цвета")
	check_eq(GameScreen.player_ids_for(4).size(), 4, "на четверых — четыре цвета")
	check_eq(GameScreen.player_ids_for(9).size(), GameScreen.MAX_PLAYERS,
		"больше четырёх игроков не бывает — число обрезается")

	for count in [3, 4]:
		var ids := GameScreen.player_ids_for(count)
		var state := GameSetup.new_game(ids, 777 + count, ["drow", "dragons"], false, true, false)
		check_eq(state.turn_order.size(), count, "%d игроков: все в очереди хода" % count)
		check_eq(int(state.layout["player_count"]), count, "%d игроков: раскладка доски на столько же" % count)
		check(state.graph.site_count() >= 20, "%d игроков: доска собрана, локаций %d" % [count, state.graph.site_count()])

		# стартовых сайтов (чёрные таблички) должно хватить на всех
		var starting := GameSetup.find_starting_sites(state.graph)
		check(starting.size() >= count, "%d игроков: стартовых сайтов %d — хватает всем" % [count, starting.size()])

		# интерактивный сетап: каждый сам выбирает стартовый сайт, по очереди
		var server := GameServer.new(state)
		var answered := 0
		while server.resolver.is_waiting() and answered < count + 2:
			var pd: PendingDecision = server.resolver.pending
			var res: Dictionary = server.apply_intent(Intent.make_decision(pd.player_id, pd.legal_options[0]))
			check_eq(int(res["error"]), GameServer.Error.OK, "%d игроков: выбор стартового сайта принят" % count)
			answered += 1
		check_eq(answered, count, "%d игроков: стартовый сайт выбрал каждый" % count)

		var on_board := {}
		for slot_id: String in state.troops.keys():
			var owner: String = state.troops[slot_id]
			if owner != GameState.WHITE:
				on_board[owner] = int(on_board.get(owner, 0)) + 1
		for pid: String in ids:
			check_eq(int(on_board.get(pid, 0)), 1, "%d игроков: у %s одно стартовое войско" % [count, pid])
			check_eq(state.players[pid].deck.hand.size(), 5, "%d игроков: у %s 5 карт в руке" % [count, pid])


func test_half_deck_data() -> void:
	section("Состав полуколод: копии карт из данных мода")
	check_eq(GameSetup.available_half_decks().size(), 6, "доступно 6 полуколод")
	for name: String in GameSetup.available_half_decks():
		var cards := GameSetup.expand_half_deck(name)
		check_eq(cards.size(), 40, "полуколода %s — ровно 40 карт" % name)

	# копий у карт РАЗНОЕ количество (1-4), а не по 2 у каждой
	var drow := GameSetup.expand_half_deck("drow")
	var counts := {}
	for cid: String in drow:
		counts[cid] = int(counts.get(cid, 0)) + 1
	check_eq(counts.size(), 20, "в полуколоде drow 20 уникальных карт")
	check_eq(int(counts.get("48306", 0)), 4, "Advocate в 4 экземплярах (не 2 — копии неравномерны)")
	check_eq(int(counts.get("48339", 0)), 1, "Weaponmaster в единственном экземпляре")

	check_eq(GameSetup.starting_deck().size(), 10, "стартовая колода — 10 карт")


func test_recruit_from_supply() -> void:
	section("Recruit из общих стопок (House Guard / Priestess of Lolth)")
	var state := GameSetup.new_game(["red", "blue"], 7, ["drow", "dragons"])
	var red: PlayerState = state.players["red"]

	red.influence = 2
	check(not Actions.recruit_from_supply(state, "red", Supplies.HOUSE_GUARD),
		"на House Guard (стоимость 3) двух Influence не хватает")
	check_eq(state.supplies.remaining(Supplies.HOUSE_GUARD), 15, "неудачная попытка стопку не тронула")

	check(Actions.recruit_from_supply(state, "red", Supplies.PRIESTESS_OF_LOLTH),
		"Priestess of Lolth (стоимость 2) куплена")
	check_eq(red.influence, 0, "Influence списан")
	check(red.deck.discard_pile.has(Supplies.PRIESTESS_OF_LOLTH), "карта легла в сброс игрока")
	check_eq(state.supplies.remaining(Supplies.PRIESTESS_OF_LOLTH), 14, "в стопке осталось 14")

	red.influence = 100
	check(not Actions.recruit_from_supply(state, "red", Supplies.INSANE_OUTCAST),
		"Insane Outcast за Influence не покупается — его только раздают эффекты карт")
	check(not Actions.recruit_from_supply(state, "red", "48342"),
		"обычную карту (Noble) из стопки купить нельзя — её там нет")

	# исчерпание стопки: партия продолжается, просто источник иссяк
	state.supplies.counts[Supplies.HOUSE_GUARD] = 1
	check(Actions.recruit_from_supply(state, "red", Supplies.HOUSE_GUARD), "последний House Guard куплен")
	check(not Actions.recruit_from_supply(state, "red", Supplies.HOUSE_GUARD), "стопка пуста — покупка невозможна")
	check(not state.game_end_triggered, "пустая стопка НЕ запускает конец партии (в отличие от колоды маркета)")


func test_insane_outcast_supply() -> void:
	section("Стопка Insane Outcast: конечна и раздаётся по часовой стрелке")
	var state := GameSetup.new_game(["red", "blue", "green"], 11, ["drow", "demons"])
	var resolver := EffectResolver.new()

	var before: int = state.supplies.remaining(Supplies.INSANE_OUTCAST)
	resolver.apply(GiveInsaneOutcast.new("each_opponent"), "red", state)
	check_eq(state.supplies.remaining(Supplies.INSANE_OUTCAST), before - 2, "двум противникам — две карты из стопки")
	check(state.players["blue"].deck.discard_pile.has(Supplies.INSANE_OUTCAST), "blue получил Insane Outcast")
	check(not state.players["red"].deck.discard_pile.has(Supplies.INSANE_OUTCAST), "сам red не получил")

	# осталась одна карта на двоих: по правилу достаётся тому, кто раньше по
	# часовой стрелке от текущего игрока (ход у red, index 0 -> первым blue)
	state.supplies.counts[Supplies.INSANE_OUTCAST] = 1
	var blue_before: int = _count_of(state.players["blue"].deck.discard_pile, Supplies.INSANE_OUTCAST)
	var green_before: int = _count_of(state.players["green"].deck.discard_pile, Supplies.INSANE_OUTCAST)
	var resolver2 := EffectResolver.new()
	resolver2.apply(GiveInsaneOutcast.new("each_opponent"), "red", state)
	var blue_after: int = _count_of(state.players["blue"].deck.discard_pile, Supplies.INSANE_OUTCAST)
	var green_after: int = _count_of(state.players["green"].deck.discard_pile, Supplies.INSANE_OUTCAST)
	check_eq(blue_after - blue_before, 1, "последняя карта ушла blue (следующий по часовой от red)")
	check_eq(green_after - green_before, 0, "green не получил ничего — стопка кончилась")
	check_eq(state.supplies.remaining(Supplies.INSANE_OUTCAST), 0, "стопка пуста")


func _count_of(list: Array, value: String) -> int:
	var n := 0
	for v in list:
		if v == value:
			n += 1
	return n


func test_state_view_legal_and_supplies() -> void:
	section("StateView: подсказки о доступных действиях и стопки")
	var state := GameSetup.new_game(["red", "blue"], 21, ["drow", "demons"])
	var red: PlayerState = state.players["red"]
	red.power = 0
	red.influence = 0

	var view := StateView.for_player(state, "red")
	check_eq(view["supplies"][Supplies.HOUSE_GUARD], 15, "в срезе видно, сколько House Guard осталось")
	check_eq((view["legal"] as Dictionary)["recruit_market"], [], "без Influence покупать в маркете нечего")
	check_eq((view["legal"] as Dictionary)["recruit_supply"], [], "и из стопок тоже")
	check_eq((view["legal"] as Dictionary)["deploy_slots"], [], "без Power развернуть войско нельзя")

	red.power = 3
	red.influence = 3
	var view2 := StateView.for_player(state, "red")
	var legal: Dictionary = view2["legal"]
	check(not (legal["deploy_slots"] as Array).is_empty(), "с 3 Power появились слоты для Deploy")
	check(legal["recruit_supply"].has(Supplies.HOUSE_GUARD), "с 3 Influence можно купить House Guard (стоит 3)")
	check(legal["recruit_supply"].has(Supplies.PRIESTESS_OF_LOLTH), "и Priestess of Lolth (стоит 2)")
	check_eq(legal["end_turn"], true, "закончить ход можно всегда")

	# у не-ходящего игрока подсказок нет вовсе
	var blue_view := StateView.for_player(state, "blue")
	check_eq(blue_view["legal"], {}, "в чужой ход подсказок о действиях нет")

	# статическое описание доски для отрисовки
	var board := StateView.board_snapshot(state)
	check_eq((board["sites"] as Dictionary).size(), state.graph.site_count(), "в снимке доски все локации")
	check_eq((board["slots"] as Dictionary).size(), state.graph.slot_count(), "и все троп-слоты")
	var any_site: String = (board["sites"] as Dictionary).keys()[0]
	check(not String((board["sites"][any_site] as Dictionary)["name"]).is_empty(), "у локации есть название")


func test_game_server_recruit_supply() -> void:
	section("GameServer: покупка из общей стопки намерением")
	var state := GameSetup.new_game(["red", "blue"], 33, ["drow", "dragons"])
	var server := GameServer.new(state)
	state.players["red"].influence = 3

	var res := server.apply_intent(Intent.recruit_supply("blue", Supplies.HOUSE_GUARD))
	check_eq(res["error"], GameServer.Error.NOT_YOUR_TURN, "в чужой ход из стопки не купить")

	res = server.apply_intent(Intent.recruit_supply("red", Supplies.HOUSE_GUARD))
	check_eq(res["error"], GameServer.Error.OK, "red покупает House Guard")
	check_eq(state.supplies.remaining(Supplies.HOUSE_GUARD), 14, "стопка уменьшилась")
	check(state.players["red"].deck.discard_pile.has(Supplies.HOUSE_GUARD), "карта в сбросе red")
	var kinds: Array[String] = []
	for e: Dictionary in (res["events"] as Array):
		kinds.append(String(e["type"]))
	check(kinds.has("recruit_supply"), "событие recruit_supply попало в журнал для UI")

	res = server.apply_intent(Intent.recruit_supply("red", Supplies.HOUSE_GUARD))
	check_eq(res["error"], GameServer.Error.INVALID_ACTION, "второй раз Influence уже не хватает")


func test_white_troops_on_real_board() -> void:
	section("Белые войска стоят на СУЩЕСТВУЮЩИХ слотах собранной доски")
	# Баг этапа 7: расстановка писала сырые id из данных ("A3_0_0"), а на
	# собранной доске слоты называются с префиксом места в раскладке
	# ("a:A3_0_0"). 56 белых войск оказывались вне доски: невидимы, неубиваемы
	# и не учитывались в контроле локаций. Тесты этого не ловили, потому что
	# работали на синтетических графах — поймалось глазами по картинке.
	var state := GameSetup.new_game(["red", "blue"], 7)

	var white_total := 0
	var orphans: Array[String] = []
	for slot_id: String in state.troops.keys():
		if not state.graph.slots.has(slot_id):
			orphans.append(slot_id)
		elif state.troops[slot_id] == GameState.WHITE:
			white_total += 1
	check(orphans.is_empty(), "нет войск на несуществующих слотах (найдено: %d)" % orphans.size())
	check(white_total > 20, "белых войск на доске: %d" % white_total)

	# белые войска обязаны стоять именно в локациях, а не на маршрутных слотах
	var on_routes := 0
	for slot_id: String in state.troops.keys():
		if state.troops[slot_id] == GameState.WHITE and state.graph.site_of_slot(slot_id) == "":
			on_routes += 1
	check_eq(on_routes, 0, "ни одно белое войско не стоит на маршрутном слоте")

	# и они должны реально мешать: слот с белым войском не может быть целью Deploy
	var occupied := ""
	for slot_id: String in state.troops.keys():
		if state.troops[slot_id] == GameState.WHITE:
			occupied = slot_id
			break
	var deployable := state.presence.deployable_slots("red", state.troops, state.spies)
	check(not deployable.has(occupied), "занятый белым войском слот не предлагается для Deploy")

	# число белых войск должно совпадать с суммой initial_white_troops тех
	# сайтов, которые попали в раскладку — считаем независимо от кода расстановки
	var expected := 0
	var site_data: Dictionary = BoardData.load_all()["sites"]
	for site_id: String in state.graph.sites.keys():
		var hex_id: String = String(state.graph.sites[site_id]["hex"])
		var raw: String = site_id.get_slice(":", 1)
		for site: Dictionary in (site_data.get(hex_id, []) as Array):
			if String(site.get("id", "")) == raw:
				expected += mini(int(site.get("initial_white_troops", 0)),
					state.graph.slots_of_site(site_id).size())
				break
	check_eq(white_total, expected, "белых войск ровно столько, сколько задано данными сайтов")


func test_choose_option_answer_protocol() -> void:
	section("Протокол выбора: ответ значением из legal_options выбирает тот вариант, что видел игрок")
	# Баг этапа 7: ChooseEffect присылал в legal_options ПОДПИСИ ("+2 Influence"),
	# а обратно ждал НОМЕР варианта. Клиент, вернувший присланное значение,
	# всегда попадал в вариант 0 — молча, без ошибки. Тесты этого не ловили,
	# потому что отвечали числом, а не тем, что прислал сервер.
	var state := GameSetup.new_game(["red", "blue"], 5, ["drow", "dragons"])
	var red: PlayerState = state.players["red"]
	red.power = 0
	red.influence = 0

	var resolver := EffectResolver.new()
	resolver.apply(ChooseEffect.new(
		[GainPower.new(7), GainInfluence.new(9)] as Array[CardEffect],
		["+7 Power", "+9 Influence"] as Array[String]), "red", state)
	check(resolver.is_waiting(), "ChooseEffect ждёт выбора")

	var pd: PendingDecision = resolver.pending
	check_eq(pd.legal_options, [0, 1], "в legal_options — номера вариантов (то, что ждут обратно)")
	check_eq(pd.option_labels, ["+7 Power", "+9 Influence"], "подписи пришли отдельным полем")

	# отвечаем ВТОРЫМ значением из legal_options, как сделал бы клиент
	resolver.resume(state, pd.legal_options[1])
	check_eq(red.influence, 9, "применился именно выбранный (второй) вариант")
	check_eq(red.power, 0, "первый вариант не применился")

	# и то же самое через сеть: подписи видит только тот, кто решает
	var state2 := GameSetup.new_game(["red", "blue"], 5, ["drow", "dragons"])
	var server := GameServer.new(state2)
	state2.players["red"].deck.hand.append("48325")  # Inquisitor: choose one
	var res := server.apply_intent(Intent.play_card("red", "48325"))
	check_eq(res["error"], GameServer.Error.OK, "Inquisitor разыгран")
	var red_view: Dictionary = (res["views"] as Dictionary)["red"]
	var blue_view: Dictionary = (res["views"] as Dictionary)["blue"]
	var pdv: Dictionary = red_view["pending_decision"]
	check_eq(pdv["legal_options"], [0, 1], "решающий видит номера вариантов")
	check_eq((pdv["option_labels"] as Array).size(), 2, "и обе подписи")
	check_eq((blue_view["pending_decision"] as Dictionary)["option_labels"], [],
		"противнику подписи вариантов не видны")

	# подпись кнопки берётся из option_labels, а не из номера
	check_eq(DecisionDialog.label_for(0, "choose_option"), "Option 1",
		"без подписи вариант подписывается номером, считая с единицы")
	check_eq(DecisionDialog.label_for("48342", "target_card"), "Noble",
		"карта в диалоге подписывается названием, а не числовым id")
	check_eq(DecisionDialog.label_for("", "target_card"), "Skip",
		"пустая строка в вариантах — это отказ")
	check_eq(DecisionDialog.label_for(-1, "target_market_index"), "Skip",
		"-1 среди индексов маркета — тоже отказ")
	check_eq(DecisionDialog.label_for(true, "confirm"), "Yes", "подтверждение читается словом")


func test_return_troop_on_real_board_ids() -> void:
	section("Return troop/spy на настоящих id слотов (с двоеточием)")
	# Баг этапа 7, найденный автопрогоном: цель кодировалась как
	# "troop:<slot_id>", а id слота собранной доски сам содержит двоеточие
	# ("c_s1:C4_0_1"). Разбор брал только префикс — вражеское войско
	# оставалось на доске, зато появлялась запись на несуществующем слоте, и
	# владельцу в барак ничего не возвращалось. Синтетические доски прежних
	# тестов двоеточий в id не имели, поэтому баг был не виден.
	var state := GameSetup.new_game(["red", "blue"], 77, ["drow", "dragons"])

	# ставим войско blue на реальный слот и возвращаем его силами red. return
	# теперь требует Присутствия (см. return_troop_or_spy.gd), поэтому нужен
	# сайт минимум с двумя свободными слотами: один под цель (blue), другой —
	# под войско red, дающее Присутствие на этом же сайте.
	var victim_slot := ""
	var presence_slot := ""
	for site_id: String in state.graph.sites.keys():
		var free_slots: Array = []
		for slot_id: String in state.graph.slots_of_site(site_id):
			if state.troops.get(slot_id, "") == "" and slot_id.contains(":"):
				free_slots.append(slot_id)
		if free_slots.size() >= 2:
			victim_slot = free_slots[0]
			presence_slot = free_slots[1]
			break
	check(victim_slot != "" and presence_slot != "", "нашли сайт с двумя свободными слотами с настоящими id")
	state.troops[victim_slot] = "blue"
	state.troops[presence_slot] = "red"
	var blue: PlayerState = state.players["blue"]
	blue.troops_in_barracks = 10

	var resolver := EffectResolver.new()
	resolver.apply(ReturnTroopOrSpy.new(1), "red", state)
	check(resolver.is_waiting(), "эффект спрашивает, какую фигуру вернуть")

	var target := ""
	for opt in resolver.pending.legal_options:
		if String(opt).ends_with(victim_slot):
			target = String(opt)
			break
	check(target != "", "войско blue есть среди целей")
	resolver.resume(state, target)

	check_eq(state.troops.get(victim_slot, ""), "", "войско действительно снято с доски")
	check_eq(blue.troops_in_barracks, 11, "и вернулось в барак владельца")
	var phantom := 0
	for slot_id: String in state.troops.keys():
		if not state.graph.slots.has(slot_id):
			phantom += 1
	check_eq(phantom, 0, "не появилось записей на несуществующих слотах")

	# то же для шпиона: в site_id тоже есть двоеточие. Переиспользуем сайт с
	# войском red, где Присутствие уже есть.
	var site_id: String = state.graph.site_of_slot(victim_slot)
	state.spies[site_id] = ["blue"]
	var spies_before: int = blue.spies_in_barracks
	var resolver2 := EffectResolver.new()
	resolver2.apply(ReturnTroopOrSpy.new(1, false, false, true), "red", state)
	check(resolver2.is_waiting(), "эффект спрашивает про шпиона")
	resolver2.resume(state, resolver2.pending.legal_options[0])
	check_eq((state.spies.get(site_id, []) as Array).size(), 0, "шпион снят с локации")
	check_eq(blue.spies_in_barracks, spies_before + 1, "шпион вернулся в барак владельца")

	# подпись такой цели в интерфейсе должна быть человеческой
	var dialog := DecisionDialog.new()
	dialog.board = StateView.board_snapshot(state)
	var label: String = dialog._board_label("troop|" + victim_slot, "target_slot")
	check(label.begins_with("Troop: "), "составная цель подписана по-человечески: %s" % label)
	check(not label.contains("|"), "в подписи не осталось служебного разделителя")
	dialog.free()


func test_board_geometry_spreads_tiles() -> void:
	section("Геометрия доски: тайлы стоят по местам, слоты не в одной куче")
	# Баг, замеченный игроком: "доска нечитаемая, всё накладывается друг на
	# друга". Причина — интерфейс брал координаты слота из графа, а там записано
	# положение ВНУТРИ гекса. Девять гексов рисовались один поверх другого.
	var state := GameSetup.new_game(["red", "blue"], 7)
	var geom := BoardGeometry.build(state)

	var tiles: Array = geom["tiles"]
	check_eq(tiles.size(), (state.layout["hex_by_slot"] as Dictionary).size(),
		"тайлов столько же, сколько мест в раскладке")
	var radius: float = float(geom["hex_radius_px"])
	check(radius > 100.0, "радиус гекса в пикселях разумный: %.0f" % radius)

	# центры тайлов не совпадают и стоят примерно на шаг соседства друг от друга
	var min_dist := INF
	for i in range(tiles.size()):
		for j in range(i + 1, tiles.size()):
			var a := Vector2(float(tiles[i]["x"]), float(tiles[i]["y"]))
			var b := Vector2(float(tiles[j]["x"]), float(tiles[j]["y"]))
			min_dist = minf(min_dist, a.distance_to(b))
	check(min_dist > radius, "центры тайлов разнесены (ближайшие: %.0f px при радиусе %.0f)"
		% [min_dist, radius])

	# слоты занимают площадь во много гексов, а не один
	var slots: Dictionary = geom["slots"]
	check_eq(slots.size(), state.graph.slot_count(), "координаты есть у всех слотов графа")
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for slot_id: String in slots.keys():
		var p := Vector2(float(slots[slot_id]["x"]), float(slots[slot_id]["y"]))
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var span: Vector2 = max_p - min_p
	check(span.x > radius * 3.0 and span.y > radius * 3.0,
		"слоты разбросаны по всей доске: %.0f x %.0f px при радиусе гекса %.0f"
			% [span.x, span.y, radius])

	# слоты РАЗНЫХ гексов не попадают в одну точку
	var collisions := 0
	var keys: Array = slots.keys()
	for i2 in range(keys.size()):
		for j2 in range(i2 + 1, keys.size()):
			var a2: Dictionary = slots[keys[i2]]
			var b2: Dictionary = slots[keys[j2]]
			if String(a2["hex"]) == String(b2["hex"]):
				continue
			if Vector2(float(a2["x"]), float(a2["y"])).distance_to(
					Vector2(float(b2["x"]), float(b2["y"]))) < 5.0:
				collisions += 1
	check_eq(collisions, 0, "нет слотов разных гексов, наложенных друг на друга")

	# у каждого тайла есть файл картинки
	var missing: Array[String] = []
	for tile: Dictionary in tiles:
		if not FileAccess.file_exists(String(tile["texture"])):
			missing.append(String(tile["texture"]))
	check(missing.is_empty(), "картинки всех тайлов на месте (нет: %s)" % [missing])


func test_vp_income_is_explained() -> void:
	section("Откуда берутся VP: начисление объяснено в срезе и в журнале")
	# Вопрос владельца игры: "за что у красного 18 VP?". Оказалось, что движок
	# ошибочно начислял VP за контроль любой локации каждый ход. Верно так:
	# в ход VP дают только маркеры контроля (A1, A3, B1-B6) и бонус гекса A2,
	# а VP обычных локаций считаются один раз в конце партии.
	var state := GameSetup.new_game(["red", "blue"], 7)
	var server := GameServer.new(state)

	var view := StateView.for_player(state, "red")
	var income: Dictionary = view["vp_income"]
	var marker: ControlMarkers.Reward = ControlMarkers.evaluate(state, "red")
	var expected_bonus: int = ClusterBonus.evaluate(state, "red").vp
	check_eq(int(income["markers"]), marker.vp, "предсказанный доход за маркеры совпадает с расчётом движка")
	check_eq(int(income["marker_influence"]), marker.influence, "и Influence маркеров тоже")
	check_eq(int(income["cluster_bonus"]), expected_bonus, "и бонус гекса A2 тоже")
	check_eq(int(income["total"]), marker.vp + expected_bonus, "итог — сумма частей, без обычных локаций")
	check_eq(int(income["final_sites"]),
		state.control.map_score("red", state.troops, state.spies),
		"отдельно показано, сколько обычные локации дадут в КОНЦЕ партии")

	# после завершения хода в журнале появляется событие с той же суммой
	var vp_before: int = state.players["red"].vp_tokens
	var res := server.apply_intent(Intent.end_turn("red"))
	var granted_now: int = state.players["red"].vp_tokens - vp_before
	check_eq(granted_now, marker.vp + expected_bonus,
		"за ход начислено ровно маркеры + бонус A2, а не VP за все локации")
	var income_event: Dictionary = {}
	for e: Dictionary in (res["events"] as Array):
		if String(e["type"]) == "vp_income":
			income_event = e
			break
	if granted_now == 0:
		check(income_event.is_empty(), "нечего начислять — события нет")
	else:
		check(not income_event.is_empty(), "событие vp_income попало в журнал")
		check_eq(int(income_event["granted"]), granted_now,
			"в событии записано, сколько VP реально начислено")
		check_eq(int(income_event["markers"]) + int(income_event["cluster_bonus"]),
			int(income_event["granted"]),
			"сумма причин совпадает с начисленным (маркеры %d + бонус %d)"
				% [int(income_event["markers"]), int(income_event["cluster_bonus"])])
		var line := EventLogPanel.describe(income_event)
		check(line.contains("control markers") or line.contains("A2 hex bonus"),
			"строка журнала объясняет причину: %s" % line)


func test_control_markers() -> void:
	section("Маркеры контроля: Influence в начале хода, VP за тотальный контроль в конце")
	var state := GameSetup.new_game(["red", "blue"], 7)
	var marked: Array[String] = ControlMarkers.marked_sites(state)
	# На доску на 2 игроков попадает один гекс A (A1 или A3) и два гекса B —
	# значит ровно три локации с маркерами. Остальные пять маркеров описаны
	# в data/board/control_markers.json для раскладок на 3-4 игроков.
	check_eq(marked.size(), 3, "на доске на 2 игроков три локации с маркерами (один A + два B)")

	# захватываем одну локацию с маркером целиком
	var site_id: String = marked[0]
	var marker: Dictionary = ControlMarkers.marker_for(state, site_id)
	check(not marker.is_empty(), "маркер найден по гексу и названию локации")
	for slot_id in state.graph.slots_of_site(site_id):
		state.troops[String(slot_id)] = "red"
	var reward: ControlMarkers.Reward = ControlMarkers.evaluate(state, "red")
	check_eq(reward.influence, int(marker["control_influence"]),
		"контроль локации с маркером даёт Influence")
	check_eq(reward.vp, int(marker["total_control_vp"]),
		"тотальный контроль добавляет VP этой локации")
	check(reward.total_control_sites.has(String(state.graph.sites[site_id]["name"])),
		"локация попала в список тотального контроля")

	var influence_before: int = state.players["red"].influence
	TurnEngine.start_turn(state, "red")
	check_eq(state.players["red"].influence - influence_before,
		reward.influence + ClusterBonus.evaluate(state, "red").influence,
		"start_turn выдал Influence маркера (и бонуса A2, если он есть)")


func test_cross_hex_site_to_site_presence() -> void:
	section("Cross-hex site-to-site tunnel gives Presence from any slot of the site")
	# Seed 13: Ath-Qua (C5) is sewn directly to Gallenghast (A2) across a hex
	# edge. A troop in a NON-port slot of Ath-Qua must still give Presence there.
	var state := GameSetup.new_game(["red", "blue"], 13, ["drow", "dragons"], false, true)
	var g := state.graph
	var ath := ""
	var gall := ""
	for s: String in g.sites.keys():
		if g.sites[s]["name"] == "Ath-Qua": ath = s
		if g.sites[s]["name"] == "Gallenghast": gall = s
	check(ath != "" and gall != "", "both sites are on the seed-13 board")
	check(g.adjacent_sites(ath).has(gall), "Ath-Qua and Gallenghast are adjacent sites")
	for slot_id in g.slots_of_site(ath):
		var troops := {slot_id: "red"}
		check(state.presence.has_presence_at_site("red", gall, troops, {}),
			"troop in %s gives Presence in Gallenghast" % slot_id)


func test_presence_slots_explain_refusal() -> void:
	section("Почему нельзя ставить войско: срез различает причины")
	# Вопрос владельца игры: "почему нельзя поставить войско в гекс B1?".
	# Ответ по правилам — нет Присутствия (рулбук стр. 11): действовать можно
	# только там, где уже есть своё войско или шпион. Чтобы интерфейс мог это
	# сказать, а не отделаться "сюда нельзя", в срезе есть presence_slots.
	var state := GameSetup.new_game(["red", "blue"], 7)
	var red: PlayerState = state.players["red"]
	red.power = 10

	var legal: Dictionary = (StateView.for_player(state, "red"))["legal"]
	var presence: Array = legal["presence_slots"]
	check(not presence.is_empty(), "есть слоты, где у red Присутствие: %d" % presence.size())

	# слоты далёкого гекса в этот список не входят
	var far_slots: Array[String] = []
	for slot_id: String in state.graph.slots.keys():
		if slot_id.begins_with("b1:"):
			far_slots.append(slot_id)
	check(not far_slots.is_empty(), "в раскладке есть гекс B1")
	var reachable := 0
	for slot_id: String in far_slots:
		if presence.has(slot_id):
			reachable += 1
	check_eq(reachable, 0, "до гекса B1 у red Присутствия нет — отказ обоснован правилами")

	# и наоборот: рядом со своим войском Присутствие есть
	var own_slot := ""
	for slot_id: String in state.troops.keys():
		if state.troops[slot_id] == "red":
			own_slot = slot_id
			break
	var neighbours := state.graph.adjacent_slots(own_slot)
	var found_neighbour := false
	for n in neighbours:
		if presence.has(String(n)):
			found_neighbour = true
			break
	check(found_neighbour, "соседний со своим войском слот доступен для Deploy")

	# с нулевым Power слоты для Deploy исчезают, а Присутствие остаётся
	red.power = 0
	var legal2: Dictionary = (StateView.for_player(state, "red"))["legal"]
	check_eq((legal2["deploy_slots"] as Array).size(), 0, "без Power разворачивать некуда")
	check(not (legal2["presence_slots"] as Array).is_empty(),
		"но Присутствие никуда не делось — интерфейс отличит 'нет Power' от 'нет Присутствия'")


# --- этап 2 доработки: исправления по аудиту (Claude outputs/audit.md) ------

## Отвечает первым "настоящим" вариантом на все решения, пока не встретится
## решение нужного типа (или решений не останется). Возвращает его или null.
func _resolve_until(state: GameState, resolver: EffectResolver, choice_type: String) -> PendingDecision:
	var guard := 0
	while resolver.is_waiting() and guard < 40:
		guard += 1
		var pd: PendingDecision = resolver.pending
		if pd.choice_type == choice_type:
			return pd
		var answer = pd.legal_options[0]
		for opt in pd.legal_options:
			if not ((typeof(opt) == TYPE_STRING and opt == "") or (typeof(opt) == TYPE_INT and opt == -1)):
				answer = opt
				break
		TurnEngine.resume_card(state, answer, resolver)
	return null


func _play(state: GameState, pid: String, card_id: String) -> EffectResolver:
	state.players[pid].deck.hand.append(card_id)
	var resolver := EffectResolver.new()
	TurnEngine.play_card(state, pid, card_id, resolver)
	return resolver


func test_audit_card_fixes() -> void:
	section("аудит: VP карт по сканам")
	check_eq(int(CardLibrary.card_data("48501")["inner_circle_vp"]), 10, "Demogorgon: 10 VP во Внутреннем круге")
	check_eq(int(CardLibrary.card_data("48734")["inner_circle_vp"]), 4, "Necromancer: 4 VP во Внутреннем круге")
	check_eq(int(CardLibrary.card_data("48324")["inner_circle_vp"]), 5, "Information Broker: 5 VP во Внутреннем круге")

	section("аудит: плата со стрелкой необязательна")
	var state := _build_rich_state()
	var red: PlayerState = state.players["red"]
	TurnEngine.start_turn(state, "red")
	var r := _play(state, "red", "48729")  # Skeletal Horde
	var pd := _resolve_until(state, r, "confirm")
	check(pd != null, "Skeletal Horde спрашивает, съесть ли себя")
	TurnEngine.resume_card(state, false, r)
	check(red.deck.played_pile.has("48729"), "отказ: карта осталась сыгранной")

	state = _build_rich_state()
	red = state.players["red"]
	TurnEngine.start_turn(state, "red")
	var devoured_before := state.devoured_pile.size()
	r = _play(state, "red", "48524")  # Mind Flayer
	check(r.is_waiting() and r.pending.legal_options.has(""), "Mind Flayer: можно не съедать карту")
	TurnEngine.resume_card(state, "", r)
	check(not r.is_waiting(), "отказ: вариантов Mind Flayer не предлагается")
	check_eq(state.devoured_pile.size(), devoured_before, "ничего не съедено")

	section("аудит: сброс — считаем карты в руке, выбирает сбрасывающий")
	state = _build_rich_state()
	var blue: PlayerState = state.players["blue"]
	var green: PlayerState = state.players["green"]
	blue.deck.hand = ["48342", "48342", "48342"] as Array[String]
	check(not ForceDiscard.new("victim", 3, "blue").is_available(state, "red"), "3 карты в руке — не сбрасывает")
	blue.deck.hand.append("48712")
	r = EffectResolver.new()
	r.apply(ForceDiscard.new("victim", 3, "blue"), "red", state)
	check(r.is_waiting() and r.pending.player_id == "blue", "4 карты — решение адресовано самому blue")
	var blue_hand_before := blue.deck.hand.size()
	r.resume(state, "48712")
	check_eq(blue.deck.hand.size(), blue_hand_before - 1 + 2, "Grimlock: после сброса blue взял 2 карты")

	green.deck.hand = ["48342", "48342", "48342", "48739"] as Array[String]
	r = EffectResolver.new()
	r.apply(ForceDiscard.new("victim", 3, "green"), "red", state)
	r.resume(state, "48739")
	check(r.is_waiting() and r.pending.player_id == "red", "Umber Hulk: виновник сброса (red) сам сбрасывает карту")

	blue.deck.hand = ["48342", "48342", "48342", "48704"] as Array[String]
	r = EffectResolver.new()
	r.apply(ForceDiscard.new("victim", 3, "blue"), "red", state)
	r.resume(state, "48704")
	check(r.is_waiting() and r.pending.choice_type == "confirm", "Ambassador: предлагает повысить вместо сброса")
	r.resume(state, true)
	check(blue.deck.inner_circle.has("48704") and not blue.deck.discard_pile.has("48704"), "Ambassador ушёл во Внутренний круг")

	check(CardLibrary.get_effect("48708") is ChooseEffect, "Nothic: сброс только внутри варианта с возвратом шпиона")

	section("аудит: трофейный зал помнит цвета")
	state = _build_rich_state()
	red = state.players["red"]
	blue = state.players["blue"]
	for pid: String in state.turn_order:
		state.players[pid].trophy_hall_count = 0
		state.players[pid].white_trophy_count = 0
	red.add_trophy("blue")
	check_eq(red.player_trophy_count(), 1, "войско игрока считается как player troop")
	check(not TakeFromTrophyHall.new(1, false, true).is_available(state, "red"), "Mummy Lord: без белых войск в залах вариант недоступен")
	red.add_trophy("white")
	check_eq(red.player_trophy_count(), 1, "белое войско не считается player troop")
	var blue_barracks := blue.troops_in_barracks
	r = EffectResolver.new()
	r.apply(TakeFromTrophyHall.new(1, false, false), "red", state)
	var labels: Array[String] = r.pending.option_labels
	var blue_index := -1
	for i in range(labels.size()):
		if labels[i].begins_with("Blue"):
			blue_index = i
	check(blue_index != -1, "в вариантах есть синее войско из зала red")
	r.resume(state, blue_index)
	check(r.is_waiting() and r.pending.choice_type == "target_slot", "дальше выбираем, куда выставить")
	var slot: String = r.pending.legal_options[0]
	r.resume(state, slot)
	check_eq(state.troops[slot], "blue", "войско выставлено своим (синим) цветом")
	check_eq(blue.troops_in_barracks, blue_barracks, "бараки blue не изменились")
	check_eq(red.trophy_hall_count, 1, "в зале red осталось одно (белое) войско")

	section("аудит: Ghost и Insane Outcast")
	state = _build_rich_state()
	red = state.players["red"]
	state.devoured_pile = ["48316"] as Array[String]  # Deathblade, стоимость 6
	r = EffectResolver.new()
	r.apply(CardLibrary._GhostDevouredPileEffect.new(), "red", state)
	check_eq(Actions.ghost_market_card(state, "red"), "48316", "Ghost: верхняя сожранная карта доступна как карта маркета")
	check_eq(Actions.ghost_market_card(state, "blue"), "", "у другого игрока эффекта нет")
	red.influence = 6
	check(Actions.recruit(state, "red", Market.DEVOURED_TOP_INDEX, 6), "её можно купить")
	check(red.deck.discard_pile.has("48316") and state.devoured_pile.is_empty(), "карта ушла в сброс покупателя")

	state = _build_rich_state()
	red = state.players["red"]
	state.supplies = Supplies.standard(true)
	var outcasts := state.supplies.remaining(Supplies.INSANE_OUTCAST)
	red.deck.discard_pile = [Supplies.INSANE_OUTCAST] as Array[String]
	r = EffectResolver.new()
	r.apply(PromoteCard.new("discard"), "red", state)
	r.resume(state, Supplies.INSANE_OUTCAST)
	check(not red.deck.inner_circle.has(Supplies.INSANE_OUTCAST), "Insane Outcast не повышается")
	check_eq(state.supplies.remaining(Supplies.INSANE_OUTCAST), outcasts + 1, "а возвращается в общую стопку")

func test_no_actions_while_decision_pending() -> void:
	section("Этап 3: пока карта ждёт ответа, интерфейсу не предлагаются действия")
	var state := GameSetup.new_game(["red", "blue"], 7, [], false, true, true)
	var server := GameServer.new(state)
	var pending: PendingDecision = server.resolver.pending
	check(pending != null, "партия начинается с вопроса о стартовой локации")
	if pending == null:
		return
	var view := StateView.for_player_with_pending(server.state, pending.player_id, pending)
	check((view["legal"] as Dictionary).is_empty(), "во время вопроса legal пуст: ни карт, ни End turn")
	check(not (view["pending_decision"] as Dictionary).is_empty(), "а сам вопрос в срезе есть")
	var result: Dictionary = server.apply_intent(Intent.end_turn(pending.player_id))
	check_eq(int(result["error"]), GameServer.Error.AWAITING_DECISION, "сервер и правда отклоняет End turn")

	var line := EventLogPanel.describe({"type": "recruit", "player_id": "red", "card_id": "48342"})
	check_eq(line, "Red recruits Noble", "журнал называет купленную карту")
	check_eq(DecisionDialog.market_label(1, ["", "48342"]), "Noble", "выбор из маркета подписан названием карты")
	check_eq(DecisionDialog.market_label(0, [""]), "Market slot 1", "пустой слот маркета — номером")


## Схема доски: правила владельца (2026-09-16) проверяются геометрически на
## нескольких настоящих раскладках. Трассы — только по осям, изгиб —
## ровно 90 градусов, через ребро гекса — посередине встречно, у каждой связи
## графа есть трасса, рамки локаций не налезают друг на друга.
func test_board_schematic() -> void:
	section("Схема доски: трассы по правилам разводки")
	for run: Array in [[2, 1], [2, 7], [2, 42], [4, 3], [4, 11]]:
		var ids: Array[String] = []
		ids.assign(["red", "blue", "green", "purple"].slice(0, int(run[0])))
		var state := GameSetup.new_game(ids, int(run[1]))
		var started := Time.get_ticks_msec()
		var s := BoardSchematic.build(state)
		var took := Time.get_ticks_msec() - started
		var tag := "%dp seed %d" % [run[0], run[1]]
		# доводка всей доски (решение владельца 2026-09-22): несколько секунд на партию
		check(took < 6000, "%s: схема собирается за приемлемое время (%d мс)" % [tag, took])
		check_eq(int(s["fallback_routes"]), 0, "%s: все трассы взяты из таблицы тайлов" % tag)

		var slots: Dictionary = s["slots"]
		var missing := 0
		for slot_id: String in state.graph.slots.keys():
			if not slots.has(slot_id):
				missing += 1
		check_eq(missing, 0, "%s: у каждого места под войско есть точка на схеме" % tag)
		check_eq((s["sites"] as Dictionary).size(), state.graph.site_count(), "%s: все локации на схеме" % tag)

		# только по осям и только повороты на 90
		var bad_angle := 0
		var bad_turn := 0
		var dir_at_port := {}   # port -> направления трасс, выходящих из него
		var ends: Dictionary = {}
		for t in (s["traces"] as Array).size():
			var flat: Array = s["traces"][t]
			var pair: Array = s["trace_ends"][t]
			ends[str(pair[0]) + "|" + str(pair[1])] = true
			ends[str(pair[1]) + "|" + str(pair[0])] = true
			var prev := -1
			for i in range(0, flat.size() - 2, 2):
				var d := Vector2(flat[i + 2] - flat[i], flat[i + 3] - flat[i + 1])
				if not (is_zero_approx(d.x) or is_zero_approx(d.y)):
					bad_angle += 1
					continue
				var dir := BoardSchematic.DIRS.find(Vector2(signf(d.x), signf(d.y)))
				if prev >= 0:
					var steps := absi(dir - prev)
					if mini(steps, 4 - steps) != 1:
						bad_turn += 1
				prev = dir
			if String(pair[0]).begins_with("port:"):
				var list: Array = dir_at_port.get(pair[0], [])
				list.append(Vector2(flat[2] - flat[0], flat[3] - flat[1]).normalized())
				dir_at_port[pair[0]] = list
		check_eq(bad_angle, 0, "%s: отрезки трасс идут только по осям" % tag)
		check_eq(bad_turn, 0, "%s: каждый изгиб трассы — ровно 90 градусов" % tag)

		# через ребро: точка — середина между центрами гексов, и обе трассы
		# сходятся в ней встречно (перпендикулярность ребру ушла вместе с
		# трассами под 45°, решение владельца 2026-09-22)
		var centres: Dictionary = s["hex_centres"]
		var bad_port := 0
		for port: String in (s["ports"] as Dictionary).keys():
			var at := Vector2(s["ports"][port][0], s["ports"][port][1])
			var dirs: Array = dir_at_port.get(port, [])
			var hex: String = port.get_slice(":", 1)
			var outward := at - Vector2(centres[hex][0], centres[hex][1])
			var mirrored := Vector2(centres[hex][0], centres[hex][1]) + outward * 2.0
			var neighbour_found := false
			for other: String in centres.keys():
				if Vector2(centres[other][0], centres[other][1]).is_equal_approx(mirrored):
					neighbour_found = true
			if dirs.size() != 2 or not neighbour_found \
					or not (dirs[0] as Vector2).is_equal_approx(-(dirs[1] as Vector2)):
				bad_port += 1
		check_eq(bad_port, 0, "%s: трассы сходятся встречно в середине ребра гекса" % tag)

		# у каждой связи графа есть трасса (напрямую или через середину ребра)
		var node_of := func(slot_id: String) -> String:
			var site := state.graph.site_of_slot(slot_id)
			return site if site != "" else slot_id
		var unlinked := 0
		for slot_id: String in state.graph.slots.keys():
			for other: String in state.graph.adjacent_slots(slot_id):
				var a: String = node_of.call(slot_id)
				var b: String = node_of.call(other)
				if a == b or ends.has(a + "|" + b):
					continue
				var via_port := false
				for port: String in (s["ports"] as Dictionary).keys():
					if ends.has(a + "|" + port) and ends.has(b + "|" + port):
						via_port = true
				if not via_port:
					unlinked += 1
		check_eq(unlinked, 0, "%s: у каждой связи графа есть трасса" % tag)

		var rects: Array = []
		for site_id: String in (s["sites"] as Dictionary).keys():
			var r: Array = s["sites"][site_id]["rect"]
			rects.append(Rect2(r[0], r[1], r[2], r[3]))
		for ring_id: String in (s["rings"] as Dictionary).keys():
			var p: Array = s["rings"][ring_id]
			rects.append(Rect2(p[0] - BoardSchematic.RING_R, p[1] - BoardSchematic.RING_R,
				BoardSchematic.RING_R * 2, BoardSchematic.RING_R * 2))
		var overlaps := 0
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				if (rects[i] as Rect2).intersects(rects[j]):
					overlaps += 1
		check_eq(overlaps, 0, "%s: рамки локаций и кольца не налезают друг на друга" % tag)

	var board := StateView.board_snapshot(GameSetup.new_game(["red", "blue"], 5))
	var image := SchematicPainter.paint(board["schematic"])
	check(image.get_width() > 200 and image.get_height() > 100, "схема рисуется в картинку")

	# Подсветка мест (Deploy, Assassinate, цели решения) не должна вылезать за
	# половину шага между местами: в локации с девятью местами (Wells of
	# Darkness) широкие кольца сливались в зелёное пятно поверх названия.
	check(BoardPanel.highlight_radius_world(false) * 2.0 <= BoardSchematic.SLOT_PITCH,
		"кольцо подсветки пустого места уже шага между местами")
	check(BoardPanel.highlight_radius_world(true) * 2.0 <= BoardSchematic.SLOT_PITCH,
		"кольцо подсветки вокруг фишки уже шага между местами")


func test_background_palette() -> void:
	section("Фон экрана: краска по полуколодам партии")
	const Bg := preload("res://scenes/ui/underdark_bg.gd")

	var state := GameSetup.new_game(["red", "blue"], 7, ["drow", "dragons"])
	check_eq(state.half_decks, ["drow", "dragons"] as Array[String],
		"партия помнит свои полуколоды")
	var snapshot := StateView.board_snapshot(state)
	check_eq(snapshot.get("half_decks", []), ["drow", "dragons"] as Array[String],
		"полуколоды доезжают до экрана в board_snapshot")

	var chosen := Bg.palette(snapshot["half_decks"])
	check_eq(chosen[0], Bg.DECK_COLOURS["drow"], "первая краска — цвет первой полуколоды")
	check_eq(chosen[1], Bg.DECK_COLOURS["dragons"], "вторая краска — цвет второй полуколоды")

	# Случайная партия: полуколоды выбираются сами, но краска всё равно нужна.
	var any := GameSetup.new_game(["red", "blue"], 11)
	check_eq(any.half_decks.size(), 2, "случайная партия тоже помнит две полуколоды")

	# Фон никогда не остаётся одноцветным: ни без полуколод, ни с мусором,
	# ни когда обе полуколоды почему-то одинаковые.
	for bad: Array in [[], ["no_such_deck"], ["drow"], ["drow", "drow"]]:
		var colours := Bg.palette(bad)
		check_eq(colours.size(), 2, "%s: две краски" % [bad])
		check(colours[0] != colours[1], "%s: краски разные" % [bad])
