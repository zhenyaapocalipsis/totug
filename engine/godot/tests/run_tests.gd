extends SceneTree

## Минимальный раннер тестов ядра. Запуск:
##   godot --headless --path godot --script res://tests/run_tests.gd
##
## Умышленно без внешних зависимостей (GUT можно подключить позже) — ядро правил
## не тянет ни сцен, ни рендера, поэтому достаточно обычного скрипта.

var _passed := 0
var _failed := 0
var _current := ""

const GameSettings := preload("res://scenes/game_settings.gd")


func _initialize() -> void:
	print("\n=== тесты ядра ===\n")
	# Свой файл профиля: тесты экрана профиля не должны трогать настоящий.
	PlayerProfile.path_override = "user://profile_test.cfg"
	# Настройки игрока (скорость анимаций, клавиши) тестам не указ.
	GameSettings.path_override = "user://settings_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.path_override))
	# Свой файл запомненной онлайн-партии — не трогать настоящий.
	NetSession.resume_path = "user://online_game_test.cfg"
	NetSession.forget_game()

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
	test_final_breakdown()
	test_rating()
	test_skin_collection()
	test_cluster_bonus()

	# этап 5: система эффектов карт
	test_effect_resolver_basics()
	test_choose_and_optional()
	test_focus_effect()
	test_deploy_and_assassinate_effects()
	test_devour_and_promote_effects()
	test_card_library_smoke_all_cards()
	test_celestial_order()
	test_shield_guardian_reaction()
	test_shadow_isles()

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
	test_a2_bonus_mid_turn()


	# этап 7: настоящая партия и общие стопки
	test_half_deck_data()
	test_game_modes()
	test_game_setup_real_game()
	test_hotseat_three_and_four_players()
	test_market_mulligan()
	test_auto_decision_answer()
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

	# сеть
	test_public_address_check()
	test_player_profile()
	test_chat_wheel_and_ping()
	test_card_back()
	test_how_to_play()
	test_main_menu()

	# этап 7: сохранение партии и восстановление после перезапуска
	test_game_journal_replay()
	test_replay_book()
	test_room_pause()
	test_colour_preference()
	test_resume_saved_game()
	test_music_stems_and_moods()

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

	# Жалоба владельца 2026-09-30: единицы кончились — и доход меньше 5 VP
	# (тотальный контроль, Deploy при пустом бараке) давал 0.
	var change := VPBank.new(0, 2)
	check_eq(change.grant(1), 1, "единиц нет — пятёрка разменивается, выдан 1 VP")
	check_eq(change.fives, 1, "одна пятёрка ушла в размен")
	check_eq(change.ones, 4, "сдача — 4 единицы")
	check_eq(change.grant(3), 3, "из сдачи выдано ещё 3")

	var poor := VPBank.new(2, 0)  # только единицы
	check_eq(poor.grant(5), 5, "запрошено 5, в банке 2 единицы — всё равно выдано 5")
	check_eq(poor.ones, 0, "банк опустошён")
	check_eq(poor.extra, 3, "3 VP выданы сверх запаса")
	check_eq(poor.grant(1), 1, "и из пустого банка VP выдаются")
	check_eq(poor.extra, 4, "сверх запаса уже 4")

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
	check_eq(state.final_round_ends_after_index, 2, "круг доигрывается до p3 (последний в порядке хода)")

	GameEnd.trigger(state, "last_troop")
	check_eq(state.game_end_reason, "market_empty", "повторный триггер не переписывает причину")

	# p2 (индекс 1) заканчивает ход — это не последний ход круга
	check(not GameEnd.advance_turn(state), "после p2 партия ещё не закончена")
	check_eq(state.current_player_index, 2, "ход переходит к p3")

	check(GameEnd.advance_turn(state), "после p3 партия заканчивается")
	check(state.game_over, "game_over выставлен")

	# 1 на 1: второй игрок вызвал конец — его ход последний
	var duel := GameState.new(_build_ab_graph(), 1)
	duel.add_player("p1", [])
	duel.add_player("p2", [])
	duel.current_player_index = 1
	GameEnd.trigger(duel, "last_troop")
	check(GameEnd.advance_turn(duel), "1v1: после хода p2 партия заканчивается")

	# 1 на 1: первый игрок вызвал конец — второй ещё ходит
	var duel2 := GameState.new(_build_ab_graph(), 1)
	duel2.add_player("p1", [])
	duel2.add_player("p2", [])
	GameEnd.trigger(duel2, "last_troop")
	check(not GameEnd.advance_turn(duel2), "1v1: после хода p1 ходит p2")
	check(GameEnd.advance_turn(duel2), "1v1: после хода p2 партия заканчивается")

	# 4 игрока: кто бы ни вызвал конец, последний ход — у p4
	for trigger_seat in 4:
		var four := GameState.new(_build_ab_graph(), 1)
		for n in 4:
			four.add_player("p%d" % (n + 1), [])
		four.current_player_index = trigger_seat
		GameEnd.trigger(four, "last_troop")
		var turns_left := 0
		while not GameEnd.advance_turn(four):
			turns_left += 1
		check_eq(turns_left, 3 - trigger_seat, "4p: триггер у p%d — ещё ходов до конца" % (trigger_seat + 1))
		check_eq(four.current_player_index, 3, "4p: триггер у p%d — последним ходит p4" % (trigger_seat + 1))


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


func test_final_breakdown() -> void:
	section("итоги партии по статьям")
	var state := _build_two_player_state()
	var red: PlayerState = state.players["red"]
	state.troops["a1"] = "red"
	state.troops["a2"] = "red"
	state.troops["b1"] = "blue"
	red.trophy_hall_count = 2
	red.vp_tokens = 7
	red.deck = Deck.new(["48734", "48324"])
	red.deck.inner_circle = ["48501"]

	var s := Scoring.breakdown(state, "red")
	check_eq(int(s["sites"]), 4, "red: VP сайта site_a")
	check_eq(int(s["total_control"]), 2, "red: +2 за тотальный контроль")
	check_eq(int(s["trophies"]), 2, "red: трофеи")
	check_eq(int(s["inner_circle"]), 10, "red: Demogorgon во Внутреннем круге = 10")
	check_eq(int(s["tokens"]), 7, "red: VP-жетоны")
	var vp := Scoring.library_card_vp(state)
	check_eq(int(s["total"]), Scoring.final_score(state, "red", vp[0], vp[1]),
			"сумма статей = final_score с VP карт из библиотеки")

	# Срез состояния — на полной партии (у мини-графа нет рынка).
	var rich := _build_rich_state(55)
	var view := StateView.for_player(rich, "blue")
	check(not view.has("final_scores"), "до конца партии итогов в срезе нет")
	rich.game_over = true
	rich.players["red"].vp_tokens = 50
	view = StateView.for_player(rich, "blue")
	check(view.has("final_scores") and view["final_scores"].has("blue"), "после конца — итоги всех игроков")
	check_eq(view["winners"], ["red"], "победитель red")


