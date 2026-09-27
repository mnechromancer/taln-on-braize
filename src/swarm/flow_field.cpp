#include "flow_field.h"

#include <algorithm>
#include <cmath>
#include <cstring>

namespace {

// Neighbor steps: four orthogonal, then four diagonal.
constexpr int kStepX[8] = { 1, -1, 0, 0, 1, 1, -1, -1 };
constexpr int kStepZ[8] = { 0, 0, 1, -1, 1, -1, 1, -1 };
// The step back the other way.
constexpr int8_t kOpposite[8] = { 1, 0, 3, 2, 7, 6, 5, 4 };
constexpr real_t kHalfSqrt2 = 0.70710678f;
constexpr real_t kTiny = 1e-5f;

enum : uint8_t {
	UNSEEN = 0,
	QUEUED = 1,
	DONE = 2,
};

} // namespace

void FlowField::set_grid(const uint8_t *p_blocked, int p_width, int p_depth, real_t p_cell_size,
		const Vector2 &p_origin) {
	width = p_width;
	depth = p_depth;
	padded_width = p_width + 2;
	cell_size = p_cell_size;
	origin = p_origin;
	const size_t padded = size_t(padded_width) * size_t(p_depth + 2);
	open.assign(padded, 0);
	for (int z = 0; z < depth; ++z) {
		const uint8_t *row = p_blocked + size_t(z) * width;
		uint8_t *out = open.data() + size_t(z + 1) * padded_width + 1;
		for (int x = 0; x < width; ++x) {
			out[x] = row[x] == 0 ? 1 : 0;
		}
	}
	cost.assign(padded, kUnreached);
	toward.assign(padded, int8_t(-1));
	state.assign(padded, UNSEEN);
	bucket_next.assign(padded, -1);
	bucket_prev.assign(padded, -1);
	line_cache.assign(size_t(width) * depth, 0);
	for (int k = 0; k < 8; ++k) {
		offsets[k] = kStepZ[k] * padded_width + kStepX[k];
	}
	goal = -1;
}

void FlowField::build(int p_goal_x, int p_goal_z) {
	if (!has_grid()) {
		return;
	}
	goal_x = std::clamp(p_goal_x, 0, width - 1);
	goal_z = std::clamp(p_goal_z, 0, depth - 1);
	goal = (goal_z + 1) * padded_width + goal_x + 1;

	const int n = int(cost.size());
	int32_t *c = cost.data();
	int8_t *t = toward.data();
	uint8_t *s = state.data();
	int32_t *next = bucket_next.data();
	int32_t *prev = bucket_prev.data();
	const uint8_t *o = open.data();
	for (int i = 0; i < n; ++i) {
		c[i] = kUnreached;
	}
	std::memset(t, 0xff, size_t(n));
	std::memset(s, 0, size_t(n));
	std::memset(line_cache.data(), 0, line_cache.size());

	// Dial's algorithm: every queued cost lies within one diagonal step of
	// the current one, so a ring of kBuckets buckets indexed by cost holds
	// each cost in its own bucket. Buckets are doubly linked lists threaded
	// through the cells, so an improved cell moves buckets in O(1).
	int head[kBuckets];
	for (int b = 0; b < kBuckets; ++b) {
		head[b] = -1;
	}
	const int weight[8] = { kOrtho, kOrtho, kOrtho, kOrtho, kDiag, kDiag, kDiag, kDiag };
	const int *off = offsets;

	c[goal] = 0;
	s[goal] = QUEUED;
	next[goal] = -1;
	prev[goal] = -1;
	head[0] = goal;
	int queued = 1;
	int current = 0;
	while (queued > 0) {
		const int cell = head[current];
		if (cell < 0) {
			current = current + 1 == kBuckets ? 0 : current + 1;
			continue;
		}
		head[current] = next[cell];
		if (next[cell] >= 0) {
			prev[next[cell]] = -1;
		}
		--queued;
		s[cell] = DONE;
		const int32_t here = c[cell];
		for (int k = 0; k < 8; ++k) {
			const int nb = cell + off[k];
			if (!o[nb] || s[nb] == DONE) {
				continue;
			}
			// No corner cutting: both cells the diagonal passes must be open.
			if (k >= 4 && (!o[cell + off[k] - kStepZ[k] * padded_width] || !o[cell + kStepZ[k] * padded_width])) {
				continue;
			}
			const int32_t through = here + weight[k];
			if (through >= c[nb]) {
				continue;
			}
			if (s[nb] == QUEUED) {
				// Unlink from its old bucket.
				const int b = c[nb] % kBuckets;
				if (prev[nb] >= 0) {
					next[prev[nb]] = next[nb];
				} else {
					head[b] = next[nb];
				}
				if (next[nb] >= 0) {
					prev[next[nb]] = prev[nb];
				}
			} else {
				s[nb] = QUEUED;
				++queued;
			}
			c[nb] = through;
			t[nb] = kOpposite[k];
			const int b = through % kBuckets;
			prev[nb] = -1;
			next[nb] = head[b];
			if (head[b] >= 0) {
				prev[head[b]] = nb;
			}
			head[b] = nb;
		}
	}
}

