class_name BackgroundScreen
extends Control

## Фон игры (решение владельца, 2026-09-28): открывается из профиля.
##
## Сверху — выбор фона (UnderdarkBg.STYLES); выбранный сразу виден за этим же
## окном и на всех экранах. Ниже — рисовалка своего фона MY DRAWING: холст
## UnderdarkBg.PICTURE_SIZE, растягивается на весь экран (клетка холста —
## 6x6 пикселей экрана 960x540).
##
## Левая кнопка — красить (кистью SIZE или заливкой FILL), правая — взять
## цвет с рисунка. UNDO (и Ctrl+Z) отменяет последний мазок. SAVE DRAWING
## сохраняет рисунок и ставит его фоном.

signal closed

const ZOOM := 3
const SWATCH := 12
const BUTTON_SIZE := Vector2(70, 16)
const BRUSH_SIZES := [1, 2, 4]
const UNDO_MAX := 30
const UnderdarkBg := preload("res://scenes/ui/underdark_bg.gd")

var _image: Image
var _texture: ImageTexture
var _canvas: TextureRect
var _brush := Color("ffffff")
var _custom: ColorPickerButton
var _size := 1
var _size_button: Button
var _fill := false
var _fill_button: Button
var _undo: Array[Image] = []
## Мазок идёт: левая кнопка зажата, клетки между событиями мыши соединяются.
var _stroke := false
var _last := Vector2i.ZERO
var _style_buttons: Dictionary = {}
var _note: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PixelTheme.theme()
	add_child(UnderdarkBg.make())

	_image = UnderdarkBg.picture()
	if _image == null or _image.get_size() != UnderdarkBg.PICTURE_SIZE:
		_image = Image.create(UnderdarkBg.PICTURE_SIZE.x, UnderdarkBg.PICTURE_SIZE.y, false, Image.FORMAT_RGB8)
		_image.fill(PixelTheme.BG)
	_image.convert(Image.FORMAT_RGB8)
	_texture = ImageTexture.create_from_image(_image)

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
	title.text = "BACKGROUND"
	title.add_theme_font_size_override("font_size", PixelTheme.SIZE_BIG)
	title.add_theme_color_override("font_color", PixelTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var styles := HBoxContainer.new()
	styles.alignment = BoxContainer.ALIGNMENT_CENTER
	styles.add_theme_constant_override("separation", 4)
	col.add_child(styles)
	var group := ButtonGroup.new()
	for style: String in UnderdarkBg.STYLES:
		var b := _button(String(UnderdarkBg.STYLE_NAMES[style]), choose_style.bind(style))
		b.custom_minimum_size.x = 0
		b.toggle_mode = true
		b.button_group = group
		styles.add_child(b)
		_style_buttons[style] = b
	(_style_buttons[UnderdarkBg.STYLE_CUSTOM] as Button).tooltip_text = "The picture drawn below."

	col.add_child(GameScreen.section_label("MY DRAWING (STRETCHED OVER THE WHOLE SCREEN)"))
	var editor := HBoxContainer.new()
	editor.add_theme_constant_override("separation", 8)
	editor.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(editor)

	_canvas = TextureRect.new()
	_canvas.texture = _texture
	_canvas.custom_minimum_size = Vector2(UnderdarkBg.PICTURE_SIZE * ZOOM)
	_canvas.stretch_mode = TextureRect.STRETCH_SCALE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.gui_input.connect(_canvas_input)
	editor.add_child(_canvas)
	editor.add_child(_tools())

	var hint := Label.new()
	hint.text = "Left mouse: paint. Right mouse: take a colour from the picture. Ctrl+Z: undo."
	hint.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

	col.add_child(HSeparator.new())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 6)
	col.add_child(buttons)
	var save := _button("SAVE DRAWING", _save)
	save.custom_minimum_size.x = 90
	buttons.add_child(save)
	buttons.add_child(_button("BACK", func(): closed.emit()))
	_note = Label.new()
	_note.add_theme_color_override("font_color", PixelTheme.GOLD)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_note)

	_refresh_styles()


