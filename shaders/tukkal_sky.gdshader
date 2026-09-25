shader_type sky;
// Tukkal Raat sky: deep indigo overhead falling to a magenta-pink glow on the
// horizon, strongest round a big pale moon sitting low ahead. A thin crescent
// hangs higher, and stars thin out toward the glow.

uniform vec3 zenith_col : source_color = vec3(0.06, 0.05, 0.16);
uniform vec3 mid_col : source_color = vec3(0.30, 0.16, 0.40);
uniform vec3 horizon_col : source_color = vec3(0.86, 0.40, 0.58);
uniform vec3 glow_col : source_color = vec3(1.0, 0.62, 0.72);
uniform vec3 below_col : source_color = vec3(0.16, 0.09, 0.22);
uniform vec3 moon_dir = vec3(0.0, 0.06, -1.0);
uniform vec3 moon_col : source_color = vec3(1.0, 0.90, 0.92);
uniform float moon_size = 0.075;
uniform vec3 crescent_dir = vec3(0.34, 0.42, -0.84);
uniform float crescent_size = 0.028;
uniform float star_density = 0.9;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 md = normalize(moon_dir);
	float up = d.y;

	// Height gradient: indigo above, violet band, pink at the horizon.
	float h = clamp(up, 0.0, 1.0);
	vec3 col = mix(horizon_col, mid_col, smoothstep(0.0, 0.22, h));
	col = mix(col, zenith_col, smoothstep(0.18, 0.75, h));
	// Below the horizon: a dark violet floor, so the far land melts into it.
	col = mix(col, below_col, smoothstep(0.0, -0.12, up));

	// The glow round the moon, spreading along the horizon.
	float to_moon = max(dot(d, md), 0.0);
	// A tight bright halo, a wider soft one, and a band of glow lying along
	// the horizon under the moon. Kept tight so the night stays indigo.
	float halo = pow(to_moon, 60.0) * 0.8 + pow(to_moon, 14.0) * 0.22;
	float band = exp(-abs(up) * 7.0) * pow(to_moon, 3.0);
	col += glow_col * (halo + band * 0.4);

	// The moon disc itself, soft edged.
	float ang = acos(clamp(dot(d, md), -1.0, 1.0));
	float disc = 1.0 - smoothstep(moon_size * 0.92, moon_size, ang);
	col = mix(col, moon_col * 1.6, disc);

	// Crescent: a disc with a second disc biting out of it.
	vec3 cd = normalize(crescent_dir);
	float ca = acos(clamp(dot(d, cd), -1.0, 1.0));
	vec3 bite_dir = normalize(cd + vec3(0.012, 0.010, 0.0));
	float ba = acos(clamp(dot(d, bite_dir), -1.0, 1.0));
	float cres = (1.0 - smoothstep(crescent_size * 0.85, crescent_size, ca)) * smoothstep(crescent_size * 0.78, crescent_size * 0.95, ba);
	col = mix(col, moon_col * 1.4, cres);

	// Stars: sparse, twinkling, gone near the glow and the horizon.
	if (up > 0.02) {
		vec3 cell = floor(d * 140.0);
		float s = hash3(cell);
		float star = step(1.0 - 0.012 * star_density, s);
		vec3 f = fract(d * 140.0) - 0.5;
		float pt = smoothstep(0.35, 0.0, length(f));
		float twinkle = 0.6 + 0.4 * sin(TIME * (1.5 + s * 4.0) + s * 40.0);
		float fade = smoothstep(0.04, 0.3, up) * (1.0 - clamp(halo * 2.5, 0.0, 1.0));
		col += vec3(1.0, 0.95, 1.0) * star * pt * twinkle * fade * 1.4;
	}
	COLOR = col;
}
