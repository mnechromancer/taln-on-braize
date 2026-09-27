shader_type spatial;
render_mode cull_disabled;
// Cracked ground for Stoneward skills (Art Direction): the slab keeps the
// Stoneward stone material and only the fracture lines glow. Through Toa'uma
// the glow is Voidlight (dark core, teal rim) with flicker and glitch-frames;
// through the Blade it is steady ochre (core_color = rim_color, flicker 0).
// Meant for a fan mesh from SkillBehavior.build_fan_mesh (UV.y = distance
// from the apex, 0 to 1).

uniform vec3 stone_color : source_color = vec3(0.549, 0.416, 0.263);
uniform vec3 core_color : source_color = vec3(0.420, 0.247, 0.627);
uniform vec3 rim_color : source_color = vec3(0.498, 0.890, 0.839);
uniform float glow_energy = 2.5;
// 1 for Voidlight flicker and glitch-frames, 0 for a steady glow.
uniform float flicker = 0.0;
// Fraction of glitch-frame slots in which the glow drops out.
uniform float glitch_rate = 0.08;
uniform float glitch_frames_per_second = 12.0;
// Crack cells per meter, and the crack core and rim half-widths in cell units.
uniform float crack_density = 1.2;
uniform float core_width = 0.035;
uniform float rim_width = 0.09;
// Softens the outer edge of the fan (fraction of the radius).
uniform float edge_soften = 0.12;
// Set per cast and per frame by the skill.
uniform float seed = 0.0;
uniform float fade = 1.0;

varying vec2 ground;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Distance to the nearest Voronoi cell border (Inigo Quilez's two-pass method).
float crack_distance(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 nearest_cell;
	vec2 nearest_offset;
	float best = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) - f;
			float d = dot(r, r);
			if (d < best) {
				best = d;
				nearest_offset = r;
				nearest_cell = g;
			}
		}
	}
	best = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = nearest_cell + vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) - f;
			if (dot(nearest_offset - r, nearest_offset - r) > 0.00001) {
				best = min(best, dot(0.5 * (nearest_offset + r), normalize(r - nearest_offset)));
			}
		}
	}
	return best;
}

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float e = crack_distance(ground * crack_density + vec2(seed));
	float core = 1.0 - smoothstep(core_width * 0.5, core_width, e);
	float rim = clamp(1.0 - smoothstep(rim_width * 0.5, rim_width, e) - core, 0.0, 1.0);

	float slot = floor(TIME * glitch_frames_per_second);
	float glitch = step(glitch_rate, fract(sin(slot * 91.7 + seed) * 437.5453));
	float wobble = 0.65 + 0.35 * sin(TIME * 31.0 + seed * 7.0);
	float energy = glow_energy * mix(1.0, wobble * glitch, flicker);

	ALBEDO = stone_color * (1.0 - 0.8 * (core + rim));
	ROUGHNESS = 1.0;
	EMISSION = (core_color * core + rim_color * rim) * energy * fade;
	// Dithered, like the swarm, so the slab stays in the opaque pass.
	ALPHA = fade * (1.0 - smoothstep(1.0 - edge_soften, 1.0, UV.y));
	ALPHA_HASH_SCALE = 1.0;
}
