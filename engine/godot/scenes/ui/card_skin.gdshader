// Образы карт (SkinCollection). Индексы 1–3 — Faerie Fire, Gilded и Prism,
// 4–11 — фойловые отделки с собственными палитрами и тиснением.
//
// Всё считается по пикселям карты (texelFetch), а не экрана: при любом целом
// масштабе пиксели остаются квадратными. Переходы — уровнями палитры
// и дизерингом Байера на сетке текстуры. За краем карты рисуется
// жёлтая рамка «можно сыграть» (CardView.PIXEL_HIGHLIGHT), с ней не спорим.
//
// Шейдер висит на всём CardView, но меняет только лицо карты: у остальной
// отрисовки (рамки draw_rect) текстура другого размера.
shader_type canvas_item;

uniform int tier = 0;
// Размер лица карты в его пикселях и области в пикселях: x0, y0, x1, y1
// (x1, y1 не включены). text_rect с x1 <= x0 — поля текста нет (мелкое лицо).
uniform vec2 face_size = vec2(176.0, 254.0);
uniform vec4 art_rect = vec4(6.0, 34.0, 170.0, 134.0);
uniform vec4 text_rect = vec4(7.0, 139.0, 169.0, 232.0);
// Наклон к мыши (-1..1) и насколько он действует (0 — карта сама покачивается).
uniform vec2 tilt = vec2(0.0);
uniform float hover = 0.0;
// Фактический поворот CardFlip и вылет карты из лутбокса.
uniform float foil_turn = 0.0;
uniform float phase = 0.0;
uniform float idle_amp = 1.0;
// Размер звёздочек и блика; сколько искр в арте.
uniform float glint_size = 4.0;
uniform float flare_size = 5.0;
uniform int ember_count = 18;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0,
	13.0, 5.0);
const vec3 GOLD[6] = vec3[](vec3(35.0, 18.0, 8.0), vec3(95.0, 50.0, 14.0), vec3(165.0, 100.0, 24.0),
	vec3(222.0, 160.0, 44.0), vec3(255.0, 212.0, 96.0), vec3(255.0, 246.0, 196.0));

// По восемь красок на отделку, в порядке индексов SkinCollection.
const vec3 FOIL_RAMPS[64] = vec3[](
	vec3(32, 9, 20), vec3(65, 16, 33), vec3(109, 25, 45), vec3(162, 42, 54),
	vec3(203, 70, 58), vec3(239, 117, 67), vec3(255, 177, 104), vec3(255, 235, 181),
	vec3(9, 17, 42), vec3(21, 36, 78), vec3(25, 62, 116), vec3(32, 94, 154),
	vec3(48, 136, 194), vec3(77, 181, 220), vec3(156, 229, 247), vec3(228, 250, 255),
	vec3(21, 9, 44), vec3(44, 18, 78), vec3(68, 29, 124), vec3(105, 52, 163),
	vec3(148, 72, 195), vec3(196, 117, 222), vec3(237, 175, 240), vec3(254, 226, 255),
	vec3(8, 25, 23), vec3(16, 51, 42), vec3(21, 81, 62), vec3(30, 120, 81),
	vec3(54, 153, 101), vec3(111, 183, 108), vec3(205, 214, 114), vec3(251, 245, 176),
	vec3(19, 22, 39), vec3(42, 47, 72), vec3(70, 77, 111), vec3(104, 116, 153),
	vec3(146, 160, 195), vec3(182, 201, 230), vec3(218, 234, 248), vec3(250, 249, 243),
	vec3(44, 12, 32), vec3(81, 22, 54), vec3(131, 31, 80), vec3(183, 49, 111),
	vec3(225, 80, 145), vec3(249, 132, 177), vec3(255, 185, 209), vec3(255, 235, 229),
	vec3(7, 25, 33), vec3(11, 50, 61), vec3(14, 82, 96), vec3(20, 119, 130),
	vec3(40, 161, 160), vec3(76, 206, 181), vec3(154, 239, 195), vec3(231, 254, 212),
	vec3(12, 11, 16), vec3(26, 24, 31), vec3(40, 36, 45), vec3(60, 52, 63),
	vec3(86, 76, 85), vec3(123, 110, 113), vec3(181, 170, 167), vec3(255, 239, 221)
);
const vec3 ECLIPSE_COOL[3] = vec3[](vec3(62, 110, 197), vec3(97, 178, 226), vec3(170, 228, 250));
const vec3 FOIL_PAPER[8] = vec3[](
	vec3(0.985, 0.875, 0.745), vec3(0.840, 0.920, 0.960), vec3(0.935, 0.870, 0.975), vec3(0.884, 0.938, 0.792),
	vec3(0.913, 0.936, 0.984), vec3(0.996, 0.830, 0.891), vec3(0.817, 0.955, 0.912), vec3(0.918, 0.890, 0.870)
);
// xy — направление движения блика, z — его ширина.
const vec3 FOIL_LIGHT[8] = vec3[](
	vec3(0.86, 0.51, 0.105), vec3(0.77, -0.64, 0.122), vec3(0.94, 0.34, 0.111), vec3(0.60, -0.80, 0.133),
	vec3(0.92, -0.39, 0.093), vec3(0.82, 0.57, 0.122), vec3(0.64, -0.77, 0.123), vec3(0.98, 0.20, 0.082)
);

