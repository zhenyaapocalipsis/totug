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

// Микрорельеф закреплён на фольге. x смещает блик, y меняет его силу.
vec2 foil_surface(vec2 uv, vec2 p) {
	if (tier == 4) {
		// Шлифовка меди: длинные бороздки с разной глубиной.
		float grain = dot(uv, vec2(37.0, 29.0)) + 0.17 * sin(dot(uv, vec2(9.0, -14.0)));
		float ridge = sin(grain * TAU);
		float depth = hash(vec2(floor(grain), 8.7));
		return vec2(ridge * 0.022 + (depth - 0.5) * 0.023, mix(0.66, 1.0, depth));
	}
	if (tier == 5) {
		// Развёрнутые в разные стороны, неподвижные треугольные грани.
		vec2 lattice = vec2(uv.x + uv.y * 0.29, uv.y) * vec2(11.0, 14.0);
		vec2 cell = floor(lattice);
		vec2 f = fract(lattice);
		float half_cell = step(f.y, f.x);
		float facet = hash(cell + vec2(0.37, 0.67) * half_cell);
		return vec2((facet - 0.5) * 0.19, mix(0.57, 1.0, facet));
	}
	if (tier == 6) {
		// Гильоше из тонких замкнутых линий, как на гравированной печати.
		float angle = atan(p.y, p.x + 0.00001);
		float radius = length(p);
		float groove = cos(TAU * (radius * 25.0) + 1.5 * sin(angle * 7.0 + radius * 31.0));
		float relief = smoothstep(0.26, 0.95, groove);
		relief *= smoothstep(0.04, 0.14, radius);
		return vec2((relief - 0.3) * 0.042, 0.58 + relief * 0.42);
	}
	// Перламутр: широкие слои с плавной волной и тонкими прожилками.
	float flow = p.y * 8.0 + p.x * 3.2 + 1.35 * sin(p.x * 6.1 - p.y * 2.2);
	float sheen = 0.5 + 0.5 * sin(flow * 2.4 + 0.42 * sin(flow * 7.4));
	return vec2((sheen - 0.5) * 0.151, 0.63 + sheen * 0.37);
}

float foil_lobe(float distance, float width) {
	float x = distance / width;
	return exp(-x * x);
}

vec3 foil_skin(vec3 ink, ivec2 pixel, int reg) {
	// Правила, название и печатные значки не покрыты фольгой.
	if (reg != 1 && reg != 2) {
		return ink;
	}
	vec2 at = vec2(pixel) + 0.5;
	vec2 uv = at / face_size;
	vec2 p = (uv - 0.5) * vec2(1.0, 1.38);
	vec2 idle = vec2(sin(TIME * 0.67 + phase) * 0.57, cos(TIME * 0.51 + phase) * 0.34) * idle_amp;
	vec2 lean = mix(idle, tilt, hover);
	lean.x += foil_turn * 0.82;
	vec2 surface = foil_surface(uv, p);
	vec3 base_metal;
	vec3 foil_a;
	vec3 foil_b;
	vec3 mirror;
	vec2 axis;
	float width;
	if (tier == 4) {
		base_metal = vec3(0.23, 0.047, 0.069);
		foil_a = vec3(0.88, 0.21, 0.32);
		foil_b = vec3(1.0, 0.55, 0.33);
		mirror = vec3(1.0, 0.85, 0.68);
		axis = vec2(0.87, 0.50);
		width = 0.067;
	} else if (tier == 5) {
		base_metal = vec3(0.065, 0.16, 0.30);
		foil_a = vec3(0.24, 0.43, 0.95);
		foil_b = vec3(0.22, 0.77, 0.91);
		mirror = vec3(0.87, 0.95, 1.0);
		axis = vec2(0.75, -0.66);
		width = 0.083;
	} else if (tier == 6) {
		base_metal = vec3(0.19, 0.084, 0.32);
		foil_a = vec3(0.47, 0.42, 0.98);
		foil_b = vec3(0.87, 0.47, 0.91);
		mirror = vec3(0.94, 0.86, 1.0);
		axis = vec2(0.93, 0.36);
		width = 0.075;
	} else {
		base_metal = vec3(0.05, 0.22, 0.145);
		foil_a = vec3(0.16, 0.76, 0.55);
		foil_b = vec3(0.73, 0.82, 0.33);
		mirror = vec3(0.96, 0.97, 0.79);
		axis = vec2(0.59, -0.81);
		width = 0.098;
	}
	// На наклоне узкое отражение скользит по более широкому цветному блику.
	float d = dot(p, axis) - dot(lean, axis * vec2(0.56, 0.44)) + surface.x;
	float broad = foil_lobe(d + 0.055, width * 2.55) * surface.y;
	float key = foil_lobe(d, width) * surface.y;
	float second = foil_lobe(d - 0.16, width * 0.48) * surface.y;
	float dispersion = smoothstep(-0.17, 0.15, d + dot(lean, vec2(0.12, -0.085)));
	vec3 colour = mix(foil_a, foil_b, dispersion);
	float specular = foil_lobe(d + 0.012, width * 0.45) * surface.y;
	vec3 reflection = mix(colour, mirror, 0.20 * key + 0.77 * specular);
	if (reg == 1) {
		// Полупрозрачные печатные краски оставляют в светлых участках больше отражения.
		float ink_light = smoothstep(0.06, 0.72, lum(ink));
		float amount = (broad * 0.23 + key * 0.37 + second * 0.09) * mix(0.52, 1.0, ink_light);
		return mix(ink, reflection, amount);
	}
	// Прикатанный кант ловит свет по краям листа и вокруг иллюстрации.
	vec2 outer = min(at, face_size - at);
	float edge = min(outer.x, outer.y);
	vec2 from_art = max(art_rect.xy - at, at - art_rect.zw);
	float art_edge = max(from_art.x, from_art.y);
	float bevel = 1.0 - smoothstep(0.5, 2.0, abs(art_edge - 1.1));
	float rim = 1.0 - smoothstep(0.3, 1.7, abs(edge - 1.5));
	float trim = max(rim, bevel * 0.82);
	vec3 metal = mix(ink * 0.42, base_metal, 0.65);
	metal = mix(metal, colour, 0.09 + broad * 0.31 + trim * 0.28 + surface.y * 0.07);
	return mix(metal, reflection, min(0.96, key * (0.60 + trim * 0.36) + second * (0.15 + trim * 0.17)));
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
