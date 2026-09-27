#include "swarm_server.h"

#include <algorithm>
#include <cmath>

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/geometry_instance3d.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>

namespace {

constexpr double kTau = 6.28318530717958647692;
// After a hitch, drop simulation time rather than spiral trying to catch up.
constexpr int kMaxStepsPerFrame = 4;
// MultiMesh buffer layout: a 3x4 transform, then custom data (phase, flash, age, unused).
constexpr int kFloatsPerInstance = 16;
// Below these, a distance or speed counts as zero.
constexpr real_t kTiny = 1e-5f;
constexpr real_t kFacingSpeed = 0.05f;

// A fixed direction per slot, for pushes between coincident points.
Vector2 fallback_direction(int p_index) {
	const real_t angle = real_t(p_index) * 2.39996323f; // Golden angle spreads neighbors apart.
	return Vector2(std::cos(angle), std::sin(angle));
}

} // namespace

SwarmServer::SwarmServer() :
		rng(std::random_device{}()) {
	_allocate();
}

void SwarmServer::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		set_process(false);
		set_physics_process(false);
		return;
	}
	if (tuning.is_null()) {
		ERR_PRINT("SwarmServer has no tuning; it will not simulate.");
	}
	set_process(true);
	set_physics_process(true);
}

void SwarmServer::_physics_process(double p_delta) {
	if (tuning.is_null() || tuning->get_step_rate() <= 0.0) {
		return;
	}
	const double step = _step_length();
	accumulator += p_delta;
	int steps = 0;
	while (accumulator + 1e-9 >= step && steps < kMaxStepsPerFrame) {
		_step(step);
		accumulator -= step;
		++steps;
	}
	if (accumulator >= step) {
		accumulator = std::fmod(accumulator, step);
	}
}

void SwarmServer::_process(double p_delta) {
	if (tuning.is_null() || tuning->get_step_rate() <= 0.0) {
		return;
	}
	// How far the render frame sits between the last two steps, including the
	// time since the last physics tick.
	Engine *engine = Engine::get_singleton();
	const double step = _step_length();
	const double since_tick = engine->get_physics_interpolation_fraction() / engine->get_physics_ticks_per_second();
	const real_t alpha = real_t(std::clamp((accumulator + since_tick) / step, 0.0, 1.0));
	const double flash_time = tuning->get_hit_flash_time();

	std::vector<float *> writers(types.size());
	for (size_t t = 0; t < types.size(); ++t) {
		writers[t] = types[t].buffer.ptrw();
		types[t].drawn = 0;
	}
	for (int i = 0; i < capacity; ++i) {
		if (!alive[i]) {
			continue;
		}
		TypeSlot &slot = types[type_index[i]];
		float *w = writers[type_index[i]] + slot.drawn * kFloatsPerInstance;
		++slot.drawn;
		const Vector3 p = previous_position[i].lerp(position[i], alpha);
		// Yaw about Y so the mesh's +Z (its front) points along facing.
		const float s = std::sin(facing[i]);
		const float c = std::cos(facing[i]);
		w[0] = c;
		w[1] = 0.0f;
		w[2] = s;
		w[3] = p.x;
		w[4] = 0.0f;
		w[5] = 1.0f;
		w[6] = 0.0f;
		w[7] = p.y;
		w[8] = -s;
		w[9] = 0.0f;
		w[10] = c;
		w[11] = p.z;
		w[12] = phase[i];
		w[13] = flash_time > 0.0 ? float(hit_flash[i] / flash_time) : 0.0f;
		w[14] = float(std::max(0.0, age[i] - (1.0 - alpha) * step));
		w[15] = 0.0f;
	}
	for (TypeSlot &slot : types) {
		slot.multimesh->set_buffer(slot.buffer);
		slot.multimesh->set_visible_instance_count(slot.drawn);
	}
}

// --- API ---------------------------------------------------------------------

