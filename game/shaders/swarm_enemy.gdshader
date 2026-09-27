shader_type spatial;
// Placeholder swarm enemy (SwarmServer v0). Per-instance custom data from
// SwarmServer: x = animation phase, y = hit flash (1 at the hit, fading to 0),
// z = seconds since spawn. No lights on enemies (spec §12): the eyes are
// emissive only.

uniform vec3 body_color : source_color = vec3(0.353, 0.337, 0.310);
uniform vec3 eye_color : source_color = vec3(0.761, 0.094, 0.357);
uniform float eye_energy = 3.0;
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
varying vec3 custom;

void vertex() {
	VERTEX.y += base_offset;
	local_position = VERTEX;
	VERTEX.y += (sin(TIME * bob_speed + INSTANCE_CUSTOM.x) * 0.5 + 0.5) * bob_height;
	custom = INSTANCE_CUSTOM.xyz;
}

void fragment() {
	float side = abs(local_position.x);
	float eye = step(eye_band_bottom, local_position.y) * step(local_position.y, eye_band_top)
			* step(eye_inner, side) * step(side, eye_outer) * step(0.0, local_position.z);
	float flash = clamp(custom.y, 0.0, 1.0);
	ALBEDO = mix(body_color, vec3(1.0), flash);
	ROUGHNESS = 1.0;
	EMISSION = eye_color * eye_energy * eye + vec3(flash * flash_energy);
	// Dithered fade-in keeps enemies in the opaque pass.
	ALPHA = clamp(custom.z / fade_in_time, 0.0, 1.0);
	ALPHA_HASH_SCALE = 1.0;
}
