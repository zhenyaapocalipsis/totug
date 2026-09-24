class_name ProfileScreen
extends Control

## Профиль игрока: имя и герб. Герб рисуется в маленьком пиксельном
## редакторе, холст которого — сама фишка войска 9x9 (PlayerProfile): ободок
## не красится, пустые пиксели на доске будут цветом места игрока. Целиком
## закрасить нельзя — хотя бы PlayerProfile.MIN_SEAT_PIXELS остаются пустыми.
##
## Левая кнопка мыши — красить, правая — стирать (можно вести с зажатой
## кнопкой). Вёрстка кодом, как у остальных экранов меню.

signal closed

## Палитра DawnBringer 32 — классический набор для пиксель-арта; любой другой
## цвет — щелчком по образцу кисти (ColorPickerButton).
const PALETTE := [
	"000000", "222034", "45283c", "663931", "8f563b", "df7126", "d9a066", "eec39a",
	"fbf236", "99e550", "6abe30", "37946e", "4b692f", "524b24", "323c39", "3f3f74",
	"306082", "5b6ee1", "639bff", "5fcde4", "cbdbfc", "ffffff", "9badb7", "847e87",
	"696a6a", "595652", "76428a", "ac3232", "d95763", "d77bba", "8f974a", "8a6f30",
]
const CELL := 18
const SWATCH := 14
const PREVIEW_ZOOM := 3
const RIM := Color(0.04, 0.03, 0.06)
const BUTTON_SIZE := Vector2(70, 16)
const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")

var _pixels: Array[Color] = []
var _brush := Color("ffffff")
var _seat := "red"
var _name_edit: LineEdit
var _canvas: Control
var _custom: ColorPickerButton
var _previews: Array[TextureRect] = []
var _saved_note: Label
## Сколько пикселей ещё можно закрасить (PlayerProfile.MIN_SEAT_PIXELS).
var _counter: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()
	add_child(UnderdarkBg.make())

	var local := PlayerProfile.load_local()
	_pixels = PlayerProfile.emblem_pixels(String(local["emblem"]))

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", GameScreen.zone_style(6))
	centre.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var title := Label.new()
	title.text = "PLAYER PROFILE"
	title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	col.add_child(GameScreen.section_label("NAME"))
	_name_edit = LineEdit.new()
	_name_edit.max_length = PlayerProfile.NAME_MAX
	_name_edit.placeholder_text = "Your name"
	_name_edit.text = String(local["name"])
	_name_edit.custom_minimum_size = Vector2(160, 0)
	_name_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_name_edit)

	col.add_child(HSeparator.new())
	col.add_child(GameScreen.section_label("EMBLEM: YOUR TROOP ON THE BOARD"))
	var editor := HBoxContainer.new()
	editor.add_theme_constant_override("separation", 10)
	editor.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(editor)

	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(CELL * PlayerProfile.SIZE + 1, CELL * PlayerProfile.SIZE + 1)
	_canvas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_canvas_input)
	editor.add_child(_canvas)

	editor.add_child(_tools())

	col.add_child(GameScreen.section_label("PREVIEW (CLICK A COLOUR TO TRY IT)"))
	var previews := HBoxContainer.new()
	previews.add_theme_constant_override("separation", 8)
	previews.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(previews)
	for pid: String in GameRoom.PLAYER_IDS:
		var big := TextureRect.new()
		big.custom_minimum_size = Vector2.ONE * PlayerProfile.SIZE * PREVIEW_ZOOM
		big.stretch_mode = TextureRect.STRETCH_SCALE
		big.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		big.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		big.tooltip_text = pid.capitalize()
		big.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed:
				_seat = pid
				_canvas.queue_redraw())
		previews.add_child(big)
		var small := TextureRect.new()
		small.custom_minimum_size = Vector2.ONE * PlayerProfile.SIZE
		small.stretch_mode = TextureRect.STRETCH_KEEP
		small.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		previews.add_child(small)
		_previews.append(big)
		_previews.append(small)

	var hint := Label.new()
	hint.text = "Left mouse: paint. Right mouse: erase.\nEmpty pixels show your seat colour."
	hint.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

	col.add_child(HSeparator.new())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 6)
	col.add_child(buttons)
	buttons.add_child(_button("SAVE", _save))
	buttons.add_child(_button("CANCEL", func(): closed.emit()))
	_saved_note = Label.new()
	_saved_note.add_theme_color_override("font_color", PixelTheme.GOLD)
	_saved_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_saved_note)

	_refresh_previews()
	_refresh_counter()