void SwarmServer::set_ground(const PackedFloat32Array &p_heights, const PackedByteArray &p_blocked, int p_width,
		int p_depth, double p_cell_size, const Vector2 &p_origin) {
	const int cells = p_width * p_depth;
	ERR_FAIL_COND_MSG(p_width <= 0 || p_depth <= 0 || p_cell_size <= 0.0, "Ground needs a positive size.");
	ERR_FAIL_COND_MSG(p_heights.size() != cells || p_blocked.size() != cells,
			vformat("Ground arrays must hold %d cells.", cells));

	ground_width = p_width;
	ground_depth = p_depth;
	ground_cell_size = real_t(p_cell_size);
	ground_origin = p_origin;
	ground_heights.assign(p_heights.ptr(), p_heights.ptr() + cells);
	ground_blocked.assign(p_blocked.ptr(), p_blocked.ptr() + cells);
	has_ground = true;

	const auto [low, high] = std::minmax_element(ground_heights.begin(), ground_heights.end());
	ground_bounds = AABB(Vector3(p_origin.x, *low - 2.0f, p_origin.y),
			Vector3(p_width * ground_cell_size, *high - *low + 4.0f, p_depth * ground_cell_size));
	for (TypeSlot &slot : types) {
		slot.multimesh->set_custom_aabb(ground_bounds);
	}
	grid_dirty = true;
}

void SwarmServer::set_target(Node3D *p_target) {
	target_id = p_target ? ObjectID(p_target->get_instance_id()) : ObjectID();
}

Node3D *SwarmServer::get_target() const {
	if (target_id.is_null()) {
		return nullptr;
	}
	return Object::cast_to<Node3D>(ObjectDB::get_instance(uint64_t(target_id)));
}

int SwarmServer::spawn(const Ref<SwarmType> &p_type, const Vector3 &p_position, double p_hp_mult, double p_dmg_mult) {
	ERR_FAIL_COND_V_MSG(p_type.is_null(), -1, "spawn() needs a SwarmType.");
	if (free_slots.empty()) {
		return -1;
	}
	const int t = _type_index(p_type);
	const int i = free_slots.back();
	free_slots.pop_back();

	Vector3 p = p_position;
	p.y = _ground_height(p.x, p.z, p.y);
	position[i] = p;
	previous_position[i] = p;
	velocity[i] = Vector3();
	impulse[i] = Vector3();
	hp[i] = p_type->get_hp() * p_hp_mult;
	hp_mult[i] = p_hp_mult;
	dmg_mult[i] = p_dmg_mult;
	type_index[i] = t;
	std::uniform_real_distribution<double> speed_roll(p_type->get_speed_min(),
			std::max(p_type->get_speed_min(), p_type->get_speed_max()));
	speed[i] = speed_roll(rng);
	contact_cooldown[i] = 0.0;
	hit_flash[i] = 0.0;
	phase[i] = std::uniform_real_distribution<float>(0.0f, float(kTau))(rng);
	age[i] = 0.0;
	facing[i] = 0.0f;
	if (Node3D *target = get_target()) {
		const Vector3 to = target->get_global_position() - p;
		if (Vector2(to.x, to.z).length() > kTiny) {
			facing[i] = std::atan2(to.x, to.z);
		}
	}
	alive[i] = 1;
	++alive_count;
	grid_dirty = true;
	return i;
}

int SwarmServer::apply_damage_in_radius(const Vector3 &p_center, double p_radius, double p_amount, int p_type) {
	int hits = 0;
	_for_each_near(p_center.x, p_center.z, real_t(p_radius) + max_radius, [&](int i) {
		const real_t reach = real_t(p_radius) + _radius(i);
		const Vector2 d(position[i].x - p_center.x, position[i].z - p_center.z);
		if (hp[i] > 0.0 && d.length_squared() <= reach * reach) {
			_hit(i, p_amount, p_type);
			++hits;
		}
	});
	return hits;
}

int SwarmServer::apply_damage_in_cone(const Vector3 &p_origin, const Vector3 &p_direction, double p_angle_deg,
		double p_range, double p_amount, int p_type) {
	const Vector2 forward = Vector2(p_direction.x, p_direction.z).normalized();
	ERR_FAIL_COND_V_MSG(forward.is_zero_approx(), 0, "Cone direction needs an XZ component.");
	const real_t min_cos = std::cos(real_t(p_angle_deg * 0.5 * kTau / 360.0));
	int hits = 0;
	_for_each_near(p_origin.x, p_origin.z, real_t(p_range) + max_radius, [&](int i) {
		if (hp[i] <= 0.0) {
			return;
		}
		const real_t r = _radius(i);
		const Vector2 d(position[i].x - p_origin.x, position[i].z - p_origin.z);
		const real_t dist = d.length();
		// Inside the range, and either overlapping the origin or within the angle.
		if (dist <= real_t(p_range) + r && (dist <= r || d.dot(forward) / dist >= min_cos)) {
			_hit(i, p_amount, p_type);
			++hits;
		}
	});
	return hits;
}

void SwarmServer::apply_impulse_in_radius(const Vector3 &p_center, double p_radius, double p_force) {
	if (tuning.is_null()) {
		return;
	}
	// Knockback distance = force / mass (spec §6.2). The kick decays by
	// exp(-decay * step) every step, so this start velocity travels exactly that far.
	// Kicks don't stack: one only tops up the knockback velocity along its own
	// direction, so calling this every tick while an enemy stays in range
	// still knocks it force / mass meters, not a multiple of that.
	const double step = _step_length();
	const double kick_per_distance = (1.0 - std::exp(-tuning->get_impulse_decay() * step)) / step;
	_for_each_near(p_center.x, p_center.z, real_t(p_radius) + max_radius, [&](int i) {
		const double mass = types[type_index[i]].type->get_mass();
		const real_t reach = real_t(p_radius) + _radius(i);
		Vector2 d(position[i].x - p_center.x, position[i].z - p_center.z);
		const real_t dist = d.length();
		if (mass <= 0.0 || hp[i] <= 0.0 || dist > reach) {
			return;
		}
		const Vector2 dir = dist > kTiny ? d / dist : fallback_direction(i);
		const real_t kick = real_t(p_force / mass * kick_per_distance);
		const Vector3 along(dir.x, 0.0f, dir.y);
		const real_t current = impulse[i].dot(along);
		if (current < kick) {
			impulse[i] += along * (kick - current);
		}
	});
}

int SwarmServer::query_count_in_radius(const Vector3 &p_center, double p_radius) {
	int count = 0;
	_for_each_near(p_center.x, p_center.z, real_t(p_radius) + max_radius, [&](int i) {
		const real_t reach = real_t(p_radius) + _radius(i);
		const Vector2 d(position[i].x - p_center.x, position[i].z - p_center.z);
		if (hp[i] > 0.0 && d.length_squared() <= reach * reach) {
			++count;
		}
	});
	return count;
}

int SwarmServer::get_alive_count() const {
	return alive_count;
}

void SwarmServer::clear_all() {
	for (int i = 0; i < capacity; ++i) {
		if (alive[i]) {
			_free(i);
		}
	}
	accumulator = 0.0;
}

double SwarmServer::get_last_step_ms() const {
	return last_step_ms;
}

void SwarmServer::set_capacity(int p_capacity) {
	ERR_FAIL_COND_MSG(p_capacity < 0, "Capacity can't be negative.");
	capacity = p_capacity;
	_allocate();
}

int SwarmServer::get_capacity() const {
	return capacity;
}

Vector3 SwarmServer::get_enemy_position(int p_index) const {
	ERR_FAIL_INDEX_V(p_index, capacity, Vector3());
	return alive[p_index] ? position[p_index] : Vector3();
}

// --- simulation --------------------------------------------------------------

