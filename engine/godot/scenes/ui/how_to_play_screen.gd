extends VBoxContainer

## HOW TO PLAY: обучение для новичков по основной книге правил (Tyrants of the
## Underdark Rulebook), без правил Demonweb (решение владельца, 2026-09-25).
##
## Живёт прямо в окне главного меню, раздел PLAY → HOW TO PLAY, без лишней
## кнопки OPEN (владелец, 2026-10-06) — поэтому компактное: сверху текст
## страницы, под ним картинка, внизу листалка. Страницы листаются кнопками или
## стрелками. Картинки — из материалов самой игры: пиксельные лица карт
## (CardView) и маленькая доска, нарисованная тем же SchematicPainter, что и
## доска в партии, с настоящими фишками (красные — с гербом игрока).

const WIDTH := 470
## Под текст — место на 10 строк: картинка под ним не прыгает от страницы к
## странице.
const TEXT_H := 10 * PixelTheme.LINE_H
const PIC_H := 260
const BOARD_ZOOM := 2
const BUTTON_SIZE := Vector2(70, 16)

# Карты из data/cards/cards.json.
const NOBLE := "48342"
const SOLDIER := "48344"
const PRIESTESS := "48343"
const HOUSE_GUARD := "48340"
const ADVOCATE := "48306"
const MARKET_SAMPLE := ["48336", "48334", "48331", "48329", "48316", "48320"]

## Маленькие доски. Места — коробки как на настоящей схеме; ключи клеток:
## "<место><номер>" (A0, B2) и "R<номер>" для клеток на пути.
const MAP_SITES := {
	"A": {"name": "Menzoberranzan", "vp": 3, "slots": 3, "at": [4, 10], "starting": true},
	"B": {"name": "Araumycos", "vp": 2, "slots": 3, "at": [81, 10]},
	"C": {"name": "Blingdenstone", "vp": 4, "slots": 2, "at": [48, 44], "marker": true},
}
const MAP_RINGS := [[56, 20], [70, 20]]
const MAP_TRACES := [[43, 20, 81, 20], [70, 20, 70, 44]]
const MAP_SIZE := [128, 66]

var _pages: Array = []
var _page := 0
var _emblem := ""
var _title: Label
var _text: RichTextLabel
var _pic: CenterContainer
var _counter: Label
var _prev: Button
var _next: Button


## page — с какой страницы открыть (меню помнит, где остановились).
func _init(page: int = 0) -> void:
	add_theme_constant_override("separation", 4)
	_emblem = String(PlayerProfile.load_local()["emblem"])
	_pages = _build_pages()

	_title = GameScreen.section_label("")
	_title.add_theme_color_override("font_color", PixelTheme.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH, TEXT_H)
	add_child(_text)
	_pic = CenterContainer.new()
	_pic.custom_minimum_size = Vector2(WIDTH, PIC_H)
	add_child(_pic)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	add_child(buttons)
	_prev = _button("< BACK", func(): show_page(_page - 1))
	buttons.add_child(_prev)
	_counter = Label.new()
	_counter.custom_minimum_size = Vector2(50, 0)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	buttons.add_child(_counter)
	_next = _button("NEXT >", func(): show_page(_page + 1))
	buttons.add_child(_next)

	show_page(page)


func page_count() -> int:
	return _pages.size()


func current_page() -> int:
	return _page


func show_page(index: int) -> void:
	_page = clampi(index, 0, _pages.size() - 1)
	var page: Dictionary = _pages[_page]
	_title.text = String(page["title"])
	_text.text = String(page["text"])
	for child in _pic.get_children():
		_pic.remove_child(child)
		child.queue_free()
	_pic.add_child((page["pic"] as Callable).call())
	_counter.text = "%d / %d" % [_page + 1, _pages.size()]
	_prev.disabled = _page == 0
	_next.disabled = _page == _pages.size() - 1


## Стрелки (и A / D) листают, пока раздел открыт.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not is_visible_in_tree():
		return
	match key.keycode:
		KEY_RIGHT, KEY_D:
			show_page(_page + 1)
		KEY_LEFT, KEY_A:
			show_page(_page - 1)
		_:
			return
	get_viewport().set_input_as_handled()


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.focus_mode = Control.FOCUS_NONE
	SetupScreen._style_button(b)
	b.pressed.connect(action)
	return b


