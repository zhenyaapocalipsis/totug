shader_type canvas_item;
render_mode unshaded;

// Огонь и дым эффектов уникальных карт — как их рисуют пиксель-художники, а не
// частицами-кружками: поле плотности (форма потока + шум, который уносится по
// течению) режется на полосы цветов палитры. Огонь — языки с острыми концами,
// вытянутые по движению, полосы от белого ядра к багровому краю, клочья отрываются.
// Дым — крупные клубы: светлая шапка со стороны света (сверху-слева), тёмный низ,
// края растворяются узором Байера.
// Чистка как у художника: пиксель, цвет которого не совпадает ни с одним из четырёх
// соседей («сирота», соль-перец), берёт цвет соседей.
// Пиксели — сетка экрана игры (floor), время — ступенями (задаёт UniqueFx, 20 к/с).
//
// mode 0 — струя огня от p0 к p1 (толщина w0 у начала, w1 у конца, на конце
//          расплёскивается); head/tail — где голова и хвост струи (доли пути);
// mode 1 — пламя над краем p0 -> p1 (растёт «вверх» от отрезка: слева направо —
//          вверх; flip = -1 — в другую сторону), высота до w1, у p0 выше;
// mode 2 — дым столбом от p0 к p1 (радиус w0 внизу, w1 вверху).

uniform int mode = 0;
uniform vec2 origin;
uniform vec2 p0;
uniform vec2 p1;
uniform float w0 = 3.0;
uniform float w1 = 16.0;
uniform float head = 1.0;
uniform float tail = 0.0;
uniform float time = 0.0;
uniform float seed = 0.0;
uniform float power = 1.0;
uniform float flip = 1.0;
// насколько струя остывает к концу (0 — горячая на всём пути)
uniform float cool = 0.22;
// живой огонь: вихри, дышащая ширина, языки всплывают вверх (0 — прежняя струя)
uniform float warp = 0.0;
uniform sampler2D palette : filter_nearest;
uniform int colours = 7;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return s;
}

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer(vec2 px) {
	int x = int(mod(px.x, 4.0));
	int y = int(mod(px.y, 4.0));
	return (BAYER[y * 4 + x] + 0.5) / 16.0;
}

