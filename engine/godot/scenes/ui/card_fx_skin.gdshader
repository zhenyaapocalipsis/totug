shader_type canvas_item;

// Свет щупалец CardFx: текстура тела без запечённого света (CardFx._flatten), а
// освещение считается здесь, от одного источника сверху-слева, по нормали
// цилиндра. Вершинный цвет тела несёт данные, а не цвет:
//   r — сторона поперёк тела (0 — левый край полоски, 1 — правый),
//   g, b — нормаль полоски в плоскости экрана (x, y из -1..1 в 0..1),
//   a — прозрачность (перекрытие шва плитки).
// Нетекстурированное (обводка, тень, капли — белая текстура 1x1) рисуется как есть.

uniform vec3 light_dir = vec3(-0.5, -0.7, 0.55);
uniform float ambient = 0.36;
uniform float bands = 4.0;
uniform vec4 shine : source_color = vec4(0.82, 0.88, 1.0, 1.0);

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
		float diff = max(dot(n, l), 0.0);
		// ступени света, как у рисованного пиксель-арта
		float lit = floor((ambient + (1.0 - ambient) * diff * 1.2) * bands + 0.5) / bands;
		float spec = step(0.94, dot(n, normalize(l + vec3(0.0, 0.0, 1.0))));
		COLOR = vec4(tex.rgb * lit + shine.rgb * spec * 0.4, tex.a * vcol.a);
	}
}
