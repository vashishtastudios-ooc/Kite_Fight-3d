// Patang flex — how a paper fighter kite moves on its bamboo frame.
// One function, shared by the sail, the spars and the rim, so the whole kite
// bends together and nothing tears apart. Include after patang.gdshaderinc.
//
// Kite-local axes: +Z nose, +X span, +Y the face turned to the flyer. The wind
// presses from the flyer's side, so bending goes to -Y (away from you).
//
//   flex_bow     the kaman (cross spar) flexing: wing tips sweep back.
//   flex_billow  paper cupping between the spars under wind load.
//   flex_flutter the trailing edges and tips shivering in the airflow.

uniform float flex_bow = 0.0;
uniform float flex_billow = 0.0;
uniform float flex_flutter = 0.0;
// 1 = the bow is an arch (kaman_z), 0 = the old straight cross stick.
uniform float kaman_arch = 0.0;

vec3 patang_flex(vec3 v) {
	vec2 q = patang_q(v.xz);
	float ax = abs(q.x);
	float dia = abs(q.x) + abs(q.y);
	// The bow bends as a curve: nothing at the spine, most at the tips.
	float bow = ax * ax;
	// Paper is held by the spine, the bow and the edge thread; it bellies
	// out between them. With an arched bow the paper is held along the arch.
	float to_bow = mix(abs(q.y), abs(v.z - kaman_z(v.x)) / SAIL_NOSE, kaman_arch);
	float belly = clamp(1.0 - dia, 0.0, 1.0) * min(ax, to_bow) * 4.0;
	// Flutter lives on the free edges, strongest toward the tail.
	float edge = smoothstep(0.55, 1.0, dia);
	float trail = 0.55 + 0.45 * clamp(-q.y, 0.0, 1.0);
	float wave = sin(TIME * 34.0 + q.x * 7.0 - q.y * 12.0) + 0.5 * sin(TIME * 53.0 - q.x * 11.0);
	v.y += -flex_bow * 0.12 * bow - flex_billow * 0.065 * belly + flex_flutter * 0.028 * edge * trail * wave;
	v.z += -flex_bow * 0.035 * bow;
	return v;
}
