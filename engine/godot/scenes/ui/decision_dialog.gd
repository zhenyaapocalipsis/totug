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
## Выбор карты (promote, discard, devour...) — сетка мелких лиц карт вместо
## строк с названиями: карту узнают по арту, а полную читают через Alt.
const CARD_SIZE := Vector2(80, 76)
const CARD_COLUMNS_MAX := 6
const CARD_LIST_MAX_HEIGHT := 240

## Статический снимок доски (StateView.board_snapshot) — нужен, чтобы
## подписывать цели по-человечески: "Caer Sidi · space 2" вместо "c_n1:C4_0_1".
var board: Dictionary = {}

var _prompt: Label
var _who: Label
var _options_box: VBoxContainer
var _scroll: ScrollContainer
var _style: StyleBoxFlat
## Плашка сейчас у верхнего края (выбор цели на доске) — доске нужно отступить.
var at_top := false
var _market_display: Array = []
var _ghost_card := ""
var _dim: ColorRect


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


func _init() -> void:
	visible = false
	custom_minimum_size = Vector2(WIDTH, 0)

	_style = PixelTheme.box(Color(PixelTheme.PANEL_HI, 0.97), PixelTheme.GOLD, 1, 3, 2)
	add_theme_stylebox_override("panel", _style)

	# Затемнение всего экрана под выбором карт: верхнеуровневый узел, его не
	# раскладывает панель, и он же ловит клики мимо карт.
	_dim = ColorRect.new()
	_dim.top_level = true
	_dim.color = Color(0.02, 0.02, 0.03, 0.62)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	# top_level не наследует z окна — задаём свой: над рукой, под окном.
	_dim.z_index = 999
	add_child(_dim)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	add_child(col)

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
		return

	_market_display = (view.get("market", {}) as Dictionary).get("display", [])
	_ghost_card = String(view.get("ghost_market_card", ""))
	var decider := String(pd.get("player_id", ""))
	var choice_type := String(pd.get("choice_type", ""))
	var on_board: bool = BOARD_CHOICES.has(choice_type)
	var options: Array = pd.get("legal_options", [])
	visible = true
	_style.border_color = BoardPanel.PLAYER_COLORS.get(decider, Color(0.85, 0.65, 0.25))
	# Схема доски занимает всю свою зону, поэтому вопрос про цель НА ДОСКЕ
	# показываем одной узкой полосой сверху: имя ходящего и вопрос в строку.
	_who.text = "%s decides" % EventLogPanel.player_name(decider)
	_who.modulate = EventLogPanel.player_color(decider)
	_who.visible = not on_board
	var prompt_text := String(pd.get("prompt", "Choose an option"))
	_prompt.text = "%s: %s" % [EventLogPanel.player_name(decider), prompt_text] if on_board \
		else prompt_text

	for child in _options_box.get_children():
		_options_box.remove_child(child)
		child.queue_free()
	var cards_mode := false

	if decider != viewer_id:
		# Не наш вопрос: сам факт показываем (чтобы было видно, чего ждём),
		# но вариантов у нас нет — сервер их и не прислал.
		_add_note("Waiting for %s." % EventLogPanel.player_name(decider))
	elif options.is_empty():
		_add_note("No options.")
	elif on_board:
		# Цели на доске выбираются кликом по самой доске — она подсвечивает
		# их золотым (board_panel.gd::_draw_decision_targets). Кнопка остаётся
		# только для "отказаться", если решение необязательное.
		# Подсказку про золотую подсветку дописываем в ту же строку: каждая
		# лишняя строка полосы закрывает ряд локаций на схеме.
		_prompt.text += " — click a gold target on the board."
		if options.has(""):
			_add_button("Skip", "")
	elif choice_type == "target_card":
		_add_card_grid(options)
		if options.has(""):
			_add_button("Skip", "")
	elif _can_show_option_cards(pd):
		_add_option_cards(pd)
		cards_mode = true
	else:
		# Если сервер прислал подписи вариантов (карты вида "Choose one:"),
		# берём их — только карта знает, что означает её вариант №2.
		var labels: Array = pd.get("option_labels", [])
		for i in range(options.size()):
			var text := String(labels[i]) if i < labels.size() and String(labels[i]) != "" \
				else _board_label(options[i], choice_type)
			_add_button(text, options[i])

	# Пустой список вариантов не должен занимать место: на доске вопрос — это
	# одна строка, и лишние пиксели полосы закрывают схему.
	_set_cards_look(cards_mode, decider)
	_set_dim(_options_box.get_child_count() > 0 and (cards_mode or choice_type == "target_card"))
	var rows: int = _options_box.get_child_count()
	var max_h: float = CARD_LIST_MAX_HEIGHT if choice_type == "target_card" else MAX_LIST_HEIGHT
	if _options_box.get_child_count() > 0 and _options_box.get_child(0) is HBoxContainer:
		max_h = INF  # карты-варианты не прокручиваются: их всего два-три
	_scroll.custom_minimum_size = Vector2(0, minf(_options_box.get_combined_minimum_size().y, max_h))
	_scroll.visible = rows > 0
	_place(on_board or decider != viewer_id)
	# Вопрос с переносом слов знает свою высоту только после раскладки по новой
	# ширине: до неё окно карт-вариантов выходило вдвое выше содержимого.
	_place.call_deferred(on_board or decider != viewer_id)


