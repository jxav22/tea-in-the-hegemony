shader_type canvas_item;
// Light film grain for dialogue/notebook panels. Compatibility-safe.

uniform float grain_amount : hint_range(0.0, 0.2) = 0.045;
uniform float time_scale : hint_range(0.0, 4.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * tint;
	float n = hash(UV * vec2(1024.0, 768.0) + vec2(TIME * time_scale));
	tex.rgb += (n - 0.5) * grain_amount;
	COLOR = tex;
}
