class_name TurnFeed
extends PanelContainer

## Сводка ходов — постоянная колонка у левого края экрана (решение
## владельца, 2026-09-26: «бесконечная сводка слева»). Копит с начала партии
## всё, что игроки сыграли, промоутили, купили и съели, маленькими картами —
## журнал никто не читает, а картинки видно.
##
## Каждый ход — отдельный блок в почти прозрачной рамке цвета игрока, сверху
## имя («RED'S TURN»). Внутри блока карты разложены по группам всегда в одном
## порядке — PLAYED, PROMOTED, BOUGHT, DEVOURED (решение владельца: группы не
## перемешивать), — и каждая группа лежит лесенкой (Ladder) с подписью.
##
## Новая карта встаёт со вспышкой, и колонка сама листается вниз — если игрок
## не отлистал колёсиком назад, читая историю. Полосы прокрутки нет: она
## съела бы ширину, а колесо работает и без неё.
##
## Карты — обычные CardView: по наведению полная карта по центру экрана,
## с Alt — крупнее (CardPreview).

const CARD := Vector2(80, 76)
## Поле колонки и поле блока внутри рамки (рамка — 1 пиксель из него).
const PAD := 1
const BLOCK_PAD := 2
## Ширина колонки: карта, поля блока и колонки. GameScreen отдаёт её слева
## от доски.
const WIDTH := CARD.x + (BLOCK_PAD + PAD) * 2
## Порядок групп внутри хода.
const ORDER: Array[String] = ["PLAYED", "PROMOTED", "BOUGHT", "DEVOURED"]
## Больше ходов не держим — самые старые уходят (сотни узлов ни к чему).
const MAX_BLOCKS := 60
## Насколько близко к низу надо быть, чтобы колонка продолжала листаться
## за новыми картами.
const FOLLOW_SLACK := 8
## Рамка и подложка блока: цвет игрока, почти прозрачный.
const FRAME_ALPHA := 0.35
const FILL_ALPHA := 0.06

var _scroll: ScrollContainer
var _list: VBoxContainer
var _placeholder: Label
var _blocks: Array[Block] = []
var _turn_closed := true
## Сколько кадров ещё дотягивать прокрутку до низа: размер списка после
## добавления карты станет известен только на следующем кадре.
var _pin_frames := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Без подложки и рамки у самой колонки: рамки — у блоков ходов.
	var style := StyleBoxEmpty.new()
	style.content_margin_left = PAD
	style.content_margin_right = PAD
	style.content_margin_top = PAD
	style.content_margin_bottom = PAD
	add_theme_stylebox_override("panel", style)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_list)
	_placeholder = Label.new()
	_placeholder.text = "MOVES"
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder.add_theme_color_override("font_color", PixelTheme.TEXT_OFF)
	_list.add_child(_placeholder)
	set_process(false)


## pid взял карту cid; tag — группа: PLAYED / PROMOTED / BOUGHT / DEVOURED.
func add(pid: String, cid: String, tag: String) -> void:
	if _placeholder != null:
		_placeholder.queue_free()
		_placeholder = null
	var follow := _at_bottom()
	var block: Block = _blocks.back() if not _blocks.is_empty() else null
	if block == null or block.pid != pid or _turn_closed:
		block = _open_block(pid)
	block.add_card(tag, _card(cid))
	_trim()
	if follow:
		_pin_frames = 2
		set_process(true)


## pid сыграл карту cid.
func add_played(pid: String, cid: String) -> void:
	add(pid, cid, "PLAYED")


## Ход закончился: следующая карта, даже того же игрока, начнёт новый блок.
func end_turn() -> void:
	_turn_closed = true


## Для проверок: сколько карт в сводке.
func card_count() -> int:
	var n := 0
	for block in _blocks:
		n += block.card_count()
	return n


## Для проверок: сколько групп во всех ходах.
func group_count() -> int:
	var n := 0
	for block in _blocks:
		n += block.groups.size()
	return n


## Для проверок: группы последнего хода сверху вниз.
func last_block_tags() -> Array[String]:
	if _blocks.is_empty():
		return []
	return _blocks.back().tags()


