shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix, fog_disabled;

uniform vec3 tint : source_color = vec3(0.58, 0.64, 0.72);
uniform float opacity : hint_range(0.0, 1.0) = 0.42;
uniform float columns = 64.0;
// 0 = jagged city teeth, 1 = smooth rolling tree-line / hills.
uniform float roundness : hint_range(0.0, 1.0) = 0.0;
uniform float height_scale : hint_range(0.1, 1.5) = 1.0;

float hash11(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

float col_h(float id) {
	return 0.15 + hash11(id) * 0.36 + hash11(id * 2.17) * 0.13;
}

void fragment() {
	float x = UV.x * columns;
	float id = floor(x);
	float f = fract(x);
	float ha = col_h(id);
	float hb = col_h(id + 1.0);
	// Jagged: hard per-column steps with the odd tall spike (a skyline).
	float jagged = ha + (hash11(id * 3.31) > 0.91 ? 0.16 : 0.0);
	// Round: smooth interpolation between columns (rolling hills / tree cover).
	float smooth_h = mix(ha, hb, f * f * (3.0 - 2.0 * f));
	float h = mix(jagged, smooth_h, roundness) * height_scale;
	if (UV.y > h) {
		discard;
	}
	float top = smoothstep(h, h - mix(0.08, 0.14, roundness), UV.y);
	float lift = smoothstep(0.0, 0.12, UV.y);
	ALBEDO = tint;
	ALPHA = opacity * top * lift;
}
