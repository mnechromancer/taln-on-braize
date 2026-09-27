#pragma once

// Getter/setter pairs and their bindings for plain data properties.

#define SWARM_ACCESSORS(m_type, m_name)                    \
	void set_##m_name(m_type p_value) { m_name = p_value; } \
	m_type get_##m_name() const { return m_name; }

#define SWARM_BIND_PROPERTY(m_class, m_variant_type, m_name, m_hint, m_hint_string)            \
	ClassDB::bind_method(D_METHOD("set_" #m_name, "value"), &m_class::set_##m_name);           \
	ClassDB::bind_method(D_METHOD("get_" #m_name), &m_class::get_##m_name);                    \
	ADD_PROPERTY(PropertyInfo(m_variant_type, #m_name, m_hint, m_hint_string), "set_" #m_name, \
			"get_" #m_name)
