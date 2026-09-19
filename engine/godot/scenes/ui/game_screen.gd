class_name GameScreen
extends Control

## Главный экран партии (этап 7). Хотсит: 2-4 человека за одним экраном,
## зритель переключается вместе с ходом.
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

## Все цвета, за какие можно сесть, в порядке рассадки: партия на N человек
## берёт первые N. Цвета — те же, что у фишек на доске (BoardPanel.PLAYER_COLORS).
const ALL_PLAYER_IDS: Array[String] = ["red", "blue", "green", "purple"]
const MIN_PLAYERS := 2
const MAX_PLAYERS := 4

# Сетка экрана в пикселях расчётного размера 640x360 (пиксель-арт: цифры
# только целые, отступы маленькие). Те же зоны и на тех же местах, что и до
# перехода на пиксель-арт, только втрое мельче. Колонки:
#   A — плашка хода сверху и чат с журналом снизу;
#   B — полоса сыгранных карт, доска и рука;
#   C — инфо игрока в нижнем ряду;
#   D — инфо противников, маркет, а внизу стопки и End turn.
# Доска в среднем ряду занимает всю ширину от A до D.
const MARGIN := 2.0
const GAP := 2.0
const COL_A := 112.0
const COL_C := 86.0
const COL_D := 134.0
const TOP_H := 26.0
const BOTTOM_H := 90.0
## Ширина плашки одного противника в верхнем ряду.
const ENEMY_W := 74.0
## Таймер хода: две минуты, по нулю ход завершается сам.
const TURN_SECONDS := 120.0

var server: GameServer
## Кто сидит за экраном, в порядке рассадки. Очередь хода — отдельно: её
## перемешивает GameSetup, чтобы первый ходящий выбирался случайно.
var player_ids: Array[String] = ALL_PLAYER_IDS.slice(0, MIN_PLAYERS)
var viewer_id: String = "red"
var board_data: Dictionary = {}

var _player_panel: PlayerPanel
var _enemy_info: EnemyInfoPanel
var _hand_panel: HandPanel
var _market_panel: MarketPanel
var _chat_panel: ChatPanel
var _log_panel: EventLogPanel
var _board_panel: BoardPanel
var _board_area: Control
var _decision_dialog: DecisionDialog
var _turn_panel: PanelContainer
var _turn_style: StyleBoxFlat
var _header: Label
var _status: Label
var _played_zone: PanelContainer
var _played_title: Label
var _played_strip: CardStrip
var _piles_column: HBoxContainer
var _pile_inner: PileZone
var _pile_discard: PileZone
var _pile_dialog: PileDialog
var _end_turn_area: Control
var _end_turn_button: Button
var _end_turn_style: StyleBoxFlat
var _timer_label: Label
var _deploy_vp_button: Button
var _hint_panel: PanelContainer
var _hint: Label
var _preview: CardPreview

## Таймер хода: сколько секунд осталось и чей ход сейчас отсчитываем — смена
## ходящего перезапускает отсчёт.
var _time_left := TURN_SECONDS
var _timed_player := ""
var _auto_ending := false


## Какие цвета раздать на партию из count человек.
static func player_ids_for(count: int) -> Array[String]:
	var ids: Array[String] = ALL_PLAYER_IDS.slice(0, clampi(count, MIN_PLAYERS, MAX_PLAYERS))
	return ids


func _init(game_seed: int = 0, half_decks: Array[String] = [], ids: Array[String] = []) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()
	if ids.size() >= MIN_PLAYERS:
		player_ids = ids.duplicate()
	var state := GameSetup.new_game(player_ids, game_seed, half_decks, false, true, true)
	server = GameServer.new(state)
	board_data = StateView.board_snapshot(state)
	viewer_id = server.resolver.pending.player_id if server.resolver.is_waiting() else state.current_player()
	_build_layout()
	refresh(StateView.for_player_with_pending(server.state, viewer_id, server.resolver.pending))
	_log_panel.add_note("Game started. Each player drew 5 cards and now chooses a starting site.")


## Общий вид зон экрана: рамка в один пиксель, без скруглений.
static func zone_style(margin: float = 2.0) -> StyleBoxFlat:
	return PixelTheme.box(PixelTheme.PANEL, PixelTheme.BORDER, 1, int(margin), int(margin))


