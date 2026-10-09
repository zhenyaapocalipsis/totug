extends Control

## Сводка по многим партиям (этап Replay-4) — окно ALL GAMES в профиле,
## поверх меню. Данные — выжимки партий истории (ReplayStats.history_summaries,
## сводит ReplayStats.aggregate). Вкладки:
##   CARDS       — карты, которые ты покупал: в скольких партиях, сколько копий,
##                 как часто ты побеждал, купив её;
##   PLAY        — средние за партию: VP, Power и Influence за ход, действия —
##                 во всех партиях, в победах и в поражениях отдельно;
##   VP BY ROUND — твои средние VP к концу каждого раунда в победах и в
##                 поражениях и VP лучшего соперника.

signal closed

const TABS: Array[String] = ["CARDS", "PLAY", "VP BY ROUND"]
const PANEL_SIZE := Vector2(900, 470)
const BAR_W := 60
const WIN_COLOUR := Color("5fd36a")
const ReplayStatsPanelScript := preload("res://scenes/ui/replay_stats_panel.gd")

var data: Dictionary
var _pages: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _body: Control
var _tab := ""


func _init(dir: String = ReplayBook.DIR) -> void:
	data = ReplayStats.aggregate(ReplayStats.history_summaries(dir))
	# Окно меню меньше экрана — сводка ложится на весь экран, как в партии.
	top_level = true
	theme = PixelTheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 1060
	var dim := ColorRect.new()
	dim.color = PixelTheme.DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", GameScreen.zone_style(4))
	frame.custom_minimum_size = PANEL_SIZE
	centre.add_child(frame)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	frame.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 2)
	col.add_child(top)
	var title := Label.new()
	title.text = "ALL GAMES: %d" % int(data["games"])
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.custom_minimum_size.x = 80
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(title)
	var group := ButtonGroup.new()
	for tab in TABS:
		var b := _button(tab, func(): show_tab(tab), 80)
		b.toggle_mode = true
		b.button_group = group
		_tab_buttons[tab] = b
		top.add_child(b)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	top.add_child(_button("CLOSE", func(): close(), 50))
	col.add_child(HSeparator.new())
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(PANEL_SIZE.x - 8, PANEL_SIZE.y - 40)
	col.add_child(_body)
	show_tab(TABS[0])


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if visible and key.pressed and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func current_tab() -> String:
	return _tab


func show_tab(tab: String) -> void:
	if not _pages.has(tab):
		var page: Control
		if int(data["games"]) == 0:
			page = _empty()
		else:
			match tab:
				"PLAY":
					page = _build_play()
				"VP BY ROUND":
					page = _build_curve()
				_:
					page = _build_cards()
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		_pages[tab] = page
		_body.add_child(page)
	for key: String in _pages:
		(_pages[key] as Control).visible = key == tab
	_tab = tab
	(_tab_buttons[tab] as Button).button_pressed = true


func _empty() -> Control:
	var centre := CenterContainer.new()
	centre.add_child(_cell("No replays to analyse yet: finish an online game.", PixelTheme.TEXT_DIM))
	return centre


func _win_rate() -> float:
	return float(data["wins"]) / maxf(1.0, float(data["games"]))


# --- CARDS ------------------------------------------------------------------

func _build_cards() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var overall := _win_rate()
	var note := _cell("CARDS YOU BOUGHT. WIN %: HOW OFTEN YOU WON THE GAMES WHERE YOU BOUGHT IT " +
		"(ALL YOUR GAMES: %d%%). GREEN: ABOVE THAT, RED: BELOW." % roundi(overall * 100.0), PixelTheme.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 2)
	centre.add_child(grid)
	for header in ["CARD", "GAMES", "COPIES", "WIN %", ""]:
		grid.add_child(_cell(header, PixelTheme.TEXT_DIM))
	var cards: Dictionary = data["cards"]
	var ids: Array = cards.keys()
	ids.sort_custom(func(a, b) -> bool:
		var x: Dictionary = cards[a]
		var y: Dictionary = cards[b]
		if int(x["games"]) != int(y["games"]):
			return int(x["games"]) > int(y["games"])
		return float(x["wins"]) / int(x["games"]) > float(y["wins"]) / int(y["games"]))
	for cid: String in ids:
		var c: Dictionary = cards[cid]
		var rate := float(c["wins"]) / int(c["games"])
		var aspect := CardLibrary.card_aspect(cid)
		grid.add_child(_cell(String(CardLibrary.card_data(cid).get("name", cid)).to_upper(),
			(CardView.ASPECT_COLORS.get(aspect, PixelTheme.TEXT) as Color).lightened(0.3)))
		grid.add_child(_cell(str(int(c["games"])), PixelTheme.TEXT))
		grid.add_child(_cell(str(int(c["copies"])), PixelTheme.TEXT))
		var colour := WIN_COLOUR if rate > overall + 0.001 else (PixelTheme.DANGER if rate < overall - 0.001 else PixelTheme.TEXT)
		grid.add_child(_cell("%d%%" % roundi(rate * 100.0), colour))
		grid.add_child(_bar(rate, colour))
	return col


