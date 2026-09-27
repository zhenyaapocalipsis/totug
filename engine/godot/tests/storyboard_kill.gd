extends SceneTree

## Раскадровка вариантов анимации убийства для владельца (2026-09-28):
## B — разрез (assassinate), C1 — перекраска и C2 — омут (supplant). Снимает настоящую доску
## с пустым местом и рисует поверх по пикселям, в масштабе игры (1 пиксель
## схемы = 1 пиксель кадра), затем увеличивает в SCALE раз.
##
##   godot --path . --script res://tests/storyboard_kill.gd -- --out=<папка>
##
## Кадры сохраняются как B_1.png ... C2_8.png; подписи — в frames.txt.

const SCALE := 5
const CROP := Vector2i(80, 52)
const GLOW := Color(1.0, 0.55, 0.15)
const SKULL := [
	".###.",
	"#####",
	"#.#.#",
	"#####",
	".#.#.",
]

var _screen: GameScreen
var _frame := 0
var _slot := ""
var _out := "C:/tyrants of the underdark godot/Claude outputs/storyboard"
var _captions: Array[String] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
	DisplayServer.window_set_size(Vector2i(960, 540))
	_screen = GameScreen.new(7, [], GameScreen.player_ids_for(2))
	root.add_child(_screen)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 40:
		# Место с нейтральным войском в локации — там и «убиваем». На снимке
		# оно пустое: фишки рисуем сами.
		var state := _screen.server.state
		for site_id: String in state.graph.sites.keys():
			var slots: Array = state.graph.slots_of_site(site_id)
			if slots.size() >= 3 and String(state.troops.get(String(slots[0]), "")) == GameState.WHITE:
				_slot = String(slots[0])
				state.troops[_slot] = ""
				break
		_screen._turn_banner.hide()
		_screen.refresh(StateView.for_player_with_pending(
			state, _screen.viewer_id, _screen.server.resolver.pending))
	if _frame < 60:
		return false
	var shot: Image = root.get_texture().get_image()
	# Окно может оказаться крупнее расчётного экрана — снимок к 960x540, в
	# этих координатах и живёт доска.
	if shot.get_size() != Vector2i(960, 540):
		shot.resize(960, 540, Image.INTERPOLATE_NEAREST)
	var at: Vector2 = _screen._board_panel.slot_global(_slot)
	var origin := Vector2i((at - Vector2(CROP) * 0.5).round())
	var bg := shot.get_region(Rect2i(origin, CROP))
	var c := Vector2i((at - Vector2(origin)).floor())
	DirAccess.make_dir_recursive_absolute(_out)
	var me := _screen.viewer_id
	var foe := ""
	for pid in _screen.server.state.turn_order:
		if pid != me:
			foe = pid
	var mine := SchematicPainter.token(BoardPanel.troop_colour(me), PlayerProfile.emblem_of(me))
	var theirs := SchematicPainter.token(BoardPanel.troop_colour(foe), PlayerProfile.emblem_of(foe))
	_slash_frames(bg, c, theirs, BoardPanel.troop_colour(foe))
	_fill_frames(bg, c, mine, theirs, BoardPanel.troop_colour(me), BoardPanel.troop_colour(foe))
	_pool_frames(bg, c, mine, theirs, BoardPanel.troop_colour(me))
	var f := FileAccess.open(_out + "/frames.txt", FileAccess.WRITE)
	f.store_string("\n".join(_captions))
	print("раскадровка: %s, место %s" % [_out, _slot])
	return true


# --- B: разрез ------------------------------------------------------------------

