class_name LobbyScreen
extends Control

const L10n := preload("res://scenes/localization.gd")

## Лобби сетевой игры (этап 6). Четыре варианта (kind):
##   "create"    — завести комнату на сервере, друзьям сказать её код;
##   "join_code" — войти в комнату на сервере по коду;
##   "host"      — открыть игру на своём компьютере (локальная сеть, Radmin);
##   "join_ip"   — войти к такому хосту по его адресу;
##   "find"      — поиск игры: встать в очередь на сервере, стол RANDOM 4
##                 соберётся из случайных игроков и раздастся сам.
## Саму связь держит NetSession — экран только показывает её состояние.
##
## Вёрстка кодом по той же причине, что и в game_screen.gd.

signal back_requested

const NetworkText := preload("res://scenes/network_text.gd")

const CONFIG_PATH := "user://online.cfg"
const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")

var _net: NetSession
var _kind := ""
var _count := 2
var _mode := ""
## Своя комната 2 на 2 (этап Team-3); у вошедших — из лобби (NetSession.room_teams).
var _teams := false
var _status: Label
var _seats: HBoxContainer
var _team_row: HBoxContainer
var _code_label: Label
var _server_edit: LineEdit
var _ip_edit: LineEdit
var _code_edit: LineEdit
var _go_button: Button
var _start_button: Button
## Хост: внешний адрес (UPnP) и пояснение под ним.
var _internet: Label
var _internet_note: Label
## Поиск игры: с какого момента ждём (Time.get_ticks_msec, -1 — не ждём) и
## строка про очередь от сервера.
var _searching_since := -1
var _queue_waiting := 0
var _queue_needed := 0
## Друзья в лобби (владелец, 2026-10-11): кого позвать сразу, как появится
## код (INVITE во вкладке FRIENDS), и строка онлайн-друзей с кнопками.
var _invite_first := ""
var _invites: HFlowContainer
var _invite_note: Label
var _friends_wait := 0.0
var _in_room := false
## Экран DEALING THE CARDS (этап Stock-2): сервер строит доску без лимита
## времени, это может занять секунды. Висит поверх лобби до старта партии.
var _dealing: Control
var _dealing_dots: Label
var _dealing_time := 0.0
## Лобби банов (этап Ban-1): висит поверх лобби, пока стол поиска банит карты.
var _bans: BanPanel


