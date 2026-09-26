class_name FlyingToken
extends Control

## Фишка войска или шпиона в полёте из барака на доску (см.
## GameScreen._launch_token). Рисуется вокруг своей позиции — position и есть
## центр фишки, поэтому полёту достаточно двигать position.
##
## Выглядит так же, как на доске: войско — та же картинка жетона в том же
## масштабе (на схеме) или цветной кружок (вид гексов), шпион — ромбик.

var texture: Texture2D = null
var texture_zoom := 1.0
var colour := Color.WHITE
var spy := false
## Шпион — полуразмер ромбика, войско без картинки — радиус кружка.
var half := 4.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	if spy:
		var d := half
		var diamond := PackedVector2Array([
			Vector2(0, -d), Vector2(d, 0), Vector2(0, d), Vector2(-d, 0)])
		draw_colored_polygon(diamond, colour)
		draw_polyline(diamond + PackedVector2Array([Vector2(0, -d)]), Color(0, 0, 0, 0.8), 1.5)
	elif texture != null:
		var s := texture.get_size() * texture_zoom
		draw_texture_rect(texture, Rect2(-s * 0.5, s), false)
	else:
		draw_circle(Vector2.ZERO, half, Color(0, 0, 0, 0.75))
		draw_circle(Vector2.ZERO, half * 0.82, colour)
