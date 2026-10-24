extends Control

## Ручная подгонка выреза мини-карт (владелец, 2026-10-24). Арт мини 52x53 —
## кусок 1:1 из арта большой карты (assets/cards_pixel, у альт-артов
## assets/cards_alt); здесь рамку выреза двигают мышью и стрелками. Каждое
## изменение сразу пишется в PNG мини-карты и в data/cards/mini_faces.json —
## оттуда вырез берёт tools/pixel_cards.gd при следующей перерисовке.
## Запуск: mini-crop-editor.bat в корне репозитория.

const FACES_JSON := "res://data/cards/mini_faces.json"
const FULL_DIR := "res://assets/cards_pixel/"
const MINI_DIR := "res://assets/cards_mini/"
const ALT_FULL_DIR := "res://assets/cards_alt/"
const ALT_MINI_DIR := "res://assets/cards_alt_mini/"
## Те же числа, что в tools/pixel_cards.gd.
const FULL_ART_POS := Vector2i(6, 34)
const FULL_ART_SIZE := Vector2i(164, 100)
const MINI_ART_POS := Vector2i(3, 28)
const MINI_ART_SIZE := Vector2i(52, 53)
const MAX_FACE := FULL_ART_SIZE - MINI_ART_SIZE
const FACE_DEFAULT := Vector2i(56, 12)
const ZOOM := 3
const FONT := 11

var faces := {}  # "48302" / "48310_1" -> [x, y]
var entries: Array[Dictionary] = []  # key, name, full, mini
var shown: Array[int] = []  # строки списка -> индексы entries
var cur := -1
var full_img: Image
var mini_img: Image
var face := Vector2i.ZERO
var opened_face := Vector2i.ZERO
var saved_face := Vector2i.ZERO
var found := true
var dragging := false
var drag_from := Vector2i.ZERO

var list: ItemList
var filter: LineEdit
var title: Label
var art: TextureRect
var frame: Control
var mini_view: TextureRect
var before_view: TextureRect


func _ready() -> void:
	if FileAccess.file_exists(FACES_JSON):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FACES_JSON))
		if parsed is Dictionary:
			for k: String in parsed:
				faces[k] = [int(parsed[k][0]), int(parsed[k][1])]
	_collect()
	_build_ui()
	_refill()
	if not shown.is_empty():
		_open(shown[0])


func _collect() -> void:
	var names := {}
	for c: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/cards.json")):
		names[str(int(c["card_id"]))] = String(c["name"])
	for f in _pngs(MINI_DIR):
		if FileAccess.file_exists(FULL_DIR + f):
			var key := f.get_basename()
			entries.append({"key": key, "name": "%s  %s" % [key, names.get(key, "?")],
				"full": FULL_DIR + f, "mini": MINI_DIR + f})
	for f in _pngs(ALT_MINI_DIR):
		if FileAccess.file_exists(ALT_FULL_DIR + f):
			var key := f.get_basename()
			entries.append({"key": key, "name": "%s  %s (alt)" % [key, names.get(key.get_slice("_", 0), "?")],
				"full": ALT_FULL_DIR + f, "mini": ALT_MINI_DIR + f})


