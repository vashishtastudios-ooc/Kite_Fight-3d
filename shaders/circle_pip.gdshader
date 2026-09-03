shader_type canvas_item;

void fragment() {
	vec2 c = UV - vec2(0.5);
	float r = length(c);
	float aa = fwidth(r) + 0.003;
	float mask = 1.0 - smoothstep(0.5 - aa, 0.5, r);
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tex.rgb, tex.a * mask);
}
