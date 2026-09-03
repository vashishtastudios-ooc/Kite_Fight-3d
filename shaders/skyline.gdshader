shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix;

uniform sampler2D skyline : source_color, filter_linear;
uniform float uv_x0 = 0.0;
uniform float uv_x1 = 1.0;
uniform vec3 tint : source_color = vec3(0.55, 0.58, 0.64);
uniform float mix_tint = 0.78;
uniform float fade = 0.82;

void fragment() {
	vec2 uv = vec2(mix(uv_x0, uv_x1, UV.x), UV.y);
	vec4 c = texture(skyline, uv);
	if (c.a < 0.05) {
		discard;
	}
	float lum = dot(c.rgb, vec3(0.30, 0.50, 0.20));
	vec3 cool = mix(c.rgb, tint * lum * 1.15, mix_tint);
	float horizon = smoothstep(0.0, 0.22, UV.y) * (1.0 - smoothstep(0.92, 1.0, UV.y));
	ALBEDO = cool;
	ALPHA = c.a * fade * horizon;
}
