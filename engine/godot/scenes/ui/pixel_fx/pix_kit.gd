class_name PixKit
extends RefCounted

## Набор элементов эффектов, из которых собираются постановки уникальных карт
## (UniqueFx). Каждый элемент рисует один кадр по времени — без состояния, поэтому
## кадр всегда один и тот же (повтор, запись, пропуск кадров).
##
## Приёмы, взятые у художников:
## - glow: свечение ступенями — сплошное ядро и кольца с выпадающими пикселями
##   (Kirokaze: огни города, глаза роботов), а не размытие;
## - spark: искра-крестик в 4 луча (waneella: звёзды);
## - burst: удар — звезда острых шипов, белая с цветным краем, выедается изнутри
##   (Blasphemous: удар о пол, вспышка луча);
## - slash: серп удара — белое тело, один цветной край, «гребёнка» прядей на хвосте и
##   дыры растворения (Blasphemous: удар мечом);
## Огонь и дым здесь НЕ рисуются (кружки-частицы — не пиксель-арт): их рисует шейдер
## pix_fluid (UniqueFx.fluid) — языками и клубами, полосами палитры.

const TAU_F := TAU


## Детерминированное псевдослучайное 0..1 по номеру (одинаково в каждом кадре).
static func rnd(seed: int, i: int) -> float:
	var x := (seed * 374761393 + i * 668265263) & 0xffffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0xffffffff
	x = x ^ (x >> 16)
	return float(x & 0xffffff) / 16777216.0


static func rnd_range(seed: int, i: int, a: float, b: float) -> float:
	return lerpf(a, b, rnd(seed, i))


## Доля x внутри [a, b], обрезанная до 0..1.
static func span(x: float, a: float, b: float) -> float:
	return clampf((x - a) / (b - a), 0.0, 1.0)


static func ease_out(x: float, p: float = 2.0) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), p)


static func ease_in(x: float, p: float = 2.0) -> float:
	return pow(clampf(x, 0.0, 1.0), p)


## Свечение ступенями вокруг точки: сплошные кольца цветов ramp (от ядра наружу), узор
## Байера только на стыке колец (2 пикселя) — как у Kirokaze, а не полутоновый круг.
## strength 0..1 — общий размер.
static func glow(p: Pix, cx: float, cy: float, r: float, ramp: PackedColorArray, strength: float = 1.0) -> void:
	if strength <= 0.0 or r <= 0.0:
		return
	var n := ramp.size()
	for i in range(n - 1, -1, -1):
		var rr := r * strength * float(i + 1) / float(n)
		p.ring(cx, cy, maxf(rr - 2.0, 0.0), rr, ramp[i], 0.5)
		p.disc(cx, cy, rr - 2.0, ramp[i])


## Искра-крестик: центр core, лучи arm длиной size (у длинных — ещё точка на конце).
static func spark(p: Pix, x: int, y: int, size: int, core: Color, arm: Color) -> void:
	p.put(x, y, core)
	for d in range(1, size + 1):
		var c := core if d == 1 and size > 2 else arm
		p.put(x + d, y, c)
		p.put(x - d, y, c)
		p.put(x, y + d, c)
		p.put(x, y - d, c)
	if size >= 3:
		p.put(x + 1, y + 1, arm)
		p.put(x - 1, y - 1, arm)
		p.put(x + 1, y - 1, arm)
		p.put(x - 1, y + 1, arm)


