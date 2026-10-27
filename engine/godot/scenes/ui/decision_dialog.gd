class_name DecisionDialog
extends PanelContainer

## Вопрос, который карта задаёт игроку посреди своего эффекта
## (PendingDecision). Через этот диалог проходят эффекты всех 125 карт, потому
## что любой выбор — "choose one", цель убийства, "you may...", какую карту
## сожрать — сервер отдаёт одинаково: prompt + choice_type + legal_options.
##
## Варианты подписываются по-разному в зависимости от choice_type: id карты
## превращается в её название, id слота — в название локации, bool — в Yes/No,
## индекс варианта — в "Option N". Пустая строка и -1 в legal_options
## означают "отказаться" (эффекты вида "up to N" кладут туда пропуск).
##
## Этап 3: если цель выбирается на доске, диалог — узкая плашка у верхнего
## края экрана, а не окно посередине: окно закрывало ту самую доску, по
## которой нужно кликнуть. Для выбора кнопками окно по центру, высотой по
## числу вариантов, без пустого места.

signal option_chosen(answer: Variant)

const BOARD_CHOICES := ["target_slot", "target_site", "target_return"]
const OPTION_HEIGHT := 15
const MAX_LIST_HEIGHT := 150
const WIDTH := 300.0
## Карт-вариантов "Choose one" в ряд — больше не влезает в 960 px (дальше списком).
const MAX_OPTION_CARDS := 4
## Выбор карты (promote, discard, devour...) — сетка мелких лиц карт вместо
## строк с названиями: карту узнают по арту, а полную читают через Alt.
const CARD_SIZE := CardView.MINI_SIZE
## Вопрос справа от карты, которая спрашивает, переносится не шире этого;
## если правее ещё и карты-варианты — не шире второго.
const ASKER_TEXT_MAX_WIDTH := 420.0
const STAIRS_TEXT_MAX_WIDTH := 220.0
## Промежуток между частями полосы: карта | вопрос | карты-варианты.
const HEAD_GAP := 6

## Статический снимок доски (StateView.board_snapshot) — нужен, чтобы
## подписывать цели по-человечески: "Caer Sidi · space 2" вместо "c_n1:C4_0_1".
var board: Dictionary = {}

var _prompt: Label
var _who: Label
var _options_box: VBoxContainer
var _scroll: ScrollContainer
var _asker_slot: HBoxContainer
var _cards_slot: CardStairs
var _style: StyleBoxFlat
## Плашка сейчас полосой под доской (выбор цели на доске), а не окном по центру.
## Имя осталось с тех пор, когда полоса была у верхнего края.
var at_top := false
## Низ полосы — на столько выше низа зоны доски (ставит GameScreen: над счётчиком
## Power/Influence).
var strip_bottom := 0.0
var _market_display: Array = []
var _ghost_card := ""
var _dim: ColorRect
## Вопрос мерцает (сброс карты — видно, кто сейчас сбрасывает).
var _blink := false
var _blink_time := 0.0
## Вопрос задала чужая карта (GameScreen.is_forced): мерцает ярче, не тусклее.
var _forced := false
const FORCED_BRIGHT := 2.2
## "Choose one" картами спрятан кнопкой Hide: вместо окна по центру — полоса
## под доской с кнопкой Show, доска видна (владелец, 2026-10-27). Новый вопрос
## снова показывает окно.
var _cards_hidden := false
var _cards_key := ""
var _last_view: Dictionary = {}
var _last_viewer := ""


## Подпись карты маркета по индексу: название и цена. Публичная — для тестов.
static func market_label(index: int, display: Array, ghost_card: String = "") -> String:
	var card_id := ""
	if index == Market.DEVOURED_TOP_INDEX:
		card_id = ghost_card
	elif index < display.size():
		card_id = String(display[index])
	if card_id == "":
		return label_for(index, "target_market_index")
	var cost: int = CardLibrary.card_cost(card_id)
	return "%s (%d)" % [_card_label(card_id), cost] if cost >= 0 else _card_label(card_id)


## id карты рынка по номеру варианта ("" — не карта: отказ или пустое место).
func _market_card_id(index: int) -> String:
	if index == Market.DEVOURED_TOP_INDEX:
		return _ghost_card
	if index >= 0 and index < _market_display.size():
		return String(_market_display[index])
	return ""


