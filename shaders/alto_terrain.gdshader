shader_type spatial;
// Alto-style ground: faceted low-poly slopes, soft two-band light, colour by
// height and steepness. Distance haze comes from the scene fog (aerial
// perspective), so near hills stay rich and far ones melt into the sky.
render_mode diffuse_toon, specular_disabled;

uniform vec3 floor_col : source_color = vec3(0.30, 0.24, 0.26);
uniform vec3 grass_col : source_color = vec3(0.42, 0.30, 0.30);
uniform vec3 rock_col : source_color = vec3(0.50, 0.34, 0.36);
uniform vec3 crest_col : source_color = vec3(0.86, 0.60, 0.52);
uniform float floor_h = 6.0;
uniform float crest_h = 120.0;
uniform vec3 snow_col : source_color = vec3(0.98, 0.86, 0.80);
uniform float snow_h = 150.0;
// Rock strata (0 = none): soft horizontal bands that wander a little, for
// cliffs and hoodoos.
uniform float strata = 0.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Facet normal: every triangle reads as one flat plane.
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(fn, VIEW) < 0.0) {
		fn = -fn;
	}
	NORMAL = fn;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(fn, 0.0)).xyz);
	float steep = 1.0 - clamp(wn.y, 0.0, 1.0);
	float h = v_world.y;
	vec3 col = mix(floor_col, grass_col, smoothstep(0.0, floor_h * 3.0, h));
	col = mix(col, rock_col, smoothstep(0.18, 0.55, steep));
	col = mix(col, crest_col, smoothstep(crest_h * 0.45, crest_h, h) * (1.0 - steep * 0.6));
	col = mix(col, snow_col, smoothstep(snow_h, snow_h + 25.0, h) * (1.0 - smoothstep(0.35, 0.7, steep)));
	if (strata > 0.0) {
		float wobble = sin(v_world.x * 0.21 + v_world.z * 0.17) * 0.9;
		float band = sin(v_world.y * 1.15 + wobble);
		float fine = sin(v_world.y * 4.3 + wobble * 2.0);
		col *= 1.0 - strata * (0.16 * smoothstep(-0.1, 0.9, band) + 0.05 * fine);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
