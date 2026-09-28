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

## Кнопка MAIN MENU в меню по Esc: вернуться к экрану выбора режима
## (его показывает обёртка game_scene.gd).
signal main_menu_requested

## Все цвета, за какие можно сесть, в порядке рассадки: партия на N человек
## берёт первые N. Цвета — те же, что у фишек на доске (BoardPanel.PLAYER_COLORS).
const ALL_PLAYER_IDS: Array[String] = ["red", "blue", "green", "purple"]
const MIN_PLAYERS := 2
const MAX_PLAYERS := 4
## Задник экрана подключён файлом, а не по глобальному имени класса:
## глобальные имена собирает редактор, а проект часто запускается из
## командной строки, где нового имени ещё нет в кэше.
const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")
const TurnBanner := preload("res://scenes/ui/turn_banner.gd")

# Сетка экрана в пикселях расчётного размера 960x540 (пиксель-арт: цифры
# только целые, отступы маленькие). Раскладка по макету владельца
# (2026-09-24): доска слева на всё свободное место (6), под ней прозрачная
# рука (5); справа одна колонка шириной с рынок, сверху вниз:
#   бараки (1), таблица игроков (2), рынок с мелкими картами целиком (3),
#   кнопки высотой с руку (4) — стопки Discard / Inner Circle / Devoured и
#   End turn.
# Слева — сводка ходов, в левом нижнем углу — чат с журналом (2026-09-27).
# Power/Influence ходящего — прозрачной плашкой над рукой.
# Чей сейчас ход, написано на самой кнопке End turn.
const MARGIN := 1.0
const GAP := 2.0
## Полёт купленной карты в стопку сброса: сколько летит и насколько выгнута
## дуга. По прямой полёт читается как рывок.
const FLIGHT_TIME := 0.42
const FLIGHT_ARC := 26.0
## Войска и шпионы вылетают из барака на доску (см. _launch_token):
## выскакивают из барака на TOKEN_HOP пикселей, зависают, потом летят по дуге
## с разгоном и врезаются в место. TOKEN_STAGGER — пауза между фишками одного
## хода (карта может выставить сразу несколько). На посадке войска игра
## замирает на TOKEN_HITSTOP — «стоп-кадр» удара.
const TOKEN_HOP := 8.0
const TOKEN_HOP_TIME := 0.1
const TOKEN_HANG_TIME := 0.07
const TOKEN_FLIGHT_TIME := 0.36
const TOKEN_STAGGER := 0.14
const TOKEN_ARC := 56.0
## До какой доли полёта фишка увеличена вдвое («поднята к камере»).
const TOKEN_BIG_UNTIL := 0.65
const TOKEN_HITSTOP := 0.055
## Насколько трясти доску: убийство и вытеснение — заметно, возврат войска или
## шпиона — чуть.
const SHAKE_KILL := 4.0
const SHAKE_NUDGE := 2.0
## Удар по убитому войску: стоп-кадр чуть длиннее посадки.
const KILL_HITSTOP := 0.08
## Ширина правой колонки — ширина рынка в две мелкие карты; все зоны колонки
## той же ширины (макет владельца, 2026-09-24). Таблица игроков под эту
## ширину — по две строки на игрока (трофеи второй строкой).
const COL := float(MarketPanel.WIDTH)
## Дектрекер — полоса в мелкую карту шириной во всю высоту экрана между
## сводкой ходов и доской (владелец, 2026-09-28). Зона доски — 620, схема 1:1.
const TRACKER_W := float(CardView.MINI_SIZE.x) + 2.0
## Ширина столбика кнопок стопок под рынком; остальное — End turn.
const PILES_W := 80.0
## Высота зоны бараков.
const TOP_H := 22.0
## Высота нижнего ряда: мелкое лицо карты (76) плюс отступы подложки руки.
## Той же высоты кнопки стопок слева и End turn справа.
const BOTTOM_H := 80.0
const TIMER_H := 11.0
const DEPLOY_H := 13.0
## Цвета ресурсов хода — те же, что и на картах.
const POWER_COLOR := Color(0.95, 0.45, 0.35)
const INFLUENCE_COLOR := Color(0.45, 0.75, 0.98)
## Таймер хода: две минуты на старте, по нулю ход завершается сам. Поздние ходы
## длиннее (колода сильнее, карт и вопросов больше), поэтому каждая сыгранная
## карта и каждый вопрос карты ходящему добавляют TURN_BONUS_SECONDS — но не
## выше TURN_MAX_SECONDS (решение владельца игры, «шахматная» добавка).
const TURN_SECONDS := 120.0
const TURN_BONUS_SECONDS := 10.0
const TURN_MAX_SECONDS := 300.0
## Таймер ответа на чужую карту (сбросить карту и т. п.): по нулю ответ
## выбирается сам.
const DECISION_SECONDS := 30.0
## Период пульсации кнопки End turn в свой ход, секунд.
const PULSE_PERIOD := 1.6

## Хотсит: партия живёт прямо здесь. В сетевой партии null — партия у хоста
## в NetSession, а экран знает только свой срез.
var server: GameServer
## Сетевая партия: через неё уходят намерения и чат. null — хотсит.
var net: NetSession
## Последний полученный срез — всё, что экран знает о партии.
var _view: Dictionary = {}
## Кто сидит за экраном, в порядке рассадки. Очередь хода — отдельно: её
## перемешивает GameSetup, чтобы первый ходящий выбирался случайно.
var player_ids: Array[String] = ALL_PLAYER_IDS.slice(0, MIN_PLAYERS)
var viewer_id: String = "red"
var board_data: Dictionary = {}

var _barracks: BarracksBar
var _players_panel: PlayersPanel
var _hand_panel: HandPanel
var _showcase: CardShowcase
var _turn_banner: TurnBanner
## Для кого баннер хода уже показан и на какой вопрос уже мигали в панели
## задач — чтобы не повторять на каждом обновлении среза.
var _banner_player := ""
var _attention_key := ""
## Цвет кнопки End turn и фаза её пульсации, пока ход свой.
var _end_turn_colour := Color(0.6, 0.6, 0.6)
var _pulse_time := 0.0
## Ход заканчивается удержанием пробела SPACE_HOLD_SECONDS секунд; пока пробел
## зажат, кнопку End turn слева направо заливает полоса _space_fill.
const SPACE_HOLD_SECONDS := 3.0
var _space_held := false
var _space_hold := 0.0
var _space_fill: ColorRect
var _feed: TurnFeed
var _market_panel: MarketPanel
var _note_toast: NoteToast
var _board_panel: BoardPanel
var _board_area: Control
var _decision_dialog: DecisionDialog
var _res_frame: PanelContainer
var _res_zone: HBoxContainer
var _res_title: Label
var _res_power: CounterLabel
var _res_influence: CounterLabel
## Что на плашке ресурсов было показано в прошлый раз и чьё оно — по этому
## считается, на сколько всплыть цифре изменения.
var _res_player := ""
var _res_power_shown := 0
var _res_influence_shown := 0
var _piles_column: VBoxContainer
var _pile_inner: PileZone
## Колода и сброс зрителя лесенкой по цене (вместо кнопки DISCARD).
var _deck_tracker: DeckTracker
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
var _pause_menu: PauseMenu
var _game_over_panel: GameOverPanel
## Связь оборвалась (только сетевая партия): кнопка вручную повторить попытку.
var _reconnect_banner: PanelContainer
var _reconnect_status: Label
## Пауза сетевой партии: последняя пауза от сервера (NetSession.pause_changed),
## сколько секунд прошло с её прихода, и плашка с затемнением.
var _pause: Dictionary = {}
var _pause_elapsed := 0.0
var _pause_overlay: Control
var _pause_lines: VBoxContainer
var _pause_hint: Label
var _pause_resume: Button

## Таймер хода: сколько секунд осталось и чей ход сейчас отсчитываем — смена
## ходящего перезапускает отсчёт.
var _time_left := TURN_SECONDS
var _timed_player := ""
## Для добавки времени: сколько карт ходящего уже учтено в played_pile и какой
## его вопрос карты уже учтён.
var _timed_played := 0
var _timed_question := ""
var _auto_ending := false
## Таймер ответа: какой вопрос отсчитываем (смена вопроса перезапускает) и
## сколько секунд на него осталось.
var _decision_key := ""
var _decision_left := DECISION_SECONDS
var _auto_answered := false


## Какие цвета раздать на партию из count человек.
static func player_ids_for(count: int) -> Array[String]:
	var ids: Array[String] = ALL_PLAYER_IDS.slice(0, clampi(count, MIN_PLAYERS, MAX_PLAYERS))
	return ids


