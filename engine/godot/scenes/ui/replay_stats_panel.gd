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
## Правая колонка вкладки VP (итог по статьям, лучший ход, лидерство).
const SIDE_W := 310.0
## Сколько последних смен лидера показать списком.
const LEADS_SHOWN := 8
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
## Щелчок по графику VP перематывает реплей (turn_chosen); на итогах живой
## партии перематывать нечего.
var can_jump := true


func _init(stats_data: Dictionary, jump := true) -> void:
	stats = stats_data
	can_jump = jump
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
	var chart := vp_chart(stats, "VP AFTER EACH TURN (AS IF THE GAME ENDED THERE)" +
		(". CLICK TO JUMP" if can_jump else ""))
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var best: Dictionary = stats.get("best", {})
	if can_jump:
		chart.clicked.connect(func(i: int):
			turn_chosen.emit(int((turns[i] as Dictionary)["start"]))
			close())
	row.add_child(chart)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 3)
	side.custom_minimum_size.x = SIDE_W
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
	side.add_child(_heading("BEST TURN"))
	if int(best.get("gain", 0)) > 0:
		var pid := String(best["player"])
		side.add_child(_cell("%s +%d VP IN ROUND %d (GOLD MARK)" % [_short(pid), int(best["gain"]),
			int((turns[int(best["turn"])] as Dictionary)["round"])], player_colour(pid)))

	# Лидерство: полоса под графиком цвета лидера, здесь — сколько ходов
	# каждый вёл и последние смены лидера (раунд и кто вышел вперёд).
	var leads: Array = stats.get("leads", [])
	var who: Array = leader_list(stats)
	side.add_child(_heading("LEADER (STRIP UNDER THE CHART)"))
	var lead_grid := GridContainer.new()
	lead_grid.columns = 2
	lead_grid.add_theme_constant_override("h_separation", 8)
	lead_grid.add_theme_constant_override("v_separation", 2)
	side.add_child(lead_grid)
	for pid in ids():
		lead_grid.add_child(_cell(_short(pid), player_colour(pid)))
		lead_grid.add_child(_cell("LED %d TURNS" % who.count(pid), PixelTheme.TEXT))
	side.add_child(_cell("LEAD CHANGED %d TIMES%s" % [leads.size(),
		", LAST %d:" % LEADS_SHOWN if leads.size() > LEADS_SHOWN else (":" if leads.size() > 0 else "")],
		PixelTheme.TEXT_DIM))
	var change_grid := GridContainer.new()
	change_grid.columns = 4
	change_grid.add_theme_constant_override("h_separation", 6)
	change_grid.add_theme_constant_override("v_separation", 2)
	side.add_child(change_grid)
	for t in leads.slice(maxi(0, leads.size() - LEADS_SHOWN)):
		var pid := String(who[int(t)])
		change_grid.add_child(_cell("R%d" % int((turns[int(t)] as Dictionary)["round"]), PixelTheme.TEXT_DIM))
		change_grid.add_child(_cell(_short(pid), player_colour(pid)))
	return row


## Лидер после каждого хода (ReplayStats.leaders; старые данные — пересчёт).
static func leader_list(data: Dictionary) -> Array:
	if data.has("leaders"):
		return data["leaders"]
	var list: Array[String] = []
	for pid in data.get("ids", []):
		list.append(String(pid))
	return ReplayStats.leaders(data["turns"], list)


## График VP всех игроков после каждого хода, лучший ход — золотой меткой.
## Общий для этой вкладки и итогового экрана партии (GameOverPanel).
static func vp_chart(data: Dictionary, caption: String) -> LineChart:
	var series: Array = []
	for pid in data.get("ids", []):
		var points: Array[float] = []
		for t in data["turns"]:
			points.append(float((t as Dictionary)["vp"].get(pid, 0)))
		series.append({"colour": player_colour(String(pid)), "points": points,
			"name": EventLogPanel.player_name(String(pid))})
	var chart := LineChart.new(series, caption, func(i: int) -> String: return turn_title(data, i))
	var best: Dictionary = data.get("best", {})
	if int(best.get("gain", 0)) > 0:
		chart.marks[int(best["turn"])] = PixelTheme.GOLD
	# Полоса под графиком — цвет лидера после каждого хода.
	for pid in leader_list(data):
		chart.band.append(player_colour(String(pid)) if String(pid) != "" else Color(0, 0, 0, 0))
	return chart


