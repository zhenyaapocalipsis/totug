class_name CavePainter
extends RefCounted

## Подземелье под схемой доски (решение владельца, 2026-09-30): вся доска —
## одно сооружение, вырубленное в скале, города — залы, тоннели — коридоры,
## кольца — ниши. Каждый город задаёт тему своему району (храм, руины, лава,
## грибы...): пол, стены, свет, пустоты между коридорами и предметы.
## Пещера — только украшение: связи показывают дорожки и кольца схемы
## (SchematicPainter.paint), поэтому залы могут сливаться, а раскладку доски
## под пещеру менять не нужно.
##
## Как строится (всё в пикселях схемы, со сдвигом CAVE_MARGIN):
## 1. Карта расстояний (чамфер 1/sqrt2) до осей тоннелей, колец и коробок.
##    Пол — ближе порога, порог колеблется шумом, край получается рваным.
##    Вокруг пола полоса скалы CAVE_WALL.
## 2. Пустоты: не пол и не скала, но замкнутые со всех сторон (не выходят к
##    краю картинки) — «сцена» района: лавовое озеро, грибная роща, пропасть
##    с паутиной... Снаружи пещеры — прозрачно, там живой фон экрана.
## 3. Район — ближайший город (вторая карта расстояний с метками); его тема
##    (SITE_THEMES) выбирает текстуры и предметы, свет — от коробки города.
## 4. У стен над полом видна лицевая грань в CAVE_FACE пикселей из текстуры
##    стены темы, под ней — тень; на скале — светлый край.
## 5. Архитектура и природа района — объекты PixelLab (assets/board_objects,
##    _objects): главное сооружение у коробки города, остальное рядом, мимо
##    дорожек, колец и коробок.
##
## Текстуры 32x32 — PixelLab (create_tiles_pro / create_image_pixflux,
## 2026-09-30). Нет файла — ровный цвет темы, пещера всё равно строится.

const MAT_DIR := "res://assets/board_mat/"

## Поля картинки пещеры вокруг схемы. BoardPanel рисует её со сдвигом -CAVE_MARGIN.
const CAVE_MARGIN := 14
const CORRIDOR_R := 4.0     # пол от оси тоннеля
const ROOM_R := 8.0         # пол от края коробки города (пещерный зал)
const NICHE_R := 3.0        # пол от края кольца
const CAVE_WALL := 7.0     # скала вокруг пола: внизу лицевая грань, сверху — верх скалы
const CAVE_NOISE := 1.6     # рваность края пола, +- пикселей
const CAVE_FACE := 4       # высота лицевой грани стены (на скале, над полом или пустотой)
const LIGHT_R := 26.0       # свет от коробки гаснет на этом расстоянии
const FLOOR_DARK := 0.32    # яркость пола в темноте (коридоры)
const FLOOR_LIGHT := 0.68   # и у самого города: пол не должен спорить с дорожками и коробками
const SCENE_DARK := 0.55
const ROCK_SHADE := 0.5
const ROCK_LIP := 1.9       # край скалы у пола
const FACE_SHADE := [1.5, 1.1, 0.9, 0.7]   # сверху вниз: светлый край, затем в тень
const AO_MIN := 0.45        # пол у самой стены темнее (окклюзия)
const AO_R := 3.0           # на столько пикселей от стены тень сходит на нет
const OUTER_EDGE := Color("07060c")   # контур пещеры снаружи
## Граница районов: метка района берётся со сдвигом по шуму на +-BORDER_JITTER
## пикселей и с зерном Байера — граница рваная и зернистая, а не прямая.
const BORDER_JITTER := 6.0
const MIN_HOLLOW := 60      # пустота меньше — просто скала
const PROP_GAP := 3         # объекты не ближе друг к другу

## Тема: floor — пол залов и коридоров района, wall — лицевая грань стен,
## scene — пустоты района, light — цвет света от города, colour — запасной
## цвет пола без текстуры.
## open = true — пустота жидкая или бездонная (лава, вода, пропасть): объекты
## туда не ставятся (кроме лавовых — в лаву).
const THEMES := {
	"temple": {"floor": "floor_temple", "wall": "wall_obsidian", "scene": "scene_temple", "open": true,
		"light": Color("ff5a4a"), "colour": Color("2a1a22")},
	"web": {"floor": "floor_web", "wall": "wall_rock", "scene": "scene_web",
		"light": Color("d8d0ff"), "colour": Color("26222e")},
	"drow": {"floor": "floor_drow", "wall": "wall_drow", "scene": "scene_drow",
		"light": Color("b070ff"), "colour": Color("241c34")},
	"hall": {"floor": "floor_hall", "wall": "wall_marble", "scene": "scene_hall", "open": true,
		"light": Color("ffd890"), "colour": Color("2e2c34")},
	"gate": {"floor": "floor_gate", "wall": "wall_blocks", "scene": "scene_gate", "open": true,
		"light": Color("ffa050"), "colour": Color("2a2630")},
	"lava": {"floor": "floor_lava", "wall": "wall_obsidian", "scene": "scene_lava", "open": true,
		"light": Color("ff7a20"), "colour": Color("2a1612")},
	"fungus": {"floor": "floor_fungus", "wall": "wall_rock", "scene": "scene_fungus",
		"light": Color("50e0e0"), "colour": Color("1a2a2a")},
	"ruins": {"floor": "floor_ruins", "wall": "wall_ruins", "scene": "scene_ruins",
		"light": Color("c0b0a0"), "colour": Color("2a2628")},
	"desert": {"floor": "floor_desert", "wall": "wall_rock", "scene": "scene_desert",
		"light": Color("f0e0b0"), "colour": Color("3a3440")},
	"mist": {"floor": "floor_mist", "wall": "wall_rock", "scene": "scene_mist",
		"light": Color("90c8ff"), "colour": Color("262a38")},
	"necro": {"floor": "floor_necro", "wall": "wall_blocks", "scene": "scene_necro",
		"light": Color("90ff90"), "colour": Color("1e2420")},
}
const DEFAULT_THEME := "ruins"