func test_rating() -> void:
	section("рейтинг Эло")
	var d := RatingBook.elo_deltas({"red": 1000, "blue": 1000}, {"red": 40, "blue": 30})
	check_eq(d["red"], 16, "1v1 равные: победитель +16")
	check_eq(d["blue"], -16, "1v1 равные: проигравший -16")
	d = RatingBook.elo_deltas({"red": 1000, "blue": 1000}, {"red": 30, "blue": 30})
	check_eq(d["red"], 0, "ничья равных — без изменений")
	d = RatingBook.elo_deltas({"red": 1200, "blue": 1000}, {"red": 40, "blue": 30})
	check(int(d["red"]) < 16 and int(d["red"]) > 0, "сильный за победу над слабым получает меньше")
	d = RatingBook.elo_deltas({"red": 1000, "blue": 1000, "green": 1000, "purple": 1000},
			{"red": 50, "blue": 40, "green": 30, "purple": 20})
	check_eq(d["red"], 16, "на четверых: первый +16 (как 1v1)")
	check_eq(int(d["red"]) + int(d["blue"]) + int(d["green"]) + int(d["purple"]), 0, "на четверых: сумма 0")

	var path := "user://ratings_test.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var book := RatingBook.new(path)
	var a := RatingBook.account_of("0123456789abcdef0123456789abcdef")
	var b := RatingBook.account_of("fedcba9876543210fedcba9876543210")
	check(a != "" and a != b, "ключ даёт учётную запись")
	check_eq(RatingBook.account_of("short"), "", "короткий ключ не годится")
	var r := book.record({"red": {"account": a, "name": "Ann"}, "blue": {"account": b, "name": "Bob"}},
			{"red": 40, "blue": 30}, ["red"])
	check_eq(r["red"]["rating"], 1016, "рейтинг победителя записан")
	check_eq(RatingBook.new(path).rating_of(b), 984, "рейтинг сохранён в файл")
	check_eq(int(book.accounts[a]["wins"]), 1, "победа засчитана")
	check_eq(int(r["red"]["games"]), 1, "итог партии несёт число партий")
	check_eq(book.stats_of(b), {"rating": 984, "games": 1, "wins": 0}, "карточка игрока: рейтинг, партии, победы")
	check_eq(book.stats_of("nobody"), {"rating": 1000, "games": 0, "wins": 0}, "карточка новичка")

	# Звания и история партий в профиле.
	check_eq(PlayerProfile.rank_title(-1), "UNRANKED", "без рейтинга — без звания")
	check_eq(PlayerProfile.rank_title(1000), "WARRIOR", "новичок — WARRIOR")
	check_eq(PlayerProfile.rank_title(949), "DRIDER", "ниже 950 — DRIDER")
	check_eq(PlayerProfile.rank_title(5000), "TYRANT", "высший — TYRANT")
	var res := {"red": {"rating": 990, "delta": -10, "vp": 40, "won": false},
		"blue": {"rating": 1020, "delta": 20, "vp": 40, "won": true},
		"green": {"rating": 995, "delta": -5, "vp": 30, "won": false}}
	var profs := {"red": {"name": "Ann", "emblem": ""}, "blue": {"name": "Bob", "emblem": ""}}
	var entry := PlayerProfile.history_entry("red", res, profs)
	check_eq(entry["place"], 2, "равные VP, но победил другой — второе место")
	check_eq(entry["players"][0]["name"], "Bob", "победитель в списке первым")
	check_eq(PlayerProfile.history_entry("green", res, profs)["place"], 3, "третье место")
	check_eq(PlayerProfile.history_entry("blue", res, profs)["place"], 1, "победитель — первое место")
	var old_path := PlayerProfile.path_override
	PlayerProfile.path_override = "user://profile_history_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProfile.path_override))
	for n in PlayerProfile.HISTORY_MAX + 2:
		entry["vp"] = n
		PlayerProfile.add_history(entry)
	var hist := PlayerProfile.history()
	check_eq(hist.size(), PlayerProfile.HISTORY_MAX, "история хранит только последние партии")
	check_eq(int(hist[0]["vp"]), PlayerProfile.HISTORY_MAX + 1, "новая партия — первой")
	PlayerProfile.cache_stats({"rating": 1016, "games": 3, "wins": 2})
	PlayerProfile.cache_stats({"rating": 1020})
	check_eq(PlayerProfile.cached_stats(), {"rating": 1020, "games": 3, "wins": 2}, "статистика запомнена в профиле")

	# Статистика по самой игре: суммы по статьям VP, полуколоды, рекорды.
	check_eq(int(PlayerProfile.totals()["games"]), 0, "без партий с разбивкой — пусто")
	PlayerProfile.add_totals(entry)
	check_eq(int(PlayerProfile.totals()["games"]), 0, "партия без разбивки (старый сервер) не в счёт")
	var parts := {"sites": 10, "total_control": 2, "trophies": 7, "deck": 12, "inner_circle": 6, "tokens": 3, "total": 40}
	var game_a := {"red": {"rating": 1016, "delta": 16, "vp": 40, "won": true, "breakdown": parts,
		"half_decks": ["drow", "dragons"], "ic_cards": 5}, "blue": {"rating": 984, "delta": -16, "vp": 30, "won": false}}
	var entry_a := PlayerProfile.history_entry("red", game_a, profs)
	check_eq(entry_a["breakdown"]["trophies"], 7, "в истории — разбивка VP")
	PlayerProfile.add_totals(entry_a)
	var parts_b := {"sites": 6, "total_control": 0, "trophies": 3, "deck": 10, "inner_circle": 8, "tokens": 1, "total": 28}
	PlayerProfile.add_totals({"vp": 28, "won": false, "breakdown": parts_b, "half_decks": ["drow", "undead"],
		"ic_cards": 7})
	var tot := PlayerProfile.totals()
	check_eq(int(tot["games"]), 2, "две партии с разбивкой")
	check_eq(int(tot["vp"]), 68, "сумма VP")
	check_eq(int(tot["parts"]["trophies"]), 10, "сумма трофеев")
	check_eq(tot["decks"]["drow"], {"games": 2, "wins": 1}, "полуколода: партии и победы")
	check_eq(tot["decks"]["undead"], {"games": 1, "wins": 0}, "вторая полуколода")
	check(int(tot["best_vp"]) == 40 and int(tot["most_trophies"]) == 7 and int(tot["most_ic"]) == 7, "рекорды")

	# Карточка игрока по щелчку на имя.
	var card := ProfileCard.new("blue", {"name": "Bob", "emblem": "", "rating": 1160, "games": 10, "wins": 4})
	var card_text := _all_text(card)
	check(card_text.contains("Bob") and card_text.contains("MATRON") and card_text.contains("RATING 1160")
		and card_text.contains("WIN RATE 40%"), "карточка: имя, звание, рейтинг, процент побед")
	card.free()
	var local_card := ProfileCard.new("red", {"name": "Ann", "emblem": ""})
	check(_all_text(local_card).contains("No online rating"), "за одним экраном — без рейтинга")
	local_card.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProfile.path_override))
	PlayerProfile.path_override = old_path
	var same := book.record({"red": {"account": a, "name": "Ann"}, "blue": {"account": a, "name": "Ann"}},
			{"red": 40, "blue": 30}, ["red"])
	check(same.is_empty(), "один человек за двумя цветами — партия без рейтинга")

	# Имена на сервере уникальны: имя закреплено за учётной записью (ключом).
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ratings_test_names.json"))
	book = RatingBook.new(path)
	check(book.claim_name(a, "Ann"), "свободное имя занимается")
	check(book.claim_name(a, "Ann"), "своё имя — снова можно")
	check(not book.claim_name(b, "ANN "), "чужое имя (другой регистр, пробел) — нельзя")
	check(not RatingBook.new(path).claim_name(b, "ann"), "занятое имя сохранено в файл")
	check(book.claim_name(a, "Anna"), "смена имени")
	check(book.claim_name(b, "Ann"), "после смены старое имя свободно")
	check(book.claim_name(b, "") and book.claim_name("", "Anna") == true,
		"пустое имя и игрок без ключа ничего не занимают")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_skin_collection() -> void:
	section("коллекция: лутбоксы, пыль, шейдеры на всю колоду")
	var odds := 0
	for tier in SkinCollection.TIERS:
		odds += int(SkinCollection.BOX_ODDS[tier])
	check_eq(odds, 100, "шансы лутбокса в сумме 100%")
	check_eq(SkinCollection.tier_for_roll(0), "epic", "бросок 0 — EPIC")
	check_eq(SkinCollection.tier_for_roll(80), "legendary", "бросок 80 — LEGENDARY")
	check_eq(SkinCollection.tier_for_roll(99), "ultra", "бросок 99 — ULTRA")
	check_eq(SkinCollection.SHADER_TIER, "ultra", "все шейдеры — ступени ULTRA")

	# Награда за место: первое — лутбокс, остальные — пыль.
	var res := {"red": {"vp": 40, "won": true}, "blue": {"vp": 35, "won": false},
		"green": {"vp": 20, "won": false}, "purple": {"vp": 30, "won": false}}
	check_eq(PlayerProfile.place_of("red", res), 1, "победитель — первое место")
	check_eq(PlayerProfile.place_of("purple", res), 3, "третье место по VP")
	check_eq(SkinCollection.reward_for_place(1), {"boxes": 1}, "первое место — лутбокс")
	check_eq(SkinCollection.reward_for_place(2), {"dust": 40}, "второе — 40 пыли")
	check_eq(SkinCollection.reward_for_place(4), {"dust": 20}, "четвёртое — 20 пыли")

	var old_path := PlayerProfile.path_override
	PlayerProfile.path_override = "user://profile_skins_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProfile.path_override))
	var rng := RandomNumberGenerator.new()
	check(SkinCollection.open_box(rng).is_empty(), "без лутбоксов открывать нечего")
	SkinCollection.grant({"boxes": 300, "dust": 150})
	SkinCollection.grant({"dust": 60})
	check_eq(int(SkinCollection.load_data()["dust"]), 210, "награды копятся в профиле")
	# Много лутбоксов: шейдер — только с ULTRA, арт — с EPIC и LEGENDARY (по
	# ступени), повтор — пыль.
	var shaders := 0
	var new_arts := 0
	var first := {}
	var right := true
	for i in 300:
		rng.seed = i
		var got := SkinCollection.open_box(rng)
		if String(got["shader"]) != "":
			shaders += 1
			right = right and got["tier"] == "ultra"
			if first.is_empty():
				first = got
		else:
			var art := String(got["art"])
			right = right and art != "" and AltArts.tier_of(art) == String(got["tier"])
			if got["duplicate"]:
				right = right and int(got["dust"]) == int(SkinCollection.DUPLICATE_DUST[got["tier"]])
			else:
				new_arts += 1
				right = right and int(got["dust"]) == 0
	check(right, "арт выпадает ступенью своей редкости, повтор даёт пыль по ступени")
	check(shaders > 0 and shaders < 30, "шейдеры редки, как ULTRA (%d из 300)" % shaders)
	check(not first.is_empty() and not first["duplicate"] and SkinCollection.owns_shader(String(first["shader"])),
		"первый выпавший шейдер лёг в коллекцию")
	check_eq(SkinCollection.active_shader(), String(first["shader"]), "первый шейдер сразу включён")
	check_eq(int(SkinCollection.load_data()["boxes"]), 0, "лутбоксы потрачены")
	var owned_arts := 0
	for item: String in SkinCollection.load_data()["owned"]:
		owned_arts += 1 if item.begins_with("alt:") else 0
	check(new_arts > 30 and owned_arts == new_arts, "новые арты легли в коллекцию (%d)" % new_arts)
	check_eq((SkinCollection.load_data()["arts"] as Dictionary).size() > 0, true, "первый арт карты сразу включён")

	# Создание за пыль и переключение.
	var cfg := ConfigFile.new()
	cfg.load(PlayerProfile.path())
	cfg.set_value("collection", "owned", [SkinCollection.shader_key("faerie")])
	cfg.set_value("collection", "shader", "faerie")
	cfg.set_value("collection", "dust", 1700)
	cfg.save(PlayerProfile.path())
	check(not SkinCollection.set_shader("prism"), "не открытый шейдер не включается")
	check(SkinCollection.craft_shader("prism"), "шейдер создаётся за пыль ULTRA")
	check_eq(int(SkinCollection.load_data()["dust"]), 100, "списано 1600 пыли")
	check_eq(SkinCollection.active_shader(), "prism", "созданный шейдер сразу включён")
	check(not SkinCollection.craft_shader("prism") and not SkinCollection.craft_shader("gilded"),
		"второй раз и без пыли — не создаётся")
	check(SkinCollection.set_shader("") and SkinCollection.active_shader() == "", "шейдер можно снять")
	check(SkinCollection.set_shader("faerie"), "открытый шейдер включается")
	check_eq(PlayerProfile.load_local()["shader"], "faerie", "включённый шейдер — в профиле для партии")
	check_eq(SkinCollection.clean_shader("gold"), "", "чужой шейдер из сети проверяется")

	# Альтернативные арты: данные, создание за пыль, выбор.
	check(AltArts.TIER_OF.size() >= 60, "в игре есть альтернативные арты (%d)" % AltArts.TIER_OF.size())
	var all_found := true
	for art: String in AltArts.TIER_OF:
		all_found = all_found and AltArts.full_texture(art) != null and AltArts.mini_texture(art) != null \
			and not CardLibrary.card_data(AltArts.card_of(art)).is_empty() \
			and SkinCollection.TIERS.has(AltArts.tier_of(art))
	check(all_found, "у каждого арта есть полная и мини-картинка, карта и ступень")
	check_eq(AltArts.arts_of("48310"), ["48310_1"] as Array[String], "арты карты — по её номеру")
	check_eq(AltArts.clean("пусто"), "", "чужой арт из файла проверяется")
	cfg = ConfigFile.new()
	cfg.load(PlayerProfile.path())
	cfg.set_value("collection", "owned", [SkinCollection.shader_key("faerie")])
	cfg.set_value("collection", "arts", {"48310": "48310_1"})
	cfg.set_value("collection", "dust", 250)
	cfg.save(PlayerProfile.path())
	check_eq(SkinCollection.art_of("48310"), "", "не открытый арт в файле не включается")
	check(not SkinCollection.set_art("48310", "48310_1"), "не открытый арт не включается")
	check(SkinCollection.craft_art("48310_1"), "арт создаётся за пыль своей ступени")
	check_eq(int(SkinCollection.load_data()["dust"]), 250 - int(SkinCollection.CRAFT_COST[AltArts.tier_of("48310_1")]),
		"списана цена ступени арта")
	check_eq(SkinCollection.art_of("48310"), "48310_1", "созданный арт сразу включён")
	check(not SkinCollection.craft_art("48310_1"), "второй раз арт не создаётся")
	check(SkinCollection.set_art("48310", "") and SkinCollection.art_of("48310") == "", "арт можно снять — оригинал")
	check(SkinCollection.set_art("48310", "48310_1"), "открытый арт включается")
	check(not SkinCollection.set_art("48302", "48310_1"), "арт чужой карты не включается")
	var art_view := CardView.new("48310", 176, 254)
	var plain_tex := art_view._pixel
	art_view.set_art("48310_1")
	check(art_view._pixel != null and art_view._pixel != plain_tex, "карта показывает альтернативный арт")
	art_view.set_card("48302")
	check(art_view.art == "" and art_view._pixel != null, "арт другой карты сбрасывается")
	art_view.free()

	# Партия: шейдер владельца на любой его карте, стартовые — тоже.
	PlayerProfile.seats = {"red": PlayerProfile.clean({"name": "Ann", "shader": "prism"})}
	check_eq(PlayerProfile.shader_of("red"), "prism", "шейдер игрока за столом")
	check_eq(PlayerProfile.shader_of("blue"), "", "у игрока без профиля шейдера нет")
	var owned_view := CardView.new("48306", 58, 84)
	owned_view.set_card_owner("red")
	check_eq(owned_view.skin, "prism", "карта игрока — с его шейдером")
	var mat := owned_view.material as ShaderMaterial
	check(mat != null and int(mat.get_shader_parameter("tier")) == 3, "PRISM рисует эффект призмы")
	check_eq(mat.get_shader_parameter("face_size"), Vector2(58, 84), "шейдер знает, что лицо мелкое")
	owned_view.set_card("48342")
	check_eq(owned_view.skin, "prism", "стартовая карта (Noble) — тоже с шейдером")
	var market_view := CardView.new("48306", 176, 254)
	check(market_view.skin == "" and market_view.material == null, "карта маркета (ничья) — без шейдера")
	market_view.set_card_owner("blue")
	check_eq(market_view.skin, "", "у игрока без шейдера карта обычная")
	owned_view.free()
	market_view.free()
	PlayerProfile.seats = {}

	# Альтернативные арты в партии: арт владельца — только на его карте, у других и
	# в маркете оригинал; строка артов чистится при приёме из сети.
	check_eq(AltArts.clean_list("48403_2,48310_1,48310_1,x,48403_1"), "48310_1,48403_2",
		"строка артов: известные, по одному на карту, по порядку")
	check_eq(AltArts.clean_list(null), "", "пустая строка артов")
	check_eq(AltArts.map_to_list(AltArts.list_to_map("48310_1,48403_2")), "48310_1,48403_2", "строка <-> словарь артов")
	PlayerProfile.seats = {"red": PlayerProfile.clean({"name": "Ann", "arts": "48403_2,48310_1,мусор"}),
		"blue": PlayerProfile.clean({"name": "Bob"})}
	check_eq(PlayerProfile.seats["red"]["arts"], "48310_1,48403_2", "профиль за столом хранит чистую строку артов")
	check_eq(PlayerProfile.art_of("red", "48403"), "48403_2", "арт карты игрока за столом")
	check_eq(PlayerProfile.art_of("red", "48302"), "", "у карты без выбранного арта оригинал")
	check_eq(PlayerProfile.art_of("blue", "48403"), "", "у игрока без артов оригинал")
	var red_blue := CardView.new("48403", 176, 254)
	var plain_dragon: Texture2D = red_blue._pixel
	red_blue.set_card_owner("red")
	check(red_blue.art == "48403_2" and red_blue._pixel != plain_dragon, "карта игрока показывает его арт")
	red_blue.set_card("48310")
	check_eq(red_blue.art, "48310_1", "другая его карта — свой арт")
	red_blue.set_card("48302")
	check(red_blue.art == "" and red_blue._pixel != null, "карта без арта — оригинал")
	red_blue.set_card_owner("blue")
	red_blue.set_card("48403")
	check(red_blue.art == "" and red_blue._pixel == plain_dragon, "у соперника без арта карта обычная")
	var market_dragon := CardView.new("48403", 176, 254)
	check(market_dragon.art == "" and market_dragon._pixel == plain_dragon, "карта маркета — оригинальный арт")
	red_blue.free()
	market_dragon.free()
	check_eq(String(PlayerProfile.clean({"arts": "48403_2"})["arts"]), "48403_2", "арты проходят PlayerProfile.clean")

	# Витрина: покупка карты с артом — оригинал превращается в арт, потом улетает.
	var show := CardShowcase.new()
	var seen: Array[String] = []
	var face_in_morph: Texture2D = null
	var face_in_hold: Texture2D = null
	show.show_card("48310", "RED RECRUITS", Color.RED, null, Vector2(10, 10), false, "", "48310_1", true)
	var plain_face := CardView.pixel_texture("48310")
	var alt_face := AltArts.full_texture("48310_1")
	for i in 600:
		if seen.is_empty() or seen.back() != show._phase:
			seen.append(show._phase)
		if show._phase == "morph" and face_in_morph == null:
			face_in_morph = show._face()
		if show._phase == "hold" and face_in_hold == null:
			face_in_hold = show._face()
		if not show.is_busy():
			break
		show._process(0.02)
	check_eq(seen.slice(0, 4), ["enter", "morph", "hold", "exit"] as Array[String],
		"витрина: появление, превращение в арт, показ, уход")
	check(face_in_morph == plain_face and face_in_hold == alt_face, "в превращении оригинал, после — арт")
	check(not show.is_busy(), "витрина с превращением доигрывает до конца")
	show.show_card("48310", "RED RECRUITS", Color.RED, null, Vector2(10, 10), false, "", "48310_1", false)
	check(show._face() == alt_face and show._item["morph"] == false, "карта с артом без покупки сразу с артом")
	show.skip()
	show._queue.clear()
	show._next()
	show.show_card("48302", "RED RECRUITS", Color.RED, null, Vector2(10, 10), false, "", "48310_1", true)
	check(show._item["art"] == "" and show._item["morph"] == false, "арт чужой карты витрина не показывает")

	# Образ владельца сопровождает карту и на витрине: не на рынке (карта ещё
	# ничья) и не рубашкой, а лицом, когда она его.
	show._queue.clear()
	show._next()
	show.show_card("48306", "RED RECRUITS", Color.RED, Vector2(5, 5), Vector2(10, 10), false, "", "", false, "prism")
	check_eq(show._slot_skin(0), "", "карта летит с рынка — образа ещё нет")
	show._set_phase("hold")
	check_eq(show._slot_skin(0), "prism", "карта стала своей — с образом владельца")
	show._set_phase("exit")
	check_eq(show._slot_skin(0), "prism", "в полёте образ с картой")
	show._set_phase("back")
	check_eq(show._slot_skin(0), "", "рубашкой вверх образа нет")
	var layer := CardShowcase.SlotLayer.new(show, 0)
	layer.set_skin("prism", false)
	var layer_mat := layer.material as ShaderMaterial
	check(layer_mat != null and int(layer_mat.get_shader_parameter("tier")) == 3, "слой витрины рисует PRISM")
	check_eq(layer_mat.get_shader_parameter("face_size"), CardView.PIXEL_SIZE, "на крупной карте лицо полное")
	layer.set_skin("prism", true)
	check_eq(layer_mat.get_shader_parameter("face_size"), CardView.MINI_SIZE, "в полёте лицо мелкое")
	layer.set_skin("", true)
	check(layer.material == null, "без образа слой без материала")
	layer.free()
	show._queue.clear()
	show._next()
	var row: Array[Dictionary] = [{"text": "A", "colour": Color.RED, "to": Vector2(1, 1), "shader": "gilded"},
		{"text": "B", "colour": Color.BLUE, "to": Vector2(2, 2), "shader": ""}]
	show.show_row("48342", row)
	show._set_phase("hold")
	check(show._slot_skin(0) == "gilded" and show._slot_skin(1) == "", "в ряду у каждой карты образ своего получателя")
	PlayerProfile.seats = {"red": PlayerProfile.clean({"name": "Ann", "shader": "prism", "arts": "48310_1"})}
	var option := OptionCard.new("48310", "Infiltrate", "red")
	var option_mat := option.material as ShaderMaterial
	check(option_mat != null and int(option_mat.get_shader_parameter("tier")) == 3, "карта с вариантами — с образом владельца")
	option.free()
	check(OptionCard.new("48310", "Infiltrate").material == null, "без владельца карта с вариантами обычная")
	PlayerProfile.seats = {}
	show.free()
	PlayerProfile.seats = {}

	# Вкладка COLLECTION профиля.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProfile.path_override))
	SkinCollection.grant({"boxes": 1, "dust": 100})
	var profile_screen := ProfileScreen.new()
	check(_find_button(profile_screen, "COLLECTION") != null, "в профиле есть вкладка COLLECTION")
	profile_screen.free()
	var page := CollectionPage.new()
	check(_find_button(page, "SHADERS") != null and _find_button(page, "CARDS") != null,
		"в коллекции разделы CARDS и SHADERS")
	check(_all_text(page).contains("DUST 100") and _all_text(page).contains("LOOT BOXES 1"),
		"вкладка показывает пыль и лутбоксы")
	check(CollectionPage.faction_cards("starting").has("48342"), "в CARDS есть и стартовые карты")
	page._rng.seed = 1
	var dropped := page.open_box()
	check(not dropped.is_empty() and _all_text(page).contains("LOOT BOXES 0"), "лутбокс открыт и потрачен")
	check(page.open_box().is_empty(), "лутбоксов больше нет — открывать нечего")
	page.select_shader("gilded")
	page.press_shader()
	check(_all_text(page).contains("Not enough dust") and not SkinCollection.owns_shader("gilded"),
		"пыли мало — шейдер не создан")
	SkinCollection.grant({"dust": 1600})
	page.press_shader()
	check(_all_text(page).contains("Click again") and not SkinCollection.owns_shader("gilded"),
		"первый щелчок только показывает цену")
	page.press_shader()
	check(SkinCollection.owns_shader("gilded") and SkinCollection.active_shader() == "gilded",
		"второй щелчок создаёт и включает шейдер")
	page.select_shader("")
	page.press_shader()
	check_eq(SkinCollection.active_shader(), "", "PLAIN — колода без шейдера")
	page.select_shader("gilded")
	page.press_shader()
	check_eq(SkinCollection.active_shader(), "gilded", "открытый шейдер включается одним щелчком")
	# Вкладка CARDS: арты выбранной карты.
	SkinCollection.grant({"dust": 1000})
	page.show_faction(CollectionPage.faction_of("48310"))
	page.select("48310")
	check(_find_button(page, " ORIGINAL  ON") != null and AltArts.arts_of("48310").is_empty() == false,
		"у карты с артом в списке оригинал и альтернативные")
	var alt := AltArts.arts_of("48310")[0]
	page.select_art(alt)
	page.press_art()
	check(_all_text(page).contains("Click again") and not SkinCollection.owns_art(alt), "первый щелчок по арту показывает цену")
	page.press_art()
	check(SkinCollection.owns_art(alt) and SkinCollection.art_of("48310") == alt, "второй щелчок создаёт и включает арт")
	page.select_art("")
	page.press_art()
	check_eq(SkinCollection.art_of("48310"), "", "ORIGINAL — карта без альтернативного арта")
	page.select_art(alt)
	page.press_art()
	check_eq(SkinCollection.art_of("48310"), alt, "открытый арт включается одним щелчком")
	page.select(CollectionPage.faction_cards("drow")[3])
	var other := page.selected()
	page.toggle_favourite()
	check(PlayerProfile.favourite() == other and _find_button(page, "YOUR FAVOURITE CARD") != null,
		"выбранная карта стала любимой")
	check_eq(String(PlayerProfile.load_local()["favourite"]), other, "любимая карта уходит в партию с профилем")
	page.toggle_favourite()
	check_eq(PlayerProfile.favourite(), "", "второй щелчок снимает любимую карту")

	# Раскрытие лутбокса (Loot-1): тряска, рулетка, вспышка, награда; несколько — итог.
	SkinCollection.grant({"boxes": 5})
	var one := page.open_boxes(1)
	check(one.size() == 1 and page._reveal != null and page._reveal.phase() == "shake", "OPEN BOX запускает раскрытие с тряски")
	check(page.open_boxes(1).is_empty() and int(SkinCollection.load_data()["boxes"]) == 4, "пока окно открыто, второй бокс не тратится")
	var reveal: LootBoxReveal = page._reveal
	reveal.step(LootBoxReveal.SHAKE_TIME)
	check_eq(reveal.phase(), "roll", "после тряски — рулетка")
	reveal.step(LootBoxReveal.ROLL_TIME)
	check_eq(reveal.phase(), "flash", "после рулетки — вспышка")
	reveal.step(LootBoxReveal.FLASH_TIME)
	check_eq(reveal.phase(), "show", "после вспышки — награда")
	for tier in SkinCollection.TIERS:
		var probe := LootBoxReveal.new()
		probe.setup([{"tier": tier, "shader": "", "art": "", "duplicate": false, "dust": 50}], 0, "48342")
		probe._enter("roll")
		check_eq(probe._roll_total() % 3, SkinCollection.TIERS.find(tier), "рулетка замирает на выпавшей ступени " + String(tier))
		probe.step(LootBoxReveal.ROLL_TIME)
		check_eq(probe.highlighted(), SkinCollection.TIERS.find(tier), "подсвечена выпавшая ступень " + String(tier))
		probe.free()
	var closed_again := []
	reveal.closed.connect(func(again: bool): closed_again.append(again))
	reveal.press_ok()
	check(closed_again == [false] and page._reveal == null, "OK закрывает окно, страница свободна")
	var five := page.open_boxes(4)
	check(five.size() == 4 and page._reveal.batch() and int(SkinCollection.load_data()["boxes"]) == 0, "OPEN ALL открывает все боксы разом")
	page._reveal.skip()
	check_eq(page._reveal.phase(), "summary", "SKIP при пачке — сразу итоговая сетка")
	check(_all_text(page._reveal).contains("OPENED 4 BOXES"), "итог пачки подписан")
	page._reveal.press_ok()
	check(page._reveal == null and _all_text(page).contains("Opened 4 boxes"), "после итога страница пишет сводку")
	var sample: Array[Dictionary] = [
		{"tier": "epic", "shader": "", "art": "", "duplicate": false, "dust": 50},
		{"tier": "legendary", "shader": "", "art": "48310_1", "duplicate": true, "dust": 150},
		{"tier": "ultra", "shader": "gilded", "art": "", "duplicate": false, "dust": 0}]
	check_eq(CollectionPage.best_result(sample)["shader"], "gilded", "лучшая награда — новая высшей ступени")
	check(not LootBoxReveal.is_new(sample[0]) and not LootBoxReveal.is_new(sample[1]) and LootBoxReveal.is_new(sample[2]),
		"пыль и повтор — не новое")
	page.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProfile.path_override))
	PlayerProfile.path_override = old_path


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


	section("Conscription Officer: promote карты из руки")
	red.deck.hand = ["48344", "48342"] as Array[String]
	red.deck.played_pile = ["48342"] as Array[String]
	red.deck.inner_circle.clear()
	resolver.apply(CardLibrary.get_effect("48345"), "red", state)
	resolver.resume(state, 1)
	check_eq(resolver.pending.legal_options, ["48344", "48342"], "на выбор — только карты из руки")
	resolver.resume(state, "48342")
	check_eq(red.deck.inner_circle, ["48342"], "Noble ушёл во внутренний круг")
	check_eq(red.deck.hand, ["48344"], "и именно из руки")
	check_eq(red.deck.played_pile, ["48342"], "сыгранный Noble не тронут")

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

	# Решение владельца: при пустом бараке каждое неразмещённое войско карты = 1 VP
	var vs := _build_rich_state()
	var vred: PlayerState = vs.players["red"]
	vred.troops_in_barracks = 0
	var vp0 := vred.vp_tokens
	var vres := EffectResolver.new()
	vres.apply(DeployTroop.new(4), "red", vs)
	check(not vres.is_waiting(), "пустой барак: Deploy 4 не спрашивает слот")
	check_eq(vred.vp_tokens, vp0 + 4, "пустой барак: Deploy 4 дал 4 VP")
	# Последнее войско кончилось посреди эффекта: остаток превращается в VP
	vred.troops_in_barracks = 1
	vp0 = vred.vp_tokens
	var vres2 := EffectResolver.new()
	vres2.apply(DeployTroop.new(3), "red", vs)
	vres2.resume(vs, vres2.pending.legal_options[0])
	check(not vres2.is_waiting(), "после последнего войска слот больше не спрашивают")
	check_eq(vred.troops_in_barracks, 0, "последнее войско размещено")
	check_eq(vred.vp_tokens, vp0 + 2, "два неразмещённых войска дали 2 VP")

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
	section("CardLibrary: все 176 карт разыгрываются без зависаний/ошибок")
	CardLibrary._ensure_loaded()
	var all_ids: Array = CardLibrary._data.keys()
	check_eq(all_ids.size(), 176, "cards.json содержит 176 карт (126 + 25 Celestial Order + 25 Shadow Isles)")

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
	red.deck.draw_pile = ["48344", "48342", "48343"]
	var deck_view: Dictionary = StateView.for_player(state, "red")
	check_eq(deck_view["players"]["red"]["deck_cards"], ["48342", "48343", "48344"],
		"владелец видит состав колоды, но отсортированным — порядок добора скрыт")
	check(not StateView.for_player(state, "blue")["players"]["red"].has("deck_cards"),
		"состав чужой колоды скрыт")
	check_eq(DeckTracker.sorted_by_cost(["48342", "48342"]).size(), 2,
		"дектрекер: каждая копия карты — своя ступенька")

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


