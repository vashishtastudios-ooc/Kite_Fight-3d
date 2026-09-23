shader_type spatial;
// Desert sand in the Alto manner: smooth dunes, a warm lit face and a cooler
// shadow face, a bright line along each crest where the low sun catches it,
// and faint wind ripples running across the slopes.
render_mode diffuse_toon, specular_disabled;

uniform vec3 lit_col : source_color = vec3(0.95, 0.58, 0.28);
uniform vec3 shade_col : source_color = vec3(0.30, 0.13, 0.14);
uniform vec3 crest_col : source_color = vec3(1.0, 0.86, 0.52);
uniform vec3 hollow_col : source_color = vec3(0.20, 0.09, 0.11);
uniform float hollow_y = 6.0;      // sand below this sits in shadowed hollows
uniform float crest_sharp = 14.0;  // how tight the lit crest line is
uniform float ripple = 0.5;
uniform vec3 sun_dir = vec3(-0.5, 0.2, -0.85);
uniform vec3 rock_col : source_color = vec3(0.30, 0.15, 0.14);
uniform vec3 rock_lit : source_color = vec3(0.62, 0.34, 0.22);

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// Which way the slope faces relative to the sun, flattened.
	float facing = dot(normalize(wn.xz + vec2(0.0001)), normalize(sun_dir.xz));
	vec3 col = mix(shade_col, lit_col, smoothstep(-0.55, 0.65, facing));
	col = mix(hollow_col, col, smoothstep(hollow_y - 6.0, hollow_y + 10.0, v_world.y));
	// Crest: where the surface turns over, the sand edge burns bright.
	float flat_top = smoothstep(0.55, 0.995, wn.y);
	float turn = clamp(length(vec2(dFdx(wn.y), dFdy(wn.y))) * crest_sharp, 0.0, 1.0);
	// Backlit crest: the sand edge between you and the sun burns brightest.
	col = mix(col, crest_col, turn * (0.25 + 0.95 * smoothstep(-0.2, 0.9, facing)));
	// Where the ground stands too steep to hold sand, it is bare rock, laid
	// in courses and lit harder on the sunward side.
	float steep = smoothstep(0.88, 0.52, wn.y);
	if (steep > 0.0) {
		vec3 rc = mix(rock_col, rock_lit, smoothstep(-0.4, 0.7, facing));
		float band = sin(v_world.y * 0.9 + sin(v_world.x * 0.15 + v_world.z * 0.11) * 1.2);
		rc *= 1.0 - 0.12 * smoothstep(-0.2, 0.9, band);
		col = mix(col, rc, steep);
	}
	// Wind ripples: fine bands across the slope, fading on flat sand.
	float r = sin(v_world.x * 0.55 + v_world.z * 0.22 + wn.y * 4.0);
	col *= 1.0 + ripple * 0.05 * r * (1.0 - flat_top) * (1.0 - steep);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