## Какая тема у какого города (по названию). Правится владельцем.
const SITE_THEMES := {
	"Lolth Shrine": "temple", "Wells of Darkness": "temple",
	"Great Web": "web", "The Great Web": "web", "Spiderhome": "web",
	"Web (N)": "web", "Web (NE)": "web", "Web (NW)": "web",
	"Web (S)": "web", "Web (SE)": "web", "Web (SW)": "web",
	"Menzoberranzan": "drow", "Erelhei-Cinlu": "drow", "Xal Veldrin": "drow",
	"Zi'Xzolca": "drow", "Xith Idrana": "drow", "Xelathir": "drow",
	"Venathir": "drow", "Enzithir": "drow",
	"Council Chamber": "hall", "Caer Sidi": "hall",
	"Black Gate": "gate", "Red Gate": "gate",
	"Darkflame": "lava", "Magma Gate": "lava",
	"Araumycos": "fungus", "Red Forest": "fungus", "Shedaklah": "fungus",
	"Iblith": "ruins", "Kulggen": "ruins", "Vrith": "ruins",
	"Spiral Desert": "desert", "Iron Wastes": "desert",
	"Fogtown": "mist", "Faerholme": "mist", "Darklight Realm": "mist", "The Twilight": "mist",
	"Thanatos Gate": "necro", "Gallenghast": "necro",
}

enum Cell { OUTSIDE, FLOOR, ROCK, HOLLOW }

static var _mat_cache: Dictionary = {}    # имя -> Image или null
static var _prop_cache: Dictionary = {}   # имя -> Image (обрезанный по непрозрачному) или null


static func theme_of(site_name: String) -> String:
	return String(SITE_THEMES.get(site_name, DEFAULT_THEME))


## Картинка пещеры размером схемы + 2 * CAVE_MARGIN; точка (m, m) картинки —
## точка (0, 0) схемы.
static func paint(schematic: Dictionary) -> Image:
	return paint_layers(schematic)[0]


