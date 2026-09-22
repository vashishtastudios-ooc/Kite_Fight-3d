shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, shadows_disabled, fog_disabled;

// Readability rim around a flexing sail — bends with the paper.

#include "res://shaders/patang.gdshaderinc"
#include "res://shaders/patang_flex.gdshaderinc"

uniform vec3 rim_col : source_color = vec3(1.0, 0.84, 0.28);
uniform float alpha : hint_range(0.0, 1.0) = 0.22;
uniform float glow = 0.12;

void vertex() {
	VERTEX = patang_flex(VERTEX);
}

void fragment() {
	ALBEDO = rim_col;
	EMISSION = rim_col * glow;
	ALPHA = alpha;
}
