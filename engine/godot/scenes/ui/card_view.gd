class_name CardView
extends PanelContainer

## Одна карта в интерфейсе: цветная шапка аспекта с именем и ценой, строка
## аспект/тип, текст способности и два значения VP. Данные берёт из
## CardLibrary по card_id — своей копии сведений о картах у интерфейса нет.
##
## Размер карты задаёт вызывающий, шрифты масштабируются под ширину: в руке
## карта крупная, в маркете и на полосах сыгранных карт — маленькая. Мелкую
## карту читают через увеличенную копию под курсором с зажатым Alt (CardPreview).
##
## Кликабельность включается отдельно (set_clickable): в руке кликать можно
## только в свой ход, в маркете — только если хватает Influence. Некликабельная
## карта рисуется приглушённой, чтобы было видно, что она сейчас недоступна.

signal pressed(card_id: String)

const ASPECT_COLORS := {
	"CONQUEST": Color(0.72, 0.24, 0.22),
	"AMBITION": Color(0.78, 0.58, 0.18),
	"MALICE": Color(0.45, 0.22, 0.55),
	"GUILE": Color(0.20, 0.50, 0.40),
	"OBEDIENCE": Color(0.30, 0.38, 0.62),
}
const NO_ASPECT_COLOR := Color(0.35, 0.35, 0.38)
const COST_COLOR := Color(1.0, 0.86, 0.45)
## Ширина, под которую подобраны базовые размеры шрифтов.
const BASE_WIDTH := 150.0

## Пиксельные лицевые стороны карт (tools/pixel_cards.gd), 1x = PIXEL_SIZE.
## Карта во весь рост читается при целом масштабе: в руке 1x, в увеличенной
## копии 2x. Слоты шире карты (маркет, полосы) показывают верх карты — имя,
## цену, аспект и арт; целиком её читают через увеличенную копию.
const PIXEL_DIR := "res://assets/cards_pixel/"
const PIXEL_SIZE := Vector2(176, 254)
## Мелкое лицо той же карты: имя, арт, цена и VP без текста способности.
## Экран рисуется в 640x360, и в руке с маркетом помещается только оно;
## полную карту показывает увеличенная копия под курсором (CardPreview).
const MINI_DIR := "res://assets/cards_mini/"
const MINI_SIZE := Vector2(80, 91)
## Слот уже этого — берём мелкое лицо: крупное в нём было бы нечитаемой кашей.
const MINI_MAX_WIDTH := 110.0
const PIXEL_HIGHLIGHT := Color("f2d23c")
const PIXEL_TOP_H := 136.0  # шапка + арт
const MINI_TOP_H := 73.0    # шапка + арт у мелкого лица

var card_id: String = ""
var clickable: bool = false
## Показывать ли увеличенную копию при наведении (у самой копии — нет).
var hover_preview: bool = true
var _pixel: Texture2D = null
## Мелкое лицо (true) или полное (false) — зависит от ширины слота.
var _mini := false

var _name_label: Label
var _cost_label: Label
var _meta_label: Label
var _text_label: Label
var _vp_label: Label
var _style: StyleBoxFlat
var _header_style: StyleBoxFlat
var _aspect_color := NO_ASPECT_COLOR


