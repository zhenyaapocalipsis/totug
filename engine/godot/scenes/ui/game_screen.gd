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
## Задник экрана подключён файлом, а не по глобальному имени класса:
## глобальные имена собирает редактор, а проект часто запускается из
## командной строки, где нового имени ещё нет в кэше.
const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")

# Сетка экрана в пикселях расчётного размера 960x540 (пиксель-арт: цифры
# только целые, отступы маленькие). Раскладка по решению владельца
# (2026-09-22), три колонки:
#   левая — бараки (1), под ними сыгранные карты во весь рост лесенкой (2),
#     внизу кнопки стопок Discard / Inner / Devoured (3);
#   середина — доска на всё свободное место (4), под ней рука (5);
#   правая — маркет от самого верха экрана (6), под ним End turn (7).
# Обе боковые колонки одной ширины — полная карта с рамкой.
# Power/Influence ходящего — в заголовке зоны сыгранных карт.
# Чей сейчас ход, написано на самой кнопке End turn; расклад по игрокам, чат и
# журнал — в меню по Tab (PlayersOverlay).
const MARGIN := 1.0
const GAP := 2.0
## Полёт купленной карты в стопку сброса: сколько летит и насколько выгнута
## дуга. По прямой полёт читается как рывок.
const FLIGHT_TIME := 0.42
const FLIGHT_ARC := 26.0
## Насколько трясти доску: убийство и вытеснение — заметно, возврат войска или
## шпиона — чуть.
const SHAKE_KILL := 4.0
const SHAKE_NUDGE := 2.0
## Ширина боковых колонок, обеих одинаковая (решение владельца, 2026-09-23):
## полная карта (176) плюс рамка зоны в пиксель с каждой стороны — в зоне
## сыгранных карт карта рисуется пиксель в пиксель. Рынку столько не нужно
## (два мелких лица по 80), лишнее у него остаётся по краям.
const COL := 178.0
## Высота зоны бараков.
const TOP_H := 22.0
## Высота нижнего ряда: мелкое лицо карты (76) плюс отступы подложки руки.
## Той же высоты кнопки стопок слева и End turn справа.
const BOTTOM_H := 80.0
## Заголовок зоны сыгранных карт: чей ход и его Power/Influence.
const PLAYED_HEAD_H := 11.0
const TIMER_H := 11.0
const DEPLOY_H := 13.0
## Цвета ресурсов хода — те же, что и на картах.
const POWER_COLOR := Color(0.95, 0.45, 0.35)
const INFLUENCE_COLOR := Color(0.45, 0.75, 0.98)
## Таймер хода: две минуты, по нулю ход завершается сам.
const TURN_SECONDS := 120.0

var server: GameServer
## Кто сидит за экраном, в порядке рассадки. Очередь хода — отдельно: её
## перемешивает GameSetup, чтобы первый ходящий выбирался случайно.
var player_ids: Array[String] = ALL_PLAYER_IDS.slice(0, MIN_PLAYERS)
var viewer_id: String = "red"
var board_data: Dictionary = {}