## Правило владельца (2026-09-28): ярус A2 достигнут посреди хода — Power и
## Influence сразу, доплачивается только разница с уже выданным в этом ходу.
func test_a2_bonus_mid_turn() -> void:
	section("Бонус A2 посреди хода")
	var state := GameState.new(_build_a2_graph(), 5)
	state.add_player("red", [])
	state.add_player("blue", [])
	var server := GameServer.new(state)
	var red: PlayerState = state.players["red"]
	check_eq([red.power, red.influence], [0, 0], "в начале хода A2 пуст — ничего")
	var steps := [
		["troops", [0, 1], "войска во всех трёх: +1 Influence сразу"],
		["control", [1, 1], "контроль всех трёх: доплата +1 Power (Influence уже выдан)"],
		["total", [2, 2], "полный контроль: доплата до +2 Power, +2 Influence"],
		["total", [2, 2], "тот же ярус повторно в этом ходу не платится"],
		["none", [2, 2], "ярус потерян — выданное не отнимается"],
	]
	for step in steps:
		for prefix in ["fogtown", "gallenghast", "darkflame"]:
			for i in range(3):
				state.troops.erase("%s_%d" % [prefix, i])
			match step[0]:
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
		TurnEngine.grant_control_income(state, "red", server.resolver)
		check_eq([red.power, red.influence], step[1], step[2])
	server._apply(Intent.end_turn("red"))
	server._apply(Intent.end_turn("blue"))
	check_eq([red.power, red.influence], [0, 0], "следующий ход: выплаты хода сброшены, яруса нет — ничего")


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
		check_eq(nobles, 6, "%s: из них 6 Noble" % pid)
		check(all_cards.has("48345"), "%s: вместо седьмого Noble — Conscription Officer" % pid)

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


## Время на ответ чужой карте вышло: берём отказ, если он есть, иначе первый вариант.
func test_auto_decision_answer() -> void:
	section("Автоответ по таймеру")
	check_eq(GameScreen.auto_decision_answer(["c1", "c2"]), "c1", "сброс без отказа — первая карта")
	check_eq(GameScreen.auto_decision_answer(["s1", ""]), "", "есть пустой вариант — отказ")
	check_eq(GameScreen.auto_decision_answer([0, 2, -1]), -1, "есть -1 — отказ")
	check_eq(GameScreen.auto_decision_answer([true, false]), false, "да/нет — нет")
	# Стартовая расстановка: таймер и «>» у выбирающего, а не у первого ходящего.
	var pick := {"current_player": "red", "pending_decision": {"player_id": "blue", "tag": "starting_site"}}
	check_eq(GameScreen.acting_player(pick), "blue", "расстановка: действует выбирающий")
	var card := {"current_player": "red", "pending_decision": {"player_id": "blue", "tag": "hand"}}
	check_eq(GameScreen.acting_player(card), "red", "вопрос карты: действует ходящий")


## Муллиган рынка (2026-10-08): по очереди хода, по одной карте или пропуск,
## убранные карты и их копии не выходят на рынок до конца муллигана, потом
## вмешиваются в колоду; после муллигана — выбор стартовых сайтов.
func test_market_mulligan() -> void:
	section("Муллиган рынка")
	var ids: Array[String] = ["red", "blue", "green"]
	var state := GameSetup.new_game(ids, 99, ["drow", "dragons"], false, true, false)
	var total := state.market.deck.size() + state.market.available_cards().size()
	var server := GameServer.new(state)
	var pd: PendingDecision = server.resolver.pending
	check(pd != null and pd.tag == "market" and pd.player_id == "red", "первым меняет карту первый игрок")
	check(pd.legal_options.has(-1), "можно пропустить")
	var res: Dictionary = server.apply_intent(Intent.make_decision("blue", 0))
	check_eq(int(res["error"]), GameServer.Error.NOT_YOUR_TURN, "чужой ход муллигана отклонён")

	var first: String = state.market.display[0]
	server.apply_intent(Intent.make_decision("red", 0))
	check(state.market.display[0] != first, "на место убранной карты не вышла её копия")
	pd = server.resolver.pending
	check(pd.tag == "market" and pd.player_id == "blue", "дальше меняет второй игрок")
	var second: String = state.market.display[0]
	server.apply_intent(Intent.make_decision("blue", 0))
	check(state.market.display[0] != first and state.market.display[0] != second,
		"обе убранные карты в чёрном списке")
	check_eq(state.market.deck_size() + state.market.available_cards().size(), total,
		"карты не теряются во время муллигана")
	server.apply_intent(Intent.make_decision("green", -1))
	check(state.market.mulligan_blacklist.is_empty(), "после муллигана чёрный список пуст")
	check(state.market.deck.has(first) and state.market.deck.has(second), "убранные карты вмешаны в колоду")
	check_eq(state.market.deck.size() + state.market.available_cards().size(), total, "размер колоды сходится")
	pd = server.resolver.pending
	check(pd != null and pd.tag == "starting_site" and pd.player_id == "red", "затем стартовый сайт, с первого игрока")

	# Сохранённые до муллигана сетевые партии переигрываются без него.
	var old_state := GameSetup.new_game(ids, 99, ["drow", "dragons"], false, true, false)
	var old_server := GameServer.new(old_state, false)
	check(old_server.resolver.pending.tag == "starting_site", "без муллигана сразу стартовый сайт")
	var room := GameRoom.restore({"code": "T", "ids": ids, "seed": 99}, [])
	check(room.server.resolver.pending.tag == "starting_site", "старый журнал (без \"mulligan\") — без муллигана")

	# Копии убранной карты сверху колоды пропускаются и остаются в колоде.
	var m := Market.new()
	m.display = ["A", "B", "C", "D", "E", "F"]
	m.deck = ["A", "G", "A"]
	m.mulligan_replace(0)
	check_eq(m.display[0], "G", "копии убранной карты пропускаются, выходит первая подходящая")
	check_eq(m.deck, ["A", "A"] as Array[String], "пропущенные копии остались в колоде")


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
		var guard := 0
		while server.resolver.is_waiting() and guard < 3 * count:
			guard += 1
			var pd: PendingDecision = server.resolver.pending
			if pd.tag == "market":  # муллиган рынка — пропускаем
				server.apply_intent(Intent.make_decision(pd.player_id, -1))
				continue
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


