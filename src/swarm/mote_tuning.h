#pragma once

#include <godot_cpp/classes/resource.hpp>

#include "property_macros.h"

using namespace godot;

// MoteServer's numbers (spec §2.3). Values live in
// game/data/tuning/mote_tuning.tres; the defaults here are deliberately zero.
class MoteTuning : public Resource {
	GDCLASS(MoteTuning, Resource);

public:
	SWARM_ACCESSORS(double, pickup_radius)
	SWARM_ACCESSORS(double, fly_speed)
	SWARM_ACCESSORS(double, collect_radius)
	SWARM_ACCESSORS(double, lifetime)
	SWARM_ACCESSORS(double, sink_time)
	SWARM_ACCESSORS(double, sink_depth)
	SWARM_ACCESSORS(double, hover_height)
	SWARM_ACCESSORS(double, target_height)
	SWARM_ACCESSORS(double, small_scale)
	SWARM_ACCESSORS(double, large_scale)
	SWARM_ACCESSORS(double, large_min_value)

protected:
	static void _bind_methods();

private:
	// Motes this close to Taln start flying to him (spec §2.3: 2.5 m).
	double pickup_radius = 0.0;
	// Flight speed once inside the pickup radius (18 m/s).
	double fly_speed = 0.0;
	// A flying mote this close to Taln's collect point is collected.
	double collect_radius = 0.0;
	// Seconds a mote waits on the ground before it sinks and is lost (30 s).
	double lifetime = 0.0;
	// Seconds the sink-and-fade takes after lifetime runs out.
	double sink_time = 0.0;
	// How far below its resting height a mote has sunk when it's gone.
	double sink_depth = 0.0;
	// Resting height above the ground.
	double hover_height = 0.0;
	// Height above Taln's feet that motes fly to (and pickup is measured from).
	double target_height = 0.0;
	// Mesh scale for ordinary motes, and for motes worth at least large_min_value.
	double small_scale = 0.0;
	double large_scale = 0.0;
	double large_min_value = 0.0;
};
