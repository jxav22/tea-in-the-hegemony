shader_type canvas_item;
// Compatibility renderer — no spatial, no screen-space compute.

uniform vec4 vignette_color : source_color = vec4(0.043, 0.071, 0.125, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float softness : hint_range(0.1, 2.0) = 0.85;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	float vig = smoothstep(softness, softness - 0.55, dist);
	float mask = mix(1.0, vig, strength);
	COLOR = vec4(mix(vignette_color.rgb, tex.rgb, mask), tex.a);
}
