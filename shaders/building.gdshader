shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.62, 0.58, 0.52, 1.0);
uniform vec4 roof_color : source_color = vec4(0.46, 0.36, 0.30, 1.0);
uniform vec4 window_color : source_color = vec4(0.28, 0.38, 0.48, 1.0);
uniform vec2 facade_scale = vec2(2.4, 3.0);

varying vec3 v_world_pos;
varying vec3 v_world_n;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_n = mat3(MODEL_MATRIX) * NORMAL;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.73, 45.21))) * 43758.5453);
}

void fragment() {
	vec3 n = normalize(v_world_n);
	vec3 an = abs(n);
	vec3 col = base_color.rgb;
	float rough = 0.84;
	float spec = 0.12;

	float plaster = hash21(floor(v_world_pos.xz * 1.7 + v_world_pos.y * 0.4));
	col *= 0.92 + plaster * 0.16;

	if (an.y > 0.72) {
		col = mix(roof_color.rgb, base_color.rgb, 0.12);
		vec2 uv = v_world_pos.xz * 1.8;
		float row = floor(uv.y);
		uv.x += 0.5 * mod(row, 2.0);
		vec2 f = fract(uv);
		float grout = 1.0 - smoothstep(0.06, 0.1, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		col = mix(col, col * 0.72, grout * 0.8);
		rough = 0.9;
	} else {
		vec2 uv = (an.x > an.z) ? v_world_pos.zy : v_world_pos.xy;
		vec2 cell = uv / facade_scale;
		vec2 id = floor(cell);
		vec2 f = fract(cell);
		float wx = smoothstep(0.22, 0.28, f.x) * (1.0 - smoothstep(0.74, 0.80, f.x));
		float wy = smoothstep(0.18, 0.24, f.y) * (1.0 - smoothstep(0.78, 0.86, f.y));
		float win = wx * wy;
		float h = hash21(id);
		win *= step(0.16, h);
		win *= step(3.4, v_world_pos.y);
		float frame = win * (1.0 - smoothstep(0.08, 0.16, min(min(f.x - 0.28, 0.76 - f.x), min(f.y - 0.24, 0.82 - f.y))));
		vec3 glass = window_color.rgb * (0.55 + h * 0.5);
		glass *= 0.75 + 0.35 * n.y;
		col = mix(col, col * 0.55, frame * 0.85);
		col = mix(col, glass, win * 0.72);
		spec = mix(0.10, 0.62, win);
		rough = mix(0.86, 0.22, win);
	}

	float ndv = clamp(dot(normalize(VIEW), normalize(NORMAL)), 0.0, 1.0);
	col *= 0.78 + 0.22 * ndv;
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
