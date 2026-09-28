class_name TurnFeed
extends PanelContainer

## Сводка ходов — постоянная колонка у левого края экрана (решение
## владельца, 2026-09-26: «бесконечная сводка слева»). Копит с начала партии
## всё, что игроки сыграли, промоутили, купили и съели, маленькими картами —
## журнал никто не читает, а картинки видно.
##
## Каждый ход — отдельный блок в почти прозрачной рамке цвета игрока, сверху
## имя («RED'S TURN»). Внутри блока карты разложены по группам всегда в одном
## порядке — PLAYED, PROMOTED, BOUGHT, OUTCAST, DEVOURED, TO SUPPLY (изгой
## вернулся в запас вместо devour/promote), DISCARDED (решение владельца:
## группы не перемешивать), — и каждая группа лежит лесенкой (Ladder) с
## подписью. Под картами — строки действий хода из бывшего журнала (решение
## владельца, 2026-09-27: чат и журнал убраны): DEPLOY 3, KILL 2 с квадратиками
## цвета убитых, SPY 1, +2 VP и т. д. — счётчики за ход, всегда в одном порядке.
##
## Строка действия помнит, где на доске это было: наведение мыши подсвечивает
## строку и шлёт places_hovered — доска зажигает эти места (решение владельца,
## 2026-09-28: игроки не видели, где убили или вытеснили).
##
## Сброс чужой карты во время хода (force discard) ложится в блок ходящего
## отдельной группой DISCARDED с подписью цвета сбросившего.
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
const ORDER: Array[String] = [
	"PLAYED", "PROMOTED", "BOUGHT", "OUTCAST", "DEVOURED", "TO SUPPLY", "DISCARDED"]
## Строки действий хода: ключ -> подпись; порядок строк — порядок ключей.
const STATS := {
	"deploy": "DEPLOY", "move": "MOVE", "kill": "KILL", "supplant": "SUPPLANT",
	"return": "RETURN", "spy": "SPY", "spy_back": "SPY BACK", "trophy": "TROPHY",
	"vp": "VP",
	# доход с маркеров контроля и бонуса гекса A2 (решение владельца,
	# 2026-09-28: игроки его не замечали)
	"mark_influence": "MARK INF", "mark_vp": "MARK VP",
	"a2_power": "A2 POWER", "a2_influence": "A2 INF", "a2_vp": "A2 VP",
}
## Больше ходов не держим — самые старые уходят (сотни узлов ни к чему).
const MAX_BLOCKS := 60
## Насколько близко к низу надо быть, чтобы колонка продолжала листаться
## за новыми картами.
const FOLLOW_SLACK := 8
## Рамка и подложка блока: цвет игрока, почти прозрачный.
const FRAME_ALPHA := 0.35
const FILL_ALPHA := 0.06

## Мышь над строкой действия — места на доске, где это было (см. add_stat);
## ушла со строки — пустой список.
signal places_hovered(places: Array)

var _scroll: ScrollContainer
var _list: VBoxContainer
var _placeholder: Label
var _blocks: Array[Block] = []
var _turn_closed := true
## Сколько кадров ещё дотягивать прокрутку до низа: размер списка после
## добавления карты станет известен только на следующем кадре.
var _pin_frames := 0
var _hovered: Array = []   # [Block, key] строки под мышью или пусто


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
	_after_add(follow)


## pid сыграл карту cid.
func add_played(pid: String, cid: String) -> void:
	add(pid, cid, "PLAYED")


## pid сбросил карту cid. Во время чужого хода (его заставили) карта ложится
## в блок ходящего своей группой с подписью цвета pid.
func add_discard(pid: String, cid: String) -> void:
	add_to_turn(pid, cid, "DISCARDED")


## Карта cid досталась pid в ход того, кто сейчас ходит (сброс, изгой от
## чужой карты): ложится в блок ходящего. Если pid — не ходящий, группа
## своя, с подписью цвета pid.
func add_to_turn(pid: String, cid: String, tag: String) -> void:
	var follow := _at_bottom()
	var block := _current_block(pid)
	if block.pid == pid:
		block.add_card(tag, _card(cid))
	else:
		block.add_card(tag + ":" + pid, _card(cid))
	_after_add(follow)


