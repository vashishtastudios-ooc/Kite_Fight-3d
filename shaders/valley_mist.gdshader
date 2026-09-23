shader_type spatial;
// Low mist lying in the valley: soft drifting banks, thicker toward the far
// end, fading at its edges. Kites flown low slip into it.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 mist_col : source_color = vec3(0.95, 0.76, 0.70);
uniform float opacity = 0.42;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec2 drift = vec2(0.004, -0.006);

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = v_world.xz * 0.0045 + TIME * drift;
	float n = texture(noise_tex, uv).r * 0.65 + texture(noise_tex, uv * 2.3 - TIME * drift * 1.7).r * 0.35;
	float banks = smoothstep(0.45, 0.8, n);
	// Fade toward the edges of the sheet so it never shows a hard border.
	float edge = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x) * smoothstep(0.0, 0.2, UV.y) * smoothstep(1.0, 0.8, UV.y);
	ALBEDO = mist_col;
	ALPHA = banks * edge * opacity;
}
