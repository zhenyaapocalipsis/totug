extends Control

## Экран STATS просмотрщика реплея (этап Replay-3) — поверх партии, как итоги.
## Данные — ReplayStats.collect(). Вкладки:
##   VP        — график VP всех игроков по ходам (будь партия окончена в этот
##               момент), лучший ход, смены лидера, разбивка VP в конце;
##   RESOURCES — Power и Influence, полученные за каждый свой ход, по раундам;
##   ACTIONS   — сколько чего сделал каждый за партию;
##   BUYS      — покупки по раундам;
##   MAP       — сколько ходов каждый держал каждый сайт.
## Под графиком строка с числами точки под мышью (подсказок при наведении в
## игре нет — владелец, 2026-10-06). Щелчок по графику VP — перемотать реплей
## на этот ход (turn_chosen).

signal turn_chosen(position: int)
signal closed

const TABS: Array[String] = ["VP", "RESOURCES", "ACTIONS", "BUYS", "MAP"]
const PANEL_SIZE := Vector2(900, 470)
const VP_PART_NAMES := {"sites": "SITES", "total_control": "TOTAL CONTROL", "trophies": "TROPHIES",
	"deck": "DECK", "inner_circle": "INNER CIRCLE", "tokens": "VP TOKENS"}
const ACTION_NAMES := {"played": "CARDS PLAYED", "bought": "CARDS BOUGHT", "deployed": "TROOPS DEPLOYED",
	"kills": "ASSASSINATED", "spies": "SPIES PLACED", "returns": "RETURNED", "devoured": "DEVOURED",
	"promoted": "PROMOTED"}

var stats: Dictionary
var _pages: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _body: Control
var _tab := ""


func _init(stats_data: Dictionary) -> void:
	stats = stats_data
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
	title.text = "GAME STATS"
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.custom_minimum_size.x = 80
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(title)
	var group := ButtonGroup.new()
	for tab in TABS:
		var b := _button(tab, func(): show_tab(tab), 70)
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


## Esc закрывает экран (раньше, чем меню паузы).
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
		match tab:
			"RESOURCES":
				page = _build_resources()
			"ACTIONS":
				page = _build_actions()
			"BUYS":
				page = _build_buys()
			"MAP":
				page = _build_map()
			_:
				page = _build_vp()
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		_pages[tab] = page
		_body.add_child(page)
	for key: String in _pages:
		(_pages[key] as Control).visible = key == tab
	_tab = tab
	(_tab_buttons[tab] as Button).button_pressed = true


func ids() -> Array[String]:
	var list: Array[String] = []
	for pid in stats.get("ids", []):
		list.append(String(pid))
	return list


static func player_colour(pid: String) -> Color:
	return EventLogPanel.player_color(pid)


# --- VP ---------------------------------------------------------------------

