class_name PlayerProfilePanel
extends Control

## Профиль другого игрока (владелец, 2026-10-15) — окно поверх меню, открывается
## кнопкой PROFILE на карточке игрока (LEADERBOARD) и у друга (FRIENDS).
## Данные — с сервера (NetSession.request_player → ProfileBook): карточка,
## многоугольник средних рядом со своим для сравнения и его последние партии.
## WATCH качает запись партии с сервера и открывает её как обычный реплей —
## глазами этого игрока.

signal replay_requested(file: String)
signal closed

const PANEL_SIZE := Vector2(720, 430)
## Цвет чужого многоугольника (свой — ProfileScreen.MINE_COLOUR).
const THEIR_COLOUR := Color("6ab8ff")
const HISTORY_H := 300.0
## Реплей с сервера ложится к своим под этим началом имени.
const NET_PREFIX := "net_"

var player_name := ""
var _net: NetSession
var _body: VBoxContainer
var _status: Label
## Запись какой партии ждём с сервера: [файл, место игрока] или [].
var _waiting: Array = []


func _init(net: NetSession, name_text: String) -> void:
	_net = net
	player_name = name_text
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
	col.add_child(top)
	var title := Label.new()
	title.text = "PROFILE: %s" % name_text
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(50, 14)
	close_button.focus_mode = Control.FOCUS_NONE
	SetupScreen._style_button(close_button)
	close_button.pressed.connect(close)
	top.add_child(close_button)
	col.add_child(HSeparator.new())
	_status = ProfileScreen._cell("Loading the profile...", PixelTheme.TEXT_DIM)
	col.add_child(_status)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 4)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)
	if net != null:
		net.player_received.connect(_on_player)
		net.record_received.connect(_on_record)
		net.request_player(name_text)
	if net == null or not net.is_connected_to_server():
		_status.text = "No connection to the server."


func _exit_tree() -> void:
	if _net != null and _net.player_received.is_connected(_on_player):
		_net.player_received.disconnect(_on_player)
		_net.record_received.disconnect(_on_record)


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _on_player(data: Dictionary) -> void:
	if RatingBook.name_id(String(data.get("name", ""))) != RatingBook.name_id(player_name):
		return
	show_data(data)


## Ответ сервера: карточка слева, многоугольник посередине, партии справа.
func show_data(data: Dictionary) -> void:
	for child in _body.get_children():
		child.queue_free()
	if data.get("missing", false):
		_status.text = "No player named %s." % player_name
		return
	_status.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	row.add_child(left)
	ProfileCard.fill(left, "", data)
	left.add_child(HSeparator.new())
	left.add_child(GameScreen.section_label("AVERAGE PER GAME"))
	var theirs := PlayerProfile.clean_totals(data.get("totals", {}))
	var mine := PlayerProfile.totals()
	if int(theirs["games"]) == 0:
		left.add_child(ProfileScreen._cell("No finished online games yet.",
			PixelTheme.TEXT_DIM))
	else:
		left.add_child(_legend(String(data.get("name", player_name)), int(mine["games"]) > 0))
		var pairs := [[theirs, THEIR_COLOUR]]
		if int(mine["games"]) > 0:
			pairs.append([mine, ProfileScreen.MINE_COLOUR])
		left.add_child(ProfileScreen.average_vp_row(pairs))
		var chart := RadarChart.new()
		for pair: Array in pairs:
			chart.add_series(PlayerProfile.averages(pair[0]), pair[1])
		left.add_child(chart)

	row.add_child(VSeparator.new())
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var history: Array = data.get("history", [])
	right.add_child(GameScreen.section_label("ONLINE GAMES: %d" % history.size() if not history.is_empty()
		else "ONLINE GAMES"))
	if history.is_empty():
		right.add_child(ProfileScreen._cell("No games recorded yet.", PixelTheme.TEXT_DIM))
		return
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = HISTORY_H
	right.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(grid)
	for header in ["DATE", "PLAYERS", "PLACE", "VP", "RATING", "REPLAY"]:
		grid.add_child(ProfileScreen._cell(header, PixelTheme.TEXT_DIM))
	for game: Dictionary in history:
		grid.add_child(ProfileScreen._cell(ProfileScreen._date(int(game.get("time", 0))), PixelTheme.TEXT_DIM))
		grid.add_child(ProfileScreen.history_players(game, false))
		var place := int(game.get("place", 0))
		var places: Array = ProfileScreen.PLACES
		grid.add_child(ProfileScreen._cell(places[clampi(place - 1, 0, places.size() - 1)],
			PixelTheme.GOLD if place == 1 else PixelTheme.TEXT))
		grid.add_child(ProfileScreen._cell(str(int(game.get("vp", 0))), PixelTheme.TEXT))
		var delta := int(game.get("delta", 0))
		var rating_row := HBoxContainer.new()
		rating_row.add_theme_constant_override("separation", 4)
		# Партии до профилей на сервере (ProfileBook.backfill): рейтинга тех дней нет.
		if game.get("old", false):
			rating_row.add_child(ProfileScreen._cell("-", PixelTheme.TEXT_DIM))
		else:
			rating_row.add_child(ProfileScreen._cell(str(int(game.get("rating", 0))), PixelTheme.TEXT))
			rating_row.add_child(ProfileScreen._cell("LOBBY" if game.get("unrated", false) else "%+d" % delta,
				Color("5fd36a") if delta > 0 else (PixelTheme.DANGER if delta < 0 else PixelTheme.TEXT_DIM)))
		grid.add_child(rating_row)
		grid.add_child(_replay_cell(game))


## Кто каким цветом: квадратик и имя.
func _legend(their_name: String, with_mine: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var items := [[their_name, THEIR_COLOUR]]
	if with_mine:
		items.append(["YOU", ProfileScreen.MINE_COLOUR])
	for item: Array in items:
		var dot := ColorRect.new()
		dot.color = item[1]
		dot.custom_minimum_size = Vector2(5, 5)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		row.add_child(ProfileScreen._cell(String(item[0]), item[1]))
	return row


## WATCH, если запись партии есть и правила с тех пор не менялись (иначе OLD).
func _replay_cell(game: Dictionary) -> Control:
	var file := String(game.get("replay", ""))
	if file == "":
		return ProfileScreen._cell("-", PixelTheme.TEXT_OFF)
	if not ReplayBook.same_rules(int(game.get("protocol", -1)), bool(game.get("teams", false)),
			String(game.get("mode", ""))):
		return ProfileScreen._cell("OLD", PixelTheme.TEXT_OFF)
	var watch := Button.new()
	watch.text = "WATCH"
	watch.custom_minimum_size = Vector2(40, 12)
	watch.focus_mode = Control.FOCUS_NONE
	SetupScreen._style_button(watch)
	watch.pressed.connect(func():
		_waiting = [file, String(game.get("seat", ""))]
		watch.text = "..."
		watch.disabled = true
		_net.request_record(file))
	return watch


## Запись пришла: сохраняем рядом со своими реплеями (их чистит keep_only
## после следующей партии) и открываем глазами этого игрока.
func _on_record(file: String, header: Dictionary, intents: Array) -> void:
	if _waiting.is_empty() or file != String(_waiting[0]):
		return
	var own := header.duplicate(true)
	own["seat"] = String(_waiting[1])
	_waiting = []
	if header.is_empty():
		_status.text = "This replay is not available."
		_status.visible = true
		return
	var local := ReplayBook.save(own, intents, ReplayBook.DIR, NET_PREFIX + file)
	if local != "":
		replay_requested.emit(local)
