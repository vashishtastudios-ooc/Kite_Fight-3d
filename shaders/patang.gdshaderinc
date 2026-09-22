// Patang pattern library — the classic Indian fighter-kite paper designs.
// Shared by the 3D sail (kite.gdshader) and the shop preview (patang_preview),
// so the kite you buy is exactly the kite that flies.
//
// Two coordinate spaces:
//   q  — diamond-normalised: |q.x| + |q.y| = 1 on the sail edge, q.y = +1 at
//        the nose. Use for anything that follows the kite's edges.
//   p  — physical (metres / 0.7), so circles stay round. Use for moons, stars,
//        suns and eyes.

#define PAT_PANELS 0
#define PAT_ADHA 1
#define PAT_CHAAND 2
#define PAT_AANKH 3
#define PAT_PATTA 4
#define PAT_CHAAND_TARA 5
#define PAT_MAANG 6
#define PAT_SHATRANJ 7
#define PAT_DHAARI 8
#define PAT_CHAKRI 9
#define PAT_TUKKAL 10
#define PAT_KINARI 11

// Sail geometry (matches kite.gd _make_diamond).
const float SAIL_HALF_W = 0.58;
const float SAIL_CROSS_Z = 0.02;
const float SAIL_NOSE = 0.76;
const float SAIL_TAIL = 0.64;

// Kaman: the bamboo bow arches up toward the nose, meeting the spine at
// KAMAN_PEAK (≈ a third of the way down from the nose). Must match kite.gd.
const float KAMAN_PEAK = 0.30;

float kaman_z(float x) {
	float t = clamp(x / SAIL_HALF_W, -1.0, 1.0);
	return SAIL_CROSS_Z + (KAMAN_PEAK - SAIL_CROSS_Z) * (1.0 - t * t);
}

// Coverage of the kaman line. Never thinner than about a pixel, so the arch —
// the kite's arrowhead — still reads at fighting distance.
float kaman_cover(vec2 xz, float half_w) {
	float d = xz.y - kaman_z(xz.x);
	float px = max(fwidth(d), 1e-4);
	float w = max(half_w, px * 0.75);
	float between_tips = step(abs(xz.x), SAIL_HALF_W);
	return (1.0 - smoothstep(w - px, w + px, abs(d))) * between_tips;
}

vec2 patang_q(vec2 xz) {
	float y = xz.y - SAIL_CROSS_Z;
	return vec2(xz.x / SAIL_HALF_W, y > 0.0 ? y / SAIL_NOSE : y / SAIL_TAIL);
}

vec2 patang_p(vec2 xz) {
	return vec2(xz.x, xz.y - 0.08) / 0.7;
}

// Anti-aliased coverage of a signed distance (inside when sd < 0).
float pfill(float sd) {
	float w = max(fwidth(sd) * 0.8, 1e-4);
	return 1.0 - smoothstep(-w, w, sd);
}

float sd_circle(vec2 p, vec2 c, float r) {
	return length(p - c) - r;
}

// Inigo Quilez five-point star.
float sd_star5(vec2 p, float r, float rf) {
	vec2 k1 = vec2(0.809016994375, -0.587785252292);
	vec2 k2 = vec2(-k1.x, k1.y);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

// c0 paper, c1 main ink, c2 accent, c3 kinari (the folded edge strip).
vec3 patang_paint(vec2 q, vec2 p, int pat, vec3 c0, vec3 c1, vec3 c2, vec3 c3) {
	vec3 col = c0;
	float dia = abs(q.x) + abs(q.y);

	if (pat == PAT_ADHA) {
		// Half-and-half down the spine — the most common patang there is.
		col = mix(col, c1, pfill(-q.x));
		col = mix(col, c2, pfill(abs(q.x) - 0.022));
	} else if (pat == PAT_CHAAND) {
		// A full moon in the upper half.
		col = mix(col, c1, pfill(sd_circle(p, vec2(0.0, 0.34), 0.27)));
		col = mix(col, c2, pfill(abs(sd_circle(p, vec2(0.0, 0.34), 0.27)) - 0.018));
	} else if (pat == PAT_AANKH) {
		// The eye: nested diamonds.
		float d = abs(q.x) + abs(q.y - 0.04);
		col = mix(col, c1, pfill(d - 0.64));
		col = mix(col, c2, pfill(d - 0.46));
		col = mix(col, c1, pfill(d - 0.27));
		col = mix(col, c0, pfill(d - 0.11));
	} else if (pat == PAT_PATTA) {
		// Bands across the sail.
		col = mix(col, c1, pfill(abs(q.y - 0.24) - 0.12));
		col = mix(col, c2, pfill(abs(q.y + 0.27) - 0.09));
	} else if (pat == PAT_CHAAND_TARA) {
		// Crescent and star.
		float moon = max(sd_circle(p, vec2(-0.05, 0.34), 0.30), -sd_circle(p, vec2(0.08, 0.41), 0.25));
		col = mix(col, c1, pfill(moon));
		col = mix(col, c2, pfill(sd_star5(p - vec2(0.14, 0.33), 0.10, 0.45)));
		col = mix(col, c2, pfill(sd_star5(p - vec2(0.0, -0.52), 0.07, 0.45)));
	} else if (pat == PAT_MAANG) {
		// The parting: a stripe down the spine, a band along the arched kaman,
		// a tail patch.
		col = mix(col, c1, pfill(abs(q.x) - 0.07));
		vec2 xz = vec2(q.x * SAIL_HALF_W, (q.y > 0.0 ? q.y * SAIL_NOSE : q.y * SAIL_TAIL) + SAIL_CROSS_Z);
		col = mix(col, c1, pfill(abs(xz.y - kaman_z(xz.x)) - 0.034));
		col = mix(col, c2, pfill(abs(q.x) + abs(q.y + 0.74) - 0.24));
	} else if (pat == PAT_SHATRANJ) {
		// Chequers set square to the kite's edges.
		float a = q.x + q.y;
		float b = q.x - q.y;
		col = mix(col, c1, pfill(-sin(a * 6.2831853) * sin(b * 6.2831853)));
		col = mix(col, c2, pfill(dia - 0.17));
	} else if (pat == PAT_DHAARI) {
		// Diagonal stripes with fine accent lines.
		float s = sin((q.x + q.y) * 10.5);
		col = mix(col, c1, pfill(-s));
		col = mix(col, c2, pfill(abs(s) - 0.16));
	} else if (pat == PAT_CHAKRI) {
		// Sunburst.
		vec2 cp = p - vec2(0.0, 0.08);
		float ang = atan(cp.y, cp.x);
		col = mix(c2, c1, pfill(-sin(ang * 12.0)));
		col = mix(col, c1, pfill(sd_circle(cp, vec2(0.0), 0.21)));
		col = mix(col, c0, pfill(sd_circle(cp, vec2(0.0), 0.15)));
	} else if (pat == PAT_TUKKAL) {
		// Patched tips — nose and tail one colour, wing tips another.
		col = mix(col, c1, pfill(0.52 - q.y));
		col = mix(col, c1, pfill(q.y + 0.52));
		col = mix(col, c2, pfill(q.x + 0.5));
		col = mix(col, c2, pfill(0.5 - q.x));
	} else if (pat == PAT_KINARI) {
		// Plain paper, bold double border.
		col = mix(col, c1, pfill(0.84 - dia));
		col = mix(col, c2, pfill(abs(dia - 0.77) - 0.018));
	}

	// Every patang has its edge folded over the thread.
	col = mix(col, c3, pfill(0.935 - dia));
	return col;
}