var _barracks: BarracksBar
var _overlay: PlayersOverlay
var _hand_panel: HandPanel
var _market_panel: MarketPanel
var _chat_panel: ChatPanel
var _log_panel: EventLogPanel
var _board_panel: BoardPanel
var _board_area: Control
var _decision_dialog: DecisionDialog
var _res_zone: HBoxContainer
var _res_power: CounterLabel
var _res_influence: CounterLabel
## Что на плашке ресурсов было показано в прошлый раз и чьё оно — по этому
## считается, на сколько всплыть цифре изменения.
var _res_player := ""
var _res_power_shown := 0
var _res_influence_shown := 0
var _played_zone: PanelContainer
var _played_head: HBoxContainer
var _played_title: Label
var _played_stack: PlayedStack
## Надпись на месте зоны сыгранных карт, пока идёт стартовая расстановка.
var _setup_label: Label
var _piles_column: VBoxContainer
var _pile_inner: PileZone
var _pile_discard: PileZone
## Общая для всех стопка сожранных карт — кнопкой рядом со своими стопками.
var _pile_devour: PileZone
var _pile_dialog: PileDialog
var _end_turn_area: Control
var _end_turn_button: Button
var _end_turn_style: StyleBoxFlat
## Две строки поверх кнопки End turn: чей ход (в цвет игрока) и сама надпись.
## Кнопка Godot однострочная, поэтому текст лежит отдельными подписями.
var _turn_label: Label
var _end_label: Label
var _timer_label: Label
## Пометка «начался последний круг» — отдельной строкой: в узкую колонку
## End turn она рядом с таймером не помещается.
var _last_round_label: Label
var _deploy_vp_button: Button
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
	# Тот же задник, что в меню, но приглушённый: за доской и картами он
	# должен только слегка дышать, а не спорить с ними за внимание.
	add_child(UnderdarkBg.make(UnderdarkBg.GAME_FADE, board_data.get("half_decks", [])))

	# 3a. Левый верхний угол: бараки всех игроков цветными квадратами.
	_barracks = BarracksBar.new()
	add_child(_barracks)

	# 2. Сыгранные карты того, чей сейчас ход: во весь рост, лесенкой. Сверху
	# заголовок — чей ход и его Power/Influence.
	_played_zone = PanelContainer.new()
	_played_zone.add_theme_stylebox_override("panel", zone_style(1))
	add_child(_played_zone)
	var played_col := VBoxContainer.new()
	played_col.add_theme_constant_override("separation", 1)
	_played_zone.add_child(played_col)
	_played_head = HBoxContainer.new()
	_played_head.custom_minimum_size = Vector2(0, PLAYED_HEAD_H)
	_played_head.add_theme_constant_override("separation", 6)
	played_col.add_child(_played_head)
	_played_title = section_label("")
	_played_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_played_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_played_title.clip_text = true
	_played_head.add_child(_played_title)
	# Power и Influence ходящего (решение владельца, 2026-09-22: в заголовке
	# этой же зоны) — тратит их тот, чьи карты под ними.
	_res_zone = HBoxContainer.new()
	_res_zone.add_theme_constant_override("separation", 6)
	_res_zone.tooltip_text = "Power and Influence of the player to move"
	_res_zone.mouse_filter = Control.MOUSE_FILTER_STOP  # чтобы работала подсказка
	_played_head.add_child(_res_zone)
	_res_power = CounterLabel.make("P %d", POWER_COLOR)
	_res_zone.add_child(_res_power)
	_res_influence = CounterLabel.make("I %d", INFLUENCE_COLOR)
	_res_zone.add_child(_res_influence)
	_played_stack = PlayedStack.new()
	_played_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	played_col.add_child(_played_stack)
	# 2b. Пока раздают стартовые локации, на месте этой же зоны стоит вопрос
	# «выбери стартовую локацию» (решение владельца, 2026-09-20): плашка над
	# доской закрывала как раз те локации, по которым надо щёлкнуть. Сама
	# зона сыгранных карт появляется, когда расстановка закончена.
	_setup_label = Label.new()
	_setup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_setup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_setup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_setup_label.visible = false
	played_col.add_child(_setup_label)

	# 4. Доска лежит в простом Control, чтобы поверх неё (а не поверх маркета)
	# можно было повесить диалог решения и подсказку.
	_board_area = Control.new()
	add_child(_board_area)

	_board_panel = BoardPanel.new()
	_board_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board_panel.slot_clicked.connect(_on_slot_clicked)
	_board_panel.site_clicked.connect(_on_site_clicked)
	_board_area.add_child(_board_panel)

	_decision_dialog = DecisionDialog.new()
	_decision_dialog.board = board_data  # чтобы подписывать цели названиями локаций
	_decision_dialog.option_chosen.connect(_on_decision_answer)
	_board_area.add_child(_decision_dialog)

	# 6. Маркет.
	_market_panel = MarketPanel.new()
	_market_panel.market_card_clicked.connect(_on_market_clicked)
	_market_panel.supply_card_clicked.connect(_on_supply_clicked)
	add_child(_market_panel)

	# 3. Стопки кнопками одна под другой в левом нижнем углу: свой сброс,
	# свой Внутренний круг и общая для всех стопка сожранных карт (из неё же
	# берётся «призрак», Ghost). По щелчку — весь список карт стопки.
	_piles_column = VBoxContainer.new()
	_piles_column.add_theme_constant_override("separation", int(GAP))
	add_child(_piles_column)
	_pile_discard = PileZone.new("DISCARD")
	_pile_discard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pile_discard.clicked.connect(func(): _open_pile("discard"))
	_piles_column.add_child(_pile_discard)
	_pile_inner = PileZone.new("INNER CIRCLE")
	_pile_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pile_inner.clicked.connect(func(): _open_pile("inner"))
	_piles_column.add_child(_pile_inner)
	_pile_devour = PileZone.new("DEVOURED")
	_pile_devour.tooltip_text = "Cards devoured out of the game. Click to see them all"
	_pile_devour.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pile_devour.clicked.connect(func(): _open_pile("devour"))
	_piles_column.add_child(_pile_devour)

	# 7. End turn — правый нижний угол: высокая кнопка, на ней же написано,
	# чей сейчас ход; под ней таймер, над ней Deploy for 1 VP.
	_end_turn_area = Control.new()
	_end_turn_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_end_turn_area)
	_end_turn_button = _square_button()
	_end_turn_button.pressed.connect(func(): _on_action_requested("end_turn"))
	_end_turn_area.add_child(_end_turn_button)
	# Подписи лежат ПОВЕРХ кнопки и не ловят мышь, поэтому щелчок по любой из
	# них — это щелчок по кнопке.
	_turn_label = Label.new()
	_turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.clip_text = true
	_end_turn_area.add_child(_turn_label)
	_end_label = Label.new()
	_end_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.text = "END TURN"
	_end_turn_area.add_child(_end_label)
	_timer_label = Label.new()
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.tooltip_text = "Turn timer: when it runs out the turn ends by itself"
	_end_turn_area.add_child(_timer_label)
	_last_round_label = Label.new()
	_last_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_last_round_label.text = "LAST ROUND"
	_last_round_label.visible = false
	_last_round_label.add_theme_color_override("font_color", PixelTheme.GOLD)
	_end_turn_area.add_child(_last_round_label)
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

	# Меню по Tab: полный расклад по игрокам, под ним чат и журнал событий.
	_overlay = PlayersOverlay.new()
	add_child(_overlay)
	_chat_panel = ChatPanel.new()
	_chat_panel.message_sent.connect(func(text: String): _chat_panel.add_message(viewer_id, text))
	_overlay.add_chat(_chat_panel)
	_log_panel = _chat_panel.log_panel
	_log_panel.board = board_data

	# Увеличенная копия карты под курсором (с зажатым Alt) — над всем экраном.
	_preview = CardPreview.new()
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_preview)

	_layout()