func _pngs(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == "png":
			out.append(f)
	out.sort()
	return out


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	filter = LineEdit.new()
	filter.placeholder_text = "search: name or id"
	filter.position = Vector2(8, 6)
	filter.size = Vector2(200, 22)
	filter.add_theme_font_size_override("font_size", FONT)
	filter.text_changed.connect(func(_t: String) -> void: _refill())
	add_child(filter)

	list = ItemList.new()
	list.position = Vector2(8, 32)
	list.size = Vector2(200, 500)
	list.focus_mode = FOCUS_NONE
	list.add_theme_font_size_override("font_size", FONT)
	list.item_selected.connect(func(row: int) -> void: _open(shown[row]))
	add_child(list)

	title = Label.new()
	title.position = Vector2(220, 6)
	title.add_theme_font_size_override("font_size", FONT + 1)
	add_child(title)

	art = TextureRect.new()
	art.position = Vector2(220, 30)
	art.size = Vector2(FULL_ART_SIZE * ZOOM)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture_filter = TEXTURE_FILTER_NEAREST
	art.mouse_default_cursor_shape = CURSOR_MOVE
	art.gui_input.connect(_art_input)
	add_child(art)

	frame = Control.new()
	frame.set_anchors_preset(PRESET_FULL_RECT)
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	frame.draw.connect(_draw_frame)
	art.add_child(frame)

	mini_view = _mini_rect(Vector2(730, 30), 3)
	_label("now", Vector2(730, 284))
	before_view = _mini_rect(Vector2(730, 304), 2)
	_label("when opened", Vector2(850, 304))

	var help := Label.new()
	help.position = Vector2(220, 340)
	help.add_theme_font_size_override("font_size", FONT)
	help.text = ("Drag the frame with the mouse (or click where it should be).\n"
		+ "Arrows: 1 px, Shift + arrows: 5 px.  PgUp / PgDn: previous / next card.\n"
		+ "Esc: back to the crop the card had when opened.\n"
		+ "Every change is saved at once (mini PNG + data/cards/mini_faces.json).")
	add_child(help)

	var x := 220.0
	for b: Array in [["< Prev", func() -> void: _step(-1)], ["Next >", func() -> void: _step(1)],
			["Undo (Esc)", _undo], ["Quit", func() -> void: get_tree().quit()]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = FOCUS_NONE
		btn.position = Vector2(x, 420)
		btn.size = Vector2(90, 24)
		btn.add_theme_font_size_override("font_size", FONT)
		btn.pressed.connect(b[1])
		add_child(btn)
		x += 100.0


func _mini_rect(at: Vector2, zoom: int) -> TextureRect:
	var t := TextureRect.new()
	t.position = at
	t.size = Vector2(58, 84) * zoom
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.texture_filter = TEXTURE_FILTER_NEAREST
	add_child(t)
	return t


func _label(text: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", FONT)
	add_child(l)


func _refill() -> void:
	list.clear()
	shown.clear()
	for i in entries.size():
		if filter.text == "" or String(entries[i]["name"]).containsn(filter.text):
			shown.append(i)
			list.add_item(_row_text(i))
	var row := shown.find(cur)
	if row >= 0:
		list.select(row)
		list.ensure_current_is_visible()


func _row_text(i: int) -> String:
	return ("* " if faces.has(entries[i]["key"]) else "  ") + String(entries[i]["name"])


func _open(i: int) -> void:
	cur = i
	var e := entries[i]
	full_img = _load(e["full"])
	mini_img = _load(e["mini"])
	before_view.texture = ImageTexture.create_from_image(mini_img)
	art.texture = ImageTexture.create_from_image(full_img.get_region(Rect2i(FULL_ART_POS, FULL_ART_SIZE)))
	found = true
	if faces.has(e["key"]):
		face = Vector2i(faces[e["key"]][0], faces[e["key"]][1])
	else:
		face = _detect()
	opened_face = face
	saved_face = face
	var row := shown.find(i)
	if row >= 0:
		list.select(row)
		list.ensure_current_is_visible()
	_refresh()


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img


## Где вырез сейчас: ищем в арте большой карты место, совпадающее с артом мини.
func _detect() -> Vector2i:
	for y in MAX_FACE.y + 1:
		for x in MAX_FACE.x + 1:
			if _matches(Vector2i(x, y)):
				return Vector2i(x, y)
	found = false
	return FACE_DEFAULT


func _matches(at: Vector2i) -> bool:
	for y in range(0, MINI_ART_SIZE.y, 3):
		for x in range(0, MINI_ART_SIZE.x, 3):
			if full_img.get_pixel(FULL_ART_POS.x + at.x + x, FULL_ART_POS.y + at.y + y) \
					!= mini_img.get_pixel(MINI_ART_POS.x + x, MINI_ART_POS.y + y):
				return false
	return true


func _composed() -> Image:
	var m := mini_img.duplicate() as Image
	m.blit_rect(full_img, Rect2i(FULL_ART_POS + face, MINI_ART_SIZE), MINI_ART_POS)
	return m


func _refresh() -> void:
	mini_view.texture = ImageTexture.create_from_image(_composed())
	frame.queue_redraw()
	var e := entries[cur]
	title.text = "%s    crop x=%d y=%d%s" % [e["name"], face.x, face.y,
		"" if found else "   (old crop not found, default shown)"]


func _save() -> void:
	if face == saved_face:
		return
	var e := entries[cur]
	_composed().save_png(ProjectSettings.globalize_path(e["mini"]))
	faces[e["key"]] = [face.x, face.y]
	var f := FileAccess.open(FACES_JSON, FileAccess.WRITE)
	f.store_string(JSON.stringify(faces, "\t", true) + "\n")
	f.close()
	saved_face = face
	var row := shown.find(cur)
	if row >= 0:
		list.set_item_text(row, _row_text(cur))


func _move_to(v: Vector2i) -> void:
	face = v.clamp(Vector2i.ZERO, MAX_FACE)
	_refresh()


func _undo() -> void:
	if cur >= 0:
		_move_to(opened_face)
		_save()


func _step(d: int) -> void:
	if shown.is_empty():
		return
	var row := shown.find(cur)
	_open(shown[clampi(row + d, 0, shown.size() - 1)])


func _draw_frame() -> void:
	var r := Rect2(Vector2(face * ZOOM), Vector2(MINI_ART_SIZE * ZOOM))
	var full := frame.size
	var shade := Color(0, 0, 0, 0.55)
	frame.draw_rect(Rect2(0, 0, full.x, r.position.y), shade)
	frame.draw_rect(Rect2(0, r.end.y, full.x, full.y - r.end.y), shade)
	frame.draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), shade)
	frame.draw_rect(Rect2(r.end.x, r.position.y, full.x - r.end.x, r.size.y), shade)
	frame.draw_rect(r, Color(1, 0.85, 0.2), false, 1.0)


func _art_input(ev: InputEvent) -> void:
	if cur < 0:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		var p := Vector2i(ev.position / ZOOM)
		if ev.pressed:
			if not Rect2i(face, MINI_ART_SIZE).has_point(p):
				_move_to(p - MINI_ART_SIZE / 2)
			drag_from = p - face
			dragging = true
		else:
			dragging = false
			_save()
	elif ev is InputEventMouseMotion and dragging:
		_move_to(Vector2i(ev.position / ZOOM) - drag_from)


func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed) or cur < 0:
		return
	var step := 5 if ev.shift_pressed else 1
	var d := Vector2i.ZERO
	match ev.keycode:
		KEY_PAGEUP:
			_step(-1)
		KEY_PAGEDOWN:
			_step(1)
		KEY_ESCAPE:
			_undo()
		KEY_LEFT:
			d = Vector2i(-step, 0)
		KEY_RIGHT:
			d = Vector2i(step, 0)
		KEY_UP:
			d = Vector2i(0, -step)
		KEY_DOWN:
			d = Vector2i(0, step)
		_:
			return
	if d != Vector2i.ZERO:
		if filter.has_focus():
			return
		_move_to(face + d)
		_save()
	get_viewport().set_input_as_handled()