## Мелкий заголовок зоны капсом.
static func section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	return label


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = PixelTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 3a. Плашка хода: чей ход, ниже — чего ждём. Левая грань — в цвет игрока.
	_turn_style = zone_style(2)
	_turn_style.border_width_left = 2
	_turn_panel = PanelContainer.new()
	_turn_panel.add_theme_stylebox_override("panel", _turn_style)
	add_child(_turn_panel)
	var turn_col := VBoxContainer.new()
	turn_col.add_theme_constant_override("separation", 1)
	turn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	_turn_panel.add_child(turn_col)
	_header = Label.new()
	turn_col.add_child(_header)
	_status = Label.new()
	_status.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	turn_col.add_child(_status)

	# 3. Общая полоса сыгранных карт: что сыграл тот, чей сейчас ход.
	_played_zone = PanelContainer.new()
	_played_zone.add_theme_stylebox_override("panel", zone_style(1))
	add_child(_played_zone)
	var played_row := HBoxContainer.new()
	played_row.add_theme_constant_override("separation", 3)
	_played_zone.add_child(played_row)
	_played_title = section_label("")
	_played_title.custom_minimum_size = Vector2(40, 0)
	_played_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_played_title.clip_text = true
	played_row.add_child(_played_title)
	_played_strip = CardStrip.new()
	# Полоса низкая: видно верх карты — имя и цену.
	_played_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	played_row.add_child(_played_strip)

	# 8. Инфо противников.
	_enemy_info = EnemyInfoPanel.new()
	add_child(_enemy_info)

	# 4. Доска лежит в простом Control, чтобы поверх неё (а не поверх маркета)
	# можно было повесить диалог решения и подсказку.
	_board_area = Control.new()
	add_child(_board_area)

	_board_panel = BoardPanel.new()
	_board_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board_panel.slot_clicked.connect(_on_slot_clicked)
	_board_panel.site_clicked.connect(_on_site_clicked)
	_board_area.add_child(_board_panel)

	# Подсказка «что можно сделать» — полупрозрачная плашка у верха доски.
	_hint_panel = PanelContainer.new()
	var hint_style := PixelTheme.box(Color(PixelTheme.BG, 0.85), PixelTheme.BORDER, 1, 3, 1)
	_hint_panel.add_theme_stylebox_override("panel", hint_style)
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint_panel.offset_left = 2
	_hint_panel.offset_right = -2
	_hint_panel.offset_top = 2
	_board_area.add_child(_hint_panel)
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", PixelTheme.GOLD)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_child(_hint)

	_decision_dialog = DecisionDialog.new()
	_decision_dialog.board = board_data  # чтобы подписывать цели названиями локаций
	_decision_dialog.option_chosen.connect(_on_decision_answer)
	_board_area.add_child(_decision_dialog)

	# 6. Маркет.
	_market_panel = MarketPanel.new()
	_market_panel.market_card_clicked.connect(_on_market_clicked)
	_market_panel.supply_card_clicked.connect(_on_supply_clicked)
	add_child(_market_panel)

	# 5. Чат и журнал.
	_chat_panel = ChatPanel.new()
	_chat_panel.message_sent.connect(func(text: String): _chat_panel.add_message(viewer_id, text))
	add_child(_chat_panel)
	_log_panel = _chat_panel.log_panel
	_log_panel.board = board_data

	# 2. Стопки зрителя: Внутренний круг и сброс. Стоят между инфо игрока и
	# кнопкой End turn, по щелчку показывают весь список карт.
	_piles_column = HBoxContainer.new()
	_piles_column.add_theme_constant_override("separation", int(GAP))
	add_child(_piles_column)
	_pile_inner = PileZone.new("INNER")
	_pile_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pile_inner.clicked.connect(func(): _open_pile("inner"))
	_piles_column.add_child(_pile_inner)
	_pile_discard = PileZone.new("DISCARD")
	_pile_discard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pile_discard.clicked.connect(func(): _open_pile("discard"))
	_piles_column.add_child(_pile_discard)

	# 7. Инфо игрока.
	_player_panel = PlayerPanel.new()
	add_child(_player_panel)

	# 9. End turn — квадратная кнопка; под ней таймер хода, над ней, когда
	# можно, Deploy for 1 VP.
	_end_turn_area = Control.new()
	_end_turn_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_end_turn_area)
	_end_turn_button = _square_button()
	_end_turn_button.pressed.connect(func(): _on_action_requested("end_turn"))
	_end_turn_area.add_child(_end_turn_button)
	_timer_label = Label.new()
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.tooltip_text = "Turn timer: when it runs out the turn ends by itself"
	_end_turn_area.add_child(_timer_label)
	_deploy_vp_button = Button.new()
	_deploy_vp_button.text = "Deploy: 1 VP"
	_deploy_vp_button.tooltip_text = "Your barracks are empty: the Deploy action gives 1 VP instead of a troop"
	_deploy_vp_button.pressed.connect(func(): _on_action_requested("deploy_for_vp"))
	_end_turn_area.add_child(_deploy_vp_button)

	# 1. Рука — поверх остальных зон: поднятая, она накрывает зону сыгранных карт.
	_hand_panel = HandPanel.new()
	# Без этой строки карты в руке молча не работали: сигнал от карты
	# отправлялся, но его никто не слушал. Ни один тест этого не видел, потому
	# что все они дёргали сервер напрямую, минуя щелчки мышью.
	_hand_panel.card_clicked.connect(_on_hand_card_clicked)
	add_child(_hand_panel)

	# Список карт стопки — поверх экрана, но под увеличенной копией карты.
	_pile_dialog = PileDialog.new()
	add_child(_pile_dialog)

	# Увеличенная копия карты под курсором (с зажатым Alt) — над всем экраном.
	_preview = CardPreview.new()
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_preview)

	_layout()


