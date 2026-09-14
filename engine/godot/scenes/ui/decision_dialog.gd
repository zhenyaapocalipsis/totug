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
const OPTION_HEIGHT := 34
const MAX_LIST_HEIGHT := 380
const WIDTH := 460.0

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

	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.16, 0.15, 0.20, 0.97)
	_style.border_color = Color(0.85, 0.65, 0.25)
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(8)
	_style.set_content_margin_all(12)
	_style.shadow_color = Color(0, 0, 0, 0.5)
	_style.shadow_size = 8
	add_theme_stylebox_override("panel", _style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	_who = Label.new()
	_who.add_theme_font_size_override("font_size", 12)
	col.add_child(_who)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 17)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_prompt)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)

	_options_box = VBoxContainer.new()
	_options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_box.add_theme_constant_override("separation", 4)
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
	_who.text = "%s decides" % EventLogPanel.player_name(decider)
	_who.modulate = EventLogPanel.player_color(decider)
	_style.border_color = BoardPanel.PLAYER_COLORS.get(decider, Color(0.85, 0.65, 0.25))
	_prompt.text = String(pd.get("prompt", "Choose an option"))

	for child in _options_box.get_children():
		_options_box.remove_child(child)
		child.queue_free()

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
		_add_note("Click a gold-highlighted target on the board.")
		if options.has(""):
			_add_button("Skip", "")
	else:
		# Если сервер прислал подписи вариантов (карты вида "Choose one:"),
		# берём их — только карта знает, что означает её вариант №2.
		var labels: Array = pd.get("option_labels", [])
		for i in range(options.size()):
			var text := String(labels[i]) if i < labels.size() and String(labels[i]) != "" \
				else _board_label(options[i], choice_type)
			_add_button(text, options[i])

	var rows: int = maxi(_options_box.get_child_count(), 1)
	_scroll.custom_minimum_size = Vector2(0, mini(rows * OPTION_HEIGHT, MAX_LIST_HEIGHT))
	_place(on_board or decider != viewer_id)


## Плашка у верхнего края (не закрывает доску) или окно по центру.
func _place(top: bool) -> void:
	at_top = top
	if at_top:
		set_anchors_preset(Control.PRESET_CENTER_TOP)
		grow_vertical = Control.GROW_DIRECTION_END
	else:
		set_anchors_preset(Control.PRESET_CENTER)
		grow_vertical = Control.GROW_DIRECTION_BOTH
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = 10.0 if at_top else 0.0
	offset_bottom = offset_top
	reset_size()


func _add_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(0.8, 0.8, 0.85)
	_options_box.add_child(label)


func _add_button(text: String, value: Variant) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, OPTION_HEIGHT - 4)
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
