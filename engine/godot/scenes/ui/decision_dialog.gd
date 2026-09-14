class_name DecisionDialog
extends PanelContainer

## Вопрос, который карта задаёт игроку посреди своего эффекта
## (PendingDecision). Через этот диалог проходят эффекты всех 125 карт, потому
## что любой выбор — "choose one", цель убийства, "you may...", какую карту
## сожрать — сервер отдаёт одинаково: prompt + choice_type + legal_options.
##
## Варианты подписываются по-разному в зависимости от choice_type: id карты
## превращается в её название, id слота остаётся как есть, bool — в Да/Нет,
## индекс варианта — в "Вариант N". Пустая строка и -1 в legal_options
## означают "отказаться" (эффекты вида "up to N" кладут туда пропуск).

signal option_chosen(answer: Variant)

## Статический снимок доски (StateView.board_snapshot) — нужен, чтобы
## подписывать цели по-человечески: "Caer Sidi · слот 2" вместо "c_n1:C4_0_1".
var board: Dictionary = {}

var _prompt: Label
var _who: Label
var _options_box: VBoxContainer
var _scroll: ScrollContainer


func _init() -> void:
	visible = false
	# Диалог висит поверх экрана по центру.
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(460, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.15, 0.20)
	style.border_color = Color(0.85, 0.65, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)

	_who = Label.new()
	_who.add_theme_font_size_override("font_size", 12)
	_who.modulate = Color(0.8, 0.75, 0.6)
	col.add_child(_who)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 16)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_prompt)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 240)
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

	var decider := String(pd.get("player_id", ""))
	visible = true
	_who.text = "Решает: %s" % decider
	_prompt.text = String(pd.get("prompt", "Выберите вариант"))

	for child in _options_box.get_children():
		child.queue_free()

	if decider != viewer_id:
		# Не наш вопрос: сам факт показываем (чтобы было видно, чего ждём),
		# но вариантов у нас нет — сервер их и не прислал.
		var waiting := Label.new()
		waiting.text = "Ждём ответа игрока %s." % decider
		_options_box.add_child(waiting)
		return

	var options: Array = pd.get("legal_options", [])
	var choice_type := String(pd.get("choice_type", ""))
	if options.is_empty():
		var none := Label.new()
		none.text = "Вариантов нет."
		_options_box.add_child(none)
		return

	# Цели на доске (войско/локация) выбираются кликом по самой доске — она
	# подсвечивает их жёлтым (см. board_panel.gd::_draw_decision_targets), а
	# не списком кнопок здесь. Кнопка остаётся только для "отказаться", если
	# решение необязательное ("up to N" кладёт "" в legal_options).
	if choice_type == "target_slot" or choice_type == "target_site" or choice_type == "target_return":
		var hint := Label.new()
		hint.text = "Кликните по подсвеченной цели на доске."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_options_box.add_child(hint)
		if options.has(""):
			var skip := Button.new()
			skip.text = "Отказаться"
			skip.alignment = HORIZONTAL_ALIGNMENT_LEFT
			skip.pressed.connect(func(): option_chosen.emit(""))
			_options_box.add_child(skip)
		return

	# Если сервер прислал подписи вариантов (карты вида "Choose one:"), берём
	# их — только карта знает, что означает её вариант №2.
	var labels: Array = pd.get("option_labels", [])
	for i in range(options.size()):
		var value: Variant = options[i]
		var button := Button.new()
		if i < labels.size() and String(labels[i]) != "":
			button.text = String(labels[i])
		else:
			button.text = _board_label(value, choice_type)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func(): option_chosen.emit(value))
		_options_box.add_child(button)


## Подпись цели на доске: id слота вида "c_n1:C4_0_1" человеку ничего не
## говорит, поэтому переводим его в название локации и номер места в ней.
## Если снимка доски нет (тесты подписей), откатываемся на общий label_for.
func _board_label(value: Variant, choice_type: String) -> String:
	if board.is_empty() or typeof(value) != TYPE_STRING:
		return label_for(value, choice_type)
	var raw := String(value)
	var sites: Dictionary = board.get("sites", {})
	var slots: Dictionary = board.get("slots", {})

	# Составные цели ReturnTroopOrSpy: "troop|<slot_id>" и "spy|<site_id>|<owner>".
	if raw.begins_with("troop|"):
		return "Войско: " + _board_label(raw.substr(6), "target_slot")
	if raw.begins_with("spy|"):
		var rest: PackedStringArray = raw.substr(4).rsplit("|", true, 1)
		if rest.size() == 2:
			return "Шпион игрока %s: %s" % [rest[1], _board_label(rest[0], "target_site")]

	if choice_type == "target_site" and sites.has(raw):
		return "%s (%d VP)" % [(sites[raw] as Dictionary)["name"], int((sites[raw] as Dictionary)["vp"])]

	if choice_type == "target_slot" and slots.has(raw):
		var site_id := String((slots[raw] as Dictionary)["site_id"])
		if site_id == "" or not sites.has(site_id):
			return "Туннель (%s)" % raw.get_slice(":", 1)
		var members: Array = (sites[site_id] as Dictionary)["slots"]
		var index: int = members.find(raw)
		return "%s · место %d" % [(sites[site_id] as Dictionary)["name"], index + 1]

	return label_for(value, choice_type)


## Публичная и без побочных эффектов — специально, чтобы подписи вариантов
## можно было проверять тестами: через них проходят решения всех 125 карт, а
## непонятная подпись ("48306" вместо "Advocate") делает игру неиграбельной
## вернее, чем упавший тест.
static func label_for(value: Variant, choice_type: String) -> String:
	# Пропуск: "" для целей-строк, -1 для индексов маркета.
	if typeof(value) == TYPE_STRING and String(value) == "":
		return "Отказаться"
	if typeof(value) == TYPE_INT and int(value) == -1:
		return "Отказаться"

	match choice_type:
		"confirm":
			return "Да" if bool(value) else "Нет"
		"choose_option":
			return "Вариант %d" % (int(value) + 1)
		"target_card":
			return _card_label(String(value))
		"target_market_index":
			return "Маркет, слот %d" % (int(value) + 1)
		"target_player":
			return "Игрок %s" % value
		"target_site":
			return "Локация %s" % value
		"target_slot":
			return "Слот %s" % value
		_:
			return str(value)


## Карты во Внутреннем круге эффекты кодируют как "inner:<id>" (см. DevourCard),
## поэтому префикс снимаем перед поиском названия.
static func _card_label(raw: String) -> String:
	var card_id := raw
	var suffix := ""
	if raw.begins_with("inner:"):
		card_id = raw.substr(6)
		suffix = " (из Внутреннего круга)"
	var data: Dictionary = CardLibrary.card_data(card_id)
	if data.is_empty():
		return raw
	return String(data.get("name", card_id)) + suffix
