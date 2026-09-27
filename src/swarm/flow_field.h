#pragma once

#include <cstdint>
#include <vector>

#include <godot_cpp/variant/vector2.hpp>

using namespace godot;

// Navigation field toward one goal cell over the station ground grid (spec
// §11.1 item 3): a Dijkstra distance per cell with 8 neighbors, where a
// diagonal step is allowed only if both cells it cuts past are open. Each
// reached cell also keeps the direction of its next step toward the goal,
// so following the field is a lookup.
//
// Plain C++ owned by SwarmServer; not a Godot object. Built for speed in the
// unoptimized dev build too: raw arrays, a grid padded with a closed border
// so neighbors need no bounds checks, and a bucket queue (Dial's algorithm)
// over integer step costs instead of a heap.
class FlowField {
public:
	// Copies the open/closed state of every cell. p_blocked is row-major
	// (index = z * width + x), nonzero where closed.
	void set_grid(const uint8_t *p_blocked, int p_width, int p_depth, real_t p_cell_size, const Vector2 &p_origin);
	bool has_grid() const { return width > 0; }

	// Rebuilds the field toward cell (x, z). A closed goal cell (Taln can
	// stand on cells the swarm can't) still seeds the field: it expands into
	// its open neighbors.
	void build(int p_goal_x, int p_goal_z);
	bool is_built() const { return goal >= 0; }

	// Cell index (row-major, unpadded) under world XZ, or -1 off the grid.
	int cell_at(real_t p_x, real_t p_z) const;
	// Cell under world XZ clamped onto the grid (for a goal off its edge).
	void clamped_cell(real_t p_x, real_t p_z, int &r_x, int &r_z) const;
	int goal_cell() const;

	// Path distance in meters from the cell to the goal; negative if the
	// goal can't be reached from it.
	real_t distance(int p_cell) const;
	// Unit flow direction at world XZ: the cell's own step toward the goal,
	// blended with those of the four nearest cell centers that flow the same
	// way. Zero where the cell isn't reached.
	Vector2 direction(real_t p_x, real_t p_z) const;
	// True if a straight grid line from the cell's center to the goal's
	// crosses only open cells (a corner crossing needs both sides open).
	// Cached per build. It tests cell centers, so an enemy off its cell's
	// center may graze a corner on the way; SwarmServer's per-axis slide
	// carries it along the wall.
	bool line_clear(int p_cell);

private:
	static constexpr int kOrtho = 10;
	static constexpr int kDiag = 14;
	static constexpr int kBuckets = kDiag + 1;
	static constexpr int32_t kUnreached = INT32_MAX;

	int _padded(int p_cell) const;
	bool _open(int p_x, int p_z) const;

	int width = 0;
	int depth = 0;
	int padded_width = 0;
	real_t cell_size = 1.0f;
	Vector2 origin;

	// Padded arrays, (width + 2) x (depth + 2), index = (z + 1) * padded_width + (x + 1).
	std::vector<uint8_t> open;
	std::vector<int32_t> cost;
	// Neighbor index 0-7 of the next step toward the goal; -1 for none.
	std::vector<int8_t> toward;
	std::vector<uint8_t> state;
	std::vector<int32_t> bucket_next;
	std::vector<int32_t> bucket_prev;
	// Unpadded: 0 unknown, 1 clear, 2 blocked.
	std::vector<uint8_t> line_cache;

	int goal = -1; // Padded index.
	int goal_x = 0;
	int goal_z = 0;
	int offsets[8] = {};
};
