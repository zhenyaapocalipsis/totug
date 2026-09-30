class_name CaveCritters
extends Control

## Живность на пещере под доской (решение владельца, 2026-10-01):
##  - пауки (наземный слой, air = false, позади схемы): живут у паучьих мест и
##    храма Ллос, бегают рывками по пещере и замирают, иногда спускаются на
##    нити; никогда не ступают на дорожки, кольца, коробки и рельеф — карта
##    "walk" из CavePainter._critter_info;
##  - летучие мыши (воздух, air = true, над доской): время от времени стайка
##    пролетает через всю доску по дуге, машет крыльями, по полу бежит тень.
## Только украшение: ничего не знает о правилах, в сеть не уходит, у каждого
## игрока своя. Спрайты — попиксельно, цвета из CavePainter.PALETTE.
## Координаты — пиксели картинки пещеры; на экран — через BoardPanel.

const MARGIN := CavePainter.CAVE_MARGIN

const SPIDER_MAX := 12
const SPIDER_RANGE := 18.0      # дальше от дома не убегает
const SPIDER_SPEED := 30.0      # пикселей пещеры в секунду в рывке
const SPIDER_PAUSE := [0.4, 3.0]
const SPIDER_STEP_TIME := 0.07  # смена кадра лапок
const HANG_CHANCE := 0.12       # вместо рывка — спуск на нити
const HANG_DEPTH := 7.0
const HANG_TIME := 3.0

const BAT_SPEED := [45.0, 65.0]
const FLOCK_EVERY := [6.0, 14.0]
const FLOCK_SIZE := [3, 5]
const BAT_FLAP := 0.12
const BAT_SHADOW := Vector2(3, 12)
const SHADOW_COLOUR := Color(0.02, 0.01, 0.04, 0.45)
const THREAD_COLOUR := Color(0.86, 0.84, 0.92, 0.7)

const COLOURS := {
	"k": Color("07060c"), "L": Color("b0a8cc"), "r": Color("c8404a"),
	"b": Color("352d4e"), "m": Color("857ea6"),
}
## Паук смотрит вверх (голова сверху), при рисовании поворачивается на 90°
## по направлению бега. Красные глаза и «песочные часы» — пауки Ллос.
const SPIDER := [
	[".L...L.", "L.krk.L", ".LkkkL.", "L.kkk.L", ".kkkkk.", "LkkrkkL", ".kkkkk.", "..kkk.."],
	["L.....L", ".LkrkL.", "..kkk..", "LLkkkLL", ".kkkkk.", ".kkrkk.", "LkkkkkL", "..kkk.."],
]
const BAT := [
	["m.......m", "mm..b..mm", ".mbbbbbm.", "...bbb...", "....b...."],
	["....b....", "...bbb...", ".mbbbbbm.", "mm..b..mm", "m.......m"],
]

var panel: BoardPanel = null
var air := false

var _walk := PackedByteArray()
var _w := 0
var _h := 0
var _spiders: Array[Dictionary] = []
var _bats: Array[Dictionary] = []
var _next_flock := 3.0
var _rng := RandomNumberGenerator.new()
var _spider_tex: Array[ImageTexture] = []
var _bat_tex: Array[ImageTexture] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.randomize()
	for rows in SPIDER:
		_spider_tex.append(_texture(rows))
	for rows in BAT:
		_bat_tex.append(_texture(rows))


## info — третий элемент CavePainter.paint_layers (пусто — живности нет).
func setup(info: Dictionary) -> void:
	_spiders.clear()
	_bats.clear()
	_walk = info.get("walk", PackedByteArray())
	_w = int(info.get("w", 0))
	_h = int(info.get("h", 0))
	if air or _walk.is_empty():
		return
	var homes: Array = (info.get("spider_homes", []) as Array).duplicate()
	homes.shuffle()
	for home: Vector2 in homes.slice(0, SPIDER_MAX):
		_spiders.append({"pos": home, "home": home, "target": home, "state": "pause",
			"timer": _rng.randf_range(0.0, 2.0), "frame": 0, "frame_t": 0.0, "hang": 0.0, "facing": 0})


func _process(delta: float) -> void:
	if panel == null or not visible:
		return
	if air:
		_step_bats(delta)
	else:
		_step_spiders(delta)
	queue_redraw()


# --- пауки ------------------------------------------------------------------------

func _walkable(p: Vector2) -> bool:
	var q := Vector2i(p.round())
	return q.x >= 0 and q.y >= 0 and q.x < _w and q.y < _h and _walk[q.y * _w + q.x] == 1


func _step_spiders(delta: float) -> void:
	for s in _spiders:
		s["timer"] = float(s["timer"]) - delta
		match String(s["state"]):
			"pause":
				if float(s["timer"]) <= 0.0:
					_next_move(s)
			"run":
				var pos: Vector2 = s["pos"]
				var to: Vector2 = s["target"]
				var step := minf(SPIDER_SPEED * delta, pos.distance_to(to))
				var next := pos + (to - pos).normalized() * step if step > 0.0 else pos
				if not _walkable(next) or step <= 0.01:
					_pause(s)
				else:
					s["pos"] = next
					s["facing"] = _facing(to - pos)
					s["frame_t"] = float(s["frame_t"]) + delta
					if float(s["frame_t"]) >= SPIDER_STEP_TIME:
						s["frame_t"] = 0.0
						s["frame"] = 1 - int(s["frame"])
			"hang":
				# вниз и обратно вверх за HANG_TIME
				var t := 1.0 - float(s["timer"]) / HANG_TIME
				s["hang"] = sin(clampf(t, 0.0, 1.0) * PI) * HANG_DEPTH
				if float(s["timer"]) <= 0.0:
					s["hang"] = 0.0
					_pause(s)


