#pragma once

#include <godot_cpp/classes/material.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/resource.hpp>

#include "property_macros.h"

using namespace godot;

// One swarm enemy type as data (spec §11.2, §11.4). SwarmServer simulates
// every enemy of this type from these numbers; there is no per-enemy script.
class SwarmType : public Resource {
	GDCLASS(SwarmType, Resource);

public:
	enum Behavior {
		BEHAVIOR_SEEK,
	};

	// Same order as Damage.Type in GDScript (spec §6.2).
	enum DamageType {
		DAMAGE_KINETIC,
		DAMAGE_VOID,
		DAMAGE_BLIGHT,
	};

	SWARM_ACCESSORS(StringName, id)
	SWARM_ACCESSORS(int, family)
	SWARM_ACCESSORS(double, hp)
	SWARM_ACCESSORS(double, contact_damage)
	SWARM_ACCESSORS(int, contact_damage_type)
	SWARM_ACCESSORS(double, speed_min)
	SWARM_ACCESSORS(double, speed_max)
	SWARM_ACCESSORS(double, mass)
	SWARM_ACCESSORS(double, radius)
	SWARM_ACCESSORS(double, separation_weight)
	SWARM_ACCESSORS(double, resist_kinetic)
	SWARM_ACCESSORS(double, resist_void)
	SWARM_ACCESSORS(double, resist_blight)
	SWARM_ACCESSORS(int, spawn_cost)
	SWARM_ACCESSORS(int, behavior)
	SWARM_ACCESSORS(Ref<Mesh>, mesh)
	SWARM_ACCESSORS(Ref<Material>, material)

	// Multiplier for damage of the given DamageType.
	double get_resist(int p_damage_type) const;

protected:
	static void _bind_methods();

private:
	// Numbers default to zero (resistances to neutral); values live in .tres files.
	StringName id;
	int family = 0;
	double hp = 0.0;
	double contact_damage = 0.0;
	int contact_damage_type = DAMAGE_KINETIC;
	double speed_min = 0.0;
	double speed_max = 0.0;
	double mass = 0.0;
	double radius = 0.0;
	double separation_weight = 0.0;
	double resist_kinetic = 1.0;
	double resist_void = 1.0;
	double resist_blight = 1.0;
	int spawn_cost = 0;
	int behavior = BEHAVIOR_SEEK;
	Ref<Mesh> mesh;
	Ref<Material> material;
};

VARIANT_ENUM_CAST(SwarmType::Behavior);
VARIANT_ENUM_CAST(SwarmType::DamageType);