varying vec4 vertex_colour;

void vertex() {
	vertex_colour = COLOR;
}

float bay(ivec2 p) {
	return BAYER[(p.y & 3) * 4 + (p.x & 3)] / 16.0;
}

float dith(float a, ivec2 p, float levels) {
	return clamp(floor(a * levels + bay(p)), 0.0, levels) / levels;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 texel(sampler2D tex, ivec2 p) {
	ivec2 size = ivec2(face_size);
	return texelFetch(tex, clamp(p, ivec2(0), size - 1), 0).rgb;
}

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

bool inside(vec4 r, ivec2 p) {
	return float(p.x) >= r.x && float(p.x) < r.z && float(p.y) >= r.y && float(p.y) < r.w;
}

// 0 — поле текста, 1 — арт, 2 — рамка, 3 — светлые буквы на рамке, 4 — тёмный контур.
int region(sampler2D tex, ivec2 p) {
	if (text_rect.z > text_rect.x && inside(text_rect, p)) {
		return 0;
	}
	if (inside(art_rect, p)) {
		return 1;
	}
	float l = lum(texel(tex, p));
	if (l < 0.04) {
		return 4;
	}
	return l > 0.6 ? 3 : 2;
}

vec3 hsv2rgb(float h, float s, float v) {
	vec3 k = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return v * mix(vec3(1.0), k, s);
}

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

// Арт переливается: оттенок сдвигается по месту и времени.
vec3 poly(vec3 c, float u, float v, float tx, float mixing) {
	vec3 hsv = rgb2hsv(c);
	hsv.x = fract(hsv.x + u * 0.55 + v * 0.3 + TIME * 0.05 + tx * 0.4);
	hsv.y = min(1.0, hsv.y * 1.4 + 0.15);
	return mix(c, hsv2rgb(hsv.x, hsv.y, hsv.z), mixing);
}

// Градиент яркости вокруг пикселя — для рельефа и контуров Faerie Fire.
vec2 slope(sampler2D tex, ivec2 p) {
	float l = lum(texel(tex, p + ivec2(-1, 0)));
	float r = lum(texel(tex, p + ivec2(1, 0)));
	float u = lum(texel(tex, p + ivec2(0, -1)));
	float d = lum(texel(tex, p + ivec2(0, 1)));
	return vec2(r - l, d - u);
}

bool is_edge(sampler2D tex, ivec2 p) {
	return inside(vec4(art_rect.xy + 1.0, art_rect.zw - 1.0), p) && length(slope(tex, p)) > 0.3;
}

// Рельеф фольги: наклон граней, отражающая способность, гравировка и дисперсия.
vec4 foil_surface(vec2 uv, vec2 p) {
	if (tier == 4) {
		// Веер глубоких бороздок и рёбер на чеканной меди.
		vec2 fan = p - vec2(0.0, 0.74);
		float angle = atan(fan.x, -fan.y);
		float ridge = 0.5 + 0.5 * sin(angle * 56.0 + sin(length(fan) * 9.0) * 0.68);
		float brush = sin(dot(uv, vec2(33.0, 18.0)) * TAU);
		float grooves = max(smoothstep(0.78, 0.98, ridge) * 0.80, smoothstep(0.65, 0.99, brush) * 0.34);
		return vec4((ridge - 0.5) * 0.070, 0.59 + ridge * 0.25 + brush * 0.055, grooves, ridge * 0.24);
	}
	if (tier == 5) {
		// Треугольные пластины с разным наклоном и тонким стыком под серебро.
		vec2 lattice = (vec2(uv.x + uv.y * 0.36, uv.y)
			+ vec2(sin(uv.y * 14.0), sin(uv.x * 11.0)) * 0.033) * vec2(9.0, 12.0);
		vec2 cell = floor(lattice);
		vec2 f = fract(lattice);
		float half_cell = step(f.y, f.x);
		float facet = hash(cell + vec2(0.37, 0.67) * half_cell);
		float edge = min(min(min(f.x, f.y), 1.0 - max(f.x, f.y)), 0.707 * abs(f.x - f.y));
		return vec4((facet - 0.5) * 0.35, 0.52 + facet * 0.42,
			1.0 - smoothstep(0.019, 0.074, edge), facet * 0.55);
	}
	if (tier == 6) {
		// Гильоше вокруг печати и спектральный сдвиг между двумя рельефами.
		vec2 centre = p - vec2(0.04, -0.24);
		float angle = atan(centre.y, centre.x + 0.00001);
		float radius = length(centre);
		float rings = radius * 29.0 + 0.31 * sin(angle * 8.0 + radius * 31.0);
		float groove = 0.5 + 0.5 * cos(TAU * rings);
		float rosette = smoothstep(0.58, 0.96, groove) * smoothstep(0.027, 0.09, radius);
		float phase_shift = sin(radius * 28.0 - angle * 4.0);
		return vec4(phase_shift * 0.070, 0.53 + groove * 0.38, rosette, phase_shift * 0.40);
	}
	if (tier == 8) {
		// Натянутая паутина с бусинками на стыках радиальных и поперечных нитей.
		vec2 hub = p + vec2(0.10, 0.14);
		float radius = length(hub);
		float sector = fract(atan(hub.y, hub.x + 0.00001) / TAU * 12.0 + 0.5);
		float angle_to_thread = min(sector, 1.0 - sector);
		float spoke = 1.0 - smoothstep(0.007, 0.021, angle_to_thread * radius);
		float ring = radius * 11.8 + sin(sector * PI) * 0.23;
		float strand = 1.0 - smoothstep(0.033, 0.11, abs(fract(ring) - 0.5));
		float knot = spoke * strand;
		float web = max(spoke * 0.63, strand * 0.88);
		return vec4((web - 0.5) * 0.067, 0.56 + web * 0.29 + knot * 0.14, max(web, knot), 0.0);
	}
	if (tier == 9) {
		// Фаски из розового кварца, где одна из сторон ловит блик наискось.
		vec2 cuts = vec2(dot(p, vec2(0.80, 0.60)), dot(p, vec2(-0.60, 0.80))) * vec2(9.6, 7.6);
		vec2 cell = floor(cuts);
		vec2 facet = fract(cuts) - 0.5;
		float diamond = abs(facet.x) + abs(facet.y);
		float rim = 1.0 - smoothstep(0.028, 0.106, abs(diamond - 0.37));
		float face = step(0.0, facet.x - facet.y) * step(diamond, 0.37);
		float grain = hash(cell);
		return vec4((face - 0.44) * 0.15 + (grain - 0.5) * 0.12,
			0.49 + face * 0.30 + grain * 0.18, rim, 0.0);
	}
	if (tier == 10) {
		// Два семейства преломлённых бороздок, как свет под рифлёным стеклом.
		float wave = sin(p.x * 18.0 + p.y * 8.0) * 0.41;
		float current = p.y * 13.0 + p.x * 5.0 + wave;
		float crest = 0.5 + 0.5 * sin(current * TAU);
		float cross = 0.5 + 0.5 * sin((p.x * 7.0 - p.y * 4.0 + sin(current) * 0.44) * TAU);
		float pools = crest * cross;
		return vec4((pools - 0.40) * 0.17, 0.61 + crest * 0.15 + pools * 0.23,
			smoothstep(0.70, 0.94, pools) * 0.86, 0.0);
	}
	if (tier == 11) {
		// Чёрное зеркало: широкие сколы отделены тонким светлым торцом.
		float split = p.x * 7.5 + abs(p.y + 0.07) * 2.35;
		float plane = floor(split);
		float shard = hash(vec2(plane, 13.1));
		float bevel = 1.0 - smoothstep(0.016, 0.085, abs(fract(split) - 0.5));
		float facet = step(0.5, fract(split));
		return vec4((shard - 0.5) * 0.19 + facet * 0.055, 0.43 + shard * 0.29 + bevel * 0.27,
			bevel * 0.84, 0.0);
	}
	// Малахитовые слои, по краям — металлическая гравировка листьев и жилок.
	float flow = p.y * 10.0 + p.x * 4.0 + sin(p.x * 8.0 - p.y * 3.0) * 1.6;
	float layer = 0.5 + 0.5 * sin(flow * 2.65 + sin(flow * 5.0) * 0.41);
	float side = step(0.5, uv.x);
	float stem_x = 0.044 + sin(uv.y * 33.0 + side * 2.0) * 0.018;
	float across = (min(uv.x, 1.0 - uv.x) - stem_x) / 0.152;
	float leaf_y = abs(fract(uv.y * 11.0 + side * 0.51) - 0.5 + across * 0.28);
	float leaf_width = max(0.0, 1.0 - abs(across * 2.0 - 1.0));
	float leaf = (1.0 - smoothstep(0.010, 0.058, abs(leaf_y - leaf_width * 0.25)))
		* smoothstep(0.02, 0.15, leaf_width);
	float stem = 1.0 - smoothstep(0.025, 0.077, abs(across));
	float veins = smoothstep(0.76, 0.98, layer) * 0.45;
	return vec4((layer - 0.5) * 0.133, 0.59 + layer * 0.35, max(max(0.65 * stem, leaf), veins), layer * 0.38);
}

float foil_lobe(float d, float width) {
	float x = d / width;
	return exp(-x * x);
}

// Клеймо фольги в углу крупной иллюстрации, по одному на отделку.
float foil_seal(vec2 p) {
	float diamond = abs(p.x) + 1.4 * abs(p.y);
	if (tier == 4) {
		float chevrons = abs(mod(diamond + p.y * 0.85, 3.5) - 1.75);
		return (1.0 - smoothstep(0.38, 0.95, chevrons)) * (1.0 - smoothstep(7.0, 13.0, diamond));
	}
	if (tier == 5) {
		float facets = min(abs(p.x), abs(abs(p.x) * 0.44 - abs(p.y)));
		return max(1.0 - smoothstep(0.42, 1.18, abs(diamond - 10.0)),
			(1.0 - smoothstep(0.35, 1.0, facets)) * (1.0 - smoothstep(9.0, 10.5, diamond)));
	}
	if (tier == 6) {
		float arcs = abs(length(p + vec2(2.5, 0.0)) - 4.4);
		float shaded = smoothstep(3.5, 5.5, length(p - vec2(1.2, -0.9)));
		return max((1.0 - smoothstep(0.38, 1.12, arcs)) * shaded,
			1.0 - smoothstep(0.50, 1.50, abs(p.x - 6.0) + abs(p.y + 2.5)));
	}
	if (tier == 8) {
		float thread = min(min(abs(p.x), abs(p.y)), abs(abs(p.x) - abs(p.y)));
		float mesh = min(thread, abs(length(p) - 4.7));
		return (1.0 - smoothstep(0.43, 1.1, mesh)) * (1.0 - smoothstep(5.5, 7.2, length(p)));
	}
	if (tier == 9) {
		float bevel = max(abs(p.y) * 1.92, diamond);
		float facet = abs(bevel - 9.0);
		return max(1.0 - smoothstep(0.45, 1.28, abs(diamond - 4.5)),
			1.0 - smoothstep(0.43, 1.13, facet));
	}
	if (tier == 10) {
		float current = sin(p.x * 0.52) * 1.55;
		float crest = abs(abs(p.y - current) - 1.45);
		return (1.0 - smoothstep(0.26, 1.03, crest)) * (1.0 - smoothstep(7.0, 10.0, abs(p.x)));
	}
	if (tier == 11) {
		float square = max(abs(p.x), abs(p.y) * 1.35);
		float edge = abs(square - 5.4);
		float split = abs(p.x - p.y * 1.35);
		return max(1.0 - smoothstep(0.42, 1.13, edge),
			(1.0 - smoothstep(0.43, 1.14, split)) * (1.0 - smoothstep(4.5, 5.6, square)));
	}
	float leaves = abs(abs(p.y) - sin(clamp(abs(p.x) / 10.0, 0.0, 1.0) * PI) * 3.5);
	return (1.0 - smoothstep(0.38, 1.18, leaves)) * (1.0 - smoothstep(8.1, 10.5, abs(p.x)));
}

bool matches_print(vec3 ink, vec3 rgb) {
	return all(lessThan(abs(ink * 255.0 - rgb), vec3(1.5)));
}

bool is_frame_ink(vec3 ink) {
	// Три краски рамки из pixel_cards.gd. Среди букв есть и тёмные цвета.
	return matches_print(ink, vec3(36.0, 21.0, 63.0))
		|| matches_print(ink, vec3(74.0, 47.0, 130.0))
		|| matches_print(ink, vec3(22.0, 12.0, 40.0));
}

vec3 foil_ink(float value, ivec2 pixel, bool cool_band) {
	int tone = int(round(dith(value, pixel, 7.0) * 7.0));
	if (cool_band && tone >= 4 && tone <= 6) {
		return ECLIPSE_COOL[tone - 4] / 255.0;
	}
	return FOIL_RAMPS[(tier - 4) * 8 + tone] / 255.0;
}

vec3 foil_skin(vec3 ink, ivec2 pixel, bool art, vec2 art_slope) {
	int style = tier - 4;
	vec3 paper_tone = FOIL_PAPER[style];
	vec2 axis = FOIL_LIGHT[style].xy;
	float width = FOIL_LIGHT[style].z;
	if (inside(text_rect, pixel)) {
		// Красится только фон бумаги, печать поверх него сохраняется.
		if (matches_print(ink, vec3(230.0, 217.0, 188.0))) {
			return mix(ink, paper_tone, 0.52);
		}
		if (matches_print(ink, vec3(191.0, 174.0, 136.0))) {
			return mix(ink, paper_tone * 0.79, 0.52);
		}
		return ink;
	}
	if (!art && !is_frame_ink(ink)) {
		return ink;
	}

	vec2 at = vec2(pixel) + 0.5;
	vec2 uv = at / face_size;
	vec2 p = (uv - 0.5) * vec2(1.0, 1.38);
	vec2 idle = vec2(sin(TIME * 0.64 + phase) * 0.67, cos(TIME * 0.48 + phase) * 0.37) * idle_amp;
	vec2 lean = mix(idle, tilt, hover);
	lean.x += foil_turn * 0.84;
	vec4 surface = foil_surface(uv, p);

	// Положение света меняется при наклоне. В палитру попадают ступени яркости.
	float shift = round(dot(lean, axis * vec2(0.64, 0.48)) * face_size.x) / face_size.x;
	float d = dot(p, axis) - shift + surface.x;
	if (tier == 10) {
		d += sin(p.x * 9.0 + p.y * 2.0) * 0.075;
	}
	float broad = foil_lobe(d + 0.055, width * 2.5);
	float key = foil_lobe(d, width) * surface.y;
	float flank = foil_lobe(d - 0.17, width * 0.59) * surface.y;
	float specular = foil_lobe(d + 0.018, width * 0.34) * surface.y;
	bool cool_band = tier == 6 && abs(d + 0.10 + surface.w * 0.17) < 0.064;
	float etched = surface.z * (0.14 + key * 0.30 + flank * 0.24);

	if (art) {
		// Под печатью свет цепляется за светлые краски и рёбра самой иллюстрации.
		float ink_light = clamp((lum(ink) - 0.07) / 0.67, 0.0, 1.0);
		float relief = max(0.0, dot(art_slope, axis)) * step(0.12, key);
		float coating = max(0.0, 0.17 * broad + 0.37 * key + 0.21 * flank + 0.25 * relief - 0.055)
			* mix(0.32, 1.0, ink_light);
		vec3 tint = foil_ink(0.41 + 0.23 * key + 0.34 * specular + 0.13 * flank, pixel, cool_band);
		vec3 printed = mix(ink, tint, dith(coating, pixel, 4.0));
		// Отдельные яркие пиксели остаются внутри блика или на печатном клейме.
		float fleck = (surface.z * (key * 0.52 + flank * 0.20) + relief * key * 0.54)
			* mix(0.12, 0.70, ink_light);
		float seal = 0.0;
		if (text_rect.z > text_rect.x) {
			seal = foil_seal(at - (art_rect.zw - vec2(15.0, 11.0)));
		}
		if (bay(pixel) + 0.085 < max(fleck, seal * (0.32 + key * 0.53))) {
			return foil_ink(0.54 + specular * 0.41 + key * 0.14, pixel, cool_band);
		}
		return printed;
	}

	// Кант шириной в пиксель и тиснение делят те же краски, что и блик.
	vec2 outer = min(at, face_size - at);
	float edge = min(outer.x, outer.y);
	vec2 from_art = max(art_rect.xy - at, at - art_rect.zw);
	float art_edge = max(from_art.x, from_art.y);
	float trim = max(1.0 - step(0.52, abs(edge - 1.5)), 1.0 - step(0.52, abs(art_edge - 1.5)));
	float level = 0.16 + 0.26 * broad + 0.32 * key + 0.28 * specular + 0.27 * flank
		+ max(trim * 0.28, etched);
	// Под строкой аспекта оставляем тёмные ступени, чтобы держать контраст красных букв.
	float aspect_row = float(text_rect.z > text_rect.x)
		* smoothstep(-14.0, -10.0, at.y - art_rect.y)
		* (1.0 - smoothstep(-4.0, -1.0, at.y - art_rect.y));
	level *= 1.0 - aspect_row * (1.0 - smoothstep(0.48, 0.67, uv.x)) * 0.47;
	return foil_ink(level, pixel, cool_band);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	bool face = abs(TEXTURE_PIXEL_SIZE.x * face_size.x - 1.0) < 0.01 && abs(TEXTURE_PIXEL_SIZE.y * face_size.y - 1.0) < 0.01;
	if (tier == 0 || !face) {
		COLOR = base * vertex_colour;
	} else if (tier >= 4 && tier <= 11) {
		ivec2 p = clamp(ivec2(floor(UV / TEXTURE_PIXEL_SIZE)), ivec2(0), ivec2(face_size) - 1);
		vec4 src = texelFetch(TEXTURE, p, 0);
		bool art = inside(art_rect, p);
		vec2 grain = art ? slope(TEXTURE, p) : vec2(0.0);
		vec3 c = foil_skin(src.rgb, p, art, grain);
		COLOR = vec4(c, src.a) * vertex_colour;
	} else {
		ivec2 p = ivec2(floor(UV / TEXTURE_PIXEL_SIZE));
		vec4 src = texelFetch(TEXTURE, p, 0);
		vec3 c = src.rgb;
		float W = face_size.x;
		float H = face_size.y;
		float u = float(p.x) / W;
		float v = float(p.y) / H;
		float l = lum(c);
		int reg = region(TEXTURE, p);
		vec2 idle = vec2(sin(TIME * 0.6 + phase) * 0.55, cos(TIME * 0.45 + phase) * 0.4) * idle_amp;
		vec2 t2 = mix(idle, tilt, hover);
		float lx = 0.5 + t2.x * 0.55;
		float ly = 0.5 + t2.y * 0.55;
		vec2 g = slope(TEXTURE, p);
		vec3 n = normalize(vec3(-g.x * 2.2, -g.y * 2.2, 1.0));
		vec3 ld = normalize(vec3(lx - u, ly - v, 0.45));
		float diff = dot(n, ld);
		float sw = (u * 0.9 + v * 0.45) - (0.68 + t2.x * 0.6 + t2.y * 0.3);
		float band = exp(-sw * sw / 0.0028) + 0.45 * exp(-(sw + 0.1) * (sw + 0.1) / 0.0008);
		float fx = float(p.x);
		float fy = float(p.y);

		if (reg != 4 && tier == 1) {
			if (reg == 1) {
				c *= 0.62 + 0.3 * diff;
				float a = 0.0;
				if (is_edge(TEXTURE, p)) {
					a = 0.55 + 0.45 * sin(TIME * 4.0 + fy * 0.4 + hash(vec2(fx, fy)) * TAU);
				} else if (is_edge(TEXTURE, p + ivec2(0, 1)) && hash(vec2(fx, fy + floor(TIME * 7.0))) > 0.55) {
					a = 0.45;
				}
				if (a > 0.0) {
					a = dith(a, p, 3.0);
					vec3 tint = sin(TIME * 1.3 + fx * 0.08 + fy * 0.03) > 0.0 ? vec3(200.0, 110.0, 255.0) / 255.0
						: vec3(110.0, 225.0, 255.0) / 255.0;
					vec3 hot = a > 0.9 ? vec3(240.0, 220.0, 255.0) / 255.0 : tint;
					c += (hot - c) * a;
				}
			} else if (reg == 2) {
				c *= 0.8 + 0.4 * diff;
				c += (vec3(190.0, 140.0, 255.0) / 255.0 - c) * dith(band * 0.6, p, 3.0) * 0.6;
			}
		} else if (reg != 4 && tier == 2) {
			if (reg == 1) {
				c = poly(c, u, v, t2.x, 0.5) * (0.78 + 0.5 * diff);
				c += (vec3(1.0, 245.0 / 255.0, 210.0 / 255.0) - c) * dith(band * 0.9 * (0.4 + l), p, 4.0) * 0.75;
			} else if (reg == 2) {
				bool shadow = p.x < 3 || p.y < 3 || fx > W - 4.0 || fy > H - 4.0;
				for (int k = 0; k < 9 && !shadow; k++) {
					ivec2 q = p + ivec2(k % 3 - 1, k / 3 - 1);
					shadow = region(TEXTURE, q) == 3;
				}
				if (shadow) {
					c = GOLD[1] / 255.0;
				} else {
					float ang = atan(fy - H * 0.5, (fx - W * 0.5) * H / W) / TAU;
					float rn = fract(ang - TIME * 0.22);
					rn = min(rn, 1.0 - rn);
					float gv = clamp(l * 1.35 * (0.75 + 0.45 * diff) + exp(-rn * rn / 0.0015) * 0.55 + band * 0.35 + 0.08,
						0.0, 1.0);
					c = GOLD[int(round(dith(gv, p, 5.0) * 5.0))] / 255.0;
				}
			} else if (reg == 3) {
				c = vec3(1.0, 240.0 / 255.0, 196.0 / 255.0);
			} else {
				c += (vec3(1.0, 240.0 / 255.0, 200.0 / 255.0) - c) * dith(band * 0.25, p, 3.0) * 0.5;
			}
			// Искры поднимаются по арту и гаснут у его верха.
			if (reg == 1) {
				float aw = art_rect.z - art_rect.x;
				float ah = art_rect.w - art_rect.y;
				for (int i = 0; i < ember_count; i++) {
					float fi = float(i);
					float speed = (0.15 + hash(vec2(fi, 1.0)) * 0.35) * ah / 100.0 * 60.0;
					float run = TIME * speed / ah + hash(vec2(fi, 2.0));
					float life = 1.0 - fract(run);
					float ey = art_rect.w - 1.0 - fract(run) * ah;
					float ex = art_rect.x + hash(vec2(fi, floor(run) + 3.0)) * aw + sin(TIME * 3.0 + ey * 0.1) * 1.5;
					if (int(round(ex)) == p.x && int(round(ey)) == p.y) {
						c = life > 0.7 ? vec3(1.0, 240.0 / 255.0, 150.0 / 255.0)
							: (life > 0.4 ? vec3(1.0, 170.0 / 255.0, 50.0 / 255.0) : vec3(210.0 / 255.0, 80.0 / 255.0, 30.0 / 255.0));
					}
				}
				// Звёздочка: раз в 0.4 с в случайном месте арта, растёт и гаснет.
				float slot = floor(TIME * 2.5 + phase);
				float frame = fract(TIME * 2.5 + phase) * 24.0;
				if (frame < glint_size * 2.0) {
					float s = floor(frame < glint_size ? frame : glint_size * 2.0 - frame);
					ivec2 at = ivec2(art_rect.xy + vec2(hash(vec2(slot, 5.0)), hash(vec2(slot, 6.0))) * (art_rect.zw - art_rect.xy));
					ivec2 d = abs(p - at);
					if ((d.x == 0 && float(d.y) <= s) || (d.y == 0 && float(d.x) <= s)) {
						c = vec3(1.0, 250.0 / 255.0, 220.0 / 255.0);
					}
				}
			}
		} else if (reg != 4 && tier == 3) {
			if (reg == 1) {
				c = poly(c, u, v, t2.x, 0.35) * (0.8 + 0.45 * diff);
				c += (vec3(1.0) - c) * dith(band * (0.4 + l), p, 4.0) * 0.8;
			} else if (reg == 2) {
				float hue = floor(fract((fx - fy) * 0.018 + t2.x * 0.8 + t2.y * 0.5 + TIME * 0.04) * 6.0 + bay(p) - 0.5) / 6.0;
				float val = round(dith(clamp(0.28 + l * 1.3 * (0.75 + 0.45 * diff) + band * 0.7, 0.0, 1.0), p, 4.0) * 4.0) / 4.0;
				c = hsv2rgb(fract(hue), 0.55, 0.25 + 0.75 * val);
			} else if (reg == 3) {
				c = vec3(1.0);
			} else {
				c += (vec3(1.0) - c) * dith(band * 0.2, p, 3.0) * 0.5;
			}
			// Блик-звезда там, куда падает свет (только внутри арта).
			ivec2 f = ivec2(int(round(lx * W)), int(round(ly * H)));
			int m = int(flare_size);
			if (inside(vec4(art_rect.xy + flare_size, art_rect.zw - flare_size), f)) {
				ivec2 d = p - f;
				if ((d.y == 0 && abs(d.x) <= m) || (d.x == 0 && abs(d.y) <= m)) {
					int k = d.x + d.y;
					c = abs(k) < 2 ? vec3(1.0) : hsv2rgb(fract(TIME * 0.3 + float(k) * 0.08), 0.5, 1.0);
				} else if (abs(d.x) == 1 && abs(d.y) == 1) {
					c = vec3(230.0, 240.0, 255.0) / 255.0;
				}
			}
		}
		COLOR = vec4(clamp(c, 0.0, 1.0), src.a) * vertex_colour;
	}
}