## Палитра, текущий цвет (он же выбор любого цвета) и ERASE ALL.
func _tools() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	box.add_child(grid)
	for hex: String in PALETTE:
		var swatch := ColorRect.new()
		swatch.color = Color(hex)
		swatch.custom_minimum_size = Vector2(SWATCH, SWATCH)
		swatch.tooltip_text = "#" + hex
		swatch.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_set_brush(Color(hex)))
		grid.add_child(swatch)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	var label := Label.new()
	label.text = "BRUSH"
	label.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	row.add_child(label)
	# Сам образец кисти — кнопка выбора любого цвета.
	_custom = ColorPickerButton.new()
	_custom.edit_alpha = false
	_custom.color = _brush
	_custom.custom_minimum_size = Vector2(SWATCH * 3, SWATCH)
	_custom.tooltip_text = "Click to pick any colour"
	SetupScreen._style_button(_custom)
	_custom.color_changed.connect(_set_brush)
	row.add_child(_custom)
	var any := Label.new()
	any.text = "< any colour"
	any.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	row.add_child(any)

	_counter = Label.new()
	box.add_child(_counter)

	box.add_child(_button("ERASE ALL", func():
		_pixels.fill(Color(0, 0, 0, 0))
		_changed()))
	return box


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	SetupScreen._style_button(b)
	b.pressed.connect(action)
	return b


func _set_brush(colour: Color) -> void:
	_brush = Color(colour, 1.0)
	_custom.color = _brush


func _canvas_input(event: InputEvent) -> void:
	var mask := 0
	if event is InputEventMouseButton and event.pressed:
		mask = MOUSE_BUTTON_MASK_LEFT if event.button_index == MOUSE_BUTTON_LEFT \
			else MOUSE_BUTTON_MASK_RIGHT if event.button_index == MOUSE_BUTTON_RIGHT else 0
	elif event is InputEventMouseMotion:
		mask = event.button_mask
	if mask == 0:
		return
	var cell := Vector2i((event.position / CELL).floor())
	paint(cell.x, cell.y, _brush if mask & MOUSE_BUTTON_MASK_LEFT else Color(0, 0, 0, 0))
	_canvas.accept_event()


## Покрасить одну клетку (прозрачный цвет — стереть). Вне кружка — ничего.
func paint(x: int, y: int, colour: Color) -> void:
	if x < 0 or y < 0 or x >= PlayerProfile.SIZE or y >= PlayerProfile.SIZE:
		return
	if not PlayerProfile.paintable(x, y):
		return
	var i := y * PlayerProfile.SIZE + x
	if _pixels[i] == colour:
		return
	# Новый закрашенный пиксель — только пока цвета места остаётся достаточно.
	if colour.a > 0.0 and _pixels[i].a == 0.0 \
			and PlayerProfile.painted_count(_pixels) >= PlayerProfile.max_painted():
		_saved_note.text = "Keep at least %d pixels in your seat colour." % PlayerProfile.MIN_SEAT_PIXELS
		return
	_pixels[i] = colour
	_changed()


func _changed() -> void:
	_saved_note.text = ""
	_canvas.queue_redraw()
	_refresh_previews()
	_refresh_counter()


func _refresh_counter() -> void:
	var left := PlayerProfile.max_painted() - PlayerProfile.painted_count(_pixels)
	_counter.text = "Pixels left to paint: %d" % left
	_counter.add_theme_color_override("font_color", PixelTheme.GOLD if left == 0 else PixelTheme.TEXT_DIM)


func emblem() -> String:
	return PlayerProfile.emblem_from_pixels(_pixels)


func _draw_canvas() -> void:
	var seat_colour: Color = BoardPanel.PLAYER_COLORS.get(_seat, Color.GRAY)
	var r := PlayerProfile.RADIUS
	for y in PlayerProfile.SIZE:
		for x in PlayerProfile.SIZE:
			var rect := Rect2(x * CELL + 1, y * CELL + 1, CELL - 1, CELL - 1)
			var dx := x - r
			var dy := y - r
			var colour := PixelTheme.PANEL_LO if (x + y) % 2 == 0 else PixelTheme.PANEL
			if PlayerProfile.paintable(x, y):
				var px := _pixels[y * PlayerProfile.SIZE + x]
				colour = px if px.a > 0.0 else seat_colour
			elif dx * dx + dy * dy <= r * r + r:
				colour = RIM
			_canvas.draw_rect(rect, colour)
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.custom_minimum_size), PixelTheme.BORDER, false, 1.0)


func _refresh_previews() -> void:
	var e := emblem()
	for i in _previews.size():
		var pid: String = GameRoom.PLAYER_IDS[i / 2]
		var tex := ImageTexture.create_from_image(
			SchematicPainter.token(BoardPanel.PLAYER_COLORS.get(pid, Color.GRAY), e))
		_previews[i].texture = tex


func _save() -> void:
	var name_text := PlayerProfile.clean_name(_name_edit.text)
	_name_edit.text = name_text
	var err := PlayerProfile.save_local({"name": name_text, "emblem": emblem()})
	if err == OK:
		closed.emit()
	else:
		_saved_note.text = "Could not save the profile (error %d)." % err


## Значок фишки игрока (цвет места + его герб) для списков в меню и лобби.
static func token_icon(pid: String, emblem_hex: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = ImageTexture.create_from_image(
		SchematicPainter.token(BoardPanel.PLAYER_COLORS.get(pid, Color.GRAY), emblem_hex))
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	icon.custom_minimum_size = Vector2.ONE * PlayerProfile.SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon
