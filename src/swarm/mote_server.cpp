#include "mote_server.h"

#include <algorithm>
#include <cmath>

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace {

constexpr double kTau = 6.28318530717958647692;
// MultiMesh buffer layout: a 3x4 transform, then custom data (phase, fade, 0, 0).
constexpr int kFloatsPerInstance = 16;

struct Event {
	double value;
	int tag;
	bool collected;
};

} // namespace

MoteServer::MoteServer() :
		rng(std::random_device{}()) {
	multimesh.instantiate();
	multimesh->set_transform_format(MultiMesh::TRANSFORM_3D);
	multimesh->set_use_custom_data(true);
	_allocate();
}

void MoteServer::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		set_process(false);
		set_physics_process(false);
		return;
	}
	if (tuning.is_null()) {
		ERR_PRINT("MoteServer has no tuning; motes will not move.");
	}
	instance = memnew(MultiMeshInstance3D);
	instance->set_name("Motes");
	instance->set_as_top_level(true);
	// _process() interpolates; engine interpolation would blend packed instance slots.
	instance->set_physics_interpolation_mode(Node::PHYSICS_INTERPOLATION_MODE_OFF);
	instance->set_cast_shadows_setting(GeometryInstance3D::SHADOW_CASTING_SETTING_OFF);
	instance->set_multimesh(multimesh);
	instance->set_material_override(material);
	add_child(instance);
	set_process(true);
	set_physics_process(true);
}

void MoteServer::_physics_process(double p_delta) {
	if (tuning.is_null() || frozen) {
		for (int i = 0; i < capacity; ++i) {
			previous_position[i] = position[i];
		}
		return;
	}
	const Vector3 goal = _collect_point();
	const bool has_target = get_target() != nullptr;
	const real_t pickup = real_t(tuning->get_pickup_radius());
	const real_t collect = real_t(tuning->get_collect_radius());
	const real_t step = real_t(tuning->get_fly_speed() * p_delta);
	std::vector<Event> events;
	for (int i = 0; i < capacity; ++i) {
		if (!alive[i]) {
			continue;
		}
		previous_position[i] = position[i];
		if (sinking[i] >= 0.0) {
			sinking[i] += p_delta;
			const double t = tuning->get_sink_time() > 0.0 ? sinking[i] / tuning->get_sink_time() : 1.0;
			position[i].y -= real_t(tuning->get_sink_depth() * p_delta / std::max(tuning->get_sink_time(), 1e-6));
			if (t >= 1.0) {
				events.push_back({ value[i], tag[i], false });
				_free(i);
			}
			continue;
		}
		age[i] += p_delta;
		if (has_target && !flying[i] && position[i].distance_to(goal) <= pickup) {
			flying[i] = 1;
		}
		if (flying[i] && has_target) {
			const Vector3 to = goal - position[i];
			const real_t dist = to.length();
			if (dist <= collect + step) {
				events.push_back({ value[i], tag[i], true });
				_free(i);
				continue;
			}
			position[i] += to / dist * step;
			continue;
		}
		if (age[i] >= tuning->get_lifetime()) {
			sinking[i] = 0.0;
		}
	}
	// Signals last, so listeners that call back in see a finished tick.
	for (const Event &event : events) {
		emit_signal(event.collected ? "mote_collected" : "mote_lost", event.value, event.tag);
	}
}

void MoteServer::_process(double p_delta) {
	if (tuning.is_null()) {
		return;
	}
	Engine *engine = Engine::get_singleton();
	const real_t alpha = frozen ? 1.0f : real_t(engine->get_physics_interpolation_fraction());
	float *w = buffer.ptrw();
	int drawn = 0;
	for (int i = 0; i < capacity; ++i) {
		if (!alive[i]) {
			continue;
		}
		const Vector3 p = previous_position[i].lerp(position[i], alpha);
		const real_t scale = real_t(value[i] >= tuning->get_large_min_value() ? tuning->get_large_scale()
																			: tuning->get_small_scale());
		float *o = w + drawn * kFloatsPerInstance;
		o[0] = scale;
		o[1] = 0.0f;
		o[2] = 0.0f;
		o[3] = p.x;
		o[4] = 0.0f;
		o[5] = scale;
		o[6] = 0.0f;
		o[7] = p.y;
		o[8] = 0.0f;
		o[9] = 0.0f;
		o[10] = scale;
		o[11] = p.z;
		o[12] = phase[i];
		const double sink = tuning->get_sink_time() > 0.0 ? sinking[i] / tuning->get_sink_time() : 1.0;
		o[13] = sinking[i] >= 0.0 ? float(std::clamp(1.0 - sink, 0.0, 1.0)) : 1.0f;
		o[14] = 0.0f;
		o[15] = 0.0f;
		++drawn;
	}
	multimesh->set_buffer(buffer);
	multimesh->set_visible_instance_count(drawn);
}

// --- API ---------------------------------------------------------------------

int MoteServer::spawn(const Vector3 &p_position, double p_value, int p_tag) {
	if (p_value <= 0.0) {
		return -1;
	}
	if (free_slots.empty()) {
		// Full: the mote is lost at once, so its value still shows up in the tallies.
		emit_signal("mote_lost", p_value, p_tag);
		return -1;
	}
	const int i = free_slots.back();
	free_slots.pop_back();
	const real_t hover = tuning.is_valid() ? real_t(tuning->get_hover_height()) : 0.0f;
	position[i] = p_position + Vector3(0.0f, hover, 0.0f);
	previous_position[i] = position[i];
	value[i] = p_value;
	tag[i] = p_tag;
	age[i] = 0.0;
	sinking[i] = -1.0;
	phase[i] = std::uniform_real_distribution<float>(0.0f, float(kTau))(rng);
	flying[i] = 0;
	alive[i] = 1;
	++count;
	return i;
}

void MoteServer::set_target(Node3D *p_target) {
	target_id = p_target ? ObjectID(p_target->get_instance_id()) : ObjectID();
}

Node3D *MoteServer::get_target() const {
	if (target_id.is_null()) {
		return nullptr;
	}
	Node3D *target = Object::cast_to<Node3D>(ObjectDB::get_instance(uint64_t(target_id)));
	return target && target->is_inside_tree() ? target : nullptr;
}

void MoteServer::set_frozen(bool p_frozen) {
	frozen = p_frozen;
}

bool MoteServer::is_frozen() const {
	return frozen;
}

void MoteServer::set_seed(int64_t p_seed) {
	rng.seed(uint32_t(uint64_t(p_seed) ^ (uint64_t(p_seed) >> 32)));
}

void MoteServer::clear_all() {
	for (int i = 0; i < capacity; ++i) {
		if (alive[i]) {
			_free(i);
		}
	}
}

int MoteServer::get_count() const {
	return count;
}

bool MoteServer::is_mote_alive(int p_index) const {
	ERR_FAIL_INDEX_V(p_index, capacity, false);
	return alive[p_index] != 0;
}

Vector3 MoteServer::get_mote_position(int p_index) const {
	ERR_FAIL_INDEX_V(p_index, capacity, Vector3());
	return alive[p_index] ? position[p_index] : Vector3();
}

bool MoteServer::is_mote_flying(int p_index) const {
	ERR_FAIL_INDEX_V(p_index, capacity, false);
	return alive[p_index] && flying[p_index];
}

void MoteServer::set_capacity(int p_capacity) {
	ERR_FAIL_COND_MSG(p_capacity < 0, "Capacity can't be negative.");
	capacity = p_capacity;
	_allocate();
}

int MoteServer::get_capacity() const {
	return capacity;
}

void MoteServer::set_mesh(const Ref<Mesh> &p_mesh) {
	mesh = p_mesh;
	multimesh->set_mesh(mesh);
}

Ref<Mesh> MoteServer::get_mesh() const {
	return mesh;
}

void MoteServer::set_material(const Ref<Material> &p_material) {
	material = p_material;
	if (instance) {
		instance->set_material_override(material);
	}
}

Ref<Material> MoteServer::get_material() const {
	return material;
}

