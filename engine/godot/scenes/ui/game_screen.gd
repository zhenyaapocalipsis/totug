class_name GameScreen
extends Control

## Главный экран партии (этап 7). Локальный режим: оба игрока за одним
## экраном, зритель переключается вместе с ходом.
##
## Единственный способ что-то изменить — послать Intent в GameServer и
## перерисоваться из того, что он вернул. Экран не читает и не правит
## GameState напрямую (кроме статической геометрии доски, которую берёт один
## раз при старте через StateView.board_snapshot) и не содержит ни одного
## правила игры: что сейчас можно нажать, ему сообщает view["legal"].
##
## Вся вёрстка собрана кодом, а не в .tscn. Причина практическая: сцены Godot
## в текстовом виде плохо читаются и правятся вслепую, а весь проект собирается
## и проверяется в контейнере без редактора. .tscn остаётся тонкой обёрткой —
## один узел со скриптом.

const PLAYER_IDS: Array[String] = ["red", "blue"]

var server: GameServer
var viewer_id: String = "red"
var board_data: Dictionary = {}

var _player_panel: PlayerPanel
var _hand_panel: HandPanel
var _market_panel: MarketPanel
var _log_panel: EventLogPanel
var _board_panel: BoardPanel
var _decision_dialog: DecisionDialog
var _header: Label


func _init(game_seed: int = 0, half_decks: Array[String] = []) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var state := GameSetup.new_game(PLAYER_IDS, game_seed, half_decks, false, true, true)
	server = GameServer.new(state)
	board_data = StateView.board_snapshot(state)
	viewer_id = server.resolver.pending.player_id if server.resolver.is_waiting() else state.current_player()
	_build_layout()
	refresh(StateView.for_player_with_pending(server.state, viewer_id, server.resolver.pending))
	_log_panel.add_note("Партия началась. Полуколоды маркета перетасованы вместе, каждому роздано по 5 карт. Каждый игрок выбирает свой стартовый сайт сам.")


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	root.offset_left = 10
	root.offset_top = 10
	root.offset_right = -10
	root.offset_bottom = -10
	add_child(root)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 16)
	root.add_child(_header)

	# Доска — главное на экране, поэтому она занимает всю ширину слева и всю
	# свободную высоту, а панель игрока переехала под неё отдельной строкой.
	# В прошлой раскладке доска была зажата в узкий угол и её нельзя было
	# рассмотреть.
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 8)
	root.add_child(middle)

	_board_panel = BoardPanel.new()
	_board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_panel.slot_clicked.connect(_on_slot_clicked)
	_board_panel.site_clicked.connect(_on_site_clicked)
	middle.add_child(_board_panel)

	# Правая колонка фиксированной ширины: карточки маркета читаемы только при
	# своей ширине, растягивать их незачем.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(452, 0)
	right.size_flags_horizontal = Control.SIZE_FILL
	right.add_theme_constant_override("separation", 8)
	middle.add_child(right)

	_market_panel = MarketPanel.new()
	_market_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_market_panel.market_card_clicked.connect(_on_market_clicked)
	_market_panel.supply_card_clicked.connect(_on_supply_clicked)
	right.add_child(_market_panel)

	# Журнал не растягиваем: свободную высоту должен забирать маркет.
	_log_panel = EventLogPanel.new()
	_log_panel.custom_minimum_size = Vector2(0, 118)
	right.add_child(_log_panel)

	_player_panel = PlayerPanel.new()
	_player_panel.action_requested.connect(_on_action_requested)
	root.add_child(_player_panel)

	_hand_panel = HandPanel.new()
	# Без этой строки карты в руке молча не работали: сигнал от карты
	# отправлялся, но его никто не слушал. Ни один тест этого не видел, потому
	# что все они дёргали сервер напрямую, минуя щелчки мышью.
	_hand_panel.card_clicked.connect(_on_hand_card_clicked)
	root.add_child(_hand_panel)

	_decision_dialog = DecisionDialog.new()
	_decision_dialog.board = board_data  # чтобы подписывать цели названиями локаций
	_decision_dialog.option_chosen.connect(_on_decision_answer)
	add_child(_decision_dialog)


# --- отправка намерений ------------------------------------------------------