func _square_button() -> Button:
	var button := Button.new()
	button.text = ""  # надписи лежат поверх кнопки отдельными Label
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


## Tab открывает и закрывает меню (расклад по игрокам, чат, журнал), Esc его
## закрывает. Tab перехватываем целиком — даже из строки чата: иначе он уводит
## фокус по кнопкам интерфейса.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null:
		return
	if key.keycode == KEY_TAB:
		if key.pressed and not key.echo:
			set_menu_open(not _overlay.visible)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and key.pressed and _overlay.visible:
		set_menu_open(false)
		get_viewport().set_input_as_handled()


func set_menu_open(open: bool) -> void:
	_overlay.visible = open
	if not open:
		# Строка чата не должна держать фокус под закрытым меню.
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and _overlay.is_ancestor_of(focused):
			focused.release_focus()


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
	var d_x := w - MARGIN - COL
	var b_x := a_x + COL + GAP
	var b_w := d_x - GAP - b_x
	var top_y := MARGIN
	var bottom_y := h - MARGIN - BOTTOM_H

	# Левая колонка: бараки, под ними сыгранные карты, внизу кнопки стопок.
	_place(_barracks, a_x, top_y, COL, TOP_H)
	var played_y := top_y + TOP_H + GAP
	_place(_played_zone, a_x, played_y, COL, bottom_y - GAP - played_y)
	_place(_piles_column, a_x, bottom_y, COL, BOTTOM_H)

	# Доска — всё, что между колонками, от верха экрана до руки.
	_place(_board_area, b_x, top_y, b_w, bottom_y - GAP - top_y)

	# Правая колонка: маркет от самого верха экрана, под ним End turn.
	_place(_market_panel, d_x, top_y, COL, bottom_y - GAP - top_y)
	_place(_end_turn_area, d_x, bottom_y, COL, BOTTOM_H)

	# Рука занимает середину нижнего ряда; запас сверху нужен карте под
	# курсором — она выдвигается выше края ряда.
	var hand_top := bottom_y - HandPanel.HOVER_LIFT - 2.0
	_place(_hand_panel, b_x, hand_top, b_w, h - MARGIN - hand_top)

	# Внутри зоны End turn: сверху Deploy (когда он есть), снизу таймер, а
	# кнопка растянута на всё, что между ними. Подписи «чей ход» и «END TURN»
	# лежат по центру кнопки.
	var ew := COL
	var deploy_h := DEPLOY_H if _deploy_vp_button.visible else 0.0
	var deploy_block: float = deploy_h + GAP if deploy_h > 0.0 else 0.0
	var timer_block: float = TIMER_H
	if _last_round_label.visible:
		timer_block += float(PixelTheme.LINE_H)
	var button_h: float = BOTTOM_H - deploy_block - timer_block
	_deploy_vp_button.position = Vector2(0, 0)
	_deploy_vp_button.size = Vector2(ew, deploy_h)
	_end_turn_button.position = Vector2(0, deploy_block)
	_end_turn_button.size = Vector2(ew, button_h)
	var caption_y := deploy_block + floorf((button_h - PixelTheme.LINE_H * 2.0) * 0.5)
	_turn_label.position = Vector2(0, caption_y)
	_turn_label.size = Vector2(ew, PixelTheme.LINE_H)
	_end_label.position = Vector2(0, caption_y + PixelTheme.LINE_H)
	_end_label.size = Vector2(ew, PixelTheme.LINE_H)
	_timer_label.position = Vector2(0, deploy_block + button_h)
	_timer_label.size = Vector2(ew, TIMER_H)
	_last_round_label.position = Vector2(0, deploy_block + button_h + TIMER_H)
	_last_round_label.size = Vector2(ew, PixelTheme.LINE_H)


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
	_react_to_events(result["events"])