// --- bookkeeping ---------------------------------------------------------------

void MoteServer::_allocate() {
	const size_t n = size_t(capacity);
	position.assign(n, Vector3());
	previous_position.assign(n, Vector3());
	value.assign(n, 0.0);
	tag.assign(n, 0);
	age.assign(n, 0.0);
	sinking.assign(n, -1.0);
	phase.assign(n, 0.0f);
	flying.assign(n, 0);
	alive.assign(n, 0);
	free_slots.clear();
	free_slots.reserve(n);
	for (int i = capacity - 1; i >= 0; --i) {
		free_slots.push_back(i);
	}
	count = 0;
	multimesh->set_instance_count(capacity);
	multimesh->set_visible_instance_count(0);
	buffer.resize(int64_t(capacity) * kFloatsPerInstance);
	buffer.fill(0.0f);
}

void MoteServer::_free(int p_index) {
	alive[p_index] = 0;
	flying[p_index] = 0;
	free_slots.push_back(p_index);
	--count;
}

Vector3 MoteServer::_collect_point() const {
	Node3D *target = get_target();
	if (!target) {
		return Vector3();
	}
	const real_t height = tuning.is_valid() ? real_t(tuning->get_target_height()) : 0.0f;
	return target->get_global_position() + Vector3(0.0f, height, 0.0f);
}

void MoteServer::_bind_methods() {
	ClassDB::bind_method(D_METHOD("spawn", "position", "value", "tag"), &MoteServer::spawn, DEFVAL(0));
	ClassDB::bind_method(D_METHOD("set_target", "node"), &MoteServer::set_target);
	ClassDB::bind_method(D_METHOD("get_target"), &MoteServer::get_target);
	ClassDB::bind_method(D_METHOD("set_frozen", "frozen"), &MoteServer::set_frozen);
	ClassDB::bind_method(D_METHOD("is_frozen"), &MoteServer::is_frozen);
	ClassDB::bind_method(D_METHOD("clear_all"), &MoteServer::clear_all);
	ClassDB::bind_method(D_METHOD("set_seed", "seed"), &MoteServer::set_seed);
	ClassDB::bind_method(D_METHOD("get_count"), &MoteServer::get_count);
	ClassDB::bind_method(D_METHOD("is_mote_alive", "index"), &MoteServer::is_mote_alive);
	ClassDB::bind_method(D_METHOD("get_mote_position", "index"), &MoteServer::get_mote_position);
	ClassDB::bind_method(D_METHOD("is_mote_flying", "index"), &MoteServer::is_mote_flying);

	ClassDB::bind_method(D_METHOD("set_capacity", "capacity"), &MoteServer::set_capacity);
	ClassDB::bind_method(D_METHOD("get_capacity"), &MoteServer::get_capacity);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "capacity", PROPERTY_HINT_RANGE, "0,8192,1"), "set_capacity",
			"get_capacity");
	SWARM_BIND_PROPERTY(MoteServer, Variant::OBJECT, tuning, PROPERTY_HINT_RESOURCE_TYPE, "MoteTuning");
	ClassDB::bind_method(D_METHOD("set_mesh", "mesh"), &MoteServer::set_mesh);
	ClassDB::bind_method(D_METHOD("get_mesh"), &MoteServer::get_mesh);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mesh", PROPERTY_HINT_RESOURCE_TYPE, "Mesh"), "set_mesh", "get_mesh");
	ClassDB::bind_method(D_METHOD("set_material", "material"), &MoteServer::set_material);
	ClassDB::bind_method(D_METHOD("get_material"), &MoteServer::get_material);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "material", PROPERTY_HINT_RESOURCE_TYPE, "Material"), "set_material",
			"get_material");

	ADD_SIGNAL(MethodInfo("mote_collected", PropertyInfo(Variant::FLOAT, "value"), PropertyInfo(Variant::INT, "tag")));
	ADD_SIGNAL(MethodInfo("mote_lost", PropertyInfo(Variant::FLOAT, "value"), PropertyInfo(Variant::INT, "tag")));
}