## Всё, что делает интерфейс, проходит здесь. Ошибку сервера показываем в
## журнале, а не глотаем: если UI предложил недопустимое действие, это его
## баг, и он должен быть виден.
func send(intent: Intent) -> void:
	var result: Dictionary = server.apply_intent(intent)
	var err: int = int(result["error"])
	if err != GameServer.Error.OK:
		_log_panel.add_note("отказ сервера: %s" % _error_name(err))
	_log_panel.add_events(result["events"])

	# Ход мог перейти к другому игроку — в локальном режиме зритель следует
	# за ходом, кроме случая, когда решение ждут от кого-то конкретного.
	var pending: PendingDecision = server.resolver.pending
	if pending != null:
		viewer_id = pending.player_id
	elif not server.state.game_over:
		viewer_id = server.state.current_player()

	var views: Dictionary = result["views"]
	var view: Dictionary = views.get(viewer_id, {})
	if view.is_empty():
		view = StateView.for_player_with_pending(server.state, viewer_id, pending)
	refresh(view)


static func _error_name(err: int) -> String:
	match err:
		GameServer.Error.NOT_YOUR_TURN: return "сейчас не ваш ход"
		GameServer.Error.AWAITING_DECISION: return "сначала нужно ответить на вопрос карты"
		GameServer.Error.NO_DECISION_PENDING: return "отвечать сейчас не на что"
		GameServer.Error.INVALID_ACTION: return "действие недопустимо по правилам"
		GameServer.Error.GAME_OVER: return "партия уже закончена"
		_: return "ошибка %d" % err


func refresh(view: Dictionary) -> void:
	_header.text = "Tyrants of the Underdark — ход: %s%s" % [
		view["current_player"],
		"   (партия окончена)" if bool(view["game_over"]) else
			("   [конец близко: доигрываем круг]" if bool(view["game_end_triggered"]) else ""),
	]
	_player_panel.update_from_view(view, viewer_id)
	_hand_panel.update_from_view(view, viewer_id)
	_market_panel.update_from_view(view)
	_board_panel.update_from_view(view, viewer_id, board_data)
	_decision_dialog.update_from_view(view, viewer_id)


# --- обработчики кликов ------------------------------------------------------

func _on_action_requested(kind: String) -> void:
	match kind:
		"end_turn":
			send(Intent.end_turn(viewer_id))
		"deploy_for_vp":
			# Барак пуст: Deploy в любой слот даёт 1 VP, слот не важен —
			# движок сам это распознаёт по пустому бараку (рулбук, стр. 12).
			send(Intent.deploy(viewer_id, ""))


func _on_hand_card_clicked(card_id: String) -> void:
	send(Intent.play_card(viewer_id, card_id))


func _on_market_clicked(index: int) -> void:
	send(Intent.recruit(viewer_id, index))


func _on_supply_clicked(card_id: String) -> void:
	send(Intent.recruit_supply(viewer_id, card_id))


## Клик по троп-слоту двусмыслен: там может быть и Deploy в пустой слот, и
## Assassinate чужого войска. Решаем по тому, что сервер назвал допустимым;
## если допустимо и то и другое (так не бывает — слот либо занят, либо нет),
## приоритет у Assassinate как у более редкого намеренного действия.
func _on_slot_clicked(slot_id: String) -> void:
	var pending: PendingDecision = server.resolver.pending
	if pending != null and pending.player_id == viewer_id:
		if _try_resolve_board_decision(pending, slot_id, _site_of_slot(slot_id)):
			return
		if _is_board_choice(pending.choice_type):
			_log_panel.add_note("это не цель текущего решения — цели подсвечены жёлтым")
			return

	var view := StateView.for_player_with_pending(server.state, viewer_id, server.resolver.pending)
	var legal: Dictionary = view.get("legal", {})
	if (legal.get("assassinate_slots", []) as Array).has(slot_id):
		send(Intent.assassinate(viewer_id, slot_id))
	elif (legal.get("deploy_slots", []) as Array).has(slot_id):
		send(Intent.deploy(viewer_id, slot_id))
	else:
		_log_panel.add_note(_explain_slot_refusal(slot_id, view, legal))


func _is_board_choice(choice_type: String) -> bool:
	return choice_type == "target_slot" or choice_type == "target_site" or choice_type == "target_return"