func test_game_modes() -> void:
	section("Режимы игры: STANDARD / DOUBLE / RANDOM 3 / RANDOM 4 / RANDOM 6")
	var pids: Array[String] = ["red", "blue"]
	var expected := {"standard": 2, "double": 2, "random3": 3, "random4": 4, "random6": 6}
	for mode: String in GameSetup.MODES:
		var state := GameSetup.new_game(pids, 99, [], false, false, false, mode)
		var total := state.market.deck.size() + state.market.display.size()
		if mode == GameSetup.MODE_NEW_ERA:
			# Полуколоды New Era — по 45 карт и не по 10 копий на аспект.
			check_eq(total, 90, "newera: в маркете 45 + 45 карт")
			check_eq(state.half_decks, ["celestial", "shadow"] as Array[String], "newera: Celestial Order + Shadow Isles")
			check_eq(state.supplies.remaining(Supplies.INSANE_OUTCAST), 30, "newera: с Shadow Isles лежит стопка Insane Outcast")
			check_eq(state.supplies.remaining(ShadowCards.TWIG_BLIGHT), 4, "newera: и 4 Twig Blight")
			continue
		check_eq(total, 80, "%s: в маркете 80 карт" % mode)
		check_eq(state.half_decks.size(), int(expected[mode]), "%s: число полуколод" % mode)
		check_eq(state.game_mode, mode, "%s: режим записан в состояние" % mode)
		var per_aspect := {}
		for cid: String in state.market.deck + state.market.display:
			var a := CardLibrary.card_aspect(cid)
			per_aspect[a] = int(per_aspect.get(a, 0)) + 1
		check_eq(per_aspect.size(), 4, "%s: 4 аспекта" % mode)
		for a: String in per_aspect.keys():
			check_eq(int(per_aspect[a]), 20, "%s: аспект %s — 20 карт" % [mode, a])
	var dbl := GameSetup.new_game(pids, 99, [], false, false, false, "double")
	check_eq(dbl.half_decks[0], dbl.half_decks[1], "DOUBLE: одна и та же полуколода дважды")
	var r4 := GameSetup.new_game(pids, 5, [], false, false, false, "random4")
	var uniq := {}
	for d: String in r4.half_decks:
		uniq[d] = true
	check_eq(uniq.size(), 4, "RANDOM 4: четыре разные полуколоды")
	var r4b := GameSetup.new_game(pids, 5, [], false, false, false, "random4")
	check_eq(r4b.market.deck, r4.market.deck, "RANDOM 4: одинаковый сид — одинаковый маркет")


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

	# выбор карты (promote/discard) — сетка мелких карт, клик отвечает id карты
	var dlg := DecisionDialog.new()
	dlg.update_from_view({"pending_decision": {"player_id": "red", "choice_type": "target_card",
		"prompt": "Promote a card", "legal_options": ["48342", "inner:48306", ""]}}, "red")
	var cards: Array = dlg.find_children("*", "CardView", true, false)
	check_eq(cards.size(), 2, "promote: по мелкой карте на каждый вариант, кроме отказа")
	check_eq((cards[1] as CardView).card_id, "48306", "карта из Inner Circle показана без префикса")
	var answers: Array = []
	dlg.option_chosen.connect(func(a): answers.append(a))
	(cards[1] as CardView).pressed.emit("48306")
	check_eq(answers, ["inner:48306"], "клик по карте отвечает исходным вариантом")
	check_eq(dlg.find_children("*", "Button", true, false).size(), 1, "отказ остаётся кнопкой Skip")

	# "Choose one" — полноформатные карты с артом сыгранной карты и "or" между ними
	check_eq(pdv.get("source_card", ""), "48325", "вопрос Choose one знает, какая карта его задала")
	dlg.update_from_view(red_view, "red")
	var option_cards: Array = dlg.find_children("*", "OptionCard", true, false)
	check_eq(option_cards.size(), 2, "Inquisitor: две карты-варианта")
	var ors: Array = dlg.find_children("*", "Label", true, false).filter(func(l): return l.text == "or")
	check_eq(ors.size(), 1, "между вариантами написано or")
	answers.clear()
	(option_cards[1] as OptionCard).pressed.emit()
	check_eq(answers, [1], "клик по правой карте выбирает второй вариант")
	check_eq((option_cards[0] as OptionCard).custom_minimum_size, CardView.PIXEL_SIZE,
		"карта-вариант размером с обычную полную карту")
	var unnamed: Array = []
	var named := 0
	CardLibrary._ensure_loaded()
	for cid in CardLibrary._data.keys():
		for choose in _collect_choose(CardLibrary.get_effect(cid)):
			for label in (choose as ChooseEffect).labels:
				named += 1
				if OptionCard.option_name(label) == "" and not unnamed.has(label):
					unnamed.append(label)
	check(named > 40, "проверка названий дошла до вариантов карт (%d)" % named)
	check_eq(unnamed, [], "у каждого варианта Choose one есть название")
	dlg.free()


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
	var ret_evt: Dictionary = resolver.events.back()
	check_eq(String(ret_evt.get("player_id", "")), "red", "в журнале видно, кто вернул войско")
	check(EventLogPanel.describe(ret_evt).contains(EventLogPanel.player_name("blue")),
		"строка журнала называет хозяина войска: %s" % EventLogPanel.describe(ret_evt))
	var trophy_line := EventLogPanel.describe({"type": "take_trophy", "player_id": "red", "hall": "blue", "color": "white"})
	check(trophy_line.contains(EventLogPanel.player_name("blue") + "'s trophy hall"),
		"взятие из зала трофеев называет, чей зал: %s" % trophy_line)
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
	var state := GameSetup.new_game(["red", "blue"], 2)  # сид с A1/A3 в центре
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

	# Контроль взят посреди хода -> Influence сразу, но не больше раза за ход.
	var site2: String = marked[1]
	var before2: int = state.players["red"].influence
	TurnEngine.grant_control_income(state, "red")
	check_eq(state.players["red"].influence, before2, "без нового контроля Influence не растёт")
	for slot_id in state.graph.slots_of_site(site2):
		state.troops[String(slot_id)] = "red"
	TurnEngine.grant_control_income(state, "red")
	check_eq(state.players["red"].influence - before2,
		int(ControlMarkers.marker_for(state, site2)["control_influence"]),
		"новый контроль посреди хода сразу даёт Influence")
	TurnEngine.grant_control_income(state, "red")
	check_eq(state.players["red"].influence - before2,
		int(ControlMarkers.marker_for(state, site2)["control_influence"]),
		"повторно в тот же ход за ту же локацию не платится")


func test_cross_hex_site_to_site_presence() -> void:
	section("Cross-hex site-to-site tunnel gives Presence from any slot of the site")
	# Seed 44: Ath-Qua (C5) is sewn directly to Gallenghast (A2) across a hex
	# edge. A troop in a NON-port slot of Ath-Qua must still give Presence there.
	var state := GameSetup.new_game(["red", "blue"], 44, ["drow", "dragons"], false, true)
	var g := state.graph
	var ath := ""
	var gall := ""
	for s: String in g.sites.keys():
		if g.sites[s]["name"] == "Ath-Qua": ath = s
		if g.sites[s]["name"] == "Gallenghast": gall = s
	check(ath != "" and gall != "", "both sites are on the seed-44 board")
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
	# свой зал не в счёт: red берёт синее войско из зала green, не из своего
	check(not TakeFromTrophyHall.new(1, false, false).is_available(state, "red"),
		"свой трофейный зал не предлагается")
	var green_hall: PlayerState = state.players["green"]
	green_hall.add_trophy("blue")
	r = EffectResolver.new()
	r.apply(TakeFromTrophyHall.new(1, false, false), "red", state)
	var labels: Array[String] = r.pending.option_labels
	var blue_index := -1
	for i in range(labels.size()):
		if labels[i].begins_with("Blue"):
			blue_index = i
	check(blue_index != -1, "в вариантах есть синее войско из зала green")
	r.resume(state, blue_index)
	check(r.is_waiting() and r.pending.choice_type == "target_slot", "дальше выбираем, куда выставить")
	var slot: String = r.pending.legal_options[0]
	r.resume(state, slot)
	check_eq(state.troops[slot], "blue", "войско выставлено своим (синим) цветом")
	check_eq(blue.troops_in_barracks, blue_barracks, "бараки blue не изменились")
	check_eq(green_hall.trophy_hall_count, 0, "войско ушло из зала green")
	check_eq(red.trophy_hall_count, 2, "зал red не тронут")

	section("Lich: несколько соперников на сайте — выбор, чей зал (этап 8)")
	state = _build_rich_state()
	red = state.players["red"]
	blue = state.players["blue"]
	green = state.players["green"]
	var lich_site := ""
	for sid: String in state.graph.sites.keys():
		if state.graph.slots_of_site(sid).size() >= 2:
			lich_site = sid
			break
	check(lich_site != "", "нашёлся сайт хотя бы с двумя слотами")
	var lich_slots: PackedStringArray = state.graph.slots_of_site(lich_site)
	state.troops[lich_slots[0]] = "blue"
	state.troops[lich_slots[1]] = "green"
	for i in range(2, lich_slots.size()):
		state.troops.erase(lich_slots[i])
	check_eq(CardLibrary._enemy_troop_owners_at_site(state, "red", lich_site), ["blue", "green"] as Array[String],
		"оба соперника на сайте найдены (не только первый), в порядке хода")
	blue.add_trophy("white")
	green.add_trophy("white")
	r = EffectResolver.new()
	r.apply(CardLibrary._LichEffect.new(lich_site), "red", state)
	check(r.is_waiting() and r.pending.choice_type == "target_player",
		"с двумя соперниками на сайте — сперва выбор, чей зал")
	check_eq(r.pending.legal_options, ["blue", "green"], "варианты выбора — оба соперника с сайта")
	r.resume(state, "blue")
	check(r.is_waiting() and r.pending.choice_type == "choose_option",
		"после выбора blue — берём войско из его зала")
	var only_from_blue := true
	for label: String in (r.pending.option_labels as Array):
		if not label.ends_with("Blue's trophy hall") and label != "Skip":
			only_from_blue = false
	check(only_from_blue, "варианты только из зала blue, зал green не предлагается")

	state.troops.erase(lich_slots[1])  # остаётся один соперник (blue)
	var r_single := EffectResolver.new()
	r_single.apply(CardLibrary._LichEffect.new(lich_site), "red", state)
	check(r_single.is_waiting() and r_single.pending.choice_type == "choose_option",
		"с одним соперником на сайте — без выбора, сразу его зал (как было на двоих)")

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

	section("аудит: Carrion Crawler")
	state = _build_rich_state()
	red = state.players["red"]
	red.deck.played_pile.append("48737")
	var cc_victim: String = state.market.display[0]
	var cc_deck_before: Array[String] = state.market.deck.duplicate()
	r = EffectResolver.new()
	r.apply(CardLibrary._CarrionCrawlerDevour.new(), "red", state)
	r.resume(state, 0)
	check_eq(state.market.display[0], "48737", "Crawler встал в слот сожранной карты")
	check(state.devoured_pile.has(cc_victim), "сожранная карта в стопке Devoured")
	check_eq(state.market.deck, cc_deck_before, "колода рынка не тронута: сожранная карта туда не вернулась")
	check(not red.deck.played_pile.has("48737"), "Crawler ушёл из сыгранных")

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
		# владелец, 2026-10-03: «дорожки не должны пересекаться» — ни петель,
		# ни пересечений трасс, у которых нет общего конца
		check_eq(_trace_crossings(s), 0, "%s: трассы не пересекаются и не делают петель" % tag)

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

		# через ребро: в точке сходятся трассы ровно двух гексов, и сходятся
		# встречно (перпендикулярность ребру ушла вместе с трассами под 45°,
		# решение владельца 2026-09-22; на доске на четверых гексы раздвинуты,
		# и точка лежит в щели между ними, см. BoardSchematic._spread)
		var hexes_at_port := {}   # port -> {hex: true}
		for t in (s["trace_ends"] as Array).size():
			var pair2: Array = s["trace_ends"][t]
			if String(pair2[0]).begins_with("port:"):
				var seen: Dictionary = hexes_at_port.get(pair2[0], {})
				seen[String(pair2[1]).get_slice(":", 0)] = true
				hexes_at_port[pair2[0]] = seen
		var bad_port := 0
		for port: String in (s["ports"] as Dictionary).keys():
			var dirs: Array = dir_at_port.get(port, [])
			var neighbour_found := (hexes_at_port.get(port, {}) as Dictionary).size() == 2
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

	# Выбор фона (решение владельца, 2026-09-28; своего рисунка нет с 2026-09-30):
	# во вкладке COLLECTION → BACKGROUNDS.
	var old_path := PlayerProfile.path_override
	PlayerProfile.path_override = "user://profile_bg_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProfile.path_override))
	Bg.forget_cache()
	check_eq(Bg.style(), "classic", "по умолчанию — CLASSIC")
	# Дерево сцены в тестах не запущено, так что перекраску группы set_style
	# здесь не увидеть: проверяем, что задник в группе, и красим его напрямую.
	var rect: ColorRect = Bg.make(Bg.GAME_FADE)
	check(rect.is_in_group(Bg.GROUP), "задник записан в группу для перекраски")
	Bg.set_style("black")
	Bg._paint(rect)
	check_eq(rect.color, Color(0, 0, 0), "BLACK — чёрная заливка")
	Bg.set_style("orange")
	Bg._paint(rect)
	check_eq(rect.color, Color("df7126"), "ORANGE IS NEW BLACK — оранжевый, и в партии не гаснет")
	Bg._style = ""
	check_eq(Bg.style(), "orange", "выбор сохранён в профиле")
	Bg.set_style("nonsense")
	check_eq(Bg.style(), "classic", "неизвестный фон — CLASSIC")
	Bg.set_style("custom")
	check_eq(Bg.style(), "classic", "бывший свой рисунок (custom) — теперь CLASSIC")
	check(not Bg.STYLES.has("custom"), "рисовалки фона больше нет")
	rect.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProfile.path_override))
	PlayerProfile.path_override = old_path
	Bg.forget_cache()

	# Режимы: сколько полуколод — столько красок; DOUBLE — два оттенка одной.
	for mode: String in ["random4", "random6"]:
		var st := GameSetup.new_game(["red", "blue"], 3, [], false, false, false, mode)
		check_eq(Bg.palette(st.half_decks).size(), st.half_decks.size(), "%s: краска на каждую полуколоду" % mode)
	var dbl := GameSetup.new_game(["red", "blue"], 3, [], false, false, false, "double")
	var two := Bg.palette(dbl.half_decks)
	check_eq(two[0], Bg.DECK_COLOURS[dbl.half_decks[0]], "DOUBLE: первая краска — цвет полуколоды")
	check_eq(two[1], two[0].lightened(Bg.SHADE_LIGHTEN), "DOUBLE: вторая — её светлый оттенок")


## Все ChooseEffect в дереве эффектов карты (по полям-эффектам и массивам).
func _collect_choose(node: Variant, out: Array = []) -> Array:
	if node is Array:
		for item in node:
			_collect_choose(item, out)
	elif node is CardEffect:
		if node is ChooseEffect:
			out.append(node)
		for prop in (node as Object).get_property_list():
			if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var v: Variant = (node as Object).get(prop["name"])
				if v is CardEffect or v is Array:
					_collect_choose(v, out)
	return out


# --- сеть: какие адреса видны из интернета ----------------------------------

func test_public_address_check() -> void:
	section("сеть: «белый» адрес для UPnP")
	check(NetSession.is_public_ipv4("85.140.12.7"), "обычный внешний адрес — белый")
	for grey in ["192.168.0.104", "10.1.2.3", "172.19.0.1", "100.72.5.9", "26.12.34.56x", "", "127.0.0.1", "169.254.1.1"]:
		check(not NetSession.is_public_ipv4(grey), "%s — не белый" % grey)
	check(NetSession.is_public_ipv4("172.32.0.1"), "172.32.* уже не частная сеть")
	check(Intent.from_dict(Intent.recruit("red", 3).to_dict()).market_index == 3, "намерение переживает пересылку словарём")


