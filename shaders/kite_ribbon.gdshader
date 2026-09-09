shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled;

void fragment() {
	vec3 col = COLOR.rgb;
	ALBEDO = col;
	EMISSION = col * 0.45;
	ALPHA = COLOR.a;
}
