#pragma once

#include <cstdint>
#include <random>
#include <vector>

#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/multi_mesh_instance3d.hpp>
#include <godot_cpp/classes/node3d.hpp>

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

	int spawn(const Ref<SwarmType> &p_type, const Vector3 &p_position, double p_hp_mult, double p_dmg_mult);
	int apply_damage_in_radius(const Vector3 &p_center, double p_radius, double p_amount, int p_type);
	int apply_damage_in_cone(const Vector3 &p_origin, const Vector3 &p_direction, double p_angle_deg, double p_range,
			double p_amount, int p_type);
	void apply_impulse_in_radius(const Vector3 &p_center, double p_radius, double p_force);
	int query_count_in_radius(const Vector3 &p_center, double p_radius);
	int get_alive_count() const;
	void clear_all();
	double get_last_step_ms() const;
	// Debugging and checks: where the enemy in this slot stands (zero if the slot is free).
	Vector3 get_enemy_position(int p_index) const;

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
	};

	void _allocate();
	int _type_index(const Ref<SwarmType> &p_type);
	void _size_multimesh(TypeSlot &p_slot);
	void _step(double p_dt);
	void _free(int p_index);
	void _hit(int p_index, double p_amount, int p_type);
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

	double accumulator = 0.0;
	double last_step_ms = 0.0;
	std::mt19937 rng;
};