func _square_button() -> Button:
	var button := Button.new()
	button.text = "End turn"
	_end_turn_style = StyleBoxFlat.new()
	_end_turn_style.set_corner_radius_all(0)
	_end_turn_style.set_border_width_all(1)
	_end_turn_style.anti_aliasing = false
	_end_turn_style.shadow_size = 0
	var states := {
		"normal": _end_turn_style,
		"hover": _end_turn_style.duplicate(),
		"pressed": _end_turn_style.duplicate(),
		"disabled": _end_turn_style.duplicate(),
		"focus": StyleBoxEmpty.new(),
	}
	for key: String in states:
		button.add_theme_stylebox_override(key, states[key])
	button.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.48, 0.55))
	return button


## Цвет квадратной кнопки — в цвет ходящего игрока, недоступная — серая.
func _style_end_turn(colour: Color) -> void:
	var normal: StyleBoxFlat = _end_turn_style
	normal.bg_color = colour.darkened(0.45)
	normal.border_color = Color(0.92, 0.75, 0.35)
	normal.shadow_color = Color(colour, 0.35)
	var hover: StyleBoxFlat = _end_turn_button.get_theme_stylebox("hover")
	hover.bg_color = colour.darkened(0.25)
	hover.border_color = Color(1.0, 0.86, 0.5)
	hover.shadow_color = Color(colour, 0.6)
	var pressed: StyleBoxFlat = _end_turn_button.get_theme_stylebox("pressed")
	pressed.bg_color = colour.darkened(0.6)
	pressed.border_color = Color(0.8, 0.62, 0.3)
	var disabled: StyleBoxFlat = _end_turn_button.get_theme_stylebox("disabled")
	disabled.bg_color = Color(0.14, 0.135, 0.17)
	disabled.border_color = Color(0.28, 0.27, 0.33)
	disabled.shadow_color = Color(0, 0, 0, 0.3)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _board_area != null:
		_layout()


## Первый кадр: минимальные размеры панелей к этому моменту уже посчитаны, и
## _place кладёт зоны ровно в отведённые прямоугольники. Без этого панель
## игрока оставалась раздутой до своего раннего минимума и уезжала за экран.
func _ready() -> void:
	_layout()
	call_deferred("_layout")