## [картинка, маска свечения, живность] — маска того же размера для шейдера
## cave_glow.gdshader: R — лава и огонь (пульс), G — туман (плывёт),
## B — кристаллы, огоньки, руны (мерцают). См. _glow_mask.
static func paint_layers(schematic: Dictionary) -> Array:
	var m := CAVE_MARGIN
	var size: Array = schematic.get("size", [1, 1])
	var w := int(size[0]) + 2 * m
	var h := int(size[1]) + 2 * m
	var img := Image.create(maxi(1, w), maxi(1, h), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var off := Vector2(m, m)

	# --- что где стоит: пол (карта расстояний) и район (метки городов) ---
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	dist.fill(1e9)
	var keep := PackedByteArray()     # дорожки, кольца, коробки: предметы сюда не ставятся
	keep.resize(w * h)
	for flat: Array in schematic.get("traces", []):
		var points := SchematicPainter._points(flat)
		for seg: Array in SchematicPainter.rounded(points):
			_seed_line(dist, keep, w, h, (seg[0] as Vector2) + off, (seg[1] as Vector2) + off)
	for at: Array in (schematic.get("rings", {}) as Dictionary).values():
		var c := Vector2i(roundi(at[0]) + m, roundi(at[1]) + m)
		_seed_rect(dist, w, h, Rect2i(c, Vector2i.ONE), CORRIDOR_R - (BoardSchematic.RING_R + NICHE_R))
		_mark(keep, w, h, Rect2i(c - Vector2i(6, 6), Vector2i(13, 13)))
	var site_dist := PackedFloat32Array()
	site_dist.resize(w * h)
	site_dist.fill(1e9)
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var themes: Array[Dictionary] = []
	var site_names: Array[String] = []
	var theme_names: Array[String] = []
	var boxes: Array[Rect2i] = []
	for site: Dictionary in (schematic.get("sites", {}) as Dictionary).values():
		var r: Array = site["rect"]
		var box := Rect2i(roundi(r[0]) + m, roundi(r[1]) + m, roundi(r[2]), roundi(r[3]))
		var index := themes.size()
		site_names.append(String(site.get("name", "")))
		theme_names.append(theme_of(site_names[index]))
		themes.append(THEMES[theme_names[index]])
		boxes.append(box)
		_mark(keep, w, h, box.grow(2))
		for y in range(maxi(box.position.y, 0), mini(box.end.y, h)):
			for x in range(maxi(box.position.x, 0), mini(box.end.x, w)):
				site_dist[y * w + x] = 0.0
				label[y * w + x] = index
	var legend: Array = schematic.get("a2_legend", [])
	if legend.size() == 4:
		var plate := Rect2i(roundi(legend[0]) + m, roundi(legend[1]) + m, roundi(legend[2]), roundi(legend[3]))
		_seed_rect(dist, w, h, plate, CORRIDOR_R - ROOM_R)
		_mark(keep, w, h, plate.grow(2))
	_chamfer(dist, PackedInt32Array(), w, h)
	_chamfer(site_dist, label, w, h)
	if themes.is_empty():
		return [img, Image.create(w, h, false, Image.FORMAT_RGBA8), {}]

	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.12
	var cell := PackedByteArray()
	cell.resize(w * h)
	var edge := PackedFloat32Array()
	edge.resize(w * h)
	# Коридоры — по карте dist (оси тоннелей, кольца, табличка A2), залы — по
	# расстоянию до своей коробки (site_dist), оба с рваным краем.
	for y in h:
		for x in w:
			var i := y * w + x
			var n := noise.get_noise_2d(x, y)
			var limit := CORRIDOR_R + n * CAVE_NOISE
			var room_d := site_dist[i]
			var room_limit := ROOM_R + n * CAVE_NOISE
			edge[i] = maxf(limit - dist[i], room_limit - room_d)
			if dist[i] <= limit or room_d <= room_limit:
				cell[i] = Cell.FLOOR
			elif dist[i] <= limit + CAVE_WALL or room_d <= room_limit + CAVE_WALL:
				cell[i] = Cell.ROCK
	_find_hollows(cell, w, h)

	# район каждого пикселя — с рваной зернистой границей
	var jitter_x := FastNoiseLite.new()
	jitter_x.seed = 11
	jitter_x.frequency = 0.09
	var jitter_y := FastNoiseLite.new()
	jitter_y.seed = 23
	jitter_y.frequency = 0.09
	var district := PackedInt32Array()
	district.resize(w * h)
	for y in h:
		for x in w:
			var grain := (float(BAYER[(y % 4) * 4 + (x % 4)]) / 15.0 - 0.5) * 3.0
			var sx := clampi(x + roundi(jitter_x.get_noise_2d(x, y) * BORDER_JITTER + grain), 0, w - 1)
			var sy := clampi(y + roundi(jitter_y.get_noise_2d(x, y) * BORDER_JITTER - grain), 0, h - 1)
			district[y * w + x] = maxi(label[sy * w + sx], 0)

	# --- краска ---
	for y in h:
		for x in w:
			var i := y * w + x
			var kind := cell[i]
			if kind == Cell.OUTSIDE:
				continue
			var theme: Dictionary = themes[district[i]]
			var light := clampf(1.0 - site_dist[i] / LIGHT_R, 0.0, 1.0)
			light = _dither(light, x, y)
			var col: Color
			if kind == Cell.HOLLOW:
				col = _mat_at(String(theme["scene"]), x, y, (theme["colour"] as Color).darkened(0.3))
				col = _lit(col, lerpf(SCENE_DARK, 1.0, light * 0.6), theme["light"], light * 0.15)
			elif kind == Cell.ROCK:
				col = _rock(cell, district, themes, w, h, x, y, light)
			else:
				col = _mat_at(String(theme["floor"]), x, y, theme["colour"])
				var k := lerpf(FLOOR_DARK, FLOOR_LIGHT, light) * lerpf(AO_MIN, 1.0, clampf(edge[i] / AO_R, 0.0, 1.0))
				col = _lit(col, k, theme["light"], light * 0.25)
			img.set_pixel(x, y, col)

	var taken := PackedByteArray()
	taken.resize(w * h)
	var spots := _landmark_spots(cell, district, w, h)
	_open_themes.clear()
	for t in theme_names:
		_open_themes.append(bool(THEMES[t].get("open", false)))
	# пиксели объектов: туман и течение лавы их не накрывают (_glow_mask)
	var object_px := PackedByteArray()
	object_px.resize(w * h)
	_objects(img, cell, keep, taken, object_px, district, boxes, theme_names, w, h)
	_quantize(img)
	return [img, _glow_mask(img, cell, district, theme_names, object_px, w, h),
		_critter_info(cell, keep, taken, district, boxes, theme_names, spots, w, h)]


## Место под рельеф каждого района (паутина, могилы): самая «глубокая» точка
## пустот района (дальше всего от пола и скалы). Возвращает
## {номер города: [центр Vector2i, радиус в пикселях]}.
static var last_spots: Dictionary = {}
static func _landmark_spots(cell: PackedByteArray, district: PackedInt32Array, w: int, h: int) -> Dictionary:
	var inner := PackedFloat32Array()
	inner.resize(w * h)
	for i in w * h:
		inner[i] = 1e9 if cell[i] == Cell.HOLLOW else 0.0
	_chamfer(inner, PackedInt32Array(), w, h)
	var spots := {}
	for i in w * h:
		if cell[i] != Cell.HOLLOW:
			continue
		var d := district[i]
		if not spots.has(d) or inner[i] > float(spots[d][1]):
			spots[d] = [Vector2i(i % w, i / w), inner[i]]
	last_spots = spots
	return spots


## Пиксель скалы. Нижние CAVE_FACE рядов скалы над полом или пустотой — лицевая
## грань стены (текстура стены района того, что под ней; сверху светлый край,
## книзу темнее). Выше — верх скалы; его край у пола светлее. Край у внешней
## пустоты — тёмный контур.
static func _rock(cell: PackedByteArray, district: PackedInt32Array, themes: Array[Dictionary],
		w: int, h: int, x: int, y: int, light: float) -> Color:
	for k in range(1, CAVE_FACE + 1):
		var below := y + k
		if below >= h:
			break
		var under := cell[below * w + x]
		if under == Cell.ROCK:
			continue
		if under == Cell.OUTSIDE:
			break
		# (x, y) — ряд CAVE_FACE - k грани над полом/пустотой
		var theme: Dictionary = themes[district[below * w + x]]
		var row := CAVE_FACE - k
		var col := _mat_at(String(theme["wall"]), x, y * 2 + 7, Color("3a3448"))
		col = _shade(col, FACE_SHADE[row])
		return _lit(col, lerpf(0.75, 1.0, light), theme["light"], light * 0.2)
	if _is(cell, w, h, x - 1, y, Cell.OUTSIDE) or _is(cell, w, h, x + 1, y, Cell.OUTSIDE) \
			or _is(cell, w, h, x, y - 1, Cell.OUTSIDE) or _is(cell, w, h, x, y + 1, Cell.OUTSIDE):
		return OUTER_EDGE
	var lip := false
	for n in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
		var c := cell[clampi(y + n.y, 0, h - 1) * w + clampi(x + n.x, 0, w - 1)]
		if c == Cell.FLOOR or c == Cell.HOLLOW:
			lip = true
	return _shade(_mat_at("rock_top", x, y, Color("1e1a28")), ROCK_SHADE * (ROCK_LIP if lip else 1.0))


## Пустоты — не пол и не скала, не связанные с краем картинки; мелкие — в скалу.
static func _find_hollows(cell: PackedByteArray, w: int, h: int) -> void:
	# Сначала заливка снаружи от краёв картинки (seen = 1), потом остаток
	# OUTSIDE разбирается на пустоты. Стек — PackedInt32Array: так в разы
	# быстрее, чем Array с массивом соседей на каждый пиксель.
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack := PackedInt32Array()
	for x in w:
		for y in [0, h - 1]:
			_push_outside(cell, seen, stack, y * w + x)
	for y in h:
		for x in [0, w - 1]:
			_push_outside(cell, seen, stack, y * w + x)
	_flood(cell, seen, stack, w, h, PackedInt32Array(), false)
	for start in w * h:
		if cell[start] != Cell.OUTSIDE or seen[start] == 1:
			continue
		var region := PackedInt32Array()
		_push_outside(cell, seen, stack, start)
		_flood(cell, seen, stack, w, h, region, true)
		var fill := Cell.HOLLOW if region.size() >= MIN_HOLLOW else Cell.ROCK
		for i in region:
			cell[i] = fill


static func _push_outside(cell: PackedByteArray, seen: PackedByteArray, stack: PackedInt32Array, i: int) -> void:
	if cell[i] == Cell.OUTSIDE and seen[i] == 0:
		seen[i] = 1
		stack.append(i)


## Заливка по 4 соседям всего, что в стеке; при collect пиксели идут в region
## (упакованные массивы в Godot 4 передаются по ссылке).
static func _flood(cell: PackedByteArray, seen: PackedByteArray, stack: PackedInt32Array,
		w: int, h: int, region: PackedInt32Array, collect: bool) -> void:
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if collect:
			region.append(i)
		var x := i % w
		if x > 0:
			_push_outside(cell, seen, stack, i - 1)
		if x < w - 1:
			_push_outside(cell, seen, stack, i + 1)
		if i >= w:
			_push_outside(cell, seen, stack, i - w)
		if i < w * (h - 1):
			_push_outside(cell, seen, stack, i + w)


## Свет в пиксель-арте: четыре ступени с узором Байера 4x4 на переходах.
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
static func _dither(v: float, x: int, y: int) -> float:
	var steps := 4.0
	var t := (float(BAYER[(y % 4) * 4 + (x % 4)]) + 0.5) / 16.0
	return clampf(floorf(v * steps + t) / steps, 0.0, 1.0)


static func _lit(c: Color, k: float, tint: Color, amount: float) -> Color:
	var base := _shade(c, k)
	return Color(minf(base.r + tint.r * amount * 0.5, 1.0), minf(base.g + tint.g * amount * 0.5, 1.0),
		minf(base.b + tint.b * amount * 0.5, 1.0), 1.0)


# --- объекты PixelLab ------------------------------------------------------------

## Архитектура и природа районов — объекты PixelLab строго сверху, одной
## партиями в одном стиле (create_1_direction_object, view top-down, 64
## варианта на выбор; отобрано 2026-10-01), assets/board_objects. Размер
## объекта — размер его холста при генерации, без масштабирования: крупные
## сооружения 32 px, средние постройки 24, мелочь (грибы, кости, кристаллы) 16.
## Ставятся уже на построенную карту («дорисовываются к готовой»): главное
## сооружение (main) — как можно ближе к коробке своего города, чтобы было
## видно, чьё оно; остальное (extra) — на свободных местах его района.
## Объект встаёт только туда, где не задевает дорожки, кольца, коробки и
## другие объекты (_fits); в лаву, воду и пропасть (open) — только extra
## своей же темы лавы. В конце всё сводится к палитре пещеры (_quantize).
const OBJECT_DIR := "res://assets/board_objects/"
const OBJECTS := {
	"temple": {"main": ["ziggurat"], "extra": ["shrine", "altar", "brazier"]},
	"drow": {"main": ["drow_spire", "drow_palace", "stalactite_home", "lolth_temple", "mushroom_farm", "drow_watchtower"],
		"extra": ["drow_house", "market_stall", "drow_shrine", "priestess_statue", "obelisk", "faerie_lantern",
			"rothe_pen", "crystal_formation", "crystal"]},
	"hall": {"main": ["dome", "great_hall"], "extra": ["stone_house", "statue"]},
	"gate": {"main": ["gatehouse"], "extra": ["arch", "portcullis", "brazier"]},
	"necro": {"main": ["crypt"], "extra": ["grave_slab", "menhir", "statue"]},
	"ruins": {"main": ["ruined_tower", "collapse"], "extra": ["small_ruin", "fallen_column", "rubble"]},
	"lava": {"main": ["forge"], "extra": ["lava_crack", "brazier"]},
	"fungus": {"main": ["mushroom_grove"], "extra": ["teal_mushrooms", "red_mushroom"]},
	"web": {"main": ["spider_lair", "web_tower", "web_stalagmites", "web_pit", "cocoon_cluster", "web", "spider_nest",
		"drider_statue"], "extra": ["egg_sacs", "large_cocoon", "web_bones", "web_pillar", "giant_spider"]},
	"desert": {"main": ["dragon_skull"], "extra": ["bones", "stalagmites"]},
	"mist": {"main": ["stone_circle", "glow_well"], "extra": ["wisp", "menhir"]},
}
const MAIN_REACH := 26        # главное сооружение — не дальше этого от коробки
const EXTRA_REACH := 44       # остальное — в этом радиусе от коробки
const EXTRAS_PER_CITY := 2
## Каждый объект на доске — не больше стольких раз (решение владельца,
## 2026-10-01): иначе доска выглядит собранной из штампов.
const MAX_SAME := 1
static var _object_cache: Dictionary = {}


static func _object(object_name: String) -> Variant:
	if not _object_cache.has(object_name):
		var out: Variant = null
		var loaded: Variant = SchematicPainter.load_image(OBJECT_DIR + object_name + ".png")
		if loaded != null:
			var img: Image = loaded
			var used := img.get_used_rect()
			if used.has_area():
				out = img.get_region(used)
		_object_cache[object_name] = out
	return _object_cache[object_name]


static func _objects(img: Image, cell: PackedByteArray, keep: PackedByteArray, taken: PackedByteArray,
		object_px: PackedByteArray,
		district: PackedInt32Array, boxes: Array[Rect2i], theme_names: Array[String], w: int, h: int) -> void:
	var used := {}	# имя объекта -> сколько уже стоит
	# сначала главные сооружения всех городов — им нужнее место у коробки
	for d in boxes.size():
		var set: Dictionary = OBJECTS.get(theme_names[d], {})
		var names: Array = set.get("main", [])
		if names.is_empty():
			continue
		var hsh := absi(hash(boxes[d].position))
		for k in names.size():
			var object_name := String(names[(hsh + k) % names.size()])
			if int(used.get(object_name, 0)) >= MAX_SAME:
				continue
			var sprite: Variant = _object(object_name)
			if sprite != null and _place_near(img, sprite, boxes[d], MAIN_REACH, cell, keep, taken, object_px, district, d, false, w, h):
				used[object_name] = int(used.get(object_name, 0)) + 1
				break
	for d in boxes.size():
		var set: Dictionary = OBJECTS.get(theme_names[d], {})
		var names: Array = (set.get("extra", []) as Array).duplicate()
		var hsh := absi(hash(boxes[d].end))
		var placed := 0
		for k in names.size():
			if placed >= EXTRAS_PER_CITY:
				break
			var object_name := String(names[(hsh + k) % names.size()])
			if int(used.get(object_name, 0)) >= MAX_SAME:
				continue
			var sprite: Variant = _object(object_name)
			if sprite != null and _place_near(img, sprite, boxes[d], EXTRA_REACH, cell, keep, taken, object_px, district, d,
					theme_names[d] == "lava", w, h):
				used[object_name] = int(used.get(object_name, 0)) + 1
				placed += 1


## Ставит спрайт как можно ближе к коробке: кандидаты по кольцам вокруг неё,
## ближние первыми; верхний левый угол подбирается так, чтобы спрайт уходил от
## коробки наружу. Центр спрайта должен быть в районе своего города (district),
## в «открытую» пустоту (лава, вода, пропасть) — только если allow_open.
static func _place_near(img: Image, s: Image, box: Rect2i, reach: int, cell: PackedByteArray,
		keep: PackedByteArray, taken: PackedByteArray, object_px: PackedByteArray, district: PackedInt32Array, owner: int,
		allow_open: bool, w: int, h: int) -> bool:
	var centre := box.get_center()
	for r in range(3, reach + 1, 2):
		var ring := box.grow(r)
		var candidates: Array[Vector2i] = []
		for x in range(ring.position.x, ring.end.x + 1, 2):
			candidates.append(Vector2i(x, ring.position.y))
			candidates.append(Vector2i(x, ring.end.y))
		for y in range(ring.position.y, ring.end.y + 1, 2):
			candidates.append(Vector2i(ring.position.x, y))
			candidates.append(Vector2i(ring.end.x, y))
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return (a - centre).length_squared() < (b - centre).length_squared())
		for p in candidates:
			var at := p - s.get_size() / 2
			if p.x <= ring.position.x:
				at.x = p.x - s.get_width() + 1
			elif p.x >= ring.end.x:
				at.x = p.x
			if p.y <= ring.position.y:
				at.y = p.y - s.get_height() + 1
			elif p.y >= ring.end.y:
				at.y = p.y
			var mid := at + s.get_size() / 2
			if mid.x < 0 or mid.y < 0 or mid.x >= w or mid.y >= h or district[mid.y * w + mid.x] != owner:
				continue
			if not allow_open and cell[mid.y * w + mid.x] == Cell.HOLLOW and _open_at(mid, district, w):
				continue
			if _fits(s, at, cell, keep, taken, w, h):
				_blit_shadowed(img, s, at, cell, keep, w, h)
				for sy in s.get_height():
					for sx in s.get_width():
						if s.get_pixel(sx, sy).a >= 0.5:
							object_px[(at.y + sy) * w + at.x + sx] = 1
				_mark(taken, w, h, Rect2i(at, s.get_size()).grow(PROP_GAP))
				return true
	return false


