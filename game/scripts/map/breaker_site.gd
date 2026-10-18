class_name BreakerSite
extends Node3D
## Where a region's breaker waits (spec v1.4 #4). Until real breakers exist a
## siege stands in (P2-10). A tall beacon, unfogged so it reads from across
## the region, and a ring on the ground at the trigger radius. Emissive only:
## no light (spec §12). The station drives its state.

enum State { WAITING, SIEGE, FALLEN }

const WAITING_COLOR := Color("6b3fa0")
const SIEGE_COLOR := Color("e0581f")
const FALLEN_COLOR := Color("2a2825")
const BEACON_RADIUS := 0.35
const RING_HEIGHT := 0.03

@export var tuning: RegionTuning

var state: State = State.WAITING

var _material := StandardMaterial3D.new()


func _ready() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.disable_fog = true
	var beacon := MeshInstance3D.new()
	var column := CylinderMesh.new()
	column.top_radius = BEACON_RADIUS
	column.bottom_radius = BEACON_RADIUS
	column.height = tuning.beacon_height
	beacon.mesh = column
	beacon.position.y = tuning.beacon_height * 0.5
	beacon.material_override = _material
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beacon)
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = tuning.site_radius
	disc.bottom_radius = tuning.site_radius
	disc.height = RING_HEIGHT
	ring.mesh = disc
	ring.position.y = RING_HEIGHT
	ring.material_override = _material
	ring.transparency = 0.6
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	set_state(State.WAITING)


func set_state(value: State) -> void:
	state = value
	match state:
		State.WAITING:
			_material.albedo_color = WAITING_COLOR
		State.SIEGE:
			_material.albedo_color = SIEGE_COLOR
		State.FALLEN:
			_material.albedo_color = FALLEN_COLOR


## True if at is within the trigger radius on XZ.
func is_inside(at: Vector3) -> bool:
	return Vector2(at.x - global_position.x, at.z - global_position.z).length() <= tuning.site_radius