func _slash_frames(bg: Image, c: Vector2i, victim: Image, colour: Color) -> void:
	var shards := _shards(colour, 11)
	# [время, подпись]
	var frames := [
		[0.00, "0.00 target marked"], [0.10, "0.10 turns red"],
		[0.16, "0.16 flash, crack"], [0.20, "0.20 cracks open"],
		[0.26, "0.26 cut in two"], [0.34, "0.34 halves fall, skull"],
		[0.46, "0.46"], [0.60, "0.60 empty slot"]]
	for i in frames.size():
		var t: float = frames[i][0]
		var im := bg.duplicate() as Image
		match i:
			0:
				_stamp(im, victim, c, Color(0, 0, 0, 0))
				_ring(im, c, 6.0, Color(1, 0.2, 0.15))
			1:
				_stamp(im, victim, c, Color(1, 0.15, 0.1, 0.55))
				_ring(im, c, 6.0, Color(1, 0.2, 0.15))
			2:
				_stamp(im, victim, c, Color(1, 1, 1, 0.6))
				_crack(im, victim, c)
			3:
				_stamp(im, victim, c, Color(0.08, 0.04, 0.06, 1.0))
				_half(im, victim, c, Vector2i(1, -1), true, 1.0)
				_half(im, victim, c, Vector2i(-1, 1), false, 1.0)
			4:
				_stamp(im, victim, c, Color(0.08, 0.04, 0.06, 1.0), 0.5)
				_half(im, victim, c, Vector2i(2, -2), true, 1.0)
				_half(im, victim, c, Vector2i(-2, 2), false, 1.0)
			5:
				_half(im, victim, c, Vector2i(4, -2), true, 0.9)
				_half(im, victim, c, Vector2i(-4, 4), false, 0.9)
				_skull(im, c + Vector2i(0, -10), 1.0)
			6:
				_half(im, victim, c, Vector2i(6, 3), true, 0.55)
				_half(im, victim, c, Vector2i(-6, 8), false, 0.55)
				_skull(im, c + Vector2i(0, -12), 1.0)
			7:
				_skull(im, c + Vector2i(0, -14), 0.35)
		if t >= 0.26:
			_draw_shards(im, c, shards, t - 0.22)
		_save(im, "B_%d" % (i + 1), "B%d %s" % [i + 1, frames[i][1]])


## Тёмная трещина «\» по самой фишке — только в её пределах.
func _crack(im: Image, token: Image, c: Vector2i) -> void:
	var h := token.get_width() / 2
	for i in range(-h, h + 1):
		if token.get_pixel(h + i, h + i).a > 0.0:
			_px(im, c.x + i, c.y + i, Color(0.08, 0.04, 0.06))


## Половина фишки по линии разреза: upper — верхняя правая.
func _half(im: Image, token: Image, c: Vector2i, off: Vector2i, upper: bool, alpha: float) -> void:
	var h := token.get_width() / 2
	for y in token.get_height():
		for x in token.get_width():
			var d := (x - h) - (y - h)
			if d == 0 or (d > 0) != upper:
				continue
			var p := token.get_pixel(x, y)
			if p.a > 0.0:
				_px(im, c.x - h + x + off.x, c.y - h + y + off.y, Color(p, p.a * alpha))


func _skull(im: Image, at: Vector2i, alpha: float) -> void:
	for y in SKULL.size():
		for x in (SKULL[y] as String).length():
			if SKULL[y][x] == "#":
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						_px(im, at.x - 2 + x + dx, at.y - 2 + y + dy, Color(0.05, 0.03, 0.08, 0.8 * alpha))
	for y in SKULL.size():
		for x in (SKULL[y] as String).length():
			if SKULL[y][x] == "#":
				_px(im, at.x - 2 + x, at.y - 2 + y, Color(0.95, 0.93, 0.85, alpha))


# --- C1: перекраска ----------------------------------------------------------------