## Итог партии одной строкой: лучший ход и сколько раз менялся лидер.
static func summary(data: Dictionary) -> String:
	var best: Dictionary = data.get("best", {})
	var text := "LEAD CHANGES: %d" % (data.get("leads", []) as Array).size()
	if int(best.get("gain", 0)) > 0:
		text = "BEST TURN: %s +%d VP (ROUND %d).  %s" % [
			EventLogPanel.player_name(String(best["player"])).to_upper(), int(best["gain"]),
			int((data["turns"][int(best["turn"])] as Dictionary)["round"]), text]
	return text


func _turn_title(i: int) -> String:
	return turn_title(stats, i)


## «TURN 34, ROUND 9, BOB» — для подписей и строки под графиком.
static func turn_title(data: Dictionary, i: int) -> String:
	var turns: Array = data["turns"]
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

## Владение сайтами по ходу партии (владелец, 2026-10-09: таблица чисел была
## непонятна): строка на сайт, слева направо — вся партия, клетка на ход
## цвета того, кто контролировал сайт после этого хода; справа — кто держал
## дольше всех.
func _build_map() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	var note := _cell("EACH ROW IS A SITE, MOST VP FIRST. LEFT TO RIGHT: THE WHOLE GAME, ONE STEP PER TURN. " +
		"COLOUR: WHO CONTROLLED THE SITE AFTER THAT TURN, DARK: NOBODY. RIGHT: WHO HELD IT LONGEST.",
		PixelTheme.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(note)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 10)
	col.add_child(legend)
	for pid in ids():
		var chip := ColorRect.new()
		chip.color = player_colour(pid)
		chip.custom_minimum_size = Vector2(6, 6)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		legend.add_child(chip)
		legend.add_child(_cell(EventLogPanel.player_name(pid).to_upper(), player_colour(pid)))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var timeline := SiteTimeline.new(stats, func(i: int) -> String: return _turn_title(i))
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(timeline)
	var readout := _cell(" ", PixelTheme.TEXT)
	col.add_child(readout)
	timeline.hovered.connect(func(text: String): readout.text = text if text != "" else " ")
	return col


