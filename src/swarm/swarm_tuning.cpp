#include "swarm_tuning.h"

void SwarmTuning::_bind_methods() {
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, step_rate, PROPERTY_HINT_RANGE, "0,120,1,suffix:Hz");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, grid_cell_size, PROPERTY_HINT_RANGE, "0,10,0.1,suffix:m");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, max_speed_ratio, PROPERTY_HINT_RANGE, "0,1,0.01");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, separation_range, PROPERTY_HINT_RANGE, "0,10,0.1,suffix:radii");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, impulse_decay, PROPERTY_HINT_RANGE, "0,50,0.1,suffix:/s");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, contact_cooldown, PROPERTY_HINT_RANGE, "0,5,0.01,suffix:s");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, hit_flash_time, PROPERTY_HINT_RANGE, "0,1,0.01,suffix:s");
}
