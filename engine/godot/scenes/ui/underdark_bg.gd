extends RefCounted

## Задник экрана: живые разводы Подземья (underdark_bg.gdshader).
##
## Один и тот же задник стоит и в меню, и в партии — разница только в силе:
## в меню он показан во всю мощь, за игровым экраном приглушён почти до
## обычной заливки, чтобы пиксельные карты и доска читались как раньше.
##
## Экраны не знают про шейдер: они просят UnderdarkBg.make() и кладут
## полученный ColorRect первым ребёнком, ровно на место прежней заливки.

const SHADER_PATH := "res://scenes/ui/underdark_bg.gdshader"

## Насколько погашен фон за игровым экраном (0 — как в меню, 1 — заливка).
const GAME_FADE := 0.72

static var _shader: Shader = null


## Задник на весь экран. fade: 0 — меню, GAME_FADE — экран партии.
static func make(fade: float = 0.0) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = PixelTheme.BG
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := _load_shader()
	if shader == null:
		return rect
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("fade", fade)
	mat.set_shader_parameter("fade_to", PixelTheme.BG)
	rect.material = mat
	return rect


## Шейдер грузится один раз на всю программу. В headless (тесты) рендера нет
## вовсе — там экран остаётся с обычной заливкой.
static func _load_shader() -> Shader:
	if _shader != null:
		return _shader
	if DisplayServer.get_name() == "headless":
		return null
	_shader = load(SHADER_PATH) as Shader
	return _shader
