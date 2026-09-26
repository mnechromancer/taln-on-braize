#pragma once

#include <godot_cpp/classes/object.hpp>

using namespace godot;

class SwarmServer : public Object {
	GDCLASS(SwarmServer, Object);

protected:
	static void _bind_methods();
};
