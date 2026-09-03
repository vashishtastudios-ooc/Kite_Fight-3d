shader_type particles;

// Adapted from:
// https://godotshaders.com/shader/wind-driven-falling-particles-leaves-petals-feathers/

uniform vec4 color : source_color = vec4(0.72, 0.55, 0.22, 1.0);
uniform vec3 box_emit_size = vec3(55.0, 32.0, 80.0);
uniform float initial_rotation_xz = 0.7;
uniform float fade_from : hint_range(0.0, 1.0) = 0.82;
uniform float forward_speed_min = 1.2;
uniform float forward_speed_max = 4.5;
uniform vec2 rot_speed_x = vec2(0.4, 1.6);
uniform vec2 rot_speed_y = vec2(0.8, 2.2);
uniform vec2 rot_speed_z = vec2(1.0, 2.8);
uniform float vel_damping = 0.35;
uniform vec3 grav = vec3(0.0, -1.8, 0.0);
uniform vec3 wind_velocity = vec3(0.0, 0.0, -9.0);

uint hash(uint x) {
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = (x >> uint(16)) ^ x;
	return x;
}

float rand_from_seed(inout uint seed) {
	int k;
	int s = int(seed);
	if (s == 0) {
		s = 305420679;
	}
	k = s / 127773;
	s = 16807 * (s - k * 127773) - 2836 * k;
	if (s < 0) {
		s += 2147483647;
	}
	seed = uint(s);
	return float(seed % uint(65536)) / 65535.0;
}

mat3 rot_x_matrix(float angle) {
	float cx = cos(angle);
	float sx = sin(angle);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cx, -sx), vec3(0.0, sx, cx));
}

mat3 rot_y_matrix(float angle) {
	float cy = cos(angle);
	float sy = sin(angle);
	return mat3(vec3(cy, 0.0, sy), vec3(0.0, 1.0, 0.0), vec3(-sy, 0.0, cy));
}

mat3 rot_z_matrix(float angle) {
	float cz = cos(angle);
	float sz = sin(angle);
	return mat3(vec3(cz, -sz, 0.0), vec3(sz, cz, 0.0), vec3(0.0, 0.0, 1.0));
}

void start() {
	uint alt_seed = hash(NUMBER + uint(1) + RANDOM_SEED);
	if (RESTART_ROT_SCALE) {
		TRANSFORM[0].xyz = vec3(1.0, 0.0, 0.0);
		TRANSFORM[1].xyz = vec3(0.0, 1.0, 0.0);
		TRANSFORM[2].xyz = vec3(0.0, 0.0, 1.0);
		float angle_y = rand_from_seed(alt_seed) * TAU;
		float angle_x = (rand_from_seed(alt_seed) - 0.5) * 2.0 * initial_rotation_xz;
		float angle_z = (rand_from_seed(alt_seed) - 0.5) * 2.0 * initial_rotation_xz;
		mat3 rot = rot_y_matrix(angle_y) * rot_x_matrix(angle_x) * rot_z_matrix(angle_z);
		TRANSFORM[0].xyz = rot * TRANSFORM[0].xyz;
		TRANSFORM[1].xyz = rot * TRANSFORM[1].xyz;
		TRANSFORM[2].xyz = rot * TRANSFORM[2].xyz;
		USERDATA1 = vec4(0.0);
		USERDATA1.y = rand_from_seed(alt_seed);
		USERDATA1.z = mix(rot_speed_x.x, rot_speed_x.y, rand_from_seed(alt_seed));
		USERDATA1.w = step(0.5, rand_from_seed(alt_seed)) * 2.0 - 1.0;
		USERDATA2 = vec4(0.0);
		USERDATA2.x = mix(rot_speed_y.x, rot_speed_y.y, rand_from_seed(alt_seed));
		USERDATA2.y = step(0.5, rand_from_seed(alt_seed)) * 2.0 - 1.0;
		USERDATA2.z = mix(rot_speed_z.x, rot_speed_z.y, rand_from_seed(alt_seed));
		USERDATA2.w = step(0.5, rand_from_seed(alt_seed)) * 2.0 - 1.0;
	}
	if (RESTART_POSITION) {
		float x = (rand_from_seed(alt_seed) - 0.5) * box_emit_size.x;
		float y = (rand_from_seed(alt_seed) - 0.5) * box_emit_size.y;
		float z = (rand_from_seed(alt_seed) - 0.5) * box_emit_size.z;
		TRANSFORM[3].xyz = vec3(x, y, z);
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
	}
	if (RESTART_COLOR) {
		float t = rand_from_seed(alt_seed);
		vec3 leaf = mix(vec3(0.62, 0.38, 0.14), vec3(0.82, 0.62, 0.22), t);
		leaf = mix(leaf, vec3(0.45, 0.52, 0.22), step(0.72, t));
		COLOR = vec4(leaf, 1.0);
	}
	if (RESTART_VELOCITY) {
		VELOCITY = vec3(0.0);
	}
}

void process() {
	USERDATA1.x += DELTA;
	float particle_normalized_time = clamp(USERDATA1.x / LIFETIME, 0.0, 1.0);
	float current_forward_speed_var = (sin(TIME + (USERDATA1.y * 10.0)) + 1.0) * 0.5;
	float current_forward_speed = mix(forward_speed_min, forward_speed_max, current_forward_speed_var);

	VELOCITY += grav * DELTA;
	VELOCITY += normalize(-TRANSFORM[2].xyz) * DELTA * current_forward_speed;
	VELOCITY += wind_velocity * DELTA * 2.2;
	VELOCITY *= 1.0 - vel_damping * DELTA;

	float current_rotation_x_var = 1.0 - clamp(current_forward_speed_var, 0.0, 1.0);
	mat3 rot_x = rot_x_matrix(USERDATA1.z * USERDATA1.w * DELTA * current_rotation_x_var);
	mat3 rot_y = rot_y_matrix(USERDATA2.x * USERDATA2.y * DELTA * current_rotation_x_var);
	mat3 rot_z = rot_z_matrix(USERDATA2.z * USERDATA2.w * DELTA * clamp(current_forward_speed_var, 0.0, 1.0));
	mat3 rot = rot_y * rot_x * rot_z;
	TRANSFORM[0].xyz = rot * TRANSFORM[0].xyz;
	TRANSFORM[1].xyz = rot * TRANSFORM[1].xyz;
	TRANSFORM[2].xyz = rot * TRANSFORM[2].xyz;
	COLOR.a = 1.0 - smoothstep(fade_from, 1.0, particle_normalized_time);
}