## Цвет вытеснившего сверху вниз заливает чужую фишку; на границе — светлая
## кромка, эмблема меняется по мере прохода волны. Остатки старого цвета
## выдавливаются вверх искрами.
func _fill_frames(bg: Image, c: Vector2i, killer: Image, victim: Image,
		kcolour: Color, vcolour: Color) -> void:
	var frames := [
		[0.00, "0.00 ring of new colour"], [0.08, "0.08 colour pours in"],
		[0.16, "0.16"], [0.24, "0.24 almost taken"],
		[0.30, "0.30 flash, emblem swapped"], [0.36, "0.36 old colour squeezed out"],
		[0.48, "0.48"], [0.60, "0.60 settled"]]
	var drops := _rising(vcolour, 8)
	var ring := kcolour.lightened(0.35)
	for i in frames.size():
		var t: float = frames[i][0]
		var im := bg.duplicate() as Image
		match i:
			0:
				_stamp(im, victim, c, Color(0, 0, 0, 0))
				_ring(im, c, 6.0, ring)
			1:
				_fill(im, victim, killer, c, 2, kcolour)
				_ring(im, c, 6.0, ring)
			2:
				_fill(im, victim, killer, c, 4, kcolour)
				_ring(im, c, 6.0, ring)
			3:
				_fill(im, victim, killer, c, 7, kcolour)
				_ring(im, c, 6.0, ring)
			4:
				_stamp(im, killer, c, Color(1, 1, 1, 0.55))
				_ring(im, c, 7.0, ring)
			5:
				_stamp(im, killer, c, Color(0, 0, 0, 0))
				_ring(im, c, 9.0, Color(ring, 0.6))
			6:
				_stamp(im, killer, c, Color(0, 0, 0, 0))
				_ring(im, c, 12.0, Color(ring, 0.3))
			7:
				_stamp(im, killer, c, Color(0, 0, 0, 0))
		if t >= 0.36:
			_draw_rising(im, c, drops, t - 0.30)
		_save(im, "C1_%d" % (i + 1), "C1.%d %s" % [i + 1, frames[i][1]])


## Фишка: строки выше level — уже вытеснившего (с его эмблемой), строка
## level — светлая кромка, ниже — ещё старая. Тёмная обводка не трогается.
func _fill(im: Image, victim: Image, killer: Image, c: Vector2i, level: int, kcolour: Color) -> void:
	var h := victim.get_width() / 2
	for y in victim.get_height():
		for x in victim.get_width():
			var p := victim.get_pixel(x, y)
			if p.a <= 0.0:
				continue
			var k := killer.get_pixel(x, y)
			var col := p
			if y < level:
				col = k
			elif y == level and k.get_luminance() > 0.15:
				col = kcolour.lightened(0.6)
			_px(im, c.x - h + x, c.y - h + y, col)