## Пустота «открытая» (лава, вода, пропасть) — по теме района в этой точке.
static var _open_themes: Array[bool] = []
static func _open_at(p: Vector2i, district: PackedInt32Array, w: int) -> bool:
	var d := district[p.y * w + p.x]
	return d < _open_themes.size() and _open_themes[d]


## Спрайт с мягкой тенью вправо-вниз (тень — до спрайта, на пол и пустоту).
static func _blit_shadowed(img: Image, s: Image, at: Vector2i, cell: PackedByteArray, keep: PackedByteArray, w: int, h: int) -> void:
	for sy in s.get_height():
		for sx in s.get_width():
			if s.get_pixel(sx, sy).a < 0.5:
				continue
			var px := at.x + sx + 1
			var py := at.y + sy + 2
			if px < w and py < h and cell[py * w + px] != Cell.OUTSIDE and keep[py * w + px] == 0:
				img.set_pixel(px, py, _shade(img.get_pixel(px, py), 0.6))
	for sy in s.get_height():
		for sx in s.get_width():
			var p := s.get_pixel(sx, sy)
			if p.a >= 0.5:
				img.set_pixel(at.x + sx, at.y + sy, img.get_pixel(at.x + sx, at.y + sy).blend(p))


static func _fits(s: Image, at: Vector2i, cell: PackedByteArray, keep: PackedByteArray,
		taken: PackedByteArray, w: int, h: int) -> bool:
	for sy in s.get_height():
		for sx in s.get_width():
			if s.get_pixel(sx, sy).a < 0.5:
				continue
			var px := at.x + sx
			var py := at.y + sy
			if px < 0 or py < 0 or px >= w or py >= h:
				return false
			var i := py * w + px
			if keep[i] == 1 or taken[i] == 1:
				return false
			if cell[i] != Cell.HOLLOW and cell[i] != Cell.FLOOR and cell[i] != Cell.ROCK:
				return false
	return true


