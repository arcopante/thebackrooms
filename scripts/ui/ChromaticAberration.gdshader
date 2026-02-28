shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float wave = sin((uv.y * 24.0) + (time * 8.0)) * 0.002 * intensity;
	float r_shift = 0.003 * intensity;
	float b_shift = -0.003 * intensity;

	float r = texture(SCREEN_TEXTURE, uv + vec2(wave + r_shift, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, uv + vec2(wave, 0.0)).g;
	float b = texture(SCREEN_TEXTURE, uv + vec2(wave + b_shift, 0.0)).b;

	// Oscurece progresivamente mezclando con negro
	vec3 aberrated = vec3(r, g, b);
	vec3 darkened = mix(aberrated, vec3(0.0), intensity * 0.85);

	COLOR = vec4(darkened, intensity);
}
