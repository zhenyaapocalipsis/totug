shader_type canvas_item;
// HsPlay берёт этот код и делает варианты смешивания (blend_add, blend_mul).
render_mode blend_mix;

// Частица/плоскость эффекта Hearthstone (HsPlay) в пиксель-арте: текстура рисуется в
// сетке игры (960x540), прозрачность — ступенями с узором Байера по пикселям экрана,
// цвет — тоже ступенями: мягкие края и градиенты становятся пиксельными.
//   alpha_mode 1 — яркость текстуры служит прозрачностью (ColorAsAlpha у Hearthstone);
//   kind 2 — умножение (тень): там, где частица непрозрачна, картинка под ней
//   умножается на её цвет.

uniform int alpha_mode = 0;
uniform int kind = 0;
uniform float alpha_steps = 5.0;
uniform float colour_steps = 14.0;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer(vec2 px) {
	int x = int(mod(px.x, 4.0));
	int y = int(mod(px.y, 4.0));
	return (BAYER[y * 4 + x] + 0.5) / 16.0;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (alpha_mode == 1) {
		t = vec4(1.0, 1.0, 1.0, t.r * t.a);
	}
	vec4 c = t * COLOR;
	float b = bayer(floor(FRAGCOORD.xy));
	c.a = clamp(floor(clamp(c.a, 0.0, 1.0) * alpha_steps + b) / alpha_steps, 0.0, 1.0);
	c.rgb = floor(c.rgb * colour_steps + b) / colour_steps;
	if (kind == 2) {
		c.rgb = mix(vec3(1.0), clamp(c.rgb, 0.0, 1.0), c.a);
		c.a = 1.0;
	}
	COLOR = c;
}
