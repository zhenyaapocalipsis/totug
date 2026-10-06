class_name ProfileCard
extends Control

## Карточка игрока по щелчку на его имя (решение владельца, 2026-09-28): в
## лобби и в таблице игроков партии. Фишка с гербом, имя, звание камнем,
## рейтинг, партии и победы, любимая карта в образе игрока — то, что сервер
## раздал вместе с профилями
## (NetSession.profiles: rating, games, wins). За одним экраном рейтинга нет —
## только имя и герб.
##
## Карточка лежит поверх всего экрана; щелчок куда угодно или Esc закрывает.

const GAP := Vector2(6, 6)

var _panel: PanelContainer


## Открыть карточку у мыши. profile — {name, emblem, rating?, games?, wins?}.
static func open(anchor: Control, pid: String, profile: Dictionary) -> ProfileCard:
	var card := ProfileCard.new(pid, profile)
	anchor.get_tree().root.add_child(card)
	card._place.call_deferred(anchor.get_global_mouse_position())
	return card


func _init(pid: String = "", profile: Dictionary = {}) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()
	z_index = 1200
	mouse_filter = Control.MOUSE_FILTER_STOP

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", GameScreen.zone_style(6))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	var token := ProfileScreen.token_icon(pid, String(profile.get("emblem", "")))
	token.stretch_mode = TextureRect.STRETCH_SCALE
	token.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	token.custom_minimum_size = Vector2.ONE * PlayerProfile.SIZE * 2
	head.add_child(token)
	var name_label := Label.new()
	var player_name := String(profile.get("name", ""))
	name_label.text = player_name if player_name != "" else pid.capitalize()
	name_label.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	name_label.add_theme_color_override("font_color", BoardPanel.PLAYER_COLORS.get(pid, PixelTheme.TEXT))
	head.add_child(name_label)
	# Любимая карта игрока — справа, в его образе.
	var fav := ProfileScreen.favourite_view(String(profile.get("favourite", "")), str(profile.get("shader", "")),
		String(profile.get("arts", "")))
	if fav != null:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(spacer)
		head.add_child(fav)

	if not profile.has("rating"):
		col.add_child(_line("No online rating.", PixelTheme.TEXT_DIM))
		return
	var rating := int(profile["rating"])
	var rank := HBoxContainer.new()
	rank.add_theme_constant_override("separation", 6)
	col.add_child(rank)
	rank.add_child(ProfileScreen.rank_badge(rating, 2))
	rank.add_child(_line(PlayerProfile.rank_title(rating), PlayerProfile.rank_colour(rating)))
	rank.add_child(_line("RATING %d" % rating, PixelTheme.TEXT))
	var games := int(profile.get("games", 0))
	var wins := int(profile.get("wins", 0))
	col.add_child(_line("GAMES %d   WINS %d   WIN RATE %s" % [games, wins,
		("%d%%" % roundi(100.0 * wins / games)) if games > 0 else "-"], PixelTheme.TEXT_DIM))


func _line(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", colour)
	return label


## Рядом с мышью, но целиком на экране.
func _place(at: Vector2) -> void:
	var box := _panel.get_combined_minimum_size()
	_panel.size = box
	var screen := get_viewport_rect().size
	var pos := at + GAP
	if pos.x + box.x > screen.x:
		pos.x = at.x - GAP.x - box.x
	if pos.y + box.y > screen.y:
		pos.y = at.y - GAP.y - box.y
	_panel.position = pos.clamp(Vector2.ZERO, (screen - box).max(Vector2.ZERO))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		queue_free()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		queue_free()
		get_viewport().set_input_as_handled()


## Сделать надпись имени кликабельной: щелчок — карточка этого игрока.
## profile_of вызывается в момент щелчка (профили приходят по сети позже).
static func attach(label: Control, pid: String, profile_of: Callable) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	label.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			ProfileCard.open(label, pid, profile_of.call())
			label.accept_event())
