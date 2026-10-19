shader_type canvas_item;
render_mode blend_premul_alpha;

// Универсальный шейдер эффектов Hearthstone (FX/CommonFX) — повторён по параметрам
// материалов: яркость берётся из основной текстуры (бежит по UV, искажается второй
// текстурой), dissolve отсекает её порогом, три цвета раскрашивают как градиент
// (_LastColor -> _MidColor -> _WhiteColor), потом _ColorMul/_ColorAdd и _AlphaMul;
// маска по UV меша (_VertexMaskUVScaleOffset) проявляет и гасит его вдоль v.
// Смешивание — премультиплицированное: тёмное с прозрачностью темнит, яркое светит.
// Пиксель-арт: прозрачность и цвет ступенями с узором Байера в сетке игры.

uniform sampler2D main_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D second_tex : repeat_enable, filter_linear_mipmap;
uniform bool has_second = false;
// UV меша — как в Unity (v вверх); у частиц — кусок текстуры (уже как в Godot)
uniform bool unity_uv = true;
uniform vec4 main_st = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec2 scroll = vec2(0.0);
uniform bool clamp_uv = false;
uniform vec4 second_st = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec2 second_speed = vec2(0.0);
uniform float noise_force = 0.0;
uniform int second_mode = 0;
uniform int dissolve = 0;
uniform float dissolve_factor = 0.0;
uniform float dissolve_smooth = 0.1;
uniform bool coloring = true;
uniform vec4 white_color : source_color = vec4(1.0);
uniform vec4 mid_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 last_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float mid_pos = 0.5;
uniform vec4 tint : source_color = vec4(1.0);
uniform float color_mul = 1.0;
uniform float color_add = 0.0;
uniform float alpha_mul = 1.0;
uniform float min_alpha = 0.0;
uniform bool vmask = false;
uniform vec4 vmask_st = vec4(1.0, 1.0, 0.0, 0.0);
uniform float time = 0.0;
uniform float fade = 1.0;
uniform float alpha_steps = 6.0;
uniform float colour_steps = 16.0;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer(vec2 px) {
	int x = int(mod(px.x, 4.0));
	int y = int(mod(px.y, 4.0));
	return (BAYER[y * 4 + x] + 0.5) / 16.0;
}

vec4 sample_unity(sampler2D tex, vec2 uv) {
	return texture(tex, unity_uv ? vec2(uv.x, 1.0 - uv.y) : uv);
}

void fragment() {
	vec2 uv = UV;
	vec2 suv = uv * second_st.xy + second_st.zw + second_speed * time;
	vec4 s = has_second ? sample_unity(second_tex, suv) : vec4(1.0);
	vec2 muv = unity_uv ? uv * main_st.xy + main_st.zw + scroll * time : uv;
	if (second_mode == 3 && has_second) {
		muv += (s.rg - 0.5) * noise_force * 0.2;
	}
	if (clamp_uv && (muv.x < 0.0 || muv.x > 1.0 || muv.y < 0.0 || muv.y > 1.0)) {
		discard;
	}
	vec4 m = sample_unity(main_tex, muv);
	float v = m.r * m.a;
	if (second_mode == 1 && has_second) {
		v *= s.r;
	} else if (second_mode == 2 && has_second) {
		v = clamp(v + s.r * 0.5, 0.0, 1.0);
	}
	float a = v;
	if (dissolve == 1) {
		a *= smoothstep(dissolve_factor, dissolve_factor + max(dissolve_smooth, 0.01), v);
	} else if (dissolve == 2 && has_second) {
		a *= smoothstep(dissolve_factor, dissolve_factor + max(dissolve_smooth, 0.01), s.r);
	}
	vec3 col = vec3(v);
	if (coloring) {
		col = v > mid_pos
			? mix(mid_color.rgb, white_color.rgb, (v - mid_pos) / max(1.0 - mid_pos, 0.001))
			: mix(last_color.rgb, mid_color.rgb, v / max(mid_pos, 0.001));
	}
	col = max(col * tint.rgb * color_mul + color_add, vec3(0.0));
	float alpha = clamp(max(a, min_alpha * step(0.001, a)) * alpha_mul, 0.0, 1.0);
	if (vmask) {
		// окно 0..1 вдоль v меша, смещение w проводит его по мешу (проявляет и гасит)
		float m = uv.y * vmask_st.y + vmask_st.w;
		alpha *= smoothstep(0.0, 0.15, m) * (1.0 - smoothstep(0.85, 1.0, m));
	}
	alpha *= COLOR.a * tint.a * fade;
	col *= COLOR.rgb;
	float b = bayer(floor(FRAGCOORD.xy));
	alpha = clamp(floor(alpha * alpha_steps + b) / alpha_steps, 0.0, 1.0);
	col = floor(col * colour_steps + b) / colour_steps;
	COLOR = vec4(col * alpha, alpha);
}