## Раскладка зон по сетке. Считается от размера экрана, а не контейнерами:
## так края зон гарантированно совпадают по линейке.
func _layout() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0 or h < 10.0:
		return
	var a_x := MARGIN
	var d_x := w - MARGIN - COL_D
	var c_x := d_x - GAP - COL_C
	var b_x := a_x + COL_A + GAP
	var b_w := c_x - GAP - b_x
	var top_y := MARGIN
	var mid_y := top_y + TOP_H + GAP
	var bottom_y := h - MARGIN - BOTTOM_H
	var mid_h := bottom_y - GAP - mid_y

	# Инфо противников — плашка на каждого, поэтому зона шире при 3-4 игроках.
	# Ширину отъедает у полосы сыгранных карт.
	var info_w: float = maxf(COL_D, ENEMY_W * float(player_ids.size() - 1))
	var info_x: float = w - MARGIN - info_w
	_place(_turn_panel, a_x, top_y, COL_A, TOP_H)
	_place(_played_zone, b_x, top_y, info_x - GAP - b_x, TOP_H)
	_place(_enemy_info, info_x, top_y, info_w, TOP_H)
	# Доска занимает весь средний ряд — от левого края до маркета.
	_place(_board_area, a_x, mid_y, d_x - GAP - a_x, mid_h)
	_place(_market_panel, d_x, mid_y, COL_D, mid_h)
	_place(_chat_panel, a_x, bottom_y, COL_A, BOTTOM_H)
	_place(_player_panel, c_x, bottom_y, COL_C, BOTTOM_H)
	# Нижний ряд колонки D: сверху стопки, ниже кнопка End turn с таймером.
	var piles_h := 40.0
	_place(_piles_column, d_x, bottom_y, COL_D, piles_h)
	_place(_end_turn_area, d_x, bottom_y + piles_h + GAP, COL_D, BOTTOM_H - piles_h - GAP)
	# Рука занимает колонку B; запас сверху нужен карте под курсором — она
	# выдвигается выше края нижнего ряда.
	var hand_top := bottom_y - HandPanel.HOVER_LIFT - 2.0
	_place(_hand_panel, b_x, hand_top, b_w, h - MARGIN - hand_top)

	var button_h := 20.0
	var timer_h := 11.0
	var deploy_h := 13.0 if _deploy_vp_button.visible else 0.0
	var deploy_block: float = deploy_h + GAP if deploy_h > 0.0 else 0.0
	_deploy_vp_button.position = Vector2(0, 0)
	_deploy_vp_button.size = Vector2(COL_D, deploy_h)
	_end_turn_button.position = Vector2(0, deploy_block)
	_end_turn_button.size = Vector2(COL_D, button_h)
	_timer_label.position = Vector2(0, deploy_block + button_h + 1.0)
	_timer_label.size = Vector2(COL_D, timer_h)


static func _place(control: Control, x: float, y: float, width: float, height: float) -> void:
	control.position = Vector2(x, y).round()
	control.size = Vector2(width, height).round()


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


## Таймер хода. Отсчёт начинается заново на каждой смене ходящего; когда время
## вышло, интерфейс сам жмёт End turn — тем же намерением, что и щелчок мышью.
## Пока на экране висит вопрос карты, завершить ход нельзя, поэтому таймер ждёт
## ответа и завершает ход сразу после него.
func _process(delta: float) -> void:
	if _timer_label == null:
		return
	if server.state.game_over:
		_timer_label.text = "--:--"
		_timer_label.add_theme_color_override("font_color", Color(0.5, 0.49, 0.56))
		return
	var current := server.state.current_player()
	if current != _timed_player:
		_timed_player = current
		_time_left = TURN_SECONDS
	_time_left = maxf(0.0, _time_left - delta)
	var left := int(ceilf(_time_left))
	_timer_label.text = "%d:%02d" % [left / 60, left % 60]
	_timer_label.add_theme_color_override("font_color",
		Color(0.95, 0.38, 0.32) if _time_left <= 20.0 else Color(0.78, 0.76, 0.86))

	if _time_left <= 0.0 and not _auto_ending and current == viewer_id \
			and not _end_turn_button.disabled:
		_auto_ending = true
		_log_panel.add_note("Time is up — the turn ends automatically.")
		send(Intent.end_turn(current))
		_auto_ending = false