## Полосы владения сайтами (вкладка MAP), рисуются целиком: имя, VP, клетки
## ходов, «кто дольше». Мышь над клеткой — hovered(строка: сайт, ход, чей).
class SiteTimeline extends Control:
	signal hovered(text: String)

	const ROW_H := 12.0
	const HEAD_H := 10.0
	const NAME_W := 120.0
	const VP_W := 18.0
	const MOST_W := 110.0
	const NOBODY := Color(0.16, 0.13, 0.2)

	var sites: Array
	var turns: Array
	var label_of: Callable
	var _hover := Vector2i(-1, -1)

	func _init(data: Dictionary, labeler: Callable) -> void:
		sites = data["sites"]
		turns = data["turns"]
		label_of = labeler
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(400, HEAD_H + ROW_H * sites.size())
		mouse_exited.connect(func():
			_hover = Vector2i(-1, -1)
			queue_redraw()
			hovered.emit(""))

	func _strip() -> Rect2:
		var x := NAME_W + VP_W
		return Rect2(x, HEAD_H, maxf(1.0, size.x - x - MOST_W), ROW_H * sites.size())

	func _cell_x(i: int) -> float:
		var r := _strip()
		return roundf(r.position.x + r.size.x * i / maxf(1.0, turns.size()))

	func _draw() -> void:
		var font := get_theme_font("font", "Label")
		var font_size := get_theme_font_size("font_size", "Label")
		var r := _strip()
		draw_string(font, Vector2(0, HEAD_H - 2), "SITE", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, PixelTheme.TEXT_DIM)
		draw_string(font, Vector2(NAME_W, HEAD_H - 2), "VP", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, PixelTheme.TEXT_DIM)
		draw_string(font, Vector2(r.end.x + 6, HEAD_H - 2), "LONGEST", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			PixelTheme.TEXT_DIM)
		# Начало каждого пятого раунда — подпись сверху и черта через все строки.
		for i in range(1, turns.size()):
			var rnd := int((turns[i] as Dictionary)["round"])
			if int((turns[i - 1] as Dictionary)["round"]) != rnd and (rnd == 1 or rnd % 5 == 0):
				var x := _cell_x(i)
				draw_line(Vector2(x, HEAD_H - 1), Vector2(x, r.end.y), PixelTheme.BORDER, 1.0)
				draw_string(font, Vector2(x + 2, HEAD_H - 2), "R%d" % rnd, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
					PixelTheme.TEXT_DIM)
		for row in sites.size():
			var s: Dictionary = sites[row]
			var y := HEAD_H + ROW_H * row
			var name_text := String(s["name"]).to_upper()
			if name_text.length() > 19:
				name_text = name_text.substr(0, 19)
			var base := y + ROW_H - 3
			draw_string(font, Vector2(0, base), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				PixelTheme.GOLD if _hover.y == row else PixelTheme.TEXT)
			draw_string(font, Vector2(NAME_W, base), str(int(s["vp"])), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				PixelTheme.GOLD)
			var held: Array = s.get("held", [])
			for i in turns.size():
				var owner := String(held[i]) if i < held.size() else ""
				var x0 := _cell_x(i)
				var x1 := _cell_x(i + 1)
				draw_rect(Rect2(x0, y + 2, maxf(1.0, x1 - x0), ROW_H - 4),
					EventLogPanel.player_color(owner) if owner != "" else NOBODY)
			var most := ""
			var most_n := 0
			var counts: Dictionary = s.get("turns", {})
			for pid: String in counts:
				if int(counts[pid]) > most_n:
					most = pid
					most_n = int(counts[pid])
			if most != "":
				var who := EventLogPanel.player_name(most).to_upper()
				draw_string(font, Vector2(r.end.x + 6, base), "%s %d" % [who.substr(0, 10), most_n],
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, EventLogPanel.player_color(most))
			else:
				draw_string(font, Vector2(r.end.x + 6, base), "NOBODY", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
					PixelTheme.TEXT_OFF)
		if _hover.x >= 0:
			var hx0 := _cell_x(_hover.x)
			var hx1 := _cell_x(_hover.x + 1)
			draw_rect(Rect2(hx0, r.position.y, maxf(1.0, hx1 - hx0), r.size.y), Color(1, 1, 1, 0.25))

	func _gui_input(event: InputEvent) -> void:
		var motion := event as InputEventMouseMotion
		if motion == null:
			return
		var r := _strip()
		var p := motion.position
		var cell := Vector2i(-1, -1)
		if r.has_point(p) and not turns.is_empty():
			cell = Vector2i(clampi(int((p.x - r.position.x) / r.size.x * turns.size()), 0, turns.size() - 1),
				clampi(int((p.y - r.position.y) / ROW_H), 0, sites.size() - 1))
		elif p.y >= r.position.y and p.y < r.end.y:
			cell = Vector2i(-1, clampi(int((p.y - r.position.y) / ROW_H), 0, sites.size() - 1))
		if cell == _hover:
			return
		_hover = cell
		queue_redraw()
		hovered.emit(text_at(cell))

	## «BLINGDENSTONE, TURN 34, ROUND 9, BOB: HELD BY ALICE».
	func text_at(cell: Vector2i) -> String:
		if cell.y < 0:
			return ""
		var s: Dictionary = sites[cell.y]
		var name_text := String(s["name"]).to_upper()
		if cell.x < 0:
			return "%s: %d VP" % [name_text, int(s["vp"])]
		var held: Array = s.get("held", [])
		var owner := String(held[cell.x]) if cell.x < held.size() else ""
		return "%s, %s: %s" % [name_text, label_of.call(cell.x),
			"HELD BY " + EventLogPanel.player_name(owner).to_upper() if owner != "" else "NOBODY HELD IT"]


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
	const BAND_H := 4.0

	## [{colour, points: Array[float], name}]
	var series: Array
	var title: String
	## Номер точки -> подпись в строке под графиком.
	var label_of: Callable
	## Отмеченные точки: номер -> цвет (черта снизу).
	var marks: Dictionary = {}
	## Полоса под графиком: цвет на каждую точку (прозрачный — пусто),
	## например лидер по VP после каждого хода.
	var band: Array = []
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
		var under := BAND_H + 2.0 if not band.is_empty() else 0.0
		return Rect2(LEFT, PAD, maxf(1.0, s.x - LEFT - PAD), maxf(1.0, s.y - PAD * 2.0 - under))

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
		for i in band.size():
			var colour: Color = band[i]
			if colour.a <= 0.0:
				continue
			var x0 := _point(i - 1, 0.0, n, top).x if i > 0 else r.position.x
			var x1 := _point(i + 1, 0.0, n, top).x if i + 1 < n else r.end.x
			var a := roundf((x0 + _point(i, 0.0, n, top).x) / 2.0) if i > 0 else x0
			var b := roundf((x1 + _point(i, 0.0, n, top).x) / 2.0) if i + 1 < n else x1
			_plot.draw_rect(Rect2(a, r.end.y + 2.0, maxf(1.0, b - a), BAND_H), colour)
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