func test_player_profile() -> void:
	section("профиль игрока: имя и герб на фишке")
	check_eq(PlayerProfile.SIZE, BoardSchematic.SLOT_R * 2 + 1, "холст герба = размер фишки войска")
	check(PlayerProfile.paintable(4, 4) and PlayerProfile.paintable(1, 4), "центр и край кружка красятся")
	check(not PlayerProfile.paintable(0, 4) and not PlayerProfile.paintable(0, 0), "ободок и угол не красятся")
	check_eq(PlayerProfile.clean_name("  Dr0w Лорд <b>King of all  "), "Dr0w Лорд bK", "имя: только знаки шрифта, до 12")
	check_eq(PlayerProfile.clean_emblem("zz"), "", "испорченный герб отбрасывается")

	var pixels: Array[Color] = []
	pixels.resize(PlayerProfile.SIZE * PlayerProfile.SIZE)
	pixels.fill(Color(0, 0, 0, 0))
	pixels[4 * 9 + 4] = Color("ac3232")
	pixels[0] = Color("ffffff")  # угол — вне кружка, должен стереться
	var emblem := PlayerProfile.emblem_from_pixels(pixels)
	check_eq(emblem.length(), PlayerProfile.EMBLEM_LENGTH, "герб — строка 648 знаков")
	var back := PlayerProfile.emblem_pixels(emblem)
	check(back[40].to_html(false) == "ac3232" and back[0].a == 0.0, "герб переживает кодирование, угол стёрт")
	check(not PlayerProfile.is_blank(emblem) and PlayerProfile.is_blank(PlayerProfile.blank_emblem()), "пустой герб узнаётся")

	var img := SchematicPainter.token(Color("d93838"), emblem)
	check(img.get_pixel(4, 4).to_html(false) == "ac3232", "на фишке нарисован герб")
	check(img.get_pixel(3, 4).is_equal_approx(Color("d93838")), "пустой пиксель герба — цвет места")
	check(img.get_pixel(0, 4).a > 0.9 and img.get_pixel(0, 4).v < 0.1, "ободок фишки остаётся тёмным")

	check_eq(PlayerProfile.paintable_count(), 37, "внутри кружка 37 пикселей")
	var full: Array[Color] = []
	full.resize(PlayerProfile.SIZE * PlayerProfile.SIZE)
	full.fill(Color("000000"))
	check_eq(PlayerProfile.clean_emblem(PlayerProfile.emblem_from_pixels(full)), "",
		"целиком закрашенный герб не принимается")
	var editor := ProfileScreen.new()
	editor.paint(4, 4, Color(0, 0, 0, 0))
	for y in PlayerProfile.SIZE:
		for x in PlayerProfile.SIZE:
			editor.paint(x, y, Color("ffffff"))
	var left_empty := PlayerProfile.paintable_count() - PlayerProfile.painted_count(
		PlayerProfile.emblem_pixels(editor.emblem()))
	check_eq(left_empty, PlayerProfile.MIN_SEAT_PIXELS, "редактор оставляет %d пикселей цвета места" % PlayerProfile.MIN_SEAT_PIXELS)
	check(PlayerProfile.clean_emblem(editor.emblem()) != "", "самый закрашенный герб из редактора годится")
	editor.free()

	PlayerProfile.seats = {"blue": {"name": "Vizeran", "emblem": emblem}}
	check_eq(EventLogPanel.player_name("blue"), "Vizeran", "имя из профиля в журнале")
	check_eq(EventLogPanel.player_name("red"), "Red", "без профиля — имя цвета")
	PlayerProfile.seats = {}


func test_chat_wheel_and_ping() -> void:
	section("колесо чата и пинг (Tab)")
	check_eq(PlayerProfile.clean_phrase("  Hi^ the`re{}~  "), "Hi there", "фраза: только знаки шрифта")
	check_eq(PlayerProfile.clean_phrase("x".repeat(50)).length(), PlayerProfile.PHRASE_MAX, "фраза не длиннее 30")
	check_eq(PlayerProfile.clean_phrase("Привет, Ёжик!"), "Привет, Ёжик!", "фраза: кириллица остаётся")
	check_eq(PlayerProfile.clean_name("Вася Пупкин"), "Вася Пупкин", "имя: кириллица остаётся")
	check_eq(RatingBook.name_id("ВОВ"), RatingBook.name_id("bob"), "имя: русская «ВОВ» — то же, что латинская «BOB»")
	check(RatingBook.name_id("Вася") != RatingBook.name_id("Петя"), "имя: разные буквы — разные имена")
	var font: Font = load(PixelTheme.FONT_PATH)
	var missing := ""
	for ch in PlayerProfile.CYRILLIC_LETTERS:
		if not font.has_char(ch.unicode_at(0)):
			missing += ch
	check_eq(missing, "", "в шрифте есть все русские буквы")
	var shot := Image.create(12, 9, false, Image.FORMAT_RGBA8)
	PixelFont.draw_text(shot, 0, 0, "Жа", Color.WHITE)
	check(shot.get_pixel(0, 0).a > 0.0 and shot.get_pixel(7, 2).a > 0.0, "рисовальщик доски рисует кириллицу")
	check_eq(PlayerProfile.save_phrases(["Go!", "", "Nice   one"]), OK, "фразы сохраняются")
	check_eq(PlayerProfile.load_phrases(),
		["Go!", PlayerProfile.DEFAULT_PHRASES[1], "Nice   one", PlayerProfile.DEFAULT_PHRASES[3]] as Array[String],
		"пустая или недостающая фраза — фраза по умолчанию")

	var times: Array = []
	check(NetSession.rate_ok(times, 0) and NetSession.rate_ok(times, 1000) and NetSession.rate_ok(times, 2000),
		"три пинга подряд можно")
	check(not NetSession.rate_ok(times, 4999), "четвёртый за 5 с — нельзя")
	check(NetSession.rate_ok(times, 5000), "через 5 с после первого — снова можно")

	check_eq(ChatWheel.side_of(Vector2(0, -20)), 0, "колесо: вверх")
	check_eq(ChatWheel.side_of(Vector2(20, 5)), 1, "колесо: вправо")
	check_eq(ChatWheel.side_of(Vector2(-3, 20)), 2, "колесо: вниз")
	check_eq(ChatWheel.side_of(Vector2(-20, -5)), 3, "колесо: влево")
	check_eq(ChatWheel.side_of(Vector2(3, 3)), -1, "колесо: у центра ничего")

	var profile := ProfileScreen.new()
	check(_find_button(profile, "CHAT") != null, "в профиле есть вкладка CHAT")
	check_eq(profile.phrases(), ["Go!", PlayerProfile.DEFAULT_PHRASES[1], "Nice   one",
		PlayerProfile.DEFAULT_PHRASES[3]] as Array[String], "редактор показывает свои фразы")
	profile._phrase_edits[1].text = "Your move^"
	check_eq(profile.phrases()[1], "Your move", "редактор чистит фразу")
	profile.free()
	PlayerProfile.save_phrases([])

	# Экран партии за одним компьютером: пинг, облачко фразы, колесо по Tab.
	var screen := GameScreen.new(5, [], ["red", "blue"])
	screen.size = Vector2(960, 540)
	screen._layout()
	var board_point := screen._board_area.get_global_rect().get_center()
	check(screen.ping_at(board_point) and screen.ping_count() == 1, "пинг на доске")
	var hand_point := screen._hand_panel.get_global_rect().end - Vector2(4, 4)
	check(not screen.ping_at(hand_point), "в руке пинга нет — рука у каждого своя")
	var market_point := screen._market_panel.get_global_rect().get_center()
	check(screen.ping_at(market_point) and screen.ping_count() == 2, "пинг на рынке")
	check(screen.ping_at(board_point), "третий пинг проходит")
	check(not screen.ping_at(board_point), "четвёртый пинг за 5 с не проходит")
	screen._said_times.clear()
	var world := screen._board_panel.world_at(Vector2(40, 30))
	check(screen._board_panel.local_of_world(world).is_equal_approx(Vector2(40, 30)),
		"точка доски переводится в схему и обратно")
	screen.show_ping("blue", "board", world)
	check_eq(screen.ping_count(), 4, "пришедший пинг рисуется")
	check(screen.say("Well played!^"), "фраза уходит")
	check_eq(screen.bubble_text(screen.viewer_id), "Well played!", "облачко у строки ходящего")
	screen._said_times.clear()

	screen.tab_key(true, board_point)
	screen._tick_tab(0.1)
	screen.tab_key(false, board_point)
	check(not screen._wheel.visible and screen.ping_count() == 5, "короткое нажатие Tab — пинг, колеса нет")
	screen.tab_key(true, board_point)
	screen._tick_tab(0.1)
	screen._tick_tab(0.2)
	check(screen._wheel.visible, "Tab держат — колесо открылось")
	screen._wheel.point_at(screen._wheel.centre() + Vector2(0, 30))
	check_eq(screen._wheel.selected(), 2, "мышь вниз — нижняя фраза")
	screen.tab_key(false, board_point)
	check(not screen._wheel.visible and not screen._tab_down, "Tab отпустили — колесо закрылось")
	check_eq(screen.bubble_text(screen.viewer_id), PlayerProfile.DEFAULT_PHRASES[2], "фраза колеса — в облачке")
	check_eq(screen.ping_count(), 5, "после колеса пинга нет")
	screen.free()


func test_card_back() -> void:
	section("рубашка карт: одна на всех, воронка цвета карты")
	check_eq(CardBack.DESIGNS, [CardBack.CLASSIC] as Array[String], "рубашка одна — CLASSIC")
	var img := CardBack.image(CardBack.CLASSIC)
	check_eq(img.get_size(), Vector2i(CardView.PIXEL_SIZE), "рубашка во весь размер карты")
	check(img.get_pixel(0, 0).a == 0.0, "углы скруглены")
	check(img.get_pixel(88, 127) == CardBack.RAMP[0], "в центре — чёрная дыра воронки")
	var shades := {}
	for x in range(10, 166, 3):
		shades[img.get_pixel(x, 40)] = true
	var ramp_only := true
	for colour: Color in shades:
		ramp_only = ramp_only and CardBack.RAMP.has(colour)
	check(ramp_only and shades.size() >= 4, "воронка — только оттенки цвета карты (%d тонов)" % shades.size())
	check_eq(CardBack.clean("drow"), CardBack.CLASSIC, "бывшие рубашки фракций — теперь CLASSIC")
	check(CardBack.texture("") == CardBack.texture("classic"), "текстура рубашки берётся из кэша")
	check_eq(PlayerProfile.clean_back("drow"), "", "в профиле рубашка — всегда обычная")

	# Карта, которую можно покрутить (коллекция → CARD BACKS).
	var flip := CardFlip.new()
	flip.set_back(CardBack.CLASSIC)
	flip.set_face("48314", "gilded")
	check(flip.shows_back(), "сначала к игроку рубашкой")
	flip.angle = PI
	flip._process(0.016)
	check(not flip.shows_back() and flip._face_layer.visible and not flip._back_layer.visible,
		"повернули — видно лицо карты")
	check((flip._face_layer.material as ShaderMaterial).get_shader_parameter("tier") == 2,
		"лицо — в своём образе")
	check(flip._back_layer.material == null, "рубашка без шейдера (решение владельца)")
	flip._speed = 0.0
	flip.angle = PI - 0.3
	for i in 120:
		flip._process(0.016)
	check(is_equal_approx(flip.angle, PI), "отпустили — карта встаёт ровно лицом")
	flip.free()

	# Любимая карта.
	check_eq(PlayerProfile.clean({"favourite": "48314"})["favourite"], "48314", "любимая карта — в профиле")
	check_eq(PlayerProfile.clean({"favourite": "999"})["favourite"], "", "неизвестная карта — не любимая")
	check(ProfileScreen.favourite_view("", "") == null, "нет любимой — нечего показывать")
	var card_fav := ProfileCard.new("blue", {"name": "Bob", "favourite": "48314", "shader": "prism"})
	check(_all_text(card_fav).contains("FAVOURITE"), "карточка игрока показывает любимую карту")
	card_fav.free()


func test_how_to_play() -> void:
	section("обучение HOW TO PLAY: страницы и картинки")
	var screen: Control = load("res://scenes/ui/how_to_play_screen.gd").new()
	check_eq(screen.page_count(), 14, "в обучении 14 страниц")
	for i in screen.page_count():
		screen.show_page(i)
		check(screen.current_page() == i, "страница %d открывается" % (i + 1))
	screen.show_page(99)
	check_eq(screen.current_page(), screen.page_count() - 1, "дальше последней страницы не листается")
	screen.free()

	var sites := {"A": {"name": "Araumycos", "vp": 2, "slots": 3, "at": [2, 10]}}
	var img: Image = load("res://scenes/ui/how_to_play_screen.gd").mini_board(
		sites, [], [], [60, 40], {"A0": "red"}, {"A": ["blue"]}, ["A1"])
	var box := BoardSchematic.site_box("Araumycos", 3)
	var slot0: Vector2 = Vector2(2, 10) + (box["slots"] as Array)[0]
	check(_close_colour(img.get_pixelv(Vector2i(slot0)), BoardPanel.PLAYER_COLORS["red"]),
		"на мини-доске красная фишка стоит в клетке")
	check(_close_colour(img.get_pixel(2 + int(box["w"]) / 2, 5), BoardPanel.PLAYER_COLORS["blue"]),
		"над местом нарисован синий шпион")