void SwarmServer::_step(double p_dt) {
	const uint64_t start = Time::get_singleton()->get_ticks_usec();
	const real_t dt = real_t(p_dt);
	_rebuild_grid();

	Node3D *target = get_target();
	const bool has_target = target != nullptr && target->is_inside_tree();
	const Vector3 goal = has_target ? target->get_global_position() : Vector3();
	const double top_speed = tuning->get_max_speed_ratio() * target_move_speed;
	const real_t decay = real_t(std::exp(-tuning->get_impulse_decay() * p_dt));

	// Steer: seek toward Taln at the enemy's own speed, plus separation, plus impulse.
	for (int i = 0; i < capacity; ++i) {
		if (!alive[i]) {
			continue;
		}
		previous_position[i] = position[i];
		contact_cooldown[i] -= p_dt;
		hit_flash[i] = std::max(0.0, hit_flash[i] - p_dt);
		age[i] += p_dt;

		const real_t max_speed = real_t(std::min(speed[i], top_speed));
		Vector2 seek;
		if (has_target) {
			const Vector2 to(goal.x - position[i].x, goal.z - position[i].z);
			const real_t dist = to.length();
			if (dist > kTiny) {
				seek = to / dist;
			}
		}
		const real_t weight = real_t(types[type_index[i]].type->get_separation_weight());
		const Vector2 steer = ((seek + _separation(i) * weight) * max_speed).limit_length(max_speed);
		velocity[i] = Vector3(steer.x, 0.0f, steer.y) + impulse[i];
		impulse[i] *= decay;
	}

	// Move, one axis at a time so enemies slide along blocked cells.
	for (int i = 0; i < capacity; ++i) {
		if (!alive[i]) {
			continue;
		}
		_slide(i, velocity[i].x * dt, velocity[i].z * dt);
		const Vector2 moved(velocity[i].x, velocity[i].z);
		if (moved.length() > kFacingSpeed) {
			facing[i] = std::atan2(moved.x, moved.y);
		}
	}

	// Push out of Taln's radius (Taln isn't pushed back); touching enemies deal contact damage.
	std::vector<Contact> contacts;
	if (has_target) {
		for (int i = 0; i < capacity; ++i) {
			if (!alive[i] || hp[i] <= 0.0) {
				continue;
			}
			const real_t touch = real_t(target_radius) + _radius(i);
			const Vector2 d(position[i].x - goal.x, position[i].z - goal.z);
			const real_t dist = d.length();
			if (dist > touch) {
				continue;
			}
			const Vector2 out = (dist > kTiny ? d / dist : fallback_direction(i)) * (touch - dist);
			_slide(i, out.x, out.y);
			if (contact_cooldown[i] <= 0.0) {
				const Ref<SwarmType> &type = types[type_index[i]].type;
				contacts.push_back({ type->get_contact_damage() * dmg_mult[i], type->get_contact_damage_type() });
				contact_cooldown[i] = tuning->get_contact_cooldown();
			}
		}
	}

	std::vector<Death> deaths;
	for (int i = 0; i < capacity; ++i) {
		if (alive[i] && hp[i] <= 0.0) {
			deaths.push_back({ types[type_index[i]].type->get_id(), position[i] });
			_free(i);
		}
	}

	grid_dirty = true;
	last_step_ms = double(Time::get_singleton()->get_ticks_usec() - start) / 1000.0;

	// Signals last, so listeners that call back in see a finished step.
	for (const Contact &contact : contacts) {
		emit_signal("taln_contacted", contact.damage, contact.type);
	}
	for (const Death &death : deaths) {
		emit_signal("enemy_died", death.type_id, death.position);
	}
}

Vector2 SwarmServer::_separation(int p_index) {
	const Vector3 p = position[p_index];
	const real_t r = _radius(p_index);
	const real_t range_radii = real_t(tuning->get_separation_range());
	Vector2 push;
	_for_each_near(p.x, p.z, range_radii * 0.5f * (r + max_radius), [&](int j) {
		if (j == p_index) {
			return;
		}
		// Twice the radius for two of the same type.
		const real_t range = range_radii * 0.5f * (r + _radius(j));
		const Vector2 d(p.x - position[j].x, p.z - position[j].z);
		const real_t dist = d.length();
		if (dist >= range) {
			return;
		}
		const Vector2 away = dist > kTiny ? d / dist : fallback_direction(p_index);
		push += away * (1.0f - dist / range);
	});
	return push;
}