# --- палитра ------------------------------------------------------------------

## Общая палитра пещеры: всё, что нарисовано (текстуры PixelLab из разных
## генераций, предметы, свет), в конце сводится к этим цветам — ближайший по
## «redmean». Иначе каждая текстура приносит свою гамму и выходит коллаж.
## У всех тёмных одна фиолетовая база, как у интерфейса.
const PALETTE := [
	"07060c", "100d18", "1a1628", "26203a", "352d4e", "484066", "625a84", "857ea6", "b0a8cc", "dcd6ee",
	"2a0e0c", "5a1c10", "9a3414", "d8641c", "f8a030", "fff0a0",
	"0c2024", "163c40", "24666a", "3ea0a0", "7ce0d8",
	"24103c", "42206a", "6e34a8", "a060e8", "d0a0ff",
	"10200e", "22401c", "3e6e2c", "7aae4a",
	"280a10", "541420", "8a2430", "c8404a",
	"3e342c", "6a5c4c", "9c8c74", "d0c4a4",
	"2e2c36", "4a4854", "74727e", "a4a2ae", "cecdd6",
	"1c2a48", "3a5c94", "80b0e8",
]
static var _palette: Array[Color] = []


static func _quantize(img: Image) -> void:
	if _palette.is_empty():
		for hex: String in PALETTE:
			_palette.append(Color(hex))
	var cache := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var key := c.to_rgba32()
			if not cache.has(key):
				var best := _palette[0]
				var best_d := INF
				for p in _palette:
					var rm := (c.r + p.r) * 0.5
					var dr := c.r - p.r
					var dg := c.g - p.g
					var db := c.b - p.b
					var dd := (2.0 + rm) * dr * dr + 4.0 * dg * dg + (3.0 - rm) * db * db
					if dd < best_d:
						best_d = dd
						best = p
				cache[key] = Color(best, c.a)
			img.set_pixel(x, y, cache[key])


