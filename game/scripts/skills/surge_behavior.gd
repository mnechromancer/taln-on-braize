class_name SurgeBehavior
extends SkillBehavior
## Base for Surge behaviors (spec §2.5, §5, §7.3). Loadout calls try_cast()
## when the Surge's binding is pressed. A cast needs the cooldown finished and
## the Investiture cost affordable; it spends the cost, routes through Toa'uma
## (unless the Blade carries it), aims, and hands off to _fire(). Aim is the
## same for every input: camera-forward flattened onto the ground, then
## soft-locked toward the densest cluster in range.
##
## Through Toa'uma the cast adds Strain and may roll a side effect. The Surge
## applies its own: Overcharge (magnitude × overcharge_mult), Misfire (aim
## turned at random) and Echo (fires again echo_delay later, re-aimed, at
## magnitude 1, with no cost, Strain or roll).

signal cast(direction: Vector3, hits: int, through_toa_uma: bool, effect: Toauma.Effect)
signal echoed(direction: Vector3, hits: int)

## Seconds until a pending Echo fires; 0 means none is pending.
var echo_left: float = 0.0
var _echo_through_toa_uma: bool = true


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if echo_left > 0.0:
		echo_left -= delta
		if echo_left <= 0.0:
			echo_left = 0.0
			var direction: Vector3 = aim_direction()
			echoed.emit(direction, _fire(taln.global_position, direction, _echo_through_toa_uma, 1.0))


## Off cooldown and affordable.
func is_ready() -> bool:
	return cooldown_left <= 0.0 and taln.investiture.can_afford(skill.investiture_cost)


## Toa'uma unless the skill is Blade-eligible and the Honorblade is held (spec §5.1).
func routes_through_toa_uma() -> bool:
	return not (skill.routing == SkillDef.Routing.BLADE_ELIGIBLE and taln.loadout.honorblade_held)


## Casts if ready. Returns false, spending nothing, otherwise.
func try_cast() -> bool:
	if not is_ready() or not taln.investiture.spend(skill.investiture_cost):
		return false
	cooldown_left = skill.cooldown
	var through_toa_uma: bool = routes_through_toa_uma()
	var effect: Toauma.Effect = Toauma.Effect.NONE
	if through_toa_uma:
		effect = taln.toauma.use_for_surge(skill.investiture_cost)
	var direction: Vector3 = aim_direction()
	if effect == Toauma.Effect.MISFIRE:
		direction = taln.toauma.misfire(direction)
	var magnitude: float = taln.toauma.tuning.overcharge_mult if effect == Toauma.Effect.OVERCHARGE else 1.0
	# A bargain's push on every Surge (P2-16), and the Strain it asks for.
	magnitude *= taln.loadout.surge_magnitude_mult
	if taln.loadout.surge_strain_add > 0.0:
		taln.toauma.add_strain(taln.loadout.surge_strain_add)
	var hits: int = _fire(taln.global_position, direction, through_toa_uma, magnitude)
	if effect == Toauma.Effect.ECHO:
		echo_left = taln.toauma.tuning.echo_delay
		_echo_through_toa_uma = through_toa_uma
	cast.emit(direction, hits, through_toa_uma, effect)
	return true


## Camera-forward on the ground plane, soft-locked toward the densest cluster
## within _aim_range() (spec §7.3).
func aim_direction() -> Vector3:
	var forward: Vector3 = -taln.global_basis.z
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		var look: Vector3 = -camera.global_basis.z
		forward = Basis(Vector3.UP, atan2(-look.x, -look.z)) * Vector3.FORWARD
	var swarm: SwarmServer = taln.loadout.swarm
	if swarm == null:
		return forward
	var t: LoadoutTuning = taln.loadout.tuning
	return swarm.find_densest_direction(taln.global_position, forward, t.surge_soft_lock_half_angle_deg,
			_aim_range(), t.surge_soft_lock_sectors)


## Override: how far the soft-lock looks for a cluster.
func _aim_range() -> float:
	return 0.0


## Override: the Surge's effect at this magnitude (1 normally, more when
## Overcharged). Returns how many enemies it hit.
func _fire(_origin: Vector3, _direction: Vector3, _through_toa_uma: bool, _magnitude: float) -> int:
	return 0
