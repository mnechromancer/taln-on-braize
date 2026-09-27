#pragma once

#include <cstdint>
#include <random>
#include <vector>

#include <godot_cpp/classes/material.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/multi_mesh_instance3d.hpp>
#include <godot_cpp/classes/node3d.hpp>

#include "mote_tuning.h"

using namespace godot;

// Investiture motes as data (spec §2.3, §11.1): kills drop them, they wait on
// the ground, fly to Taln once he comes within the pickup radius, and are
// collected on reaching him. One left on the ground for its lifetime sinks
// and fades into the ground and is lost. Parallel arrays with a free-list,
// simulated in _physics_process and drawn with one MultiMeshInstance3D,
// positions interpolated between physics ticks. A mote carries its base
// value and a tag (the dropping enemy's tier); the Investiture it grants
// (times the station value) is the listener's business.
class MoteServer : public Node3D {
	GDCLASS(MoteServer, Node3D);

public:
	MoteServer();

	void _ready() override;
	void _physics_process(double p_delta) override;
	void _process(double p_delta) override;

	// Returns the slot, or -1 when full (then the mote is reported lost at once).
	int spawn(const Vector3 &p_position, double p_value, int p_tag = 0);
	void set_target(Node3D *p_target);
	Node3D *get_target() const;
	// While frozen nothing moves, ages or is collected; drawing continues.
	void set_frozen(bool p_frozen);
	bool is_frozen() const;
	void clear_all();
	// Reseeds the random rolls (spawn speeds, animation phases) for reproducible runs (spec §11.5).
	void set_seed(int64_t p_seed);
	int get_count() const;
	// Checks and debugging.
	bool is_mote_alive(int p_index) const;
	Vector3 get_mote_position(int p_index) const;
	bool is_mote_flying(int p_index) const;

	void set_capacity(int p_capacity);
	int get_capacity() const;
	SWARM_ACCESSORS(Ref<MoteTuning>, tuning)
	void set_mesh(const Ref<Mesh> &p_mesh);
	Ref<Mesh> get_mesh() const;
	void set_material(const Ref<Material> &p_material);
	Ref<Material> get_material() const;

protected:
	static void _bind_methods();

private:
	void _allocate();
	void _free(int p_index);
	Vector3 _collect_point() const;

	int capacity = 1024;
	Ref<MoteTuning> tuning;
	Ref<Mesh> mesh;
	Ref<Material> material;
	ObjectID target_id;
	bool frozen = false;

	std::vector<Vector3> position;
	std::vector<Vector3> previous_position;
	std::vector<double> value;
	std::vector<int> tag;
	std::vector<double> age;
	// Seconds into the sink after lifetime ran out; negative while resting.
	std::vector<double> sinking;
	std::vector<float> phase;
	std::vector<uint8_t> flying;
	std::vector<uint8_t> alive;
	std::vector<int> free_slots;
	int count = 0;

	MultiMeshInstance3D *instance = nullptr;
	Ref<MultiMesh> multimesh;
	PackedFloat32Array buffer;
	std::mt19937 rng;
};
