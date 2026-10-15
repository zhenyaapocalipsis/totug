extends HBoxContainer

## Вкладка FRIENDS главного меню (владелец, 2026-10-11), между LEADERBOARD и
## SETTINGS. Слева: добавить по нику, заявки (принять / отклонить), свои
## отправленные заявки и список друзей (кто в сети — выше, непрочитанные —
## числом). Справа — выбранный друг: карточка профиля (ProfileCard.fill),
## кнопки INVITE (своё лобби и сразу приглашение), WATCH (его идущая партия),
## REMOVE, и переписка — сообщения хранятся на сервере (FriendBook) и доходят,
## даже если друг был не в сети.
##
## Данные — с сервера по связи меню (NetSession.watch, как у LEADERBOARD):
## пока вкладка открыта, раз в REFRESH секунд просим свежий список.

## Своё лобби для друга: GameScene заводит комнату и, как появится код,
## зовёт туда друга (NetSession.friends_action "invite").
signal invite_requested(friend_name: String)
## Смотреть партию друга (режим зрителя).
signal watch_requested(friend_name: String)
## Сколько непрочитанных и заявок — для метки на кнопке вкладки.
signal badge_changed(count: int)
## PROFILE — открыть полный профиль друга (PlayerProfilePanel).
signal profile_requested(friend_name: String)

const REFRESH := 10.0
const LIST_WIDTH := 150.0
const SIDE_WIDTH := 236.0
const THREAD_HEIGHT := 92.0
const STATUS_COLOURS := {"IN GAME": Color("f2d23c"), "IN LOBBY": Color("5fd36a"), "ONLINE": Color("5fd36a"),
	"OFFLINE": Color("8a7fa8")}

var net: NetSession
var _wait := 0.0
var _data := {}
var _selected := ""
var _nick: LineEdit
var _note: Label
var _list: VBoxContainer
var _side: VBoxContainer
var _card: VBoxContainer
var _status: Label
var _actions: HBoxContainer
var _thread_scroll: ScrollContainer
var _thread: VBoxContainer
var _message: LineEdit
var _invite: Button
var _watch: Button


func _init(session: NetSession = null) -> void:
	net = session
	add_theme_constant_override("separation", 6)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.custom_minimum_size.x = LIST_WIDTH
	add_child(left)
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 2)
	left.add_child(add_row)
	_nick = LineEdit.new()
	_nick.placeholder_text = "nickname"
	_nick.max_length = PlayerProfile.NAME_MAX
	_nick.custom_minimum_size = Vector2(LIST_WIDTH - 42, 16)
	_nick.text_submitted.connect(func(_t: String): _add())
	add_row.add_child(_nick)
	add_row.add_child(_button("ADD", 40, _add))
	_note = _label("", PixelTheme.TEXT_DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.custom_minimum_size.x = LIST_WIDTH
	left.add_child(_note)
	left.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(LIST_WIDTH, 200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_list.add_child(_label("Connecting to the server...", PixelTheme.TEXT_DIM))

	add_child(VSeparator.new())
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 3)
	_side.custom_minimum_size.x = SIDE_WIDTH
	add_child(_side)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 4)
	_side.add_child(_card)
	_status = _label("", PixelTheme.TEXT_DIM)
	_side.add_child(_status)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 2)
	_side.add_child(_actions)
	_actions.add_child(_button("PROFILE", 56, func(): profile_requested.emit(_selected)))
	_invite = _button("INVITE", 56, func(): invite_requested.emit(_selected))
	_actions.add_child(_invite)
	_watch = _button("WATCH", 56, func(): watch_requested.emit(_selected))
	_actions.add_child(_watch)
	_actions.add_child(_button("REMOVE", 56, func():
		net.friends_action("remove", [_selected])
		_selected = ""))
	_side.add_child(HSeparator.new())
	_thread_scroll = ScrollContainer.new()
	_thread_scroll.custom_minimum_size = Vector2(SIDE_WIDTH, THREAD_HEIGHT)
	_thread_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_thread_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side.add_child(_thread_scroll)
	_thread = VBoxContainer.new()
	_thread.add_theme_constant_override("separation", 1)
	_thread.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_thread_scroll.add_child(_thread)
	var send_row := HBoxContainer.new()
	send_row.add_theme_constant_override("separation", 2)
	_side.add_child(send_row)
	_message = LineEdit.new()
	_message.placeholder_text = "message"
	_message.max_length = FriendBook.TEXT_MAX
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.custom_minimum_size.y = 16
	_message.text_submitted.connect(func(_t: String): _send_message())
	send_row.add_child(_message)
	send_row.add_child(_button("SEND", 44, _send_message))
	_show_friend()

	if net != null:
		net.friends_received.connect(show_data)
		net.thread_received.connect(_show_thread)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0 or net == null:
		return
	_wait = REFRESH
	# Связь меню поднимает и держит LEADERBOARD (LeaderboardPage) — здесь
	# только спрашиваем список, пока вкладку видно.
	if net.is_connected_to_server() and is_visible_in_tree():
		net.friends_action("list")


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_wait = 0.0


func _add() -> void:
	var nick := PlayerProfile.clean_name(_nick.text)
	if nick == "" or net == null:
		return
	net.friends_action("add", [nick])
	_nick.text = ""