## Палитра (та же, что у герба), кисть любого цвета, размер, заливка, отмена.
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
				set_brush(Color(hex)))
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
	_custom.custom_minimum_size = Vector2(SWATCH * 4, SWATCH)
	_custom.tooltip_text = "Click to pick any colour"
	SetupScreen._style_button(_custom)
	_custom.color_changed.connect(set_brush)
	row.add_child(_custom)

	_size_button = _button("SIZE: 1", func():
		set_brush_size(BRUSH_SIZES[(BRUSH_SIZES.find(_size) + 1) % BRUSH_SIZES.size()]))
	_size_button.tooltip_text = "Brush size in cells: 1, 2 or 4."
	box.add_child(_size_button)
	_fill_button = _button("FILL: OFF", func(): pass)
	_fill_button.toggle_mode = true
	_fill_button.tooltip_text = "Click an area to fill it with the brush colour."
	_fill_button.toggled.connect(set_fill)
	box.add_child(_fill_button)
	box.add_child(_button("UNDO", undo))
	var all := _button("FILL ALL", func():
		_push_undo()
		_image.fill(_brush)
		_changed())
	all.tooltip_text = "Paint the whole picture with the brush colour."
	box.add_child(all)
	return box


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	SetupScreen._style_button(b)
	b.pressed.connect(action)
	return b


# --- выбор фона -----------------------------------------------------------

## Выбрать фон. MY DRAWING — то, что сейчас на холсте (оно и сохраняется).
func choose_style(style: String) -> void:
	if style == UnderdarkBg.STYLE_CUSTOM:
		_save()
		return
	UnderdarkBg.set_style(style)
	_refresh_styles()


func _refresh_styles() -> void:
	for style: String in _style_buttons:
		(_style_buttons[style] as Button).set_pressed_no_signal(style == UnderdarkBg.style())


# --- рисование ------------------------------------------------------------

func set_brush(colour: Color) -> void:
	_brush = Color(colour, 1.0)
	_custom.color = _brush


func set_brush_size(value: int) -> void:
	_size = value if BRUSH_SIZES.has(value) else 1
	_size_button.text = "SIZE: %d" % _size


func set_fill(on: bool) -> void:
	_fill = on
	_fill_button.set_pressed_no_signal(on)
	_fill_button.text = "FILL: ON" if on else "FILL: OFF"


func pixel(x: int, y: int) -> Color:
	return _image.get_pixel(x, y)


func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var cell := _cell_at(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_push_undo()
				if _fill:
					fill_at(cell.x, cell.y)
				else:
					_stroke = true
					_last = cell
					paint_at(cell.x, cell.y)
			else:
				_stroke = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _inside(cell):
			set_brush(pixel(cell.x, cell.y))
		_canvas.accept_event()
	elif event is InputEventMouseMotion and _stroke:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_stroke = false
			return
		var cell := _cell_at(event.position)
		# Быстрый взмах мышью: клетки между событиями тоже закрашиваются.
		var steps := maxi(absi(cell.x - _last.x), absi(cell.y - _last.y))
		for i in range(1, steps + 1):
			var p := Vector2(_last).lerp(Vector2(cell), float(i) / steps).round()
			paint_at(int(p.x), int(p.y))
		_last = cell
		_canvas.accept_event()


func _cell_at(position: Vector2) -> Vector2i:
	return Vector2i((position / ZOOM).floor())


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _image.get_width() and cell.y < _image.get_height()


## Кисть размером _size с центром в клетке (края холста обрезают кисть).
func paint_at(x: int, y: int) -> void:
	var from := Vector2i(x, y) - Vector2i.ONE * (_size / 2)
	var rect := Rect2i(from, Vector2i.ONE * _size).intersection(Rect2i(Vector2i.ZERO, _image.get_size()))
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	_image.fill_rect(rect, _brush)
	_changed()


## Заливка: все клетки того же цвета, связанные с этой по сторонам.
func fill_at(x: int, y: int) -> void:
	if not _inside(Vector2i(x, y)):
		return
	var target := _image.get_pixel(x, y)
	if target == _brush:
		return
	var w := _image.get_width()
	var h := _image.get_height()
	var stack: Array[Vector2i] = [Vector2i(x, y)]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h or _image.get_pixelv(c) != target:
			continue
		_image.set_pixelv(c, _brush)
		stack.append_array([c + Vector2i.RIGHT, c + Vector2i.LEFT, c + Vector2i.DOWN, c + Vector2i.UP])
	_changed()


func _push_undo() -> void:
	_undo.append(_image.duplicate())
	if _undo.size() > UNDO_MAX:
		_undo.pop_front()


func undo() -> void:
	if _undo.is_empty():
		return
	_image = _undo.pop_back()
	_changed()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_Z and key.ctrl_pressed:
		undo()
		get_viewport().set_input_as_handled()


func _changed() -> void:
	_note.text = ""
	_texture.update(_image)


func _save() -> void:
	var err: int = UnderdarkBg.save_picture(_image.duplicate())
	_note.text = "Saved: your drawing is the background now." if err == OK \
		else "Could not save the drawing (error %d)." % err
	_refresh_styles()