## online — сетевая партия: {session, seat, board, view} из NetSession.game_started.
## Пустой — хотсит, партию собирает сам экран.
func _init(game_seed: int = 0, half_decks: Array[String] = [], ids: Array[String] = [],
		mode: String = GameSetup.MODE_STANDARD, online: Dictionary = {}) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()
	if not online.is_empty():
		net = online["session"]
		viewer_id = String(online["seat"])
		board_data = online["board"]
		net.result_received.connect(_on_result)
		net.player_left.connect(func(who: String):
			_note("%s has disconnected." % EventLogPanel.player_name(who)))
		net.player_rejoined.connect(func(who: String):
			_note("%s is back." % EventLogPanel.player_name(who)))
		net.connection_lost.connect(func(reason: String):
			_note(reason + ".")
			_reconnect_banner.visible = true
			_reconnect_status.text = reason + ".")
		net.rating_changed.connect(func(result: Dictionary): _game_over_panel.set_ratings(result))
		net.pause_changed.connect(_on_pause_changed)
		_build_layout()
		refresh(online["view"])
		_on_pause_changed(net.pause_status)
		_note("Online game started. You play %s." % EventLogPanel.player_name(viewer_id))
		return
	if ids.size() >= MIN_PLAYERS:
		player_ids = ids.duplicate()
	var state := GameSetup.new_game(player_ids, game_seed, half_decks, false, true, true, mode)
	server = GameServer.new(state)
	board_data = StateView.board_snapshot(state)
	viewer_id = server.resolver.pending.player_id if server.resolver.is_waiting() else state.current_player()
	_build_layout()
	refresh(StateView.for_player_with_pending(server.state, viewer_id, server.resolver.pending))


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

	# 2. Расклад по игрокам — под бараками. Пока раздают стартовые локации,
	# под таблицей стоит вопрос «выбери стартовую локацию» (решение владельца,
	# 2026-09-20): плашка над доской закрывала как раз те локации, по которым
	# надо щёлкнуть.
	_players_panel = PlayersPanel.new()
	_players_panel.player_chosen.connect(_on_decision_answer)
	_players_panel.trophy_chosen.connect(_on_decision_answer)
	add_child(_players_panel)

	# 4. Доска лежит в простом Control, чтобы поверх неё (а не поверх маркета)
	# можно было повесить диалог решения и подсказку.
	_board_area = Control.new()
	add_child(_board_area)

	_board_panel = BoardPanel.new()
	_board_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board_panel.slot_clicked.connect(_on_slot_clicked)
	_board_panel.site_clicked.connect(_on_site_clicked)
	_board_panel.spy_clicked.connect(_on_spy_clicked)
	_board_panel.kill_struck.connect(_on_kill_struck)
	_board_area.add_child(_board_panel)

	_decision_dialog = DecisionDialog.new()
	_decision_dialog.board = board_data  # чтобы подписывать цели названиями локаций
	_decision_dialog.option_chosen.connect(_on_decision_answer)
	_board_area.add_child(_decision_dialog)

	# 6. Маркет.
	_market_panel = MarketPanel.new()
	_market_panel.market_card_clicked.connect(_on_market_clicked)
	_market_panel.supply_card_clicked.connect(_on_supply_clicked)
	_market_panel.choice_clicked.connect(_on_decision_answer)
	add_child(_market_panel)

	# Колода и сброс — дектрекер слева от рынка.
	_deck_tracker = DeckTracker.new()
	add_child(_deck_tracker)

	# 3. Стопки кнопками одна под другой под рынком: свой Внутренний круг и
	# общая для всех стопка сожранных карт (из неё же берётся «призрак»,
	# Ghost). По щелчку — весь список карт стопки.
	_piles_column = VBoxContainer.new()
	_piles_column.add_theme_constant_override("separation", int(GAP))
	add_child(_piles_column)
	_pile_inner = PileZone.new("INNER")
	_pile_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pile_inner.clicked.connect(func(): _open_pile("inner"))
	_piles_column.add_child(_pile_inner)
	_pile_devour = PileZone.new("DEVOUR")
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
	# Без фокуса: иначе после щелчка пробел жал бы кнопку сразу, мимо удержания.
	_end_turn_button.focus_mode = Control.FOCUS_NONE
	_end_turn_button.tooltip_text = "Click, or hold Space for 3 seconds, to end the turn"
	_end_turn_area.add_child(_end_turn_button)
	_space_fill = ColorRect.new()
	_space_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_space_fill.color = Color(1.0, 0.95, 0.7, 0.35)
	_space_fill.size = Vector2.ZERO
	_end_turn_area.add_child(_space_fill)
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
	_hand_panel.choice_clicked.connect(_on_decision_answer)
	add_child(_hand_panel)

	# 1b. Над рукой — чей ход и его Power/Influence (решение владельца,
	# 2026-09-27). Рамка прозрачная и лежит поверх низа доски, чтобы доску не
	# пришлось ужимать. Под поднятой картой руки: та рисуется выше.
	_res_zone = HBoxContainer.new()
	_res_zone.add_theme_constant_override("separation", 12)
	_res_zone.tooltip_text = "Power and Influence of the player to move"
	_res_zone.mouse_filter = Control.MOUSE_FILTER_STOP  # чтобы работала подсказка
	_res_frame = PanelContainer.new()
	var no_frame := StyleBoxEmpty.new()
	no_frame.set_content_margin_all(1)
	_res_frame.add_theme_stylebox_override("panel", no_frame)
	_res_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_res_frame.add_child(_res_zone)
	add_child(_res_frame)
	_res_title = Label.new()
	_res_zone.add_child(_res_title)
	_res_power = CounterLabel.make("POWER %d", POWER_COLOR)
	_res_zone.add_child(_res_power)
	_res_influence = CounterLabel.make("INFLUENCE %d", INFLUENCE_COLOR)
	_res_zone.add_child(_res_influence)
	# Крупно — вдвое, целым масштабом шрифта; обводка — чтобы читалось на доске.
	for label: Label in [_res_title, _res_power, _res_influence]:
		label.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
		label.add_theme_color_override("font_outline_color", PixelTheme.BG)
		label.add_theme_constant_override("outline_size", 2)

	# Витрина: крупный показ чужих покупок, промоутов и съеденных карт — поверх
	# доски и руки, но под диалогами (999+) и крупным просмотром карты.
	_showcase = CardShowcase.new()
	_showcase.board_area = _board_area
	_showcase.set_anchors_preset(Control.PRESET_FULL_RECT)
	_showcase.z_index = 950
	add_child(_showcase)
	_showcase.finished.connect(func():
		if not _view.is_empty():
			_show_decision(_view))
	_turn_banner = TurnBanner.new()
	add_child(_turn_banner)

	# Сводка ходов — постоянная колонка у левого края, слева от доски.
	_feed = TurnFeed.new()
	# Наведение на строку действия сводки — доска зажигает, где это было.
	_feed.places_hovered.connect(func(places: Array) -> void: _board_panel.show_places(places))
	add_child(_feed)

	# Список карт стопки — поверх экрана, но под увеличенной копией карты.
	_pile_dialog = PileDialog.new()
	add_child(_pile_dialog)

	# Чата и журнала больше нет (решение владельца, 2026-09-27): ход виден в
	# сводке слева, а подсказки и отказы («не та цель», «время вышло») —
	# всплывающей строкой над счётчиками Power/Influence.
	_note_toast = NoteToast.new()
	_note_toast.area = _board_area
	_note_toast.above = _res_frame
	add_child(_note_toast)

	# Увеличенная копия карты под курсором (с зажатым Alt) — над всем экраном.
	_preview = CardPreview.new()
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_preview)

	# Пауза сетевой партии: затемнение (щелчки до игры не доходят) и плашка —
	# кого ждём и сколько. Раньше меню по Esc в дереве: оно должно оставаться
	# доступным и во время паузы.
	_build_pause_overlay()

	# Меню по Esc: главное меню или выход из игры; в сети — ещё и общая пауза.
	_pause_menu = PauseMenu.new()
	_pause_menu.main_menu_requested.connect(func(): main_menu_requested.emit())
	if net != null:
		_pause_menu.add_button("PAUSE FOR ALL", func():
			_pause_menu.visible = false
			net.request_pause(true))
	add_child(_pause_menu)

	# Связь оборвалась (этап 7): заметная плашка сверху с кнопкой переподключения.
	# Скрыта, пока не пришёл net.connection_lost; хотсит её не показывает вовсе.
	_reconnect_banner = PanelContainer.new()
	_reconnect_banner.add_theme_stylebox_override("panel", zone_style(4))
	_reconnect_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_reconnect_banner.position.y = 30
	_reconnect_banner.z_index = 1200
	_reconnect_banner.visible = false
	var reconnect_row := HBoxContainer.new()
	reconnect_row.add_theme_constant_override("separation", 6)
	_reconnect_banner.add_child(reconnect_row)
	_reconnect_status = Label.new()
	_reconnect_status.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	reconnect_row.add_child(_reconnect_status)
	var reconnect_button := Button.new()
	reconnect_button.text = "RECONNECT"
	reconnect_button.custom_minimum_size = Vector2(90, 16)
	SetupScreen._style_button(reconnect_button)
	reconnect_button.pressed.connect(func():
		_reconnect_status.text = "Reconnecting..."
		if net.reconnect() != OK:
			_reconnect_status.text = "Could not reconnect.")
	reconnect_row.add_child(reconnect_button)
	add_child(_reconnect_banner)

	# Итоги партии — открываются сами после GAME OVER.
	_game_over_panel = GameOverPanel.new()
	_game_over_panel.main_menu_requested.connect(func(): main_menu_requested.emit())
	add_child(_game_over_panel)

	_layout()


