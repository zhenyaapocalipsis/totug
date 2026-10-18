shader_type canvas_item;

// Существо в эффекте уникальной карты (кадр пиксельного спрайта, UniqueFx.sprite):
// - появление/уход «из огня»: пиксели выпадают узором Байера (dissolve 0..1), у кромки
//   растворения — тлеющий ободок цветов ember (как сгорающая бумага в Hearthstone);
// - silhouette 0..1: тёмный силуэт, из которого проступает рисунок;
// - flash 0..1: вспышка белым (удар);
// - rim: подсветка края со стороны света (rim_dir — откуда свет, в пикселях; огонь
//   из пасти, свечение карты) — пиксель, у которого сосед к свету пуст, светлеет;
// - цветная обводка в 1 пиксель (тёмный оттенок соседа, как pix_outline).
// Пиксель узора — пиксель экрана игры (FRAGCOORD на холсте сетки 1).

uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float silhouette : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sil_color : source_color = vec3(0.05, 0.02, 0.06);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec2 rim_dir = vec2(-1.0, -1.0);
uniform vec3 rim_color : source_color = vec3(1.0, 0.55, 0.25);
uniform float rim : hint_range(0.0, 1.0) = 0.0;
uniform vec3 ember_hot : source_color = vec3(1.0, 0.85, 0.45);
uniform vec3 ember_cold : source_color = vec3(0.85, 0.25, 0.12);
uniform vec2 offset = vec2(0.0);
// своя цветная обводка (0 — без неё: у готовых эффектов PixelLab тёмный край уже есть)
uniform float outline = 1.0;
// проявление снизу вверх: wipe 0 — клочьями (сгорает), 1 — снизу вверх с рваной кромкой;
// region_uv — кадр в листе (u0, v0, u1, v1), чтобы знать высоту внутри кадра
uniform float wipe : hint_range(0.0, 1.0) = 0.0;
uniform vec4 region_uv = vec4(0.0, 0.0, 1.0, 1.0);

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer(vec2 px) {
	int x = int(mod(px.x, 4.0));
	int y = int(mod(px.y, 4.0));
	return (BAYER[y * 4 + x] + 0.5) / 16.0;
}

// крупный шум для растворения: клочьями, а не ровным узором
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float blot(vec2 px) {
	vec2 q = floor(px / 6.0);
	vec2 f = fract(px / 6.0);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float n = mix(mix(hash(q), hash(q + vec2(1.0, 0.0)), u.x), mix(hash(q + vec2(0.0, 1.0)), hash(q + vec2(1.0, 1.0)), u.x), u.y);
	return n * 0.75 + bayer(px) * 0.25;
}

bool solid(sampler2D tx, vec2 uv) {
	return texture(tx, uv).a > 0.5;
}

void fragment() {
	vec2 px = floor(FRAGCOORD.xy) + offset;
	vec4 tex = texture(TEXTURE, UV);
	vec2 ts = TEXTURE_PIXEL_SIZE;
	float ly = clamp((UV.y - region_uv.y) / max(region_uv.w - region_uv.y, 0.0001), 0.0, 1.0);
	float d = mix(blot(px), ly * 0.85 + blot(px) * 0.15, wipe);
	if (tex.a > 0.5) {
		if (dissolve > 0.0 && d < dissolve) discard;
		vec3 c = tex.rgb;
		// подсветка края со стороны света
		if (rim > 0.0) {
			vec2 l = normalize(rim_dir);
			if (!solid(TEXTURE, UV + vec2(sign(l.x), 0.0) * ts) || !solid(TEXTURE, UV + vec2(0.0, sign(l.y)) * ts)) {
				c = mix(c, rim_color, rim);
			} else if (!solid(TEXTURE, UV + l * 2.0 * ts)) {
				c = mix(c, rim_color, rim * 0.45);
			}
		}
		c = mix(c, sil_color, silhouette);
		c = mix(c, vec3(1.0), flash);
		// тлеющая кромка растворения
		if (dissolve > 0.0 && d < dissolve + 0.08) {
			c = d < dissolve + 0.035 ? ember_hot : ember_cold;
		}
		COLOR = vec4(c, 1.0);
	} else {
		if (outline < 0.5) discard;
		// обводка: пустой пиксель рядом с непрозрачным (и не растворённым)
		vec4 nb = vec4(0.0);
		vec2 dirs[4] = vec2[4](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));
		for (int i = 0; i < 4; i++) {
			vec4 s = texture(TEXTURE, UV + dirs[i] * ts);
			if (s.a > 0.5 && mix(blot(px + dirs[i]), ly * 0.85 + blot(px + dirs[i]) * 0.15, wipe) >= dissolve) {
				nb = s;
				break;
			}
		}
		if (nb.a < 0.5) discard;
		vec3 o = mix(nb.rgb * vec3(0.26, 0.2, 0.36) + vec3(0.04, 0.02, 0.07), sil_color * 0.5, silhouette);
		COLOR = vec4(o, 1.0);
	}
}