## address — код комнаты (join_code) или IP хоста (join_ip), набранные в
## главном меню: с ним вход начинается сразу.
func _init(net: NetSession, kind: String, player_count: int = 2, mode: String = "",
		address: String = "", invite: String = "", teams: bool = false) -> void:
	_net = net
	_kind = kind
	_count = player_count
	_mode = mode
	_teams = teams
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
	L10n.scope(title)
	title.text = {"create": "CREATE A ROOM", "join_code": "JOIN BY CODE", "find": "FIND A GAME",
		"host": "HOST A GAME", "join_ip": "JOIN BY ADDRESS", "resume": "RETURN TO GAME"}.get(kind, "ONLINE")
	title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(HSeparator.new())

	match kind:
		"create", "join_code", "find":
			_build_server_part(col)
		"host":
			_build_host_part(col)
		"resume":
			_go_button = _button("TRY AGAIN")
			_go_button.custom_minimum_size = Vector2(90, 16)
			_go_button.visible = false
			_go_button.pressed.connect(_on_go)
			_row(col).add_child(_go_button)
		_:
			_build_join_ip_part(col)

	col.add_child(HSeparator.new())
	col.add_child(_caption("AT THE TABLE"))
	_seats = HBoxContainer.new()
	_seats.add_theme_constant_override("separation", 6)
	_seats.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_seats)
	# 2 на 2: в какую команду сесть (видно, когда комната командная).
	_team_row = HBoxContainer.new()
	_team_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_team_row.add_theme_constant_override("separation", 6)
	_team_row.visible = false
	for team: String in ["red", "blue"]:
		var b := _button("")
		L10n.bind(b, "lobby.team_" + team)
		b.add_theme_color_override("font_color", BoardPanel.PLAYER_COLORS[team])
		b.pressed.connect(func(): _net.choose_team(team))
		_team_row.add_child(b)
	col.add_child(_team_row)
	_status = _dim("")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 340
	col.add_child(_status)
	_invite_first = invite
	if kind == "create" or kind == "join_code":
		var friends_head := _caption("INVITE FRIENDS")
		col.add_child(friends_head)
		_invites = HFlowContainer.new()
		_invites.add_theme_constant_override("h_separation", 2)
		_invites.add_theme_constant_override("v_separation", 2)
		_invites.custom_minimum_size.x = 300
		col.add_child(_invites)
		_invite_note = _dim("")
		L10n.bind(_invite_note, "lobby.friends_initial")
		col.add_child(_invite_note)
		net.friends_received.connect(_on_friends)

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
	_start_button.visible = kind == "create" or kind == "host"
	_start_button.pressed.connect(_on_start)
	buttons.add_child(_start_button)

	_net.lobby_changed.connect(_on_lobby_changed)
	_net.connection_lost.connect(_on_connection_lost)
	_net.queue_changed.connect(_on_queue_changed)
	_net.dealing_started.connect(_show_dealing)
	_net.bans_changed.connect(_on_bans_changed)
	_net.match_cancelled.connect(_on_match_cancelled)
	match kind:
		# CREATE ROOM и SEARCH уже нажаты в главном меню — второй раз не просим;
		# кнопка здесь — только повтор, если связь не удалась.
		"create", "find":
			_on_go()
		"join_code":
			L10n.bind(_status, "lobby.code_hint")
			if address != "":
				_code_edit.text = address.to_upper()
				_on_go()
		"join_ip":
			L10n.bind(_status, "lobby.address_hint")
			if address != "":
				_ip_edit.text = address
				_on_go()
		"resume":
			_on_go()
		"host":
			L10n.bind(_status, "lobby.waiting")
			var err := _net.host(NetSession.DEFAULT_PORT, player_count, mode, teams)
			if err != OK:
				L10n.bind(_status, "lobby.port_error", {"port": NetSession.DEFAULT_PORT, "error": err})
				L10n.bind(_internet, "lobby.raw", {"value": "-"})
			else:
				_net.upnp_finished.connect(_on_upnp_finished)
				_net.open_upnp(NetSession.DEFAULT_PORT)


# --- части экрана ------------------------------------------------------------

## Сервер с комнатами: адрес сервера (запоминается), код комнаты.
func _build_server_part(col: VBoxContainer) -> void:
	if _kind == "create":
		_description(col, "lobby.description", _mode)
	elif _kind == "find":
		_description(col, "lobby.description_find", NetSession.match_mode(_count))
	var server_row := _row(col)
	server_row.add_child(_dim("SERVER"))
	_server_edit = LineEdit.new()
	_server_edit.custom_minimum_size = Vector2(110, 16)
	_server_edit.text = _load("server", NetSession.DEFAULT_SERVER)
	# Адрес локальной проверки не должен навсегда заслонить настоящий сервер.
	if _server_edit.text == "127.0.0.1":
		_server_edit.text = NetSession.DEFAULT_SERVER
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

	_go_button = _button({"create": "CREATE ROOM", "find": "FIND GAME"}.get(_kind, "JOIN"))
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
	_description(col, "lobby.description_host", _mode)
	col.add_child(_caption("OVER THE INTERNET"))
	_internet = _centred("")
	L10n.bind(_internet, "lobby.router_wait")
	col.add_child(_internet)
	_internet_note = _dim("")
	_internet_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_internet_note.custom_minimum_size.x = 340
	_internet_note.visible = false
	col.add_child(_internet_note)
	col.add_child(_caption("SAME HOME NETWORK OR RADMIN VPN"))
	for address: String in local_addresses():
		col.add_child(_centred(address + ("   (Radmin VPN)" if address.begins_with("26.") else "")))