## Искры старого цвета, выдавленные из фишки: летят вверх и в стороны.
func _rising(colour: Color, count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var list := []
	for i in count:
		var angle := lerpf(-2.6, -0.55, float(i) / (count - 1)) + rng.randf_range(-0.15, 0.15)
		list.append({"vel": Vector2(cos(angle), sin(angle)) * rng.randf_range(25.0, 45.0),
			"colour": colour})
	return list


func _draw_rising(im: Image, c: Vector2i, drops: Array, t: float) -> void:
	for s in drops:
		var dir: Vector2 = (s["vel"] as Vector2).normalized()
		var p: Vector2 = Vector2(c) + dir * 5.0 + (s["vel"] as Vector2) * t + Vector2(0, 40.0 * t * t)
		var a := clampf(1.0 - t / 0.35, 0.0, 1.0)
		_px(im, int(p.x), int(p.y), Color((s["colour"] as Color).lightened(0.15), a))
		if t < 0.1:
			_px(im, int(p.x) + 1, int(p.y), Color((s["colour"] as Color).lightened(0.15), a))


# --- C2: омут ---------------------------------------------------------------------

## Под фишкой растекается лужа тени, старая фишка проваливается в неё, из
## той же лужи всплывает новая, лужа стягивается.
func _pool_frames(bg: Image, c: Vector2i, killer: Image, victim: Image, kcolour: Color) -> void:
	# [время, подпись, ширина лужи, на сколько утонула старая (-1 — нет её),
	#  на сколько ещё под водой новая (-1 — нет её)]
	var frames := [
		[0.00, "0.00 shadow pool spreads", 4, 0, -1],
		[0.08, "0.08 old troop sinks", 7, 3, -1],
		[0.16, "0.16", 8, 6, -1],
		[0.24, "0.24 swallowed", 8, -1, -1],
		[0.32, "0.32 new troop rises", 8, -1, 6],
		[0.40, "0.40", 7, -1, 3],
		[0.48, "0.48 out, pool shrinks", 4, -1, 0],
		[0.60, "0.60 settled", 0, -1, 0]]
	var ring := kcolour.lightened(0.35)
	for i in frames.size():
		var im := bg.duplicate() as Image
		var rx: int = frames[i][2]
		var sunk: int = frames[i][3]
		var rising: int = frames[i][4]
		if rx > 0:
			_pool(im, c, rx)
		if sunk >= 0:
			_sunk(im, victim, c, sunk)
		if rising >= 0:
			_sunk(im, killer, c, rising)
		if i == 3:
			_px(im, c.x - 2, c.y + 2, Color(0.45, 0.2, 0.6))
			_px(im, c.x + 3, c.y + 1, Color(0.45, 0.2, 0.6))
			_px(im, c.x, c.y - 1, Color(0.45, 0.2, 0.6, 0.6))
		if i == 6:
			_ring(im, c, 7.0, ring)
		_save(im, "C2_%d" % (i + 1), "C2.%d %s" % [i + 1, frames[i][1]])


## Лужа тени шириной 2*rx+1, её середина — у низа фишки.
func _pool(im: Image, c: Vector2i, rx: int) -> void:
	var ry := maxf(1.0, rx / 2.5)
	var centre := Vector2(c.x, c.y + 4)
	for y in range(-4, 5):
		for x in range(-rx - 1, rx + 2):
			var d := Vector2(x / (rx + 0.5), y / (ry + 0.5)).length()
			if d <= 1.0:
				var rim := d > 0.7
				_px(im, int(centre.x) + x, int(centre.y) + y,
					Color(0.3, 0.12, 0.42, 0.9) if rim else Color(0.06, 0.02, 0.1, 0.92))


## Фишка, опущенная на sunk пикселей: всё, что ниже её обычного низа, —
## под водой и не рисуется.
func _sunk(im: Image, token: Image, c: Vector2i, sunk: int) -> void:
	var h := token.get_width() / 2
	for y in token.get_height():
		var sy := c.y - h + y + sunk
		if sy > c.y + h:
			continue
		for x in token.get_width():
			var p := token.get_pixel(x, y)
			if p.a > 0.0:
				_px(im, c.x - h + x, sy, p)


# --- общее --------------------------------------------------------------------

## Фишка с центром в c, подкрашенная tint (его альфа — сила подкраски).
func _stamp(im: Image, token: Image, c: Vector2i, tint: Color, alpha: float = 1.0) -> void:
	var h := token.get_width() / 2
	for y in token.get_height():
		for x in token.get_width():
			var p := token.get_pixel(x, y)
			if p.a <= 0.0:
				continue
			var col := p.lerp(Color(tint.r, tint.g, tint.b), tint.a)
			_px(im, c.x - h + x, c.y - h + y, Color(col, p.a * alpha))


func _ring(im: Image, c: Vector2i, r: float, colour: Color) -> void:
	var n := int(r) + 2
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			if absf(Vector2(x, y).length() - r) < 0.5:
				_px(im, c.x + x, c.y + y, colour)


func _shards(colour: Color, count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var list := []
	for i in count:
		var angle := TAU * i / count + rng.randf() * 0.5
		list.append({"vel": Vector2(cos(angle), sin(angle)) * rng.randf_range(30.0, 60.0),
			"colour": colour if i % 3 != 0 else GLOW})
	return list


func _draw_shards(im: Image, c: Vector2i, shards: Array, t: float) -> void:
	for s in shards:
		var p: Vector2 = Vector2(c) + (s["vel"] as Vector2) * t + Vector2(0, 150.0 * t * t)
		var a := clampf(1.0 - t / 0.45, 0.0, 1.0)
		var size := 2 if t < 0.15 else 1
		for dy in size:
			for dx in size:
				_px(im, int(p.x) + dx, int(p.y) + dy, Color((s["colour"] as Color).lightened(0.2), a))


func _px(im: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= im.get_width() or y >= im.get_height() or col.a <= 0.0:
		return
	im.set_pixel(x, y, im.get_pixel(x, y).blend(col))


func _save(im: Image, name: String, caption: String) -> void:
	im.resize(im.get_width() * SCALE, im.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	im.save_png("%s/%s.png" % [_out, name])
	_captions.append("%s|%s" % [name, caption])
