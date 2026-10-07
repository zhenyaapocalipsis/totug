shader_type canvas_item;

// Свет щупалец CardFx: текстура тела без запечённого света (CardFx._flatten), а
// освещение считается здесь, от одного источника сверху-слева, по нормали
// цилиндра. Вершинный цвет тела несёт данные, а не цвет:
//   r — сторона поперёк тела (0 — левый край полоски, 1 — правый),
//   g, b — нормаль полоски в плоскости экрана (x, y из -1..1 в 0..1),
//   a — прозрачность (перекрытие шва плитки).
// Нетекстурированное (обводка, тень, капли — белая текстура 1x1) рисуется как есть.
//
// Как в рисованном пиксель-арте: свет меняет только яркость, а цвет берётся из палитры
// самого спрайта (palette: яркость -> цвет), поэтому тело остаётся в своих цветах.
// Рисунок колец главный; влажные блики — на гребнях колец, а не линией вдоль тела.

uniform vec3 light_dir = vec3(-0.5, -0.7, 0.55);
uniform sampler2D palette : filter_nearest;

varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (TEXTURE_PIXEL_SIZE.x > 0.2) {
		COLOR = tex * vcol;
	} else {
		float s = clamp(vcol.r * 2.0 - 1.0, -1.0, 1.0);
		vec2 n2 = vcol.gb * 2.0 - 1.0;
		vec3 n = normalize(vec3(n2 * s, sqrt(max(1.0 - s * s, 0.0)) + 0.001));
		vec3 l = normalize(light_dir);
		float diff = dot(n, l);
		float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		float lit = lum * mix(0.45, 1.12, smoothstep(-0.7, 0.9, diff));
		float ridge = smoothstep(0.25, 0.45, lum);
		float spec = pow(max(dot(n, normalize(l + vec3(0.0, 0.0, 1.0))), 0.0), 20.0) * ridge;
		lit += spec * 0.35;
		vec3 col = texture(palette, vec2(clamp(lit, 0.0, 0.999), 0.5)).rgb;
		COLOR = vec4(col, tex.a * vcol.a);
	}
}
