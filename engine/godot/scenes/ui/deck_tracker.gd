class_name DeckTracker
extends Control

## Дектрекер (решение владельца, 2026-09-28): полоса слева от рынка во всю
## высоту от верха рынка до низа экрана. Показывает, какие карты зрителя лежат
## в колоде добора и в сбросе, — не в настоящем порядке (его не знает и сам
## игрок), а по убыванию цены, одинаковые карты рядом.
##
## Карты — мелкие лица 80x76 лесенкой: каждая следующая ложится на предыдущую,
## от той видна только верхняя полоска (имя и цена). Шаг лесенки один на обе
## части и подбирается под высоту полосы: мало карт — они стоят целиком, много
## — полоски тоньше. Разделитель «DISCARD» плавает: стоит сразу под колодой.
## Каждая копия карты — своя ступенька (решение владельца).

const CARD := Vector2i(CardView.MINI_SIZE)
const PAD := 1
## Шаг, когда место есть: карты целиком и промежуток как на рынке.
const MAX_STEP := CARD.y + 2
## Тоньше полоска уже ничего не говорит; что не влезло — обрежет край.
const MIN_STEP := 3
## Разделитель: пиксель отступа, линия, пиксель отступа.
const DIVIDER_H := 3

var _style: StyleBoxFlat
var _deck_label: Label
var _discard_label: Label
var _divider: ColorRect
## Пул лиц: сначала карты колоды, за ними сброса. Лишние скрыты.
var _cards: Array[CardView] = []
var _deck: Array = []
var _discard: Array = []
## Где начинается часть сброса (верх разделителя), в своих координатах.
var _discard_top := 0.0


func _init() -> void:
	_style = GameScreen.zone_style(PAD)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_label = GameScreen.section_label("DECK 0")
	add_child(_deck_label)
	_divider = ColorRect.new()
	_divider.color = PixelTheme.BORDER
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_divider)
	_discard_label = GameScreen.section_label("DISCARD 0")
	add_child(_discard_label)
	resized.connect(_arrange)


## deck — состав колоды добора, discard — сброс; порядок не важен.
func set_cards(deck: Array, discard: Array) -> void:
	_deck = sorted_by_cost(deck)
	_discard = sorted_by_cost(discard)
	_deck_label.text = "DECK %d" % _deck.size()
	_discard_label.text = "DISCARD %d" % _discard.size()
	var ids := _deck + _discard
	# Новое лицо сразу со своей картой: без id CardView не берёт пиксельную
	# картинку и собирается текстовой карточкой.
	while _cards.size() < ids.size():
		var card := CardView.new(String(ids[_cards.size()]), CARD.x, CARD.y)
		card.set_clickable(false, false)
		add_child(card)
		_cards.append(card)
	for i in _cards.size():
		_cards[i].visible = i < ids.size()
		if i < ids.size() and _cards[i].card_id != String(ids[i]):
			_cards[i].set_card(String(ids[i]))
	_arrange()


## Дороже — выше; при равной цене по имени, чтобы копии стояли подряд.
static func sorted_by_cost(ids: Array) -> Array:
	var out := ids.duplicate()
	out.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ca := _cost(String(a))
		var cb := _cost(String(b))
		if ca != cb:
			return ca > cb
		var na := String(CardLibrary.card_data(String(a)).get("name", a))
		var nb := String(CardLibrary.card_data(String(b)).get("name", b))
		if na != nb:
			return na < nb
		return String(a) < String(b))
	return out


static func _cost(cid: String) -> int:
	var cost: Variant = CardLibrary.card_data(cid).get("cost")
	return int(cost) if cost != null else 0


## Шаг лесенки: обе части целиком в полосу, у каждой непустой части последняя
## карта видна полностью.
func ladder_step() -> int:
	var line := PixelTheme.LINE_H
	var fixed := PAD * 2 + line * 2 + DIVIDER_H
	var links := maxi(_deck.size() - 1, 0) + maxi(_discard.size() - 1, 0)
	var whole := (1 if not _deck.is_empty() else 0) + (1 if not _discard.is_empty() else 0)
	if links == 0:
		return MAX_STEP
	var free := int(size.y) - fixed - CARD.y * whole
	return clampi(floori(float(free) / links), MIN_STEP, MAX_STEP)


func _arrange() -> void:
	var line := float(PixelTheme.LINE_H)
	var inner_w := size.x - PAD * 2
	var step := ladder_step()
	var x := PAD + floorf((inner_w - CARD.x) * 0.5)
	var y := float(PAD)
	_deck_label.position = Vector2(PAD, y)
	_deck_label.size = Vector2(inner_w, line)
	y += line
	y = _lay(0, _deck.size(), x, y, step)
	_discard_top = y
	_divider.position = Vector2(PAD, y + 1)
	_divider.size = Vector2(inner_w, 1)
	y += DIVIDER_H
	_discard_label.position = Vector2(PAD, y)
	_discard_label.size = Vector2(inner_w, line)
	y += line
	_lay(_deck.size(), _discard.size(), x, y, step)
	queue_redraw()


## Кладёт count карт пула с номера first лесенкой от y; возвращает низ части.
func _lay(first: int, count: int, x: float, y: float, step: int) -> float:
	if count == 0:
		return y
	for k in count:
		var card := _cards[first + k]
		card.position = Vector2(x, y + k * step)
		card.size = Vector2(CARD)
	return y + (count - 1) * step + CARD.y


## Часть сброса на экране — туда летит купленная карта.
func discard_rect() -> Rect2:
	var top := minf(_discard_top, size.y - 1.0)
	return Rect2(global_position + Vector2(0, top), Vector2(size.x, size.y - top))


func _draw() -> void:
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
