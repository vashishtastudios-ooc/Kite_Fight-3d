shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 core_col : source_color = vec3(1.0, 0.88, 0.45);
uniform vec3 halo_col : source_color = vec3(1.0, 0.28, 0.42);

void fragment() {
	vec2 c = UV - vec2(0.5);
	float r = length(c);
	float core = exp(-r * 22.0);
	float mid = exp(-r * 7.5);
	float halo = exp(-r * 3.2);
	vec3 col = core_col * core * 2.4 + core_col * mid * 0.7 + halo_col * halo * 0.45;
	ALBEDO = col;
	EMISSION = col;
	ALPHA = clamp(core + mid * 0.55 + halo * 0.25, 0.0, 1.0);
}
