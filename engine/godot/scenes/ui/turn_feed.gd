class_name TurnFeed
extends PanelContainer

## Сводка ходов — постоянная колонка у левого края экрана (решение
## владельца, 2026-09-26: «бесконечная сводка слева»). Копит с начала партии
## всё, что игроки купили, промоутили и съели, маленькими картами с подписью
## BOUGHT / PROMOTED / DEVOURED — журнал никто не читает, а картинки видно.
##
## Сверху вниз — по порядку: каждый ход начинается подписью «RED'S TURN» в
## цвет игрока. Новая карта встаёт внизу со вспышкой, и колонка сама
## листается к ней — если игрок не отлистал колёсиком назад, читая историю.
## Полосы прокрутки нет: она съела бы ширину, а колесо работает и без неё.
##
## Карты — обычные CardView, но крупно их видно по одному наведению, без Alt
## (полная карта по центру экрана, как в CardPreview).

const CARD := Vector2(80, 76)
const PAD := 3
## Ширина колонки: карта и поля. GameScreen отдаёт её слева от доски.
const WIDTH := CARD.x + PAD * 2
## Больше карт не держим — самые старые уходят (сотни узлов ни к чему).
const MAX_CELLS := 200
## Насколько близко к низу надо быть, чтобы колонка продолжала листаться
## за новыми картами.
const FOLLOW_SLACK := 8

var _scroll: ScrollContainer
var _list: VBoxContainer
var _placeholder: Label
var _last_pid := ""
var _turn_closed := true
var _cells: Array[Control] = []
## Сколько кадров ещё дотягивать прокрутку до низа: размер списка после
## добавления карты станет известен только на следующем кадре.
var _pin_frames := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Без подложки и рамки (решение владельца): карты висят прямо над фоном.
	var style := StyleBoxEmpty.new()
	style.content_margin_left = PAD
	style.content_margin_right = PAD
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	add_theme_stylebox_override("panel", style)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_list)
	_placeholder = Label.new()
	_placeholder.text = "MOVES"
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder.add_theme_color_override("font_color", PixelTheme.TEXT_OFF)
	_list.add_child(_placeholder)
	set_process(false)


## pid взял карту cid (tag — BOUGHT / PROMOTED / DEVOURED).
func add(pid: String, cid: String, tag: String) -> void:
	if _placeholder != null:
		_placeholder.queue_free()
		_placeholder = null
	var follow := _at_bottom()
	if pid != _last_pid or _turn_closed:
		_list.add_child(_header(pid))
		_last_pid = pid
		_turn_closed = false
	var cell := _cell(cid, tag)
	_list.add_child(cell)
	_cells.append(cell)
	_trim()
	if follow:
		_pin_frames = 2
		set_process(true)


## Ход закончился: следующая карта, даже того же игрока, начнёт новый блок.
func end_turn() -> void:
	_turn_closed = true


## Для проверок: сколько карт в сводке.
func card_count() -> int:
	return _cells.size()


func _at_bottom() -> bool:
	var bar := _scroll.get_v_scroll_bar()
	return _scroll.scroll_vertical >= int(bar.max_value - bar.page) - FOLLOW_SLACK


func _process(_delta: float) -> void:
	var bar := _scroll.get_v_scroll_bar()
	_scroll.scroll_vertical = int(bar.max_value)
	_pin_frames -= 1
	if _pin_frames <= 0:
		set_process(false)


## Слишком длинная история — убираем самые старые карты и заголовки, над
## которыми не осталось карт.
func _trim() -> void:
	while _cells.size() > MAX_CELLS:
		var old: Control = _cells.pop_front()
		_list.remove_child(old)
		old.queue_free()
	while _list.get_child_count() > 1 and _list.get_child(0) is Label \
			and _list.get_child(1) is Label:
		var header := _list.get_child(0)
		_list.remove_child(header)
		header.queue_free()


func _header(pid: String) -> Label:
	var colour: Color = BoardPanel.PLAYER_COLORS.get(pid, PixelTheme.TEXT)
	var title := Label.new()
	title.text = "%s'S TURN" % EventLogPanel.player_name(pid).to_upper()
	title.clip_text = true
	title.add_theme_color_override("font_color", colour.lightened(0.3))
	return title


func _cell(cid: String, tag: String) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 0)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := CardView.new(cid, int(CARD.x), int(CARD.y))
	card.set_clickable(false, false)
	card.preview_without_alt = true
	# PASS, а не STOP: колесо над картой должно листать колонку.
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.add_child(card)
	# Новая карта встаёт со вспышкой — глаз замечает, что сводка пополнилась.
	card.flash_arrival()
	var label := Label.new()
	label.text = tag
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color",
		PixelTheme.DANGER if tag == "DEVOURED" else PixelTheme.TEXT_DIM)
	cell.add_child(label)
	return cell
