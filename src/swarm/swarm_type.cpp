#include "swarm_type.h"

double SwarmType::get_resist(int p_damage_type) const {
	switch (p_damage_type) {
		case DAMAGE_KINETIC:
			return resist_kinetic;
		case DAMAGE_VOID:
			return resist_void;
		case DAMAGE_BLIGHT:
			return resist_blight;
		default:
			ERR_FAIL_V_MSG(1.0, vformat("Unknown damage type %d.", p_damage_type));
	}
}

void SwarmType::_bind_methods() {
	BIND_ENUM_CONSTANT(BEHAVIOR_SEEK);
	BIND_ENUM_CONSTANT(DAMAGE_KINETIC);
	BIND_ENUM_CONSTANT(DAMAGE_VOID);
	BIND_ENUM_CONSTANT(DAMAGE_BLIGHT);

	ClassDB::bind_method(D_METHOD("get_resist", "damage_type"), &SwarmType::get_resist);

	SWARM_BIND_PROPERTY(SwarmType, Variant::STRING_NAME, id, PROPERTY_HINT_NONE, "");
	SWARM_BIND_PROPERTY(SwarmType, Variant::INT, family, PROPERTY_HINT_RANGE, "0,8,1");
	SWARM_BIND_PROPERTY(SwarmType, Variant::FLOAT, hp, PROPERTY_HINT_RANGE, "0,10000,0.1");
	SWARM_BIND_PROPERTY(SwarmType, Variant::FLOAT, contact_damage, PROPERTY_HINT_RANGE, "0,1000,0.1");
	SWARM_BIND_PROPERTY(SwarmType, Variant::INT, contact_damage_type, PROPERTY_HINT_ENUM, "Kinetic,Void,Blight");
	SWARM_BIND_PROPERTY(SwarmType, Variant::FLOAT, speed_min, PROPERTY_HINT_RANGE, "0,20,0.1,suffix:m/s");
	SWARM_BIND_PROPERTY(SwarmType, Variant::FLOAT, speed_max, PROPERTY_HINT_RANGE, "0,20,0.1,suffix:m/s");
	SWARM_BIND_PROPERTY(SwarmType, Variant::FLOAT, mass, PROPERTY_HINT_RANGE, "0,100,0.1");
	SWARM_BIND_PROPERTY(SwarmType, Variant::FLOAT, radius, PROPERTY_HINT_RANGE, "0,5,0.01,suffix:m");
	SWARM_BIND_PROPERTY(SwarmType, Variant::FLOAT, separation_weight, PROPERTY_HINT_RANGE, "0,10,0.05");
	ADD_GROUP("Resistances", "resist_");
	SWARM_BIND_PROPERTY(SwarmType, Variant::FLOAT, resist_kinetic, PROPERTY_HINT_RANGE, "0,5,0.05");
	SWARM_BIND_PROPERTY(SwarmType, Variant::FLOAT, resist_void, PROPERTY_HINT_RANGE, "0,5,0.05");
	SWARM_BIND_PROPERTY(SwarmType, Variant::FLOAT, resist_blight, PROPERTY_HINT_RANGE, "0,5,0.05");
	ADD_GROUP("", "");
	SWARM_BIND_PROPERTY(SwarmType, Variant::INT, spawn_cost, PROPERTY_HINT_RANGE, "0,100,1");
	SWARM_BIND_PROPERTY(SwarmType, Variant::INT, behavior, PROPERTY_HINT_ENUM, "Seek");
	ADD_GROUP("Rendering", "");
	SWARM_BIND_PROPERTY(SwarmType, Variant::OBJECT, mesh, PROPERTY_HINT_RESOURCE_TYPE, "Mesh");
	SWARM_BIND_PROPERTY(SwarmType, Variant::OBJECT, material, PROPERTY_HINT_RESOURCE_TYPE, "Material");
}