func _build_pause_overlay() -> void:
	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Над картами, баннером хода и подсказками, под итогами и меню по Esc.
	_pause_overlay.z_index = 1040
	_pause_overlay.visible = false
	var dim := ColorRect.new()
	dim.color = PixelTheme.DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(dim)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(centre)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", zone_style(6))
	centre.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var title := Label.new()
	title.text = "GAME PAUSED"
	title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_pause_lines = VBoxContainer.new()
	_pause_lines.add_theme_constant_override("separation", 2)
	col.add_child(_pause_lines)
	_pause_hint = Label.new()
	_pause_hint.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	_pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_pause_hint)
	_pause_resume = Button.new()
	_pause_resume.text = "RESUME"
	_pause_resume.custom_minimum_size = Vector2(90, 16)
	_pause_resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	SetupScreen._style_button(_pause_resume)
	_pause_resume.pressed.connect(func(): net.request_pause(false))
	col.add_child(_pause_resume)
	add_child(_pause_overlay)


## Новая пауза от сервера (NetSession.pause_changed): кто отключился, кто
## поставил общую паузу. Отсчёт дальше тикает здесь же, в _tick_pause.
func _on_pause_changed(status: Dictionary) -> void:
	var was_paused := is_paused()
	_pause = status.duplicate(true)
	_pause_elapsed = 0.0
	var paused := is_paused()
	if paused and not was_paused and is_inside_tree():
		_request_attention()
	elif was_paused and not paused and not bool(_view.get("game_over", false)):
		_note("The game goes on.")
	_rebuild_pause_lines()
	_tick_pause(0.0)


## Сетевая партия стоит: кто-то отключился или поставил общую паузу.
func is_paused() -> bool:
	if net == null or _pause.is_empty() or bool(_view.get("game_over", false)):
		return false
	return not (_pause.get("absent", {}) as Dictionary).is_empty() or String(_pause.get("by", "")) != ""


## Строки плашки: по одной на отключившегося и на общую паузу. Счёт времени
## в них обновляет _tick_pause.
func _rebuild_pause_lines() -> void:
	for child in _pause_lines.get_children():
		_pause_lines.remove_child(child)
		child.queue_free()
	var absent: Dictionary = _pause.get("absent", {})
	for pid: String in absent:
		_pause_lines.add_child(_pause_line(pid, "%s DISCONNECTED" % EventLogPanel.player_name(pid).to_upper()))
	var by := String(_pause.get("by", ""))
	if by != "":
		var who := "YOU" if by == viewer_id else EventLogPanel.player_name(by).to_upper()
		_pause_lines.add_child(_pause_line(by, "PAUSED BY %s" % who))
	_pause_hint.text = "If they do not return in time, the game ends with the current score.\nRating does not change." \
		if not absent.is_empty() else "The game goes on by itself when the time is up."
	_pause_resume.visible = by == viewer_id and absent.is_empty()


