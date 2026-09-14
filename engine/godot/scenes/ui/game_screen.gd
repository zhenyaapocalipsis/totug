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
var _board_area: Control
var _decision_dialog: DecisionDialog
var _header: Label
var _header_style: StyleBoxFlat
var _scoreboard: RichTextLabel


func _init(game_seed: int = 0, half_decks: Array[String] = []) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var state := GameSetup.new_game(PLAYER_IDS, game_seed, half_decks, false, true, true)
	server = GameServer.new(state)
	board_data = StateView.board_snapshot(state)
	viewer_id = server.resolver.pending.player_id if server.resolver.is_waiting() else state.current_player()
	_build_layout()
	refresh(StateView.for_player_with_pending(server.state, viewer_id, server.resolver.pending))
	_log_panel.add_note("Game started. Each player drew 5 cards and now chooses a starting site.")


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

	# Плашка хода: чей ход — крупно и в цвете игрока, справа счёт всех игроков.
	_header_style = StyleBoxFlat.new()
	_header_style.bg_color = Color(0.12, 0.12, 0.16)
	_header_style.set_corner_radius_all(6)
	_header_style.content_margin_left = 12
	_header_style.content_margin_right = 12
	_header_style.content_margin_top = 4
	_header_style.content_margin_bottom = 4
	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", _header_style)
	root.add_child(header_panel)
	var header_row := HBoxContainer.new()
	header_panel.add_child(header_row)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 20)
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(_header)

	_scoreboard = RichTextLabel.new()
	_scoreboard.bbcode_enabled = true
	_scoreboard.fit_content = true
	_scoreboard.scroll_active = false
	_scoreboard.autowrap_mode = TextServer.AUTOWRAP_OFF
	_scoreboard.custom_minimum_size = Vector2(520, 0)
	_scoreboard.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_scoreboard.add_theme_font_size_override("normal_font_size", 14)
	_scoreboard.add_theme_font_size_override("bold_font_size", 14)
	header_row.add_child(_scoreboard)

	# Доска — главное на экране, поэтому она занимает всю ширину слева и всю
	# свободную высоту, а панель игрока переехала под неё отдельной строкой.
	# В прошлой раскладке доска была зажата в узкий угол и её нельзя было
	# рассмотреть.
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 8)
	root.add_child(middle)

	# Доска лежит в простом Control, чтобы поверх неё (а не поверх маркета)
	# можно было повесить диалог решения.
	_board_area = Control.new()
	_board_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_area.custom_minimum_size = Vector2(520, 300)
	middle.add_child(_board_area)

	_board_panel = BoardPanel.new()
	_board_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board_panel.slot_clicked.connect(_on_slot_clicked)
	_board_panel.site_clicked.connect(_on_site_clicked)
	_board_area.add_child(_board_panel)

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
	# Журнал делит высоту с маркетом (маркет прокручивается), иначе в нём
	# помещалось три строки и читать его было невозможно.
	_market_panel.size_flags_stretch_ratio = 1.6
	_log_panel = EventLogPanel.new()
	_log_panel.board = board_data
	_log_panel.custom_minimum_size = Vector2(0, 150)
	_log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	_board_area.add_child(_decision_dialog)


# --- отправка намерений ------------------------------------------------------

## Всё, что делает интерфейс, проходит здесь. Ошибку сервера показываем в
## журнале, а не глотаем: если UI предложил недопустимое действие, это его
## баг, и он должен быть виден.
func send(intent: Intent) -> void:
	var result: Dictionary = server.apply_intent(intent)
	var err: int = int(result["error"])
	if err != GameServer.Error.OK:
		_log_panel.add_note("Not allowed: %s" % _error_name(err))
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
		GameServer.Error.NOT_YOUR_TURN: return "it is not your turn"
		GameServer.Error.AWAITING_DECISION: return "answer the card's question first"
		GameServer.Error.NO_DECISION_PENDING: return "there is no question to answer"
		GameServer.Error.INVALID_ACTION: return "this action is not legal right now"
		GameServer.Error.GAME_OVER: return "the game is over"
		_: return "error %d" % err


func refresh(view: Dictionary) -> void:
	_refresh_header(view)
	_player_panel.update_from_view(view, viewer_id)
	_hand_panel.update_from_view(view, viewer_id)
	_market_panel.update_from_view(view)
	_board_panel.update_from_view(view, viewer_id, board_data)
	_decision_dialog.update_from_view(view, viewer_id)
	# Плашка выбора цели закрывает верх доски — доска вписывается ниже неё.
	var covered: bool = _decision_dialog.visible and _decision_dialog.at_top
	_board_panel.set_top_inset(_decision_dialog.get_combined_minimum_size().y + 16.0 if covered else 0.0)


