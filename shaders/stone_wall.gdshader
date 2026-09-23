shader_type spatial;
// Himalayan masonry: whitewashed stone laid in courses, the lime wearing thin
// toward the foot, with a faint offset-block pattern so it reads as stone.
render_mode diffuse_toon, specular_disabled;

uniform vec3 wash_col : source_color = vec3(0.92, 0.88, 0.82);
uniform vec3 stone_col : source_color = vec3(0.62, 0.54, 0.52);
uniform float wash_top = 40.0;       // world y where the whitewash is fresh
uniform float wash_depth = 10.0;     // metres over which it wears away below
uniform float course = 0.55;         // course height (m)
uniform float block = 1.1;           // block length (m)

varying vec3 v_world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(fn, VIEW) < 0.0) {
		fn = -fn;
	}
	NORMAL = fn;
	float row = floor(v_world.y / course);
	float along = (abs(fn.x) > abs(fn.z)) ? v_world.z : v_world.x;
	float cell = floor(along / block + row * 0.5);
	float n = hash(vec2(row, cell));
	vec2 f = vec2(fract(along / block + row * 0.5), fract(v_world.y / course));
	float joint = smoothstep(0.0, 0.05, f.x) * smoothstep(1.0, 0.95, f.x) * smoothstep(0.0, 0.08, f.y) * smoothstep(1.0, 0.92, f.y);
	float wash = smoothstep(wash_top - wash_depth, wash_top - 1.0, v_world.y);
	vec3 col = mix(stone_col * (0.86 + 0.22 * n), wash_col * (0.95 + 0.06 * n), wash * (0.75 + 0.25 * n));
	col *= mix(0.72, 1.0, joint);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
