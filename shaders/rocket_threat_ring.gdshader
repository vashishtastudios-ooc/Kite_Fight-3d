shader_type canvas_item;

// Red arc on the side the rocket launched from. 0 = forward (top), + = right.
uniform float threat_a = 0.0;
uniform float threat_b = 0.0;
uniform float threat_c = 0.0;
uniform float strength_a : hint_range(0.0, 1.0) = 0.0;
uniform float strength_b : hint_range(0.0, 1.0) = 0.0;
uniform float strength_c : hint_range(0.0, 1.0) = 0.0;
uniform float pulse = 1.0;

const float INNER = 0.74;
const float OUTER = 0.98;
const float HALF_W = 0.85;

float sector(float ang, float target, float str) {
	if (str < 0.01) {
		return 0.0;
	}
	float d = abs(atan(sin(ang - target), cos(ang - target)));
	float core = 1.0 - smoothstep(HALF_W * 0.35, HALF_W, d);
	float trail = exp(-d * 2.4) * 0.55;
	return (core + trail) * str;
}

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float r = length(uv);
	float ang = atan(uv.x, -uv.y);
	float ring = smoothstep(INNER - 0.01, INNER, r) * (1.0 - smoothstep(OUTER, OUTER + 0.012, r));
	float rim = smoothstep(0.012, 0.0, abs(r - mix(INNER, OUTER, 0.55))) * 0.22;
	float hit = max(sector(ang, threat_a, strength_a), max(sector(ang, threat_b, strength_b), sector(ang, threat_c, strength_c)));
	vec3 gold = vec3(0.72, 0.52, 0.22);
	vec3 red = vec3(1.0, 0.12, 0.08);
	vec3 hot = vec3(1.0, 0.55, 0.15);
	vec3 col = gold * (0.35 + rim);
	col = mix(col, mix(red, hot, pulse * 0.45), hit);
	float a = ring * (0.40 + hit * 0.95 * pulse);
	COLOR = vec4(col, a);
}