func _build_vp() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var turns: Array = stats["turns"]
	var series: Array = []
	for pid in ids():
		var points: Array[float] = []
		for t in turns:
			points.append(float((t as Dictionary)["vp"].get(pid, 0)))
		series.append({"colour": player_colour(pid), "points": points, "name": EventLogPanel.player_name(pid)})
	var chart := LineChart.new(series, "VP AFTER EACH TURN (AS IF THE GAME ENDED THERE). CLICK TO JUMP",
		func(i: int) -> String: return _turn_title(i))
	chart.custom_minimum_size = Vector2(560, 0)
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var best: Dictionary = stats.get("best", {})
	if int(best.get("gain", 0)) > 0:
		chart.marks[int(best["turn"])] = PixelTheme.GOLD
	chart.clicked.connect(func(i: int):
		turn_chosen.emit(int((turns[i] as Dictionary)["start"]))
		close())
	row.add_child(chart)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 3)
	row.add_child(side)
	side.add_child(_heading("FINAL VP"))
	var grid := GridContainer.new()
	grid.columns = ids().size() + 1
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	side.add_child(grid)
	grid.add_child(_cell("", PixelTheme.TEXT_DIM))
	for pid in ids():
		grid.add_child(_cell(_short(pid), player_colour(pid)))
	var parts: Dictionary = stats["parts"]
	for key: String in PlayerProfile.VP_PARTS:
		grid.add_child(_cell(VP_PART_NAMES[key], PixelTheme.TEXT_DIM))
		for pid in ids():
			grid.add_child(_cell(str(int(parts[pid].get(key, 0))), PixelTheme.TEXT))
	grid.add_child(_cell("TOTAL", PixelTheme.GOLD))
	for pid in ids():
		grid.add_child(_cell(str(int(parts[pid].get("total", 0))), PixelTheme.GOLD))

	side.add_child(HSeparator.new())
	side.add_child(_heading("TURNING POINTS"))
	if int(best.get("gain", 0)) > 0:
		var pid := String(best["player"])
		side.add_child(_cell("BEST TURN: %s +%d VP" % [EventLogPanel.player_name(pid).to_upper(), int(best["gain"])],
			player_colour(pid)))
		side.add_child(_cell("  (%s, GOLD MARK)" % _turn_title(int(best["turn"])), PixelTheme.TEXT_DIM))
	var leads: Array = stats.get("leads", [])
	side.add_child(_cell("LEAD CHANGES: %d" % leads.size(), PixelTheme.TEXT))
	for t in leads.slice(maxi(0, leads.size() - 4)):
		var vp: Dictionary = turns[int(t)]["vp"]
		var top := ids()[0]
		for pid in ids():
			if int(vp[pid]) > int(vp[top]):
				top = pid
		side.add_child(_cell("  %s TAKES THE LEAD, %s" % [EventLogPanel.player_name(top).to_upper(),
			_turn_title(int(t))], player_colour(top)))
	return row


## «TURN 34, ROUND 9, BOB» — для подписей и строки под графиком.
func _turn_title(i: int) -> String:
	var turns: Array = stats["turns"]
	if i <= 0 or i >= turns.size():
		return "SETUP"
	var t: Dictionary = turns[i]
	return "TURN %d, ROUND %d, %s" % [i, int(t["round"]), EventLogPanel.player_name(String(t["player"])).to_upper()]


# --- RESOURCES --------------------------------------------------------------

func _build_resources() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var charts := VBoxContainer.new()
	charts.add_theme_constant_override("separation", 6)
	charts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(charts)
	var averages := {}
	for res: String in ["power", "influence"]:
		var series: Array = []
		for pid in ids():
			var points: Array[float] = []
			for t in stats["turns"]:
				if String((t as Dictionary)["player"]) == pid:
					points.append(float(t[res]))
			averages["%s/%s" % [pid, res]] = _average(points)
			series.append({"colour": player_colour(pid), "points": points, "name": EventLogPanel.player_name(pid)})
		var chart := LineChart.new(series, "%s GAINED EACH ROUND" % res.to_upper(),
			func(i: int) -> String: return "ROUND %d" % (i + 1))
		chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
		charts.add_child(chart)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 3)
	row.add_child(side)
	side.add_child(_heading("AVERAGE PER TURN"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	side.add_child(grid)
	grid.add_child(_cell("", PixelTheme.TEXT_DIM))
	grid.add_child(_cell("POWER", GameScreen.POWER_COLOR))
	grid.add_child(_cell("INFLUENCE", GameScreen.INFLUENCE_COLOR))
	for pid in ids():
		grid.add_child(_cell(_short(pid), player_colour(pid)))
		grid.add_child(_cell("%.1f" % float(averages["%s/power" % pid]), PixelTheme.TEXT))
		grid.add_child(_cell("%.1f" % float(averages["%s/influence" % pid]), PixelTheme.TEXT))
	return row


static func _average(points: Array[float]) -> float:
	if points.is_empty():
		return 0.0
	var sum := 0.0
	for p in points:
		sum += p
	return sum / points.size()


# --- ACTIONS ----------------------------------------------------------------

func _build_actions() -> Control:
	var centre := CenterContainer.new()
	var grid := GridContainer.new()
	grid.columns = ids().size() + 1
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	centre.add_child(grid)
	grid.add_child(_cell("", PixelTheme.TEXT_DIM))
	for pid in ids():
		grid.add_child(_cell(_short(pid), player_colour(pid)))
	var counts: Dictionary = stats["counts"]
	for action: String in ReplayStats.ACTION_ORDER:
		grid.add_child(_cell(ACTION_NAMES[action], PixelTheme.TEXT_DIM))
		var top := 0
		for pid in ids():
			top = maxi(top, int(counts[pid][action]))
		for pid in ids():
			var n := int(counts[pid][action])
			grid.add_child(_cell(str(n), PixelTheme.GOLD if n == top and n > 0 else PixelTheme.TEXT))
	return centre


# --- BUYS -------------------------------------------------------------------

func _build_buys() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)
	var turns: Array = stats["turns"]
	for pid in ids():
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var buys: Array = stats["buys"][pid]
		col.add_child(_cell("%s: %d CARDS" % [_short(pid), buys.size()], player_colour(pid)))
		for b in buys:
			var t := int((b as Dictionary)["turn"])
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 4)
			col.add_child(line)
			var round_no := int((turns[t] as Dictionary)["round"]) if t < turns.size() else 0
			var when := _cell("R%d" % round_no, PixelTheme.TEXT_DIM)
			when.custom_minimum_size.x = 18
			line.add_child(when)
			var cid := String(b["card"])
			var aspect := CardLibrary.card_aspect(cid)
			line.add_child(_cell(String(CardLibrary.card_data(cid).get("name", cid)).to_upper(),
				(CardView.ASPECT_COLORS.get(aspect, PixelTheme.TEXT) as Color).lightened(0.3)))
	return scroll


