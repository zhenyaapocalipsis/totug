class_name CardView
extends PanelContainer

## Одна карта в интерфейсе: имя, стоимость, аспект/тип, текст способности и
## два значения VP. Данные берёт из CardLibrary по card_id — своей копии
## сведений о картах у интерфейса нет.
##
## Кликабельность включается отдельно (set_clickable): в руке кликать можно
## только в свой ход, в маркете — только если хватает Influence, а во
## Внутреннем круге карты вообще не кликаются. Некликабельная карта рисуется
## приглушённой, чтобы было видно, что она сейчас недоступна.

signal pressed(card_id: String)

const ASPECT_COLORS := {
	"CONQUEST": Color(0.72, 0.24, 0.22),
	"AMBITION": Color(0.78, 0.58, 0.18),
	"MALICE": Color(0.45, 0.22, 0.55),
	"GUILE": Color(0.20, 0.50, 0.40),
	"OBEDIENCE": Color(0.30, 0.38, 0.62),
}
const NO_ASPECT_COLOR := Color(0.35, 0.35, 0.38)

var card_id: String = ""
var clickable: bool = false

var _name_label: Label
var _cost_label: Label
var _meta_label: Label
var _text_label: Label
var _vp_label: Label
var _style: StyleBoxFlat


## max_text_lines — сколько строк способности показывать. В руке места много и
## текст влезает целиком (0 = без ограничения), а в маркете шесть карт должны
## поместиться в узкую колонку, поэтому там текст обрезается многоточием.
## Обрезка нужна не для красоты: пока карточки не влезали, прокрутка резала их
## пополам, и по нижнему ряду нельзя было попасть мышью.
func _init(cid: String = "", card_width: int = 150, card_height: int = 210,
		max_text_lines: int = 0) -> void:
	card_id = cid
	custom_minimum_size = Vector2(card_width, card_height)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.14, 0.13, 0.18)
	_style.border_color = NO_ASPECT_COLOR
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(6)
	_style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", _style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)

	_name_label = Label.new()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_name_label)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 15)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_cost_label)

	_meta_label = Label.new()
	_meta_label.add_theme_font_size_override("font_size", 10)
	_meta_label.modulate = Color(0.75, 0.75, 0.8)
	col.add_child(_meta_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 11)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if max_text_lines > 0:
		_text_label.max_lines_visible = max_text_lines
		_text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_text_label)

	_vp_label = Label.new()
	_vp_label.add_theme_font_size_override("font_size", 10)
	_vp_label.modulate = Color(0.7, 0.7, 0.75)
	col.add_child(_vp_label)

	if card_id != "":
		set_card(card_id)


func set_card(cid: String) -> void:
	card_id = cid
	var data: Dictionary = CardLibrary.card_data(cid)
	if data.is_empty():
		_name_label.text = "?" + cid
		_cost_label.text = ""
		_meta_label.text = "no card data"
		_text_label.text = ""
		_vp_label.text = ""
		return

	_name_label.text = String(data.get("name", cid))

	# Стоимость null — у карты её нет вовсе (Noble, Soldier, Insane Outcast),
	# это не то же самое, что «стоит 0» (claude/progress.md, этап 4).
	var cost = data.get("cost")
	_cost_label.text = "" if cost == null else str(int(cost))

	var aspect := String(data.get("aspect", "") if data.get("aspect") != null else "")
	var type_name := String(data.get("type", "") if data.get("type") != null else "")
	# Insane Outcast — единственная карта вообще без аспекта (этап 4), поэтому
	# строку собираем из того, что есть, а не по жёсткому шаблону.
	if aspect != "" and type_name != "":
		_meta_label.text = "%s · %s" % [aspect, type_name]
	else:
		_meta_label.text = aspect + type_name

	_style.border_color = ASPECT_COLORS.get(aspect, NO_ASPECT_COLOR)
	_text_label.text = String(data.get("ability_text", "") if data.get("ability_text") != null else "")

	var deck_vp = data.get("deck_vp")
	var ic_vp = data.get("inner_circle_vp")
	var parts: Array[String] = []
	if deck_vp != null:
		parts.append("deck %d" % int(deck_vp))
	if ic_vp != null:
		parts.append("inner circle %d" % int(ic_vp))
	_vp_label.text = "VP: " + ", ".join(parts) if not parts.is_empty() else ""


## Доступная карта — яркая, с толстой рамкой и курсором-рукой; недоступная —
## приглушённая. Раньше разница была только в яркости и её не замечали.
func set_clickable(value: bool) -> void:
	clickable = value
	modulate = Color(1, 1, 1) if value else Color(0.55, 0.55, 0.6)
	_style.set_border_width_all(4 if value else 2)
	_style.bg_color = Color(0.19, 0.18, 0.24) if value else Color(0.14, 0.13, 0.18)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	if not clickable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(card_id)
		accept_event()
