class_name CounterLabel
extends Label

## Число, которое не подменяется мгновенно: оно накручивается до нового
## значения и коротко вспыхивает белым.
##
## Зачем: подменённая цифра не читается как событие. Игрок сыграл карту, число
## стало другим — и непонятно, выросло оно или упало. Накрутка показывает
## направление, вспышка говорит «вот здесь изменилось».
##
## Накрутка идёт тем дольше, чем больше разница, но не дольше ROLL_MAX: на
## разнице в единицу она почти мгновенная, и остаётся одна вспышка.
##
## Масштаб при вспышке не трогаем: пиксельный шрифт на дробном масштабе
## мылится. Пульсирует только цвет.

const ROLL_PER_UNIT := 0.06   # секунд на каждую единицу разницы
const ROLL_MAX := 0.3
const FLASH_TIME := 0.32

var _format := "%d"
var _base := PixelTheme.TEXT
var _shown := 0     # что написано сейчас
var _target := 0    # куда накручиваем
var _from := 0
var _roll_left := 0.0
var _roll_time := 0.0
var _flash_left := 0.0


## format — шаблон с одним %d, например "P %d".
static func make(format: String, colour: Color) -> CounterLabel:
	var node := CounterLabel.new()
	node._format = format
	node._base = colour
	node.add_theme_color_override("font_color", colour)
	node.text = format % 0
	node.set_process(false)
	return node


## Новое значение. animate = false — поставить сразу, без накрутки и вспышки
## (например, когда цифры стали чужими: ход перешёл к другому игроку).
func set_value(value: int, animate: bool = true) -> void:
	if value == _target:
		return
	_target = value
	if not animate:
		_shown = value
		_roll_left = 0.0
		_flash_left = 0.0
		text = _format % value
		add_theme_color_override("font_color", _base)
		set_process(false)
		return
	_from = _shown
	_roll_time = minf(absi(value - _from) * ROLL_PER_UNIT, ROLL_MAX)
	_roll_left = _roll_time
	_flash_left = FLASH_TIME
	set_process(true)


## Текст, который будет написан, когда накрутка закончится. По нему считают
## ширину плашки — иначе она прыгала бы вслед за промежуточными цифрами.
func target_text() -> String:
	return _format % _target


func _process(delta: float) -> void:
	if _roll_left > 0.0:
		_roll_left = maxf(_roll_left - delta, 0.0)
		var k: float = 1.0 - (_roll_left / _roll_time) if _roll_time > 0.0 else 1.0
		_shown = int(roundf(lerpf(float(_from), float(_target), k)))
		text = _format % _shown
	elif _shown != _target:
		_shown = _target
		text = _format % _shown

	_flash_left = maxf(_flash_left - delta, 0.0)
	add_theme_color_override("font_color",
		_base.lerp(Color.WHITE, _flash_left / FLASH_TIME))

	if _roll_left <= 0.0 and _flash_left <= 0.0:
		set_process(false)


## Для проверок: число сейчас накручивается или вспыхивает.
func is_animating() -> bool:
	return _roll_left > 0.0 or _flash_left > 0.0
