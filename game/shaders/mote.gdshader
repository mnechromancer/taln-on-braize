shader_type spatial;
render_mode unshaded, cull_back;
// Investiture mote (spec §2.3): small, faceted, Honor hue, emissive only (no
// lights, spec §12). Per-instance custom data from MoteServer: x = phase,
// y = fade (1 while it waits or flies, falling to 0 as it sinks into the ground).

uniform vec3 color : source_color = vec3(0.812, 0.910, 1.0);
// Brightness of the darkest facet relative to the brightest.
uniform float facet_floor = 0.6;
uniform float spin_speed = 1.5;
uniform float bob_height = 0.04;
uniform float bob_speed = 3.0;

varying float fade;

void vertex() {
	float a = TIME * spin_speed + INSTANCE_CUSTOM.x;
	VERTEX.xz = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX.xz;
	VERTEX.y += sin(TIME * bob_speed + INSTANCE_CUSTOM.x) * bob_height;
	fade = INSTANCE_CUSTOM.y;
}

void fragment() {
	// Flat per-facet normal from screen-space derivatives: faceted without a lit pass.
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	float facet = clamp(dot(n, normalize(vec3(0.3, 0.8, 0.5))) * 0.5 + 0.5, 0.0, 1.0);
	ALBEDO = color * mix(facet_floor, 1.0, facet);
	// Dithered fade keeps motes in the opaque pass.
	ALPHA = clamp(fade, 0.0, 1.0);
	ALPHA_HASH_SCALE = 1.0;
}
