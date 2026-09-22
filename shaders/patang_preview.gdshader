shader_type canvas_item;

// Flat patang for the shop card: same designs as the 3D sail, drawn in 2D.

#include "res://shaders/patang.gdshaderinc"

uniform int pattern = 1;
uniform vec3 col0 : source_color = vec3(0.96, 0.92, 0.84);
uniform vec3 col1 : source_color = vec3(0.86, 0.16, 0.42);
uniform vec3 col2 : source_color = vec3(0.98, 0.80, 0.18);
uniform vec3 col3 : source_color = vec3(0.30, 0.10, 0.12);
uniform vec3 ink : source_color = vec3(0.10, 0.05, 0.06);
uniform vec3 spar : source_color = vec3(0.42, 0.28, 0.14);
uniform float kaman_arch = 0.0;

void fragment() {
	// The rect maps onto the sail's real footprint (1.16 m wide, 1.40 m tall)
	// with a small margin, nose at the top.
	float margin = 0.06;
	vec2 uv = (UV - 0.5) * (1.0 + margin * 2.0);
	vec2 xz = vec2(uv.x * 2.0 * SAIL_HALF_W, -uv.y * (SAIL_NOSE + SAIL_TAIL) + (SAIL_NOSE - SAIL_TAIL) * 0.5 + SAIL_CROSS_Z);
	vec2 q = patang_q(xz);
	vec2 p = patang_p(xz);
	float dia = abs(q.x) + abs(q.y);

	vec3 col = patang_paint(q, p, pattern, col0, col1, col2, col3);
	// Bamboo spars: the spine and the bow.
	col = mix(col, spar, pfill(abs(q.x) - 0.018) * pfill(dia - 0.98));
	if (kaman_arch > 0.5) {
		col = mix(col, spar, kaman_cover(xz, 0.012) * pfill(dia - 0.98));
	} else {
		col = mix(col, spar, pfill(abs(q.y) - 0.016) * pfill(dia - 0.98));
	}
	// Inked outline so the shape reads on the dark card.
	col = mix(col, ink, pfill(abs(dia - 1.0) - 0.035));
	COLOR = vec4(col, pfill(dia - 1.035));
}
