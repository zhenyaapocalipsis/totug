class_name FlyingToken
extends Control

## Фишка войска или шпиона в полёте из барака на доску (см.
## GameScreen._launch_token). Рисуется вокруг своей позиции — position и есть
## центр фишки, поэтому полёту достаточно звать move_to.
##
## Выглядит так же, как на доске: войско — та же картинка жетона в том же
## масштабе (на схеме) или цветной кружок (вид гексов), шпион — ромбик.
##
## Для веса: фишку можно увеличить в целое число раз («поднялась к камере»),
## а за ней тянется шлейф из нескольких гаснущих копий.

## Сколько копий в шлейфе и насколько прозрачна самая яркая.
const TRAIL := 3
const TRAIL_ALPHA := 0.45

var texture: Texture2D = null
var texture_zoom := 1.0
var colour := Color.WHITE
var spy := false
## Шпион — полуразмер ромбика, войско без картинки — радиус кружка.
var half := 4.0
## Во сколько раз фишка больше, чем на доске. Только целые: пиксели не плывут.
var magnify := 1
## Прошлые позиции (координаты родителя), новые — в конце.
var _trail: Array[Vector2] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Переставить фишку на целый пиксель p; старое место уходит в шлейф.
func move_to(p: Vector2) -> void:
	p = p.round()
	if p == position:
		return
	_trail.append(position)
	if _trail.size() > TRAIL:
		_trail.pop_front()
	position = p
	queue_redraw()


func set_magnify(k: int) -> void:
	if magnify != k:
		magnify = k
		queue_redraw()


func _draw() -> void:
	for i in range(_trail.size()):
		var alpha := TRAIL_ALPHA * float(i + 1) / float(_trail.size() + 1)
		_draw_token(_trail[i] - position, alpha)
	_draw_token(Vector2.ZERO, 1.0)


func _draw_token(at: Vector2, alpha: float) -> void:
	var k := float(magnify)
	if spy:
		var d := half * k
		var diamond := PackedVector2Array([
			at + Vector2(0, -d), at + Vector2(d, 0), at + Vector2(0, d), at + Vector2(-d, 0)])
		draw_colored_polygon(diamond, Color(colour, alpha))
		if alpha >= 1.0:
			draw_polyline(diamond + PackedVector2Array([at + Vector2(0, -d)]), Color(0, 0, 0, 0.8), 1.5)
	elif texture != null:
		var s := texture.get_size() * texture_zoom * k
		draw_texture_rect(texture, Rect2(at - s * 0.5, s), false, Color(1, 1, 1, alpha))
	else:
		draw_circle(at, half * k, Color(0, 0, 0, 0.75 * alpha))
		draw_circle(at, half * 0.82 * k, Color(colour, alpha))
