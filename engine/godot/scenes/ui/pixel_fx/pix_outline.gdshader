shader_type canvas_item;

// Цветная обводка холста эффекта (Pix). Идея — шейдер «outline and shade with alpha
// threshold» (godotshaders.com, CC0): пустой пиксель рядом с непрозрачным становится
// обводкой. Отличие — обводка не чёрная, а тёмный оттенок соседа со сдвигом в
// фиолетовый (sel-out пиксель-арта: контур в цвет формы, а не карандашный).
// Вид пикселя — в альфе: 255 — вещество (обводится), 254 — свет (не обводится).

uniform vec3 shade = vec3(0.26, 0.2, 0.36);
uniform vec3 tint : source_color = vec3(0.04, 0.02, 0.07);
uniform float strength : hint_range(0.0, 1.0) = 1.0;

const vec2 DIRS[4] = vec2[4](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a > 0.5) {
		COLOR = vec4(tex.rgb, 1.0);
	} else {
		vec3 nb = vec3(0.0);
		float found = 0.0;
		for (int i = 0; i < 4; i++) {
			vec4 s = texture(TEXTURE, UV + DIRS[i] * TEXTURE_PIXEL_SIZE);
			if (s.a > 0.998 && found < 0.5) {
				nb = s.rgb;
				found = 1.0;
			}
		}
		if (found < 0.5 || strength <= 0.0) {
			discard;
		}
		COLOR = vec4(nb * shade + tint, 1.0);
	}
}
