shader_type spatial;
render_mode cull_disabled;

// Bamboo spine and bow. Bends with the same flex as the paper so the frame
// never detaches from the sail.

#include "res://shaders/patang.gdshaderinc"
#include "res://shaders/patang_flex.gdshaderinc"

uniform vec3 wood : source_color = vec3(0.42, 0.28, 0.14);

void vertex() {
	VERTEX = patang_flex(VERTEX);
}

void fragment() {
	ALBEDO = wood;
	ROUGHNESS = 0.8;
}