func _pause_line(pid: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var name_label := Label.new()
	name_label.text = text
	name_label.add_theme_color_override("font_color", EventLogPanel.player_color(pid))
	row.add_child(name_label)
	var time_label := Label.new()
	time_label.add_theme_color_override("font_color", PixelTheme.TEXT)
	row.add_child(time_label)
	return row


## Плашка паузы видна, пока партия стоит; время в строках убывает.
func _tick_pause(delta: float) -> void:
	var paused := is_paused()
	_pause_overlay.visible = paused
	if not paused:
		return
	_pause_elapsed += delta
	var lefts: Array[float] = []
	var absent: Dictionary = _pause.get("absent", {})
	for pid: String in absent:
		lefts.append(float(absent[pid]))
	if String(_pause.get("by", "")) != "":
		lefts.append(float(_pause.get("left", 0.0)))
	var rows := _pause_lines.get_children()
	for i in mini(rows.size(), lefts.size()):
		var left := int(ceilf(maxf(0.0, lefts[i] - _pause_elapsed)))
		((rows[i] as HBoxContainer).get_child(1) as Label).text = "%d:%02d" % [left / 60, left % 60]


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


## Пока End turn доступна (ход свой), кнопка мягко пульсирует в цвет игрока:
## фон и рамка светлеют и темнеют четырьмя ступенями — по-пиксельному, без
## плавного перелива. Недоступная кнопка серая и не пульсирует.
func _pulse_end_turn(delta: float) -> void:
	if _end_turn_button.disabled:
		_pulse_time = 0.0
		return
	_pulse_time += delta
	var wave := (sin(_pulse_time * TAU / PULSE_PERIOD) + 1.0) * 0.5
	var step := floorf(wave * 3.99) / 3.0
	_end_turn_style.bg_color = _end_turn_colour.darkened(0.45 - 0.25 * step)
	_end_turn_style.border_color = Color(0.92, 0.75, 0.35).lerp(Color(1.0, 0.95, 0.7), step)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _board_area != null:
		_layout()


## Esc из строки чата снимает с неё фокус. Tab глотаем целиком: иначе он
## уводит фокус по кнопкам интерфейса. Пока печатают в чат, буквенные
## клавиши игры не срабатывают.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null:
		return
	# Отпускание пробела сбрасывает удержание при любом состоянии экрана.
	if key.keycode == KEY_SPACE and not key.pressed:
		_space_held = false
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	if _pause_menu.visible:
		# Под меню паузы клавиши до игры не доходят; Esc его закрывает.
		if key.keycode == KEY_ESCAPE and key.pressed and not key.echo:
			_pause_menu.visible = false
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
	elif typing:
		if key.keycode == KEY_ESCAPE and key.pressed:
			get_viewport().gui_get_focus_owner().release_focus()
			get_viewport().set_input_as_handled()
	elif key.keycode == KEY_SPACE:
		# Пробел глотаем целиком, чтобы он не жал кнопку в фокусе; сам конец
		# хода — в _tick_space_hold, после 3 секунд удержания.
		if key.pressed and not key.echo:
			_space_held = true
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_B and key.pressed and not key.echo:
		# Stage 0 фонового арта гексов (PixelLab) — временная клавиша, пока
		# владелец не решил, входит ли это в игру насовсем.
		_board_panel.set_art_layer(not _board_panel.art_layer)
	elif key.keycode == KEY_O and key.pressed and not key.echo:
		# Тематические объекты на 5 плитках (PixelLab) — временная клавиша,
		# пока владелец не решил, входит ли это в игру насовсем.
		_board_panel.set_object_layer(not _board_panel.object_layer)


## Esc открывает меню паузы. Через unhandled — чтобы сперва свой Esc получили
## окна поменьше (список карт стопки закрывается им).
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key.keycode == KEY_ESCAPE and key.pressed and not key.echo:
		# После конца партии Esc возвращает спрятанные итоги (VIEW BOARD).
		if bool(_view.get("game_over", false)) and not _game_over_panel.visible:
			_game_over_panel.visible = true
		else:
			_pause_menu.visible = true
		get_viewport().set_input_as_handled()


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
	var top_y := MARGIN
	var bottom_y := h - MARGIN - BOTTOM_H

	# Правая колонка: бараки, таблица игроков, под ней рынок, под рынком
	# кнопки. Рынок ровно своего размера (карты целиком), таблице — всё, что
	# осталось.
	_place(_barracks, d_x, top_y, COL, TOP_H)
	var market_h := _market_panel.get_combined_minimum_size().y
	var market_y := bottom_y - GAP - market_h
	var market_x := d_x
	_place(_market_panel, market_x, market_y, MarketPanel.WIDTH, market_h)
	var players_y := top_y + TOP_H + GAP
	_place(_players_panel, d_x, players_y, COL, market_y - GAP - players_y)
	_place(_piles_column, market_x, bottom_y, PILES_W, BOTTOM_H)
	var ew := MarketPanel.WIDTH - PILES_W - GAP
	_place(_end_turn_area, market_x + PILES_W + GAP, bottom_y, ew, BOTTOM_H)

	# Слева — сводка ходов во всю высоту экрана (решение владельца,
	# 2026-09-27: чат убран, сводка — до низа), за ней дектрекер тоже во всю
	# высоту; доска — всё между ним и правой колонкой, от верха экрана до руки.
	# Ширины сводки доске не жалко: масштаб схемы от неё не падает ни на
	# двоих, ни на четверых.
	var board_h := bottom_y - GAP - top_y
	_place(_feed, a_x, top_y, TurnFeed.WIDTH, h - MARGIN - top_y)
	var tracker_x := a_x + TurnFeed.WIDTH + GAP
	_place(_deck_tracker, tracker_x, top_y, TRACKER_W, h - MARGIN - top_y)
	var board_x := tracker_x + TRACKER_W + GAP
	_place(_board_area, board_x, top_y, d_x - GAP - board_x, board_h)

	# Рука — под доской, без подложки; запас сверху нужен карте под
	# курсором — она выдвигается выше края ряда.
	var hand_x := board_x
	var hand_top := bottom_y - HandPanel.HOVER_LIFT - 2.0
	_place(_hand_panel, hand_x, hand_top, d_x - GAP - hand_x, h - MARGIN - hand_top)
	_place_res_frame()

	# Внутри зоны End turn: сверху Deploy (когда он есть), снизу таймер, а
	# кнопка растянута на всё, что между ними. Подписи «чей ход» и «END TURN»
	# лежат по центру кнопки.
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


## Счётчики ходящего — по центру над рукой, поверх низа доски. Низ плашки —
## на верхнем краю зоны руки: выше него поднятая карта уже не достаёт.
func _place_res_frame() -> void:
	var res_size := _res_frame.get_combined_minimum_size()
	var x := _hand_panel.position.x + floorf((_hand_panel.size.x - res_size.x) * 0.5)
	_place(_res_frame, x, _hand_panel.position.y - res_size.y, res_size.x, res_size.y)


static func _place(control: Control, x: float, y: float, width: float, height: float) -> void:
	control.position = Vector2(x, y).round()
	control.size = Vector2(width, height).round()


# --- отправка намерений ------------------------------------------------------

## Всё, что делает интерфейс, проходит здесь. Ошибку сервера показываем в
## журнале, а не глотаем: если UI предложил недопустимое действие, это его
## баг, и он должен быть виден.
func send(intent: Intent) -> void:
	if net != null:
		# Ответ придёт позже сигналом result_received -> _on_result.
		net.send_intent(intent)
		return
	var result: Dictionary = server.apply_intent(intent)

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
	_on_result(int(result["error"]), result["events"], view)


## Подсказка или отказ — всплывающей строкой над счётчиками Power/Influence.
func _note(text: String) -> void:
	_note_toast.show_note(text)


## Ответ сервера — свой или пришедший по сети: перерисовка, сводка, тряска.
func _on_result(err: int, events: Array, view: Dictionary) -> void:
	if err != GameServer.Error.OK:
		_note("Not allowed: %s" % _error_name(err))
	refresh(view)
	_react_to_events(events)
	# Витрина (крупный показ повышенной, купленной, съеденной карты) запускается
	# событиями — уже после refresh. Вопрос ждёт конца показа: иначе два
	# затемнения складываются в чёрный экран, а карту витрины закрывает окно.
	if _showcase.is_busy():
		_decision_dialog.visible = false


## Окно вопроса по виду (или скрыть его). Пока идёт витрина — скрыто, его
## покажет сигнал CardShowcase.finished.
func _show_decision(view: Dictionary) -> void:
	_decision_dialog.update_from_view(view, viewer_id)
	if _showcase.is_busy():
		_decision_dialog.visible = false


## Чем громче событие на доске, тем сильнее её тряхнёт. Захват локации доска
## замечает сама (по смене владельца), а здесь — то, чего в расстановке войск
## не видно: убийство, вытеснение, возврат чужого войска или шпиона.
##
## Заодно здесь запускаются полёты фишек: из барака на доску (деплой,
## шпион), с места на место (move) и с доски обратно в барак (return).
## Фишки одного ответа сервера летят друг за другом (launched).
func _react_to_events(events: Array) -> void:
	var power := 0.0
	var launched := 0
	var kills := 0
	# Изгои, выданные подряд одной картой: один показ на всех.
	var outcasts: Array[Dictionary] = []
	for e in events:
		var evt: Dictionary = e
		var pid := String(evt.get("player_id", ""))
		var started := false
		if String(evt.get("type", "")) != "give_insane_outcast" and not outcasts.is_empty():
			_showcase_outcasts(outcasts)
			outcasts = []
		match String(evt.get("type", "")):
			# "deploy" — действие за мечи (Power), "deploy_troop" — деплой картой.
			"deploy", "deploy_troop":
				# С "color" — войско взято из зала трофеев, а не из барака.
				started = not evt.has("color") \
					and _launch_troop(pid, String(evt.get("slot_id", "")), launched)
			"choose_starting_site":
				var slot_id := _board_panel.troop_slot_of(String(evt.get("site_id", "")), pid)
				started = _launch_troop(pid, slot_id, launched)
			"place_spy":
				started = _launch_spy(pid, String(evt.get("site_id", "")), launched)
			"move_troop":
				started = _move_troop(String(evt.get("owner", "")), String(evt.get("from", "")),
					String(evt.get("to", "")), launched)
			# Раскол (assassinate) или омут (supplant) прямо на месте — всё
			# рисует доска, см. BoardPanel.kill_at. Убийства — по очереди.
			"assassinate", "supplant":
				var supplant := String(evt.get("type", "")) == "supplant"
				if _board_panel.kill_at(String(evt.get("slot_id", "")), String(evt.get("victim", "")),
						pid, supplant, BoardPanel.KILL_STEP * kills):
					kills += 1
				else:
					power = maxf(power, SHAKE_KILL)
			"return_troop":
				power = maxf(power, SHAKE_NUDGE)
				started = _return_troop(String(evt.get("owner", "")),
					String(evt.get("slot_id", "")), launched)
			"return_spy":
				power = maxf(power, SHAKE_NUDGE)
				started = _return_spy(String(evt.get("owner", "")),
					String(evt.get("site_id", "")), launched)
			"return_own_spy":
				power = maxf(power, SHAKE_NUDGE)
				started = _return_spy(pid, String(evt.get("site_id", "")), launched)
			# Свою покупку щелчком игрок и так видит (карта летит в сброс),
			# чужую — только витриной.
			"recruit":
				if pid != viewer_id:
					_showcase_card(pid, String(evt.get("card_id", "")), "RECRUITS",
						_market_panel.card_rect(int(evt.get("market_index", -1))), "barracks")
			"recruit_supply":
				if pid != viewer_id:
					var cid := String(evt.get("card_id", ""))
					_showcase_card(pid, cid, "RECRUITS", _market_panel.supply_rect(cid), "barracks")
			"recruit_free":
				_showcase_card(pid, String(evt.get("card_id", "")), "RECRUITS",
					_market_panel.card_rect(int(evt.get("market_index", -1))), "discard")
			# «... recruits an Insane Outcast»: изгоя навязали эффектом карты,
			# получатель сам его не брал — показываем всем, включая его самого.
			# Выдачи одной карты (идут подряд) собираются в один показ.
			"give_insane_outcast":
				outcasts.append(evt)
			"promote":
				_showcase_card(pid, String(evt.get("card_id", "")), "PROMOTES", null, "inner",
					String(evt.get("from", "")) == "top_of_deck")
			"devour":
				# Свою карту из руки или из игры игрок съел сам и знает об этом.
				if pid != viewer_id or String(evt.get("source", "")) == "market":
					_showcase_card(pid, String(evt.get("card_id", "")), "DEVOURS", null, "")
		if started:
			launched += 1
	if not outcasts.is_empty():
		_showcase_outcasts(outcasts)
	if power > 0.0:
		_board_panel.shake(power)
	_note_recap(events)


## Один показ на все изгои одной карты (решение владельца, 2026-09-27:
## девять одинаковых показов подряд после Ghoul и Demogorgon — затянуто):
## ряд крупных изгоев, по одному на получателя, над каждым плашка его цвета
## «RED RECRUITS ×2», потом каждая копия улетает к своему получателю. Ряд
## идёт в порядке бараков слева направо, чтобы копии не летели крест-накрест.
func _showcase_outcasts(gives: Array[Dictionary]) -> void:
	var slots: Array[Dictionary] = []
	for evt in gives:
		var pid := String(evt.get("player_id", ""))
		var count := int(evt.get("count", 1))
		slots.append({
			"text": EventLogPanel.player_name(pid).to_upper() + " RECRUITS" \
				+ (" ×%d" % count if count > 1 else ""),
			"colour": BoardPanel.PLAYER_COLORS.get(pid, PixelTheme.GOLD),
			"to": _showcase_target(pid, "discard"),
		})
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["to"] as Vector2).x < (b["to"] as Vector2).x)
	_showcase.show_row(Supplies.INSANE_OUTCAST, slots)


