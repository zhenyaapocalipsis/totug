shader_type canvas_item;
render_mode unshaded, blend_add;

uniform sampler2D card_face : filter_nearest, repeat_disable;
uniform vec4 burn_color : source_color;
uniform float strength = 0.0;
uniform float revealed = 0.0;
uniform float clip_time = 0.0;

void fragment() {
	vec2 face_size = vec2(textureSize(card_face, 0));
	// The draw rectangle extends four source pixels past the miniature on each side.
	vec2 pixel = floor(UV * (face_size + 8.0)) - 4.0;
	vec2 edge = min(pixel, face_size - 1.0 - pixel);
	vec4 face = texture(card_face, (pixel + 0.5) / face_size);
	float inside = step(0.0, min(edge.x, edge.y));
	float luma = dot(face.rgb, vec3(0.2126, 0.7152, 0.0722));
	float lettering = inside * float(pixel.y > 0.0 && pixel.y < 27.0) * smoothstep(0.62, 0.86, luma);
	// The original flare still supplies the outline below the title.
	float header_edge = inside * float(pixel.y < 27.0) * (1.0 - smoothstep(0.0, 1.5, min(edge.x, edge.y)));
	float contour = max(0.62 * header_edge, 0.85 * lettering);
	float front = (face_size.y * (1.0 - revealed)) - pixel.y;
	float sweep_edge = inside * (1.0 - smoothstep(0.0, 3.0, abs(front)));
	sweep_edge *= float(revealed > 0.0 && revealed < 1.0);
	// A moving, pixel-sized grain keeps the glow from reading as a solid neon frame.
	float grain = fract(sin(dot(floor(pixel / 2.0) + floor(clip_time * 24.0), vec2(12.9898, 78.233))) * 43758.5453);
	float wave = 0.5 + 0.5 * sin(pixel.x * 0.21 + pixel.y * 0.18 - 15.0 * clip_time);
	float flicker = 0.49 + grain * 0.25 + wave * 0.26;
	float amount = max(contour * smoothstep(-1.0, 3.0, front), 0.84 * sweep_edge) * flicker;
	COLOR = vec4(mix(burn_color.rgb, vec3(1.0), 0.24 * amount), amount * strength);
}
