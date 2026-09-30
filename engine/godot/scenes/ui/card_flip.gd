class_name CardFlip
extends Control

## Карта, которую можно покрутить мышью (коллекция → CARD BACKS): с одной
## стороны рубашка, с другой — лицо карты в образе. Тянешь вбок — карта
## поворачивается вокруг вертикальной оси; отпустил — докручивается по инерции
## и встаёт ровно рубашкой или лицом к игроку (тогда пиксели снова ровные).
##
## Поворот честный, с перспективой: карта режется на вертикальные полоски, и
## каждая рисуется на своей глубине. Стороны — два дочерних слоя, видна одна;
## у лица свой шейдер образа.

## Сколько полосок и насколько близко «камера» (меньше — сильнее перспектива).
const STRIPS := 24
const FOCAL := 520.0
## Радиан поворота на пиксель движения мыши; затухание разгона за секунду.
const DRAG_SPEED := 0.012
const FRICTION := 3.0
## Слабее этого (рад/с) карта перестаёт крутиться сама и встаёт ровно.
const SETTLE_SPEED := 1.2
const SETTLE_EASE := 8.0

var angle := 0.0
var _speed := 0.0
var _dragging := false
var _back_layer: Control
var _face_layer: Control
var _back: Texture2D
var _face: Texture2D


func _init() -> void:
	custom_minimum_size = CardView.PIXEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	_back_layer = _layer()
	_face_layer = _layer()
	_back_layer.draw.connect(func(): _draw_side(_back_layer, _back, false))
	_face_layer.draw.connect(func(): _draw_side(_face_layer, _face, true))
	set_process(true)


func _layer() -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(layer)
	return layer


## Рубашка (CardBack) на обороте.
func set_back(design: String) -> void:
	_back = CardBack.texture(design)
	_back_layer.queue_redraw()


## Лицо: карта cid в образе tier ("" — обычная).
func set_face(cid: String, tier: String) -> void:
	_face = CardView.pixel_texture(cid)
	if tier == "":
		_face_layer.material = null
	else:
		var mat := _face_layer.material as ShaderMaterial
		if mat == null:
			mat = ShaderMaterial.new()
			_face_layer.material = mat
		CardView.configure_skin(mat, SkinCollection.SHADER_INDEX[tier], false)
	_face_layer.queue_redraw()


## Лицом к игроку сейчас рубашка.
func shows_back() -> bool:
	return cos(angle) >= 0.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var turn: float = event.relative.x * DRAG_SPEED
		angle += turn
		_speed = turn / maxf(get_process_delta_time(), 0.001)
		accept_event()


func _process(delta: float) -> void:
	if not _dragging:
		if absf(_speed) > SETTLE_SPEED:
			angle += _speed * delta
			_speed *= exp(-FRICTION * delta)
		else:
			# Докрутить до ближайшего «ровно»: рубашкой (0) или лицом (PI).
			_speed = 0.0
			var rest := roundf(angle / PI) * PI
			angle = lerpf(angle, rest, 1.0 - exp(-SETTLE_EASE * delta))
			if absf(angle - rest) < 0.001:
				angle = rest
	var back := shows_back()
	_back_layer.visible = back
	_face_layer.visible = not back
	(_back_layer if back else _face_layer).queue_redraw()


## Сторона полосками с перспективой. Лицо видно с обратной стороны, поэтому
## его картинка зеркалится — и читается нормально.
func _draw_side(layer: Control, tex: Texture2D, face: bool) -> void:
	if tex == null:
		return
	var w := CardView.PIXEL_SIZE.x
	var h := CardView.PIXEL_SIZE.y
	var centre := (size * 0.5).floor()
	var c := cos(angle)
	var s := sin(angle)
	for i in STRIPS:
		var x0 := -w * 0.5 + w * i / STRIPS
		var x1 := x0 + w / STRIPS
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for corner in 4:
			var x := x0 if corner == 0 or corner == 3 else x1
			var top := corner < 2
			var k := FOCAL / (FOCAL + x * s)
			var p := centre + Vector2(x * c * k, (-h * 0.5 if top else h * 0.5) * k)
			if absf(s) < 0.0005:
				p = p.round()
			pts.append(p)
			var u := (x + w * 0.5) / w
			uvs.append(Vector2(1.0 - u if face else u, 0.0 if top else 1.0))
		layer.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)
