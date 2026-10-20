shader_type canvas_item;
render_mode blend_premul_alpha;

// Пиксельная часть шейдера Hearthstone FX/CommonFX — переписана по его коду (DXBC из
// essential_base_global-shader-0, варианты по ключевым словам материала), смешивание
// как у него: One, OneMinusSrcAlpha. Вершинную часть (UV с прокруткой, маска по
// вершинам, удвоение цвета, порог растворения) считает HsPlay на CPU и передаёт:
//   UV       — UV основной текстуры (как в Unity: v вверх);
//   COLOR    — цвет вершины после вершинного шейдера (o3);
//   CUSTOM0  — xy: UV второй текстуры, z: порог растворения (o4.x), w: альфа вершины (o2.w);
//   CUSTOM1  — второй цвет (o2) для _SECONDTEXTURE_ADD.

uniform sampler2D main_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D second_tex : repeat_enable, filter_linear_mipmap;
uniform bool has_second = false;
uniform bool rgbr = true;               // _TEXTURETYPE_RGBR: альфа — красный канал
uniform bool ramp = false;              // _COLORING_RAMP
uniform int second_mode = 0;            // 0 нет, 1 MASK, 2 ADD, 3 NOISEUV
uniform int dissolve = 0;               // 0 нет, 1 MAINALPHA, 2 SECONDALPHA
uniform float clamp_uv = 0.0;           // _ClampUV
uniform float second_clamp = 0.0;       // _SecondTexClampUV
uniform vec2 noise_force = vec2(0.0);   // _SecondTexSpeed_NoiseForce.zw
uniform float color_mul = 1.0;
uniform float color_add = 0.0;
uniform float premul = 1.0;             // _PremultipliedRGBTexture
uniform vec3 white_color = vec3(1.0);
uniform vec3 mid_color = vec3(0.5);
uniform vec3 last_color = vec3(0.0);
uniform float mid_pos = 0.5;
uniform vec4 color2 = vec4(1.0);        // _Color2 (a — сила маски второй текстурой)
uniform float color_mul2 = 1.0;
uniform float dissolve_factor = 0.0;
uniform float smoothness = 0.1;
uniform float fade = 1.0;
// пиксель-арт: цвет ступенями (0 — без ступеней)
uniform float colour_steps = 0.0;
// Hearthstone считает цвет в линейном пространстве (URP Linear): sRGB-текстуры и цвета
// материала переводятся в линейные, цвета вершин — нет; результат — обратно в sRGB
uniform bool linear_space = true;
// обратный перевод результата в sRGB (смешивание у нас всё равно в гамме)
uniform bool linear_out = false;
// счёт в гамме: предел яркости до перевода в линейный буфер
uniform float gamma_clip = 1.0;

varying vec4 custom0;
varying vec4 custom1;

void vertex() {
	custom0 = CUSTOM0;
	custom1 = CUSTOM1;
}

vec3 lin(vec3 c) {
	return linear_space ? pow(max(c, vec3(0.0)), vec3(2.2)) : c;
}

vec4 tex_unity(sampler2D t, vec2 uv) {
	vec4 c = texture(t, vec2(uv.x, 1.0 - uv.y));
	return vec4(lin(c.rgb), c.a);
}

// Наш пиксель (960x540) покрывает много текселей: среднее по нему гасит тонкие линии
// (контур карты, кромки огня), а порог растворения их срезает. Берём максимум из четырёх
// выборок внутри пикселя на более мелком уровне мип-карт — как при разрешении HS.
vec4 tex_main(vec2 uv) {
	vec2 d = fwidth(uv) * 0.25;
	vec2 u = vec2(uv.x, 1.0 - uv.y);
	vec4 c = max(max(texture(main_tex, u + vec2(d.x, d.y), -1.5), texture(main_tex, u + vec2(-d.x, d.y), -1.5)),
		max(texture(main_tex, u + vec2(d.x, -d.y), -1.5), texture(main_tex, u + vec2(-d.x, -d.y), -1.5)));
	return vec4(lin(c.rgb), c.a);
}

void fragment() {
	vec2 suv = mix(custom0.xy, clamp(custom0.xy, 0.0, 1.0), second_clamp);
	vec4 s = has_second ? tex_unity(second_tex, suv) : vec4(1.0);
	vec2 muv = UV;
	if (second_mode == 3 && has_second) {
		muv += (s.rg * 2.0 - 1.0) * noise_force;
	}
	muv = mix(muv, clamp(muv, 0.0, 1.0), clamp_uv);
	vec4 t = tex_main(muv);
	float a = rgbr ? t.r : t.a;
	float pa = max(a, premul);
	vec3 c = (t.rgb + color_add) * pa;
	if (ramp) {
		float v = (t.g + color_add) * pa - mid_pos;
		float hi = clamp(v * 5.0, 0.0, 1.0);
		vec3 upper = mix(lin(mid_color), lin(white_color), v / max(1.0 - mid_pos, 1e-4));
		// _MiddlePointPos = 0 (тень дракона): у HS здесь деление на ноль, предел — mid_color
		vec3 lower = mid_pos < 1e-3 ? lin(mid_color)
			: mix(lin(last_color), lin(mid_color), (v + mid_pos) / mid_pos);
		c *= mix(lower, upper, hi);
	}
	vec4 o = vec4(c * color_mul, a);
	float thr = custom0.z;
	if (dissolve == 1) {
		float lo = clamp(thr - smoothness, 0.0, 1.0) - 1e-5;
		float hi = clamp(thr + smoothness, 0.0, 1.0);
		float f = clamp((a - lo) / max(hi - lo, 1e-5), 0.0, 1.0);
		f = f * f * (3.0 - 2.0 * f);
		o *= f;
	} else if (dissolve == 2 && has_second) {
		float d = clamp(s.r - ((thr + dissolve_factor) * 2.0 - 1.0), 0.0, 1.0);
		float e = pow(d, smoothness * 10.0);
		o *= e;
		float edge = pow(max(1.0 - e, 0.0), 10.0) * clamp(o.a * 1e6, 0.0, 1.0) * a;
		o.rgb += lin(color2.rgb) * color_mul2 * edge * custom0.w;
	}
	if (second_mode == 1 && has_second && dissolve != 2) {
		o *= mix(1.0, s.r, color2.a);
	} else if (second_mode == 2 && has_second) {
		o += vec4(s.r, s.g, s.b, s.r) * custom1;
	}
	o *= COLOR;
	o *= fade;
	if (linear_space && linear_out) {
		o.rgb = pow(max(o.rgb, vec3(0.0)), vec3(1.0 / 2.2));
	}
	if (!linear_space) {
		// счёт в гамме (как у HS) -> линейный буфер нашего кадра
		o.rgb = pow(clamp(o.rgb, vec3(0.0), vec3(gamma_clip)), vec3(2.2));
	}
	if (colour_steps > 0.0) {
		o.rgb = floor(o.rgb * colour_steps + 0.5) / colour_steps;
	}
	COLOR = o;
}