func _init() -> void:
	visible = false
	custom_minimum_size = Vector2(WIDTH, 0)

	_style = PixelTheme.box(Color(PixelTheme.PANEL_HI, 0.97), PixelTheme.GOLD, 1, 3, 2)
	add_theme_stylebox_override("panel", _style)

	# Затемнение всего экрана под выбором карт: верхнеуровневый узел, его не
	# раскладывает панель. Клики он НЕ ловит: верхнеуровневый узел Godot
	# опрашивает раньше детей окна, и карты переставали нажиматься. Клики
	# мимо окна гасит _input.
	_dim = ColorRect.new()
	_dim.top_level = true
	_dim.color = PixelTheme.DIM
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	# top_level не наследует z окна — задаём свой: над рукой, под окном.
	_dim.z_index = 999
	add_child(_dim)

	# Полоса в один ряд: карта, которая спрашивает | вопрос и кнопки под ним |
	# карты-варианты (пустые части скрыты).
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", HEAD_GAP)
	add_child(head)
	_asker_slot = HBoxContainer.new()
	_asker_slot.visible = false
	head.add_child(_asker_slot)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(col)

	_cards_slot = CardStairs.new()
	_cards_slot.visible = false
	head.add_child(_cards_slot)

	_who = Label.new()
	col.add_child(_who)

	_prompt = Label.new()
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_prompt)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)

	_options_box = VBoxContainer.new()
	_options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_box.add_theme_constant_override("separation", 1)
	_scroll.add_child(_options_box)


