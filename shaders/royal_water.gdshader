shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 deep_color : source_color = vec3(0.018, 0.10, 0.16);
uniform vec3 glint_color : source_color = vec3(0.26, 0.61, 0.63);
uniform float night = 1.0;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float ripple = sin(world.z * 2.8 + sin(world.x * 0.18 + TIME * 0.23) * 3.0 + TIME * 0.7);
    float cross_wave = sin(world.z * 0.65 - world.x * 0.32 + TIME * 0.38);
    float path = exp(-pow((world.x - 90.0 + sin(world.z * 0.025) * 18.0) / 30.0, 2.0));
    float glint = smoothstep(0.70, 1.0, ripple) * smoothstep(-0.2, 0.8, cross_wave);
    vec3 c = deep_color + glint_color * glint * (0.045 + path * 0.38);
    float palace = exp(-pow((world.x + 98.0) / 47.0, 2.0)) * exp(-abs(world.z + 185.0) * 0.007);
    c += vec3(0.55, 0.18, 0.055) * glint * palace * 0.23 * night;
    ALBEDO = c;
}