int FlowField::cell_at(real_t p_x, real_t p_z) const {
	if (!has_grid()) {
		return -1;
	}
	const int x = int(std::floor((p_x - origin.x) / cell_size));
	const int z = int(std::floor((p_z - origin.y) / cell_size));
	if (x < 0 || z < 0 || x >= width || z >= depth) {
		return -1;
	}
	return z * width + x;
}

void FlowField::clamped_cell(real_t p_x, real_t p_z, int &r_x, int &r_z) const {
	r_x = std::clamp(int(std::floor((p_x - origin.x) / cell_size)), 0, std::max(0, width - 1));
	r_z = std::clamp(int(std::floor((p_z - origin.y) / cell_size)), 0, std::max(0, depth - 1));
}

int FlowField::goal_cell() const {
	return goal >= 0 ? goal_z * width + goal_x : -1;
}

real_t FlowField::distance(int p_cell) const {
	if (goal < 0 || p_cell < 0 || p_cell >= width * depth) {
		return -1.0f;
	}
	const int32_t value = cost[_padded(p_cell)];
	return value == kUnreached ? -1.0f : real_t(value) / real_t(kOrtho) * cell_size;
}

Vector2 FlowField::direction(real_t p_x, real_t p_z) const {
	const int own = cell_at(p_x, p_z);
	if (goal < 0 || own < 0) {
		return Vector2();
	}
	const int8_t own_step = toward[_padded(own)];
	if (own_step < 0) {
		return Vector2();
	}
	const Vector2 own_dir = Vector2(real_t(kStepX[own_step]), real_t(kStepZ[own_step])).normalized();
	// Bilinear between the four nearest cell centers, like the ground height,
	// counting only cells that flow the same way as the enemy's own (within
	// 90°). On a ridge between two routes the far side would cancel the
	// sideways part and leave a push straight into whatever splits them.
	const real_t gx = (p_x - origin.x) / cell_size - 0.5f;
	const real_t gz = (p_z - origin.y) / cell_size - 0.5f;
	const int x0 = int(std::floor(gx));
	const int z0 = int(std::floor(gz));
	const real_t fx = gx - real_t(x0);
	const real_t fz = gz - real_t(z0);
	Vector2 sum;
	for (int k = 0; k < 4; ++k) {
		const int x = x0 + (k & 1);
		const int z = z0 + (k >> 1);
		if (x < 0 || z < 0 || x >= width || z >= depth) {
			continue;
		}
		const int8_t step = toward[(z + 1) * padded_width + x + 1];
		if (step < 0) {
			continue;
		}
		const real_t unit = step >= 4 ? kHalfSqrt2 : 1.0f;
		const Vector2 dir(real_t(kStepX[step]) * unit, real_t(kStepZ[step]) * unit);
		if (dir.dot(own_dir) <= 0.0f) {
			continue;
		}
		const real_t weight = ((k & 1) ? fx : 1.0f - fx) * ((k >> 1) ? fz : 1.0f - fz);
		sum += dir * weight;
	}
	const real_t length = sum.length();
	return length > kTiny ? sum / length : own_dir;
}

bool FlowField::line_clear(int p_cell) {
	if (goal < 0 || p_cell < 0 || p_cell >= width * depth) {
		return false;
	}
	uint8_t &cached = line_cache[p_cell];
	if (cached != 0) {
		return cached == 1;
	}
	// A 4-connected walk between cell centers visits every cell the segment
	// crosses. Where it passes exactly through a corner, both cells beside
	// the corner must be open.
	int x = p_cell % width;
	int z = p_cell / width;
	const int dx = std::abs(goal_x - x);
	const int dz = std::abs(goal_z - z);
	const int sx = goal_x > x ? 1 : -1;
	const int sz = goal_z > z ? 1 : -1;
	int error = dx - dz;
	bool clear = true;
	for (int left = dx + dz; left > 0 && clear;) {
		if (error > 0) {
			x += sx;
			error -= 2 * dz;
			--left;
		} else if (error < 0) {
			z += sz;
			error += 2 * dx;
			--left;
		} else {
			clear = _open(x + sx, z) && _open(x, z + sz);
			x += sx;
			z += sz;
			error += 2 * dx - 2 * dz;
			left -= 2;
		}
		// The goal cell may be closed; Taln stands there anyway.
		if (clear && !(x == goal_x && z == goal_z) && !_open(x, z)) {
			clear = false;
		}
	}
	cached = clear ? 1 : 2;
	return clear;
}

int FlowField::_padded(int p_cell) const {
	return (p_cell / width + 1) * padded_width + p_cell % width + 1;
}

bool FlowField::_open(int p_x, int p_z) const {
	return open[(p_z + 1) * padded_width + p_x + 1] != 0;
}
