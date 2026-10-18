shader_type canvas_item;
render_mode unshaded;

// Экранный проход постановки уникальной карты (UniqueFx.ScreenFx): берёт уже
// нарисованный экран (доска, затемнение, карта, слои эффекта) и меняет его целиком.
// Всё в сетке игры (game_size, 960x540): сдвиги — только на целые пиксели игры,
// переходы тонов — узором Байера, время — ступенями (20 к/с), как в пиксель-арте.
//
// - wave: ударная волна от рёва — кольцо преломляет картинку (сдвиг по радиусу);
// - heat: горячий воздух над картой — строки дрожат на пиксель;
// - art_glow: красное на арте карты раскаляется (дракон на арте «вспыхивает»);
// - shadow: тень огромных крыльев проносится по экрану (силуэт сверху, край —
//   растворяется узором: тень от высоко летящего — мягкая);
// - wind: полосы ветра за тенью;
// - sky: свет огненного вала на доске (вокруг band_y);
// - vignette: края экрана темнеют и уходят в багровый.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 game_size = vec2(960.0, 540.0);
uniform float time = 0.0;
uniform vec4 card = vec4(402.0, 103.0, 176.0, 254.0);
uniform vec4 art = vec4(406.0, 124.0, 168.0, 110.0);

uniform float wave_t = -1.0;
uniform vec2 wave_c = vec2(490.0, 230.0);
uniform float wave_r = 520.0;
uniform float heat = 0.0;
uniform float art_glow = 0.0;
uniform float shadow_x = -9999.0;
uniform float shadow_y = 270.0;
uniform float shadow_scale = 1.0;
uniform float band_y = 270.0;
uniform float wind = 0.0;
uniform float sky = 0.0;
uniform float vignette = 0.0;
uniform vec3 tint : source_color = vec3(0.55, 0.12, 0.10);

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer(vec2 px) {
	int x = int(mod(px.x, 4.0));
	int y = int(mod(px.y, 4.0));
	return (BAYER[y * 4 + x] + 0.5) / 16.0;
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

// Расстояние до отрезка с радиусом r (капсула); < 0 — внутри.
float capsule(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

float ellipse(vec2 p, vec2 c, vec2 r) {
	vec2 q = (p - c) / r;
	return (length(q) - 1.0) * min(r.x, r.y);
}

// Знаковое расстояние до многоугольника из 9 точек (вогнутого тоже) — приём Иниго
// Килеса (sdPolygon): минимум расстояний до сторон, знак — по чётности пересечений.
float poly9(vec2 p, vec2 v[9]) {
	float d = dot(p - v[0], p - v[0]);
	float s = 1.0;
	for (int i = 0, j = 8; i < 9; j = i, i++) {
		vec2 e = v[j] - v[i];
		vec2 w = p - v[i];
		vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
		d = min(d, dot(b, b));
		bvec3 c = bvec3(p.y >= v[i].y, p.y < v[j].y, e.x * w.y > e.y * w.x);
		if (all(c) || all(not(c))) s *= -1.0;
	}
	return s * sqrt(d);
}

// Силуэт дракона сверху, летит влево (голова в -x), время tm — живой: крылья машут
// (размах сжимается при подъёме и опускании, кончики заносятся вперёд на взмахе
// вниз), по хвосту бежит волна, шея и голова покачиваются, тело чуть виляет.
float dragon(vec2 p, float tm) {
	float ph = tm * 6.2831 * 1.3;
	float span = 0.42 + 0.58 * (0.5 + 0.5 * cos(ph));
	float sweep = sin(ph) * 34.0;
	float sway = sin(ph + 1.2) * 5.0;
	p.y -= sway;
	float d = ellipse(p, vec2(0.0, 0.0), vec2(120.0, 26.0));
	float nb = sin(tm * 4.0) * 10.0;
	d = min(d, capsule(p, vec2(-110.0, 0.0), vec2(-190.0, -6.0 + nb * 0.6), 14.0));
	d = min(d, ellipse(p, vec2(-215.0, -8.0 + nb), vec2(34.0, 16.0)));
	// хвост: пять звеньев, волна бежит от тела к кончику
	vec2 a = vec2(110.0, 0.0);
	for (int i = 1; i <= 5; i++) {
		float fi = float(i);
		vec2 b = vec2(110.0 + fi * 52.0, sin(tm * 5.5 - fi * 0.9) * 7.0 * fi);
		d = min(d, capsule(p, a, b, 13.0 - fi * 2.0));
		a = b;
	}
	for (int s = -1; s <= 1; s += 2) {
		float k = float(s) * span;
		float fs = float(s);
		vec2 v[9] = vec2[9](
			vec2(-40.0, 14.0 * fs), vec2(-12.0 - sweep * 0.3, 130.0 * k), vec2(-62.0 - sweep, 300.0 * k),
			vec2(-4.0 - sweep * 0.7, 232.0 * k), vec2(40.0 - sweep * 0.8, 282.0 * k), vec2(66.0 - sweep * 0.5, 196.0 * k),
			vec2(122.0 - sweep * 0.6, 212.0 * k), vec2(96.0 - sweep * 0.3, 104.0 * k), vec2(90.0, 24.0 * fs));
		d = min(d, poly9(p, v));
	}
	return d;
}

void fragment() {
	vec2 px = floor(SCREEN_UV * game_size);
	vec2 off = vec2(0.0);
	float t = time;

	// ударная волна: кольцо сдвигает картинку наружу, к краю — слабее
	if (wave_t >= 0.0 && wave_t < 1.0) {
		float ease = 1.0 - pow(1.0 - wave_t, 3.0);
		float r = wave_r * ease;
		float th = mix(22.0, 6.0, wave_t);
		vec2 dv = px + 0.5 - wave_c;
		float d = length(dv);
		float k = 1.0 - abs(d - r) / th;
		if (k > 0.0) {
			off -= normalize(dv) * floor(k * 4.0 * (1.0 - wave_t) + 0.5);
		}
	}
	// горячий воздух над картой: строки дрожат на пиксель
	if (heat > 0.0) {
		float top = card.y - 80.0;
		if (px.x > card.x - 12.0 && px.x < card.x + card.z + 12.0 && px.y > top && px.y < card.y + 24.0) {
			float fade = smoothstep(top, card.y - 10.0, px.y) * heat;
			float n = sin(px.y * 0.45 + t * 11.0 + vnoise(vec2(px.y * 0.2, t * 3.0)) * 6.0);
			off.x += floor(n * fade * 1.6 + 0.5);
		}
	}
	vec2 uv = (off.x == 0.0 && off.y == 0.0) ? SCREEN_UV : (px + off + 0.5) / game_size;
	vec3 col = texture(screen_tex, uv).rgb;

	// красное на арте раскаляется: ступенями, сильнее у самых красных пикселей
	if (art_glow > 0.0 && px.x >= art.x && px.x < art.x + art.z && px.y >= art.y && px.y < art.y + art.w) {
		float red = col.r - max(col.g, col.b);
		float g = smoothstep(0.08, 0.35, red) * art_glow;
		float q = floor(g * 3.0 + bayer(px) * 0.999) / 3.0;
		col += vec3(1.0, 0.5, 0.18) * q * 0.55;
	}

	// тень крыльев
	if (shadow_x > -2000.0) {
		vec2 sp = px - vec2(shadow_x, shadow_y);
		float d = dragon(sp / shadow_scale, t) * shadow_scale;
		float k = clamp(-d / 14.0, 0.0, 1.0);
		if (k > bayer(px) * 0.999) {
			col *= mix(vec3(0.5, 0.44, 0.56), vec3(0.16, 0.13, 0.2), step(0.5, k));
		}
		// ветер за тенью: короткие светлые штрихи летят влево
		if (wind > 0.0) {
			float row = floor(px.y / 3.0);
			float x0 = shadow_x + 160.0 + hash(vec2(row, 7.0)) * 420.0;
			float len = 18.0 + hash(vec2(row, 3.0)) * 50.0;
			if (hash(vec2(row, 1.0)) > 0.86 && mod(px.y, 3.0) < 1.0 && px.x > x0 && px.x < x0 + len) {
				col = mix(col, vec3(0.75, 0.68, 0.72), 0.35 * wind);
			}
		}
	}

	// свет огненного вала на доске: три полосы вокруг band_y, стыки — узором
	if (sky > 0.0) {
		float g = (1.0 - abs(px.y - band_y) / 130.0) * sky;
		g += (vnoise(vec2(px.x / 60.0, t * 0.8)) - 0.5) * 0.25 * sky;
		float q = floor(clamp(g, 0.0, 1.0) * 3.0 + bayer(px) * 0.999) / 3.0;
		col += vec3(0.85, 0.32, 0.08) * q * 0.45;
	}

	// виньетка с багровым оттенком: 4 ступени
	if (vignette > 0.0) {
		vec2 c = (px - game_size * 0.5) / (game_size * 0.5);
		float v = smoothstep(0.4, 1.2, length(c * vec2(1.0, 0.8))) * vignette;
		float q = floor(v * 4.0 + bayer(px) * 0.999) / 4.0;
		col = mix(col, col * tint, q);
	}

	COLOR = vec4(col, 1.0);
}