## Чем громче событие на доске, тем сильнее её тряхнёт. Захват локации доска
## замечает сама (по смене владельца), а здесь — то, чего в расстановке войск
## не видно: убийство, вытеснение, возврат чужого войска или шпиона.
func _react_to_events(events: Array) -> void:
	var power := 0.0
	for e in events:
		var evt: Dictionary = e
		match String(evt.get("type", "")):
			"assassinate", "supplant":
				power = maxf(power, SHAKE_KILL)
				_board_panel.spark_at_slot(String(evt.get("slot_id", "")),
					BoardPanel.KILL_COLOR)
			"return_troop", "return_spy", "return_own_spy":
				power = maxf(power, SHAKE_NUDGE)
	if power > 0.0:
		_board_panel.shake(power)


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
	# Под таймером — единственная оставшаяся пометка о состоянии партии:
	# начался последний круг, дальше подсчёт очков. Отдельной строкой: рядом с
	# таймером она в узкую колонку не помещается.
	if _last_round_label.visible != server.state.game_end_triggered:
		_last_round_label.visible = server.state.game_end_triggered
		_layout()
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
	_refresh_turn(view)
	_barracks.update_from_view(view)
	_overlay.update_from_view(view)
	_hand_panel.update_from_view(view, viewer_id)
	_market_panel.update_from_view(view)
	_board_panel.update_from_view(view, viewer_id, board_data)
	_decision_dialog.update_from_view(view, viewer_id)
	# Вопрос стартовой расстановки показывает не плашка над доской, а сама
	# зона сыгранных карт — плашке тут делать нечего.
	if _is_starting_pick(view):
		_decision_dialog.visible = false
	_refresh_played(view)
	_refresh_piles(view)
	_refresh_actions(view)
	# Плашка выбора цели закрывает верх доски — доска вписывается ниже неё.
	var covered: bool = _decision_dialog.visible and _decision_dialog.at_top
	_board_panel.set_top_inset(_decision_dialog.get_combined_minimum_size().y + 4.0 if covered else 0.0)


