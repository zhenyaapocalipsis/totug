class_name PixelTheme
extends RefCounted

## Единое оформление всего интерфейса в пиксель-арте: растровый шрифт
## assets/font/pixel5.fnt, палитра Подземья и рамки толщиной ровно в один
## пиксель без скруглений и теней-размывов.
##
## Экран рисуется в расчётном размере 640x360 и растягивается на окно целым
## числом раз (project.godot: stretch canvas_items + фильтр nearest), поэтому
## один пиксель здесь — это настоящий квадратный пиксель на экране. Отсюда
## правило: все размеры и отступы — целые числа, скруглений нет, размер
## шрифта только 9 (1x) или 18 (2x).

const FONT_PATH := "res://assets/font/pixel5.fnt"

## Размер шрифта: 9 — пиксель в пиксель, 18 — тот же шрифт ровно вдвое.
const SIZE := 9
const SIZE_BIG := 18
## Высота строки шрифта при SIZE (см. common lineHeight в pixel5.fnt).
const LINE_H := 11

# Палитра — та же, что у пиксельных лиц карт (tools/pixel_cards.gd).
const BG := Color("0a0612")           # фон экрана
const PANEL := Color("140e26")        # фон панели
const PANEL_HI := Color("1d1436")     # фон панели посветлее (шапки, кнопки)
const PANEL_LO := Color("0d0820")     # утопленные места (списки, поля ввода)
const BORDER := Color("3b2a63")       # обычная рамка
const BORDER_HI := Color("6a5ad0")    # рамка активного элемента
const TEXT := Color("f0e6d2")         # основной текст
const TEXT_DIM := Color("a89cc0")     # подписи и второстепенное
const TEXT_OFF := Color("6b5f85")     # недоступное
const GOLD := Color("f2d23c")         # подсветка выбора, цена, VP
const DANGER := Color("d0283e")

static var _theme: Theme = null


## Общая тема интерфейса. Строится один раз и переиспользуется всеми экранами.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var font := load(FONT_PATH)
	if font != null:
		t.default_font = font
	t.default_font_size = SIZE

	_setup_panels(t)
	_setup_buttons(t)
	_setup_labels(t)
	_setup_scroll(t)
	_setup_misc(t)
	_theme = t
	return t


## Рамка в один пиксель без скруглений: единственный вид рамки в игре.
static func box(bg: Color, border_color: Color = BORDER, border_width: int = 1,
		pad_x: int = 3, pad_y: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border_color
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


## Заливка без рамки (шапки зон, полосы выделения).
static func fill(bg: Color, pad_x: int = 2, pad_y: int = 1) -> StyleBoxFlat:
	var s := box(bg, bg, 0, pad_x, pad_y)
	return s


static func _setup_panels(t: Theme) -> void:
	t.set_type_variation("Zone", "PanelContainer")
	for type in ["Panel", "PanelContainer"]:
		t.set_stylebox("panel", type, box(PANEL))
	t.set_stylebox("panel", "Zone", box(PANEL))


static func _setup_buttons(t: Theme) -> void:
	var normal := box(PANEL_HI, BORDER, 1, 4, 2)
	var hover := box(BORDER, BORDER_HI, 1, 4, 2)
	var pressed := box(BORDER_HI, GOLD, 1, 4, 2)
	# Нажатая кнопка вдавливается: надпись съезжает на пиксель вниз. Мелочь,
	# но без неё нажатие ощущается как подсветка, а не как нажатие.
	pressed.content_margin_top += 1
	pressed.content_margin_bottom = maxf(pressed.content_margin_bottom - 1.0, 0.0)
	var disabled := box(PANEL, TEXT_OFF, 1, 4, 2)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", BG)
	t.set_color("font_disabled_color", "Button", TEXT_OFF)
	t.set_font_size("font_size", "Button", SIZE)


static func _setup_labels(t: Theme) -> void:
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", SIZE)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", SIZE)
	t.set_font_size("bold_font_size", "RichTextLabel", SIZE)
	t.set_font_size("italics_font_size", "RichTextLabel", SIZE)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_constant("line_separation", "RichTextLabel", 1)
	t.set_constant("line_spacing", "Label", 1)


## Полосы прокрутки — узкие бруски без скруглений, 4 пикселя.
static func _setup_scroll(t: Theme) -> void:
	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, fill(PANEL_LO, 0, 0))
		t.set_stylebox("scroll_focus", type, fill(PANEL_LO, 0, 0))
		t.set_stylebox("grabber", type, fill(BORDER, 0, 0))
		t.set_stylebox("grabber_highlight", type, fill(BORDER_HI, 0, 0))
		t.set_stylebox("grabber_pressed", type, fill(BORDER_HI, 0, 0))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("focus", "ScrollContainer", StyleBoxEmpty.new())


static func _setup_misc(t: Theme) -> void:
	t.set_stylebox("normal", "LineEdit", box(PANEL_LO, BORDER, 1, 2, 1))
	t.set_stylebox("focus", "LineEdit", box(PANEL_LO, BORDER_HI, 1, 2, 1))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_OFF)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_font_size("font_size", "LineEdit", SIZE)

	t.set_stylebox("panel", "TabContainer", box(PANEL, BORDER, 1, 2, 2))
	t.set_stylebox("tab_selected", "TabContainer", box(PANEL_HI, BORDER_HI, 1, 4, 1))
	t.set_stylebox("tab_unselected", "TabContainer", box(PANEL_LO, BORDER, 1, 4, 1))
	t.set_stylebox("tab_hovered", "TabContainer", box(BORDER, BORDER_HI, 1, 4, 1))
	t.set_color("font_selected_color", "TabContainer", GOLD)
	t.set_color("font_unselected_color", "TabContainer", TEXT_DIM)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_font_size("font_size", "TabContainer", SIZE)

	t.set_stylebox("panel", "PopupMenu", box(PANEL, BORDER_HI, 1, 2, 2))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_font_size("font_size", "PopupMenu", SIZE)

	t.set_constant("separation", "HBoxContainer", 2)
	t.set_constant("separation", "VBoxContainer", 2)
