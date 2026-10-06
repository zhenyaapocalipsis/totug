shader_type canvas_item;

// Фон «PAINT»: закрученная краска трёх цветов в духе фона Balatro, но своя
// формула (чужой код не берём: у него некоммерческая лицензия) и пиксель-арт,
// как у underdark_bg.gdshader: экран режется на клетки по pixel_size пикселей
// расчётного экрана 960x540, цвета плоские, границы полос — шахматкой Байера.
//
// Как устроено:
//   1. Закрутка: угол точки растёт с расстоянием от центра — краска вьётся
//      спиралью и медленно вращается.
//   2. Разводы: координата несколько раз сдвигается синусами от самой себя —
//      прямые полосы превращаются в текучие языки.
//   3. Полосы: длина искажённой координаты режется на три цвета, между
//      соседними — светлая кромка.

uniform vec4 colour_1 : source_color = vec4(0.871, 0.267, 0.231, 1.0);
uniform vec4 colour_2 : source_color = vec4(0.000, 0.420, 0.706, 1.0);
uniform vec4 colour_3 : source_color = vec4(0.086, 0.137, 0.145, 1.0);
uniform vec4 fade_to : source_color = vec4(0.039, 0.023, 0.070, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float pixel_size = 2.0;
uniform float design_height = 540.0;
uniform float speed = 0.35;
uniform float twist = 5.0;
/// Сколько раз повторяются полосы — больше, мельче рисунок.
uniform float bands = 0.11;


float bayer2(vec2 c) {
	c = floor(c);
	return fract(dot(c, vec2(0.5, c.y * 0.75)));
}
float bayer4(vec2 c) {
	return bayer2(0.5 * c) * 0.25 + bayer2(c);
}


void fragment() {
	vec2 res = vec2(1.0) / SCREEN_PIXEL_SIZE;
	float px = max(1.0, floor(res.y / design_height)) * max(pixel_size, 1.0);
	vec2 cells = floor(res / px);
	vec2 cell = floor(UV * cells);
	vec2 uv = ((cell + 0.5) / cells - 0.5) * vec2(res.x / res.y, 1.0);
	float d = bayer4(cell) - 0.5;
	float t = TIME * speed;

	// 1. Закрутка вокруг центра.
	float r = length(uv);
	float a = atan(uv.y, uv.x) + 0.15 * t - twist * r;
	vec2 p = vec2(cos(a), sin(a)) * r * 18.0;

	// 2. Разводы: каждый шаг сдвигает точку синусами от её же координат.
	for (int i = 0; i < 5; i++) {
		float k = float(i);
		p += 0.9 * vec2(sin(0.61 * p.y + 1.3 * k + 0.9 * t), cos(0.57 * p.x - 0.8 * k - 0.7 * t));
		p -= 0.6 * vec2(cos(0.5 * (p.x + p.y) + k), sin(0.43 * p.x - 0.37 * p.y));
	}

	// 3. Три полосы по кругу: тёмная, красная, синяя; кромки — светлее.
	float v = fract(length(p) * bands + d * 0.05);
	vec3 col = v < 0.40 ? colour_3.rgb : (v < 0.70 ? colour_1.rgb : colour_2.rgb);
	float edge = min(min(abs(v - 0.40), abs(v - 0.70)), min(v, 1.0 - v));
	if (edge < 0.018 && v >= 0.40) {
		col = mix(col, vec3(1.0), 0.35);
	}

	COLOR = vec4(mix(col, fade_to.rgb, fade), 1.0);
}