## Чей сейчас ход — на самой кнопке End turn (решение владельца, 2026-09-19).
func _refresh_turn(view: Dictionary) -> void:
	var current := String(view["current_player"])
	if bool(view["game_over"]):
		_turn_label.text = "GAME OVER"
		_turn_label.add_theme_color_override("font_color", PixelTheme.GOLD)
		_end_label.text = ""
		return
	_turn_label.text = "%s'S TURN" % EventLogPanel.player_name(current).to_upper()
	_turn_label.add_theme_color_override("font_color", EventLogPanel.player_color(current))
	_end_label.text = "END TURN"


## Общая полоса сыгранных карт: что сыграл в этот ход тот, чей сейчас ход.
## Своя стопка сыгранных карт внизу больше не нужна — она была здесь же.
func _refresh_played(view: Dictionary) -> void:
	# Стартовая расстановка: на месте зоны — сам вопрос, а карт ещё нет.
	var setup_pick := _is_starting_pick(view)
	_played_head.visible = not setup_pick
	_played_stack.visible = not setup_pick
	_setup_label.visible = setup_pick
	if setup_pick:
		var pd: Dictionary = view["pending_decision"]
		var who := String(pd.get("player_id", ""))
		_setup_label.text = "%s: %s — click a gold site on the board" % [
			EventLogPanel.player_name(who).to_upper(), String(pd.get("prompt", ""))]
		_setup_label.add_theme_color_override("font_color", EventLogPanel.player_color(who))
		return

	var current := String(view["current_player"])
	var p: Dictionary = (view["players"] as Dictionary).get(current, {})
	_played_title.text = "%s:" % EventLogPanel.player_name(current).to_upper()
	_played_title.add_theme_color_override("font_color", EventLogPanel.player_color(current))
	_played_stack.empty_text = "nothing played yet"
	_played_stack.set_cards(p.get("played_pile", []))
	# Ресурсы хода — в заголовке этой же зоны: тратит их тот, чей ход.
	var power := int(p.get("power", 0))
	var influence := int(p.get("influence", 0))
	# Накручиваем только в пределах одного хода: когда ход перешёл к другому,
	# цифры стали чужими, и накрутка от чужого значения врала бы.
	var same_player := current == _res_player
	_res_power.set_value(power, same_player)
	_res_influence.set_value(influence, same_player)
	_popup_resource_change(current, power, influence)


## Сейчас идёт стартовая расстановка: кто-то выбирает свою первую локацию.
## Метку ставит сам эффект (ChooseStartingSite), а не угадывает интерфейс по
## тексту вопроса.
static func _is_starting_pick(view: Dictionary) -> bool:
	var pd: Dictionary = view.get("pending_decision", {})
	return String(pd.get("tag", "")) == "starting_site"


## Изменилось Power или Influence — над плашкой всплывает «+2» или «-1».
## Считаем только для того, чей ход: плашка показывает именно его ресурсы, а
## при переходе хода цифры меняются не от траты, и всплывать там нечему.
func _popup_resource_change(current: String, power: int, influence: int) -> void:
	# size.x < 10 — экран ещё не разложен (см. _layout), места плашки нет, и
	# цифра всплыла бы в углу за краем.
	if current == _res_player and _res_zone.is_visible_in_tree() and size.x >= 10.0:
		# Цифра всплывает под заголовком, над самими картами: выше него —
		# бараки, и там её не разглядеть.
		var top := _res_zone.global_position - global_position + Vector2(0, PixelTheme.LINE_H)
		if power != _res_power_shown:
			FloatingText.spawn(self, _signed(power - _res_power_shown),
				POWER_COLOR, top)
		if influence != _res_influence_shown:
			FloatingText.spawn(self, _signed(influence - _res_influence_shown),
				INFLUENCE_COLOR, top + Vector2(_res_zone.size.x * 0.5, 0))
	_res_player = current
	_res_power_shown = power
	_res_influence_shown = influence