// Ступень палитры пикселя px: 0 — самая светлая, colours-1 — самая тёмная, -1 — пусто.
int band(vec2 px) {
	vec2 d = p1 - p0;
	float len = max(length(d), 1.0);
	vec2 dir = d / len;
	vec2 n = vec2(-dir.y, dir.x);
	vec2 rel = px - p0;
	float u = dot(rel, dir) / len;
	float v = dot(rel, n);
	float lo;
	float f;
	if (mode == 0) {
		float lu = u * len;
		// вихри (domain warping): поле сдвигается шумом, который сам течёт, — клубы
		// перекатываются, края струи волнистые, а не ровные полосы
		vec2 q = vec2(lu, v);
		vec2 wv = vec2(fbm(q / 46.0 + vec2(time * 2.6, seed)), fbm(q / 46.0 + vec2(seed * 1.3, -time * 2.1))) - 0.5;
		q += wv * vec2(34.0, 20.0) * warp;
		// ширина дышит вдоль струи; за концом струя расплёскивается
		float hw = mix(w0, w1, clamp(u, 0.0, 1.0)) * mix(1.0, 0.75 + 0.5 * fbm(vec2(lu / 90.0 - time * 3.5, seed + 3.0)), warp)
			+ max(0.0, u - 0.85) * len * 0.9;
		// огонь поднимается: верхняя сторона (v > 0) выше, нижняя короче
		float vv = q.y > 0.0 ? q.y / mix(1.0, 1.45, warp) : q.y / mix(1.0, 0.85, warp);
		// шум уносится по течению и вытянут вдоль него -> языки острые по движению;
		// с warp ещё и всплывает вверх
		float n1 = fbm(vec2(q.x / 13.0 - time * 15.0, (q.y - time * 22.0 * warp) / 7.0 + seed));
		float n2 = fbm(vec2(q.x / 6.0 - time * 26.0, (q.y - time * 30.0 * warp) / 3.5 - seed * 1.7));
		float across = 1.0 - abs(vv) / max(hw, 1.0);
		float along = smoothstep(tail - 0.04, tail + 0.12, u) * (1.0 - smoothstep(head - 0.14, head + 0.02, u));
		along *= 1.0 - smoothstep(1.05, 1.45, u);
		f = across * 1.15 + (n1 - 0.5) * 1.35 + (n2 - 0.5) * 0.35 * (1.0 - 0.5 * warp);
		f = f * along * power - u * cool;
		lo = 0.12;
		if (f < lo) return -1;
		return clamp(int(floor((1.0 - (f - lo) / 0.85) * float(colours))), 0, colours - 1);
	} else if (mode == 1) {
		// пламя над краем: «вверх» — от отрезка наружу; высота языков меняется вдоль края
		vec2 up = vec2(dir.y, -dir.x) * flip;
		float y = dot(rel, up);
		if (u < -0.02 || u > 1.02 || y < -1.0) return -1;
		float tongues = 0.35 + 0.95 * fbm(vec2(u * len / 16.0 + seed, time * 0.9));
		float h = w1 * power * mix(1.0, 0.35, clamp(u, 0.0, 1.0)) * tongues;
		float n1 = fbm(vec2(u * len / 6.0 + seed, y / 7.0 - time * 7.0));
		float n2 = fbm(vec2(u * len / 3.0 - seed, y / 3.5 - time * 12.0));
		float edge = smoothstep(0.0, 0.06, u) * (1.0 - smoothstep(0.85, 1.0, u));
		f = (1.0 - y / max(h, 1.0)) * 1.15 + (n1 - 0.5) * 1.0 + (n2 - 0.5) * 0.3;
		f *= edge;
		lo = 0.18;
		if (f < lo || h < 1.0) return -1;
		return clamp(int(floor((1.0 - (f - lo) / 0.9) * float(colours))), 0, colours - 1);
	} else {
		// дым: столб от p0 к p1, клубы шумом крупного масштаба
		float hw = mix(w0, w1, clamp(u, 0.0, 1.0));
		vec2 q = vec2(v / 14.0 + seed, u * len / 14.0 - time * 1.6);
		float n1 = fbm(q);
		float n2 = fbm(q * 2.1 + vec2(3.7, -time * 0.8));
		float across = 1.0 - abs(v + sin(u * 5.0 + seed) * hw * 0.25) / max(hw, 1.0);
		float along = smoothstep(-0.05, 0.12, u) * (1.0 - smoothstep(0.55, 1.0, u));
		f = (across * 0.95 + (n1 - 0.5) * 1.3 + (n2 - 0.5) * 0.35) * along * power;
		// край растворяется узором
		if (f < 0.12 + bayer(px) * 0.2) return -1;
		// свет сверху-слева: где плотность растёт к свету — светлее
		vec2 ql = vec2((v - 3.0) / 14.0 + seed, (u * len + 3.0) / 14.0 - time * 1.6);
		float lit = fbm(ql) - n1;
		float tone = clamp(0.3 + f * 0.7 + lit * 2.5, 0.0, 1.0);
		return clamp(int(floor((1.0 - tone) * float(colours - 1))) + 1, 1, colours - 1);
	}
}

void fragment() {
	vec2 px = floor(origin + local) + 0.5;
	int b = band(px);
	int r = band(px + vec2(1.0, 0.0));
	int l = band(px - vec2(1.0, 0.0));
	int dn = band(px + vec2(0.0, 1.0));
	int up = band(px - vec2(0.0, 1.0));
	if (b != r && b != l && b != dn && b != up) {
		// сирота: берём цвет соседей (если пара соседей совпадает — его, иначе правого)
		if (l == r || l == up || l == dn) b = l;
		else if (r == up || r == dn) b = r;
		else if (up == dn) b = up;
		else b = r;
	}
	if (b < 0) discard;
	COLOR = vec4(texelFetch(palette, ivec2(b, 0), 0).rgb, 1.0);
}
