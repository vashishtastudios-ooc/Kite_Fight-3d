shader_type spatial;
render_mode cull_back, diffuse_burley;

// Micro surface detail only — colour is built procedurally so no baked highway
// lane-markings show through.
uniform sampler2D ground_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 ground_repeat = vec2(0.22, 0.22);

// Distance haze (matches the sky/fog).
uniform vec3 haze_color : source_color = vec3(0.86, 0.60, 0.46);
uniform vec3 hub = vec3(0.0, 0.0, 92.0);
uniform float haze_start = 520.0;
uniform float haze_end = 1150.0;

// Road network — aligned to the city's plot grid (lines every grid_spacing).
uniform float grid_spacing = 20.0;
uniform vec2 grid_origin = vec2(16.0, 82.0);
uniform float road_half_width = 2.9;
uniform float gali_half_width = 1.15;
uniform float major_stride = 4.0;
uniform float road_edge = 1.6;
uniform float shoulder_width = 0.85;

uniform vec3 road_color : source_color = vec3(0.28, 0.22, 0.18);
uniform vec3 dirt_color : source_color = vec3(0.52, 0.40, 0.28);
uniform vec3 dirt_color2 : source_color = vec3(0.40, 0.30, 0.20);
uniform vec3 rim_color : source_color = vec3(0.34, 0.22, 0.15);

varying vec3 v_world;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = v_world.xz;
	vec2 uv = w * ground_repeat;

	float rough_t = texture(ground_rough, uv).r;
	vec3 nts = texture(ground_normal, uv).xyz * 2.0 - 1.0;
	vec3 wn = normalize(vec3(nts.x, 1.0, nts.y));

	vec2 g = abs(mod(w - grid_origin + grid_spacing * 0.5, grid_spacing) - grid_spacing * 0.5);
	float line_ix = round((w.x - grid_origin.x) / grid_spacing);
	float line_iy = round((w.y - grid_origin.y) / grid_spacing);
	float major_x = float(mod(abs(line_ix), major_stride) < 0.5);
	float major_y = float(mod(abs(line_iy), major_stride) < 0.5);
	// Drop some galis so the aerial map is a mohalla, not graph paper.
	float keep_x = max(major_x, float(hash(vec2(line_ix, 9.7)) > 0.34));
	float keep_y = max(major_y, float(hash(vec2(line_iy, 4.2)) > 0.34));
	float gx = mix(1e4, g.x, keep_x);
	float gy = mix(1e4, g.y, keep_y);
	float dline = min(gx, gy);
	float is_ns = float(gx <= gy);
	float is_major = mix(major_y, major_x, is_ns);
	float half_w = mix(gali_half_width, road_half_width, is_major);

	float wob = (fbm(w * 0.045) - 0.5) * mix(4.2, 1.6, is_major)
		+ (fbm(w * 0.16) - 0.5) * mix(1.4, 0.5, is_major);
	float d_road = dline + wob;

	float road = 1.0 - smoothstep(half_w, half_w + road_edge, d_road);
	float core_end = max(half_w - mix(0.45, shoulder_width, is_major), 0.35);
	float lane_core = (1.0 - smoothstep(core_end, half_w - 0.08, d_road)) * road;
	float shoulder = clamp(road - lane_core, 0.0, 1.0);

	float macro = fbm(w * 0.014);
	float patch = fbm(w * 0.085);
	float grime = vnoise(w * 0.5);

	vec3 dirt = mix(dirt_color, dirt_color2, macro);
	dirt *= 0.90 + 0.24 * patch;
	dirt = mix(dirt, dirt * 1.10, grime * 0.32);
	// Per-plot tint so empty lots are courtyards, not identical tiles.
	vec2 plot_id = floor((w - grid_origin) / grid_spacing);
	float ph = hash(plot_id);
	vec3 plot_tint = mix(vec3(1.08, 1.03, 0.94), vec3(0.84, 0.92, 0.74), ph);
	dirt *= mix(vec3(1.0), plot_tint, 0.42);

	vec3 lane = mix(dirt * 0.86, road_color, mix(0.28, 0.72, is_major));
	lane *= 0.94 + 0.12 * patch;
	vec3 shoulder_col = mix(lane, dirt * 0.92, 0.70);
	float wet = smoothstep(0.74, 0.97, macro) * lane_core * is_major * 0.35;

	vec3 col = mix(dirt, lane, lane_core);
	col = mix(col, shoulder_col, shoulder);

	float inset = dline - half_w;
	float rim_wob = (fbm(w * 0.21) - 0.5) * 0.28;
	float rim = (1.0 - road)
		* smoothstep(0.08, 0.22, inset + rim_wob)
		* (1.0 - smoothstep(0.50, 0.86, inset + rim_wob));

	// From the kite, rims and black lanes become a chessboard — fade them with height.
	float aerial = smoothstep(28.0, 88.0, CAMERA_POSITION_WORLD.y);
	float dist = length(w - hub.xz);
	float far_soft = smoothstep(80.0, 260.0, dist);
	float grid_fade = max(aerial, far_soft * 0.75);
	col = mix(col, dirt, grid_fade * mix(0.55, 0.22, is_major) * road);
	col = mix(col, rim_color * (0.88 + 0.22 * patch), rim * 0.80 * (1.0 - grid_fade));

	float rough = mix(0.98, 0.72, lane_core * (1.0 - grid_fade * 0.6));
	rough = mix(rough, 0.84, shoulder);
	rough = mix(rough, 0.90, rim * (1.0 - grid_fade));
	rough = mix(rough, 0.42, wet);
	rough *= 0.85 + 0.3 * rough_t;
	rough = clamp(rough, 0.22, 1.0);

	float haze = smoothstep(haze_start, haze_end, dist);
	col = mix(col, haze_color, haze);

	float nstr = mix(0.42, 0.78, lane_core * (1.0 - aerial));
	wn = normalize(mix(vec3(0.0, 1.0, 0.0), wn, nstr));

	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.96, haze);
	SPECULAR = mix(0.04, 0.16, wet);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
