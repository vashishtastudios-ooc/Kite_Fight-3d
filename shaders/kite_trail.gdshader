shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

void fragment() {
	vec3 col = COLOR.rgb;
	ALBEDO = col;
	EMISSION = col * 1.8;
	ALPHA = COLOR.a;
}
