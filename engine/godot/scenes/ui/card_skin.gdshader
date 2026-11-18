// Образы карт (SkinCollection). Индексы 1–3 — Faerie Fire, Gilded и Prism,
// 4–6 — фойловые отделки с собственными палитрами и тиснением.
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

const vec3 ECLIPSE_FOIL[8] = vec3[](
	vec3(21, 9, 44), vec3(44, 18, 78), vec3(68, 29, 124), vec3(105, 52, 163),
	vec3(148, 72, 195), vec3(196, 117, 222), vec3(237, 175, 240), vec3(254, 226, 255)
);
const vec3 THORN_FOIL[8] = vec3[](
	vec3(12, 28, 24), vec3(17, 49, 38), vec3(25, 77, 52), vec3(34, 104, 65),
	vec3(63, 141, 79), vec3(117, 170, 86), vec3(203, 206, 118), vec3(255, 239, 178)
);
const vec3 GLASS_FOIL[8] = vec3[](
	vec3(9, 24, 43), vec3(15, 40, 62), vec3(24, 63, 89), vec3(28, 91, 122),
	vec3(45, 132, 169), vec3(71, 182, 205), vec3(142, 231, 243), vec3(237, 251, 255)
);
const vec3 ECLIPSE_COOL[3] = vec3[](vec3(62, 110, 197), vec3(97, 178, 226), vec3(170, 228, 250));
const vec3 FOIL_PAPER[3] = vec3[](vec3(0.935, 0.870, 0.975), vec3(0.884, 0.938, 0.792), vec3(0.817, 0.955, 0.912));

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
vec4 eclipse_surface(vec2 p) {
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

float foil_lobe(float d, float width) {
	float x = d / width;
	return exp(-x * x);
}

// Клеймо Void Eclipse в углу крупной иллюстрации.
float eclipse_seal(vec2 p) {
	float arcs = abs(length(p + vec2(2.5, 0.0)) - 4.4);
	float shaded = smoothstep(3.5, 5.5, length(p - vec2(1.2, -0.9)));
	return max((1.0 - smoothstep(0.38, 1.12, arcs)) * shaded,
		1.0 - smoothstep(0.50, 1.50, abs(p.x - 6.0) + abs(p.y + 2.5)));
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

vec3 eclipse_ink(float value, ivec2 pixel, bool cool_band) {
	int tone = int(round(dith(value, pixel, 7.0) * 7.0));
	if (cool_band && tone >= 4 && tone <= 6) {
		return ECLIPSE_COOL[tone - 4] / 255.0;
	}
	return ECLIPSE_FOIL[tone] / 255.0;
}

vec3 foil_paper(vec3 ink) {
	// Красится только фон бумаги, печать поверх него сохраняется.
	vec3 paper_tone = FOIL_PAPER[tier - 4];
	if (matches_print(ink, vec3(230.0, 217.0, 188.0))) {
		return mix(ink, paper_tone, 0.52);
	}
	if (matches_print(ink, vec3(191.0, 174.0, 136.0))) {
		return mix(ink, paper_tone * 0.79, 0.52);
	}
	return ink;
}

vec3 eclipse_skin(vec3 ink, ivec2 pixel, bool art, vec2 art_slope, vec2 lean) {
	const vec2 axis = vec2(0.94, 0.34);
	const float width = 0.111;
	vec2 at = vec2(pixel) + 0.5;
	vec2 uv = at / face_size;
	vec2 p = (uv - 0.5) * vec2(1.0, 1.38);
	vec4 surface = eclipse_surface(p);

	// Положение света меняется при наклоне. В палитру попадают ступени яркости.
	float shift = round(dot(lean, axis * vec2(0.64, 0.48)) * face_size.x) / face_size.x;
	float d = dot(p, axis) - shift + surface.x;
	float broad = foil_lobe(d + 0.055, width * 2.5);
	float key = foil_lobe(d, width) * surface.y;
	float flank = foil_lobe(d - 0.17, width * 0.59) * surface.y;
	float specular = foil_lobe(d + 0.018, width * 0.34) * surface.y;
	bool cool_band = abs(d + 0.10 + surface.w * 0.17) < 0.064;
	float etched = surface.z * (0.14 + key * 0.30 + flank * 0.24);

	if (art) {
		// Под печатью свет цепляется за светлые краски и рёбра самой иллюстрации.
		float ink_light = clamp((lum(ink) - 0.07) / 0.67, 0.0, 1.0);
		float relief = max(0.0, dot(art_slope, axis)) * step(0.12, key);
		float coating = max(0.0, 0.17 * broad + 0.37 * key + 0.21 * flank + 0.25 * relief - 0.055)
			* mix(0.32, 1.0, ink_light);
		vec3 tint = eclipse_ink(0.41 + 0.23 * key + 0.34 * specular + 0.13 * flank, pixel, cool_band);
		vec3 printed = mix(ink, tint, dith(coating, pixel, 4.0));
		// Отдельные яркие пиксели остаются внутри блика или на печатном клейме.
		float fleck = (surface.z * (key * 0.52 + flank * 0.20) + relief * key * 0.54)
			* mix(0.12, 0.70, ink_light);
		float seal = 0.0;
		if (text_rect.z > text_rect.x) {
			seal = eclipse_seal(at - (art_rect.zw - vec2(15.0, 11.0)));
		}
		if (bay(pixel) + 0.085 < max(fleck, seal * (0.32 + key * 0.53))) {
			return eclipse_ink(0.54 + specular * 0.41 + key * 0.14, pixel, cool_band);
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
	return eclipse_ink(level, pixel, cool_band);
}


// На арте блик зависит от рельефа печати. Форма стеклянной грани или листа
// используется только для рамки, где не закрывает детали иллюстрации.
vec3 tideglass_art(vec3 ink, ivec2 pixel, vec2 normal, vec2 uv, vec2 lean) {
	float light = lum(ink);
	float lit = smoothstep(0.20, 0.81, light);
	float field = 1.0 - smoothstep(0.05, 0.85, abs(uv.x - 0.50 - lean.x * 0.42));
	float edge = smoothstep(0.07, 0.42, max(0.0, dot(normal, vec2(lean.x * 0.54 + 0.30, -0.72))));
	float gain = dith((0.042 * lit + 0.25 * edge) * field * lit, pixel, 12.0);
	vec3 light_colour = mix(vec3(0.22, 0.79, 1.0), vec3(0.66, 1.0, 0.91),
		smoothstep(-0.45, 0.75, lean.x + lean.y * 0.48));
	return mix(ink, max(ink, light_colour), gain);
}

vec3 tideglass_frame(ivec2 pixel, vec2 uv, vec2 outer, vec2 lean) {
	float depth = min(outer.x, outer.y);
	float rail = 1.0 - step(0.51, abs(depth - 1.5));
	// На стыке в углу отражение смещается с одной грани на другую.
	float bevel = 1.0 - step(0.51, abs(depth - 3.5));
	float facet = step(outer.x, outer.y);
	float shift = dot(lean, vec2(0.57, -0.31));
	float ray = dot(uv - 0.5, vec2(0.96, -0.50)) - shift + facet * 0.095;
	float wash = 1.0 - smoothstep(0.02, 0.44, abs(ray));
	// Тонкое второе отражение дробится на рёбрах стекла.
	float face = 1.0 - smoothstep(0.05, 0.128, abs(ray));
	float rib = 1.0 - step(0.25, fract((uv.x + uv.y * 0.77) * 20.0));
	float second = (1.0 - smoothstep(0.015, 0.045, abs(ray - 0.163))) * mix(0.55, 1.0, rib);
	float band = (1.0 - step(0.51, abs(depth - 5.5))) * smoothstep(0.55, 0.86, uv.y);
	float level = 0.16 + 0.13 * wash + 0.30 * face + 0.43 * second
		+ rail * (0.20 + face * 0.35) + bevel * (0.17 + second * 0.35) + band * 0.09;
	int tone = int(round(dith(level, pixel, 7.0) * 7.0));
	vec3 base = GLASS_FOIL[tone] / 255.0;
	return mix(base, base.brg, second * smoothstep(0.42, 0.76, level) * 0.24);
}

vec3 thornweave_art(vec3 ink, ivec2 pixel, vec2 normal, vec2 uv, vec2 lean) {
	float green_ink = smoothstep(-0.03, 0.25, ink.g - max(ink.r, ink.b));
	float warm_ink = smoothstep(-0.04, 0.34, ink.r - ink.b);
	float light = lum(ink);
	float field = 1.0 - smoothstep(0.03, 0.93, abs(uv.y - 0.5 + lean.y * 0.46 + lean.x * 0.21));
	float edge = smoothstep(0.08, 0.46, max(0.0, dot(normal, vec2(-0.42 + lean.x * 0.40, -0.79))));
	float gilding = dith(edge * field * smoothstep(0.24, 0.70, light) * (0.11 + warm_ink * 0.22),
		pixel, 12.0);
	float glaze = green_ink * smoothstep(0.14, 0.58, light) * field * 0.12;
	vec3 leaf = mix(ink, max(ink, vec3(0.24, 0.73, 0.40)), dith(glaze, pixel, 12.0));
	return mix(leaf, max(leaf, vec3(1.0, 0.82, 0.36)), gilding);
}

vec3 thornweave_frame(ivec2 pixel, vec2 uv, vec2 outer, vec2 lean) {
	bool horizontal = outer.y <= outer.x;
	float depth = min(outer.x, outer.y);
	float along = horizontal ? float(pixel.x) : float(pixel.y);
	float reverse = horizontal ? step(0.5, uv.y) : step(0.5, uv.x);
	float repeat = face_size.x < 80.0 ? 15.0 : 23.0;
	float shoot = along / repeat + reverse * 0.52;
	float middle = (horizontal ? 10.0 : 2.5) + sin(shoot * PI) * (horizontal ? 1.7 : 0.72);
	float side = mod(floor(shoot), 2.0) * 2.0 - 1.0;
	float leaf_pos = clamp((fract(shoot) - 0.04) / 0.89, 0.0, 1.0);
	float leaf_width = sin(leaf_pos * PI) * 3.2;
	float leaf_axis = middle + side * leaf_pos * (horizontal ? 8.4 : 4.1);
	float leaf_dist = abs(depth - leaf_axis);
	float leaf = step(0.8, leaf_width) * (1.0 - smoothstep(leaf_width - 0.82, leaf_width + 0.37, leaf_dist));
	float vein = leaf * (1.0 - smoothstep(0.24, 0.91, leaf_dist));
	float stem = 1.0 - smoothstep(0.36, 1.28, abs(depth - middle));

	float shift = dot(lean, vec2(-0.42, 0.63));
	float position = (uv.y - 0.5) + abs(uv.x - 0.47) * 0.31 - shift;
	float light = 1.0 - smoothstep(0.02, 0.46, abs(position));
	float branch_light = (horizontal ? uv.x : uv.y) - 0.50 - shift + reverse * 0.16;
	float tip = 1.0 - smoothstep(0.04, 0.25, abs(branch_light));
	float rail = 1.0 - step(0.51, abs(depth - 1.5));
	float stone = 0.5 + 0.5 * sin(depth * 1.05 + sin(along * 0.074) * 1.38);
	float level = 0.16 + 0.10 * light + 0.055 * stone
		+ max(stem * 0.22, leaf * 0.25) + vein * (0.11 + 0.29 * tip) + rail * (0.17 + 0.10 * light);
	int tone = int(round(dith(level, pixel, 7.0) * 7.0));
	return THORN_FOIL[tone] / 255.0;
}

vec3 foil_skin(vec3 ink, ivec2 pixel, bool art, vec2 art_slope) {
	if (inside(text_rect, pixel)) {
		return foil_paper(ink);
	}
	if (!art && !is_frame_ink(ink)) {
		return ink;
	}
	vec2 idle = vec2(sin(TIME * 0.64 + phase) * 0.67, cos(TIME * 0.48 + phase) * 0.37) * idle_amp;
	vec2 lean = mix(idle, tilt, hover);
	lean.x += foil_turn * 0.84;
	if (tier == 4) {
		return eclipse_skin(ink, pixel, art, art_slope, lean);
	}

	vec2 at = vec2(pixel) + 0.5;
	if (art) {
		vec2 uv = (at - art_rect.xy) / (art_rect.zw - art_rect.xy);
		if (tier == 5) {
			return thornweave_art(ink, pixel, art_slope, uv, lean);
		}
		return tideglass_art(ink, pixel, art_slope, uv, lean);
	}
	vec2 uv = at / face_size;
	vec2 outer = min(at, face_size - at);
	if (tier == 5) {
		return thornweave_frame(pixel, uv, outer, lean);
	}
	return tideglass_frame(pixel, uv, outer, lean);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	bool face = abs(TEXTURE_PIXEL_SIZE.x * face_size.x - 1.0) < 0.01 && abs(TEXTURE_PIXEL_SIZE.y * face_size.y - 1.0) < 0.01;
	if (tier == 0 || !face) {
		COLOR = base * vertex_colour;
	} else if (tier >= 4 && tier <= 6) {
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