func refresh(view: Dictionary) -> void:
	_refresh_header(view)
	_player_panel.update_from_view(view, viewer_id)
	_enemy_info.update_from_view(view, viewer_id)
	_hand_panel.update_from_view(view, viewer_id)
	_market_panel.update_from_view(view)
	_board_panel.update_from_view(view, viewer_id, board_data)
	_decision_dialog.update_from_view(view, viewer_id)
	_refresh_played(view)
	_refresh_piles(view)
	_refresh_actions(view)
	# Плашка выбора цели закрывает верх доски — доска вписывается ниже неё.
	var covered: bool = _decision_dialog.visible and _decision_dialog.at_top
	_board_panel.set_top_inset(_decision_dialog.get_combined_minimum_size().y + 4.0 if covered else 0.0)


func _refresh_header(view: Dictionary) -> void:
	var current := String(view["current_player"])
	var pending: Dictionary = view.get("pending_decision", {})
	if bool(view["game_over"]):
		_header.text = "GAME OVER"
		_header.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
		_turn_style.border_color = Color(0.92, 0.75, 0.35)
		_status.text = "Final scores are in the log."
		return
	_header.text = "%s'S TURN" % EventLogPanel.player_name(current).to_upper()
	_header.add_theme_color_override("font_color", EventLogPanel.player_color(current))
	_turn_style.border_color = BoardPanel.PLAYER_COLORS.get(current, Color.GRAY)
	var notes: Array[String] = []
	var decider := String(pending.get("player_id", ""))
	if decider != "":
		notes.append("%s is deciding" % EventLogPanel.player_name(decider))
	if bool(view["game_end_triggered"]):
		notes.append("LAST ROUND")
	if notes.is_empty():
		notes.append("You are playing %s" % EventLogPanel.player_name(viewer_id))
	_status.text = " · ".join(PackedStringArray(notes))


## Общая полоса сыгранных карт: что сыграл в этот ход тот, чей сейчас ход.
## Своя стопка сыгранных карт внизу больше не нужна — она была здесь же.
func _refresh_played(view: Dictionary) -> void:
	var current := String(view["current_player"])
	var p: Dictionary = (view["players"] as Dictionary).get(current, {})
	_played_title.text = "%s:" % EventLogPanel.player_name(current).to_upper()
	_played_title.add_theme_color_override("font_color", EventLogPanel.player_color(current))
	_played_strip.empty_text = "nothing played yet"
	_played_strip.set_cards(p.get("played_pile", []))


## Стопки зрителя. Сброс виден только своему игроку (StateView его прячет),
## Внутренний круг открыт всем — здесь показываем всё равно только свой.
func _refresh_piles(view: Dictionary) -> void:
	var me: Dictionary = (view["players"] as Dictionary)[viewer_id]
	_pile_inner.set_cards(me.get("inner_circle", []))
	_pile_discard.set_cards(me.get("discard_pile", []))


## Щелчок по стопке — весь её список поверх экрана.
func _open_pile(which: String) -> void:
	var view := StateView.for_player_with_pending(server.state, viewer_id, server.resolver.pending)
	var me: Dictionary = (view["players"] as Dictionary)[viewer_id]
	var who := EventLogPanel.player_name(viewer_id)
	if which == "inner":
		_pile_dialog.open_pile("%s — Inner Circle" % who, me.get("inner_circle", []))
	else:
		_pile_dialog.open_pile("%s — Discard pile" % who, me.get("discard_pile", []))


func _refresh_actions(view: Dictionary) -> void:
	var legal: Dictionary = view.get("legal", {})
	var p: Dictionary = (view["players"] as Dictionary)[viewer_id]
	_end_turn_button.disabled = not bool(legal.get("end_turn", false))
	_style_end_turn(BoardPanel.PLAYER_COLORS.get(viewer_id, Color(0.6, 0.6, 0.6)))
	var show_deploy := bool(legal.get("deploy_for_vp", false))
	if _deploy_vp_button.visible != show_deploy:
		_deploy_vp_button.visible = show_deploy
		_layout()

	var pending: Dictionary = view.get("pending_decision", {})
	var text := ""
	if bool(view.get("game_over", false)):
		text = "The game is over."
	elif not pending.is_empty():
		text = ""  # вопрос карты уже показан плашкой решения
	elif String(view["current_player"]) != viewer_id:
		text = "%s's turn." % EventLogPanel.player_name(String(view["current_player"]))
	else:
		text = PlayerPanel.describe_options(legal, p)
	_hint.text = text
	_hint_panel.visible = text != ""


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
