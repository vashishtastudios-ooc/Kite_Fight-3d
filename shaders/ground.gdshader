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
uniform float road_half_width = 3.2;
uniform float road_edge = 1.8;

uniform vec3 road_color : source_color = vec3(0.13, 0.12, 0.12);
uniform vec3 dirt_color : source_color = vec3(0.31, 0.23, 0.16);
uniform vec3 dirt_color2 : source_color = vec3(0.22, 0.16, 0.11);

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

	// Micro bump + roughness detail from the tiling maps (no colour used).
	float rough_t = texture(ground_rough, uv).r;
	vec3 nts = texture(ground_normal, uv).xyz * 2.0 - 1.0;
	vec3 wn = normalize(vec3(nts.x, 1.0, nts.y));

	// --- road grid mask, aligned to the plots, with a wobbled edge ---
	vec2 g = abs(mod(w - grid_origin + grid_spacing * 0.5, grid_spacing) - grid_spacing * 0.5);
	float dline = min(g.x, g.y);
	float wob = (fbm(w * 0.07) - 0.5) * 1.8;
	float road = 1.0 - smoothstep(road_half_width, road_half_width + road_edge, dline + wob);

	// --- macro variation so the surface never reads as one repeating tile ---
	float macro = fbm(w * 0.014);
	float patch = fbm(w * 0.085);
	float grime = vnoise(w * 0.5);

	// Packed-earth plots: colour drift + patchy light/dark.
	vec3 dirt = mix(dirt_color, dirt_color2, macro);
	dirt *= 0.80 + 0.40 * patch;
	dirt = mix(dirt, dirt * 1.14, grime * 0.4);

	// Worn lane: dark, slightly patchy, occasionally damp.
	vec3 lane = road_color * (0.78 + 0.55 * patch);
	float wet = smoothstep(0.62, 0.95, macro) * road;

	// Dust creeps from the plots onto the lane edges.
	float lane_core = smoothstep(road_half_width - 0.4, 0.0, dline);
	vec3 col = mix(dirt, lane, road);
	col = mix(col, dirt * 0.88, (road - road * lane_core) * 0.6);

	// Roughness: earth rough, lane a touch smoother, damp spots smooth.
	float rough = mix(0.98, 0.72, road);
	rough = mix(rough, 0.36, wet);
	rough *= 0.85 + 0.3 * rough_t;
	rough = clamp(rough, 0.22, 1.0);

	// Distance haze into the horizon colour.
	float dist = length(w - hub.xz);
	float haze = smoothstep(haze_start, haze_end, dist);
	col = mix(col, haze_color, haze);

	// Flatten the bump on lanes so they read smoother than the earth.
	wn = normalize(mix(wn, vec3(0.0, 1.0, 0.0), road * 0.5));

	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.96, haze);
	SPECULAR = mix(0.04, 0.22, wet);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
