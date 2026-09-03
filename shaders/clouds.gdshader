shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled, blend_mix;

uniform vec3 cloud_color : source_color = vec3(1.0, 0.99, 0.97);
uniform vec3 wisp_color : source_color = vec3(1.0, 0.94, 0.88);
uniform float coverage : hint_range(0.0, 1.0) = 0.38;
uniform float softness : hint_range(0.05, 0.5) = 0.22;
uniform float opacity : hint_range(0.0, 1.0) = 0.50;
uniform float far_speed = 0.012;
uniform float near_speed = 0.022;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i);
	float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);
	return mix(nxy0, nxy1, f.z);
}

float fbm(vec3 p) {
	p = vec3(
		dot(p, vec3(0.80, 0.36, -0.48)),
		dot(p, vec3(-0.31, 0.91, 0.28)),
		dot(p, vec3(0.50, -0.18, 0.85))
	);
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * value_noise(p);
		p = p * 2.03 + vec3(0.17, 0.31, 0.11);
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec3 dir = normalize(v_world);
	float h = dir.y;
	float above = smoothstep(0.02, 0.16, h);

	vec3 p_far = dir * 2.4 + vec3(TIME * far_speed, 0.0, TIME * far_speed * 0.35);
	vec3 p_near = dir * 4.1 + vec3(-TIME * near_speed, TIME * 0.004, TIME * near_speed * 0.2);
	float n_far = fbm(p_far);
	float n_near = fbm(p_near);

	float far_c = smoothstep(coverage, coverage + softness, n_far);
	float near_c = smoothstep(coverage + 0.05, coverage + softness + 0.04, n_near);
	float cloud = far_c * 0.65 + near_c * 0.55;

	float alpha = cloud * opacity * above;
	vec3 col = mix(cloud_color, wisp_color, clamp((1.0 - h) * 0.35, 0.0, 0.5));
	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 0.7);
}
