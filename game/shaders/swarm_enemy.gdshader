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
// A commander's buff: the eyes burn brighter in this color. The disease:
// the body sickens toward blight_color.
uniform vec3 buff_eye_color : source_color = vec3(1.0, 0.55, 0.15);
uniform float buff_eye_scale = 2.5;
uniform vec3 blight_color : source_color = vec3(0.48, 0.60, 0.23);
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
// 1 while a commander's buff holds, 2 while infected, 3 for both.
varying float flags;

void vertex() {
	VERTEX.y += base_offset;
	local_position = VERTEX;
	// Rooted enemies stop bobbing.
	custom = INSTANCE_CUSTOM;
	// Unpack the flags from the rooted amount.
	flags = floor(custom.w / 10.0 + 0.001);
	custom.w -= flags * 10.0;
	VERTEX.y += (sin(TIME * bob_speed + custom.x) * 0.5 + 0.5) * bob_height * (1.0 - custom.w);
}

void fragment() {
	float side = abs(local_position.x);
	float eye = step(eye_band_bottom, local_position.y) * step(local_position.y, eye_band_top)
			* step(eye_inner, side) * step(side, eye_outer) * step(0.0, local_position.z);
	float flash = clamp(custom.y, 0.0, 1.0);
	float rooted = clamp(custom.w, 0.0, 1.0);
	float buffed = step(0.5, mod(flags, 2.0));
	float sick = step(1.5, flags);
	vec3 gray = vec3(dot(body_color, vec3(0.2126, 0.7152, 0.0722)));
	vec3 stone = mix(gray, stone_color, 0.5);
	vec3 body = mix(body_color, blight_color, sick * 0.7);
	ALBEDO = mix(mix(body, stone, rooted), vec3(1.0), flash);
	ROUGHNESS = 1.0;
	vec3 eyes = mix(eye_color, buff_eye_color, buffed) * eye_energy * mix(1.0, buff_eye_scale, buffed);
	EMISSION = eyes * mix(1.0, rooted_eye_scale, rooted) * eye + vec3(flash * flash_energy);
	// Dithered fade-in keeps enemies in the opaque pass.
	ALPHA = clamp(custom.z / fade_in_time, 0.0, 1.0);
	ALPHA_HASH_SCALE = 1.0;
}
