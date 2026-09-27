shader_type spatial;
// Placeholder swarm enemy (SwarmServer v0). Per-instance custom data from
// SwarmServer: x = animation phase, y = hit flash (1 at the hit, fading to 0),
// z = seconds since spawn, w = rooted (1 while rooted, easing to 0 as the root
// ends). No lights on enemies (spec §12): the eyes are emissive only.

uniform vec3 body_color : source_color = vec3(0.353, 0.337, 0.310);
uniform vec3 eye_color : source_color = vec3(0.761, 0.094, 0.357);
uniform float eye_energy = 3.0;
// Rooted enemies turn to stone: the body desaturates toward stone_color and
// the eyes dim to this fraction of eye_energy.
uniform vec3 stone_color : source_color = vec3(0.353, 0.337, 0.310);
uniform float rooted_eye_scale = 0.2;
// Eye band height above the feet, and how far each eye sits off center.
uniform float eye_band_bottom = 1.0;
uniform float eye_band_top = 1.1;
uniform float eye_inner = 0.03;
uniform float eye_outer = 0.11;
uniform float bob_height = 0.05;
uniform float bob_speed = 8.0;
uniform float flash_energy = 2.0;
uniform float fade_in_time = 0.3;
// The mesh is centered on its origin; this lifts its base to the feet.
uniform float base_offset = 0.65;

varying vec3 local_position;
varying vec4 custom;

void vertex() {
	VERTEX.y += base_offset;
	local_position = VERTEX;
	// Rooted enemies stop bobbing.
	VERTEX.y += (sin(TIME * bob_speed + INSTANCE_CUSTOM.x) * 0.5 + 0.5) * bob_height * (1.0 - INSTANCE_CUSTOM.w);
	custom = INSTANCE_CUSTOM;
}

void fragment() {
	float side = abs(local_position.x);
	float eye = step(eye_band_bottom, local_position.y) * step(local_position.y, eye_band_top)
			* step(eye_inner, side) * step(side, eye_outer) * step(0.0, local_position.z);
	float flash = clamp(custom.y, 0.0, 1.0);
	float rooted = clamp(custom.w, 0.0, 1.0);
	vec3 gray = vec3(dot(body_color, vec3(0.2126, 0.7152, 0.0722)));
	vec3 stone = mix(gray, stone_color, 0.5);
	ALBEDO = mix(mix(body_color, stone, rooted), vec3(1.0), flash);
	ROUGHNESS = 1.0;
	EMISSION = eye_color * eye_energy * mix(1.0, rooted_eye_scale, rooted) * eye + vec3(flash * flash_energy);
	// Dithered fade-in keeps enemies in the opaque pass.
	ALPHA = clamp(custom.z / fade_in_time, 0.0, 1.0);
	ALPHA_HASH_SCALE = 1.0;
}
