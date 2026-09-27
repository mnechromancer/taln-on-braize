#pragma once

#include <godot_cpp/classes/resource.hpp>

#include "property_macros.h"

using namespace godot;

// SwarmServer's own numbers (not per type). Values live in
// game/data/tuning/swarm_tuning.tres; the defaults here are deliberately zero.
class SwarmTuning : public Resource {
	GDCLASS(SwarmTuning, Resource);

public:
	SWARM_ACCESSORS(double, step_rate)
	SWARM_ACCESSORS(double, grid_cell_size)
	SWARM_ACCESSORS(double, max_speed_ratio)
	SWARM_ACCESSORS(double, separation_range)
	SWARM_ACCESSORS(double, impulse_decay)
	SWARM_ACCESSORS(double, contact_cooldown)
	SWARM_ACCESSORS(double, hit_flash_time)

protected:
	static void _bind_methods();

private:
	// Simulation steps per second (spec §12).
	double step_rate = 0.0;
	// Spatial grid cell size in meters.
	double grid_cell_size = 0.0;
	// Top swarm speed as a fraction of Taln's move speed (spec §8.2).
	double max_speed_ratio = 0.0;
	// Neighbors closer than this many radii push each other apart.
	double separation_range = 0.0;
	// Impulse velocity decay rate, per second.
	double impulse_decay = 0.0;
	// Seconds between contact hits from one enemy (spec §6.2).
	double contact_cooldown = 0.0;
	double hit_flash_time = 0.0;
};