void SwarmServer::_slide(int p_index, real_t p_dx, real_t p_dz) {
	Vector3 &p = position[p_index];
	// Sub-steps of at most half a cell, so a fast knockback can't hop a thin blocked band.
	const real_t longest = std::max(std::abs(p_dx), std::abs(p_dz));
	const int parts = has_ground ? std::max(1, int(std::ceil(longest / (ground_cell_size * 0.5f)))) : 1;
	const real_t dx = p_dx / real_t(parts);
	const real_t dz = p_dz / real_t(parts);
	bool x_open = true;
	bool z_open = true;
	for (int k = 0; k < parts; ++k) {
		// An enemy already inside a blocked cell may move anywhere, so it can get out.
		const bool stuck = _blocked_at(p.x, p.z);
		if (x_open && (stuck || !_blocked_at(p.x + dx, p.z))) {
			p.x += dx;
		} else {
			x_open = false;
			impulse[p_index].x = 0.0f;
		}
		if (z_open && (stuck || !_blocked_at(p.x, p.z + dz))) {
			p.z += dz;
		} else {
			z_open = false;
			impulse[p_index].z = 0.0f;
		}
	}
	p.y = _ground_height(p.x, p.z, p.y);
}

void SwarmServer::_free(int p_index) {
	alive[p_index] = 0;
	hp[p_index] = 0.0;
	free_slots.push_back(p_index);
	--alive_count;
	grid_dirty = true;
}

void SwarmServer::_hit(int p_index, double p_amount, int p_type) {
	hp[p_index] -= p_amount * types[type_index[p_index]].type->get_resist(p_type);
	hit_flash[p_index] = tuning.is_valid() ? tuning->get_hit_flash_time() : 0.0;
}

// --- ground --------------------------------------------------------------------

bool SwarmServer::_blocked_at(real_t p_x, real_t p_z) const {
	if (!has_ground) {
		return false;
	}
	const int x = int(std::floor((p_x - ground_origin.x) / ground_cell_size));
	const int z = int(std::floor((p_z - ground_origin.y) / ground_cell_size));
	if (x < 0 || z < 0 || x >= ground_width || z >= ground_depth) {
		return true;
	}
	return ground_blocked[z * ground_width + x] != 0;
}

// Bilinear between the four nearest cell centers, skipping blocked ones so a
// wall top or the far side of a cliff doesn't lift or sink the enemy.
real_t SwarmServer::_ground_height(real_t p_x, real_t p_z, real_t p_fallback) const {
	if (!has_ground) {
		return p_fallback;
	}
	const real_t gx = (p_x - ground_origin.x) / ground_cell_size - 0.5f;
	const real_t gz = (p_z - ground_origin.y) / ground_cell_size - 0.5f;
	const int x0 = int(std::floor(gx));
	const int z0 = int(std::floor(gz));
	const real_t fx = gx - real_t(x0);
	const real_t fz = gz - real_t(z0);
	real_t sum = 0.0f;
	real_t weight_sum = 0.0f;
	for (int k = 0; k < 4; ++k) {
		const int x = std::clamp(x0 + (k & 1), 0, ground_width - 1);
		const int z = std::clamp(z0 + (k >> 1), 0, ground_depth - 1);
		const int cell = z * ground_width + x;
		const real_t weight = ((k & 1) ? fx : 1.0f - fx) * ((k >> 1) ? fz : 1.0f - fz);
		if (ground_blocked[cell] == 0 && weight > 0.0f) {
			sum += ground_heights[cell] * weight;
			weight_sum += weight;
		}
	}
	if (weight_sum > kTiny) {
		return sum / weight_sum;
	}
	const int x = std::clamp(int(std::floor(gx + 0.5f)), 0, ground_width - 1);
	const int z = std::clamp(int(std::floor(gz + 0.5f)), 0, ground_depth - 1);
	return ground_heights[z * ground_width + x];
}

// --- spatial grid --------------------------------------------------------------