# --- PLAY -------------------------------------------------------------------

func _build_play() -> Control:
	var centre := CenterContainer.new()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	centre.add_child(col)
	col.add_child(_cell("AVERAGE PER GAME: ALL YOUR GAMES, THE ONES YOU WON AND THE ONES YOU LOST", PixelTheme.TEXT_DIM))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	col.add_child(grid)
	var groups: Dictionary = data["groups"]
	grid.add_child(_cell("", PixelTheme.TEXT_DIM))
	grid.add_child(_cell("ALL", PixelTheme.GOLD))
	grid.add_child(_cell("WINS", WIN_COLOUR))
	grid.add_child(_cell("LOSSES", PixelTheme.DANGER))
	var rows: Array = [["GAMES", func(g: Dictionary) -> String: return str(int(g["games"]))],
		["VP", func(g: Dictionary) -> String: return _avg(g, float(g["vp"]))],
		["POWER PER TURN", func(g: Dictionary) -> String: return _avg(g, float(g["power"]))],
		["INFLUENCE PER TURN", func(g: Dictionary) -> String: return _avg(g, float(g["influence"]))]]
	for action: String in ReplayStats.ACTION_ORDER:
		rows.append([String(ReplayStatsPanelScript.ACTION_NAMES[action]),
			func(g: Dictionary) -> String: return _avg(g, float(g["counts"][action]))])
	for row in rows:
		grid.add_child(_cell(String(row[0]), PixelTheme.TEXT_DIM))
		for key in ["all", "wins", "losses"]:
			grid.add_child(_cell((row[1] as Callable).call(groups[key]), PixelTheme.TEXT))
	return centre


func _avg(group: Dictionary, sum: float) -> String:
	var games := int(group["games"])
	return "-" if games == 0 else "%.1f" % (sum / games)


# --- VP BY ROUND ------------------------------------------------------------

func _build_curve() -> Control:
	var curve: Dictionary = data["curve"]
	var series: Array = []
	for s in [["wins", "YOU WHEN YOU WON", WIN_COLOUR], ["losses", "YOU WHEN YOU LOST", PixelTheme.DANGER],
			["rival", "BEST RIVAL", PixelTheme.TEXT_DIM]]:
		series.append({"colour": s[2], "points": curve.get(s[0], []), "name": s[1]})
	var chart := ReplayStatsPanelScript.LineChart.new(series,
		"AVERAGE VP AT THE END OF EACH ROUND. GREEN: YOU IN GAMES YOU WON, RED: IN GAMES YOU LOST, GREY: THE BEST RIVAL",
		func(i: int) -> String: return "ROUND %d" % (i + 1))
	return chart


# --- мелочи -----------------------------------------------------------------

func _cell(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", colour)
	return label


## Полоска доли (0..1), как в профиле.
func _bar(share: float, colour: Color) -> Control:
	var back := ColorRect.new()
	back.color = PixelTheme.PANEL_LO
	back.custom_minimum_size = Vector2(BAR_W, 5)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := ColorRect.new()
	fill.color = colour
	fill.size = Vector2(roundf(BAR_W * clampf(share, 0.0, 1.0)), 5)
	back.add_child(fill)
	return back


func _button(text: String, action: Callable, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 14)
	b.focus_mode = Control.FOCUS_NONE
	SetupScreen._style_button(b)
	b.pressed.connect(action)
	return b
