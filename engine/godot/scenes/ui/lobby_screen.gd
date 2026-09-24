class_name LobbyScreen
extends Control

## Лобби сетевой игры (этап 6). Хост видит свои адреса и кто уже сел за стол,
## клиент вводит адрес хоста. Саму связь держит NetSession — экран только
## показывает её состояние.
##
## Вёрстка кодом по той же причине, что и в game_screen.gd.

signal back_requested

const CONFIG_PATH := "user://online.cfg"
const DOT := 7.0
const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")

var _net: NetSession
var _hosting := false
var _status: Label
var _seats: HBoxContainer
var _ip_edit: LineEdit
var _join_button: Button
var _start_button: Button
## Хост: внешний адрес (UPnP) и пояснение под ним.
var _internet: Label
var _internet_note: Label


func _init(net: NetSession, hosting: bool, player_count: int = 2, mode: String = "") -> void:
	_net = net
	_hosting = hosting
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
	title.text = "HOST A GAME" if hosting else "JOIN A GAME"
	title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(HSeparator.new())

	if hosting:
		col.add_child(_dim("%d players, mode %s, port %d (UDP)" % [
			player_count, SetupScreen.MODE_TITLES.get(mode, mode), NetSession.DEFAULT_PORT]))
		col.add_child(GameScreen.section_label("OVER THE INTERNET"))
		_internet = _centred("Asking your router to open the port (up to 10 s)...")
		col.add_child(_internet)
		_internet_note = _dim("")
		_internet_note.visible = false
		col.add_child(_internet_note)
		col.add_child(GameScreen.section_label("SAME HOME NETWORK OR RADMIN VPN"))
		for address: String in local_addresses():
			col.add_child(_centred(address + ("   (Radmin VPN)" if address.begins_with("26.") else "")))
	else:
		col.add_child(GameScreen.section_label("HOST ADDRESS"))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(row)
		_ip_edit = LineEdit.new()
		_ip_edit.custom_minimum_size = Vector2(120, 16)
		_ip_edit.placeholder_text = "e.g. 26.12.34.56"
		_ip_edit.text = _load_last_ip()
		_ip_edit.text_submitted.connect(func(_t: String): _on_join())
		row.add_child(_ip_edit)
		_join_button = _button("CONNECT")
		_join_button.pressed.connect(_on_join)
		row.add_child(_join_button)

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
	if hosting:
		_start_button = _button("START")
		_start_button.disabled = true
		_start_button.pressed.connect(func(): _net.start_game(int(Time.get_unix_time_from_system())))
		buttons.add_child(_start_button)

	_net.lobby_changed.connect(_on_lobby_changed)
	_net.connection_lost.connect(_on_connection_lost)
	_status.text = "Waiting for players..." if hosting else "Enter the host's address."
	if hosting:
		var err := _net.host(NetSession.DEFAULT_PORT, player_count, mode)
		if err != OK:
			_status.text = "Could not open port %d (error %d). Is another game already hosting?" % [
				NetSession.DEFAULT_PORT, err]
			_internet.text = "-"
		else:
			_net.upnp_finished.connect(_on_upnp_finished)
			_net.open_upnp(NetSession.DEFAULT_PORT)


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


func _on_join() -> void:
	var address := _ip_edit.text.strip_edges()
	if address == "":
		_status.text = "Enter the host's address first."
		return
	_save_last_ip(address)
	var err := _net.join(address, NetSession.DEFAULT_PORT)
	if err != OK:
		_status.text = "Could not connect (error %d)." % err
		return
	_join_button.disabled = true
	_ip_edit.editable = false
	_status.text = "Connecting to %s..." % address


func _on_lobby_changed(joined: Array, needed: int) -> void:
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
	if _hosting:
		_start_button.disabled = not full
		_status.text = "Everyone is here — press START." if full \
			else "Waiting for players: %d of %d." % [joined.size(), needed]
	else:
		_status.text = "Connected. Waiting for the host to start (%d of %d)." % [joined.size(), needed]


func _on_connection_lost(reason: String) -> void:
	_status.text = reason + "."
	if _join_button != null:
		_join_button.disabled = false
		_ip_edit.editable = true


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


static func _load_last_ip() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return ""
	return String(cfg.get_value("online", "last_ip", ""))


static func _save_last_ip(address: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("online", "last_ip", address)
	cfg.save(CONFIG_PATH)
