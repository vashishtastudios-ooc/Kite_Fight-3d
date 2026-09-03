shader_type spatial;
render_mode unshaded, blend_add, cull_back, shadows_disabled, depth_draw_opaque;

// A few warm panes per house — not a neon grid.
uniform vec3 warm_col : source_color = vec3(1.0, 0.74, 0.36);
uniform vec3 cool_col : source_color = vec3(1.0, 0.86, 0.58);
uniform vec2 window_scale = vec2(7.2, 7.6);
uniform float lit_chance : hint_range(0.0, 1.0) = 0.09;
uniform float glow = 1.15;

varying vec3 wpos;
varying vec3 wn;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = mat3(MODEL_MATRIX) * NORMAL;
}

void fragment() {
	vec3 n = normalize(wn);
	float wall = step(abs(n.y), 0.48) * step(4.0, wpos.y);
	vec2 lot = floor(wpos.xz / 16.0);
	float house = hash21(lot);
	float house_lit = step(0.28, house);
	vec2 uv = (abs(n.x) > abs(n.z)) ? wpos.zy : wpos.xy;
	vec2 id = floor(uv / window_scale);
	vec2 f = fract(uv / window_scale);
	float pane = step(0.28, f.x) * step(f.x, 0.72) * step(0.26, f.y) * step(f.y, 0.74);
	float h = hash21(id + lot * 3.1);
	float on = pane * wall * house_lit * step(1.0 - lit_chance, h);
	vec3 col = mix(warm_col, cool_col, step(0.78, h));
	vec3 lit = col * on * glow;
	ALBEDO = lit * 0.28;
	EMISSION = lit;
	ALPHA = on * 0.7;
}