## Подписи сводки хода для событий, которые в неё попадают.
const RECAP_TAGS := {
	"recruit": "BOUGHT", "recruit_supply": "BOUGHT", "recruit_free": "BOUGHT",
	"promote": "PROMOTED", "devour": "DEVOURED",
}


## Пополняет сводку ходов (колонку слева) сыгранными картами, покупками,
## промоутами и devour всех игроков; конец хода начинает в ней новый блок.
func _note_recap(events: Array) -> void:
	for e in events:
		var evt: Dictionary = e
		var type := String(evt.get("type", ""))
		if RECAP_TAGS.has(type):
			var pid := String(evt.get("player_id", ""))
			var cid := String(evt.get("card_id", ""))
			if pid != "" and cid != "":
				_feed.add(pid, cid, RECAP_TAGS[type])
		elif type == "play_card":
			_feed.add_played(String(evt.get("player_id", "")), String(evt.get("card_id", "")))
		elif type == "discard" or type == "force_discard":
			_feed.add_discard(String(evt.get("player_id", "")), String(evt.get("card_id", "")))
		elif type == "give_insane_outcast":
			# «... recruits an Insane Outcast»: карта изгоя столько раз,
			# сколько выдано, в блок ходящего; подпись цвета получившего.
			for i in range(int(evt.get("count", 1))):
				_feed.add_to_turn(String(evt.get("player_id", "")), Supplies.INSANE_OUTCAST, "OUTCAST")
		elif type == "removed_to_supply":
			# Изгой вместо devour/promote вернулся в запас — своя группа.
			_feed.add_to_turn(String(evt.get("player_id", "")), String(evt.get("card_id", "")), "TO SUPPLY")
		elif type == "turn_ended":
			_feed.end_turn()
		elif type == "turn_income":
			var who := String(evt.get("player_id", ""))
			_feed.add_stat(who, "mark_influence", int(evt.get("marker_influence", 0)), "",
				_site_places(evt.get("marker_site_ids", [])))
			_feed.add_stat(who, "a2_power", int(evt.get("a2_power", 0)), "", _a2_places())
			_feed.add_stat(who, "a2_influence", int(evt.get("a2_influence", 0)), "", _a2_places())
		elif type == "vp_income":
			# VP бонуса A2 и маркеров — своими строками. Банк VP мог выдать
			# меньше просимого: тогда сперва A2, потом маркеры.
			var who_vp := String(evt.get("player_id", ""))
			var granted := int(evt.get("granted", 0))
			var a2_vp := mini(int(evt.get("cluster_bonus", 0)), granted)
			var mark_vp := mini(int(evt.get("markers", 0)), granted - a2_vp)
			_feed.add_stat(who_vp, "a2_vp", a2_vp, "", _a2_places())
			_feed.add_stat(who_vp, "mark_vp", mark_vp, "", _site_places(evt.get("marker_site_ids", [])))
			_feed.add_stat(who_vp, "vp", granted - a2_vp - mark_vp)
		elif RECAP_STATS.has(type):
			var stat: Array = RECAP_STATS[type]
			var amount := 1
			if stat[0] == "vp":
				amount = int(evt.get("granted", evt.get("amount", 0)))
				if type == "gain_per_n" and String(evt.get("resource", "")) != "vp":
					continue
			# Возврат шпиона эффектом карты пишет хозяина в "owner".
			var mark := String(evt.get(stat[1], evt.get("owner", ""))) if stat[1] != "" else ""
			_feed.add_stat(String(evt.get("player_id", "")), stat[0], amount, mark,
				_event_places(evt))


## Три города бонуса A2 как места доски ("site:<id>") — строки A2 в сводке
## подсвечивают их. Пусто, если гекса A2 нет.
func _a2_places() -> Array:
	var places: Array = []
	var sites: Dictionary = board_data.get("sites", {})
	for site_id: String in sites:
		if ClusterBonus.SITE_NAMES.has(String((sites[site_id] as Dictionary).get("name", ""))):
			places.append("site:" + site_id)
	return places


## Локации по id как места доски ("site:<id>").
static func _site_places(site_ids: Array) -> Array:
	var places: Array = []
	for site_id in site_ids:
		places.append("site:" + String(site_id))
	return places


## Где на доске было действие evt — для подсветки при наведении на строку
## сводки (см. BoardPanel.show_places).
static func _event_places(evt: Dictionary) -> Array:
	var places: Array = []
	match String(evt.get("type", "")):
		"deploy", "deploy_troop", "return_troop":
			places.append("slot:" + String(evt.get("slot_id", "")))
		"assassinate":
			places.append("kill:" + String(evt.get("slot_id", "")))
		"supplant":
			places.append("supplant:" + String(evt.get("slot_id", "")))
		"move_troop":
			places.append("slot:" + String(evt.get("from", "")))
			places.append("slot:" + String(evt.get("to", "")))
		"place_spy", "return_spy", "return_own_spy":
			places.append("site:" + String(evt.get("site_id", "")))
	return places.filter(func(p: String) -> bool: return not p.ends_with(":"))


## Строки действий сводки: тип события -> [ключ TurnFeed.STATS, поле события
## с цветом квадратика ("" — без квадратика)].
const RECAP_STATS := {
	"deploy": ["deploy", ""], "deploy_troop": ["deploy", ""],
	"move_troop": ["move", ""],
	"assassinate": ["kill", "victim"], "supplant": ["supplant", "victim"],
	"return_troop": ["return", "owner"],
	"place_spy": ["spy", ""],
	"return_spy": ["spy_back", "spy_owner"], "return_own_spy": ["spy_back", "player_id"],
	"take_trophy": ["trophy", ""],
	"gain_vp": ["vp", ""], "gain_per_n": ["vp", ""],
}


## Крупный показ карты cid, которую взял pid (см. CardShowcase).
##   from — прямоугольник, откуда карта прилетает (глобальный), или null;
##   dest — куда улетает: "barracks" (к игроку), "discard", "inner" (для
##          зрителя — в его стопку, для соперника — в его барак) или "" —
##          рассыпается (съедена).
func _showcase_card(pid: String, cid: String, verb: String, from: Variant, dest: String,
		face_down: bool = false) -> void:
	if cid == "":
		return
	var start: Variant = null
	if from != null and (from as Rect2).size.x >= 1.0:
		start = (from as Rect2).get_center() - get_global_position()
	var to: Variant = _showcase_target(pid, dest) if dest != "" else null
	var colour: Color = BoardPanel.PLAYER_COLORS.get(pid, PixelTheme.GOLD)
	_showcase.show_card(cid, "%s %s" % [EventLogPanel.player_name(pid).to_upper(), verb],
		colour, start, to, face_down, PlayerProfile.back_of(pid))


## Куда улетает карта витрины, взятая pid: для зрителя — в его стопку
## ("discard" / "inner"), для соперника — в его барак.
func _showcase_target(pid: String, dest: String) -> Vector2:
	if pid == viewer_id and dest == "discard":
		return _deck_tracker.discard_rect().get_center() - get_global_position()
	if pid == viewer_id and dest == "inner" and _pile_inner.visible:
		return _pile_inner.get_global_rect().get_center() - get_global_position()
	var at: Variant = _barracks_at(pid)
	return at if at != null else Vector2(size.x * 0.5, -CardView.MINI_SIZE.y)


## Фишка войска owner — такая же, как на доске.
func _troop_token(owner: String) -> FlyingToken:
	var token := FlyingToken.new()
	token.texture = _board_panel.troop_token(owner)
	token.texture_zoom = _board_panel.token_zoom()
	token.colour = BoardPanel.troop_colour(owner)
	token.half = _board_panel.troop_radius()
	return token


func _spy_token(owner: String) -> FlyingToken:
	var token := FlyingToken.new()
	token.spy = true
	token.colour = BoardPanel.troop_colour(owner)
	token.half = _board_panel.spy_half()
	return token


## Середина прямоугольника барака pid в координатах экрана или null.
func _barracks_at(pid: String) -> Variant:
	var at: Variant = _barracks.box_global_centre(pid)
	return (at as Vector2) - get_global_position() if at != null else null


