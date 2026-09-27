#include "mote_tuning.h"

void MoteTuning::_bind_methods() {
	SWARM_BIND_PROPERTY(MoteTuning, Variant::FLOAT, pickup_radius, PROPERTY_HINT_RANGE, "0,20,0.1,suffix:m");
	SWARM_BIND_PROPERTY(MoteTuning, Variant::FLOAT, fly_speed, PROPERTY_HINT_RANGE, "0,100,0.5,suffix:m/s");
	SWARM_BIND_PROPERTY(MoteTuning, Variant::FLOAT, collect_radius, PROPERTY_HINT_RANGE, "0,5,0.01,suffix:m");
	SWARM_BIND_PROPERTY(MoteTuning, Variant::FLOAT, lifetime, PROPERTY_HINT_RANGE, "0,300,0.5,suffix:s");
	SWARM_BIND_PROPERTY(MoteTuning, Variant::FLOAT, sink_time, PROPERTY_HINT_RANGE, "0,10,0.05,suffix:s");
	SWARM_BIND_PROPERTY(MoteTuning, Variant::FLOAT, sink_depth, PROPERTY_HINT_RANGE, "0,5,0.01,suffix:m");
	SWARM_BIND_PROPERTY(MoteTuning, Variant::FLOAT, hover_height, PROPERTY_HINT_RANGE, "0,5,0.01,suffix:m");
	SWARM_BIND_PROPERTY(MoteTuning, Variant::FLOAT, target_height, PROPERTY_HINT_RANGE, "0,5,0.01,suffix:m");
	ADD_GROUP("Look", "");
	SWARM_BIND_PROPERTY(MoteTuning, Variant::FLOAT, small_scale, PROPERTY_HINT_RANGE, "0,5,0.01");
	SWARM_BIND_PROPERTY(MoteTuning, Variant::FLOAT, large_scale, PROPERTY_HINT_RANGE, "0,5,0.01");
	SWARM_BIND_PROPERTY(MoteTuning, Variant::FLOAT, large_min_value, PROPERTY_HINT_RANGE, "0,1000,1");
}
