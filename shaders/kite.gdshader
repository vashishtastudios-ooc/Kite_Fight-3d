shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, fog_disabled;

uniform float lift : hint_range(0.0, 1.0) = 0.0;
uniform float rim : hint_range(0.0, 2.0) = 0.0;
uniform vec3 rim_color : source_color = vec3(1.0, 0.84, 0.28);

void fragment() {
	vec3 base = COLOR.rgb;
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float r = pow(1.0 - ndv, 1.55) * rim;
	vec3 col = mix(base, base * 1.22 + vec3(0.07), lift);
	ALBEDO = col;
	ROUGHNESS = mix(0.62, 0.38, lift);
	EMISSION = col * (0.18 * lift) + rim_color * r;
}