# --- MAP --------------------------------------------------------------------

func _build_map() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	centre.add_child(col)
	col.add_child(_cell("TURNS EACH PLAYER CONTROLLED EACH SITE", PixelTheme.TEXT_DIM))
	var sites: Array = stats["sites"]
	var columns := 2 if sites.size() > 12 else 1
	var grid := GridContainer.new()
	grid.columns = (ids().size() + 2) * columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	col.add_child(grid)
	for c in columns:
		grid.add_child(_cell("SITE", PixelTheme.TEXT_DIM))
		grid.add_child(_cell("VP", PixelTheme.TEXT_DIM))
		for pid in ids():
			grid.add_child(_cell(_short(pid), player_colour(pid)))
	for s in sites:
		var held: Dictionary = (s as Dictionary)["turns"]
		grid.add_child(_cell(String(s["name"]).to_upper(), PixelTheme.TEXT))
		grid.add_child(_cell(str(int(s["vp"])), PixelTheme.GOLD))
		var top := 0
		for pid in ids():
			top = maxi(top, int(held.get(pid, 0)))
		for pid in ids():
			var n := int(held.get(pid, 0))
			grid.add_child(_cell(str(n) if n > 0 else "-",
				player_colour(pid) if n == top and n > 0 else PixelTheme.TEXT_DIM))
	return scroll


# --- мелочи -----------------------------------------------------------------

## Имя игрока капсом, не длиннее 8 знаков (колонки таблиц узкие).
func _short(pid: String) -> String:
	var name := EventLogPanel.player_name(pid).to_upper()
	return name if name.length() <= 8 else name.substr(0, 8)


func _heading(text: String) -> Label:
	return GameScreen.section_label(text)


