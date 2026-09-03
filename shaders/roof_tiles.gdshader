shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 tile_color : source_color = vec4(0.72, 0.42, 0.28, 1.0);
uniform vec4 grout_color : source_color = vec4(0.50, 0.38, 0.30, 1.0);
uniform vec2 tile_size = vec2(0.38, 0.38);

varying vec3 v_world_pos;
varying vec3 v_world_n;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_n = mat3(MODEL_MATRIX) * NORMAL;
}

void fragment() {
	vec3 n = normalize(v_world_n);
	vec3 col = tile_color.rgb;
	float rough = 0.82;

	if (n.y > 0.55) {
		vec2 uv = v_world_pos.xz / tile_size;
		float row = floor(uv.y);
		uv.x += 0.5 * mod(row, 2.0);
		vec2 cell = floor(uv);
		vec2 f = fract(uv);
		float h = fract(sin(dot(cell, vec2(12.73, 45.21))) * 43758.5453);
		vec3 tile = tile_color.rgb * (0.88 + h * 0.22);
		tile = mix(tile, tile * vec3(1.05, 0.95, 0.88), step(0.55, h));
		float grout = 1.0 - smoothstep(0.045, 0.08, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		col = mix(tile, grout_color.rgb, grout);
		rough = mix(0.78, 0.95, grout);
		NORMAL = normalize(NORMAL + vec3((f.x - 0.5) * 0.18, 0.0, (f.y - 0.5) * 0.18) * (1.0 - grout));
	} else {
		col = mix(tile_color.rgb * 0.72, grout_color.rgb, 0.35);
		rough = 0.9;
	}

	float ndv = clamp(dot(normalize(VIEW), normalize(NORMAL)), 0.0, 1.0);
	col *= 0.82 + 0.18 * ndv;
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.14;
}
