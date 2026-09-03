shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform sampler2D ground_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ground_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 ground_repeat = vec2(0.133, 0.133);
uniform vec3 haze_color : source_color = vec3(0.62, 0.70, 0.80);
uniform vec3 hub = vec3(0.0, 0.0, 92.0);
uniform float haze_start = 720.0;
uniform float haze_end = 1480.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = v_world.xz * ground_repeat;
	vec3 col = texture(ground_albedo, uv).rgb;
	float rough = texture(ground_rough, uv).r;
	vec3 nts = texture(ground_normal, uv).xyz * 2.0 - 1.0;
	vec3 wn = normalize(vec3(nts.x, 1.0, nts.y));

	float dist = length(v_world.xz - hub.xz);
	float haze = smoothstep(haze_start, haze_end, dist);
	col = mix(col, haze_color, haze);

	float ndv = clamp(dot(normalize(VIEW), normalize(NORMAL)), 0.0, 1.0);
	ALBEDO = col * (0.88 + 0.12 * ndv);
	ROUGHNESS = mix(rough, 0.95, haze);
	SPECULAR = 0.06;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
