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

var net: NetSession
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
	add_child(HSeparator.new())
	var head := GridContainer.new()
	head.columns = COLUMNS.size()
	head.add_theme_constant_override("h_separation", 6)
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.custom_minimum_size.x = table_width() + 8   # как у списка ниже (полоса прокрутки)
	for column: Array in COLUMNS:
		head.add_child(_cell(String(column[0]), PixelTheme.TEXT_DIM, int(column[1])))
	add_child(head)
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
	_counts.text = "TYRANTS %d   ONLINE %d   IN GAME %d" % [int(data.get("registered", 0)),
		int(data.get("online", 0)), int(data.get("in_game", 0))]
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
