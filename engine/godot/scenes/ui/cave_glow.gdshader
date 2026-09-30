shader_type canvas_item;

// Оживление пещеры под доской (CavePainter.paint_layers): маска glow того же
// размера, что картинка. R — лава и огонь: пульсируют волной, как текущая
// лава; G — туман: светлая дымка плывёт; B — кристаллы, руны, огоньки:
// редкие вспышки, у каждого пикселя своя фаза. Всё ступенчато (STEPS), чтобы
// оставаться пиксель-артом, а не мягким свечением.

uniform sampler2D glow : filter_nearest;
uniform float strength = 1.0;
const float STEPS = 3.0;
// огненная лесенка из палитры CavePainter.PALETTE: 5a1c10 9a3414 d8641c f8a030 fff0a0
const vec3 LAVA[5] = vec3[5](vec3(0.353, 0.110, 0.063), vec3(0.604, 0.204, 0.078),
	vec3(0.847, 0.392, 0.110), vec3(0.973, 0.627, 0.188), vec3(1.0, 0.941, 0.627));

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float stepped(float v) {
	return floor(clamp(v, 0.0, 1.0) * STEPS + 0.5) / STEPS;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec4 m = texture(glow, UV);
	vec2 px = floor(UV * vec2(textureSize(TEXTURE, 0)));
	float t = TIME;

	// лавовое озеро (A = 0.5): цикл палитры — яркость пикселя сдвигается по
	// огненной лесенке LAVA бегущей волной, полосы текут по диагонали
	bool flows = m.a > 0.25 && m.a < 0.75;
	if (flows) {
		float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
		float wave = sin(t * 1.8 - px.x * 0.22 - px.y * 0.13) + 0.6 * sin(t * 1.1 + px.x * 0.07 - px.y * 0.19);
		float idx = clamp(floor(lum * 5.0 + wave * 1.2 + 0.5), 0.0, 4.0);
		vec3 ramp = LAVA[int(idx)];
		c.rgb = mix(c.rgb, ramp, 0.85 * strength);
	} else {
		// факелы, жаровни, трещины: волна + мелкая дрожь пламени
		float wave = 0.5 + 0.5 * sin(t * 1.3 - px.x * 0.18 - px.y * 0.11);
		float flicker = 0.5 + 0.5 * sin(t * 9.0 + hash(floor(px / 3.0)) * 6.28);
		float fire = m.r * stepped(wave * 0.7 + flicker * 0.3);
		c.rgb += fire * vec3(0.28, 0.13, 0.03) * strength;
	}

	// туман: две бегущие полосы, светлая дымка поверх
	float fog = 0.5 + 0.5 * sin(px.x * 0.09 + t * 0.6) * sin(px.y * 0.13 - t * 0.35 + px.x * 0.03);
	c.rgb = mix(c.rgb, vec3(0.72, 0.78, 0.9), m.g * stepped(fog) * 0.3 * strength);

	// искры: у каждого пикселя своя фаза, вспыхивает ненадолго
	float phase = fract(t * 0.35 + hash(px));
	float spark = m.b * step(0.9, phase) * (1.0 - (phase - 0.9) * 10.0);
	c.rgb += stepped(spark) * vec3(0.4, 0.35, 0.5) * strength;

	COLOR = c;
}