## Глобальная точка доски (или null) в координатах экрана.
func _board_at(global: Variant) -> Variant:
	return (global as Vector2) - get_global_position() if global != null else null


## Войско pid вылетает из его барака в место slot_id. Состояние уже
## применено — войско на доске стоит, доска лишь прячет его до конца полёта.
## Если к этому виду место уже занял кто-то другой (выставили и тут же
## убили), не летим. Возвращает true, если полёт начался.
func _launch_troop(pid: String, slot_id: String, order: int) -> bool:
	if slot_id == "" or String((_view.get("troops", {}) as Dictionary).get(slot_id, "")) != pid:
		return false
	var from: Variant = _barracks_at(pid)
	var to: Variant = _board_at(_board_panel.slot_global(slot_id))
	if from == null or to == null:
		return false
	_fly_to_board(_troop_token(pid), from, to, "troop|" + slot_id, order,
		func() -> void: _barracks.kick(pid))
	return true


## Удар по войску victim (см. BoardPanel.kill_at): стоп-кадр, цифра зала
## трофеев killer вспыхивает. Ничего не летит (решение владельца, 2026-09-28):
## трофей просто засчитывается.
func _on_kill_struck(_slot_id: String, victim: String, killer: String, _supplant: bool) -> void:
	_hitstop(KILL_HITSTOP)
	_players_panel.flash_trophy(killer, victim)


## Шпион pid вылетает из барака к локации site_id.
func _launch_spy(pid: String, site_id: String, order: int) -> bool:
	var from: Variant = _barracks_at(pid)
	var to: Variant = _board_at(_board_panel.spy_global(site_id, pid))
	if from == null or to == null:
		return false
	_fly_to_board(_spy_token(pid), from, to, "spy|%s|%s" % [site_id, pid], order,
		func() -> void: _barracks.kick(pid))
	return true


## Move: войско owner срывается с места from_slot (облачко пыли) и
## врезается в to_slot так же, как при деплое.
func _move_troop(owner: String, from_slot: String, to_slot: String, order: int) -> bool:
	if owner == "" or String((_view.get("troops", {}) as Dictionary).get(to_slot, "")) != owner:
		return false
	var from: Variant = _board_at(_board_panel.slot_global(from_slot))
	var to: Variant = _board_at(_board_panel.slot_global(to_slot))
	if from == null or to == null:
		return false
	var colour := BoardPanel.troop_colour(owner)
	_fly_to_board(_troop_token(owner), from, to, "troop|" + to_slot, order,
		func() -> void: _board_panel.dust_at_slot(from_slot, colour))
	return true


## Return: войско срывается с места и улетает в барак хозяина, барак
## вспыхивает, принимая его. У белых (нейтральных) войск барака нет — они
## взлетают и тают на месте.
func _return_troop(owner: String, slot_id: String, order: int) -> bool:
	var from: Variant = _board_at(_board_panel.slot_global(slot_id))
	if owner == "" or from == null:
		return false
	var colour := BoardPanel.troop_colour(owner)
	_fly_to_barracks(_troop_token(owner), owner, from, order,
		func() -> void: _board_panel.dust_at_slot(slot_id, colour))
	return true


## Шпион owner улетает от локации site_id обратно в барак.
func _return_spy(owner: String, site_id: String, order: int) -> bool:
	var from: Variant = _board_at(_board_panel.spy_departure_global(site_id))
	if owner == "" or from == null:
		return false
	_fly_to_barracks(_spy_token(owner), owner, from, order, Callable())
	return true


## Полёт на доску: в конце доска ставит фишку key на место с ударом (land),
## войско — ещё и со стоп-кадром. До того доска её прячет.
func _fly_to_board(token: FlyingToken, from: Vector2, to: Vector2, key: String,
		order: int, on_start: Callable) -> void:
	# Запас на случай, если полёт оборвётся: доска поставит фишку сама.
	_board_panel.hold_arrival(key, _flight_duration(order) + 0.5)
	var heavy := not token.spy
	_fly(token, from, to, order, on_start,
		func(t: float) -> void: _board_panel.set_arrival_progress(key, t),
		func() -> void:
			_board_panel.land(key, heavy)
			if heavy:
				_hitstop(TOKEN_HITSTOP))


## Полёт в барак owner: фишка уменьшается к концу и «ныряет» в прямоугольник,
## тот вспыхивает. Барака нет (белое войско) — фишка взлетает и тает.
func _fly_to_barracks(token: FlyingToken, owner: String, from: Vector2, order: int,
		on_start: Callable) -> void:
	var to: Variant = _barracks_at(owner)
	if to == null:
		_fly(token, from, from + Vector2(0, -TOKEN_ARC * 0.5), order, on_start,
			func(t: float) -> void: token.modulate.a = 1.0 - t, Callable())
		return
	_fly(token, from, to, order, on_start, Callable(),
		func() -> void: _barracks.kick(owner))


func _flight_duration(order: int) -> float:
	return TOKEN_STAGGER * order + TOKEN_HOP_TIME + TOKEN_HANG_TIME + TOKEN_FLIGHT_TIME


