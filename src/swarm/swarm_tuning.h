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
	SWARM_ACCESSORS(double, root_fade_time)
	SWARM_ACCESSORS(double, flow_rebuild_interval)
	SWARM_ACCESSORS(double, flow_direct_range)
	SWARM_ACCESSORS(int, flow_window_cells)
	SWARM_ACCESSORS(int, flow_window_margin)
	SWARM_ACCESSORS(double, despawn_distance)

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
	// The shader's rooted amount eases from 1 to 0 over a root's last this-many seconds.
	double root_fade_time = 0.0;
	// The flow field (spec §11.1) rebuilds when Taln changes cell, at most
	// once per this many seconds; a ground change rebuilds it at once.
	double flow_rebuild_interval = 0.0;
	// Enemies this far or closer along the field seek Taln directly.
	double flow_direct_range = 0.0;
	// The field covers a square window of this many cells per side around
	// Taln (spec v1.4 #5); 0, or a ground smaller than the window, covers the
	// whole ground.
	int flow_window_cells = 0;
	// The window recenters on Taln once he comes within this many cells of
	// an edge that isn't the ground's own.
	int flow_window_margin = 0;
	// Swarm-tier enemies farther than this from Taln (XZ) are removed
	// unrewarded; 0 never removes them. Elites are never removed.
	double despawn_distance = 0.0;
};