## Угли/искры: count частиц из точки origin по направлению dir (разброс spread,
## радианы), скорость speed, ускорение acc (вверх — отрицательный y). t — время с
## вылета, life — жизнь. Цвет по возрасту из ramp, у быстрых — хвост в 1 пиксель.
static func embers(p: Pix, seed: int, origin: Vector2, t: float, count: int, dir: float, spread: float,
		speed: float, acc: Vector2, life: float, ramp: PackedColorArray, area: float = 0.0) -> void:
	for i in count:
		var delay := rnd(seed, i * 7) * life * 0.35
		var tt := t - delay
		var l := life * rnd_range(seed, i * 7 + 1, 0.6, 1.0)
		if tt < 0.0 or tt > l:
			continue
		var a := dir + (rnd(seed, i * 7 + 2) - 0.5) * spread
		var v := Vector2(cos(a), sin(a)) * speed * rnd_range(seed, i * 7 + 3, 0.45, 1.0)
		var o := origin + Vector2(rnd(seed, i * 7 + 4) - 0.5, rnd(seed, i * 7 + 5) - 0.5) * area
		# лёгкое трепыхание поперёк пути
		var wob := sin(tt * 9.0 + rnd(seed, i * 7 + 6) * TAU_F) * 3.0 * tt
		var pos := o + v * tt + acc * tt * tt * 0.5 + Vector2(-v.y, v.x).normalized() * wob
		var age := tt / l
		var c := PixPal.at(ramp, age)
		var x := floori(pos.x)
		var y := floori(pos.y)
		p.put(x, y, c)
		var vel := v + acc * tt
		if vel.length() > 120.0 and age < 0.6:
			var back := (pos - vel.normalized() * 1.5).floor()
			p.put(int(back.x), int(back.y), PixPal.at(ramp, minf(age + 0.3, 1.0)))
		elif age < 0.25 and i % 4 == 0:
			spark(p, x, y, 1, ramp[0], ramp[mini(1, ramp.size() - 1)])


## Удар: звезда из spikes острых шипов, растёт и выедается изнутри (t 0..1).
static func burst(p: Pix, seed: int, cx: float, cy: float, r: float, t: float, spikes: int,
		core: Color, edge: Color) -> void:
	if t < 0.0 or t >= 1.0:
		return
	var outer := r * ease_out(t * 1.6, 2.0)
	var inner := r * ease_in(span(t, 0.25, 1.0), 1.5)
	var pts := PackedVector2Array()
	for i in spikes * 2:
		var a := float(i) / float(spikes * 2) * TAU_F + rnd(seed, i) * 0.25
		var rr := outer if i % 2 == 0 else outer * 0.38
		if i % 2 == 0:
			rr *= rnd_range(seed, 100 + i, 0.6, 1.0)
		pts.append(Vector2(cx + cos(a) * rr, cy + sin(a) * rr))
	var k := span(t, 0.55, 1.0)
	p.poly(pts, edge, k)
	var pts2 := PackedVector2Array()
	for q in pts:
		pts2.append(Vector2(cx, cy) + (q - Vector2(cx, cy)) * 0.7)
	p.poly(pts2, core, k)
	if inner > 0.5:
		p.disc(cx, cy, inner, Pix.NONE)


## Ударная волна: кольцо растёт до r, тончает и рассыпается (t 0..1).
static func shock(p: Pix, cx: float, cy: float, r: float, t: float, c: Color, thick: float = 3.0,
		squash: float = 1.0) -> void:
	if t < 0.0 or t >= 1.0:
		return
	var rr := r * ease_out(t, 3.0)
	var th := maxf(thick * (1.0 - t), 1.0)
	var k := span(t, 0.4, 1.0)
	if squash == 1.0:
		p.ring(cx, cy, rr - th, rr, c, k)
		return
	for y in range(floori(cy - rr * squash), ceili(cy + rr * squash) + 1):
		var dy := (float(y) + 0.5 - cy) / squash
		for x in range(floori(cx - rr), ceili(cx + rr) + 1):
			var dx := float(x) + 0.5 - cx
			var d := sqrt(dx * dx + dy * dy)
			if d >= rr - th and d <= rr:
				p.put_d(x, y, c, k)