## Общий полёт фишки из from в to (координаты экрана). Позиция и масштаб —
## только целые, как всё на пиксельном экране.
##
## Три фазы: выскочить в сторону цели (и сразу вырасти вдвое — «поднялась к
## камере»), коротко зависнуть, полететь по дуге с разгоном — фишка не
## тормозит у цели, а врезается в неё. on_start — в момент вылета, on_step(t)
## — на каждом шаге полёта, on_end — в момент прибытия.
func _fly(token: FlyingToken, from: Vector2, to: Vector2, order: int,
		on_start: Callable, on_step: Callable, on_end: Callable) -> void:
	var hop := from + (to - from).normalized() * TOKEN_HOP
	var delay := TOKEN_STAGGER * order

	token.position = from.round()
	token.visible = false
	token.z_index = 6
	add_child(token)

	var mid := hop.lerp(to, 0.5) + Vector2(0, -TOKEN_ARC)
	# Барак у самого верха экрана: выше него дуга ушла бы за край. Тогда
	# фишка летит почти горизонтально и потом падает на место.
	mid.y = maxf(mid.y, minf(hop.y, to.y) - TOKEN_HOP)
	var tween := token.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		token.visible = true
		token.set_magnify(2)
		if on_start.is_valid():
			on_start.call())
	tween.tween_method(func(t: float) -> void:
			token.move_to(from.lerp(hop, t)),
		0.0, 1.0, TOKEN_HOP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(TOKEN_HANG_TIME)
	tween.tween_method(func(t: float) -> void:
			token.move_to(hop.lerp(mid, t).lerp(mid.lerp(to, t), t))
			token.set_magnify(2 if t < TOKEN_BIG_UNTIL else 1)
			if on_step.is_valid():
				on_step.call(t),
		0.0, 1.0, TOKEN_FLIGHT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if on_end.is_valid():
			on_end.call()
		token.queue_free())


## Стоп-кадр: вся игра замирает на seconds секунд настоящего времени.
## Таймер идёт мимо Engine.time_scale, иначе он замер бы вместе со всеми.
## Сетевую логику не трогает: замирают только анимации и таймер хода.
func _hitstop(seconds: float) -> void:
	Engine.time_scale = 0.0
	get_tree().create_timer(seconds, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0)


func _exit_tree() -> void:
	# Экран закрыли посреди стоп-кадра — время не должно остаться стоящим.
	Engine.time_scale = 1.0


static func _error_name(err: int) -> String:
	match err:
		GameServer.Error.NOT_YOUR_TURN: return "it is not your turn"
		GameServer.Error.AWAITING_DECISION: return "answer the card's question first"
		GameServer.Error.NO_DECISION_PENDING: return "there is no question to answer"
		GameServer.Error.INVALID_ACTION: return "this action is not legal right now"
		GameServer.Error.GAME_OVER: return "the game is over"
		GameServer.Error.PAUSED: return "the game is paused"
		_: return "error %d" % err


## Таймер хода. Отсчёт начинается заново на каждой смене ходящего; когда время
## вышло, интерфейс сам жмёт End turn — тем же намерением, что и щелчок мышью.
## Пока на экране висит вопрос карты, завершить ход нельзя, поэтому таймер ждёт
## ответа и завершает ход сразу после него. Если же отвечает не ходящий, а
## другой игрок, таймер ходящего стоит на паузе.
func _process(delta: float) -> void:
	if _timer_label == null or _view.is_empty():
		return
	_pulse_end_turn(delta)
	_tick_space_hold(delta)
	_tick_pause(delta)
	if bool(_view["game_over"]):
		_timer_label.text = "--:--"
		_timer_label.add_theme_color_override("font_color", Color(0.5, 0.49, 0.56))
		return
	var current := acting_player(_view)
	# Под таймером — единственная оставшаяся пометка о состоянии партии:
	# начался последний круг, дальше подсчёт очков. Отдельной строкой: рядом с
	# таймером она в узкую колонку не помещается.
	var last_round := bool(_view["game_end_triggered"])
	if _last_round_label.visible != last_round:
		_last_round_label.visible = last_round
		_layout()
	var pending: Dictionary = _view.get("pending_decision", {})
	if current != _timed_player:
		_timed_player = current
		_time_left = TURN_SECONDS
		_timed_played = _played_count(current)
		_timed_question = ""
		_auto_answered = false
	_add_turn_bonus(current, pending)
	# Пока на вопрос карты отвечает другой игрок (например, сбрасывает карту
	# по эффекту), время ходящего не тратится — идёт таймер ответа.
	if not pending.is_empty() and String(pending.get("player_id", "")) != current:
		_tick_decision_timer(pending, delta)
		return
	_decision_key = ""
	# Пока открыто меню паузы или сетевая партия на паузе, таймер хода стоит.
	if not _clock_stopped():
		_time_left = maxf(0.0, _time_left - delta)
	_show_time(_time_left)

	# Стартовая расстановка: End turn недоступна, по нулю локация выбирается сама.
	if _time_left <= 0.0 and _is_starting_pick(_view) and current == viewer_id \
			and not _auto_answered and not (pending.get("legal_options", []) as Array).is_empty():
		_auto_answered = true
		_note("Time is up — a starting site was chosen automatically.")
		_on_decision_answer(auto_decision_answer(pending["legal_options"]))
	if _time_left <= 0.0 and not _auto_ending and current == viewer_id \
			and not _end_turn_button.disabled:
		_auto_ending = true
		_note("Time is up — the turn ends automatically.")
		send(Intent.end_turn(current))
		_auto_ending = false


## Удержание пробела: копится, пока пробел зажат и End turn доступна; через
## SPACE_HOLD_SECONDS ход заканчивается, как от щелчка. Чтобы закончить и
## следующий ход, пробел надо отпустить и зажать снова.
func _tick_space_hold(delta: float) -> void:
	if _space_held and not _end_turn_button.disabled and not _pause_menu.visible:
		_space_hold += delta
	else:
		_space_hold = 0.0
	if _space_hold >= SPACE_HOLD_SECONDS:
		_space_held = false
		_space_hold = 0.0
		_on_action_requested("end_turn")
	var part := _space_hold / SPACE_HOLD_SECONDS
	_space_fill.position = _end_turn_button.position
	_space_fill.size = Vector2(floorf(_end_turn_button.size.x * part), _end_turn_button.size.y)


## Добавка ко времени хода: +TURN_BONUS_SECONDS за каждую новую карту в
## played_pile ходящего и за каждый новый вопрос карты ему самому. Считается
## только по открытому виду, поэтому у всех игроков сети совпадает.
func _add_turn_bonus(current: String, pending: Dictionary) -> void:
	var bonus := 0
	var played := _played_count(current)
	if played > _timed_played:
		bonus += played - _timed_played
	_timed_played = played
	if not pending.is_empty() and String(pending.get("player_id", "")) == current:
		var key := "%s|%s|%s" % [pending.get("prompt", ""), pending.get("tag", ""),
			pending.get("source_card", "")]
		if key != _timed_question:
			_timed_question = key
			bonus += 1
	else:
		_timed_question = ""
	if bonus > 0:
		_time_left = minf(TURN_MAX_SECONDS, _time_left + TURN_BONUS_SECONDS * bonus)


func _played_count(player_id: String) -> int:
	var p: Dictionary = (_view.get("players", {}) as Dictionary).get(player_id, {})
	return (p.get("played_pile", []) as Array).size()


func _show_time(seconds: float) -> void:
	var left := int(ceilf(seconds))
	_timer_label.text = "%d:%02d" % [left / 60, left % 60]
	_timer_label.add_theme_color_override("font_color",
		Color(0.95, 0.38, 0.32) if seconds <= 20.0 else Color(0.78, 0.76, 0.86))


## Таймер ответа на чужую карту: у всех на месте таймера хода идёт отсчёт
## отвечающего; по нулю его собственный клиент сам выбирает ответ.
func _tick_decision_timer(pending: Dictionary, delta: float) -> void:
	var key := "%s|%s|%s|%s|%s" % [pending.get("player_id", ""), pending.get("prompt", ""),
		pending.get("tag", ""), pending.get("source_card", ""), str(pending.get("legal_options", []))]
	if key != _decision_key:
		_decision_key = key
		_decision_left = DECISION_SECONDS
		_auto_answered = false
	if not _clock_stopped():
		_decision_left = maxf(0.0, _decision_left - delta)
	_show_time(_decision_left)
	if _decision_left > 0.0 or _auto_answered or String(pending["player_id"]) != viewer_id:
		return
	var options: Array = pending.get("legal_options", [])
	if options.is_empty():
		return
	_auto_answered = true
	_note("Time is up — an answer was chosen automatically.")
	_on_decision_answer(auto_decision_answer(options))


func _clock_stopped() -> bool:
	return _pause_menu.visible or is_paused()


## Ответ по истечении времени: отказ, если он разрешён ("" / -1 / false),
## иначе первый допустимый вариант.
static func auto_decision_answer(options: Array) -> Variant:
	for o in options:
		match typeof(o):
			TYPE_STRING, TYPE_STRING_NAME:
				if String(o) == "":
					return o
			TYPE_INT, TYPE_FLOAT:
				if o == -1:
					return o
			TYPE_BOOL:
				if not o:
					return o
	return options[0]


func refresh(view: Dictionary) -> void:
	_view = view
	_refresh_turn(view)
	_barracks.update_from_view(view)
	_game_over_panel.update_from_view(view)
	_hand_panel.update_from_view(view, viewer_id)
	_market_panel.update_from_view(view)
	_board_panel.update_from_view(view, viewer_id, board_data)
	_show_decision(view)
	_refresh_played(view)
	_refresh_piles(view)
	_refresh_actions(view)
	# Появился или ушёл ghost — рынок вырос или сжался на ряд, колонку
	# раскладываем заново.
	if not is_equal_approx(_market_panel.get_combined_minimum_size().y, _market_panel.size.y):
		_layout()


## Чей сейчас ход — на самой кнопке End turn (решение владельца, 2026-09-19).
func _refresh_turn(view: Dictionary) -> void:
	var current := acting_player(view)
	if bool(view["game_over"]):
		_turn_label.text = "GAME OVER"
		_turn_label.add_theme_color_override("font_color", PixelTheme.GOLD)
		_end_label.text = ""
		return
	_announce_turn(view)
	var who := EventLogPanel.player_name(current).to_upper()
	# Сетевая партия, ход чужой: на кнопке — кого ждём (решение владельца,
	# 2026-09-27), сама кнопка серая.
	if net != null and current != viewer_id:
		_turn_label.text = "WAITING:"
		_turn_label.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
		_end_label.text = who
		_end_label.add_theme_color_override("font_color", EventLogPanel.player_color(current))
		return
	# Длинное имя из профиля не влезает в кнопку вместе с "'S TURN" —
	# тогда пишем одно имя: цвет надписи и так говорит, чей ход.
	var text := "YOUR TURN" if net != null else "%s'S TURN" % who
	var font := _turn_label.get_theme_font("font")
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			_turn_label.get_theme_font_size("font_size")).x > _turn_label.size.x:
		text = who
	_turn_label.text = text
	_turn_label.add_theme_color_override("font_color", EventLogPanel.player_color(current))
	_end_label.text = "END TURN"
	_end_label.remove_theme_color_override("font_color")


## Ход перешёл к другому игроку — баннер по центру доски: в хотсите
## «BLUE'S TURN» (за экран садится другой человек), в сети «YOUR TURN» только
## своему. Стартовая расстановка баннера не даёт: там вопрос и так написан
## под таблицей игроков.
##
## В сети, если окно игры не в фокусе, иконка в панели задач мигает — и на
## свой ход, и на вопрос чужой карты, на который надо ответить.
func _announce_turn(view: Dictionary) -> void:
	var current := String(view["current_player"])
	if not _is_starting_pick(view) and current != _banner_player:
		_banner_player = current
		if net == null or current == viewer_id:
			var text := "YOUR TURN" if net != null \
				else "%s'S TURN" % EventLogPanel.player_name(current).to_upper()
			# Отложенно: в самом первом срезе экран ещё не разложен, и центра
			# доски пока нет.
			_show_banner.call_deferred(text, EventLogPanel.player_color(current))
			_request_attention()
	var pending: Dictionary = view.get("pending_decision", {})
	var key := "%s|%s" % [String(pending.get("player_id", "")), String(pending.get("prompt", ""))]
	if not pending.is_empty() and String(pending.get("player_id", "")) == viewer_id \
			and current != viewer_id and key != _attention_key:
		_request_attention()
	_attention_key = key