# --- общее --------------------------------------------------------------------

static func _mat_at(mat_name: String, x: int, y: int, fallback: Color) -> Color:
	if not _mat_cache.has(mat_name):
		var path := MAT_DIR + mat_name + ".png"
		var image: Variant = SchematicPainter.load_image(path)
		_mat_cache[mat_name] = image
	var tex: Variant = _mat_cache[mat_name]
	if tex == null:
		return fallback
	var t := tex as Image
	var c := t.get_pixel(posmod(x, t.get_width()), posmod(y, t.get_height()))
	c.a = 1.0
	return c


static func _shade(c: Color, k: float) -> Color:
	return Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0), c.a)


static func _is(cell: PackedByteArray, w: int, h: int, x: int, y: int, kind: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and cell[y * w + x] == kind


static func _mark(mask: PackedByteArray, w: int, h: int, r: Rect2i) -> void:
	for y in range(maxi(r.position.y, 0), mini(r.end.y, h)):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, w)):
			mask[y * w + x] = 1


static func _seed_rect(dist: PackedFloat32Array, w: int, h: int, r: Rect2i, value: float) -> void:
	for y in range(maxi(r.position.y, 0), mini(r.end.y, h)):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, w)):
			dist[y * w + x] = minf(dist[y * w + x], value)


