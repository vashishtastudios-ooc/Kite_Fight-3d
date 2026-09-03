shader_type sky;
render_mode use_half_res_pass;

// Based on axilirate "Stylized Sky Shader With Clouds" (CC0)
// https://godotshaders.com/shader/stylized-sky-shader-with-clouds/
// Day-weighted: sunset only when the sun is on the horizon.

uniform vec3 day_bottom_color : source_color = vec3(0.58, 0.70, 0.84);
uniform vec3 day_top_color : source_color = vec3(0.26, 0.46, 0.74);

uniform vec3 sunset_bottom_color : source_color = vec3(0.90, 0.58, 0.36);
uniform vec3 sunset_top_color : source_color = vec3(0.30, 0.36, 0.55);

uniform vec3 night_bottom_color : source_color = vec3(0.06, 0.08, 0.16);
uniform vec3 night_top_color : source_color = vec3(0.02, 0.03, 0.08);

uniform vec3 horizon_color_day : source_color = vec3(0.86, 0.76, 0.58);
uniform vec3 horizon_color_sunset : source_color = vec3(0.95, 0.55, 0.28);
uniform vec3 horizon_color_night : source_color = vec3(0.12, 0.18, 0.32);
uniform float horizon_falloff : hint_range(0.0, 20.0, 0.1) = 7.5;

uniform vec3 sun_col : source_color = vec3(1.0, 0.94, 0.78);
uniform float sun_size : hint_range(0.01, 1.0) = 0.055;
uniform float sun_blur : hint_range(0.01, 1.0) = 0.06;

uniform sampler2D clouds_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D clouds_distort_texture : filter_linear_mipmap, repeat_enable;
uniform sampler2D clouds_noise_texture : filter_linear_mipmap, repeat_enable;
uniform vec3 clouds_main_color : source_color = vec3(0.96, 0.95, 0.93);
uniform vec3 clouds_edge_color : source_color = vec3(0.78, 0.82, 0.88);
uniform float clouds_speed : hint_range(0.0, 0.2, 0.001) = 0.048;
uniform float clouds_scale : hint_range(0.0, 1.0, 0.01) = 0.09;
uniform float clouds_cutoff : hint_range(0.0, 1.0, 0.01) = 0.26;
uniform float clouds_fuzziness : hint_range(0.0, 1.0, 0.01) = 0.28;
uniform float clouds_opacity : hint_range(0.0, 1.0, 0.01) = 0.88;

void sky() {
	float y_safe = max(abs(EYEDIR.y), 0.08);
	vec2 sky_uv = EYEDIR.xz / y_safe;
	float height = clamp(EYEDIR.y, 0.0, 1.0);

	float sun_el = LIGHT0_DIRECTION.y;
	float day_w = smoothstep(-0.04, 0.10, sun_el);
	float night_w = 1.0 - day_w;
	float sunset_w = exp(-pow(sun_el / 0.14, 2.0)) * day_w;

	vec3 gradient = mix(day_bottom_color, day_top_color, pow(height, 0.72));
	gradient = mix(gradient, mix(sunset_bottom_color, sunset_top_color, height), sunset_w);
	gradient = mix(gradient, mix(night_bottom_color, night_top_color, height), night_w);

	vec3 haze = mix(day_bottom_color, horizon_color_day, 0.28);
	float near_horizon = 1.0 - smoothstep(0.02, 0.22, abs(EYEDIR.y));
	gradient = mix(gradient, haze, near_horizon * 0.7);
	float horizon = exp(-abs(EYEDIR.y) * horizon_falloff);
	vec3 horizon_glow = horizon * mix(
		mix(horizon_color_night, horizon_color_day, day_w),
		horizon_color_sunset,
		sunset_w
	) * 0.35;

	float sun_distance = distance(EYEDIR.xyz, LIGHT0_DIRECTION);
	float core = smoothstep(sun_size, sun_size * 0.28, sun_distance) * day_w;
	float halo = exp(-sun_distance / max(sun_blur * 2.8, 0.02)) * day_w;
	float wash = exp(-sun_distance * 3.2) * day_w;
	vec3 sun = sun_col * (core * 0.9 + halo * 0.55 + wash * 0.22);

	vec2 drift = vec2(TIME * clouds_speed, TIME * clouds_speed * 0.22);
	vec2 drift2 = vec2(-TIME * clouds_speed * 0.55, TIME * clouds_speed * 0.08);
	float base = texture(clouds_texture, sky_uv * clouds_scale + drift).r;
	float warp = texture(clouds_distort_texture, sky_uv * clouds_scale * 1.35 + drift2 + base * 0.12).r;
	float detail = texture(clouds_noise_texture, sky_uv * clouds_scale * 2.4 + drift * 1.6).r;
	float n = base * 0.58 + warp * 0.27 + detail * 0.15;
	// Planar UVs smear into a white stripe at the horizon — fade that out.
	n *= smoothstep(0.08, 0.28, height);
	float clouds_value = smoothstep(clouds_cutoff, clouds_cutoff + clouds_fuzziness, n);
	vec3 clouds = mix(clouds_edge_color, clouds_main_color, clouds_value);

	vec3 col = gradient + horizon_glow + sun * (1.0 - clouds_value * 0.7);
	col = mix(col, clouds, clouds_value * clouds_opacity);

	COLOR = col;
}