func update_from_view(view: Dictionary, viewer_id: String) -> void:
	var pd: Dictionary = view.get("pending_decision", {})
	if pd.is_empty():
		visible = false
		_cards_key = ""
		return
	_last_view = view
	_last_viewer = viewer_id

	_market_display = (view.get("market", {}) as Dictionary).get("display", [])
	_ghost_card = String(view.get("ghost_market_card", ""))
	var decider := String(pd.get("player_id", ""))
	var choice_type := String(pd.get("choice_type", ""))
	# Карту из руки выбирают в самой руке внизу (hand_panel.gd), с рынка — на
	# самом рынке (market_panel.gd), поэтому вопрос — такая же полоса сверху,
	# как у цели на доске.
	var tag := String(pd.get("tag", ""))
	var in_hand := tag == "hand"
	var hand_or_discard := tag == HandPanel.HAND_OR_DISCARD
	# Inner Circle и сброс на время выбора встают в ряд руки справа (hand_panel.gd).
	var on_board: bool = BOARD_CHOICES.has(choice_type) or in_hand or hand_or_discard \
		or tag == "market" or HandPanel.ZONE_LABELS.has(tag) \
		or choice_type == "target_player" or tag == "trophy_hall"   # в таблице игроков (players_panel.gd)
	var options: Array = pd.get("legal_options", [])
	visible = true
	_style.border_color = BoardPanel.colour(decider, Color(0.85, 0.65, 0.25))
	# Схема доски занимает всю свою зону, поэтому вопрос про цель НА ДОСКЕ
	# показываем одной узкой полосой сверху: имя ходящего и вопрос в строку.
	_who.text = "%s decides" % EventLogPanel.player_name(decider)
	_who.modulate = EventLogPanel.player_color(decider)
	_prompt.text = String(pd.get("prompt", "Choose an option"))
	# Сброс: крупно и мерцая, цветом игрока — кто сейчас сбрасывает (решение
	# владельца, 2026-09-27; чья карта заставила — видно в журнале слева).
	# Так же — выбор стартовой локации: он был строкой под таблицей игроков и
	# терялся (решение владельца, 2026-09-27).
	var discard := in_hand and _prompt.text.begins_with("Discard")
	var starting := tag == "starting_site"
	# Чужая карта заставляет отвечать: вопрос не тускнеет, а вспыхивает ярче
	# и называет, чья карта (владелец, 2026-10-11).
	_forced = GameScreen.is_forced(view)
	_blink = discard or starting or _forced
	if _forced:
		_who.text = "Forced by %s: %s decides" % [
			EventLogPanel.player_name(String(view.get("current_player", ""))),
			EventLogPanel.player_name(decider)]
	if discard or starting:
		_prompt.text = "%s: %s" % [EventLogPanel.player_name(decider),
			"discard a card" if discard else "choose your starting site"]
	if _blink:
		_prompt.add_theme_color_override("font_color", EventLogPanel.player_color(decider))
	else:
		_prompt.remove_theme_color_override("font_color")
	_prompt.modulate = Color.WHITE

	for box in [_options_box, _asker_slot, _cards_slot]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_asker_slot.visible = false
	_cards_slot.visible = false
	var cards_mode := false
	# Вопрос полосой сверху, без затемнения: "You may..." и выбор карты
	# (решение владельца, 2026-10-11; "Choose one" остаётся окном по центру).
	var strip := false
	var waiting := decider != viewer_id

	if waiting:
		# Не наш вопрос: сам факт показываем (чтобы было видно, чего ждём),
		# но вариантов у нас нет — сервер их и не прислал. Без рамки, по
		# центру и без затемнения (решение владельца, 2026-09-27).
		_add_asker(pd, decider)
		_add_note("Waiting for %s." % EventLogPanel.player_name(decider))
		(_options_box.get_child(0) as Label).horizontal_alignment = \
			HORIZONTAL_ALIGNMENT_LEFT if _asker_slot.visible else HORIZONTAL_ALIGNMENT_CENTER
	elif options.is_empty():
		_add_note("No options.")
	elif on_board:
		# Цели на доске выбираются кликом по самой доске — она подсвечивает
		# их золотым (board_panel.gd::_draw_decision_targets). Кнопка остаётся
		# только для "отказаться", если решение необязательное.
		# Вопрос — крупный текст без рамки над доской (решение владельца,
		# 2026-09-26), подсказка про подсветку — в мелкой строке над ним.
		# Слева — карта, которая спрашивает (promote, deploy...; владелец, 2026-10-11).
		_add_asker(pd, decider)
		if in_hand:
			_who.text += " — click a gold card in your hand"
		elif hand_or_discard:
			_who.text += " — click a gold card in your hand or right of it"
		elif choice_type == "target_player":
			_who.text += " — click a gold player in the players table"
		elif tag == "trophy_hall":
			_who.text += " — click a gold trophy number in the players table"
		elif tag == "market":
			_who.text += " — click a gold card in the market"
		elif HandPanel.ZONE_LABELS.has(tag):
			_who.text += " — click a gold card in your %s, right of the hand" \
				% ("Inner Circle" if tag == "inner_circle" else "discard pile")
		else:
			_who.text += " — click a gold site on the board" if tag == "starting_site" \
				else " — click a gold target on the board"
		# Отказ: "" у целей и карт руки, -1 у номера карты рынка. Перебором, а
		# не has(): список карт руки типизирован строками, has(-1) там — ошибка.
		for o in options:
			if (typeof(o) == TYPE_STRING and o == "") or (typeof(o) == TYPE_INT and o == -1):
				if _asker_slot.visible:
					_add_strip_buttons([["Skip", o]])
				else:
					_add_button("Skip", o)
					make_plain(_options_box.get_child(0) as Button)
				break
	elif choice_type == "confirm":
		# "You may..." — слева карта, которая спрашивает (щелчок по ней —
		# "да"), под вопросом Yes / No.
		strip = true
		_add_asker(pd, decider, true)
		_add_strip_buttons(options.map(func(o): return [_board_label(o, choice_type), o]))
	elif choice_type == "target_market_index":
		# Карты рынка — справа от вопроса; в ответ уходит номер карты на
		# рынке. -1 — отказ ("You may devour..."), это Skip.
		strip = true
		_add_asker(pd, decider)
		var ids: Array = []
		var indices: Array = []
		for value in options:
			var cid := _market_card_id(int(value))
			if cid != "":
				ids.append(cid)
				indices.append(int(value))
		_add_stairs(ids, indices)
		if options.has(-1):
			_add_strip_buttons([["Skip", -1]])
	elif choice_type == "target_card":
		strip = true
		_add_asker(pd, decider)
		_add_stairs(options, [], decider)
		if options.has(""):
			_add_strip_buttons([["Skip", ""]])
	elif _can_show_option_cards(pd):
		var key := "%s|%s|%s" % [pd.get("source_card", ""), _prompt.text, str(options)]
		if key != _cards_key:
			_cards_key = key
			_cards_hidden = false
		if _cards_hidden:
			strip = true
			_add_asker(pd, decider)
			_add_strip_buttons([["Show", toggle_cards]])
		else:
			_add_option_cards(pd)
			var hide := Button.new()
			hide.text = "Hide"
			hide.pressed.connect(toggle_cards)
			make_plain(hide)
			_options_box.add_child(hide)
			cards_mode = true
	else:
		# Если сервер прислал подписи вариантов (карты вида "Choose one:"),
		# берём их — только карта знает, что означает её вариант №2.
		# Тоже полосой под доской, кнопки в несколько рядов (владелец,
		# 2026-10-27: все вопросы под доской, а не на ней).
		strip = true
		_add_asker(pd, decider)
		var labels: Array = pd.get("option_labels", [])
		var pairs: Array = []
		for i in range(options.size()):
			var text := String(labels[i]) if i < labels.size() and String(labels[i]) != "" \
				else _board_label(options[i], choice_type)
			pairs.append([text, options[i]])
		_add_button_rows(pairs)

	# Пустой список вариантов не должен занимать место: на доске вопрос — это
	# одна строка, и лишние пиксели полосы закрывают схему.
	_set_cards_look(cards_mode or on_board or waiting or strip, decider)
	_fit_strip()
	# Полоса вопроса над доской прозрачна, но клики ловила сама: шпион или
	# войско у верхнего края доски оказывались под ней — рамка цели видна, а
	# клик пропадал, и игрок, целясь ниже, попадал в локацию ("not a valid
	# target"; Xith Idrana на 4 игрока). Теперь сквозь неё кликается доска,
	# кнопка Skip ловит клики сама.
	_pass_clicks(on_board or waiting or strip)
	_set_dim(not waiting and not on_board and not strip and cards_mode)
	var rows: int = _options_box.get_child_count()
	var max_h: float = MAX_LIST_HEIGHT
	if on_board or waiting or strip:
		# Полоса не выше места под доской (BoardSchematic.PROMPT_STRIP), иначе
		# она залезает на схему; лишние ряды кнопок прокручиваются.
		max_h = maxf(BoardSchematic.PROMPT_STRIP - _style.get_minimum_size().y - 4.0
			- _who.get_combined_minimum_size().y - _prompt_height(), OPTION_HEIGHT)
	elif _options_box.get_child_count() > 0 and _options_box.get_child(0) is HBoxContainer:
		max_h = INF  # карты-варианты не прокручиваются: их всего два-три
	_scroll.custom_minimum_size = Vector2(0, minf(_options_box.get_combined_minimum_size().y, max_h))
	_scroll.visible = rows > 0
	_place(on_board or strip or decider != viewer_id)
	# Вопрос с переносом слов знает свою высоту только после раскладки по новой
	# ширине: до неё окно карт-вариантов выходило вдвое выше содержимого.
	_place.call_deferred(on_board or strip or decider != viewer_id)