## Ось тоннеля: затравка 0 в карте расстояний, дорожка (3 px + зазор) — в keep.
static func _seed_line(dist: PackedFloat32Array, keep: PackedByteArray, w: int, h: int, a: Vector2, b: Vector2) -> void:
	var from := Vector2i(a.round())
	var to := Vector2i(b.round())
	var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
	for i in steps + 1:
		var t := 0.0 if steps == 0 else float(i) / steps
		var p := Vector2i((Vector2(from) + Vector2(to - from) * t).round())
		_seed_rect(dist, w, h, Rect2i(p, Vector2i.ONE), 0.0)
		_mark(keep, w, h, Rect2i(p - Vector2i(2, 2), Vector2i(5, 5)))


## Карта расстояний двумя проходами (шаги 1 и sqrt2). Если label не пуст,
## вместе с расстоянием переносится метка ближайшей затравки.
static func _chamfer(dist: PackedFloat32Array, label: PackedInt32Array, w: int, h: int) -> void:
	const D := 1.41421356
	var labelled := not label.is_empty()
	for pass_index in 2:
		var forward := pass_index == 0
		var ys := range(h) if forward else range(h - 1, -1, -1)
		var xs := range(w) if forward else range(w - 1, -1, -1)
		var s := 1 if forward else -1
		for y: int in ys:
			for x: int in xs:
				var i := y * w + x
				var v := dist[i]
				var best := -1
				var nx := x - s
				var ny := y - s
				if nx >= 0 and nx < w and dist[y * w + nx] + 1.0 < v:
					v = dist[y * w + nx] + 1.0
					best = y * w + nx
				if ny >= 0 and ny < h:
					if dist[ny * w + x] + 1.0 < v:
						v = dist[ny * w + x] + 1.0
						best = ny * w + x
					if nx >= 0 and nx < w and dist[ny * w + nx] + D < v:
						v = dist[ny * w + nx] + D
						best = ny * w + nx
					var fx := x + s
					if fx >= 0 and fx < w and dist[ny * w + fx] + D < v:
						v = dist[ny * w + fx] + D
						best = ny * w + fx
				if best >= 0:
					dist[i] = v
					if labelled:
						label[i] = label[best]