## Пытается ответить на pending-решение кликом по доске: slot_id — конкретное
## войско (если кликнули по нему), site_id — локация под ним, либо локация,
## если кликнули по её названию напрямую (slot_id тогда ""). target_return
## кодирует составные цели ("troop|<slot_id>" / "spy|<site_id>|<owner>") —
## те же префиксы, что и в decision_dialog.gd::_board_label. Возвращает true,
## если ответ отправлен на сервер.
func _try_resolve_board_decision(pending: PendingDecision, slot_id: String, site_id: String) -> bool:
	match pending.choice_type:
		"target_slot":
			if slot_id != "" and pending.legal_options.has(slot_id):
				send(Intent.make_decision(viewer_id, slot_id))
				return true
		"target_site":
			if site_id != "" and pending.legal_options.has(site_id):
				send(Intent.make_decision(viewer_id, site_id))
				return true
		"target_return":
			if slot_id != "":
				var composite := "troop|" + slot_id
				if pending.legal_options.has(composite):
					send(Intent.make_decision(viewer_id, composite))
					return true
			if site_id != "":
				for opt in pending.legal_options:
					var raw := String(opt)
					if raw.begins_with("spy|" + site_id + "|"):
						send(Intent.make_decision(viewer_id, raw))
						return true
	return false


func _site_of_slot(slot_id: String) -> String:
	var slots: Dictionary = board_data.get("slots", {})
	if not slots.has(slot_id):
		return ""
	return String((slots[slot_id] as Dictionary).get("site_id", ""))


## Игроку мало знать, что "туда нельзя" — он спрашивал, почему нельзя занять
## гекс на другом конце доски. Причины разные, и различить их можно по срезу:
## presence_slots — где Присутствие есть вообще, без учёта ресурсов.
func _explain_slot_refusal(slot_id: String, view: Dictionary, legal: Dictionary) -> String:
	var where := _slot_name(slot_id)
	var owner := String((view.get("troops", {}) as Dictionary).get(slot_id, ""))
	if owner == viewer_id:
		return "%s: здесь уже стоит ваше войско" % where
	if legal.is_empty():
		return "%s: сейчас не ваш ход" % where

	var me: Dictionary = (view["players"] as Dictionary)[viewer_id]
	var has_presence: bool = (legal.get("presence_slots", []) as Array).has(slot_id)
	if owner == "":
		if not has_presence:
			return "%s: нет Присутствия. Ставить войско можно только туда, где рядом уже есть ваше войско или шпион" % where
		if int(me["troops_in_barracks"]) <= 0:
			return "%s: в бараке не осталось войск — используйте кнопку «Deploy за 1 VP»" % where
		return "%s: не хватает Power (Deploy стоит 1)" % where

	# слот занят чужим или белым войском — это цель для убийства
	if not has_presence:
		return "%s: нет Присутствия рядом с этой целью" % where
	return "%s: не хватает Power (Assassinate стоит 3, у вас %d)" % [where, int(me["power"])]


## Человеческое имя слота: "Caer Sidi, место 2" вместо "c_n1:C4_3_1".
func _slot_name(slot_id: String) -> String:
	var slots: Dictionary = board_data.get("slots", {})
	var sites: Dictionary = board_data.get("sites", {})
	if not slots.has(slot_id):
		return slot_id
	var site_id := String((slots[slot_id] as Dictionary).get("site_id", ""))
	if site_id == "" or not sites.has(site_id):
		return "туннель"
	var members: Array = (sites[site_id] as Dictionary)["slots"]
	return "%s, место %d" % [(sites[site_id] as Dictionary)["name"], members.find(slot_id) + 1]


## Клик по названию локации — возврат вражеского шпиона оттуда (3 Power).
func _on_site_clicked(site_id: String) -> void:
	var pending: PendingDecision = server.resolver.pending
	if pending != null and pending.player_id == viewer_id:
		if _try_resolve_board_decision(pending, "", site_id):
			return
		if _is_board_choice(pending.choice_type):
			_log_panel.add_note("это не цель текущего решения — цели подсвечены жёлтым")
			return

	var view := StateView.for_player_with_pending(server.state, viewer_id, server.resolver.pending)
	for target in ((view.get("legal", {}) as Dictionary).get("return_spy", []) as Array):
		var t: Dictionary = target
		if String(t["site_id"]) == site_id:
			send(Intent.return_spy(viewer_id, site_id, String(t["spy_owner"])))
			return
	_log_panel.add_note("на локации %s нечего возвращать" % site_id)


func _on_decision_answer(answer: Variant) -> void:
	send(Intent.make_decision(viewer_id, answer))
