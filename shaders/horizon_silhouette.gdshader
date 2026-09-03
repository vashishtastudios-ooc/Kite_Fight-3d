shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix, fog_disabled;

uniform vec3 tint : source_color = vec3(0.58, 0.64, 0.72);
uniform float opacity : hint_range(0.0, 1.0) = 0.42;

float hash11(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	float id = floor(UV.x * 64.0);
	float h = 0.16 + hash11(id) * 0.38 + hash11(id * 2.17) * 0.14;
	if (hash11(id * 3.31) > 0.91) {
		h += 0.16;
	}
	if (UV.y > h) {
		discard;
	}
	float top = smoothstep(h, h - 0.08, UV.y);
	float lift = smoothstep(0.0, 0.12, UV.y);
	ALBEDO = tint;
	ALPHA = opacity * top * lift;
}
