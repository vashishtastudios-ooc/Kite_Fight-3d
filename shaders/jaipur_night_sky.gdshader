shader_type sky;
// An indigo / peacock-blue night, with an off-centre ivory crescent.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void sky() {
    vec3 d = normalize(EYEDIR);
    float h = max(d.y, 0.0);
    vec3 col = mix(vec3(0.055, 0.023, 0.065), vec3(0.0015, 0.003, 0.015), smoothstep(0.0, 0.65, h));
    col += vec3(0.002, 0.008, 0.014) * exp(-pow((h - 0.27) * 5.0, 2.0));
    col += vec3(0.028, 0.007, 0.009) * exp(-pow((d.x + 0.35) * 2.0, 2.0)) * exp(-h * 9.0);
    vec2 uv = vec2(atan(d.x, -d.z), asin(d.y));
    vec2 grid = uv * 180.0;
    vec2 cell = floor(grid);
    vec2 offset = vec2(hash(cell), hash(cell + 32.7)) * 0.65 + 0.175;
    float star = 1.0 - smoothstep(0.035, 0.115, length(fract(grid) - offset));
    star *= step(0.965, hash(cell + 8.3)) * smoothstep(0.035, 0.30, h);
    col += vec3(0.66, 0.80, 1.0) * star * (0.6 + 0.4 * sin(TIME * 0.4 + hash(cell) * 90.0));
    vec3 moon = normalize(vec3(0.39, 0.34, -0.86));
    float distance_to_moon = length(d - moon);
    float disc = 1.0 - smoothstep(0.029, 0.031, distance_to_moon);
    float bite = smoothstep(0.028, 0.030, length(d - normalize(moon + vec3(0.017, 0.009, 0.005))));
    col += vec3(0.22, 0.32, 0.39) * exp(-distance_to_moon * 22.0) * 0.22;
    col += vec3(1.7, 1.46, 1.05) * disc * bite;
    COLOR = col;
}
