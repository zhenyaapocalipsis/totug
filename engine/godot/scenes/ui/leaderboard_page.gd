extends VBoxContainer

## Вкладка LEADERBOARD главного меню (владелец, 2026-10-11): первые 100 по
## рейтингу; сколько всего тиранов (сыграли хоть одну рейтинговую партию),
## сколько сейчас на связи (меню, поиск, лобби, партии) и сколько в партиях.
## Данные — с сервера по связи меню (NetSession.watch, узел заводит GameScene):
## пока меню открыто, раз в REFRESH секунд страница просит свежую таблицу, а
## пропавшую связь поднимает заново — так игрок в меню и считается онлайн.

const REFRESH := 10.0
const LIST_HEIGHT := 250.0
## Заголовки столбцов и их ширина.
const COLUMNS := [["#", 26], ["NAME", 150], ["RANK", 80], ["RATING", 48], ["GAMES", 44], ["WINS", 40]]

## Мировые рекорды (RecordBook, владелец 2026-10-11): кто первым поставил.
const RECORD_COLUMNS := [["RECORD", 140], ["BEST", 40], ["HOLDER", 130], ["DATE", 70]]
const MODES := {"players": "PLAYERS", "2": "RECORDS 2P", "3": "RECORDS 3P", "4": "RECORDS 4P"}

var net: NetSession
var _mode := "players"
var _data := {}
var _head: GridContainer
var _rec_head: GridContainer
var _rec_grid: GridContainer
var _counts: Label
var _status: Label
var _grid: GridContainer
var _mine: Label
var _wait := 0.0


func _init(session: NetSession = null) -> void:
	net = session
	add_theme_constant_override("separation", 2)
	_counts = _label("", PixelTheme.GOLD)
	_counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_counts)
	# Что показать: игроков по рейтингу или мировые рекорды стола на 2/3/4.
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 2)
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	var group := ButtonGroup.new()
	for mode: String in MODES:
		var b := Button.new()
		b.text = MODES[mode]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = mode == _mode
		b.custom_minimum_size = Vector2(76, 16)
		SetupScreen._style_button(b)
		b.pressed.connect(_set_mode.bind(mode))
		modes.add_child(b)
	add_child(modes)
	add_child(HSeparator.new())
	_head = _header(COLUMNS)
	add_child(_head)
	_rec_head = _header(RECORD_COLUMNS)
	_rec_head.visible = false
	add_child(_rec_head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(table_width() + 8, LIST_HEIGHT)
	# Таблица по центру окна, список — на всю его высоту.
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	_status = _label("Connecting to the server...", PixelTheme.TEXT_DIM)
	list.add_child(_status)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS.size()
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 1)
	list.add_child(_grid)
	_rec_grid = GridContainer.new()
	_rec_grid.columns = RECORD_COLUMNS.size()
	_rec_grid.add_theme_constant_override("h_separation", 6)
	_rec_grid.add_theme_constant_override("v_separation", 1)
	_rec_grid.visible = false
	list.add_child(_rec_grid)
	add_child(HSeparator.new())
	# Своё место, если оно ниже первой сотни (или ещё нет рейтинговых партий).
	_mine = _label("", PixelTheme.TEXT_DIM)
	_mine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_mine)
	if net != null:
		net.leaderboard_received.connect(show_data)
		net.connection_lost.connect(func(reason: String):
			if _grid.get_child_count() == 0:
				_status.text = "The server is not available. %s" % reason)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0 or net == null:
		return
	_wait = REFRESH
	if net.is_connected_to_server():
		if is_visible_in_tree():
			net.request_leaderboard()
		return
	var peer := net.multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		net.watch(server_address(), NetSession.SERVER_PORT)


## Адрес сервера — тот же, что в лобби (LobbyScreen запоминает набранный).
static func server_address() -> String:
	var address := LobbyScreen._load("server", NetSession.DEFAULT_SERVER)
	return NetSession.DEFAULT_SERVER if address == "127.0.0.1" else address