## Действие хода: key из STATS, amount — сколько добавить к счётчику,
## mark — чей цвет поставить квадратиком (убитый, вытесненный, хозяин шпиона).
## pid — кто действовал; пустой — тот, чей ход сейчас. places — где на доске
## это было: "slot:<id>", "site:<id>" или "kill:<slot_id>" (см.
## BoardPanel.show_places).
func add_stat(pid: String, key: String, amount: int = 1, mark: String = "",
		places: Array = []) -> void:
	if amount <= 0 or not STATS.has(key):
		return
	var follow := _at_bottom()
	var block := _current_block(pid)
	var fresh := not block.has_row(key)
	block.add_stat(key, amount, mark, places)
	if fresh:
		var row := block.row(key)
		row.mouse_entered.connect(_hover_row.bind(block, key, true))
		row.mouse_exited.connect(_hover_row.bind(block, key, false))
		# Строку убрали из-под мыши (старый ход ушёл) — mouse_exited не придёт.
		row.tree_exiting.connect(_hover_row.bind(block, key, false))
	_after_add(follow)


## Для проверок: места строки действия key последнего хода.
func last_places(key: String) -> Array:
	if _blocks.is_empty():
		return []
	return _blocks.back().places.get(key, [])


## Для проверок и экрана: строка действия key последнего хода или null.
func last_row(key: String) -> Control:
	if _blocks.is_empty() or not _blocks.back().has_row(key):
		return null
	return _blocks.back().row(key)


## Строка под мышью подсвечена, места — на доске; ушла мышь — гаснет.
func _hover_row(block: Block, key: String, inside: bool) -> void:
	if inside:
		_hovered = [block, key]
	elif _hovered.is_empty() or _hovered[0] != block or _hovered[1] != key:
		return
	else:
		_hovered = []
	block.light_row(key, inside)
	places_hovered.emit((block.places.get(key, []) as Array).duplicate() if inside else [])


## Для проверок: число в строке действия key последнего хода (0 — строки нет).
func last_stat(key: String) -> int:
	if _blocks.is_empty():
		return 0
	return int(_blocks.back().stats.get(key, 0))


## Открытый блок текущего хода, а если его нет — новый блок pid.
func _current_block(pid: String) -> Block:
	if _placeholder != null:
		_placeholder.queue_free()
		_placeholder = null
	var block: Block = _blocks.back() if not _blocks.is_empty() else null
	if block == null or _turn_closed:
		block = _open_block(pid if pid != "" else "?")
	return block


