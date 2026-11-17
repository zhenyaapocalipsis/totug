// Образы карт (SkinCollection). Индексы 1–3 — Faerie Fire, Gilded и Prism,
// 4–7 — Magma Rift, Frostshard, Void Eclipse и Thornweave.
//
// Всё считается по пикселям карты (texelFetch), а не экрана: при любом целом
// масштабе пиксели остаются квадратными. Переходы — дизерингом Байера, без
// плавных градиентов. Эффект не выходит за края карты: снаружи рисуется
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

// Ломаный разлом проходит по диагонали. Тепло бежит по трещинам снизу вверх.
float rift_distance(vec2 q) {
	float segment = q.y * 8.0;
	float bend = 0.09 * abs(fract(segment) * 2.0 - 1.0) + 0.022 * sin(segment * 2.1);
	return abs(fract(q.x * 1.8 + q.y * 0.74 + bend) - 0.5);
}

vec2 magma_rift(vec2 q, float t) {
	float main_rift = rift_distance(q);
	float branch = rift_distance(vec2(q.x + 0.19, 1.0 - q.y));
	branch += 0.12 * smoothstep(0.08, 0.28, abs(q.x - 0.5));
	float seam = min(main_rift, branch + 0.008);
	float surge = 0.32 + 0.68 * pow(0.5 + 0.5 * sin(q.y * 10.0 + q.x * 3.0 + t * 2.8), 3.0);
	float glow = (1.0 - smoothstep(0.012, 0.15, seam)) * surge;
	float core = (1.0 - smoothstep(0.008, 0.033, seam)) * (0.35 + 0.65 * surge);
	return vec2(glow, core);
}

// Ледяные осколки с двумя гранями и коротким шлейфом, каждый столбец падает в своём ритме.
vec2 frost_shards(vec2 q, float t) {
	float column = floor(q.x * 6.0);
	float drift = hash(vec2(column, 7.0));
	float fall = q.y * 2.2 - t * (0.44 + 0.33 * drift) + drift * 3.0;
	float seed = hash(vec2(column, floor(fall)));
	vec2 d = vec2(fract(q.x * 6.0) - mix(0.24, 0.76, seed), fract(fall) - 0.67);
	float ridge = d.x + d.y * 0.38;
	float facet = abs(ridge) * 1.4 + abs(d.y) * 0.78;
	float shard = 1.0 - smoothstep(0.13, 0.21, facet);
	float tail = (1.0 - smoothstep(0.025, 0.14, abs(d.x + d.y * 0.18)))
		* smoothstep(-0.53, 0.0, d.y) * step(d.y, 0.0);
	float flash = 0.74 + 0.26 * sin(t * 2.1 + seed * TAU);
	return vec2(max(shard, tail * 0.48), shard * mix(0.26, 0.99, step(ridge, 0.0)) * flash);
}

// По пересекающимся эллипсам идут магнитные дуги и их яркие головки.
vec2 orbit_arc(vec2 p, float stretch, float angle) {
	vec2 ellipse = p * vec2(1.0, stretch);
	vec2 head = vec2(cos(angle), sin(angle));
	float radius = length(ellipse);
	float alignment = dot(ellipse, head) / max(radius, 0.001);
	float arc = smoothstep(-0.48, 0.97, alignment);
	float rim = abs(radius - 1.0);
	return vec2((1.0 - smoothstep(0.015, 0.13, rim)) * arc,
		(1.0 - smoothstep(0.02, 0.07, rim)) * mix(0.3, 1.0, smoothstep(0.81, 1.0, alignment)) * arc);
}

vec2 void_eclipse(vec2 q, float t, vec2 lean) {
	vec2 p = (q - vec2(0.5, 0.51) - lean * 0.07) * vec2(2.6, 3.4);
	vec2 primary = orbit_arc(vec2(p.x, p.y - p.x * 0.78), 1.84, t * 1.42);
	vec2 secondary = orbit_arc(vec2(p.x, p.y + p.x * 0.73), 2.05, -t * 1.68 + 1.4);
	float halo = (1.0 - smoothstep(0.04, 0.32, abs(length(p * vec2(1.1, 1.08)) - 0.69))) * 0.16;
	return max(max(primary, secondary), vec2(halo, 0.0));
}

