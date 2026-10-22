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

	// Enemy tier (spec §8.1) for the tiers SwarmServer simulates.
	enum Tier {
		TIER_SWARM,
		TIER_ELITE,
	};

	// Same order as Damage.Type in GDScript (spec §6.2).
	enum DamageType {
		DAMAGE_KINETIC,
		DAMAGE_VOID,
		DAMAGE_BLIGHT,
	};

	SWARM_ACCESSORS(StringName, id)
	SWARM_ACCESSORS(int, family)
	SWARM_ACCESSORS(int, tier)
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
	SWARM_ACCESSORS(double, investiture_drop)
	SWARM_ACCESSORS(double, commander_radius)
	SWARM_ACCESSORS(double, commander_speed_mult)
	SWARM_ACCESSORS(double, commander_damage_mult)
	SWARM_ACCESSORS(bool, spotter)
	SWARM_ACCESSORS(double, sight_range)
	SWARM_ACCESSORS(Ref<Mesh>, mesh)

	bool is_commander() const { return commander_radius > 0.0; }
	SWARM_ACCESSORS(Ref<Material>, material)

	// Multiplier for damage of the given DamageType.
	double get_resist(int p_damage_type) const;

protected:
	static void _bind_methods();

private:
	// Numbers default to zero (resistances to neutral); values live in .tres files.
	StringName id;
	int family = 0;
	int tier = TIER_SWARM;
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
	// Base Investiture in the one mote a rewarded kill drops (spec §2.3); 0 drops none.
	double investiture_drop = 0.0;
	// Commanders (spec v1.4 #7, P2-13): enemies within commander_radius move
	// commander_speed_mult faster and hit commander_damage_mult harder; 0
	// means not a commander.
	double commander_radius = 0.0;
	double commander_speed_mult = 1.0;
	double commander_damage_mult = 1.0;
	// Spotters report Taln to the swarm's Awareness when he's within
	// sight_range with a clear line over the ground (spec v1.4 #6).
	bool spotter = false;
	double sight_range = 0.0;
	Ref<Mesh> mesh;
	Ref<Material> material;
};

VARIANT_ENUM_CAST(SwarmType::Behavior);
VARIANT_ENUM_CAST(SwarmType::Tier);
VARIANT_ENUM_CAST(SwarmType::DamageType);