func _open_block(pid: String) -> Block:
	var colour: Color = BoardPanel.PLAYER_COLORS.get(pid, PixelTheme.TEXT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(colour, FILL_ALPHA)
	style.border_color = Color(colour, FRAME_ALPHA)
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.content_margin_left = BLOCK_PAD
	style.content_margin_right = BLOCK_PAD
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	var block := Block.new(pid, ORDER)
	block.add_theme_stylebox_override("panel", style)
	block.title.add_theme_color_override("font_color", colour.lightened(0.3))
	_list.add_child(block)
	_fit_header(block.title, pid)
	_blocks.append(block)
	_turn_closed = false
	return block


## Длинное имя из профиля не влезает в блок вместе с "'S TURN" — тогда
## пишем одно имя: цвет и так говорит, чей ход (как на кнопке End turn).
## Мерить можно только в дереве: шрифт приходит из темы экрана.
func _fit_header(title: Label, pid: String) -> void:
	var who := EventLogPanel.player_name(pid).to_upper()
	var text := "%s'S TURN" % who
	var font := title.get_theme_font("font")
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			title.get_theme_font_size("font_size")).x > CARD.x:
		text = who
	title.text = text


func _at_bottom() -> bool:
	var bar := _scroll.get_v_scroll_bar()
	return _scroll.scroll_vertical >= int(bar.max_value - bar.page) - FOLLOW_SLACK


func _process(_delta: float) -> void:
	var bar := _scroll.get_v_scroll_bar()
	_scroll.scroll_vertical = int(bar.max_value)
	_pin_frames -= 1
	if _pin_frames <= 0:
		set_process(false)


## Слишком длинная история — убираем самые старые ходы.
func _trim() -> void:
	while _blocks.size() > MAX_BLOCKS:
		var old: Block = _blocks.pop_front()
		_list.remove_child(old)
		old.queue_free()


func _card(cid: String) -> CardView:
	var card := CardView.new(cid, int(CARD.x), int(CARD.y))
	card.set_clickable(false, false)
	# PASS, а не STOP: колесо над картой должно листать колонку.
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	# Новая карта встаёт со вспышкой — глаз замечает, что сводка пополнилась.
	card.flash_arrival()
	return card


## Один ход в сводке: заголовок и группы карт в порядке order.
class Block extends PanelContainer:
	var pid := ""
	var title: Label
	## tag -> Ladder
	var groups: Dictionary = {}
	var _order: Array[String] = []
	var _col: VBoxContainer

	func _init(player_id: String, order: Array[String]) -> void:
		pid = player_id
		_order = order
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_col = VBoxContainer.new()
		_col.add_theme_constant_override("separation", 1)
		_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_col)
		title = Label.new()
		title.clip_text = true
		_col.add_child(title)

	func add_card(tag: String, card: CardView) -> void:
		if not groups.has(tag):
			_add_group(tag)
		(groups[tag] as Ladder).add_card(card)

	func card_count() -> int:
		var n := 0
		for tag: String in groups:
			n += (groups[tag] as Ladder).get_child_count()
		return n

	## Группы сверху вниз.
	func tags() -> Array[String]:
		var result: Array[String] = []
		for tag in _order:
			if groups.has(tag):
				result.append(tag)
		return result

	## Новая группа встаёт на своё место по порядку: после заголовка и всех
	## групп, которые в порядке идут раньше неё.
	func _add_group(tag: String) -> void:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ladder := Ladder.new()
		cell.add_child(ladder)
		var label := Label.new()
		label.text = tag
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color",
			PixelTheme.DANGER if tag == "DEVOURED" else PixelTheme.TEXT_DIM)
		cell.add_child(label)
		var before := 0
		for other in _order:
			if other == tag:
				break
			if groups.has(other):
				before += 1
		_col.add_child(cell)
		_col.move_child(cell, 1 + before)
		groups[tag] = ladder


## Карты одной группы — лесенкой сверху вниз, как стопка на столе: каждая
## следующая лежит ниже предыдущей и поверх неё, у предыдущих видна шапка с
## названием, последняя — целиком. Наведение на шапку показывает крупно
## именно ту карту: следующая её шапку не закрывает.
class Ladder extends Control:
	## Сколько видно от каждой карты под следующей: две строки названия.
	const STEP := 20
	const SIZE := Vector2(80, 76)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func add_card(card: CardView) -> void:
		card.position = Vector2(0, STEP * get_child_count())
		add_child(card)
		card.size = SIZE
		custom_minimum_size = Vector2(SIZE.x, STEP * (get_child_count() - 1) + SIZE.y)
