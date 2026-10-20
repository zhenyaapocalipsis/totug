shader_type canvas_item;

// Кадр эффекта Hearthstone (SubViewport с HDR 2D, линейный) -> sRGB поверх экрана игры.
// Свечение (bloom, как постобработка Hearthstone): то, что ярче порога, размывается
// двумя кольцами выборок и прибавляется.

uniform float glow_threshold = 1.0;
uniform float glow_intensity = 0.6;
uniform float glow_radius = 10.0;   // в пикселях игры

vec3 to_srgb(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 bright(sampler2D t, vec2 uv) {
	vec3 c = textureLod(t, uv, 0.0).rgb;
	return max(c - glow_threshold, vec3(0.0));
}

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	vec3 glow = vec3(0.0);
	float wsum = 0.0;
	for (int ring = 1; ring <= 3; ring++) {
		float r = glow_radius * float(ring) / 3.0;
		float w = 1.0 / float(ring);
		for (int k = 0; k < 10; k++) {
			float a = 6.2831853 * (float(k) + 0.5 * float(ring)) / 10.0;
			glow += bright(TEXTURE, UV + vec2(cos(a), sin(a)) * r * TEXTURE_PIXEL_SIZE) * w;
			wsum += w;
		}
	}
	c += glow / wsum * glow_intensity * 4.0;
	COLOR = vec4(to_srgb(c), 1.0);
}