func _build_join_ip_part(col: VBoxContainer) -> void:
	col.add_child(_caption("HOST ADDRESS"))
	var row := _row(col)
	_ip_edit = LineEdit.new()
	_ip_edit.custom_minimum_size = Vector2(120, 16)
	L10n.bind(_ip_edit, "lobby.ip_example", {}, "placeholder_text")
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
		"resume":
			# Партия могла кончиться, пока нас не было: сервер отказал, и запись
			# стёрта (NetSession._refused) — возвращаться больше некуда.
			if NetSession.saved_game().is_empty():
				L10n.bind(_status, "lobby.over")
				_go_button.visible = false
				return
			err = _net.resume_saved()
			_go_button.visible = false
		"join_ip":
			var address := _ip_edit.text.strip_edges()
			if address == "":
				L10n.bind(_status, "lobby.need_address")
				return
			_save("last_ip", address)
			err = _net.join(address, NetSession.DEFAULT_PORT)
		_:
			var server := _server_edit.text.strip_edges()
			if server == "":
				L10n.bind(_status, "lobby.need_server")
				return
			_save("server", server)
			if _kind == "create":
				err = _net.create_room(server, NetSession.SERVER_PORT, _count, _mode, _teams)
			elif _kind == "find":
				err = _net.find_match(server, NetSession.SERVER_PORT, _count, _teams, PlayerProfile.ban())
			else:
				var code := _code_edit.text.strip_edges().to_upper()
				if code.length() != NetSession.CODE_LENGTH:
					L10n.bind(_status, "lobby.code_length", {"count": NetSession.CODE_LENGTH})
					return
				err = _net.enter_room(server, NetSession.SERVER_PORT, code)
	if err != OK:
		L10n.bind(_status, "lobby.connect_error", {"error": err})
		return
	_set_editable(false)
	L10n.bind(_status, "lobby.connecting")


## Раздача партии занимает несколько секунд (схема доски рисуется долго, на
## слабом сервере — дольше) — без надписи кажется, что кнопка не сработала.
func _on_start() -> void:
	_start_button.disabled = true
	L10n.bind(_status, "lobby.dealing")
	_show_dealing()
	# хост по IP раздаёт у себя и на это время замирает — экран сначала рисуется
	await get_tree().process_frame
	await get_tree().process_frame
	_net.start_game(int(Time.get_unix_time_from_system()))


func _show_dealing() -> void:
	if _dealing != null:
		return
	_dealing = ColorRect.new()
	(_dealing as ColorRect).color = PixelTheme.BG
	_dealing.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dealing.mouse_filter = Control.MOUSE_FILTER_STOP
	_dealing.add_child(UnderdarkBg.make())
	add_child(_dealing)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dealing.add_child(centre)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", GameScreen.zone_style(10))
	centre.add_child(plate)
	plate.add_child(col)
	var title := Label.new()
	L10n.bind(title, "lobby.dealing_title")
	title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_dealing_dots = _dim("")
	L10n.bind(_dealing_dots, "lobby.building")
	_dealing_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_dealing_dots)
	_dealing_time = 0.0


## Лобби банов: первое состояние открывает экран, конец банов — DEALING. Отсчёт
## 10 с после последнего бана ("starting") идёт в самом лобби: игроки смотрят
## баны и пишут в чат (владелец, 2026-11-04).
func _on_bans_changed(view: Dictionary) -> void:
	if _bans == null:
		_bans = BanPanel.new(_net)
		add_child(_bans)
	_bans.show_view(view)
	if String(view.get("turn", "")) == "" and not bool(view.get("starting", false)):
		_hide_bans()
		_show_dealing()


func _hide_bans() -> void:
	if _bans != null:
		_bans.queue_free()
		_bans = null