func _after_add(follow: bool) -> void:
	_trim()
	if follow:
		_pin_frames = 2
		set_process(true)


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
	card.hover_full = true   # полная карта по наведению, без Alt
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
	## Строки действий: key -> счётчик.
	var stats: Dictionary = {}
	## Строки действий: key -> места на доске (см. TurnFeed.add_stat).
	var places: Dictionary = {}
	## Квадратик цвета в строке действия и сколько их влезает в ширину карты.
	const MARK := 5
	const MAX_MARKS := 6
	var _order: Array[String] = []
	var _col: VBoxContainer
	var _cells: Dictionary = {}
	## key -> [Label, HBoxContainer квадратиков]
	var _rows: Dictionary = {}
	var _stats_box: VBoxContainer

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
		for tag: String in groups:
			result.append(tag)
		result.sort_custom(func(a: String, b: String) -> bool:
			return _cells[a].get_index() < _cells[b].get_index())
		return result

	func has_row(key: String) -> bool:
		return _rows.has(key)

	## Вся строка действия (подпись и квадратики) — по ней ловится наведение.
	func row(key: String) -> Control:
		return (_rows[key][0] as Control).get_parent()

	## Строка под мышью светлеет. Только у строк с местами на доске — у
	## остальных наводить не на что.
	func light_row(key: String, on: bool) -> void:
		if _rows.has(key) and not (places.get(key, []) as Array).is_empty():
			row(key).modulate = Color(1.6, 1.6, 1.6) if on else Color.WHITE

	## Строка действия: счётчик растёт, квадратик цвета mark добавляется,
	## места на доске копятся.
	func add_stat(key: String, amount: int, mark: String, where: Array = []) -> void:
		if not _rows.has(key):
			_add_row(key)
		stats[key] = int(stats.get(key, 0)) + amount
		if not places.has(key):
			places[key] = []
		(places[key] as Array).append_array(where)
		var row: Array = _rows[key]
		var label: Label = row[0]
		match key:
			"vp":
				label.text = "+%d VP" % stats[key]
			"a2_vp":
				label.text = "A2 +%d VP" % stats[key]
			"mark_vp":
				label.text = "MARK +%d VP" % stats[key]
			"a2_power", "a2_influence", "mark_influence":
				label.text = "%s +%d" % [TurnFeed.STATS[key], stats[key]]
			_:
				label.text = "%s %d" % [TurnFeed.STATS[key], stats[key]]
		var marks: HBoxContainer = row[1]
		# Квадратики — пока влезают в ширину карты рядом с подписью: иначе
		# строка раздвинула бы колонку.
		var font := label.get_theme_font("font")
		var text_w := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			label.get_theme_font_size("font_size")).x
		var room := int((TurnFeed.CARD.x - text_w - 2) / (MARK + 1))
		while marks.get_child_count() > maxi(room, 0):
			var extra := marks.get_child(marks.get_child_count() - 1)
			marks.remove_child(extra)
			extra.queue_free()
		if mark != "" and marks.get_child_count() < mini(room, MAX_MARKS):
			var dot := ColorRect.new()
			dot.color = BoardPanel.troop_colour(mark)
			dot.custom_minimum_size = Vector2(MARK, MARK)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marks.add_child(dot)

	## Строки действий лежат под всеми группами карт, по порядку STATS.
	func _add_row(key: String) -> void:
		if _stats_box == null:
			_stats_box = VBoxContainer.new()
			_stats_box.add_theme_constant_override("separation", 0)
			_stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_col.add_child(_stats_box)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		# PASS: наведение строка ловит, а колесо уходит дальше — листать колонку.
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var label := Label.new()
		var colour := PixelTheme.TEXT_DIM
		if key == "vp" or key == "a2_vp" or key == "mark_vp":
			colour = PixelTheme.GOLD
		elif key == "a2_power":
			colour = GameScreen.POWER_COLOR
		elif key == "a2_influence" or key == "mark_influence":
			colour = GameScreen.INFLUENCE_COLOR
		elif key == "kill":
			colour = PixelTheme.DANGER
		label.add_theme_color_override("font_color", colour)
		row.add_child(label)
		var marks := HBoxContainer.new()
		marks.add_theme_constant_override("separation", 1)
		marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(marks)
		var before := 0
		for other: String in TurnFeed.STATS:
			if other == key:
				break
			if _rows.has(other):
				before += 1
		_stats_box.add_child(row)
		_stats_box.move_child(row, before)
		_rows[key] = [label, marks]

	## Новая группа встаёт на своё место по порядку: после заголовка и всех
	## групп, которые в порядке идут раньше неё или вместе с ней. Чужой сброс
	## ("DISCARDED:blue") стоит рядом со своим, подпись — цвета сбросившего.
	func _add_group(tag: String) -> void:
		var base := tag.get_slice(":", 0)
		var owner := tag.get_slice(":", 1) if tag.contains(":") else ""
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ladder := Ladder.new()
		cell.add_child(ladder)
		var label := Label.new()
		label.text = base
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var colour := PixelTheme.DANGER if base == "DEVOURED" else PixelTheme.TEXT_DIM
		if owner != "":
			colour = EventLogPanel.player_color(owner)
		label.add_theme_color_override("font_color", colour)
		cell.add_child(label)
		var rank := _order.find(base)
		var before := 0
		for other: String in groups:
			if _order.find(other.get_slice(":", 0)) <= rank:
				before += 1
		_col.add_child(cell)
		_col.move_child(cell, 1 + before)
		groups[tag] = ladder
		_cells[tag] = cell


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