func _cell(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", colour)
	return label


func _button(text: String, action: Callable, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 14)
	b.focus_mode = Control.FOCUS_NONE
	SetupScreen._style_button(b)
	b.pressed.connect(action)
	return b


## Линейный график в пиксельном стиле: рамка, сетка с подписями слева, по
## линии на игрока (отрезки в пиксель, без сглаживания). Мышь над графиком —
## вертикальная черта и строка чисел под графиком; щелчок — clicked(номер точки).
class LineChart extends VBoxContainer:
	signal clicked(index: int)

	const LEFT := 22.0
	const PAD := 3.0

	## [{colour, points: Array[float], name}]
	var series: Array
	var title: String
	## Номер точки -> подпись в строке под графиком.
	var label_of: Callable
	## Отмеченные точки: номер -> цвет (черта снизу).
	var marks: Dictionary = {}
	var _plot: Control
	var _readout: Label
	var _hover := -1

	func _init(data: Array, caption: String, labeler: Callable) -> void:
		series = data
		title = caption
		label_of = labeler
		add_theme_constant_override("separation", 2)
		var head := Label.new()
		head.text = caption
		head.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
		add_child(head)
		_plot = Control.new()
		_plot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_plot.custom_minimum_size = Vector2(200, 80)
		_plot.mouse_filter = Control.MOUSE_FILTER_STOP
		_plot.draw.connect(_draw_plot)
		_plot.gui_input.connect(_on_input)
		_plot.mouse_exited.connect(func():
			_hover = -1
			_update_readout())
		add_child(_plot)
		_readout = Label.new()
		_readout.add_theme_color_override("font_color", PixelTheme.TEXT)
		add_child(_readout)
		_update_readout()

	func count() -> int:
		var n := 0
		for s in series:
			n = maxi(n, (s["points"] as Array).size())
		return n

	func top_value() -> float:
		var top := 1.0
		for s in series:
			for p in s["points"]:
				top = maxf(top, float(p))
		return top

	## Шаг сетки: 1, 2, 5, 10, 20, 50 — чтобы линий было не больше пяти.
	func grid_step(top: float) -> float:
		for step in [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0]:
			if top / step <= 5.0:
				return step
		return 200.0

	func _area() -> Rect2:
		var s := _plot.size
		return Rect2(LEFT, PAD, maxf(1.0, s.x - LEFT - PAD), maxf(1.0, s.y - PAD * 2.0))

	func _point(i: int, value: float, n: int, top: float) -> Vector2:
		var r := _area()
		var x := r.position.x + (r.size.x * i / maxf(1.0, n - 1.0))
		var y := r.position.y + r.size.y - r.size.y * value / top
		return Vector2(roundf(x), roundf(y))

	func _draw_plot() -> void:
		var r := _area()
		var n := count()
		var top := top_value()
		var step := grid_step(top)
		top = ceilf(top / step) * step
		var font := get_theme_font("font", "Label")
		var font_size := get_theme_font_size("font_size", "Label")
		_plot.draw_rect(r, PixelTheme.PANEL_LO)
		var v := 0.0
		while v <= top + 0.01:
			var y := roundf(r.position.y + r.size.y - r.size.y * v / top)
			_plot.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), PixelTheme.BORDER, 1.0)
			_plot.draw_string(font, Vector2(0, y + 3), str(int(v)), HORIZONTAL_ALIGNMENT_RIGHT, LEFT - 3,
				font_size, PixelTheme.TEXT_DIM)
			v += step
		for i: int in marks:
			var p := _point(i, 0.0, n, top)
			_plot.draw_rect(Rect2(p.x - 1, r.end.y - 3, 3, 3), marks[i])
		if _hover >= 0:
			var hx := _point(_hover, 0.0, n, top).x
			_plot.draw_line(Vector2(hx, r.position.y), Vector2(hx, r.end.y), PixelTheme.TEXT_DIM, 1.0)
		for s in series:
			var points: Array = s["points"]
			for i in range(1, points.size()):
				_plot.draw_line(_point(i - 1, float(points[i - 1]), n, top), _point(i, float(points[i]), n, top),
					s["colour"], 1.0)
			if _hover >= 0 and _hover < points.size():
				var p := _point(_hover, float(points[_hover]), n, top)
				_plot.draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), s["colour"])

	func _on_input(event: InputEvent) -> void:
		var motion := event as InputEventMouseMotion
		var button := event as InputEventMouseButton
		var x := 0.0
		if motion != null:
			x = motion.position.x
		elif button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			x = button.position.x
		else:
			return
		var r := _area()
		var n := count()
		var i := clampi(roundi((x - r.position.x) / r.size.x * (n - 1)), 0, maxi(0, n - 1))
		if i != _hover:
			_hover = i
			_update_readout()
		if button != null:
			clicked.emit(i)

	func _update_readout() -> void:
		_plot.queue_redraw()
		if _hover < 0:
			_readout.text = " "
			return
		var parts: Array[String] = [label_of.call(_hover)]
		for s in series:
			var points: Array = s["points"]
			if _hover < points.size():
				parts.append("%s %d" % [String(s["name"]).to_upper(), int(points[_hover])])
		_readout.text = ":  ".join(parts.slice(0, 1)) + ":  " + "  ".join(parts.slice(1))