# --- свечение (маска для шейдера) ----------------------------------------------

## Цикл палитры, как в старых пиксельных играх: что светится, видно по цвету
## пикселя после _quantize — тёплые яркие цвета (лава, огонь, факелы) пульсируют,
## холодные яркие (кристаллы, руны, огоньки) мерцают; пустоты туманных районов
## — под плывущим туманом.
const GLOW_FIRE := {"9a3414": 0.35, "d8641c": 0.65, "f8a030": 1.0, "fff0a0": 1.0}
const GLOW_SPARK := {"a060e8": 0.7, "d0a0ff": 1.0, "3ea0a0": 0.6, "7ce0d8": 1.0, "80b0e8": 1.0}


static func _glow_mask(img: Image, cell: PackedByteArray, district: PackedInt32Array,
		theme_names: Array[String], object_px: PackedByteArray, w: int, h: int) -> Image:
	var fire := {}
	for hex: String in GLOW_FIRE:
		fire[Color(hex).to_rgba32() | 0xff] = GLOW_FIRE[hex]
	var spark := {}
	for hex: String in GLOW_SPARK:
		spark[Color(hex).to_rgba32() | 0xff] = GLOW_SPARK[hex]
	var mask := Image.create(w, h, false, Image.FORMAT_RGBA8)
	mask.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var i := y * w + x
			if cell[i] == Cell.OUTSIDE:
				continue
			var c := img.get_pixel(x, y)
			var key := Color(c, 1.0).to_rgba32()
			var fog := 0.0
			var on_object := object_px[i] == 1
			if theme_names[district[i]] == "mist" and not on_object:
				fog = 1.0 if cell[i] == Cell.HOLLOW else (0.4 if cell[i] == Cell.FLOOR else 0.0)
			# лавовое озеро течёт целиком (A = 0.5 — метка «течёт» для шейдера)
			if theme_names[district[i]] == "lava" and cell[i] == Cell.HOLLOW and not on_object:
				mask.set_pixel(x, y, Color(1.0, 0.0, 0.0, 0.5))
				continue
			mask.set_pixel(x, y, Color(float(fire.get(key, 0.0)), fog, float(spark.get(key, 0.0)), 1.0))
	return mask


# --- живность (CaveCritters) ----------------------------------------------------

## Для CaveCritters: где можно ходить и где живут пауки. Координаты — пиксели
## картинки пещеры (со сдвигом CAVE_MARGIN от схемы).
##   "walk": PackedByteArray w*h — 1, где пещера (пол, скала, пустота), кроме
##            дорожек, колец и коробок (keep) и рельефа/предметов (taken);
##   "w", "h"; "spider_homes": Array[Vector2] — пустоты паучьих районов и углы
##            залов паучьих мест и храма.
const SPIDER_THEMES := ["web", "temple"]


static func _critter_info(cell: PackedByteArray, keep: PackedByteArray, taken: PackedByteArray,
		district: PackedInt32Array, boxes: Array[Rect2i], theme_names: Array[String],
		spots: Dictionary, w: int, h: int) -> Dictionary:
	var walk := PackedByteArray()
	walk.resize(w * h)
	for i in w * h:
		walk[i] = 1 if cell[i] != Cell.OUTSIDE and keep[i] == 0 and taken[i] == 0 else 0
	var homes: Array[Vector2] = []
	for d in boxes.size():
		if not SPIDER_THEMES.has(theme_names[d]):
			continue
		if spots.has(d):
			homes.append(Vector2(spots[d][0]))
		var box := boxes[d].grow(int(ROOM_R) - 2)
		for corner in [box.position, Vector2i(box.end.x, box.position.y), Vector2i(box.position.x, box.end.y), box.end]:
			var c: Vector2i = corner
			if c.x >= 0 and c.y >= 0 and c.x < w and c.y < h and walk[c.y * w + c.x] == 1:
				homes.append(Vector2(c))
	return {"walk": walk, "w": w, "h": h, "spider_homes": homes}
