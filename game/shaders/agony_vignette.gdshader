shader_type canvas_item;
// Agony-hue edge vignette at a full meter (Art Direction, VFX: the Agony table).

uniform vec4 color : source_color = vec4(0.878, 0.345, 0.122, 0.55);
// Distance from the center (0) to the corners (about 1.41) where it starts and peaks.
uniform float inner = 0.7;
uniform float outer = 1.35;

void fragment() {
	float d = length((UV - 0.5) * 2.0);
	COLOR = vec4(color.rgb, color.a * smoothstep(inner, outer, d));
}
