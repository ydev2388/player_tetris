shader_type canvas_item;
render_mode unshaded;

uniform bool aura_enabled = false;
uniform vec4 aura_color : source_color = vec4(1.0, 0.78, 0.08, 1.0);

void fragment() {
	vec4 vertex_tint = COLOR;
	vec4 base = texture(TEXTURE, UV);
	vec4 result = base;
	if (aura_enabled) {
		float inner_alpha = 0.0;
		float outer_alpha = 0.0;
		for (int y = -4; y <= 4; y++) {
			for (int x = -4; x <= 4; x++) {
				float distance_squared = float(x * x + y * y);
				float sampled_alpha = texture(
					TEXTURE,
					UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE
				).a;
				if (distance_squared <= 6.25) {
					inner_alpha = max(inner_alpha, sampled_alpha);
				}
				if (distance_squared <= 18.0) {
					outer_alpha = max(outer_alpha, sampled_alpha);
				}
			}
		}

		float pulse = 0.84 + 0.16 * sin(TIME * 6.0);
		float outline = max(inner_alpha - base.a, 0.0);
		float glow = max(outer_alpha - max(inner_alpha, base.a), 0.0);
		result.rgb = mix(result.rgb, aura_color.rgb, outline);
		result.a = max(result.a, outline * aura_color.a * pulse);
		result.rgb = mix(result.rgb, aura_color.rgb, glow * 0.55);
		result.a = max(result.a, glow * aura_color.a * 0.42 * pulse);
	}
	COLOR = result * vertex_tint;
}
