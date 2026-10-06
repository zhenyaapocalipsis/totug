extends SceneTree

## Макет: схема доски в изометрии (A) и в «наклонном столе» (B) рядом с плоской.
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path engine/godot --script res://tools/iso_preview.gd -- --players=4 --seed=3
## Output: Claude outputs/iso_<mode>_<players>p_seed<N>.png at x2.

const OUT := "C:/tyrants of the underdark godot/Claude outputs/"
const LIFT := 5                    # высота «плиты» локации, px
const TILT := 0.6                  # сжатие по вертикали для варианта B
const SIDE_L := Color("8f86a8")
const SIDE_R := Color("b6aecb")
const SIDE_DARK := Color("0d0b18")
const SEATS := [Color("d8433a"), Color("3f7fe0"), Color("4cb050"), Color("a05cd6")]

var iso := true
var ox := 0.0
var oy := 0.0


func _init() -> void:
	var players := 4
	var game_seed := 3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--players="):
			players = int(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="):
			game_seed = int(arg.get_slice("=", 1))
	var ids: Array[String] = []
	ids.assign(["red", "blue", "green", "purple"].slice(0, players))
	var sch := BoardSchematic.build(GameSetup.new_game(ids, game_seed))
	for mode in ["iso", "tilt"]:
		iso = mode == "iso"
		var img := _render(sch, players, game_seed)
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		var path := OUT + "iso_%s_%dp_seed%d.png" % [mode, players, game_seed]
		img.save_png(path)
		print("%s  %dx%d" % [path, img.get_width() / 2, img.get_height() / 2])
	quit()


func proj(u: float, v: float, z: float) -> Vector2:
	if iso:
		return Vector2(u - v + ox, (u + v) * 0.5 + oy - z)
	return Vector2(u + ox, v * TILT + oy - z)


func unproj(x: float, y: float, z: float) -> Vector2:
	if iso:
		var a := y - oy + z
		var b := (x - ox) * 0.5
		return Vector2(a + b, a - b)
	return Vector2(x - ox, (y - oy + z) / TILT)


func _render(sch: Dictionary, players: int, game_seed: int) -> Image:
	var w := int(sch["size"][0])
	var h := int(sch["size"][1])
	var ow: int
	var oh: int
	if iso:
		ox = h + 8
		oy = LIFT + 24
		ow = w + h + 16
		oh = (w + h) / 2 + LIFT + 32
	else:
		ox = 8
		oy = LIFT + 16
		ow = w + 16
		oh = int(h * TILT) + LIFT + 24
	var out := Image.create(ow, oh, false, Image.FORMAT_RGBA8)
	out.fill(SchematicPainter.BG)

	# 1. Пол: трассы и кольца без локаций, спроецированные на плоскость z=0.
	var floor_sch := sch.duplicate()
	floor_sch["sites"] = {}
	var floor_img := SchematicPainter.paint(floor_sch)
	_project_texture(out, floor_img, Vector2.ZERO, 0)

	var rng := RandomNumberGenerator.new()
	rng.seed = game_seed
	var pawns: Array = []   # [глубина, позиция на экране, цвет]
	for ring_id: String in (sch.get("rings", {}) as Dictionary).keys():
		if rng.randf() < 0.3:
			var at: Array = sch["rings"][ring_id]
			pawns.append([_depth(at[0], at[1]), proj(at[0], at[1], 0), SEATS[rng.randi() % players]])

	# 2. Локации — плиты высотой LIFT, от дальних к ближним.
	var sites: Array = (sch.get("sites", {}) as Dictionary).values()
	sites.sort_custom(func(a, b): return _depth(a["rect"][0] + a["rect"][2], a["rect"][1] + a["rect"][3]) \
		< _depth(b["rect"][0] + b["rect"][2], b["rect"][1] + b["rect"][3]))
	var labels: Array = []
	for site: Dictionary in sites:
		var r: Array = site["rect"]
		var rect := Rect2(r[0], r[1], r[2], r[3])
		# сначала фишки на полу, что лежат дальше этой плиты
		var d := _depth(rect.end.x, rect.end.y)
		pawns.sort_custom(func(a, b): return a[0] < b[0])
		while not pawns.is_empty() and pawns[0][0] < d - 40:
			var p: Array = pawns.pop_front()
			_pawn(out, p[1], p[2])
		for z in LIFT:
			_fill_slab(out, rect, z)
		var top := Image.create(int(rect.size.x), int(rect.size.y), false, Image.FORMAT_RGBA8)
		var local := site.duplicate(true)
		local["rect"] = [0, 0, r[2], r[3]]
		for slot_id: String in (local["slots"] as Dictionary).keys():
			var at: Array = local["slots"][slot_id]
			local["slots"][slot_id] = [at[0] - r[0], at[1] - r[1]]
		SchematicPainter._site(top, local)
		if true:
			# надпись на скошенной крыше не читается — стираем, подпись поставим табличкой
			top.fill_rect(Rect2i(1, 1, top.get_width() - 2, PixelFont.HEIGHT + 3),
				SchematicPainter.BOX_DARK if site.get("starting", false) else SchematicPainter.BOX_LIGHT)
		_project_texture(out, top, rect.position, LIFT)
		for slot_id: String in (site["slots"] as Dictionary).keys():
			if rng.randf() < 0.45:
				var at: Array = site["slots"][slot_id]
				_pawn(out, proj(at[0], at[1], LIFT), SEATS[rng.randi() % players])
		if true:
			labels.append([proj(rect.position.x + rect.size.x / 2, rect.position.y, LIFT), site])
	for p: Array in pawns:
		_pawn(out, p[1], p[2])

	# 3. Таблички с названиями — поверх всего, стоят прямо.
	for l: Array in labels:
		var text := BoardSchematic.short_name(String(l[1]["name"])) + " " + str(l[1]["vp"])
		var tw := PixelFont.text_width(text)
		var at: Vector2 = l[0]
		var x := int(at.x) - tw / 2
		var y := int(at.y) - PixelFont.HEIGHT - 6
		out.fill_rect(Rect2i(x - 2, y - 2, tw + 4, PixelFont.HEIGHT + 4), SchematicPainter.INK)
		out.fill_rect(Rect2i(x - 1, y - 1, tw + 2, PixelFont.HEIGHT + 2), SchematicPainter.BOX_DARK)
		PixelFont.draw_text(out, x, y, text, SchematicPainter.BOX_LIGHT)
	return out


func _depth(u: float, v: float) -> float:
	return u + v if iso else v * 2.0


## Перенос картинки, лежащей в плоскости высоты z, на экран (обратное отображение, nearest).
func _project_texture(out: Image, tex: Image, at: Vector2, z: int) -> void:
	var bb := _bbox(Rect2(at, tex.get_size()), z, out)
	for y in range(bb.position.y, bb.end.y):
		for x in range(bb.position.x, bb.end.x):
			var uv := unproj(x + 0.5, y + 0.5, z) - at
			var tx := int(floor(uv.x))
			var ty := int(floor(uv.y))
			if tx < 0 or ty < 0 or tx >= tex.get_width() or ty >= tex.get_height():
				continue
			var c := tex.get_pixel(tx, ty)
			if c.a > 0.0:
				out.set_pixel(x, y, c)


## Один слой боковины плиты на высоте z: две грани разного тона.
func _fill_slab(out: Image, rect: Rect2, z: int) -> void:
	var bb := _bbox(rect, z, out)
	for y in range(bb.position.y, bb.end.y):
		for x in range(bb.position.x, bb.end.x):
			var uv := unproj(x + 0.5, y + 0.5, z)
			if not rect.has_point(uv):
				continue
			var c := SIDE_L
			if iso and rect.end.x - uv.x < rect.end.y - uv.y:
				c = SIDE_R
			if z == 0:
				c = SIDE_DARK
			out.set_pixel(x, y, c)


func _bbox(rect: Rect2, z: int, out: Image) -> Rect2i:
	var pts := [proj(rect.position.x, rect.position.y, z), proj(rect.end.x, rect.position.y, z),
		proj(rect.position.x, rect.end.y, z), proj(rect.end.x, rect.end.y, z)]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Vector2 in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var r := Rect2i(Vector2i(lo.floor()) - Vector2i.ONE, Vector2i((hi - lo).ceil()) + Vector2i(3, 3))
	return r.intersection(Rect2i(Vector2i.ZERO, out.get_size()))


## Фигурка войска стоит прямо: основание в точке at.
const PAWN := [
	"..###..",
	".#ooo#.",
	".#ooo#.",
	"..#o#..",
	".#ooo#.",
	"#ooooo#",
	"#ooooo#",
	".#####.",
]

func _pawn(out: Image, at: Vector2, colour: Color) -> void:
	var x0 := int(at.x) - 3
	var y0 := int(at.y) - PAWN.size() + 1
	for j in PAWN.size():
		var row: String = PAWN[j]
		for i in row.length():
			var ch := row[i]
			if ch == ".":
				continue
			var c := Color(0.04, 0.03, 0.06) if ch == "#" else colour
			if ch == "o" and i <= 2 and j < 4:
				c = colour.lightened(0.35)
			var px := x0 + i
			var py := y0 + j
			if px >= 0 and py >= 0 and px < out.get_width() and py < out.get_height():
				out.set_pixel(px, py, c)