func test_main_menu() -> void:
	section("главное меню, первый профиль и вопрос про обучение")
	var menu := SetupScreen.new()
	check_eq(menu.current_page(), SetupScreen.PAGE_ONLINE, "меню открывается на PLAY → ONLINE")
	for text in ["PROFILE", "PLAY", "SETTINGS", "EXIT"]:
		check(_find_button(menu, text) != null, "под названием есть кнопка %s" % text)
	for text in ["ONLINE", "LOBBY", "HOTSEAT", "HOW TO PLAY", "SEARCH"]:
		check(_find_button(menu, text) != null, "в окне PLAY есть %s" % text)
	check(_find_button(menu, "LIBRARY") == null and _find_button(menu, "CARDS") == null,
		"библиотеки карт в меню больше нет")

	check(_find_button(menu, "NEWS") == null, "NEWS убрана (владелец, 2026-10-06)")

	_find_button(menu, "PROFILE").pressed.emit()
	check_eq(menu.current_page(), SetupScreen.PAGE_PROFILE, "PROFILE открывает профиль в окне меню")
	for text in ["STATS", "EMBLEM", "CHAT", "COLLECTION"]:
		check(_find_button(menu, text) != null, "в профиле есть %s" % text)
	check(_find_button(menu, "CARD BACK") == null and _find_button(menu, "CANCEL") == null,
		"рубашки и фон — внутри коллекции; CANCEL не нужен")
	check(_find_button(menu, "EDIT") != null, "ник меняется на вкладке STATS (кнопка EDIT)")
	var first_profile := ProfileScreen.new(true)
	check(_find_button(first_profile, "COLLECTION") == null, "при первом запуске — только имя и герб")
	first_profile.free()

	_find_button(menu, "SETTINGS").pressed.emit()
	check_eq(menu.current_page(), SetupScreen.PAGE_SETTINGS, "SETTINGS открывает настройки")
	var panel: Node = menu._tabs[SetupScreen.PAGE_SETTINGS].get_child(0)
	check_eq(panel.find_children("*", "HSlider", true, false).size(), 3,
		"в настройках три ползунка громкости: общая, эффекты, музыка")
	for text in ["TAB", "SPACE", "ALT", "F11", "RESET KEYS", "x1", "3 S"]:
		check(_find_button(panel, text) != null, "в настройках есть %s" % text)
	_test_settings(panel)

	var got := {}
	menu.started.connect(func(ids: Array[String], m: String): got["start"] = [ids.size(), m])
	menu.online_requested.connect(func(k: String, c: int, m: String, a: String): got["online"] = [k, c, m, a])
	_find_button(menu, "PLAY").pressed.emit()
	check_eq(menu.current_page(), SetupScreen.PAGE_ONLINE, "PLAY возвращает в последний раздел")
	_find_button(menu, "HOTSEAT").pressed.emit()
	check_eq(menu.current_page(), SetupScreen.PAGE_HOTSEAT, "HOTSEAT открывает хотсит")
	_find_button(menu, "3").pressed.emit()
	_find_button(menu, "RANDOM 4").pressed.emit()
	_find_button(menu, "START").pressed.emit()
	check_eq(got.get("start"), [3, GameSetup.MODE_RANDOM_4], "START в углу: 3 игрока, режим RANDOM 4")

	_find_button(menu, "ONLINE").pressed.emit()
	check_eq(menu.current_page(), SetupScreen.PAGE_ONLINE, "ONLINE открывает поиск игры")
	_find_button(menu, "2").pressed.emit()
	_find_button(menu, "SEARCH").pressed.emit()
	check_eq(got.get("online"), ["find", 2, GameSetup.MODE_STANDARD, ""], "SEARCH: на 2 игроков — режим STANDARD")
	_find_button(menu, "3").pressed.emit()
	_find_button(menu, "SEARCH").pressed.emit()
	check_eq(got.get("online"), ["find", 3, GameSetup.MODE_RANDOM_3, ""], "SEARCH: на 3 игроков — режим RANDOM 3")
	_find_button(menu, "4").pressed.emit()
	_find_button(menu, "SEARCH").pressed.emit()
	check_eq(got.get("online"), ["find", 4, GameSetup.MODE_RANDOM_4, ""], "SEARCH: на 4 игроков — режим RANDOM 4")
	_find_button(menu, "LOBBY").pressed.emit()
	check_eq(menu.current_page(), SetupScreen.PAGE_LOBBY, "LOBBY открывает игру с друзьями")
	check(_find_button(menu, "CREATE") != null and _find_button(menu, "JOIN") != null,
		"в LOBBY сверху выбор: CREATE или JOIN")
	_find_button(menu, "CREATE ROOM").pressed.emit()
	check_eq(got.get("online"), ["create", 3, GameSetup.MODE_RANDOM_4, ""],
		"CREATE ROOM в углу: 3 игрока и режим запомнены, выбор стола для поиска их не трогает")
	_find_button(menu, "DIRECT IP").pressed.emit()
	check(_find_button(menu, "CREATE ROOM") == null, "связь DIRECT IP: кнопка в углу уже не CREATE ROOM")
	_find_button(menu, "HOST").pressed.emit()
	check_eq(got.get("online")[0], "host", "DIRECT IP → HOST: игра по IP этого компьютера")
	_find_button(menu, "JOIN").pressed.emit()
	check(_find_button(menu, "STANDARD") == null,
		"JOIN: режим и игроков выбирает тот, кто создал игру")
	var code_edit: LineEdit = menu._col.find_children("*", "LineEdit", true, false)[0]
	code_edit.text = "wxyz"
	menu._action.pressed.emit()
	check_eq(got.get("online"), ["join_code", 0, GameSetup.MODE_RANDOM_4, "wxyz"],
		"JOIN по коду: код из поля уходит в лобби")
	_find_button(menu, "BY IP").pressed.emit()
	var ip_edit: LineEdit = menu._col.find_children("*", "LineEdit", true, false)[0]
	ip_edit.text = "26.1.2.3"
	_find_button(menu, "JOIN").pressed.emit()
	check(got.get("online")[0] != "join_ip", "кнопка JOIN сверху только переключает вкладку")
	menu._action.pressed.emit()
	check_eq(got.get("online")[0], "join_ip", "JOIN по IP — вход по IP")
	check_eq(got.get("online")[3], "26.1.2.3", "JOIN по IP: адрес из поля уходит в лобби")
	_find_button(menu, "HOW TO PLAY").pressed.emit()
	check_eq(menu.current_page(), SetupScreen.PAGE_HOW_TO_PLAY, "HOW TO PLAY — раздел PLAY")
	check(_find_button(menu, "OPEN") == null and _find_button(menu, "NEXT >") != null,
		"HOW TO PLAY: обучение сразу в окне, без кнопки OPEN")
	_find_button(menu, "NEXT >").pressed.emit()
	_find_button(menu, "HOTSEAT").pressed.emit()
	_find_button(menu, "HOW TO PLAY").pressed.emit()
	check_eq(menu._learn.current_page(), 1, "обучение открывается там, где остановились")
	menu.free()

	var back := SetupScreen.new(SetupScreen.PAGE_LOBBY)
	check_eq(back.current_page(), SetupScreen.PAGE_LOBBY, "меню можно открыть сразу на нужном разделе")
	back.free()

	# Первый профиль: без имени не создаётся (файл при этом не пишется).
	var first := ProfileScreen.new(true)
	check(_find_button(first, "CREATE") != null and _find_button(first, "CANCEL") == null,
		"первый профиль: кнопка CREATE, без CANCEL")
	var closed := [false]
	first.closed.connect(func(): closed[0] = true)
	first._name_edit.text = ""
	first._save()
	check(not closed[0], "без имени профиль не создаётся")
	first.free()
	var usual := ProfileScreen.new()
	check(_find_button(usual, "SAVE") != null and _find_button(usual, "CANCEL") == null,
		"обычный профиль: SAVE, без CANCEL (он живёт в окне меню)")
	usual.free()

	var offer: Control = load("res://scenes/ui/tutorial_offer_screen.gd").new()
	var answers: Array = []
	offer.answered.connect(func(w: bool): answers.append(w))
	_find_button(offer, "YES, I'M NEWBIE").pressed.emit()
	_find_button(offer, "NO, I'M ALREADY KIKORIKI").pressed.emit()
	check_eq(answers, [true, false], "вопрос про обучение: YES — обучение, NO — меню")
	offer.free()


## Все надписи (Label) под узлом одной строкой — для проверки содержимого окон.
## Настройки: значения по кругу, клавиши меняются местами, SETTINGS в меню по
## Esc. Пишется в свой файл (GameSettings.path_override в _initialize).
func _test_settings(panel: Node) -> void:
	check_eq(GameSettings.hold_seconds(), 3.0, "конец хода — 3 секунды удержания по умолчанию")
	_find_button(panel, "3 S").pressed.emit()
	check_eq(GameSettings.hold_seconds(), 5.0, "END TURN HOLD: 3 S → 5 S")
	check(_find_button(panel, "5 S") != null, "кнопка показывает новое значение")
	_find_button(panel, "x1").pressed.emit()
	check_eq(GameSettings.anim_speed(), 1.5, "ANIMATIONS: x1 → x1.5")
	GameSettings.set_value("hold_seconds", 3.0)
	GameSettings.set_value("anim_speed", 1.0)

	panel._wait_key("ping")
	check(_find_button(panel, "PRESS A KEY") != null, "щелчок по клавише — ждём новую")
	panel._wait_key("")
	GameSettings.set_key("ping", KEY_SPACE)
	check_eq(GameSettings.key("ping"), KEY_SPACE, "пинг теперь на пробеле")
	check_eq(GameSettings.key("end_turn"), KEY_TAB, "занятая клавиша поменялась местами с прежней")
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	check(GameSettings.is_key(event, "ping") and not GameSettings.is_key(event, "end_turn"),
		"нажатие узнаётся по новой клавише")
	GameSettings.reset_keys()
	check(GameSettings.key("ping") == KEY_TAB and GameSettings.key("end_turn") == KEY_SPACE,
		"RESET KEYS возвращает Tab и пробел")

	var pause := PauseMenu.new()
	check(_find_button(pause, "SETTINGS") != null, "в меню по Esc есть SETTINGS")
	_find_button(pause, "SETTINGS").pressed.emit()
	check(pause.settings_open() and _find_button(pause, "RESET KEYS") != null,
		"SETTINGS в меню по Esc открывает те же настройки")
	_find_button(pause, "BACK").pressed.emit()
	check(not pause.settings_open(), "BACK — назад к кнопкам меню")
	pause.free()


func _all_text(node: Node) -> String:
	var out := ""
	for child in node.get_children():
		if child is Label:
			out += (child as Label).text + "\n"
		out += _all_text(child)
	return out


func _find_button(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and (child as Button).text == text and not child.is_queued_for_deletion():
			return child
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


## Цвет из картинки RGBA8 совпадает с заданным с точностью до округления в 8 бит.
func _close_colour(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


## GameState целиком не сериализуем (дерево GDScript-объектов, не Dictionary) —
## сохранение партии (этап 7) хранит только сид + принятые Intent'ы и
## восстанавливает состояние повторным розыгрышем (GameRoom.restore). Здесь —
## без сети: то же самое напрямую через GameServer.apply_intent, проверяем,
## что восстановленная партия бит-в-бит совпадает с исходной.
func test_game_journal_replay() -> void:
	section("сеть: журнал партии и восстановление после «перезапуска» (этап 7)")
	var dir := "user://journal_test/"
	var code := "TEST"
	GameJournal.erase(code, dir)

	var ids: Array[String] = ["red", "blue"]
	var seed_value := 777
	var state := GameSetup.new_game(ids, seed_value, [], false, true, true, GameSetup.MODE_STANDARD)
	var live := GameServer.new(state)
	var log: Array = []

	# Стартовые сайты обоих (interactive_start=true) — те же MAKE_DECISION,
	# что шлёт сеть, отвечаем первым допустимым вариантом.
	while live.resolver.is_waiting():
		var pending := live.resolver.pending
		var intent := Intent.make_decision(pending.player_id, (pending.legal_options as Array)[0])
		check_eq(int(live.apply_intent(intent)["error"]), GameServer.Error.OK, "стартовый выбор принят")
		log.append(intent.to_dict())

	# Одно настоящее действие — конец хода текущего игрока.
	var end_intent := Intent.end_turn(state.current_player())
	check_eq(int(live.apply_intent(end_intent)["error"]), GameServer.Error.OK, "конец хода принят")
	log.append(end_intent.to_dict())

	var header := {"code": code, "ids": ids, "mode": GameSetup.MODE_STANDARD, "seed": seed_value,
		"profiles": {}, "accounts": {}, "keys": {}, "matched": true, "mulligan": true}
	GameJournal.save(code, header, log, dir)
	var loaded := GameJournal.load_game(code, dir)
	check(not loaded.is_empty(), "журнал читается обратно")
	check_eq((loaded["intents"] as Array).size(), log.size(), "в журнале все принятые ходы")

	var restored := GameRoom.restore(loaded["header"], loaded["intents"])
	check(restored.matched, "после перезапуска сервера партия поиска игры помнит, что за неё награда")
	check_eq(restored.server.state.current_player(), state.current_player(),
		"восстановленная партия на том же ходе")
	check_eq(Array(restored.server.state.players["red"].deck.hand), Array(state.players["red"].deck.hand),
		"рука red совпадает после восстановления")
	check_eq(Array(restored.server.state.players["blue"].deck.hand), Array(state.players["blue"].deck.hand),
		"рука blue совпадает после восстановления")
	check_eq(Array(restored.server.state.market.display), Array(state.market.display),
		"рынок совпадает после восстановления")
	check_eq(restored.server.state.troops, state.troops, "войска на доске совпадают после восстановления")
	check(not (restored.cached_board.get("schematic", {}) as Dictionary).is_empty(),
		"восстановленный снимок доски посчитан")

	GameJournal.erase(code, dir)
	check(GameJournal.load_game(code, dir).is_empty(), "erase убирает файл журнала")

	# Переподключение: свободное место находится по ключу профиля, занятое — нет.
	var room := GameRoom.new("ABCD", 2, GameSetup.MODE_STANDARD)
	room.started = true
	room.keys = {"red": "key-red", "blue": "key-blue"}
	check_eq(room.claim(5, "key-red"), "red", "переподключение по верному ключу находит цвет")
	check_eq(room.claim(6, "key-red"), "", "тот же ключ второй раз — место уже занято")
	check_eq(room.claim(7, "nope"), "", "чужой ключ — отказ")


## Реплеи (Replay-1): полная партия на 2, 3 и 4 игрока простым автоигроком,
## реплей на диск и обратно, пересборка по сиду и ходам — тот же итог.
func test_replay_book() -> void:
	section("реплеи: запись партии и пересборка по ходам")
	var dir := "user://replay_test/"
	for name in ReplayBook.list(dir):
		ReplayBook.erase(name, dir)
	var modes := {2: GameSetup.MODE_STANDARD, 3: GameSetup.MODE_RANDOM_3, 4: GameSetup.MODE_RANDOM_4}
	for count: int in [2, 3, 4]:
		var ids := GameScreen.player_ids_for(count)
		var seed_value := 4242 + count
		var live := GameServer.new(GameSetup.new_game(ids, seed_value, [], false, true, true, modes[count]))
		var log := _autoplay(live)
		check(live.state.game_over, "%d игрока: автоигрок доиграл партию до конца (%d ходов)" % [count, log.size()])
		var header := ReplayBook.header_for(live.state, ids, seed_value, modes[count], live.with_mulligan,
			{"red": {"name": "Ann", "emblem": "x"}}, "", "", log)
		header["date"] = 1700000000 + count
		var file := ReplayBook.save(header, log, dir)
		var loaded := ReplayBook.load_replay(file, dir)
		check(not loaded.is_empty() and ReplayBook.same_version(loaded), "%d игрока: реплей читается, версия своя" % count)
		check_eq(String((loaded["header"]["profiles"] as Dictionary)["red"]["name"]), "Ann", "%d игрока: имена в реплее" % count)
		var rebuilt := ReplayBook.rebuild(loaded)
		check(ReplayBook.matches(loaded, rebuilt), "%d игрока: пересборка по ходам — те же очки" % count)
		check_eq(Array(rebuilt.state.market.display), Array(live.state.market.display), "%d игрока: тот же рынок в конце" % count)
		check_eq(rebuilt.state.troops, live.state.troops, "%d игрока: те же войска в конце" % count)
	check_eq(ReplayBook.list(dir).size(), 3, "три реплея в папке")
	check(ReplayBook.list(dir)[0].begins_with("20231114"), "новые первыми, имя файла — дата")

	# Досрочный конец: игрок не вернулся — реплей кончается тем же abandon.
	var ids2 := GameScreen.player_ids_for(2)
	var quit := GameServer.new(GameSetup.new_game(ids2, 99, [], false, true, true, GameSetup.MODE_STANDARD))
	var short := _autoplay(quit, 10)
	quit.abandon("blue")
	var gone := ReplayBook.header_for(quit.state, ids2, 99, GameSetup.MODE_STANDARD, true, {}, "", "", short)
	check_eq(String(gone["abandoned_by"]), "blue", "в реплее записано, кто бросил партию")
	check(ReplayBook.matches({"header": gone, "intents": short}, ReplayBook.rebuild({"header": gone, "intents": short})),
		"брошенная партия пересобирается до того же конца")

	# Реплей живёт, пока на него ссылается история.
	var keep := ReplayBook.list(dir)[1]
	ReplayBook.keep_only([keep, ""], dir)
	check_eq(ReplayBook.list(dir), [keep] as Array[String], "keep_only оставляет только реплеи из истории")
	ReplayBook.keep_only([], dir)
	check(ReplayBook.list(dir).is_empty(), "пустая история — реплеев нет")


## Простой автоигрок для тестов: отвечает первым вариантом, разыгрывает всю
## руку, покупает что по карману, ставит войско, кончает ход. Возвращает
## принятые ходы (как журнал комнаты). max_intents — остановиться раньше.
func _autoplay(server: GameServer, max_intents: int = 20000) -> Array:
	var log: Array = []
	var state := server.state
	var tries := 0
	while not state.game_over and log.size() < max_intents and tries < 200000:
		tries += 1
		var intents: Array[Intent] = []
		if server.resolver.is_waiting():
			var pending := server.resolver.pending
			intents.append(Intent.make_decision(pending.player_id, (pending.legal_options as Array)[0]))
		else:
			var pid := state.current_player()
			var me: PlayerState = state.players[pid]
			for card in me.deck.hand:
				intents.append(Intent.play_card(pid, String(card)))
			for i in state.market.display.size():
				intents.append(Intent.recruit(pid, i))
			var slots := state.presence.deployable_slots(pid, state.troops, state.spies)
			if not slots.is_empty():
				intents.append(Intent.deploy(pid, slots[0]))
			intents.append(Intent.end_turn(pid))
		for intent in intents:
			if int(server.apply_intent(intent)["error"]) == GameServer.Error.OK:
				log.append(intent.to_dict())
				break
	return log


## Любимый цвет из профиля (решение владельца, 2026-09-28).
func test_colour_preference() -> void:
	section("профиль: любимый цвет места")
	check_eq(PlayerProfile.clean_colour("purple"), "purple", "цвет игры годится")
	check_eq(PlayerProfile.clean_colour("pink"), "", "чужой цвет — без предпочтения")
	var two: Array[String] = ["red", "blue"]
	check_eq(PlayerProfile.seat_first(two, "blue"), ["blue", "red"] as Array[String], "за одним экраном: свой цвет первым")
	check_eq(PlayerProfile.seat_first(two, "purple"), ["purple", "blue"] as Array[String],
		"цвета нет среди мест — он заменяет первый")
	check_eq(PlayerProfile.seat_first(two, ""), two, "без предпочтения — как было")

	var room := GameRoom.new("COLR", 3, GameSetup.MODE_STANDARD)
	check_eq(room.add(1), "red", "без предпочтения — первый свободный")
	room.profiles["red"] = {"name": "Ann"}
	room.keys["red"] = "key-ann"
	check_eq(room.add(2, "red"), "red", "red занят тем, кто его не выбирал, — меняются местами")
	check_eq(room.seats[1], "blue", "уступивший пересел на освободившийся цвет")
	check_eq(room.profiles.get("blue", {}).get("name", ""), "Ann", "профиль переехал вместе с игроком")
	check_eq(room.keys.get("blue", ""), "key-ann", "ключ переехал вместе с игроком")
	check(not room.profiles.has("red"), "за red пока нет чужого профиля")
	check_eq(room.add(3, "red"), "green", "red уже выбран раньше — остаётся свободный цвет")
	check_eq(room.prefer(3, "purple"), "purple", "свободный цвет — пересел")
	check_eq(room.prefer(1, "purple"), "blue", "выбранный другим цвет не отнять")
	room.deal(3)
	check_eq(room.prefer(2, "blue"), "red", "после раздачи пересаживаться нельзя")

	var old_path := PlayerProfile.path_override
	PlayerProfile.path_override = "user://profile_colour_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProfile.path_override))
	PlayerProfile.save_local({"name": "Ann", "emblem": "", "colour": "green"})
	PlayerProfile.save_local({"name": "Anna", "emblem": ""})
	check_eq(String(PlayerProfile.load_local()["colour"]), "green", "цвет сохранён и не стёрт сохранением без цвета")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerProfile.path_override))
	PlayerProfile.path_override = old_path


