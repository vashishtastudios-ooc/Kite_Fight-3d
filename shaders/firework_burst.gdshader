shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled, fog_disabled;

// Diwali shell — BigWings / Tsar333 fireworks, layered for a night burst.
// https://godotshaders.com/shader/fireworks/
// https://www.shadertoy.com/view/lscGRl

uniform float burst_t : hint_range(0.0, 2.0) = 0.0;
uniform vec3 burst_col : source_color = vec3(1.0, 0.42, 0.12);
uniform float seed = 3.1;

const vec3 MOD3 = vec3(0.1031, 0.11369, 0.13787);

vec3 hash31(float p) {
	vec3 p3 = fract(vec3(p) * MOD3);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract(vec3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x));
}

float lighter(vec2 uv, vec2 pos, float size) {
	uv -= pos;
	size *= size;
	return size / max(dot(uv, uv), 0.00005);
}

vec3 festive(float h) {
	return 0.52 + 0.48 * sin(vec3(0.15, 2.15, 4.25) + h * 6.4 + seed);
}

vec3 explosion(vec2 uv, float t) {
	vec3 col = vec3(0.0);
	vec3 en = hash31(seed);
	float rise = 1.0 - pow(clamp(t * 0.92, 0.0, 1.0) - 1.0, 2.0);
	float fade = smoothstep(1.75, 0.22, t);

	for (int i = 0; i < 72; i++) {
		vec3 n = hash31(float(i) * 1.17 + seed) - 0.5;
		vec3 base = mix(burst_col, festive(n.z), 0.7);
		base = mix(base, en, 0.08);
		vec2 dir = normalize(n.xy + vec2(0.0008));
		float reach = 0.16 + abs(n.z) * 0.26;
		vec2 pos = dir * reach * rise;
		pos.y -= t * t * 0.10 * abs(n.x);
		float size = mix(0.016, 0.0035, smoothstep(0.0, 0.22, rise));
		size *= smoothstep(1.0, 0.14, rise);
		float tw = pow(abs(sin((rise + n.z) * 110.0 + t * 22.0)) * 0.5 + 0.5, 5.0);
		size += tw * 0.012;
		col += base * lighter(uv, pos, size) * (1.15 + tw * 0.9);
	}

	for (int j = 0; j < 28; j++) {
		vec3 n = hash31(float(j) * 3.9 + seed * 2.1) - 0.5;
		vec3 base = mix(vec3(1.0, 0.92, 0.55), festive(n.y), 0.45);
		vec2 pos = normalize(n.xy + vec2(0.001)) * (0.08 + abs(n.z) * 0.28) * rise;
		float size = 0.007 * smoothstep(1.0, 0.2, rise);
		col += base * lighter(uv, pos, size) * 1.8;
	}

	float r = length(uv);
	float flash = exp(-t * 4.2) * exp(-r * 16.0) * 1.2;
	col += mix(burst_col, vec3(1.0, 0.9, 0.6), 0.45) * flash;
	vec3 ring_c = festive(seed * 0.3);
	float ring = exp(-abs(r - rise * 0.22) * 28.0) * (1.0 - smoothstep(0.9, 1.4, t));
	col += ring_c * ring * 0.7;
	float halo = exp(-r * 11.0) * exp(-t * 3.0) * 0.22;
	col += burst_col * halo;
	float disk = 1.0 - smoothstep(0.28, 0.46, r);
	return col * fade * disk;
}

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float disk = 1.0 - smoothstep(0.28, 0.46, length(uv));
	if (disk < 0.004) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(0.0);
		ALPHA = 0.0;
	} else {
		vec3 c = explosion(uv, burst_t);
		float a = clamp(dot(c, vec3(0.26, 0.40, 0.22)) * 1.25, 0.0, 1.0) * disk;
		ALBEDO = c;
		EMISSION = c * 1.8;
		ALPHA = a;
	}
}
