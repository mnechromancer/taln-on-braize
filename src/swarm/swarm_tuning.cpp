#include "swarm_tuning.h"

void SwarmTuning::_bind_methods() {
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, step_rate, PROPERTY_HINT_RANGE, "0,120,1,suffix:Hz");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, grid_cell_size, PROPERTY_HINT_RANGE, "0,10,0.1,suffix:m");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, max_speed_ratio, PROPERTY_HINT_RANGE, "0,1,0.01");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, separation_range, PROPERTY_HINT_RANGE, "0,10,0.1,suffix:radii");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, impulse_decay, PROPERTY_HINT_RANGE, "0,50,0.1,suffix:/s");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, contact_cooldown, PROPERTY_HINT_RANGE, "0,5,0.01,suffix:s");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, hit_flash_time, PROPERTY_HINT_RANGE, "0,1,0.01,suffix:s");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, root_fade_time, PROPERTY_HINT_RANGE, "0,2,0.01,suffix:s");
	ADD_GROUP("Flow field", "flow_");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, flow_rebuild_interval, PROPERTY_HINT_RANGE, "0,2,0.01,suffix:s");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, flow_direct_range, PROPERTY_HINT_RANGE, "0,20,0.1,suffix:m");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::INT, flow_window_cells, PROPERTY_HINT_RANGE, "0,1024,1,suffix:cells");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::INT, flow_window_margin, PROPERTY_HINT_RANGE, "0,512,1,suffix:cells");
	ADD_GROUP("Despawn", "despawn_");
	SWARM_BIND_PROPERTY(SwarmTuning, Variant::FLOAT, despawn_distance, PROPERTY_HINT_RANGE, "0,500,1,suffix:m");
}