## Пауза сетевой партии (решение владельца, 2026-09-27): отключился — партия
## стоит; вернулся — идёт дальше; не вернулся за отведённое время — конец
## партии по текущему счёту без рейтинга. Общая пауза кнопкой: снять может
## только поставивший, сама снимается по времени. Без сети — прямо на GameRoom.
func test_room_pause() -> void:
	section("сеть: пауза при отключении и общая пауза")
	var room := GameRoom.new("PAUS", 2, GameSetup.MODE_STANDARD)
	room.add(10)
	room.add(11)
	room.keys = {"red": "key-red", "blue": "key-blue"}
	room.deal(5)
	check(not room.is_paused(), "партия только началась — паузы нет")

	room.seats.erase(11)
	room.mark_absent("blue")
	check(room.is_paused(), "blue отключился — партия на паузе")
	check_eq(room.pause_status(300.0, 300.0)["absent"], {"blue": 300.0}, "в паузе: кого ждём и сколько")
	check(room.tick_pause(100.0, 300.0, 300.0).is_empty(), "100 с из 300 — ещё ждём")
	check_eq(room.pause_status(300.0, 300.0)["absent"], {"blue": 200.0}, "время ожидания убывает")
	check_eq(room.claim(12, "key-blue"), "blue", "blue вернулся на своё место")
	check(not room.is_paused(), "вернулся — пауза снята")

	check(room.set_manual_pause("red", true), "red ставит общую паузу")
	check(room.is_paused(), "общая пауза — партия стоит")
	check(not room.set_manual_pause("blue", false), "чужую паузу снять нельзя")
	check(not room.set_manual_pause("blue", true), "вторую паузу поверх первой не поставить")
	check_eq(room.pause_status(300.0, 300.0)["by"], "red", "в паузе видно, кто её поставил")
	check_eq(room.tick_pause(300.0, 300.0, 300.0), {"resumed": true}, "через 5 минут пауза снимается сама")
	check(not room.is_paused(), "после конца общей паузы партия идёт")
	check(room.set_manual_pause("red", true) and room.set_manual_pause("red", false),
		"поставивший снимает свою паузу сам")

	# Экран партии: плашка паузы и кнопка RESUME только у поставившего.
	var net := NetSession.new()
	var view := StateView.for_player_with_pending(room.server.state, "red", room.server.resolver.pending)
	var screen := GameScreen.new(0, [], [], GameSetup.MODE_STANDARD,
		{"session": net, "seat": "red", "board": StateView.board_snapshot(room.server.state), "view": view})
	screen._on_pause_changed({"absent": {"blue": 120.0}, "by": "", "left": 0.0})
	check(screen.is_paused() and screen._pause_overlay.visible, "экран: отключился соперник — плашка паузы")
	check(not screen._pause_resume.visible, "экран: пока ждём отключившегося, RESUME нет")
	screen._on_pause_changed({"absent": {}, "by": "red", "left": 300.0})
	check(screen._pause_resume.visible, "экран: своя общая пауза — есть RESUME")
	screen._on_pause_changed({"absent": {}, "by": "", "left": 0.0})
	check(not screen.is_paused() and not screen._pause_overlay.visible, "экран: пауза снята — плашки нет")
	screen.free()
	net.free()

	var empty := GameRoom.new("NONE", 2, GameSetup.MODE_STANDARD)
	empty.add(20)
	empty.add(21)
	empty.deal(6)
	empty.seats.clear()
	empty.mark_absent("red")
	empty.mark_absent("blue")
	check(empty.tick_pause(1000.0, 300.0, 300.0).is_empty(), "за столом никого — время ожидания не идёт")

	room.seats.erase(12)
	room.mark_absent("blue")
	check(room.tick_pause(299.0, 300.0, 300.0).is_empty(), "299 с — ещё ждём")
	check_eq(room.tick_pause(2.0, 300.0, 300.0), {"abandon": "blue"}, "5 минут без blue — конец партии")
	var result := room.abandon("blue")
	var red_view: Dictionary = result["views"]["red"]
	check(room.server.state.game_over and bool(red_view["game_over"]), "партия окончена")
	check_eq(red_view["abandoned_by"], "blue", "в срезе видно, кто не вернулся")
	check(red_view.has("final_scores") and red_view.has("winners"), "очки посчитаны по текущему состоянию")
	check(room.rated, "рейтинг за такую партию не считается")
	check(not room.is_paused(), "после конца партии паузы нет")
	check_eq(String((result["events"] as Array)[0]["type"]), "game_abandoned", "событие о конце партии")
	var panel := GameOverPanel.new()
	panel.update_from_view(red_view)
	check(panel._head.text.contains("DID NOT COME BACK"), "итоги: написано, что игрок не вернулся")
	panel.free()


## RETURN TO GAME в главном меню — только когда есть запомненная партия.
func test_resume_saved_game() -> void:
	section("сеть: возврат в незаконченную партию из меню")
	NetSession.forget_game()
	check(NetSession.saved_game().is_empty(), "запомненной партии нет")
	var menu := SetupScreen.new()
	check(_find_button(menu, "RETURN TO GAME") == null, "без партии кнопки RETURN TO GAME нет")
	menu.free()

	var net := NetSession.new()
	net._remember_server("127.0.0.1", NetSession.SERVER_PORT)
	net.room_code = "WXYZ"
	net._remember_game()
	check_eq(NetSession.saved_game(), {"address": "127.0.0.1", "port": NetSession.SERVER_PORT,
		"code": "WXYZ", "by_code": true}, "партия запомнена: сервер и код комнаты")
	menu = SetupScreen.new()
	var got := []
	menu.online_requested.connect(func(k: String, _c: int, _m: String, _a: String): got.append(k))
	var button := _find_button(menu, "RETURN TO GAME")
	check(button != null, "есть партия — на главной кнопка RETURN TO GAME")
	if button != null:
		button.pressed.emit()
	check_eq(got, ["resume"], "RETURN TO GAME открывает возврат в партию")
	menu.free()

	net._forget_if_over({"game_over": true})
	check(NetSession.saved_game().is_empty(), "партия кончилась — запись стёрта")
	net.free()


## Музыка: все версии есть, одной длины (иначе разъедутся) и зациклены;
## настроение выбирается по виду партии.
func test_music_stems_and_moods() -> void:
	_current = "music"
	var length := -1.0
	for name: String in Music.TRACKS:
		var stream := load(Music.DIR + name + ".ogg") as AudioStreamOggVorbis
		check(stream != null, "версия музыки %s загружается" % name)
		if stream == null:
			continue
		check(stream.loop, "версия %s зациклена" % name)
		if length < 0.0:
			length = stream.get_length()
		check(absf(stream.get_length() - length) < 0.01, "версия %s той же длины" % name)
	for mood: String in Music.MOODS:
		check(Music.TRACKS.has(Music.MOODS[mood]), "настроение %s ведёт на существующую версию" % mood)
	var view := {"current_player": "red", "game_over": false, "game_end_triggered": false}
	check_eq(GameScreen.music_mood(view, "red", false), "turn", "мой ход — turn")
	check_eq(GameScreen.music_mood(view, "blue", false), "wait", "ход соперника — wait")
	check_eq(GameScreen.music_mood(view, "blue", true), "turn", "хотсит — всегда turn")
	view["game_end_triggered"] = true
	check_eq(GameScreen.music_mood(view, "blue", false), "tension", "последний круг — tension")
	view["game_over"] = true
	check_eq(GameScreen.music_mood(view, "blue", false), "end", "итоги — end")


## Цвета совпадают с точностью до 8 бит на канал (картинка хранит RGBA8).
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


## Сколько на схеме мест, где трасса касается сама себя (петля) или пересекает
## трассу без общего с ней конца. Внутри рамок локаций не считается: там трассы
## не видны.
func _trace_crossings(s: Dictionary) -> int:
	var boxes: Array[Rect2] = []
	for site_id: String in (s["sites"] as Dictionary).keys():
		var r: Array = s["sites"][site_id]["rect"]
		boxes.append(Rect2(r[0], r[1], r[2], r[3]).grow(1.0))
	var segs: Array = []  # [от, до, номер трассы, номер отрезка]
	var traces: Array = s["traces"]
	for t in traces.size():
		var flat: Array = traces[t]
		for i in range(0, flat.size() - 2, 2):
			segs.append([Vector2(flat[i], flat[i + 1]), Vector2(flat[i + 2], flat[i + 3]), t, i / 2])
	var ends: Array = s["trace_ends"]
	var found := 0
	for i in segs.size():
		for j in range(i + 1, segs.size()):
			var a: Array = segs[i]
			var b: Array = segs[j]
			if a[2] == b[2]:
				if absi(int(a[3]) - int(b[3])) < 2:
					continue
			elif (ends[a[2]] as Array).has(ends[b[2]][0]) or (ends[a[2]] as Array).has(ends[b[2]][1]):
				continue
			var ra := Rect2(a[0], Vector2.ZERO).expand(a[1]).grow(0.01)
			var rb := Rect2(b[0], Vector2.ZERO).expand(b[1]).grow(0.01)
			if not ra.intersects(rb):
				continue
			var at := ra.intersection(rb).get_center()
			var hidden := false
			for box in boxes:
				if box.has_point(at):
					hidden = true
			if not hidden:
				found += 1
	return found