void SwarmServer::_rebuild_grid() {
	grid_dirty = false;
	if (!has_ground || tuning.is_null() || tuning->get_grid_cell_size() <= 0.0) {
		grid_cols = 0;
		return;
	}
	grid_cell_size = real_t(tuning->get_grid_cell_size());
	grid_cols = std::max(1, int(std::ceil(ground_width * ground_cell_size / grid_cell_size)));
	grid_rows = std::max(1, int(std::ceil(ground_depth * ground_cell_size / grid_cell_size)));
	grid_start.assign(size_t(grid_cols) * grid_rows + 1, 0);
	for (int i = 0; i < capacity; ++i) {
		if (alive[i]) {
			grid_cell_of[i] = _grid_cell(position[i].x, position[i].z);
			++grid_start[grid_cell_of[i] + 1];
		}
	}
	for (size_t c = 1; c < grid_start.size(); ++c) {
		grid_start[c] += grid_start[c - 1];
	}
	std::vector<int> fill(grid_start.begin(), grid_start.end() - 1);
	for (int i = 0; i < capacity; ++i) {
		if (alive[i]) {
			grid_items[fill[grid_cell_of[i]]++] = i;
		}
	}
}

// Enemies off the ground land in the nearest edge cell.
int SwarmServer::_grid_cell(real_t p_x, real_t p_z) const {
	const int x = std::clamp(int(std::floor((p_x - ground_origin.x) / grid_cell_size)), 0, grid_cols - 1);
	const int z = std::clamp(int(std::floor((p_z - ground_origin.y) / grid_cell_size)), 0, grid_rows - 1);
	return z * grid_cols + x;
}

template <typename Visit>
void SwarmServer::_for_each_near(real_t p_x, real_t p_z, real_t p_reach, Visit &&p_visit) {
	if (grid_dirty) {
		_rebuild_grid();
	}
	if (grid_cols == 0) {
		for (int i = 0; i < capacity; ++i) {
			if (alive[i]) {
				p_visit(i);
			}
		}
		return;
	}
	const auto column = [&](real_t x) {
		return std::clamp(int(std::floor((x - ground_origin.x) / grid_cell_size)), 0, grid_cols - 1);
	};
	const auto row = [&](real_t z) {
		return std::clamp(int(std::floor((z - ground_origin.y) / grid_cell_size)), 0, grid_rows - 1);
	};
	const int x_end = column(p_x + p_reach);
	const int z_end = row(p_z + p_reach);
	for (int z = row(p_z - p_reach); z <= z_end; ++z) {
		for (int x = column(p_x - p_reach); x <= x_end; ++x) {
			const int cell = z * grid_cols + x;
			for (int k = grid_start[cell]; k < grid_start[cell + 1]; ++k) {
				// Skip enemies that died after the grid was built.
				if (alive[grid_items[k]]) {
					p_visit(grid_items[k]);
				}
			}
		}
	}
}

// --- bookkeeping ---------------------------------------------------------------

void SwarmServer::_allocate() {
	const size_t n = size_t(capacity);
	position.assign(n, Vector3());
	previous_position.assign(n, Vector3());
	velocity.assign(n, Vector3());
	impulse.assign(n, Vector3());
	hp.assign(n, 0.0);
	hp_mult.assign(n, 1.0);
	dmg_mult.assign(n, 1.0);
	type_index.assign(n, -1);
	speed.assign(n, 0.0);
	contact_cooldown.assign(n, 0.0);
	hit_flash.assign(n, 0.0);
	phase.assign(n, 0.0f);
	age.assign(n, 0.0);
	facing.assign(n, 0.0f);
	alive.assign(n, 0);
	grid_items.assign(n, 0);
	grid_cell_of.assign(n, 0);
	free_slots.clear();
	free_slots.reserve(n);
	// Reversed so the lowest slot is handed out first.
	for (int i = capacity - 1; i >= 0; --i) {
		free_slots.push_back(i);
	}
	alive_count = 0;
	grid_dirty = true;
	for (TypeSlot &slot : types) {
		_size_multimesh(slot);
	}
}

