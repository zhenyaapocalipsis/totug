extends RefCounted

## Задник экрана: живые разводы Подземья (underdark_bg.gdshader).
##
## Один и тот же задник стоит и в меню, и в партии — разницы две:
## в меню он показан во всю мощь, за игровым экраном приглушён почти до
## обычной заливки; и краска в партии берёт цвета тех двух полуколод, что
## собраны в маркет этой партии.
##
## Экраны не знают про шейдер: они просят UnderdarkBg.make() и кладут
## полученный ColorRect первым ребёнком, ровно на место прежней заливки.

const SHADER_PATH := "res://scenes/ui/underdark_bg.gdshader"

## Насколько погашен фон за игровым экраном (0 — как в меню, 1 — заливка).
const GAME_FADE := 0.72

## Цвет каждой полуколоды. Ключи — те же, что в data/cards/half_decks.json.
## Цвета подобраны так, чтобы любые две краски рядом не сливались в одно
## пятно: тёплые (драконы, демоны) против холодных (элементали, нежить) и
## двух ядовитых (дроу, аберрации).
const DECK_COLOURS := {
	"drow": Color(0.420, 0.100, 0.660),        # паучий пурпур дроу
	"dragons": Color(0.720, 0.380, 0.050),     # раскалённое золото чешуи
	"demons": Color(0.600, 0.080, 0.140),      # багрянец Бездны
	"elementals": Color(0.050, 0.460, 0.550),  # бирюза подземных вод
	"aberrations": Color(0.260, 0.560, 0.160), # ядовитая зелень иллитидов
	"undead": Color(0.200, 0.320, 0.680),      # призрачный синий
}

## Чем красить, если полуколоды неизвестны (меню, тесты, старые сохранения).
const DEFAULT_COLOURS: Array[Color] = [Color(0.400, 0.110, 0.700), Color(0.040, 0.450, 0.500)]

static var _shader: Shader = null


## Две краски фона по списку полуколод партии. Незнакомые ключи и нехватка
## полуколод добиваются цветами по умолчанию, чтобы фон никогда не остался
## одноцветным.
static func palette(half_decks: Array = []) -> Array[Color]:
	var colours: Array[Color] = []
	for key: Variant in half_decks:
		var colour: Variant = DECK_COLOURS.get(String(key))
		if colour != null and not colours.has(colour):
			colours.append(colour)
		if colours.size() == 2:
			break
	for fallback: Color in DEFAULT_COLOURS:
		if colours.size() == 2:
			break
		if not colours.has(fallback):
			colours.append(fallback)
	return colours


## Задник на весь экран. fade: 0 — меню, GAME_FADE — экран партии.
## half_decks — полуколоды партии (board_snapshot), по ним берётся краска.
static func make(fade: float = 0.0, half_decks: Array = []) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = PixelTheme.BG
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := _load_shader()
	if shader == null:
		return rect
	var colours := palette(half_decks)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("fade", fade)
	mat.set_shader_parameter("fade_to", PixelTheme.BG)
	mat.set_shader_parameter("colour_1", _water(colours))
	mat.set_shader_parameter("colour_2", colours[0])
	mat.set_shader_parameter("colour_3", colours[1])
	rect.material = mat
	return rect


## Тёмная вода под краской: фон темы, чуть подкрашенный самими красками —
## иначе на стыке чёрного и яркого мазка видна грязная кайма.
static func _water(colours: Array[Color]) -> Color:
	var tint := (colours[0] + colours[1]) * 0.5
	return PixelTheme.BG.lerp(tint, 0.14)


## Шейдер грузится один раз на всю программу. В headless (тесты) рендера нет
## вовсе — там экран остаётся с обычной заливкой.
static func _load_shader() -> Shader:
	if _shader != null:
		return _shader
	if DisplayServer.get_name() == "headless":
		return null
	_shader = load(SHADER_PATH) as Shader
	return _shader