static func _signed(delta: int) -> String:
	return ("+%d" % delta) if delta > 0 else str(delta)


## Стопки зрителя. Сброс виден только своему игроку (StateView его прячет),
## Внутренний круг открыт всем — здесь показываем всё равно только свой.
func _refresh_piles(view: Dictionary) -> void:
	var me: Dictionary = (view["players"] as Dictionary)[viewer_id]
	_pile_inner.set_cards(me.get("inner_circle", []))
	_pile_discard.set_cards(me.get("discard_pile", []))
	# Сожранные карты — стопка общая для всех, не своя у зрителя.
	_pile_devour.set_cards(view.get("devoured_pile", []))


## Щелчок по стопке — весь её список поверх экрана.
func _open_pile(which: String) -> void:
	var view := StateView.for_player_with_pending(server.state, viewer_id, server.resolver.pending)
	var me: Dictionary = (view["players"] as Dictionary)[viewer_id]
	var who := EventLogPanel.player_name(viewer_id)
	match which:
		"inner":
			_pile_dialog.open_pile("%s — Inner Circle" % who, me.get("inner_circle", []))
		"devour":
			_pile_dialog.open_pile("Devoured cards", view.get("devoured_pile", []))
		_:
			_pile_dialog.open_pile("%s — Discard pile" % who, me.get("discard_pile", []))


func _refresh_actions(view: Dictionary) -> void:
	var legal: Dictionary = view.get("legal", {})
	_end_turn_button.disabled = not bool(legal.get("end_turn", false))
	_style_end_turn(BoardPanel.PLAYER_COLORS.get(viewer_id, Color(0.6, 0.6, 0.6)))
	var show_deploy := bool(legal.get("deploy_for_vp", false))
	if _deploy_vp_button.visible != show_deploy:
		_deploy_vp_button.visible = show_deploy
		_layout()


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
	_fly_to_discard(_market_panel.card_rect(index), _market_panel.card_id_at(index))
	send(Intent.recruit(viewer_id, index))


func _on_supply_clicked(card_id: String) -> void:
	_fly_to_discard(_market_panel.supply_rect(card_id), card_id)
	send(Intent.recruit_supply(viewer_id, card_id))


## Купленная карта улетает в стопку сброса: снимок слота маркета летит по дуге
## к зоне DISCARD и гаснет. Это только показ — саму карту сервер уже положил
## в сброс, и полёт ни на что не влияет.
##
## Летит отдельная копия карты, а не сама карта слота: та в это же мгновение
## уже показывает пришедшую ей на смену.
func _fly_to_discard(from: Rect2, cid: String) -> void:
	if cid == "" or from.size.x < 1.0 or not _pile_discard.visible:
		return
	var to := _pile_discard.get_global_rect().get_center() - from.size * 0.5
	var start := from.position - get_global_position()
	var finish := to - get_global_position()
	if start.distance_to(finish) < 1.0:
		return

	var ghost := CardView.new(cid, int(from.size.x), int(from.size.y))
	ghost.hover_preview = false   # это картинка в полёте, а не карта под курсором
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.set_clickable(false, false)
	ghost.position = start.round()
	ghost.z_index = 6
	add_child(ghost)

	# Дуга: контрольная точка выше прямой, иначе полёт читается как рывок.
	var mid := start.lerp(finish, 0.5) + Vector2(0, -FLIGHT_ARC)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
			var p: Vector2 = start.lerp(mid, t).lerp(mid.lerp(finish, t), t)
			ghost.position = p.round()
			ghost.modulate.a = 1.0 - t * t,
		0.0, 1.0, FLIGHT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(ghost.queue_free)


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