## Плашка у верхнего края (не закрывает доску) или окно по центру.
func _place(top: bool) -> void:
	at_top = top
	if at_top:
		# Полоса во всю ширину доски: так вопрос влезает в одну-две строки и
		# закрывает минимум схемы.
		set_anchors_preset(Control.PRESET_TOP_WIDE)
		grow_vertical = Control.GROW_DIRECTION_END
		custom_minimum_size = Vector2.ZERO
		offset_left = 2.0
		offset_right = -2.0
	else:
		set_anchors_preset(Control.PRESET_CENTER)
		grow_vertical = Control.GROW_DIRECTION_BOTH
		custom_minimum_size = Vector2(WIDTH, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	if at_top:
		# Ширину задают якоря (во всю доску), высоту — содержимое.
		offset_left = 2.0
		offset_right = -2.0
		offset_top = 2.0
		offset_bottom = 2.0 + get_combined_minimum_size().y
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
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(0.8, 0.8, 0.85)
	_options_box.add_child(label)


## Мелкие карты-кнопки. Одинаковые карты (два Soldier в руке) показываются
## каждая отдельно — ответ у них один и тот же id, серверу это безразлично.
## "inner:<id>" — карта из Внутреннего круга: лицо то же, в ответ уходит
## исходная строка с префиксом.
func _add_card_grid(options: Array) -> void:
	var ids: Array = options.filter(func(o): return typeof(o) == TYPE_STRING and String(o) != "")
	if ids.is_empty():
		return
	var grid := GridContainer.new()
	grid.columns = mini(ids.size(), CARD_COLUMNS_MAX)
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for raw in ids:
		var value := String(raw)
		var cid := value.substr(6) if value.begins_with("inner:") else value
		var card := CardView.new(cid, int(CARD_SIZE.x), int(CARD_SIZE.y))
		card.set_clickable(true)
		card.tooltip_text = _card_label(value)
		card.pressed.connect(func(_id): option_chosen.emit(value))
		grid.add_child(card)
	_options_box.add_child(grid)


## Выбор карты затемняет весь экран: окно поднимается над рукой (её поднятая
## карта рисуется с z_index до 901) и маркетом, как окно стопки.
func _set_dim(on: bool) -> void:
	_dim.visible = on
	z_index = 1000 if on else 0
	if on and is_inside_tree():
		_dim.position = Vector2.ZERO
		_dim.size = get_viewport_rect().size


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
		else BoardPanel.PLAYER_COLORS.get(decider, Color(0.85, 0.65, 0.25))
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
	for label in labels:
		if String(label) == "":
			return false
	return true


## Карты-варианты в ряд, между ними "or".
func _add_option_cards(pd: Dictionary) -> void:
	var options: Array = pd.get("legal_options", [])
	var labels: Array = pd.get("option_labels", [])
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
		var card := OptionCard.new(String(pd.get("source_card", "")), String(labels[i]))
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
