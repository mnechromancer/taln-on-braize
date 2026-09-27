#pragma once

#include <cstdint>
#include <random>
#include <vector>

#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/multi_mesh_instance3d.hpp>
#include <godot_cpp/classes/node3d.hpp>

#include "flow_field.h"
#include "mote_server.h"
#include "swarm_tuning.h"
#include "swarm_type.h"

using namespace godot;

// Swarm-tier enemies as data (spec §11.2): parallel arrays allocated once for
// `capacity` enemies, a free-list for dead slots, a fixed-rate simulation run
// from _physics_process, and one MultiMeshInstance3D per swarm type drawn with
// positions interpolated between simulation steps. There is no node or script
// per enemy.
//
// The ground comes from StationGround via set_ground(): per-cell heights and a
// blocked mask. Enemies never step into blocked cells and stand on the heights.
//
// A flow field over the same cells (spec §11.1) routes enemies around walls
// and cliffs toward Taln. It rebuilds when Taln changes cell (at most once per
// flow_rebuild_interval) and whenever the ground or target changes, on the
// next physics tick that runs no simulation step. Enemies follow it
// unless they're within flow_direct_range of Taln along it, can see his cell
// in a straight grid line, or can't reach him at all; then they seek directly.
// Rooted enemies don't steer, so they ignore it.
class SwarmServer : public Node3D {
	GDCLASS(SwarmServer, Node3D);

public:
	SwarmServer();

	void _ready() override;
	void _physics_process(double p_delta) override;
	void _process(double p_delta) override;

	void set_ground(const PackedFloat32Array &p_heights, const PackedByteArray &p_blocked, int p_width, int p_depth,
			double p_cell_size, const Vector2 &p_origin);
	void set_target(Node3D *p_target);
	Node3D *get_target() const;
	// Rewarded kills drop a mote of their type's investiture_drop here.
	void set_mote_server(MoteServer *p_motes);
	MoteServer *get_mote_server() const;

	int spawn(const Ref<SwarmType> &p_type, const Vector3 &p_position, double p_hp_mult, double p_dmg_mult);
	int apply_damage_in_radius(const Vector3 &p_center, double p_radius, double p_amount, int p_type);
	int apply_damage_in_cone(const Vector3 &p_origin, const Vector3 &p_direction, double p_angle_deg, double p_range,
			double p_amount, int p_type);
	void apply_impulse_in_radius(const Vector3 &p_center, double p_radius, double p_force);
	int query_count_in_radius(const Vector3 &p_center, double p_radius);
	int apply_root_in_cone(const Vector3 &p_origin, const Vector3 &p_direction, double p_angle_deg, double p_range,
			double p_duration);
	int apply_slow_in_radius(const Vector3 &p_center, double p_radius, double p_factor, double p_duration);
	// The enemy in this slot expires after p_seconds (0 clears it): it is
	// removed with enemy_died(..., rewarded = false), since nothing killed it.
	void set_enemy_lifetime(int p_index, double p_seconds);
	int get_rooted_count() const;
	Vector3 find_nearest(const Vector3 &p_center, double p_radius);
	Vector3 find_densest_direction(const Vector3 &p_origin, const Vector3 &p_forward, double p_half_angle_deg,
			double p_range, int p_sectors);
	int get_alive_count() const;
	// Mean position of every live enemy; Vector3.INF if there are none.
	Vector3 get_alive_centroid() const;
	void clear_all();
	// Reseeds the random rolls (spawn speeds, animation phases) for reproducible runs (spec §11.5).
	void set_seed(int64_t p_seed);
	double get_last_step_ms() const;
	// Everything the last physics tick cost: steps plus any flow rebuild.
	double get_last_tick_ms() const;
	// Flow field: rebuild now toward the target's cell; time and count of
	// rebuilds; path distance in meters from the cell under a point to the
	// goal (negative if unreachable); the flow there; whether that cell sees
	// the goal in a straight grid line. For checks and debugging.
	void rebuild_flow_field();
	double get_last_flow_build_ms() const;
	int get_flow_build_count() const;
	Vector2i get_flow_goal_cell() const;
	double get_flow_distance(const Vector3 &p_position) const;
	Vector3 get_flow_direction(const Vector3 &p_position) const;
	bool is_flow_line_clear(const Vector3 &p_position);
	// Debugging and checks: whether the slot holds a live enemy, and where it
	// stands (zero if the slot is free).
	bool is_enemy_alive(int p_index) const;
	Vector3 get_enemy_position(int p_index) const;
	// Checks: seconds of root and slow left on the enemy in this slot.
	double get_enemy_root_time(int p_index) const;
	double get_enemy_slow_time(int p_index) const;

