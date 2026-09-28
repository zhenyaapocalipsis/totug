shader_type canvas_item;

// Фон «Windows XP»: синее небо с облаками над зелёным холмом — рисуется
// самим движком, в пиксель-арте (решение владельца, 2026-09-28).
//
// Всё как у underdark_bg.gdshader: экран режется на клетки по pixel_size
// пикселей расчётного экрана 960x540, клетка красится одним цветом из
// небольшой палитры, переходы между цветами — шахматкой (матрица Байера).
// Координаты берутся из UV прямоугольника (0,0 — левый верхний угол): фон
// всегда растянут на весь экран. Облака медленно плывут вправо.

/// Куда гасится фон за игровым экраном (обычно цвет фона темы).
uniform vec4 fade_to : source_color = vec4(0.039, 0.023, 0.070, 1.0);
/// 0 — фон во всю силу (меню), 1 — полностью погашен в fade_to.
uniform float fade : hint_range(0.0, 1.0) = 0.0;
/// Размер «пикселя» фона в пикселях расчётного экрана 960x540.
uniform float pixel_size = 2.0;
uniform float design_height = 540.0;
/// Скорость облаков.
uniform float speed = 0.004;

// Палитра: небо сверху вниз, облака, трава от света к тени, дальний гребень.
const vec3 SKY_0 = vec3(0.075, 0.290, 0.780);
const vec3 SKY_1 = vec3(0.140, 0.420, 0.870);
const vec3 SKY_2 = vec3(0.250, 0.560, 0.930);
const vec3 SKY_3 = vec3(0.420, 0.690, 0.960);
const vec3 CLOUD = vec3(1.000, 1.000, 1.000);
const vec3 CLOUD_SHADE = vec3(0.800, 0.870, 0.960);
const vec3 CLOUD_DARK = vec3(0.620, 0.740, 0.900);
/// Порог шума, выше которого — облако: ниже порог — облаков больше.
const float CLOUD_GATE = 0.53;
const vec3 GRASS_LIT = vec3(0.560, 0.820, 0.200);
const vec3 GRASS_0 = vec3(0.330, 0.690, 0.120);
const vec3 GRASS_1 = vec3(0.200, 0.560, 0.090);
const vec3 GRASS_2 = vec3(0.130, 0.430, 0.070);
const vec3 GRASS_3 = vec3(0.080, 0.310, 0.050);
const vec3 RIDGE = vec3(0.180, 0.360, 0.150);


/// Случайное число клетки шума. Без sin(): у видеокарт sin от больших чисел
/// считается грубо, и шум рвался — облака получали прямые обрубленные края.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}


float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += amp * vnoise(p);
		p = p * 2.02 + vec2(3.1, 1.7);
		amp *= 0.5;
	}
	return sum;
}


float bayer2(vec2 c) {
	c = floor(c);
	return fract(dot(c, vec2(0.5, c.y * 0.75)));
}
float bayer4(vec2 c) {
	return bayer2(0.5 * c) * 0.25 + bayer2(c);
}


/// Выбор из ступенчатой палитры: value 0..1 делится на 4 ступени, граница
/// между соседними дрожит шахматкой d.
vec3 ramp(float value, float d, vec3 c0, vec3 c1, vec3 c2, vec3 c3) {
	float k = clamp(floor(value * 4.0 + d), 0.0, 3.0);
	return k < 0.5 ? c0 : (k < 1.5 ? c1 : (k < 2.5 ? c2 : c3));
}


void fragment() {
	vec2 res = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float px = max(1.0, floor(res.y / design_height)) * max(pixel_size, 1.0);
	vec2 cells = floor(res / px);
	vec2 cell = floor(UV * cells);
	vec2 uv = (cell + 0.5) / cells;
	float aspect = res.x / res.y;
	float d = bayer4(cell) - 0.5;
	float t = TIME * speed;

	// Холм: пологий купол с вершиной слева от центра, справа — дальний гребень.
	float hill = 0.53 + 0.16 * (uv.x - 0.33) * (uv.x - 0.33);
	float ridge = 0.60 - 0.035 * smoothstep(0.78, 1.0, uv.x) + 0.006 * sin(uv.x * 40.0);

	vec3 col;
	if (uv.y < min(hill, ridge)) {
		// Небо: к горизонту светлее.
		col = ramp(uv.y / hill, d * 0.9, SKY_0, SKY_1, SKY_2, SKY_3);
		// Облака: шум, искажённый другим шумом, — пышные кучевые клубы; гуще
		// у горизонта и в верхней трети. Низ облака в тени: если чуть ниже уже
		// чистое небо, клетка — тень, иначе белая.
		vec2 q = vec2(uv.x * aspect * 2.6 - t * 6.0, uv.y * 4.4);
		vec2 w = vec2(fbm(q * 1.3 + vec2(2.0, 7.0)), fbm(q * 1.3 + vec2(8.0, 1.0)));
		float band = 0.5 * smoothstep(0.05, 0.22, uv.y) * (1.0 - smoothstep(0.28, 0.40, uv.y))
			+ 0.8 * smoothstep(0.36, 0.52, uv.y);
		float amount = 0.55 + 0.6 * band;
		float cloud = fbm(q + 0.9 * w) * amount + d * 0.03;
		float below = fbm(q + vec2(0.0, 0.25) + 0.9 * w) * amount;
		if (cloud > CLOUD_GATE) {
			col = below < CLOUD_GATE ? CLOUD_SHADE : CLOUD;
		} else if (cloud > CLOUD_GATE - 0.025) {
			// Край облака: сверху светлый, снизу темнее.
			col = below < CLOUD_GATE - 0.025 ? CLOUD_DARK : CLOUD_SHADE;
		}
	} else if (uv.y < hill) {
		// Дальний гребень за холмом справа.
		col = RIDGE;
	} else {
		// Трава: на гребне светло, к низу темнее; по склону — полосы ветра.
		float depth = (uv.y - hill) / (1.0 - hill);
		float lit = depth * 1.15 + 0.25 * uv.x + 0.12 * (fbm(vec2(uv.x * 5.0 + uv.y * 9.0, uv.y * 30.0)) - 0.5);
		col = ramp(lit, d, GRASS_0, GRASS_1, GRASS_2, GRASS_3);
		if (depth < 0.035 + d * 0.02 && uv.x < 0.75) {
			col = GRASS_LIT;
		}
		// Ближнее поле внизу — чуть темнее, с мелкой рябью травы.
		float near = 0.84 + 0.02 * uv.x;
		if (uv.y > near) {
			col = ramp(0.55 + 0.4 * (uv.y - near) / (1.0 - near) + 0.1 * vnoise(vec2(uv.x * 60.0, uv.y * 8.0)),
				d, GRASS_0, GRASS_1, GRASS_2, GRASS_3);
		}
	}

	COLOR = vec4(mix(col, fade_to.rgb, fade), 1.0);
}