# --- страницы ------------------------------------------------------------------

static func _gold(s: String) -> String:
	return "[color=#f2d23c]%s[/color]" % s


func _build_pages() -> Array:
	return [
		{"title": "1. YOUR GOAL", "pic": _pic_overview,
		"text": "You are the head of a drow house fighting for power in the Underdark.\n\n"
			+ "Build a deck of minion cards, send your troops and spies across the map and "
			+ "collect %s.\n\n" % _gold("victory points (VP)")
			+ "The game ends when a player deploys their last troop or the market deck runs out. "
			+ "The player with the most VP wins."},

		{"title": "2. YOUR DECK", "pic": _pic_cards.bind([NOBLE, SOLDIER]),
		"text": "Everyone starts with the same 10 cards: %s and %s.\n\n"
				% [_gold("7 Nobles"), _gold("3 Soldiers")]
			+ "You always hold 5 cards. At the end of your turn you discard everything and "
			+ "draw a fresh hand of 5.\n\n"
			+ "When your deck is empty, your discard pile is shuffled into a new deck. "
			+ "This is how the new cards you buy reach your hand."},

		{"title": "3. POWER AND INFLUENCE", "pic": _pic_rows.bind([
			["1 POWER", "Deploy a troop"],
			["3 POWER", "Assassinate a troop"],
			["3 POWER", "Return an enemy spy"],
			["INFLUENCE", "Recruit a card (pay its cost)"],
		], "WHAT YOU CAN BUY ANY TIME ON YOUR TURN"),
		"text": "Cards give you two resources:\n"
			+ "• %s acts on the map;\n• %s buys new cards.\n\n" % [_gold("Power"), _gold("Influence")]
			+ "A Noble gives +1 Influence, a Soldier +1 Power.\n\n"
			+ "Spend them during your turn. Whatever is left when the turn ends is lost, "
			+ "so use it all!"},

		{"title": "4. YOUR TURN", "pic": _pic_rows.bind([
			["1", "Promote cards (if a card said so)"],
			["2", "Get bonuses from control markers"],
			["3", "Discard played cards and your hand"],
			["4", "Draw 5 new cards"],
		], "AFTER END TURN THE GAME DOES THIS FOR YOU"),
		"text": "On your turn do these in any order, as many times as you like:\n"
			+ "• play a card from your hand and follow its text;\n"
			+ "• spend Power and Influence on actions.\n\n"
			+ "Cards are played one at a time, top to bottom of their text.\n\n"
			+ "When you are done, press %s." % _gold("END TURN")},

		{"title": "5. THE MARKET", "pic": _pic_market,
		"text": "Buying a card is called %s. " % _gold("recruiting")
			+ "Six market cards lie face up; a bought card is replaced from the market deck.\n\n"
			+ "Two cards are always on sale: %s (+2 Influence) and %s (+2 Power).\n\n"
				% [_gold("Priestess of Lolth"), _gold("House Guard")]
			+ "A recruited card goes to your discard pile and comes to your hand after the next "
			+ "shuffle. Better cards cost more and are worth more VP."},

		{"title": "6. THE MAP", "pic": _pic_board.bind({"C0": "white", "B1": "white"}, {}, [],
			"Dark box: starting site. Gold frame: control\nmarker. Big number: VP of the site."),
		"text": "The map is made of %s (boxes) joined by %s (lines with round troop spaces).\n\n"
				% [_gold("sites"), _gold("routes")]
			+ "A box shows the site name, its troop spaces and how many VP it is worth.\n\n"
			+ "Dark boxes are %s: each player places their first troop in one.\n\n" % _gold("starting sites")
			+ "Grey troops are %s. They are enemies to everyone and only get in the way."
				% _gold("white (neutral)")},

		{"title": "7. PRESENCE", "pic": _pic_board.bind({"A0": "red", "R0": "red", "C0": "white"}, {},
			["A1", "A2", "R1"], "Red troops. Green rings: where red can deploy."),
		"text": "Most map actions need %s. You have presence:\n" % _gold("presence")
			+ "• at a site with your troop or spy;\n"
			+ "• at a site next to one of your troops;\n"
			+ "• on a route space next to your troop.\n\n"
			+ "%s costs 1 Power: put a troop on an empty space where you have presence.\n\n"
				% _gold("Deploy")
			+ "With no troops on the map at all you may deploy anywhere."},

		{"title": "8. CONTROL", "pic": _pic_control,
		"text": "You %s a site when you have more troops there than any other single colour.\n\n"
				% _gold("control")
			+ "%s: every space is yours and no enemy spy is there.\n\n" % _gold("Total control")
			+ "A site with a %s gives its holder a bonus every turn "
				% _gold("control marker")
			+ "(Influence; VP for total control).\n\n"
			+ "At the end each controlled site scores its VP, total control +2 VP more."},

		{"title": "9. SPIES", "pic": _pic_spies,
		"text": "%s (from cards): put a spy on any site, no presence needed. " % _gold("Place a spy")
			+ "It gives you presence there.\n\n"
			+ "You have 5 spies. A site may hold spies of several players, but only one of yours.\n\n"
			+ "An enemy spy stops your total control. %s: pay 3 Power to send it back to its owner "
				% _gold("Return an enemy spy")
			+ "(you need presence at that site)."},

		{"title": "10. FIGHTING", "pic": _pic_trophies,
		"text": "%s (3 Power): take an enemy troop where you have presence and put it in "
				% _gold("Assassinate")
			+ "your %s. Each trophy is 1 VP.\n\n" % _gold("trophy hall")
			+ "%s (from cards): assassinate a troop and deploy yours on its space.\n\n"
				% _gold("Supplant")
			+ "%s (from cards): send an enemy troop or spy back to its owner.\n\n" % _gold("Return")
			+ "White troops count as enemies too."},

		{"title": "11. INNER CIRCLE", "pic": _pic_cards.bind([ADVOCATE]),
		"text": "Some cards let you %s a card. It leaves your deck for good and goes to your %s.\n\n"
				% [_gold("promote"), _gold("inner circle")]
			+ "Every card has two VP values at the bottom: in your deck and in the inner circle. "
			+ "Promoted cards score the inner-circle value.\n\n"
			+ "Promoting also thins your deck, so your best cards come back sooner."},

		{"title": "12. READING CARDS", "pic": _pic_aspects,
		"text": "A card's colour is its %s.\n\n" % _gold("aspect")
			+ "%s: the arrow part is optional. Pay the cost to get the effect, or skip it.\n\n"
				% _gold("Cost ► effect")
			+ "%s: you get the bonus if you played another card of the same aspect this turn, "
				% _gold("Focus")
			+ "or can show one from your hand.\n\n"
			+ "If a card disagrees with the rules, the card wins."},

		{"title": "13. END OF THE GAME", "pic": _pic_rows.bind([
			["SITES", "VP of each site you control"],
			["TOTAL", "+2 VP per site in total control"],
			["TROPHIES", "1 VP per troop in your trophy hall"],
			["DECK", "Deck VP of cards in deck, hand, discard"],
			["CIRCLE", "Inner-circle VP of promoted cards"],
			["TOKENS", "VP gained during the game"],
		], "FINAL SCORE"),
		"text": "The end is triggered when:\n"
			+ "• a player deploys their last troop, or\n• the market deck runs out.\n\n"
			+ "The round is then played to the end, so everyone gets the same number of turns.\n\n"
			+ "The most VP wins; tied players share the win."},

		{"title": "14. PLAYING ON THE COMPUTER", "pic": _pic_rows.bind([
			["CLICK CARD", "Play it from your hand"],
			["CLICK MAP", "Deploy (green) / assassinate (orange)"],
			["CLICK MARKET", "Recruit a card"],
			["HOLD ALT", "Enlarge the card under the mouse"],
			["TAB", "Ping the spot under the mouse"],
			["HOLD TAB", "Chat wheel (phrases: PROFILE)"],
			["ESC", "Pause menu"],
			["F11", "Full screen"],
		], "CONTROLS"),
		"text": "The game keeps the rules for you: it only allows legal moves and lights up "
			+ "where you can act.\n\n"
			+ "When a card asks you to choose, pick an option in the window or click a target "
			+ "on the map.\n\n"
			+ "%s buy good cards early, take the sites near your start, " % _gold("First game tips:")
			+ "and watch how many market cards are left."},
	]


