class_name FloatingText
extends Label

## Всплывающая надпись вроде «+2» или «−1»: появляется в точке, поднимается на
## десяток пикселей, гаснет и удаляет себя.
##
## Зачем: число в плашке ресурсов просто меняется, и глаз этого не ловит —
## особенно когда карта даёт сразу и Power, и Influence. Всплывшая цифра
## говорит, что именно изменилось и на сколько.
##
## Поднимается быстро в начале и медленно в конце, гаснет в последнюю треть
## жизни. Положение округляется до целого пикселя: на дробном пиксельный
## шрифт мылится.

const RISE := 18.0    # на сколько поднимается за свою жизнь
const LIFE := 0.7    # сколько живёт, секунд
const FADE := 0.35    # доля жизни в конце, за которую гаснет

var _left := LIFE
var _from := Vector2.ZERO


## Пускает надпись над точкой at (в координатах parent) и возвращает её.
static func spawn(parent: Control, text_value: String, colour: Color,
		at: Vector2) -> FloatingText:
	var node := FloatingText.new()
	node.text = text_value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_color_override("font_color", colour)
	# Обводка под цвет фона: цифра читается поверх любой панели и доски.
	node.add_theme_color_override("font_outline_color", PixelTheme.BG)
	node.add_theme_constant_override("outline_size", 2)
	node._from = at
	node.position = at.round()
	node.z_index = 4
	parent.add_child(node)
	return node


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	var t := 1.0 - _left / LIFE            # 0 в начале, 1 в конце
	var lifted := 1.0 - (1.0 - t) * (1.0 - t)   # быстро вверх, потом замедление
	position = (_from - Vector2(0.0, RISE * lifted)).round()
	modulate.a = clampf(_left / (LIFE * FADE), 0.0, 1.0)