## max_text_lines: 0 — сколько влезет по высоте, N — не больше N строк,
## -1 — текст способности не показывать вовсе (карты на узких полосах).
func _init(cid: String = "", card_width: int = 150, card_height: int = 210,
		max_text_lines: int = 0) -> void:
	card_id = cid
	custom_minimum_size = Vector2(card_width, card_height)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_mini = card_width <= MINI_MAX_WIDTH
	_pixel = mini_texture(cid) if _mini else pixel_texture(cid)
	if _pixel != null:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		return

	var k := clampf(card_width / BASE_WIDTH, 0.62, 1.3)

	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.12, 0.115, 0.15)
	_style.border_color = NO_ASPECT_COLOR
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(7)
	_style.set_content_margin_all(2)
	_style.shadow_color = Color(0, 0, 0, 0.45)
	_style.shadow_size = 3
	add_theme_stylebox_override("panel", _style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	var header := PanelContainer.new()
	_header_style = StyleBoxFlat.new()
	_header_style.corner_radius_top_left = 5
	_header_style.corner_radius_top_right = 5
	_header_style.content_margin_left = 5 * k
	_header_style.content_margin_right = 5 * k
	_header_style.content_margin_top = 2 * k
	_header_style.content_margin_bottom = 2 * k
	header.add_theme_stylebox_override("panel", _header_style)
	col.add_child(header)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	header.add_child(header_row)

	_name_label = Label.new()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", roundi(13 * k))
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.max_lines_visible = 2
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_row.add_child(_name_label)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", roundi(15 * k))
	_cost_label.add_theme_color_override("font_color", COST_COLOR)
	_cost_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header_row.add_child(_cost_label)

	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", roundi(2 * k))
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, roundi(5 * k))
	margin.add_theme_constant_override("margin_top", roundi(2 * k))
	margin.add_theme_constant_override("margin_bottom", roundi(3 * k))
	margin.add_child(body)
	col.add_child(margin)

	_meta_label = Label.new()
	_meta_label.add_theme_font_size_override("font_size", roundi(10 * k))
	_meta_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
	_meta_label.clip_text = true
	body.add_child(_meta_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", roundi(11 * k))
	_text_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Текст не распирает карту: что не влезло — обрезается многоточием.
	_text_label.clip_text = true
	_text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if max_text_lines > 0:
		_text_label.max_lines_visible = max_text_lines
	_text_label.visible = max_text_lines >= 0
	body.add_child(_text_label)

	_vp_label = Label.new()
	_vp_label.add_theme_font_size_override("font_size", roundi(10 * k))
	_vp_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	_vp_label.visible = card_height >= 100
	body.add_child(_vp_label)

	# Внутренние узлы мышь не ловят: наведение и щелчок принадлежат карте
	# целиком, иначе mouse_exited срабатывает при переходе на надпись.
	_ignore_mouse(col)

	if card_id != "":
		set_card(card_id)


static func pixel_texture(cid: String) -> Texture2D:
	var path := PIXEL_DIR + cid + ".png"
	return load(path) as Texture2D if cid != "" and ResourceLoader.exists(path) else null


static func mini_texture(cid: String) -> Texture2D:
	var path := MINI_DIR + cid + ".png"
	return load(path) as Texture2D if cid != "" and ResourceLoader.exists(path) else null


## Размер лица карты в его собственных пикселях — мелкого или полного.
func face_size() -> Vector2:
	return MINI_SIZE if _mini else PIXEL_SIZE


## Часть пиксельной карты, которая влезает в слот: слот уже карты — карта
## целиком по центру; слот шире — верх карты, но не ниже арта (пустое
## текстовое поле в мелком слоте ни к чему), вписанный по центру.
##
## Масштаб округляется вниз до целого, как только карта в слот помещается:
## при 1.01x или 0.91x пиксели карты разъезжаются и шрифт мылится, а лишние
## два-три пикселя слота лучше оставить пустыми.
func _pixel_rects() -> Array[Rect2]:
	var face := face_size()
	var slot_aspect := size.x / maxf(size.y, 1.0)
	var card_aspect := face.x / face.y
	var region := Rect2(Vector2.ZERO, face)
	# Допуск в пару процентов: слот, который шире карты лишь на округление
	# размера, должен показывать карту целиком, а не её верх.
	if slot_aspect > card_aspect * 1.03:
		region.size.y = floorf(minf(face.x / slot_aspect, MINI_TOP_H if _mini else PIXEL_TOP_H))
	var k := minf(size.x / region.size.x, size.y / region.size.y)
	if k >= 1.0:
		k = floorf(k)
	var dest_size := (region.size * k).floor()
	return [Rect2(((size - dest_size) * 0.5).floor(), dest_size), region]


func _draw() -> void:
	if _pixel == null:
		return
	var rects := _pixel_rects()
	var dest: Rect2 = rects[0]
	# Не меньше 1 экранного пикселя на пиксель карты — чёткие пиксели (nearest);
	# меньше — nearest выкидывает целые строки шрифта, поэтому сглаживание.
	var on_screen := dest.size.x / face_size().x * get_screen_transform().get_scale().x
	var filter := TEXTURE_FILTER_NEAREST if on_screen >= 0.99 else TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if texture_filter != filter:
		texture_filter = filter
	draw_texture_rect_region(_pixel, dest, rects[1])
	if clickable:
		draw_rect(dest.grow(1), PIXEL_HIGHLIGHT, false, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_ENTER_TREE and _pixel != null:
		# масштаб окна меняется — фильтр пересчитывается в _draw()
		if not get_viewport().size_changed.is_connected(queue_redraw):
			get_viewport().size_changed.connect(queue_redraw)
		queue_redraw()


static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


func set_card(cid: String) -> void:
	card_id = cid
	if _pixel != null:
		_pixel = mini_texture(cid) if _mini else pixel_texture(cid)
		queue_redraw()
		return
	var data: Dictionary = CardLibrary.card_data(cid)
	if data.is_empty():
		_name_label.text = "?" + cid
		_cost_label.text = ""
		_meta_label.text = "no card data"
		_text_label.text = ""
		_vp_label.text = ""
		_apply_colors()
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

	_aspect_color = ASPECT_COLORS.get(aspect, NO_ASPECT_COLOR)
	_text_label.text = String(data.get("ability_text", "") if data.get("ability_text") != null else "")

	var deck_vp = data.get("deck_vp")
	var ic_vp = data.get("inner_circle_vp")
	var parts: Array[String] = []
	if deck_vp != null:
		parts.append("deck %d" % int(deck_vp))
	if ic_vp != null:
		parts.append("inner circle %d" % int(ic_vp))
	_vp_label.text = "VP: " + ", ".join(parts) if not parts.is_empty() else ""
	_apply_colors()


## Доступная карта — яркая, с толстой рамкой и свечением в цвет аспекта;
## недоступная — приглушённая (dim = false — карта просто лежит на столе и
## должна читаться, например сыгранные карты).
func set_clickable(value: bool, dim: bool = true) -> void:
	clickable = value
	modulate = Color(1, 1, 1) if value or not dim else Color(0.58, 0.58, 0.63)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
	_apply_colors()


func _apply_colors() -> void:
	if _pixel != null:
		queue_redraw()
		return
	_style.border_color = _aspect_color.lightened(0.15) if clickable else _aspect_color
	_style.set_border_width_all(3 if clickable else 2)
	_style.shadow_color = Color(_aspect_color.lightened(0.3), 0.55) if clickable else Color(0, 0, 0, 0.45)
	_style.shadow_size = 6 if clickable else 3
	_header_style.bg_color = _aspect_color.darkened(0.35)


func _on_mouse_entered() -> void:
	if hover_preview:
		CardPreview.set_hovered(self)


func _on_mouse_exited() -> void:
	CardPreview.clear_hovered(self)


func _gui_input(event: InputEvent) -> void:
	if not clickable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(card_id)
		accept_event()
