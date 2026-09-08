shader_type spatial;
// Unshaded: we light the water analytically, so it never double-lights or costs
// a shadow/probe pass. fog_disabled: we do our own horizon dissolve so the near
// sea stays readable. No SCREEN_TEXTURE, no depth_texture, no reflection probe —
// mobile-safe by construction.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_opaque, fog_disabled;

uniform vec3 hub = vec3(0.0, 0.0, 92.0);
uniform float land_radius = 780.0;
uniform float shore_width = 60.0;

uniform vec3 deep_color : source_color = vec3(0.17, 0.16, 0.23);
uniform vec3 shallow_color : source_color = vec3(0.34, 0.30, 0.33);
uniform vec3 sky_horizon : source_color = vec3(0.94, 0.63, 0.48);
uniform vec3 sky_top : source_color = vec3(0.46, 0.40, 0.52);
uniform vec3 sun_dir = vec3(0.55, 0.16, -0.42);
uniform vec3 sun_color : source_color = vec3(1.0, 0.76, 0.46);
uniform vec3 foam_color : source_color = vec3(0.95, 0.86, 0.78);
uniform vec3 haze_color : source_color = vec3(0.90, 0.66, 0.56);
uniform float haze_start = 900.0;
uniform float haze_end = 1750.0;
uniform float swell_scale = 0.012;
uniform float swell_speed = 0.03;
uniform float ripple_scale = 0.06;
uniform float ripple_speed = 0.06;
uniform float ripple_strength = 0.36;

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

// Smooth multi-octave wave height — breaks up the value-noise grid so the
// swell reads as rolling water, not square patches.
float wave(vec2 p) {
	return 0.55 * vnoise(p) + 0.28 * vnoise(p * 2.03 + 11.3) + 0.17 * vnoise(p * 4.11 + 23.7);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = v_world.xz;
	float dist = length(w - hub.xz);
	// Transparent over the city, ramps to full water past the shore.
	float water = smoothstep(land_radius, land_radius + shore_width, dist);
	if (water < 0.003) {
		discard;
	}

	// Normal from a big rolling swell (visible far, at grazing angles) plus a
	// finer ripple layer (visible closer). Finite differences of the noise.
	float e = 0.5;
	vec2 suv = w * swell_scale;
	vec2 sflow = vec2(TIME * swell_speed, TIME * swell_speed * 0.6);
	float sx = wave(suv + vec2(e, 0.0) + sflow) - wave(suv - vec2(e, 0.0) + sflow);
	float sz = wave(suv + vec2(0.0, e) + sflow) - wave(suv - vec2(0.0, e) + sflow);
	vec2 ruv = w * ripple_scale;
	vec2 rflow = vec2(-TIME * ripple_speed * 0.7, TIME * ripple_speed);
	float rx = wave(ruv + vec2(e, 0.0) + rflow) - wave(ruv - vec2(e, 0.0) + rflow);
	float rz = wave(ruv + vec2(0.0, e) + rflow) - wave(ruv - vec2(0.0, e) + rflow);
	float gx = sx * 1.6 + rx * 0.6;
	float gz = sz * 1.6 + rz * 0.6;
	vec3 N = normalize(vec3(gx * ripple_strength, 1.0, gz * ripple_strength));

	// World view ray (camera -> fragment) and its reflection off the surface.
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 V = normalize(v_world - cam);
	vec3 R = reflect(V, N);

	// Analytic sky reflection — warm at the horizon, cooler overhead.
	float upness = clamp(R.y, 0.0, 1.0);
	vec3 sky = mix(sky_horizon, sky_top, smoothstep(0.0, 0.5, upness));

	// Fresnel: grazing angles show mostly sky, straight-down shows deep water.
	float fres = pow(1.0 - clamp(dot(N, -V), 0.0, 1.0), 5.0);
	fres = clamp(0.03 + fres, 0.0, 1.0);

	float swell_h = wave(suv + sflow);
	float detail_h = wave(ruv + rflow);

	vec3 base = mix(deep_color, shallow_color, 0.3 + 0.25 * detail_h);
	vec3 col = mix(base, sky, fres);

	// Rolling light/dark bands straight from the swell height, so the surface
	// reads as moving water even at grazing angles where fresnel would flatten
	// the reflection to plain sky. Gentle = calm dusk sea.
	col *= 0.82 + 0.32 * swell_h;

	// A few soft whitecaps on the steepest crests.
	float crest = smoothstep(0.8, 0.97, swell_h) * (0.5 + 0.5 * detail_h);
	col = mix(col, foam_color, crest * 0.16);

	// Sun reflection — a broad warm sheen toward the sun plus a tighter glint,
	// both using the rippled normal so they scatter into a shimmering path.
	vec3 sd = normalize(sun_dir);
	float sun_amt = max(dot(R, sd), 0.0);
	float sheen = pow(sun_amt, 6.0);
	float glint = pow(sun_amt, 90.0);
	col += sun_color * (sheen * 0.5 + glint * 2.2);

	// Soft foam line along the shore.
	float foam = smoothstep(land_radius, land_radius + 7.0, dist)
		* (1.0 - smoothstep(land_radius + 7.0, land_radius + shore_width * 0.7, dist));
	foam *= 0.55 + 0.45 * vnoise(ruv * 3.2 + TIME * 0.12);
	col = mix(col, foam_color, clamp(foam, 0.0, 1.0) * 0.7);

	// Dissolve into the horizon haze so sea -> sky is seamless.
	float haze = smoothstep(haze_start, haze_end, dist);
	col = mix(col, haze_color, haze);

	ALBEDO = col;
	ALPHA = water;
}
