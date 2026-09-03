shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * 0.92;
}
