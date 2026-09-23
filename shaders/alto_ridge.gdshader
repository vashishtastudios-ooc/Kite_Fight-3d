shader_type spatial;
// Far mountain layer, Alto style: one flat silhouette colour, a touch lighter
// at the peaks and on the sun side, fading to the haze colour at its foot so
// the layers stack like paper cut-outs. Pre-hazed, so scene fog is off.
render_mode unshaded, fog_disabled, cull_disabled;

uniform vec3 body_col : source_color = vec3(0.56, 0.38, 0.42);
uniform vec3 peak_col : source_color = vec3(0.70, 0.48, 0.48);
uniform vec3 haze_col : source_color = vec3(0.92, 0.66, 0.58);
uniform float base_y = 0.0;
uniform float top_y = 200.0;
uniform float foot_haze = 0.55;
uniform vec3 sun_dir = vec3(0.6, 0.2, -0.8);
uniform float sun_warm = 0.18;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = clamp((v_world.y - base_y) / max(top_y - base_y, 1.0), 0.0, 1.0);
	vec3 col = mix(body_col, peak_col, smoothstep(0.55, 1.0, t));
	// Foot of each layer dissolves into haze, like mist in the valleys between.
	col = mix(col, haze_col, (1.0 - smoothstep(0.0, 0.55, t)) * foot_haze);
	// A warm cast on the side of the range nearest the sun.
	vec2 ground_dir = normalize(v_world.xz + vec2(0.0001));
	float sunward = clamp(dot(ground_dir, normalize(sun_dir.xz)), 0.0, 1.0);
	col = mix(col, haze_col, sunward * sun_warm);
	ALBEDO = col;
}
