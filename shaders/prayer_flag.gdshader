shader_type spatial;
// A string of lungta prayer flags: each little cloth flaps from its top edge,
// harder when a gust arrives. Colour comes from the vertex colour.
render_mode cull_disabled, diffuse_toon, specular_disabled;

uniform float gust = 0.0;
uniform float flap_speed = 7.0;

void vertex() {
	// UV.y = 0 at the string, 1 at the free bottom edge.
	float free = UV.y;
	float amp = (0.06 + gust * 0.16) * free;
	float ph = VERTEX.x * 3.1 + VERTEX.z * 2.7;
	VERTEX.z += sin(TIME * flap_speed * (1.0 + gust) + ph) * amp;
	VERTEX.x += sin(TIME * flap_speed * 0.7 + ph * 1.3) * amp * 0.4;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