func _show_banner(text: String, colour: Color) -> void:
	_turn_banner.show_turn(text, colour, Rect2(_board_area.position, _board_area.size))


func _request_attention() -> void:
	if net != null and not get_window().has_focus():
		get_window().request_attention()


## Таблица игроков. Power/Influence ходящего — на прозрачной плашке над рукой:
## тратит их тот, чей ход. Во время стартовой расстановки плашки нет, а вопрос
## «выбери стартовую локацию» — строкой над доской, мерцая (DecisionDialog).
func _refresh_played(view: Dictionary) -> void:
	_players_panel.update_from_view(view)
	var setup_pick := _is_starting_pick(view)
	_res_frame.visible = not setup_pick
	if setup_pick:
		return

	var current := String(view["current_player"])
	var p: Dictionary = (view["players"] as Dictionary).get(current, {})
	_res_title.text = "%s:" % EventLogPanel.player_name(current).to_upper()
	_res_title.add_theme_color_override("font_color", EventLogPanel.player_color(current))
	# Имя другой длины — плашка ужимается или растёт под него.
	_place_res_frame()
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


## Кто сейчас действует — ему принадлежат таймер, надпись над ним и «>» в
## таблице игроков. Обычно это ходящий; но на стартовой расстановке сервер
## держит ходящим первого игрока, пока остальные по очереди выбирают локации,
## — тогда действует выбирающий.
static func acting_player(view: Dictionary) -> String:
	if _is_starting_pick(view):
		return String((view["pending_decision"] as Dictionary).get("player_id", ""))
	return String(view["current_player"])


## Изменилось Power или Influence — над плашкой всплывает «+2» или «-1».
## Считаем только для того, чей ход: плашка показывает именно его ресурсы, а
## при переходе хода цифры меняются не от траты, и всплывать там нечему.
func _popup_resource_change(current: String, power: int, influence: int) -> void:
	# size.x < 10 — экран ещё не разложен (см. _layout), места плашки нет, и
	# цифра всплыла бы в углу за краем.
	if current == _res_player and _res_zone.is_visible_in_tree() and size.x >= 10.0:
		# Цифра всплывает над своим счётчиком, поверх низа доски.
		var up := Vector2(0, -PixelTheme.LINE_H) - global_position
		if power != _res_power_shown:
			FloatingText.spawn(self, _signed(power - _res_power_shown),
				POWER_COLOR, _res_power.global_position + up)
		if influence != _res_influence_shown:
			FloatingText.spawn(self, _signed(influence - _res_influence_shown),
				INFLUENCE_COLOR, _res_influence.global_position + up)
	_res_player = current
	_res_power_shown = power
	_res_influence_shown = influence


static func _signed(delta: int) -> String:
	return ("+%d" % delta) if delta > 0 else str(delta)


## Стопки зрителя. Сброс и состав колоды видны только своему игроку
## (StateView их прячет), Внутренний круг открыт всем — здесь показываем
## всё равно только свой.
func _refresh_piles(view: Dictionary) -> void:
	var me: Dictionary = (view["players"] as Dictionary)[viewer_id]
	_pile_inner.set_cards(me.get("inner_circle", []))
	_deck_tracker.set_cards(me.get("deck_cards", []), me.get("discard_pile", []))
	# Сожранные карты — стопка общая для всех, не своя у зрителя.
	_pile_devour.set_cards(view.get("devoured_pile", []))


## Щелчок по стопке — весь её список поверх экрана.
func _open_pile(which: String) -> void:
	var view := _view
	var me: Dictionary = (view["players"] as Dictionary)[viewer_id]
	var who := EventLogPanel.player_name(viewer_id)
	match which:
		"inner":
			_pile_dialog.open_pile("%s — Inner Circle" % who, me.get("inner_circle", []))
		"devour":
			_pile_dialog.open_pile("Devoured cards", view.get("devoured_pile", []))


func _refresh_actions(view: Dictionary) -> void:
	var legal: Dictionary = view.get("legal", {})
	_end_turn_button.disabled = not bool(legal.get("end_turn", false))
	_end_turn_colour = BoardPanel.PLAYER_COLORS.get(viewer_id, Color(0.6, 0.6, 0.6))
	_style_end_turn(_end_turn_colour)
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
	if cid == "" or from.size.x < 1.0 or not _deck_tracker.visible:
		return
	var to := _deck_tracker.discard_rect().get_center() - from.size * 0.5
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
	var pending: Dictionary = _view.get("pending_decision", {})
	if not pending.is_empty() and String(pending["player_id"]) == viewer_id:
		if _try_resolve_board_decision(pending, slot_id, _site_of_slot(slot_id)):
			return
		if _is_board_choice(String(pending["choice_type"])):
			_note("That is not a valid target — valid targets have gold rings.")
			return

	var view := _view
	var legal: Dictionary = view.get("legal", {})
	if (legal.get("assassinate_slots", []) as Array).has(slot_id):
		send(Intent.assassinate(viewer_id, slot_id))
	elif (legal.get("deploy_slots", []) as Array).has(slot_id):
		send(Intent.deploy(viewer_id, slot_id))
	else:
		_note(_explain_slot_refusal(slot_id, view, legal))


func _is_board_choice(choice_type: String) -> bool:
	return choice_type == "target_slot" or choice_type == "target_site" or choice_type == "target_return"


## Пытается ответить на pending-решение кликом по доске: slot_id — конкретное
## войско (если кликнули по нему), site_id — локация под ним, либо локация,
## если кликнули по её названию напрямую (slot_id тогда ""). target_return
## кодирует составные цели ("troop|<slot_id>" / "spy|<site_id>|<owner>") —
## те же префиксы, что и в decision_dialog.gd::_board_label. Возвращает true,
## если ответ отправлен на сервер.
func _try_resolve_board_decision(pending: Dictionary, slot_id: String, site_id: String) -> bool:
	var options: Array = pending.get("legal_options", [])
	match String(pending["choice_type"]):
		"target_slot":
			if slot_id != "" and options.has(slot_id):
				send(Intent.make_decision(viewer_id, slot_id))
				return true
		"target_site":
			if site_id != "" and options.has(site_id):
				send(Intent.make_decision(viewer_id, site_id))
				return true
		"target_return":
			if slot_id != "":
				var composite := "troop|" + slot_id
				if options.has(composite):
					send(Intent.make_decision(viewer_id, composite))
					return true
			# Шпиона-цель выбирают кликом по самому ромбику (_on_spy_clicked),
			# не по локации: на ней их может стоять несколько.
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


## Клик по названию локации — ответ на решение с целью-локацией. Вражеского
## шпиона так не вернуть: только кликом по его ромбику (_on_spy_clicked).
func _on_site_clicked(site_id: String) -> void:
	var pending: Dictionary = _view.get("pending_decision", {})
	if not pending.is_empty() and String(pending["player_id"]) == viewer_id:
		if _try_resolve_board_decision(pending, "", site_id):
			return
		if _is_board_choice(String(pending["choice_type"])):
			_note("That is not a valid target — valid targets have gold rings.")
			return

	for target in ((_view.get("legal", {}) as Dictionary).get("return_spy", []) as Array):
		if String((target as Dictionary)["site_id"]) == site_id:
			_note("Click the spy itself to return it")
			return
	_note("%s: nothing to do here" % EventLogPanel.site_name(site_id, board_data))


## Клик прямо по ромбику шпиона: возвращаем именно его, без меню. Если этого
## шпиона вернуть нельзя (свой, нет Присутствия...), клик считается кликом по
## локации — там работают "вернуть своего шпиона" и прочие цели-локации.
func _on_spy_clicked(site_id: String, owner: String) -> void:
	var pending: Dictionary = _view.get("pending_decision", {})
	if not pending.is_empty() and String(pending["player_id"]) == viewer_id:
		var composite := "spy|%s|%s" % [site_id, owner]
		if String(pending["choice_type"]) == "target_return" \
				and (pending.get("legal_options", []) as Array).has(composite):
			send(Intent.make_decision(viewer_id, composite))
			return
	else:
		for target in ((_view.get("legal", {}) as Dictionary).get("return_spy", []) as Array):
			var t: Dictionary = target
			if String(t["site_id"]) == site_id and String(t["spy_owner"]) == owner:
				send(Intent.return_spy(viewer_id, site_id, owner))
				return
	_on_site_clicked(site_id)


func _on_decision_answer(answer: Variant) -> void:
	send(Intent.make_decision(viewer_id, answer))
