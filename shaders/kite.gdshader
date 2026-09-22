shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, fog_disabled;

#include "res://shaders/patang.gdshaderinc"
#include "res://shaders/patang_flex.gdshaderinc"

uniform float lift : hint_range(0.0, 1.0) = 0.0;
uniform float rim : hint_range(0.0, 2.0) = 0.0;
uniform vec3 rim_color : source_color = vec3(1.0, 0.84, 0.28);

// 0 = legacy vertex-colour panels; 1+ = a patang design (see patang.gdshaderinc).
uniform int pattern = 0;
uniform vec3 col0 : source_color = vec3(0.96, 0.92, 0.84);
uniform vec3 col1 : source_color = vec3(0.86, 0.16, 0.42);
uniform vec3 col2 : source_color = vec3(0.98, 0.80, 0.18);
uniform vec3 col3 : source_color = vec3(0.30, 0.10, 0.12);

varying vec2 v_xz;

float fibre(vec2 x) {
	return fract(sin(dot(floor(x), vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	// Pattern coordinates come from the rest shape, so the design stays
	// pinned to the paper while it bends.
	v_xz = VERTEX.xz;
	VERTEX = patang_flex(VERTEX);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float paper = 0.0;
	if (pattern > 0) {
		vec2 q = patang_q(v_xz);
		vec2 p = patang_p(v_xz);
		// Vertex colour is white on the face, a touch darker on the back.
		base = patang_paint(q, p, pattern, col0, col1, col2, col3) * COLOR.r;
		// Paper: faint fibres, and a soft crease where it is pasted to the spars.
		float grain = mix(fibre(v_xz * 180.0), fibre(v_xz * 71.0), 0.5);
		base *= 0.965 + 0.05 * grain;
		// Soft crease where the paper is pasted: the spine, and the bow — a
		// straight cross stick, or the arch.
		float bow_crease = mix(exp(-abs(q.y) * 70.0), exp(-abs(v_xz.y - kaman_z(v_xz.x)) * 90.0), kaman_arch);
		float crease = exp(-abs(q.x) * 70.0) + bow_crease * 0.8;
		base *= 1.0 - 0.10 * clamp(crease, 0.0, 1.0);
		if (kaman_arch > 0.5) {
			// The arched bow — the kite's arrowhead, pointing at the nose.
			// Bamboo core with a shadow edge, so it reads over any colour:
			// light across dark rings, dark across bright paper.
			base = mix(base, base * 0.22, kaman_cover(v_xz, 0.017) * 0.9);
			base = mix(base, vec3(0.80, 0.62, 0.36), kaman_cover(v_xz, 0.008));
		}
		paper = 1.0;
	}
	// True face normal from screen-space derivatives. The sail mesh stacks a
	// front and a back triangle on the same vertices, so its smoothed normals
	// cancel out and point along the spine — useless for light and fresnel.
	// This one always faces the viewer; light from behind comes through
	// BACKLIGHT, like real paper.
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(fn, VIEW) < 0.0) {
		fn = -fn;
	}
	NORMAL = fn;
	float ndv = clamp(dot(fn, VIEW), 0.0, 1.0);
	float r = pow(1.0 - ndv, 1.55) * rim;
	vec3 col = mix(base, base * 1.22 + vec3(0.07), lift);
	if (paper > 0.5) {
		// Far-kite lift for dyed paper: brighten by multiplying (an added grey
		// washes dark dyes to khaki), and push saturation so a small kite still
		// reads as its colours against the sky.
		col = base * (1.0 + 0.45 * lift);
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		col = max(mix(vec3(luma), col, 1.0 + 0.3 * lift), vec3(0.0));
	}
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.62, 0.82, paper), 0.38, lift);
	// Thin paper glows when the low sun is behind it.
	BACKLIGHT = col * 0.42 * paper;
	// Sky light soaking through the paper keeps dyed hues true under the
	// orange dusk sun — pink stays pink instead of going crimson.
	EMISSION = col * (0.18 * lift + 0.16 * paper) + rim_color * r;
}