int SwarmServer::_type_index(const Ref<SwarmType> &p_type) {
	for (size_t t = 0; t < types.size(); ++t) {
		if (types[t].type == p_type) {
			return int(t);
		}
	}
	TypeSlot slot;
	slot.type = p_type;
	slot.multimesh.instantiate();
	slot.multimesh->set_transform_format(MultiMesh::TRANSFORM_3D);
	slot.multimesh->set_use_custom_data(true);
	slot.multimesh->set_mesh(p_type->get_mesh());
	if (has_ground) {
		slot.multimesh->set_custom_aabb(ground_bounds);
	}
	_size_multimesh(slot);

	slot.instance = memnew(MultiMeshInstance3D);
	slot.instance->set_name(String(p_type->get_id()));
	// Enemy positions are in world space.
	slot.instance->set_as_top_level(true);
	slot.instance->set_multimesh(slot.multimesh);
	slot.instance->set_material_override(p_type->get_material());
	add_child(slot.instance);

	max_radius = std::max(max_radius, real_t(p_type->get_radius()));
	types.push_back(slot);
	return int(types.size() - 1);
}

void SwarmServer::_size_multimesh(TypeSlot &p_slot) {
	p_slot.multimesh->set_instance_count(capacity);
	p_slot.multimesh->set_visible_instance_count(0);
	p_slot.buffer.resize(int64_t(capacity) * kFloatsPerInstance);
	p_slot.buffer.fill(0.0f);
}

real_t SwarmServer::_radius(int p_index) const {
	return real_t(types[type_index[p_index]].type->get_radius());
}

double SwarmServer::_step_length() const {
	return 1.0 / tuning->get_step_rate();
}

void SwarmServer::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_ground", "heights", "blocked", "width", "depth", "cell_size", "origin"),
			&SwarmServer::set_ground);
	ClassDB::bind_method(D_METHOD("set_target", "node"), &SwarmServer::set_target);
	ClassDB::bind_method(D_METHOD("get_target"), &SwarmServer::get_target);
	ClassDB::bind_method(D_METHOD("spawn", "type", "position", "hp_mult", "dmg_mult"), &SwarmServer::spawn);
	ClassDB::bind_method(D_METHOD("apply_damage_in_radius", "center", "radius", "amount", "type"),
			&SwarmServer::apply_damage_in_radius);
	ClassDB::bind_method(D_METHOD("apply_damage_in_cone", "origin", "direction", "angle_deg", "range", "amount", "type"),
			&SwarmServer::apply_damage_in_cone);
	ClassDB::bind_method(D_METHOD("apply_impulse_in_radius", "center", "radius", "force"),
			&SwarmServer::apply_impulse_in_radius);
	ClassDB::bind_method(D_METHOD("query_count_in_radius", "center", "radius"), &SwarmServer::query_count_in_radius);
	ClassDB::bind_method(D_METHOD("get_alive_count"), &SwarmServer::get_alive_count);
	ClassDB::bind_method(D_METHOD("clear_all"), &SwarmServer::clear_all);
	ClassDB::bind_method(D_METHOD("get_last_step_ms"), &SwarmServer::get_last_step_ms);
	ClassDB::bind_method(D_METHOD("get_enemy_position", "index"), &SwarmServer::get_enemy_position);

	ClassDB::bind_method(D_METHOD("set_capacity", "capacity"), &SwarmServer::set_capacity);
	ClassDB::bind_method(D_METHOD("get_capacity"), &SwarmServer::get_capacity);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "capacity", PROPERTY_HINT_RANGE, "0,4000,1"), "set_capacity",
			"get_capacity");
	SWARM_BIND_PROPERTY(SwarmServer, Variant::OBJECT, tuning, PROPERTY_HINT_RESOURCE_TYPE, "SwarmTuning");
	ADD_GROUP("Target", "target_");
	// Set from Taln's tuning by whoever wires the server up; top speed follows it (spec §8.2).
	SWARM_BIND_PROPERTY(SwarmServer, Variant::FLOAT, target_move_speed, PROPERTY_HINT_RANGE, "0,20,0.1,suffix:m/s");
	SWARM_BIND_PROPERTY(SwarmServer, Variant::FLOAT, target_radius, PROPERTY_HINT_RANGE, "0,5,0.01,suffix:m");

	ADD_SIGNAL(MethodInfo("enemy_died", PropertyInfo(Variant::STRING_NAME, "type_id"),
			PropertyInfo(Variant::VECTOR3, "position")));
	ADD_SIGNAL(MethodInfo("taln_contacted", PropertyInfo(Variant::FLOAT, "damage"), PropertyInfo(Variant::INT, "type")));
}
