class_name CardBackScreen
extends Control

## Рисовалка рубашки карт — как герб в ProfileScreen, только холст больше:
## рисунок PlayerProfile.BACK_SIZE x BACK_SIZE встаёт в центр рубашки
## (CardBack). Соперники видят рубашку, когда игрок берёт карту вслепую
## (промоут верхней карты колоды, CardShowcase). Справа — рубашка целиком 1:1.
##
## Левая кнопка мыши — красить, правая — стирать (можно вести с зажатой
## кнопкой). MIRROR красит сразу и зеркальную клетку.

signal closed

const CELL := 7
const SWATCH := 14
const BUTTON_SIZE := Vector2(70, 16)
const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")

var _pixels: Array[Color] = []
var _brush := Color("ffffff")
var _mirror := false
var _mirror_button: Button
var _canvas: Control
var _custom: ColorPickerButton
var _preview: TextureRect
var _note: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()
	add_child(UnderdarkBg.make())
	_pixels = PlayerProfile.back_pixels(String(PlayerProfile.load_local()["back"]))

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
	title.text = "CARD BACK"
	title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(GameScreen.section_label("OPPONENTS SEE IT WHEN YOU TAKE A CARD UNSEEN"))

	var editor := HBoxContainer.new()
	editor.add_theme_constant_override("separation", 10)
	editor.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(editor)

	var n := PlayerProfile.BACK_SIZE
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(CELL * n + 1, CELL * n + 1)
	_canvas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_canvas_input)
	editor.add_child(_canvas)

	editor.add_child(_tools())

	_preview = TextureRect.new()
	_preview.custom_minimum_size = CardView.PIXEL_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP
	_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_preview.texture = ImageTexture.create_from_image(CardBack.image(back()))
	editor.add_child(_preview)

	var hint := Label.new()
	hint.text = "Left mouse: paint. Right mouse: erase.\nAn empty drawing keeps the standard back."
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
	_note = Label.new()
	_note.add_theme_color_override("font_color", PixelTheme.GOLD)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_note)


## Палитра (та же, что у герба), текущий цвет, MIRROR и ERASE ALL.
func _tools() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	box.add_child(grid)
	for hex: String in ProfileScreen.PALETTE:
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

	_mirror_button = _button("MIRROR: OFF", func(): pass)
	_mirror_button.toggle_mode = true
	_mirror_button.tooltip_text = "Paint the left and right halves together."
	_mirror_button.toggled.connect(set_mirror)
	box.add_child(_mirror_button)

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


func set_mirror(on: bool) -> void:
	_mirror = on
	_mirror_button.set_pressed_no_signal(on)
	_mirror_button.text = "MIRROR: ON" if on else "MIRROR: OFF"


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


## Покрасить клетку (прозрачный цвет — стереть), с MIRROR — и зеркальную.
func paint(x: int, y: int, colour: Color) -> void:
	var n := PlayerProfile.BACK_SIZE
	if x < 0 or y < 0 or x >= n or y >= n:
		return
	var changed := false
	for cx in ([x, n - 1 - x] if _mirror else [x]):
		var i: int = y * n + cx
		if _pixels[i] != colour:
			_pixels[i] = colour
			changed = true
	if changed:
		_changed()


func _changed() -> void:
	_note.text = ""
	_canvas.queue_redraw()
	(_preview.texture as ImageTexture).update(CardBack.image(back()))


func back() -> String:
	return PlayerProfile.back_from_pixels(_pixels)


## Пустая клетка — цвет поля рубашки, как её и увидят в игре.
func _draw_canvas() -> void:
	var n := PlayerProfile.BACK_SIZE
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.custom_minimum_size), PixelTheme.PANEL_LO)
	for y in n:
		for x in n:
			var px := _pixels[y * n + x]
			_canvas.draw_rect(Rect2(x * CELL + 1, y * CELL + 1, CELL - 1, CELL - 1),
				px if px.a > 0.0 else CardBack.FIELD)
	# Середина — ориентир для симметричных рисунков.
	var mid := n / 2 * CELL
	_canvas.draw_rect(Rect2(mid, 0, 1, _canvas.custom_minimum_size.y), PixelTheme.BORDER)
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.custom_minimum_size), PixelTheme.BORDER, false, 1.0)


func _save() -> void:
	var err := PlayerProfile.save_back(back())
	if err == OK:
		closed.emit()
	else:
		_note.text = "Could not save the card back (error %d)." % err
