class_name LobbyScreen
extends Control

## Лобби сетевой игры (этап 6). Четыре варианта (kind):
##   "create"    — завести комнату на сервере, друзьям сказать её код;
##   "join_code" — войти в комнату на сервере по коду;
##   "host"      — открыть игру на своём компьютере (локальная сеть, Radmin);
##   "join_ip"   — войти к такому хосту по его адресу.
## Саму связь держит NetSession — экран только показывает её состояние.
##
## Вёрстка кодом по той же причине, что и в game_screen.gd.

signal back_requested

const CONFIG_PATH := "user://online.cfg"
const DOT := 7.0
const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")

var _net: NetSession
var _kind := ""
var _count := 2
var _mode := ""
var _status: Label
var _seats: HBoxContainer
var _code_label: Label
var _server_edit: LineEdit
var _ip_edit: LineEdit
var _code_edit: LineEdit
var _go_button: Button
var _start_button: Button
## Хост: внешний адрес (UPnP) и пояснение под ним.
var _internet: Label
var _internet_note: Label


func _init(net: NetSession, kind: String, player_count: int = 2, mode: String = "") -> void:
	_net = net
	_kind = kind
	_count = player_count
	_mode = mode
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()
	add_child(UnderdarkBg.make())

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", GameScreen.zone_style(6))
	centre.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	card.add_child(col)

	var title := Label.new()
	title.text = {"create": "CREATE A ROOM", "join_code": "JOIN BY CODE",
		"host": "HOST A GAME", "join_ip": "JOIN BY ADDRESS"}.get(kind, "ONLINE")
	title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(HSeparator.new())

	match kind:
		"create", "join_code":
			_build_server_part(col)
		"host":
			_build_host_part(col)
		_:
			_build_join_ip_part(col)

	col.add_child(HSeparator.new())
	col.add_child(GameScreen.section_label("AT THE TABLE"))
	_seats = HBoxContainer.new()
	_seats.add_theme_constant_override("separation", 6)
	_seats.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_seats)
	_status = _dim("")
	col.add_child(_status)

	col.add_child(HSeparator.new())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	var back := _button("BACK")
	back.pressed.connect(func(): back_requested.emit())
	buttons.add_child(back)
	_start_button = _button("START")
	_start_button.disabled = true
	_start_button.visible = kind != "join_ip" and kind != "join_code"
	_start_button.pressed.connect(func(): _net.start_game(int(Time.get_unix_time_from_system())))
	buttons.add_child(_start_button)

	_net.lobby_changed.connect(_on_lobby_changed)
	_net.connection_lost.connect(_on_connection_lost)
	match kind:
		"create":
			_status.text = "Press CREATE ROOM."
		"join_code":
			_status.text = "Enter the room code your friend got."
		"join_ip":
			_status.text = "Enter the host's address."
		"host":
			_status.text = "Waiting for players..."
			var err := _net.host(NetSession.DEFAULT_PORT, player_count, mode)
			if err != OK:
				_status.text = "Could not open port %d (error %d). Is another game already hosting?" % [
					NetSession.DEFAULT_PORT, err]
				_internet.text = "-"
			else:
				_net.upnp_finished.connect(_on_upnp_finished)
				_net.open_upnp(NetSession.DEFAULT_PORT)


# --- части экрана ------------------------------------------------------------

## Сервер с комнатами: адрес сервера (запоминается), код комнаты.
func _build_server_part(col: VBoxContainer) -> void:
	if _kind == "create":
		col.add_child(_dim("%d players, mode %s" % [_count, SetupScreen.MODE_TITLES.get(_mode, _mode)]))
	var server_row := _row(col)
	server_row.add_child(_dim("SERVER"))
	_server_edit = LineEdit.new()
	_server_edit.custom_minimum_size = Vector2(110, 16)
	_server_edit.text = _load("server", NetSession.DEFAULT_SERVER)
	server_row.add_child(_server_edit)

	if _kind == "join_code":
		var code_row := _row(col)
		code_row.add_child(_dim("ROOM CODE"))
		_code_edit = LineEdit.new()
		_code_edit.custom_minimum_size = Vector2(60, 16)
		_code_edit.max_length = NetSession.CODE_LENGTH
		_code_edit.placeholder_text = "ABCD"
		_code_edit.text_submitted.connect(func(_t: String): _on_go())
		code_row.add_child(_code_edit)

	_go_button = _button("CREATE ROOM" if _kind == "create" else "JOIN")
	_go_button.custom_minimum_size = Vector2(90, 16)
	_go_button.pressed.connect(_on_go)
	_row(col).add_child(_go_button)

	# Код комнаты крупно — его надо продиктовать друзьям.
	_code_label = Label.new()
	_code_label.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	_code_label.add_theme_color_override("font_color", PixelTheme.GOLD)
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.visible = false
	col.add_child(_code_label)


func _build_host_part(col: VBoxContainer) -> void:
	col.add_child(_dim("%d players, mode %s, port %d (UDP)" % [
		_count, SetupScreen.MODE_TITLES.get(_mode, _mode), NetSession.DEFAULT_PORT]))
	col.add_child(GameScreen.section_label("OVER THE INTERNET"))
	_internet = _centred("Asking your router to open the port (up to 10 s)...")
	col.add_child(_internet)
	_internet_note = _dim("")
	_internet_note.visible = false
	col.add_child(_internet_note)
	col.add_child(GameScreen.section_label("SAME HOME NETWORK OR RADMIN VPN"))
	for address: String in local_addresses():
		col.add_child(_centred(address + ("   (Radmin VPN)" if address.begins_with("26.") else "")))


func _build_join_ip_part(col: VBoxContainer) -> void:
	col.add_child(GameScreen.section_label("HOST ADDRESS"))
	var row := _row(col)
	_ip_edit = LineEdit.new()
	_ip_edit.custom_minimum_size = Vector2(120, 16)
	_ip_edit.placeholder_text = "e.g. 26.12.34.56"
	_ip_edit.text = _load("last_ip", "")
	_ip_edit.text_submitted.connect(func(_t: String): _on_go())
	row.add_child(_ip_edit)
	_go_button = _button("CONNECT")
	_go_button.pressed.connect(_on_go)
	row.add_child(_go_button)


# --- действия ----------------------------------------------------------------

## CREATE ROOM / JOIN / CONNECT.
func _on_go() -> void:
	var err := OK
	match _kind:
		"join_ip":
			var address := _ip_edit.text.strip_edges()
			if address == "":
				_status.text = "Enter the host's address first."
				return
			_save("last_ip", address)
			err = _net.join(address, NetSession.DEFAULT_PORT)
		_:
			var server := _server_edit.text.strip_edges()
			if server == "":
				_status.text = "Enter the server address first."
				return
			_save("server", server)
			if _kind == "create":
				err = _net.create_room(server, NetSession.SERVER_PORT, _count, _mode)
			else:
				var code := _code_edit.text.strip_edges().to_upper()
				if code.length() != NetSession.CODE_LENGTH:
					_status.text = "The room code has %d letters." % NetSession.CODE_LENGTH
					return
				err = _net.enter_room(server, NetSession.SERVER_PORT, code)
	if err != OK:
		_status.text = "Could not connect (error %d)." % err
		return
	_set_editable(false)
	_status.text = "Connecting..."


func _set_editable(on: bool) -> void:
	for edit: LineEdit in [_server_edit, _ip_edit, _code_edit]:
		if edit != null:
			edit.editable = on
	if _go_button != null:
		_go_button.disabled = not on


func _on_lobby_changed(joined: Array, needed: int, code: String, owner_seat: String) -> void:
	if _go_button != null:
		_go_button.visible = false
	if _code_label != null:
		_code_label.visible = true
		_code_label.text = "ROOM  %s" % code
	for child in _seats.get_children():
		child.queue_free()
	for pid in joined:
		var dot := ColorRect.new()
		dot.color = BoardPanel.PLAYER_COLORS.get(String(pid), Color.GRAY)
		dot.custom_minimum_size = Vector2(DOT, DOT)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_seats.add_child(dot)
		var name_label := Label.new()
		name_label.text = EventLogPanel.player_name(String(pid)) + (" (you)" if String(pid) == _net.seat else "")
		_seats.add_child(name_label)
	var full := joined.size() >= needed
	var i_start := owner_seat == _net.seat
	_start_button.visible = i_start
	_start_button.disabled = not full
	if full:
		_status.text = "Everyone is here — press START." if i_start \
			else "Everyone is here. Waiting for %s to start." % EventLogPanel.player_name(owner_seat)
	else:
		var share := "Tell your friends the room code. " if _code_label != null and i_start else ""
		_status.text = "%sWaiting for players: %d of %d." % [share, joined.size(), needed]


func _on_connection_lost(reason: String) -> void:
	_status.text = reason + "."
	_set_editable(true)
	if _go_button != null:
		_go_button.visible = true


func _on_upnp_finished(address: String, note: String) -> void:
	_internet_note.visible = true
	if address != "":
		_internet.text = address
		_internet.add_theme_color_override("font_color", PixelTheme.GOLD)
		_internet_note.text = note + " Friends can join by this address."
	else:
		_internet.text = "Not available"
		_internet_note.text = note + " Use Radmin VPN instead."


## Свои IPv4-адреса: локальная сеть и Radmin VPN (26.x.x.x — первым).
static func local_addresses() -> Array[String]:
	var found: Array[String] = []
	for address: String in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		if address.begins_with("26."):
			found.push_front(address)
		else:
			found.append(address)
	return found


# --- мелочи ------------------------------------------------------------------

func _row(col: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	return row


func _dim(text: String) -> Label:
	var label := _centred(text)
	label.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	return label


func _centred(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(70, 16)
	SetupScreen._style_button(button)
	return button


static func _load(key: String, fallback: String) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return fallback
	return String(cfg.get_value("online", key, fallback))


static func _save(key: String, value: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("online", key, value)
	cfg.save(CONFIG_PATH)