## Кто-то ушёл из лобби банов — стол распался, ищем дальше.
func _on_match_cancelled(gone: String) -> void:
	_hide_bans()
	_hide_dealing()
	for child in _seats.get_children():
		child.queue_free()
	L10n.bind(_status, "lobby.cancelled", {"name": EventLogPanel.player_name(gone)})
	_on_go()


func _hide_dealing() -> void:
	if _dealing != null:
		_dealing.queue_free()
		_dealing = null


func _set_editable(on: bool) -> void:
	for edit: LineEdit in [_server_edit, _ip_edit, _code_edit]:
		if edit != null:
			edit.editable = on
	if _go_button != null:
		_go_button.disabled = not on


func _on_lobby_changed(joined: Array, needed: int, code: String, owner_seat: String) -> void:
	if _go_button != null:
		_go_button.visible = false
	_searching_since = -1
	# Поиск игры: код комнаты никому диктовать не надо.
	if _code_label != null and _kind != "find":
		_code_label.visible = true
		L10n.bind(_code_label, "lobby.room", {"code": code})
	# В комнате — можно звать друзей (и того, ради кого комнату завели).
	if _invites != null and not _in_room:
		_in_room = true
		_friends_wait = 0.0
		if _invite_first != "":
			_net.friends_action("invite", [_invite_first])
			_invite_first = ""
	for child in _seats.get_children():
		child.queue_free()
	PlayerProfile.seats = _net.profiles
	# 2 на 2: два цвета — фишки и имена цветом команды, кнопки выбора команды.
	_teams = _teams or _net.room_teams
	BoardPanel.team_of = GameSetup.team_map(GameRoom.PLAYER_IDS) if _teams else {}
	_team_row.visible = _teams and _kind != "find"
	if _teams:
		var order := ["red", "green", "blue", "purple"]
		joined = joined.duplicate()
		joined.sort_custom(func(a, b): return order.find(a) < order.find(b))
	for pid in joined:
		_seats.add_child(ProfileScreen.token_icon(String(BoardPanel.team_of.get(pid, pid)),
			PlayerProfile.emblem_of(String(pid))))
		var name_label := Label.new()
		if String(pid) == _net.seat:
			L10n.bind(name_label, "lobby.you", {"name": EventLogPanel.player_name(String(pid))})
		else:
			name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			name_label.text = EventLogPanel.player_name(String(pid))
		var seat_profile: Dictionary = _net.profiles.get(pid, {})
		# Щелчок по имени — карточка игрока (звание, рейтинг, партии).
		ProfileCard.attach(name_label, String(pid), func(): return seat_profile)
		_seats.add_child(name_label)
		# Звание камнем и рейтинг (подсказка — звание, партии и победы).
		if seat_profile.has("rating"):
			var rating := int(seat_profile["rating"])
			var badge := ProfileScreen.rank_badge(rating)
			L10n.bind(badge, "lobby.rating_tip", {"rank": {"l10n_key": ProfileScreen.rank_key(rating)}, "games": int(seat_profile.get("games", 0)), "wins": int(seat_profile.get("wins", 0))}, "tooltip_text")
			_seats.add_child(badge)
			var rating_label := Label.new()
			rating_label.text = str(rating)
			rating_label.add_theme_color_override("font_color", PlayerProfile.rank_colour(rating))
			_seats.add_child(rating_label)
	var full := joined.size() >= needed
	if _kind == "find":
		# Стол собрал сервер, он же и раздаёт — START не нужен.
		_start_button.visible = false
		L10n.bind(_status, "lobby.found_bans" if GameRoom.has_bans(NetSession.match_mode(needed)) else "lobby.found_dealing")
		return
	var i_start := owner_seat == _net.seat
	_start_button.visible = i_start
	_start_button.disabled = not full
	if full:
		L10n.bind(_status, "lobby.full_owner" if i_start else "lobby.full_guest", {"name": EventLogPanel.player_name(owner_seat)})
	else:
		var share: Variant = {"l10n_key": "lobby.share"} if _code_label != null and i_start else ""
		L10n.bind(_status, "lobby.room_wait", {"share": share, "joined": joined.size(), "needed": needed})