func _send_message() -> void:
	var text := FriendBook.clean_text(_message.text)
	if text == "" or _selected == "" or net == null:
		return
	net.friends_action("send", [_selected, text])
	_message.text = ""


## Снимок с сервера (NetSession.friends_data).
func show_data(data: Dictionary) -> void:
	_data = data
	if String(data.get("note", "")) != "":
		_note.text = String(data["note"])
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var badge := 0
	var incoming: Array = data.get("incoming", [])
	if not incoming.is_empty():
		_list.add_child(_label("REQUESTS", PixelTheme.GOLD))
		for who in incoming:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 2)
			var name_label := _label(String(who), PixelTheme.TEXT)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.clip_text = true
			row.add_child(name_label)
			row.add_child(_button("YES", 30, func(): net.friends_action("answer", [String(who), true])))
			row.add_child(_button("NO", 26, func(): net.friends_action("answer", [String(who), false])))
			_list.add_child(row)
		badge += incoming.size()
	var friends: Array = data.get("friends", [])
	_list.add_child(_label("FRIENDS %d" % friends.size(), PixelTheme.TEXT_DIM))
	if friends.is_empty():
		_list.add_child(_label("Add a friend by nickname,\nor click a player's name\nin a lobby, a game or\nLEADERBOARD.", PixelTheme.TEXT_DIM))
	var still_there := false
	for f: Dictionary in friends:
		var fname := String(f["name"])
		still_there = still_there or fname == _selected
		var b := Button.new()
		var unread := int(f.get("unread", 0))
		badge += unread
		b.text = fname + ("  (%d)" % unread if unread > 0 else "")
		b.toggle_mode = true
		b.button_pressed = fname == _selected
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(LIST_WIDTH - 10, 16)
		b.clip_text = true
		SetupScreen._style_button(b)
		b.add_theme_color_override("font_color", STATUS_COLOURS.get(String(f["status"]), PixelTheme.TEXT))
		b.pressed.connect(_select.bind(fname))
		_list.add_child(b)
	var outgoing: Array = data.get("outgoing", [])
	if not outgoing.is_empty():
		_list.add_child(_label("SENT", PixelTheme.TEXT_DIM))
		for who in outgoing:
			var row := HBoxContainer.new()
			var name_label := _label(String(who), PixelTheme.TEXT_DIM)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.clip_text = true
			row.add_child(name_label)
			row.add_child(_button("CANCEL", 50, func(): net.friends_action("remove", [String(who)])))
			_list.add_child(row)
	if not still_there:
		_selected = ""
	badge_changed.emit(badge)
	_show_friend()
	# Пришло новое от открытого друга — перечитать переписку (заодно прочитано).
	var open := _friend(_selected)
	if not open.is_empty() and int(open.get("unread", 0)) > 0 and is_visible_in_tree():
		net.friends_action("thread", [_selected])


func _friend(fname: String) -> Dictionary:
	for f: Dictionary in _data.get("friends", []):
		if String(f["name"]) == fname:
			return f
	return {}


func _select(fname: String) -> void:
	_selected = fname
	for child in _thread.get_children():
		child.queue_free()
	show_data(_data)
	if net != null:
		net.friends_action("thread", [fname])


## Правая половина: карточка выбранного друга и что с ним можно сделать.
func _show_friend() -> void:
	for child in _card.get_children():
		_card.remove_child(child)
		child.queue_free()
	var f := _friend(_selected)
	_actions.visible = not f.is_empty()
	_message.editable = not f.is_empty()
	if f.is_empty():
		_status.text = "Choose a friend on the left."
		for child in _thread.get_children():
			child.queue_free()
		return
	var profile := f.duplicate()
	if not bool(f.get("rated", false)):
		profile.erase("rating")
	ProfileCard.fill(_card, "", profile)
	var status := String(f["status"])
	var line := status
	if int(f.get("records", 0)) > 0:
		line += "   WORLD RECORDS %d" % int(f["records"])
	_status.text = line
	_status.add_theme_color_override("font_color", STATUS_COLOURS.get(status, PixelTheme.TEXT_DIM))
	_invite.disabled = status == "OFFLINE" or status == "IN GAME"
	_watch.disabled = String(f.get("room", "")) == ""


func _show_thread(fname: String, messages: Array) -> void:
	if fname.to_lower() != _selected.to_lower():
		return
	for child in _thread.get_children():
		_thread.remove_child(child)
		child.queue_free()
	if messages.is_empty():
		_thread.add_child(_label("No messages yet.", PixelTheme.TEXT_DIM))
	for m: Dictionary in messages:
		var mine := bool(m["mine"])
		var label := _label(("YOU: " if mine else fname + ": ") + String(m["text"]),
			PixelTheme.GOLD if mine else PixelTheme.TEXT)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = SIDE_WIDTH - 12
		_thread.add_child(label)
	# К последнему сообщению — когда список перемерится.
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_thread_scroll.scroll_vertical = int(_thread_scroll.get_v_scroll_bar().max_value)


func _button(text: String, width: float, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 16)
	SetupScreen._style_button(b)
	b.pressed.connect(action)
	return b


func _label(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", colour)
	return label