## Молния a -> b: ломаная (смещение середины), ядро core в 1 пиксель и край edge;
## ветки — короче и тоньше. seed меняется по кадрам — молния дрожит.
static func bolt(p: Pix, seed: int, a: Vector2, b: Vector2, core: Color, edge: Color, jag: float = 0.25,
		branches: int = 2) -> void:
	var pts := _jag(seed, a, b, jag, 5)
	for i in pts.size() - 1:
		p.capsule(pts[i], pts[i + 1], 1.0, 1.0, edge)
	for i in pts.size() - 1:
		p.line_v(pts[i], pts[i + 1], core)
	for j in branches:
		var from := pts[int(rnd(seed, 50 + j) * float(pts.size() - 2)) + 1]
		var d := (b - a).rotated(rnd_range(seed, 60 + j, -1.0, 1.0)) * rnd_range(seed, 70 + j, 0.15, 0.3)
		var bp := _jag(seed + 7 * j, from, from + d, jag, 3)
		for i in bp.size() - 1:
			p.line_v(bp[i], bp[i + 1], edge)


static func _jag(seed: int, a: Vector2, b: Vector2, jag: float, depth: int) -> PackedVector2Array:
	var pts := PackedVector2Array([a, b])
	var amp := a.distance_to(b) * jag
	for d in depth:
		var out := PackedVector2Array()
		for i in pts.size() - 1:
			var m := (pts[i] + pts[i + 1]) * 0.5
			var n := (pts[i + 1] - pts[i]).orthogonal().normalized()
			out.append(pts[i])
			out.append(m + n * (rnd(seed, d * 97 + i) - 0.5) * amp)
		out.append(pts[pts.size() - 1])
		pts = out
		amp *= 0.5
	return pts


## Луч a -> b ширины wid: белое ядро, цветной край, рваная кромка мерцает (seed).
static func beam(p: Pix, seed: int, a: Vector2, b: Vector2, wid: float, core: Color, edge: Color, k: float = 0.0) -> void:
	var len := a.distance_to(b)
	if len < 1.0:
		return
	var d := (b - a) / len
	var n := d.orthogonal()
	var steps := ceili(len)
	for s in steps:
		var c := a + d * float(s)
		var jitter := (rnd(seed, s / 3) - 0.5) * 2.0
		var we := wid * 0.5 + 1.0 + jitter
		var wc := maxf(wid * 0.5 - 1.0, 0.5)
		for o in range(-ceili(we), ceili(we) + 1):
			var q := (c + n * float(o)).floor()
			var col := core if absf(float(o)) <= wc else edge
			p.put_d(int(q.x), int(q.y), col, k)


## Серп удара по дуге окружности (центр, радиус r, толщина th) от угла a0 к a1;
## t 0..1: голова пробегает дугу, хвост догоняет и рвётся прядями.
static func slash(p: Pix, seed: int, cx: float, cy: float, r: float, th: float, a0: float, a1: float, t: float,
		core: Color, edge: Color) -> void:
	if t <= 0.0 or t >= 1.0:
		return
	var head := ease_out(span(t, 0.0, 0.45), 2.0)
	var tail := ease_in(span(t, 0.15, 1.0), 1.6)
	var k := span(t, 0.5, 1.0)
	var steps := ceili(absf(a1 - a0) * r)
	for s in steps:
		var f := float(s) / float(steps)
		if f > head or f < tail:
			continue
		# толщина: тонко у хвоста, полно у головы, острый кончик
		var local := (f - tail) / maxf(head - tail, 0.001)
		var w := th * sin(clampf(local, 0.0, 1.0) * PI * 0.92 + 0.08)
		var a := lerpf(a0, a1, f)
		var dir := Vector2(cos(a), sin(a))
		for o in range(0, ceili(w) + 1):
			var q := (Vector2(cx, cy) + dir * (r - float(o))).floor()
			# пряди на хвосте: часть внутренних рядов выпадает полосами
			if local < 0.4 and int(o + floori(rnd(seed, s / 4) * 3.0)) % 3 == 0:
				continue
			p.put_d(int(q.x), int(q.y), edge if o == 0 or o >= ceili(w) - 1 else core, k)