## Полоса с картой слева или картами-вариантами справа: всё компактной
## группой по центру доски, текст прижат к карте. Без карт столбец вопроса
## во всю ширину. Карты-варианты получают остаток ширины доски и, если не
## влезают, ложатся лесенкой внахлёст.
func _fit_strip() -> void:
	var col := _who.get_parent() as Control
	(col.get_parent() as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	if not _asker_slot.visible and not _cards_slot.visible:
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_prompt.custom_minimum_size.x = 0
		return
	for label: Label in [_who, _prompt]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# Ширина доски минус поля полосы (_place: по 2 с краёв), рамка и карта слева.
	var room := _board_width() - 4.0 - _style.get_minimum_size().x
	if _asker_slot.visible:
		room -= CARD_SIZE.x + HEAD_GAP
	# Тексту — всё, что не нужно картам-вариантам без нахлёста, но не уже
	# STAIRS_TEXT_MAX_WIDTH: дальше пусть лучше карты лягут лесенкой.
	var cap := ASKER_TEXT_MAX_WIDTH
	if _cards_slot.visible:
		var cards_w := _cards_slot.natural_width()
		cap = clampf(room - cards_w - HEAD_GAP, STAIRS_TEXT_MAX_WIDTH, ASKER_TEXT_MAX_WIDTH)
	var width := _prompt_width(cap)
	# Вопрос выше карты (Barbed Devil в пять строк) — обычным шрифтом.
	var font := _prompt.get_theme_font("font")
	var lines_h := font.get_multiline_string_size(_prompt.text, HORIZONTAL_ALIGNMENT_LEFT, width,
		_prompt.get_theme_font_size("font_size")).y
	var rest_h := _who.get_combined_minimum_size().y + _options_box.get_combined_minimum_size().y + 4.0
	if (_asker_slot.visible or _cards_slot.visible) and lines_h + rest_h > CARD_SIZE.y:
		_prompt.remove_theme_font_size_override("font_size")
		width = _prompt_width(cap)
	# Ширина у самой подписи: иначе на первой раскладке (ширина 0) она
	# ложится по букве в строку и столбец остаётся в тысячу пикселей высотой.
	_prompt.custom_minimum_size.x = width
	_prompt.size = Vector2(width, 0)
	col.queue_sort()
	if _cards_slot.visible:
		# Ширину столбца считаем сами: его минимум в этот миг ещё старый.
		var col_w := maxf(width, maxf(_who.get_combined_minimum_size().x,
			_options_box.get_combined_minimum_size().x))
		_cards_slot.arrange(room - col_w - HEAD_GAP)


## Ширина зоны доски, над которой висит полоса (get_parent_area_size у
## Control-родителя без контейнера бывает нулём).
func _board_width() -> float:
	var parent := get_parent() as Control
	return parent.size.x if parent != null else get_viewport_rect().size.x


## Высота вопроса с переносом по той ширине, что ему достанется: сама
## подпись до раскладки знает только старую (или нулевую) ширину.
func _prompt_height() -> float:
	var width := _prompt.custom_minimum_size.x
	if width <= 0.0:
		width = _board_width() - 4.0 - _style.get_minimum_size().x
	var font := _prompt.get_theme_font("font")
	return font.get_multiline_string_size(_prompt.text, HORIZONTAL_ALIGNMENT_LEFT, width,
		_prompt.get_theme_font_size("font_size")).y


## Ширина вопроса одной строкой, но не шире cap. Перенос слов не даёт
## подписи своей ширины — меряем строку сами.
func _prompt_width(cap: float) -> float:
	var font := _prompt.get_theme_font("font")
	var text_w := font.get_string_size(_prompt.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		_prompt.get_theme_font_size("font_size")).x
	return minf(ceilf(text_w) + 2.0, cap)


func _pass_clicks(through: bool) -> void:
	var mode := Control.MOUSE_FILTER_IGNORE if through else Control.MOUSE_FILTER_STOP
	mouse_filter = mode
	for node: Control in [_who.get_parent(), _who.get_parent().get_parent(), _asker_slot, _cards_slot, _scroll, _options_box]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE if through else Control.MOUSE_FILTER_PASS


## Мерцание вопроса: плавно от полной яркости до трети, полтора раза в секунду.
func _process(delta: float) -> void:
	if not _blink or not visible:
		return
	_blink_time += delta
	var wave := 0.5 + 0.5 * cos(_blink_time * TAU * 1.5)
	if _forced:
		# вспышка к белому и обратно к цвету игрока — без потускнения
		_prompt.modulate = Color.WHITE.lerp(Color(FORCED_BRIGHT, FORCED_BRIGHT, FORCED_BRIGHT), wave)
	else:
		_prompt.modulate.a = 0.35 + 0.65 * wave


func set_strip_bottom(value: float) -> void:
	if is_equal_approx(value, strip_bottom):
		return
	strip_bottom = value
	if at_top:
		_place(true)


## Полоса под доской (не закрывает её) или окно по центру.
func _place(top: bool) -> void:
	at_top = top
	if at_top:
		# Полоса во всю ширину доски: так вопрос влезает в одну-две строки и
		# закрывает минимум схемы. Низ стоит на месте, растёт вверх.
		set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		grow_vertical = Control.GROW_DIRECTION_BEGIN
		custom_minimum_size = Vector2.ZERO
		offset_left = 2.0
		offset_right = -2.0
	else:
		set_anchors_preset(Control.PRESET_CENTER)
		grow_vertical = Control.GROW_DIRECTION_BOTH
		custom_minimum_size = Vector2(WIDTH, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	if at_top:
		# Ширину задают якоря (во всю доску), высоту — содержимое. Нулевая
		# высота в отступах: Godot растягивает плашку до минимума содержимого
		# и сжимает обратно, когда минимум падает. Раньше высота замерялась
		# один раз, и если в тот миг ширина ещё не была посчитана, вопрос с
		# переносом строк ложился по букве в строку — плашка в 683 пикселя
		# невидимо накрывала доску и съедала клики (выбор стартовой локации).
		offset_left = 2.0
		offset_right = -2.0
		offset_top = -strip_bottom
		offset_bottom = -strip_bottom
	else:
		# Размер считаем сами: reset_size() после полосы во всю ширину
		# оставлял плашку смещённой влево (ловилось снимком экрана).
		var wanted := get_combined_minimum_size()
		offset_left = -wanted.x * 0.5
		offset_right = wanted.x * 0.5
		offset_top = -wanted.y * 0.5
		offset_bottom = wanted.y * 0.5


func _add_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	# Без переноса: подпись короткая ("Waiting for X."), а с переносом она при
	# первом замере (ширина 0) ложилась по слову в строку, и полоса "Waiting"
	# вырастала вверх на пол-доски (владелец, 2026-10-27).
	label.modulate = Color(0.8, 0.8, 0.85)
	_options_box.add_child(label)


## Мелкие карты-варианты справа от вопроса. Одинаковые карты (два Soldier в
## руке) показываются каждая отдельно — ответ у них один и тот же id, серверу
## это безразлично. "inner:<id>" — карта из Внутреннего круга: лицо то же, в
## ответ уходит исходная строка с префиксом. answers (если заданы) — ответ
## каждой карты по порядку (номер карты на рынке).
func _add_stairs(options: Array, answers: Array = [], seat: String = "") -> void:
	var ids: Array = options.filter(func(o): return typeof(o) == TYPE_STRING and String(o) != "")
	for i in ids.size():
		var value := String(ids[i])
		var cid := value.substr(6) if value.begins_with("inner:") else value
		var card := CardView.new(cid, int(CARD_SIZE.x), int(CARD_SIZE.y))
		if seat != "":
			card.set_card_owner(seat)
		card.highlight = false
		card.set_clickable(true)
		card.tooltip_text = _card_label(value)
		var reply: Variant = answers[i] if i < answers.size() else value
		card.pressed.connect(func(_id): option_chosen.emit(reply))
		_cards_slot.add_child(card)
	_cards_slot.visible = not ids.is_empty()


## Карта, которая задала вопрос, — слева от него. yes_on_click: щелчок по
## ней отвечает "да" ("You may..."); у выбора карты она только для вида.
func _add_asker(pd: Dictionary, decider: String, yes_on_click: bool = false) -> void:
	var asker := String(pd.get("source_card", ""))
	if CardView.pixel_texture(asker) == null:
		return
	var card := CardView.new(asker, int(CARD_SIZE.x), int(CARD_SIZE.y))
	card.set_card_owner(decider)
	card.highlight = false
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if yes_on_click:
		card.set_clickable(true)
		card.pressed.connect(func(_id): option_chosen.emit(true))
	_asker_slot.add_child(card)
	_asker_slot.visible = true


## Hide / Show у "Choose one" картами: окно по центру <-> полоса под доской.
func toggle_cards() -> void:
	_cards_hidden = not _cards_hidden
	update_from_view(_last_view, _last_viewer)


## Кнопки под вопросом в строку: [[подпись, ответ], ...]. Ответ-Callable
## не уходит серверу, а вызывается (Show). Обычные кнопки
## темы, с подложкой: надпись без фона терялась на белых табличках локаций
## у верхнего края доски.
func _add_strip_buttons(pairs: Array) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN if _asker_slot.visible or _cards_slot.visible \
		else BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair: Array in pairs:
		var b := Button.new()
		b.text = String(pair[0])
		var value: Variant = pair[1]
		if value is Callable:
			b.pressed.connect(value)
		else:
			b.pressed.connect(func(): option_chosen.emit(value))
		b.custom_minimum_size = Vector2(40, OPTION_HEIGHT - 1)
		row.add_child(b)
	_options_box.add_child(row)


## Кнопки вариантов рядами под вопросом: ряд не шире полосы (минус карта
## слева), следующий вариант — на новый ряд.
func _add_button_rows(pairs: Array) -> void:
	var room := _board_width() - 4.0 - _style.get_minimum_size().x
	if _asker_slot.visible:
		room -= CARD_SIZE.x + HEAD_GAP
	var font := get_theme_font("font", "Button")
	var font_size := get_theme_font_size("font_size", "Button")
	var pad := get_theme_stylebox("normal", "Button").get_minimum_size().x
	var row: Array = []
	var row_w := 0.0
	for pair: Array in pairs:
		var w := maxf(40.0, ceilf(font.get_string_size(String(pair[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + pad)
		if not row.is_empty() and row_w + 6.0 + w > room:
			_add_strip_buttons(row)
			row = []
			row_w = 0.0
		row_w += w if row.is_empty() else 6.0 + w
		row.append(pair)
	if not row.is_empty():
		_add_strip_buttons(row)


## Кнопка — одна надпись по центру: без фона и рамки, с тенью; под курсором
## светлее (Skip — золотая).
static func make_plain(b: Button, color: Color = PixelTheme.TEXT, font_size: int = 0) -> void:
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", color)
	var hover := PixelTheme.GOLD if color == PixelTheme.TEXT else color.lightened(0.4)
	b.add_theme_color_override("font_hover_color", hover)
	b.add_theme_color_override("font_pressed_color", hover)
	b.add_theme_color_override("font_focus_color", color)
	b.add_theme_color_override("font_shadow_color", PixelTheme.PANEL_LO)
	b.add_theme_constant_override("shadow_offset_x", 1)
	b.add_theme_constant_override("shadow_offset_y", 1)
	if font_size > 0:
		b.add_theme_font_size_override("font_size", font_size)
		b.custom_minimum_size.y = font_size + 4


## Выбор карты затемняет весь экран: окно поднимается над рукой (её поднятая
## карта рисуется с z_index до 901) и маркетом, как окно стопки.
func _set_dim(on: bool) -> void:
	_dim.visible = on
	z_index = 1000 if on else 0
	if on and is_inside_tree():
		_dim.position = Vector2.ZERO
		_dim.size = get_viewport_rect().size


## Пока экран затемнён, щелчки мимо окна выбора никуда не доходят: ни до
## доски, ни до руки, ни до маркета.
func _input(event: InputEvent) -> void:
	if not (_dim.visible and is_visible_in_tree()):
		return
	if event is InputEventMouseButton and not get_global_rect().has_point(event.position):
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		z_index = 0
	elif what == NOTIFICATION_ENTER_TREE:
		get_viewport().size_changed.connect(func():
			if _dim.visible:
				_dim.size = get_viewport_rect().size)


## Карты-варианты висят прямо над доской: окно без фона и рамки, вопрос по
## центру двойным шрифтом с тенью (решение владельца, 2026-09-24).
func _set_cards_look(on: bool, decider: String) -> void:
	_style.bg_color = Color(PixelTheme.PANEL_HI, 0.0 if on else 0.97)
	_style.border_color = Color(0, 0, 0, 0) if on \
		else BoardPanel.colour(decider, Color(0.85, 0.65, 0.25))
	for label: Label in [_who, _prompt]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if on else HORIZONTAL_ALIGNMENT_LEFT
		if on:
			label.add_theme_color_override("font_shadow_color", PixelTheme.PANEL_LO)
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 1)
		else:
			label.remove_theme_color_override("font_shadow_color")
	if on:
		_prompt.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	else:
		_prompt.remove_theme_font_size_override("font_size")


## "Choose one" карты с пиксельным лицом рисуется полноформатными картами
## (OptionCard); если карта неизвестна или у варианта нет подписи — списком.
static func _can_show_option_cards(pd: Dictionary) -> bool:
	if String(pd.get("choice_type", "")) != "choose_option":
		return false
	if CardView.pixel_texture(String(pd.get("source_card", ""))) == null:
		return false
	var labels: Array = pd.get("option_labels", [])
	var options: Array = pd.get("legal_options", [])
	if labels.size() != options.size():
		return false
	# Больше 4 карт-вариантов в 960 px не влезает (Magma Mephit "Choose two" —
	# 6 пар, Homunculus "All of them" к 4 вариантам): крайние уходили за экран.
	if options.size() > MAX_OPTION_CARDS:
		return false
	for label in labels:
		if String(label) == "":
			return false
	return true


## Карты-варианты в ряд, между ними "or".
func _add_option_cards(pd: Dictionary) -> void:
	var options: Array = pd.get("legal_options", [])
	var labels: Array = pd.get("option_labels", [])
	var decider := String(pd.get("player_id", ""))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for i in range(options.size()):
		if i > 0:
			var or_label := Label.new()
			or_label.text = "or"
			or_label.add_theme_color_override("font_color", PixelTheme.GOLD)
			or_label.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
			or_label.add_theme_color_override("font_shadow_color", PixelTheme.PANEL_LO)
			or_label.add_theme_constant_override("shadow_offset_x", 1)
			or_label.add_theme_constant_override("shadow_offset_y", 1)
			or_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(or_label)
		var card := OptionCard.new(String(pd.get("source_card", "")), String(labels[i]), decider)
		var value: Variant = options[i]
		card.pressed.connect(func(): option_chosen.emit(value))
		row.add_child(card)
	_options_box.add_child(row)


func _add_button(text: String, value: Variant) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, OPTION_HEIGHT - 1)
	button.pressed.connect(func(): option_chosen.emit(value))
	_options_box.add_child(button)


## Подпись цели на доске: id слота вида "c_n1:C4_0_1" человеку ничего не
## говорит, поэтому переводим его в название локации и номер места в ней.
## Если снимка доски нет (тесты подписей), откатываемся на общий label_for.
func _board_label(value: Variant, choice_type: String) -> String:
	# Слот маркета: "Kobold (1)" вместо "Market slot 2" — игрок не должен
	# сверять номера с рядом карт справа.
	if choice_type == "target_market_index" and typeof(value) == TYPE_INT and int(value) >= 0:
		return market_label(int(value), _market_display, _ghost_card)
	if board.is_empty() or typeof(value) != TYPE_STRING:
		return label_for(value, choice_type)
	var raw := String(value)
	var sites: Dictionary = board.get("sites", {})
	var slots: Dictionary = board.get("slots", {})

	# Составные цели ReturnTroopOrSpy: "troop|<slot_id>" и "spy|<site_id>|<owner>".
	if raw.begins_with("troop|"):
		return "Troop: " + _board_label(raw.substr(6), "target_slot")
	if raw.begins_with("spy|"):
		var rest: PackedStringArray = raw.substr(4).rsplit("|", true, 1)
		if rest.size() == 2:
			return "%s spy: %s" % [EventLogPanel.player_name(rest[1]), _board_label(rest[0], "target_site")]

	if choice_type == "target_site" and sites.has(raw):
		return "%s (%d VP)" % [(sites[raw] as Dictionary)["name"], int((sites[raw] as Dictionary)["vp"])]

	if choice_type == "target_slot" and slots.has(raw):
		var site_id := String((slots[raw] as Dictionary)["site_id"])
		if site_id == "" or not sites.has(site_id):
			return "Tunnel (%s)" % raw.get_slice(":", 1)
		var members: Array = (sites[site_id] as Dictionary)["slots"]
		var index: int = members.find(raw)
		return "%s · space %d" % [(sites[site_id] as Dictionary)["name"], index + 1]

	return label_for(value, choice_type)


## Публичная и без побочных эффектов — специально, чтобы подписи вариантов
## можно было проверять тестами: через них проходят решения всех 125 карт, а
## непонятная подпись ("48306" вместо "Advocate") делает игру неиграбельной
## вернее, чем упавший тест.
static func label_for(value: Variant, choice_type: String) -> String:
	# Пропуск: "" для целей-строк, -1 для индексов маркета.
	if typeof(value) == TYPE_STRING and String(value) == "":
		return "Skip"
	if typeof(value) == TYPE_INT and int(value) == -1:
		return "Skip"

	match choice_type:
		"confirm":
			return "Yes" if bool(value) else "No"
		"choose_option":
			return "Option %d" % (int(value) + 1)
		"target_card":
			return _card_label(String(value))
		"target_market_index":
			return "Market slot %d" % (int(value) + 1)
		"target_player":
			return EventLogPanel.player_name(String(value))
		"target_site":
			return "Site %s" % value
		"target_slot":
			return "Space %s" % value
		_:
			return str(value)


## Карты во Внутреннем круге эффекты кодируют как "inner:<id>" (см. DevourCard),
## поэтому префикс снимаем перед поиском названия.
static func _card_label(raw: String) -> String:
	var card_id := raw
	var suffix := ""
	if raw.begins_with("inner:"):
		card_id = raw.substr(6)
		suffix = " (from Inner Circle)"
	var data: Dictionary = CardLibrary.card_data(card_id)
	if data.is_empty():
		return raw
	return String(data.get("name", card_id)) + suffix


## Карты-варианты в ряд. Если не влезают в отведённую ширину — внахлёст
## лесенкой: каждая следующая ложится на предыдущую, от той остаётся видна
## левая полоска с названием (решение владельца, 2026-10-11).
class CardStairs extends Control:
	const GAP := 2.0
	## Уже этого полоска карты не бывает, даже если лесенка вылезет за край.
	const MIN_STEP := 8.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	func natural_width() -> float:
		var n := get_child_count()
		return CARD_SIZE.x * n + GAP * maxi(n - 1, 0)

	func arrange(max_width: float) -> void:
		var n := get_child_count()
		var w := CARD_SIZE.x
		var step := w + GAP
		if n > 1 and w + step * (n - 1) > max_width:
			step = maxf(floorf((max_width - w) / float(n - 1)), MIN_STEP)
		for i in n:
			var card := get_child(i) as Control
			card.position = Vector2(step * i, 0)
			card.size = CARD_SIZE
		custom_minimum_size = Vector2(w + step * maxi(n - 1, 0), CARD_SIZE.y) if n > 0 else Vector2.ZERO