	void set_capacity(int p_capacity);
	int get_capacity() const;
	SWARM_ACCESSORS(Ref<SwarmTuning>, tuning)
	SWARM_ACCESSORS(double, target_move_speed)
	SWARM_ACCESSORS(double, target_radius)

protected:
	static void _bind_methods();

private:
	struct TypeSlot {
		Ref<SwarmType> type;
		MultiMeshInstance3D *instance = nullptr;
		Ref<MultiMesh> multimesh;
		PackedFloat32Array buffer;
		int drawn = 0;
	};

	struct Contact {
		double damage;
		int type;
	};

	struct Death {
		StringName type_id;
		Vector3 position;
		bool rewarded;
	};

	void _allocate();
	int _type_index(const Ref<SwarmType> &p_type);
	void _size_multimesh(TypeSlot &p_slot);
	void _step(double p_dt);
	// p_step_due: a step runs this tick, so any rebuild waits for the next one.
	void _update_flow(double p_delta, bool p_step_due);
	void _build_flow(const Vector3 &p_goal);
	// Unit direction an enemy at p_position steers toward p_goal: the flow,
	// or straight at it (see the class comment).
	Vector2 _seek_direction(const Vector3 &p_position, const Vector3 &p_goal);
	void _free(int p_index);
	void _hit(int p_index, double p_amount, int p_type);
	// Inside the range, and either within the angle or overlapping the origin.
	bool _in_cone(int p_index, const Vector3 &p_origin, const Vector2 &p_forward, real_t p_min_cos, real_t p_range) const;
	Vector2 _separation(int p_index);
	void _slide(int p_index, real_t p_dx, real_t p_dz);
	bool _blocked_at(real_t p_x, real_t p_z) const;
	real_t _ground_height(real_t p_x, real_t p_z, real_t p_fallback) const;
	real_t _radius(int p_index) const;
	double _step_length() const;

	void _rebuild_grid();
	int _grid_cell(real_t p_x, real_t p_z) const;
	// Calls p_visit(index) for every live enemy that may lie within p_reach of
	// (p_x, p_z) on XZ. Callers still check the exact distance.
	template <typename Visit>
	void _for_each_near(real_t p_x, real_t p_z, real_t p_reach, Visit &&p_visit);

	int capacity = 800;
	Ref<SwarmTuning> tuning;
	ObjectID target_id;
	ObjectID motes_id;
	double target_move_speed = 0.0;
	double target_radius = 0.0;

	// Per-enemy data, indexed by slot.
	std::vector<Vector3> position;
	std::vector<Vector3> previous_position;
	std::vector<Vector3> velocity;
	std::vector<Vector3> impulse;
	std::vector<double> hp;
	std::vector<double> hp_mult;
	std::vector<double> dmg_mult;
	std::vector<int> type_index;
	std::vector<double> speed;
	std::vector<double> contact_cooldown;
	std::vector<double> hit_flash;
	std::vector<float> phase;
	std::vector<double> age;
	std::vector<float> facing;
	// Rooted enemies don't seek or separate and ignore impulses; they still
	// deal contact damage.
	std::vector<double> root_time;
	// Speed multiplier while slow_time > 0.
	std::vector<double> slow_mult;
	std::vector<double> slow_time;
	// Seconds left to live; 0 means no limit.
	std::vector<double> lifetime;
	std::vector<uint8_t> alive;
	std::vector<int> free_slots;
	int alive_count = 0;

	std::vector<TypeSlot> types;
	real_t max_radius = 0.0;

	// Ground copy from StationGround.
	bool has_ground = false;
	std::vector<float> ground_heights;
	std::vector<uint8_t> ground_blocked;
	int ground_width = 0;
	int ground_depth = 0;
	real_t ground_cell_size = 1.0;
	Vector2 ground_origin;
	AABB ground_bounds;

	// Spatial grid over the ground bounds (counting sort by cell).
	int grid_cols = 0;
	int grid_rows = 0;
	real_t grid_cell_size = 0.0;
	std::vector<int> grid_start;
	std::vector<int> grid_items;
	std::vector<int> grid_cell_of;
	bool grid_dirty = true;

	FlowField flow;
	bool flow_dirty = true;
	double flow_since_build = 0.0;
	double last_flow_build_ms = 0.0;
	int flow_builds = 0;

	double accumulator = 0.0;
	double last_step_ms = 0.0;
	double last_tick_ms = 0.0;
	std::mt19937 rng;
};