# --- картинки ------------------------------------------------------------------

func _pic_cards(ids: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for cid: String in ids:
		row.add_child(_texture(CardView.pixel_texture(cid)))
	return row


func _pic_market() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.add_child(_caption("MARKET: 6 CARDS FACE UP", PixelTheme.GOLD))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for cid: String in MARKET_SAMPLE:
		grid.add_child(_texture(CardView.mini_texture(cid)))
	col.add_child(grid)
	col.add_child(_caption("ALWAYS ON SALE", PixelTheme.GOLD))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	for cid: String in [PRIESTESS, HOUSE_GUARD]:
		row.add_child(_texture(CardView.mini_texture(cid)))
	col.add_child(row)
	return col


## Таблица «слева — что, справа — зачем».
func _pic_rows(rows: Array, heading: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.add_child(_caption(heading, PixelTheme.GOLD))
	for r: Array in rows:
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", PixelTheme.box(PixelTheme.PANEL_HI, PixelTheme.BORDER, 1, 4, 3))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		box.add_child(line)
		var left := Label.new()
		left.text = String(r[0])
		left.custom_minimum_size = Vector2(80, 0)
		left.add_theme_color_override("font_color", PixelTheme.GOLD)
		line.add_child(left)
		var right := Label.new()
		right.text = String(r[1])
		line.add_child(right)
		col.add_child(box)
	return col


func _pic_aspects() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.add_child(_caption("THE FIVE ASPECTS", PixelTheme.GOLD))
	var roles := {
		"AMBITION": "Recruiting and the inner circle",
		"CONQUEST": "Taking over the map",
		"MALICE": "Assassination",
		"GUILE": "Spies and breaking control",
		"OBEDIENCE": "Everyday work",
	}
	for aspect: String in roles:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", PixelTheme.box(CardView.ASPECT_COLORS[aspect], PixelTheme.BG, 1, 3, 2))
		chip.custom_minimum_size = Vector2(76, 0)
		var name_label := Label.new()
		name_label.text = aspect
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(name_label)
		line.add_child(chip)
		var role := Label.new()
		role.text = String(roles[aspect])
		role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(role)
		col.add_child(line)
	return col


func _pic_overview() -> Control:
	return _pic_board({"A0": "red", "A1": "red", "R0": "red", "B0": "blue", "B1": "blue",
		"C0": "white"}, {"A": ["blue"], "C": ["red"]}, [],
		"Red and blue troops; diamonds are spies.")


func _pic_control() -> Control:
	var sites := {
		"A": {"name": "Menzoberranzan", "vp": 3, "slots": 4, "at": [4, 10], "marker": true},
		"B": {"name": "Araumycos", "vp": 2, "slots": 3, "at": [72, 14]},
	}
	var img := mini_board(sites, [[58, 24]], [[43, 24, 72, 24]], [120, 44],
		{"A0": "red", "A1": "red", "A2": "blue", "A3": "white", "B0": "red", "B1": "red", "B2": "red"},
		{}, [], _emblem)
	return _board_block(img, "Left: red controls (2 troops against 1 and 1).\n"
		+ "Right: red has total control.")


func _pic_spies() -> Control:
	var img := mini_board(MAP_SITES, MAP_RINGS, MAP_TRACES, MAP_SIZE,
		{"B0": "red", "B1": "red", "B2": "red"}, {"B": ["blue"], "C": ["red"]}, [], _emblem)
	return _board_block(img, "Blue spy at the right site: red controls it,\n"
		+ "but has no total control. Red spy below.")


func _pic_trophies() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var img := mini_board(MAP_SITES, MAP_RINGS, MAP_TRACES, MAP_SIZE,
		{"A0": "red", "R0": "red", "R1": "blue", "C0": "white"}, {}, ["R1"], _emblem,
		BoardPanel.KILL_COLOR)
	col.add_child(_board_block(img, "Orange ring: red can assassinate this troop."))
	col.add_child(_caption("RED TROPHY HALL: 2 VP", PixelTheme.GOLD))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for pid: String in ["blue", "white"]:
		var tex := ImageTexture.create_from_image(SchematicPainter.token(_colour(pid)))
		var rect := _texture(tex, BOARD_ZOOM)
		row.add_child(rect)
	col.add_child(row)
	return col


func _pic_board(troops: Dictionary, spies: Dictionary, marks: Array, caption: String) -> Control:
	var img := mini_board(MAP_SITES, MAP_RINGS, MAP_TRACES, MAP_SIZE, troops, spies, marks, _emblem)
	return _board_block(img, caption)


func _board_block(img: Image, caption: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.add_child(_texture(ImageTexture.create_from_image(img), BOARD_ZOOM))
	col.add_child(_caption(caption, PixelTheme.TEXT_DIM))
	return col


func _caption(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", colour)
	return label


## Картинка целым масштабом, пиксель в пиксель.
static func _texture(tex: Texture2D, zoom: int = 1) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if tex != null:
		rect.custom_minimum_size = tex.get_size() * zoom
	return rect


static func _colour(pid: String) -> Color:
	return BoardPanel.NEUTRAL_TROOP_COLOR if pid == "white" \
		else BoardPanel.PLAYER_COLORS.get(pid, Color.GRAY)


## Маленькая доска в 1x: коробки мест и пути рисует SchematicPainter (как в
## партии), сверху фишки, ромбики шпионов и кольца подсветки (marks).
static func mini_board(sites: Dictionary, rings: Array, traces: Array, size: Array,
		troops: Dictionary, spies: Dictionary, marks: Array, emblem: String = "",
		mark_colour: Color = BoardPanel.DEPLOY_COLOR) -> Image:
	var schematic := {"size": size, "traces": traces, "rings": {}, "sites": {}}
	var slot_at := {}
	for i in rings.size():
		schematic["rings"]["R%d" % i] = rings[i]
		slot_at["R%d" % i] = Vector2i(int(rings[i][0]), int(rings[i][1]))
	var rects := {}
	for id: String in sites:
		var s: Dictionary = sites[id]
		var box := BoardSchematic.site_box(String(s["name"]), int(s["slots"]), bool(s.get("marker", false)))
		var at := Vector2i(int(s["at"][0]), int(s["at"][1]))
		var slots := {}
		for k in (box["slots"] as Array).size():
			var p := at + Vector2i(box["slots"][k])
			slots["%s%d" % [id, k]] = [p.x, p.y]
			slot_at["%s%d" % [id, k]] = p
		rects[id] = Rect2i(at.x, at.y, int(box["w"]), int(box["h"]))
		schematic["sites"][id] = {
			"rect": [at.x, at.y, box["w"], box["h"]], "name": s["name"], "vp": s["vp"],
			"starting": s.get("starting", false), "marker": s.get("marker", false), "slots": slots,
		}
	var img := SchematicPainter.paint(schematic)

	var r := BoardSchematic.SLOT_R
	for key: String in marks:
		var c: Vector2i = slot_at[key]
		for dy in range(-r - 2, r + 3):
			for dx in range(-r - 2, r + 3):
				var d := dx * dx + dy * dy
				if d > r * r + r and d <= (r + 1) * (r + 1) + r + 1:
					img.set_pixel(c.x + dx, c.y + dy, mark_colour)
	for key: String in troops:
		var pid := String(troops[key])
		var token := SchematicPainter.token(_colour(pid), emblem if pid == "red" else "")
		var c: Vector2i = slot_at[key]
		img.blend_rect(token, Rect2i(Vector2i.ZERO, token.get_size()), c - Vector2i(r, r))
	for id: String in spies:
		var owners: Array = spies[id]
		var rect: Rect2i = rects[id]
		for i in owners.size():
			var c := Vector2i(rect.get_center().x + (i * 2 - owners.size() + 1) * 4, rect.position.y - 5)
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var d := absi(dx) + absi(dy)
					if d <= 3:
						img.set_pixel(c.x + dx, c.y + dy,
							_colour(String(owners[i])) if d <= 2 else Color(0.04, 0.03, 0.06))
	return img