func _pause(s: Dictionary) -> void:
	s["state"] = "pause"
	s["timer"] = _rng.randf_range(SPIDER_PAUSE[0], SPIDER_PAUSE[1])


func _next_move(s: Dictionary) -> void:
	var pos: Vector2 = s["pos"]
	var home: Vector2 = s["home"]
	if _rng.randf() < HANG_CHANCE and _walkable(pos + Vector2(0, HANG_DEPTH)):
		s["state"] = "hang"
		s["timer"] = HANG_TIME
		return
	for attempt in 6:
		var to := pos + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(4.0, 12.0)
		if to.distance_to(home) > SPIDER_RANGE:
			to = pos + (home - pos).normalized() * _rng.randf_range(4.0, 10.0)
		if _walkable(to):
			s["target"] = to
			s["state"] = "run"
			return
	_pause(s)


# --- летучие мыши ----------------------------------------------------------------

func _step_bats(delta: float) -> void:
	_next_flock -= delta
	if _next_flock <= 0.0 and _w > 0:
		_next_flock = _rng.randf_range(FLOCK_EVERY[0], FLOCK_EVERY[1])
		_spawn_flock()
	for b in _bats:
		b["t"] = float(b["t"]) + delta
		var base: Vector2 = b["start"] + (b["velocity"] as Vector2) * float(b["t"])
		base.y += sin(float(b["t"]) * float(b["wobble"]) + float(b["phase"])) * 6.0
		b["pos"] = base + (b["offset"] as Vector2)
		b["frame"] = int(float(b["t"]) / BAT_FLAP + float(b["phase"])) % 2
	_bats = _bats.filter(func(b: Dictionary) -> bool:
		var p: Vector2 = b["pos"]
		return p.x > -40.0 and p.x < _w + 40.0 and p.y > -40.0 and p.y < _h + 40.0)


func _spawn_flock() -> void:
	var from_left := _rng.randf() < 0.5
	var start := Vector2(-30.0 if from_left else _w + 30.0, _rng.randf_range(0.15, 0.85) * _h)
	var speed := _rng.randf_range(BAT_SPEED[0], BAT_SPEED[1])
	var velocity := Vector2(speed if from_left else -speed, _rng.randf_range(-0.25, 0.25) * speed)
	for k in _rng.randi_range(FLOCK_SIZE[0], FLOCK_SIZE[1]):
		_bats.append({"start": start, "velocity": velocity, "t": 0.0,
			"offset": Vector2(-k * 9.0 * signf(velocity.x) + _rng.randf_range(-3, 3), _rng.randf_range(-10, 10)),
			"wobble": _rng.randf_range(2.0, 3.5), "phase": _rng.randf_range(0.0, 6.0),
			"pos": start, "frame": 0})


# --- рисование ---------------------------------------------------------------------

func _draw() -> void:
	if panel == null:
		return
	var zoom := panel._zoom
	if air:
		for b in _bats:
			var pos: Vector2 = b["pos"]
			var shadow := pos + BAT_SHADOW
			if _walkable(shadow):
				draw_rect(Rect2(_screen(shadow - Vector2(2, 0)), Vector2(5, 1) * zoom), SHADOW_COLOUR)
			_sprite(_bat_tex[int(b["frame"])], pos, zoom)
	else:
		for s in _spiders:
			var pos: Vector2 = s["pos"]
			var hang := float(s["hang"])
			if hang > 0.5:
				draw_rect(Rect2(_screen(pos + Vector2(0, -1)), Vector2(1, hang + 1) * zoom), THREAD_COLOUR)
			_sprite(_spider_tex[int(s["frame"])], pos + Vector2(0, hang), zoom, int(s["facing"]) if hang <= 0.5 else 0)


## Центр спрайта — в пикселе p пещеры; позиция округляется до пикселя пещеры,
## чтобы спрайт не «плыл» между пикселями доски.
func _sprite(tex: ImageTexture, p: Vector2, zoom: float, quarter_turns: int = 0) -> void:
	var size := Vector2(tex.get_size())
	var centre := _screen(Vector2(p.round()))
	# поворот ровно на 90° — пиксели остаются квадратными
	draw_set_transform(centre, quarter_turns * PI / 2.0)
	draw_texture_rect(tex, Rect2(-(size / 2.0).floor() * zoom, size * zoom), false)
	draw_set_transform(Vector2.ZERO)


func _screen(cave_px: Vector2) -> Vector2:
	return panel.local_of_world(cave_px - Vector2(MARGIN, MARGIN))


static func _texture(rows: Array) -> ImageTexture:
	var img := Image.create(String(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			if COLOURS.has(row[x]):
				img.set_pixel(x, y, COLOURS[row[x]])
	return ImageTexture.create_from_image(img)


## Направление бега -> четверть оборота (0 — вверх, 1 — вправо, 2 — вниз, 3 — влево).
static func _facing(d: Vector2) -> int:
	if absf(d.x) > absf(d.y):
		return 1 if d.x > 0.0 else 3
	return 2 if d.y > 0.0 else 0
