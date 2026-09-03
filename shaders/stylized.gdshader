shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo_color : source_color = vec4(0.62, 0.58, 0.52, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.78;
uniform float metalness : hint_range(0.0, 1.0) = 0.0;
uniform float variation : hint_range(0.0, 0.4) = 0.12;
uniform float edge_ao : hint_range(0.0, 0.6) = 0.22;

varying vec3 v_world_pos;
varying vec3 v_world_n;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_n = mat3(MODEL_MATRIX) * NORMAL;
}

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void fragment() {
	vec3 n = normalize(v_world_n);
	float blot = hash31(floor(v_world_pos * 3.4));
	vec3 col = albedo_color.rgb * (1.0 - variation * 0.5 + blot * variation);
	float ndv = clamp(dot(normalize(VIEW), normalize(NORMAL)), 0.0, 1.0);
	col *= 1.0 - edge_ao * pow(1.0 - ndv, 2.2);
	ALBEDO = col;
	ROUGHNESS = roughness;
	METALLIC = metalness;
	SPECULAR = mix(0.12, 0.55, metalness);
}