func test_celestial_order() -> void:
	section("New Era: полуколода Celestial Order")
	var deck := GameSetup.expand_half_deck("celestial")
	check_eq(deck.size(), 45, "Celestial Order: 45 карт в полуколоде")
	check(not GameSetup.available_half_decks().has("celestial"), "пока не все эффекты готовы, колода не в выборе (wip)")
	for cid: String in ["49000", "49010", "49019", "49022", "49023", "49024"]:
		check(CardLibrary.card_data(cid).get("type") == "CELESTIAL", "%s — карта Celestial" % cid)

	# Scout: при получении в сброс приходит Giant Eagle
	var state := _build_rich_state(5)
	var red: PlayerState = state.players["red"]
	red.deck.discard_pile.clear()
	state.market.display[0] = "49019"
	red.influence = 10
	check(Actions.recruit(state, "red", 0, 6), "Scout покупается с рынка")
	check(red.deck.discard_pile.has("49023"), "вместе со Scout в сброс пришёл Giant Eagle")

	# Gladiator: скидки на базовые действия до конца хода
	TurnEngine.start_turn(state, "red")
	check_eq(Actions.assassinate_cost(state), 3, "обычная цена Assassinate — 3")
	var r := EffectResolver.new()
	r.apply(CelestialCards.TurnDiscount.new("assassinate", 1), "red", state)
	r.apply(CelestialCards.TurnDiscount.new("return_spy", 2), "red", state)
	check_eq(Actions.assassinate_cost(state), 2, "после Gladiator Assassinate стоит 2")
	check_eq(Actions.return_spy_cost(state), 1, "после Gladiator возврат шпиона стоит 1")
	TurnEngine.start_turn(state, "red")
	check_eq(Actions.assassinate_cost(state), 3, "в новом ходу скидка пропала")

	# Hippogriff: House Guard дешевле на 1
	r.apply(CelestialCards.TurnDiscount.new("supply:" + Supplies.HOUSE_GUARD, 1), "red", state)
	check_eq(Actions.supply_cost(state, Supplies.HOUSE_GUARD), 2, "House Guard стоит 2 после Hippogriff")

	# Gold Dragon превращается в Ancient Gold Dragon и обратно
	red.deck.hand.append("49022")
	red.deck.discard_pile.clear()
	var r2 := EffectResolver.new()
	TurnEngine.play_card(state, "red", "49022", r2)
	_auto_resolve(state, r2, false)
	check(not red.deck.played_pile.has("49022"), "Gold Dragon ушёл из игры")
	check(red.deck.discard_pile.has("49024"), "Ancient Gold Dragon в сбросе")

	# Warrior Infantry: House Guard из 6 верхних карт — в руку
	red.deck.draw_pile = ["48342", "48340", "48342", "48340"] as Array[String]
	var hand_before := red.deck.hand.count("48340")
	var r3 := EffectResolver.new()
	r3.apply(FetchFromTop.new(6, func(c): return c == "48340"), "red", state)
	check_eq(red.deck.hand.count("48340"), hand_before + 2, "оба House Guard из верхних карт в руке")
	check_eq(red.deck.draw_pile, ["48342", "48342"] as Array[String], "остальные карты остались в колоде")

	# Scry 2: сбросить одну из двух верхних
	red.deck.draw_pile = ["48344", "48342", "48343"] as Array[String]
	red.deck.discard_pile.clear()
	var r4 := EffectResolver.new()
	r4.apply(ScryCards.new(2), "red", state)
	check(r4.is_waiting() and (r4.pending.legal_options as Array).has("48343"), "Scry показывает верхнюю карту")
	TurnEngine.resume_card(state, "48343", r4)
	TurnEngine.resume_card(state, "", r4)
	check_eq(red.deck.draw_pile, ["48344", "48342"] as Array[String], "сброшенная карта ушла с верха колоды")
	check_eq(red.deck.discard_pile, ["48343"] as Array[String], "и попала в сброс")

	# ReturnOwnTroops ровно 2: без двух своих войск вариант недоступен
	var empty_state := _build_rich_state(6)
	for slot_id: String in empty_state.troops.keys():
		if empty_state.troops[slot_id] == "red":
			empty_state.troops[slot_id] = ""
	check(not ReturnOwnTroops.new(2, true, func(_k): return null).is_available(empty_state, "red"),
		"Return 2 of your troops недоступен без своих войск")

	# Couatl и Druid: VP в конце партии
	var s2 := _build_rich_state(7)
	var a: PlayerState = s2.players["red"]
	var b: PlayerState = s2.players["blue"]
	a.deck = Deck.new(["49006", "49009", "48342", "48342", "48342"] as Array[String])
	b.deck = Deck.new(["48342"] as Array[String])
	(s2.players["green"] as PlayerState).deck = Deck.new([] as Array[String])
	s2.spies.clear()
	s2.spies["x"] = ["red", "blue"]
	s2.spies["y"] = ["red"]
	var extra := Scoring.card_bonus_vp(s2, "red")
	check_eq(int(extra["deck"]), 2 + 5, "Couatl = 2 VP за 2 шпиона, Druid = 5 VP втроём за самую большую колоду")
	check_eq(int(Scoring.card_bonus_vp(s2, "blue")["deck"]), 0, "у соперника без этих карт бонуса нет")

	# все карты колоды разыгрываются до конца
	for cid: String in ["49000", "49001", "49002", "49003", "49004", "49005", "49006", "49007", "49008",
			"49009", "49010", "49011", "49012", "49013", "49014", "49015", "49016", "49017", "49018",
			"49019", "49020", "49021", "49022", "49023", "49024"]:
		for prefer_last in [true, false]:
			var st := _build_rich_state(hash(cid) % 1000)
			var pl: PlayerState = st.players["red"]
			pl.deck.hand.append(cid)
			TurnEngine.start_turn(st, "red")
			var res := EffectResolver.new()
			TurnEngine.play_card(st, "red", cid, res)
			_auto_resolve(st, res, prefer_last)
			if res.is_waiting():
				check(false, "%s завис (prefer_last=%s)" % [cid, prefer_last])


func test_shield_guardian_reaction() -> void:
	section("New Era: реакция Shield Guardian в чужой ход")
	var state := _build_rich_state(31)
	var server := GameServer.new(state)
	var red: PlayerState = state.players["red"]
	var blue: PlayerState = state.players["blue"]
	# blue-войско там, где у red есть Присутствие
	var target := ""
	for slot_id in state.presence.deployable_slots("red", state.troops, state.spies):
		if state.troops.get(slot_id, "") == "":
			target = slot_id
			break
	check(target != "", "нашли слот рядом с red")
	state.troops[target] = "blue"
	blue.deck.hand = ["49021", "48342"] as Array[String]
	var blue_troops_before := blue.troops_in_barracks
	red.power = 10

	# базовое Assassinate: вопрос уходит blue, Power red уже потрачен
	var res := server.apply_intent(Intent.assassinate("red", target))
	check_eq(res["error"], GameServer.Error.OK, "Assassinate принят")
	check(server.resolver.is_waiting() and server.resolver.pending.player_id == "blue", "решает blue (владелец войска)")
	check_eq(red.power, 7, "red заплатил 3 Power")
	res = server.apply_intent(Intent.make_decision("blue", true))
	check_eq(res["error"], GameServer.Error.OK, "blue сбрасывает Shield Guardian")
	check_eq(state.troops[target], "blue", "войско blue выжило")
	check(not blue.deck.hand.has("49021") and blue.deck.discard_pile.has("49021"), "Shield Guardian ушёл из руки в сброс")
	# дальше blue сам ставит 4 войска
	var steps := 0
	while server.resolver.is_waiting() and steps < 10:
		steps += 1
		var pd: PendingDecision = server.resolver.pending
		check_eq(pd.player_id, "blue", "войска ставит blue")
		server.apply_intent(Intent.make_decision("blue", pd.legal_options[0]))
	check_eq(blue.troops_in_barracks, blue_troops_before - 4, "blue поставил 4 войска")
	check_eq(blue.deck.hand.size(), 2, "и взял карту (в руке снова 2)")

	# без Shield Guardian в руке удар проходит без вопроса
	res = server.apply_intent(Intent.assassinate("red", target))
	check(not server.resolver.is_waiting(), "без Shield Guardian вопроса нет")
	check(state.troops[target] != "blue", "войско убито")

	# карта: отказ от реакции — удар проходит
	var s2 := _build_rich_state(32)
	var target2 := ""
	for slot_id in s2.presence.deployable_slots("red", s2.troops, s2.spies):
		if s2.troops.get(slot_id, "") == "":
			target2 = slot_id
			break
	s2.troops[target2] = "blue"
	(s2.players["blue"] as PlayerState).deck.hand = ["49021"] as Array[String]
	var r := EffectResolver.new()
	r.apply(AssassinateTroop.new(1), "red", s2)
	TurnEngine.resume_card(s2, target2, r)
	check(r.is_waiting() and r.pending.player_id == "blue", "эффект карты тоже спрашивает blue")
	TurnEngine.resume_card(s2, false, r)
	check(not r.is_waiting(), "после отказа эффект закончился")
	check_eq(s2.troops[target2], "", "войско blue убито")
	check((s2.players["blue"] as PlayerState).deck.hand.has("49021"), "Shield Guardian остался в руке")


func test_shadow_isles() -> void:
	section("New Era: полуколода Shadow Isles")
	var deck := GameSetup.expand_half_deck("shadow")
	check_eq(deck.size(), 45, "Shadow Isles: 45 карт в полуколоде")
	check(not GameSetup.available_half_decks().has("shadow"), "колода пока не в обычном выборе (wip)")
	for cid: String in ["49100", "49113", "49123", "49124"]:
		check(CardLibrary.card_data(cid).get("type") == "SHADOW", "%s — карта Shadow Isles" % cid)

	var outcast := ShadowCards.OUTCAST
	var state := _build_rich_state(11)
	state.supplies = Supplies.standard(true, true)
	var red: PlayerState = state.players["red"]
	var blue: PlayerState = state.players["blue"]
	var green: PlayerState = state.players["green"]
	TurnEngine.start_turn(state, "red")

	# Insane Outcast считается, Specter получает +1 Power за каждый
	red.deck.hand.append_array([outcast, outcast, "49100"] as Array[String])
	for i in range(2):
		var ro := EffectResolver.new()
		TurnEngine.play_card(state, "red", outcast, ro)
		if ro.is_waiting():
			TurnEngine.resume_card(state, "", ro)  # не сбрасывать карту
	check_eq(ShadowCards.outcasts_played(state), 2, "сыграно 2 Insane Outcast")
	red.power = 0
	var r1 := EffectResolver.new()
	TurnEngine.play_card(state, "red", "49100", r1)
	check_eq(red.power, 5, "Specter: 3 + 2 за Outcast")

	# Cursed Affinity: Skull Lord дешевле на 2, обычная карта — нет, пока не сыгран Drider
	state.market.display[0] = "49113"
	state.market.display[1] = "49104"
	check_eq(Actions.market_cost(state, 0), 6, "Skull Lord: 8 - 2 за Outcast")
	check_eq(Actions.market_cost(state, 1), 4, "Needle Blight без скидки")
	EffectResolver.new().apply(ShadowCards._SetFlag.new("market_affinity"), "red", state)
	check_eq(Actions.market_cost(state, 1), 2, "после Drider скидка у всех карт рынка")
	TurnEngine.start_turn(state, "red")
	check_eq(Actions.market_cost(state, 0), 8, "в новом ходу скидка пропала")

	# Shadow: Outcast даёт +2 Power и карту
	EffectResolver.new().apply(ShadowCards._AddFlag.new("outcast_bonus"), "red", state)
	red.power = 0
	red.deck.hand.append(outcast)
	var hand_size := red.deck.hand.size()
	var r2 := EffectResolver.new()
	TurnEngine.play_card(state, "red", outcast, r2)
	if r2.is_waiting():
		TurnEngine.resume_card(state, "", r2)
	check_eq(red.power, 2, "Outcast под Shadow: +2 Power")
	check_eq(red.deck.hand.size(), hand_size, "и взята карта (минус сыгранный Outcast)")

	# Shambling Mound: Gargoyle разыгран дважды, в конце хода сожран, +3 Influence в начале следующего
	TurnEngine.start_turn(state, "red")
	red.influence = 0
	red.deck.hand.append_array(["49103", "49108"] as Array[String])
	TurnEngine.play_card(state, "red", "49103", EffectResolver.new())
	TurnEngine.play_card(state, "red", "49108", EffectResolver.new())
	check_eq(red.influence, 4, "Gargoyle под Shambling Mound: дважды по +2 Influence")
	var r3 := EffectResolver.new()
	TurnEngine.end_turn(state, "red", r3)
	_auto_resolve(state, r3, false)
	check(state.devoured_pile.has("49108"), "Gargoyle сожран в конце хода")
	check_eq(red.start_of_turn_influence, 3, "Gargoyle: +3 Influence отложено на следующий ход")
	TurnEngine.start_turn(state, "red")
	check(red.influence >= 3, "в начале хода пришло 3 Influence (плюс доход маркеров)")
	check_eq(red.start_of_turn_influence, 0, "и отложенное обнулилось")

	# Twig Blight при Devour уходит в запас и даёт 2 карты
	state.supplies.counts[ShadowCards.TWIG_BLIGHT] = 0
	red.deck.hand = ["49124"] as Array[String]
	red.deck.draw_pile = ["48342", "48342", "48342"] as Array[String]
	var r4 := EffectResolver.new()
	r4.apply(DevourCard.new("hand"), "red", state)
	TurnEngine.resume_card(state, "49124", r4)
	check_eq(state.supplies.remaining(ShadowCards.TWIG_BLIGHT), 1, "Twig Blight вернулся в запас")
	check_eq(red.deck.hand.size(), 2, "и дал взять 2 карты")
	check(not state.devoured_pile.has("49124"), "в стопку сожранных не попал")

	# Swarm of Crawling Claws в руке у blue: Outcast можно взять в руку
	blue.deck.hand = ["49109"] as Array[String]
	var r5 := EffectResolver.new()
	r5.apply(GiveInsaneOutcast.new("self"), "blue", state)
	check(r5.is_waiting() and r5.pending.player_id == "blue", "Swarm of Crawling Claws: вопрос получателю")
	TurnEngine.resume_card(state, true, r5)
	check(blue.deck.hand.has(outcast), "Outcast пришёл в руку")
	check(r5.is_waiting() and r5.pending.player_id == "blue", "затем Scry 1 у blue")
	TurnEngine.resume_card(state, "", r5)
	check(not r5.is_waiting(), "реакция закончилась")

	# Will-o'-Wisp: Outcast получает только тот, у кого его нет в руке
	var green_discard := green.deck.discard_pile.count(outcast)
	var blue_discard := blue.deck.discard_pile.count(outcast)
	var r6 := EffectResolver.new()
	r6.apply(ShadowCards._OutcastUnlessHolding.new(), "red", state)
	check_eq(blue.deck.discard_pile.count(outcast), blue_discard, "blue показал Outcast — ничего не получил")
	check_eq(green.deck.discard_pile.count(outcast), green_discard + 1, "green получил Outcast")

	# Green Hag: соперники могут сожрать карту из руки
	var r7 := EffectResolver.new()
	r7.apply(ShadowCards._OpponentsMayDevour.new(), "red", state)
	check(r7.is_waiting() and r7.pending.player_id == "blue", "Green Hag: первым спрашивают blue")
	TurnEngine.resume_card(state, "", r7)
	check(r7.is_waiting() and r7.pending.player_id == "green", "затем green")
	TurnEngine.resume_card(state, "", r7)

	# Barbed Devil: соперник делит 5 верхних карт, хозяин берёт одну стопку
	red.deck.hand.clear()
	red.deck.discard_pile.clear()
	red.deck.draw_pile = ["48342", "48342", "48342", "48344", "48340"] as Array[String]
	var r8 := EffectResolver.new()
	r8.apply(ShadowCards._ShadowSplit.new(), "red", state)
	check(r8.pending.choice_type == "target_player", "Barbed Devil: выбор соперника")
	TurnEngine.resume_card(state, "blue", r8)
	check(r8.pending.player_id == "blue", "делит blue")
	TurnEngine.resume_card(state, "48340", r8)
	TurnEngine.resume_card(state, "", r8)
	check(r8.pending.player_id == "red" and r8.pending.choice_type == "choose_option", "red выбирает стопку")
	TurnEngine.resume_card(state, 0, r8)
	check_eq(red.deck.hand, ["48340"] as Array[String], "открытая стопка в руке")
	check_eq(red.deck.discard_pile.size(), 4, "закрытая в сбросе")

	# Chain Devil: Outcast в колоде стоят 0 VP
	var s2 := _build_rich_state(12)
	(s2.players["red"] as PlayerState).deck = Deck.new(["49115", outcast, outcast] as Array[String])
	check_eq(int(Scoring.card_bonus_vp(s2, "red")["deck"]), 2, "Chain Devil: два Outcast по 0 вместо -1")

	# все карты колоды разыгрываются до конца
	for cid: String in ["49100", "49101", "49102", "49103", "49104", "49105", "49106", "49107", "49108",
			"49109", "49110", "49111", "49112", "49113", "49114", "49115", "49116", "49117", "49118",
			"49119", "49120", "49121", "49122", "49123", "49124"]:
		for prefer_last in [true, false]:
			var st := _build_rich_state(hash(cid) % 1000)
			st.supplies = Supplies.standard(true, true)
			var pl: PlayerState = st.players["red"]
			pl.deck.hand.append(cid)
			(st.players["blue"] as PlayerState).deck.hand.append("49109")
			TurnEngine.start_turn(st, "red")
			var res := EffectResolver.new()
			TurnEngine.play_card(st, "red", cid, res)
			_auto_resolve(st, res, prefer_last)
			if res.is_waiting():
				check(false, "%s завис (prefer_last=%s)" % [cid, prefer_last])