func _refresh_header(view: Dictionary) -> void:
	var current := String(view["current_player"])
	var pending: Dictionary = view.get("pending_decision", {})
	if bool(view["game_over"]):
		_header.text = "Game over"
		_header.modulate = Color(0.95, 0.9, 0.8)
		_header_style.border_width_bottom = 0
	else:
		var text := "%s's turn" % EventLogPanel.player_name(current).to_upper()
		var decider := String(pending.get("player_id", ""))
		if decider != "" and decider != current:
			text += "  ·  waiting for %s to decide" % EventLogPanel.player_name(decider)
		if bool(view["game_end_triggered"]):
			text += "  ·  LAST ROUND"
		_header.text = text
		_header.modulate = EventLogPanel.player_color(current)
		_header_style.border_color = BoardPanel.PLAYER_COLORS.get(current, Color.GRAY)
		_header_style.border_width_bottom = 3

	# Счёт: VP открыты для всех, у текущего игрока ещё Power/Influence хода.
	var parts: Array[String] = []
	for pid in (view.get("turn_order", PLAYER_IDS) as Array):
		var p: Dictionary = (view["players"] as Dictionary).get(pid, {})
		if p.is_empty():
			continue
		var entry := "[b][color=%s]%s[/color][/b] %d VP" % [
			EventLogPanel.player_color(String(pid)).to_html(false),
			EventLogPanel.player_name(String(pid)), int(p["vp_tokens"])]
		if String(pid) == current:
			entry += " · %d Power · %d Influence" % [int(p["power"]), int(p["influence"])]
		parts.append(entry)
	_scoreboard.text = "[right]%s[/right]" % "      ".join(PackedStringArray(parts))


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
			_log_panel.add_note("That is not a valid target — valid targets have gold rings.")
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
		return "%s: your troop is already here" % where
	if legal.is_empty():
		return "%s: it is not your turn" % where

	var me: Dictionary = (view["players"] as Dictionary)[viewer_id]
	var has_presence: bool = (legal.get("presence_slots", []) as Array).has(slot_id)
	if owner == "":
		if not has_presence:
			return "%s: no Presence. You can only deploy next to your troops or at a site with your spy" % where
		if int(me["troops_in_barracks"]) <= 0:
			return "%s: your barracks are empty — use the \"Deploy for 1 VP\" button" % where
		return "%s: not enough Power (Deploy costs 1)" % where

	# слот занят чужим или белым войском — это цель для убийства
	if not has_presence:
		return "%s: you have no Presence at this troop" % where
	return "%s: not enough Power (Assassinate costs 3, you have %d)" % [where, int(me["power"])]


## Человеческое имя слота: "Caer Sidi, место 2" вместо "c_n1:C4_3_1".
func _slot_name(slot_id: String) -> String:
	var slots: Dictionary = board_data.get("slots", {})
	var sites: Dictionary = board_data.get("sites", {})
	if not slots.has(slot_id):
		return slot_id
	var site_id := String((slots[slot_id] as Dictionary).get("site_id", ""))
	if site_id == "" or not sites.has(site_id):
		return "Tunnel"
	var members: Array = (sites[site_id] as Dictionary)["slots"]
	return "%s, space %d" % [(sites[site_id] as Dictionary)["name"], members.find(slot_id) + 1]


## Клик по названию локации — возврат вражеского шпиона оттуда (3 Power).
func _on_site_clicked(site_id: String) -> void:
	var pending: PendingDecision = server.resolver.pending
	if pending != null and pending.player_id == viewer_id:
		if _try_resolve_board_decision(pending, "", site_id):
			return
		if _is_board_choice(pending.choice_type):
			_log_panel.add_note("That is not a valid target — valid targets have gold rings.")
			return

	var view := StateView.for_player_with_pending(server.state, viewer_id, server.resolver.pending)
	for target in ((view.get("legal", {}) as Dictionary).get("return_spy", []) as Array):
		var t: Dictionary = target
		if String(t["site_id"]) == site_id:
			send(Intent.return_spy(viewer_id, site_id, String(t["spy_owner"])))
			return
	_log_panel.add_note("%s: nothing to do here" % EventLogPanel.site_name(site_id, board_data))


func _on_decision_answer(answer: Variant) -> void:
	send(Intent.make_decision(viewer_id, answer))