// Две лозы цепляются за края арта. Вслед за растущим кончиком раскрываются листья.
vec2 thornweave(vec2 q, float t) {
	float side = step(0.5, q.x);
	float x = min(q.x, 1.0 - q.x);
	float stem_x = 0.058 + 0.034 * sin(q.y * 12.0 + side * 3.0 + sin(t * 0.95) * 0.75);
	float stem = 1.0 - smoothstep(0.006, 0.027, abs(x - stem_x));
	float stem_core = 1.0 - smoothstep(0.0, 0.012, abs(x - stem_x));
	float tip = fract(t * 0.23 + side * 0.47);
	float growth = fract(q.y + tip);
	float pulse = smoothstep(0.0, 0.036, growth) * (1.0 - smoothstep(0.025, 0.21, growth));
	float offset = fract(q.y * 4.3 + side * 0.45) - 0.5;
	float leaf_x = (x - stem_x) / mix(0.128, 0.20, pulse);
	float leaf_size = max(0.0, 1.0 - abs(leaf_x * 2.0 - 1.0));
	float leaf_y = abs(offset + leaf_x * 0.33);
	float leaf = (1.0 - smoothstep(0.16, 0.23, leaf_y / max(leaf_size, 0.001))) * step(0.01, leaf_x);
	float vein = 1.0 - smoothstep(0.006, 0.060, leaf_y);
	return vec2(max(stem * 0.64, leaf * 0.92) * (0.61 + pulse * 0.39),
		max(stem_core * 0.52, leaf * vein) * (0.45 + pulse * 0.55));
}

vec3 elemental_skin(vec3 c, ivec2 p, int reg) {
	// Текст, значки и тёмные обводки сохраняют исходный контраст.
	if (reg != 1 && reg != 2) {
		return c;
	}
	float t = TIME + phase * 0.7;
	vec2 q = (vec2(p) + 0.5 - art_rect.xy) / (art_rect.zw - art_rect.xy);
	vec2 grid = (vec2(p) + 0.5) / face_size * vec2(96.0, 138.0);
	vec3 dark;
	vec3 colour;
	vec3 hot;
	vec2 energy;
	float inlay;
	if (tier == 4) {
		dark = vec3(0.15, 0.025, 0.038);
		colour = vec3(0.97, 0.12, 0.09);
		hot = vec3(1.0, 0.72, 0.32);
		energy = magma_rift(q, t);
		inlay = 1.0 - smoothstep(0.028, 0.105, rift_distance(grid / 42.0));
	} else if (tier == 5) {
		dark = vec3(0.037, 0.10, 0.23);
		colour = vec3(0.15, 0.55, 1.0);
		hot = vec3(0.77, 0.95, 1.0);
		energy = frost_shards(q, t);
		vec2 facet = fract(vec2(grid.x + grid.y * 0.6, grid.x - grid.y * 0.6) / 13.0);
		inlay = smoothstep(0.65, 0.94, facet.x) * (0.25 + facet.y * 0.75);
	} else if (tier == 6) {
		dark = vec3(0.12, 0.041, 0.23);
		colour = vec3(0.66, 0.26, 1.0);
		hot = vec3(0.95, 0.66, 1.0);
		energy = void_eclipse(q, t, tilt * hover);
		vec2 mark = abs(fract(grid / 10.0) - 0.5);
		inlay = (1.0 - smoothstep(0.045, 0.145, abs(mark.x + mark.y - 0.38)))
			* (0.55 + 0.45 * sin(t * 2.1 - floor(grid.x / 10.0) * 0.85));
	} else {
		dark = vec3(0.041, 0.16, 0.104);
		colour = vec3(0.32, 0.78, 0.19);
		hot = vec3(0.83, 1.0, 0.43);
		energy = thornweave(q, t);
		float vein = abs(fract((grid.y + abs(fract(grid.x / 16.0) - 0.5) * 16.0) / 11.0) - 0.5);
		inlay = 1.0 - smoothstep(0.02, 0.14, vein);
	}
	if (reg == 2) {
		float shine = 0.5 + 0.5 * sin(grid.x * 0.065 - grid.y * 0.074 + t * 1.35);
		float edge = min(min(grid.x, 96.0 - grid.x), min(grid.y, 138.0 - grid.y));
		float relief = 0.05 + lum(c) * 0.4 + inlay * (0.18 + shine * 0.19);
		relief += (1.0 - smoothstep(0.6, 2.8, abs(edge - 1.8))) * (0.14 + shine * 0.32);
		return mix(dark, colour, dith(relief, p, 7.0));
	}
	vec3 dyed = mix(c, c * 0.74 + colour * (0.08 + lum(c) * 0.20), 0.67);
	dyed = mix(dyed, colour, dith(energy.x, p, 5.0) * 0.63);
	return mix(dyed, hot, dith(energy.y, p, 5.0) * 0.83);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	bool face = abs(TEXTURE_PIXEL_SIZE.x * face_size.x - 1.0) < 0.01 && abs(TEXTURE_PIXEL_SIZE.y * face_size.y - 1.0) < 0.01;
	if (tier == 0 || !face) {
		COLOR = base * vertex_colour;
	} else if (tier >= 4) {
		ivec2 p = clamp(ivec2(floor(UV / TEXTURE_PIXEL_SIZE)), ivec2(0), ivec2(face_size) - 1);
		vec4 src = texelFetch(TEXTURE, p, 0);
		vec3 c = elemental_skin(src.rgb, p, region(TEXTURE, p));
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
