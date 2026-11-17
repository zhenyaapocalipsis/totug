// Образы карт (SkinCollection). Индексы 1–3 — Faerie Fire, Gilded и Prism,
// 4–7 — Magma Rift, Frostshard, Void Eclipse и Thornweave.
//
// Всё считается по пикселям карты (texelFetch), а не экрана: при любом целом
// масштабе пиксели остаются квадратными. У образов 1–3 переходы с дизерингом,
// у фольги — мягкие отражения на сетке пикселей. За краем карты рисуется
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

vec3 foil_skin(vec3 ink, ivec2 pixel, int reg) {
	float l = lum(ink);
	// Печатные знаки и тёмные контуры сохраняют цвет.
	if (reg > 1 && !is_frame_ink(ink)) {
		return ink;
	}
	vec3 base_metal;
	vec3 foil_a;
	vec3 foil_b;
	vec3 mirror;
	vec3 paper_tone;
	vec2 axis;
	float width;
	if (tier == 4) {
		base_metal = vec3(0.19, 0.035, 0.055);
		foil_a = vec3(0.95, 0.16, 0.24);
		foil_b = vec3(1.0, 0.69, 0.33);
		mirror = vec3(1.0, 0.91, 0.69);
		paper_tone = vec3(0.985, 0.875, 0.745);
		axis = vec2(0.86, 0.51);
		width = 0.105;
	} else if (tier == 5) {
		base_metal = vec3(0.041, 0.105, 0.225);
		foil_a = vec3(0.36, 0.44, 1.0);
		foil_b = vec3(0.15, 0.85, 0.99);
		mirror = vec3(0.91, 0.98, 1.0);
		paper_tone = vec3(0.84, 0.92, 0.96);
		axis = vec2(0.77, -0.64);
		width = 0.122;
	} else if (tier == 6) {
		base_metal = vec3(0.107, 0.038, 0.234);
		foil_a = vec3(0.44, 0.33, 1.0);
		foil_b = vec3(0.97, 0.41, 0.79);
		mirror = vec3(0.96, 0.87, 1.0);
		paper_tone = vec3(0.935, 0.87, 0.975);
		axis = vec2(0.94, 0.34);
		width = 0.111;
	} else {
		base_metal = vec3(0.035, 0.16, 0.095);
		foil_a = vec3(0.045, 0.77, 0.53);
		foil_b = vec3(0.88, 0.78, 0.25);
		mirror = vec3(0.99, 0.97, 0.73);
		paper_tone = vec3(0.884, 0.938, 0.792);
		axis = vec2(0.60, -0.80);
		width = 0.133;
	}
	if (reg == 0) {
		// Красится только фон бумаги, печать поверх него сохраняется.
		if (matches_print(ink, vec3(230.0, 217.0, 188.0))) {
			return mix(ink, paper_tone, 0.52);
		}
		if (matches_print(ink, vec3(191.0, 174.0, 136.0))) {
			return mix(ink, paper_tone * 0.79, 0.52);
		}
		return ink;
	}

	vec2 at = vec2(pixel) + 0.5;
	vec2 uv = at / face_size;
	vec2 p = (uv - 0.5) * vec2(1.0, 1.38);
	vec2 idle = vec2(sin(TIME * 0.64 + phase) * 0.67, cos(TIME * 0.48 + phase) * 0.37) * idle_amp;
	vec2 lean = mix(idle, tilt, hover);
	lean.x += foil_turn * 0.84;
	vec4 surface = foil_surface(uv, p);

	// Цветная полоса дифракции и более узкое зеркальное ядро движутся вместе.
	float d = dot(p, axis) - dot(lean, axis * vec2(0.64, 0.48)) + surface.x;
	float broad = foil_lobe(d + 0.07, width * 2.65);
	float key = foil_lobe(d, width) * surface.y;
	float flank = foil_lobe(d - 0.17, width * 0.65) * surface.y;
	float specular = foil_lobe(d + 0.024, width * 0.36) * surface.y;
	float dispersion = smoothstep(-0.17, 0.22, d + surface.w * 0.27 + dot(lean, vec2(0.15, -0.10)));
	vec3 colour = mix(foil_a, foil_b, dispersion);
	if (tier == 6) {
		colour = mix(colour, vec3(0.25, 0.86, 1.0), foil_lobe(d + 0.10 + surface.w * 0.17, 0.085) * 0.70);
	}
	vec3 reflection = mix(colour, mirror, clamp(specular * 0.92 + key * 0.21, 0.0, 1.0));
	float engraved = surface.z * (0.29 + key * 0.55 + flank * 0.34);

	if (reg == 1) {
		// Свет отражают светлые краски и металлизированные штрихи под печатью.
		float ink_light = smoothstep(0.07, 0.78, l);
		float coating = (0.095 + broad * 0.20 + key * 0.38 + flank * 0.16)
			* mix(0.38, 1.0, ink_light);
		vec3 printed = mix(ink, reflection, coating);
		vec3 stamp = mix(colour, mirror, 0.29 + specular * 0.62);
		printed = mix(printed, stamp, engraved * mix(0.09, 0.39, ink_light));
		if (text_rect.z > text_rect.x) {
			float mark = foil_seal(at - (art_rect.zw - vec2(15.0, 11.0)));
			printed = mix(printed, stamp, mark * (0.32 + key * 0.38));
		}
		return printed;
	}

	// Наружный кант и оправка арта печатаются в металле.
	vec2 outer = min(at, face_size - at);
	float edge = min(outer.x, outer.y);
	vec2 from_art = max(art_rect.xy - at, at - art_rect.zw);
	float art_edge = max(from_art.x, from_art.y);
	float rim = 1.0 - smoothstep(0.38, 1.28, abs(edge - 2.2));
	float inner_rim = 1.0 - smoothstep(0.44, 1.36, abs(art_edge - 1.6));
	float trim = max(rim, inner_rim * 0.93);
	float relief = max(trim * 0.76, engraved);
	vec3 metal = mix(ink * 0.50, base_metal, 0.78);
	metal = mix(metal, colour, 0.075 + broad * 0.32 + key * 0.27 + flank * 0.24);
	vec3 etching = mix(colour, reflection, 0.40 + specular * 0.55);
	etching = mix(etching, mirror, 0.13 + relief * 0.25);
	vec3 finish = mix(metal, etching, clamp(relief * 0.76 + specular * 0.46, 0.0, 1.0));
	// Чуть темнее под строкой аспекта, чтобы красная печать читалась на меди.
	float aspect_row = float(text_rect.z > text_rect.x)
		* smoothstep(-14.0, -10.0, at.y - art_rect.y)
		* (1.0 - smoothstep(-4.0, -1.0, at.y - art_rect.y));
	return mix(finish, base_metal, aspect_row * (1.0 - smoothstep(0.48, 0.67, uv.x)) * 0.61);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	bool face = abs(TEXTURE_PIXEL_SIZE.x * face_size.x - 1.0) < 0.01 && abs(TEXTURE_PIXEL_SIZE.y * face_size.y - 1.0) < 0.01;
	if (tier == 0 || !face) {
		COLOR = base * vertex_colour;
	} else if (tier >= 4) {
		ivec2 p = clamp(ivec2(floor(UV / TEXTURE_PIXEL_SIZE)), ivec2(0), ivec2(face_size) - 1);
		vec4 src = texelFetch(TEXTURE, p, 0);
		vec3 c = foil_skin(src.rgb, p, region(TEXTURE, p));
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