## Поиск игры: сколько уже ждут. Время ожидания тикает в _process.
func _on_queue_changed(waiting: int, needed: int) -> void:
	_queue_waiting = waiting
	_queue_needed = needed
	if _go_button != null:
		_go_button.visible = false
	if _searching_since < 0:
		_searching_since = Time.get_ticks_msec()
	_show_search_time()


func _process(delta: float) -> void:
	if _dealing != null:
		_dealing_time += delta
		var dots := int(_dealing_time * 2.5) % 4
		L10n.bind(_dealing_dots, "lobby.building_dots", {"dots": ".".repeat(dots) + " ".repeat(3 - dots)})
	if _searching_since >= 0:
		_show_search_time()
	# Кто из друзей в сети — раз в несколько секунд, пока сидим в комнате.
	if _in_room and not _net.started:
		_friends_wait -= delta
		if _friends_wait <= 0.0:
			_friends_wait = 10.0
			_net.friends_action("list")


## Друзья в сети и в лобби — кнопками; нажал — приглашение ушло.
func _on_friends(data: Dictionary) -> void:
	if String(data.get("note", "")) != "":
		L10n.bind(_invite_note, "lobby.raw", {"value": NetworkText.message(String(data["note"]))})
	for child in _invites.get_children():
		child.queue_free()
	var shown := 0
	for f: Dictionary in data.get("friends", []):
		if not ["ONLINE", "IN LOBBY"].has(String(f["status"])):
			continue
		var fname := String(f["name"])
		var b := _button(fname)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.pressed.connect(func():
			_net.friends_action("invite", [fname])
			b.disabled = true)
		_invites.add_child(b)
		shown += 1
	if shown == 0 and String(data.get("note", "")) == "":
		L10n.bind(_invite_note, "lobby.no_friends")


func _show_search_time() -> void:
	var seconds := (Time.get_ticks_msec() - _searching_since) / 1000
	L10n.bind(_status, "lobby.queue_time", {"queue": {"l10n_key": "lobby.queue", "parameters": {"waiting": _queue_waiting, "needed": _queue_needed}}, "clock": "%d:%02d" % [seconds / 60, seconds % 60]})


func _on_connection_lost(reason: String) -> void:
	_hide_bans()
	_hide_dealing()
	_searching_since = -1
	L10n.bind(_status, "lobby.reason", {"reason": NetworkText.message(reason)})
	_set_editable(true)
	if _go_button != null:
		_go_button.visible = true


func _on_upnp_finished(address: String, note: String) -> void:
	_internet_note.visible = true
	if address != "":
		L10n.bind(_internet, "lobby.raw", {"value": address})
		_internet.add_theme_color_override("font_color", PixelTheme.GOLD)
		L10n.bind(_internet_note, "lobby.internet_success", {"note": NetworkText.message(note)})
	else:
		L10n.bind(_internet, "lobby.unavailable")
		L10n.bind(_internet_note, "lobby.internet_fail", {"note": NetworkText.message(note)})


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
	L10n.scope(label)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	L10n.scope(button)
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


func _caption(text: String) -> Label:
	var label := GameScreen.section_label(text)
	L10n.scope(label)
	return label


func _description(col: VBoxContainer, key: String, mode: String) -> void:
	var label := _dim("")
	col.add_child(label)
	var mode_message := SetupScreen.mode_message(mode)
	L10n.bind(label, key, {"players": {"l10n_key": "lobby.teams"} if _teams else {"l10n_key": "lobby.players", "parameters": {"count": _count}}, "mode": mode_message, "port": NetSession.DEFAULT_PORT})