## Ответ сервера (NetSession.leaderboard): {top, registered, online, in_game, mine?}.
func show_data(data: Dictionary) -> void:
	_data = data
	_counts.text = "TYRANTS %d   ONLINE %d   IN GAME %d" % [int(data.get("registered", 0)),
		int(data.get("online", 0)), int(data.get("in_game", 0))]
	var records := _mode != "players"
	_head.visible = not records
	_grid.visible = not records
	_rec_head.visible = records
	_rec_grid.visible = records
	if records:
		_status.visible = false
		_mine.text = "Records count only in SEARCH games you win. First to set a value keeps it."
		_show_records(_mode)
		return
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var top: Array = data.get("top", [])
	_status.visible = top.is_empty()
	_status.text = "No rated games yet."
	for i in top.size():
		var row: Dictionary = top[i]
		var me := bool(row.get("me", false))
		var colour := PixelTheme.GOLD if me else PixelTheme.TEXT
		var rating := int(row.get("rating", 0))
		_grid.add_child(_cell(str(i + 1), PixelTheme.TEXT_DIM, int(COLUMNS[0][1])))
		_grid.add_child(_cell(String(row.get("name", "")), colour, int(COLUMNS[1][1])))
		_grid.add_child(_cell(PlayerProfile.rank_title(rating), PlayerProfile.rank_colour(rating), int(COLUMNS[2][1])))
		_grid.add_child(_cell(str(rating), colour, int(COLUMNS[3][1])))
		_grid.add_child(_cell(str(int(row.get("games", 0))), colour, int(COLUMNS[4][1])))
		_grid.add_child(_cell(str(int(row.get("wins", 0))), colour, int(COLUMNS[5][1])))
	var mine: Dictionary = data.get("mine", {})
	if mine.is_empty():
		_mine.text = "Play a game from SEARCH to get on the board."
	elif int(mine["rank"]) > top.size():
		_mine.text = "YOU: #%d   %d" % [int(mine["rank"]), int(mine["rating"])]
	else:
		_mine.text = "YOU: #%d" % int(mine["rank"])


func _set_mode(mode: String) -> void:
	_mode = mode
	if not _data.is_empty():
		show_data(_data)


## Рекорды стола на n игроков: все виды по порядку, ещё не поставленные — прочерк.
func _show_records(n: String) -> void:
	for child in _rec_grid.get_children():
		_rec_grid.remove_child(child)
		child.queue_free()
	var row: Dictionary = (_data.get("records", {}) as Dictionary).get(n, {})
	var my_name := String(PlayerProfile.load_local().get("name", ""))
	for kind: Array in RecordBook.KINDS:
		var r: Dictionary = row.get(kind[0], {})
		var holder := String(r.get("name", ""))
		var colour := PixelTheme.GOLD if holder != "" and holder == my_name else PixelTheme.TEXT
		_rec_grid.add_child(_cell(String(kind[1]), PixelTheme.TEXT_DIM, int(RECORD_COLUMNS[0][1])))
		_rec_grid.add_child(_cell(str(int(r["value"])) if not r.is_empty() else "-", colour, int(RECORD_COLUMNS[1][1])))
		_rec_grid.add_child(_cell(holder if holder != "" else "-", colour, int(RECORD_COLUMNS[2][1])))
		_rec_grid.add_child(_cell(String(r.get("date", "")), PixelTheme.TEXT_DIM, int(RECORD_COLUMNS[3][1])))


func _header(columns: Array) -> GridContainer:
	var head := GridContainer.new()
	head.columns = columns.size()
	head.add_theme_constant_override("h_separation", 6)
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.custom_minimum_size.x = table_width() + 8   # как у списка ниже (полоса прокрутки)
	for column: Array in columns:
		head.add_child(_cell(String(column[0]), PixelTheme.TEXT_DIM, int(column[1])))
	return head


func _cell(text: String, colour: Color, width: int) -> Label:
	var label := _label(text, colour)
	label.custom_minimum_size.x = width
	label.clip_text = true
	return label


func _label(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", colour)
	return label


## Ширина таблицы: столбцы и промежутки между ними.
static func table_width() -> float:
	var width := 6.0 * (COLUMNS.size() - 1)
	for column: Array in COLUMNS:
		width += float(column[1])
	return width
