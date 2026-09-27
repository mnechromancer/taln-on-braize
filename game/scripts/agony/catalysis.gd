class_name Catalysis
extends Node
## Resolves a full Agony meter (spec §3.3–3.4, §4).
##
## Case A: with no catalyst owned, Catalysis still locked, or no owned
## catalyst within the budget, the point banks at once (a notice, no pause).
## The first point ever banked unlocks Catalysis (§4.2).
##
## Case B, the Welcome the Agony state machine:
##   PROMPT (prompt_window real seconds): Welcome → CATALYZE; Bank or
##     timeout → bank.
##   CATALYZE (catalyze_window real seconds): hold a catalyst's icon
##     commit_hold to commit it (its cost comes off the budget). Release, or
##     nothing uncommitted still fitting the budget, fires every committed
##     Cataclysm together, cheapest tier first; the meter empties and nothing
##     banks. Expiry with nothing committed banks; with something committed
##     it fires.
## Both windows run at window_time_scale (or a full pause with
## catalyze_full_pause) and are timed in real, unscaled seconds. While one is
## open Agony gain is suspended, the mouse is free, the Invest menu is shut
## and Taln can move but not Shoulder, cast or Draw. Something like the
## Return sequence can hold() resolution: a fill waits until it's released,
## and a fill never opens a window over the paused Invest menu.

enum State { IDLE, PROMPT, CATALYZE }

## After every fill resolves. choice: &"auto_bank" (Case A), &"bank",
## &"timeout_bank" (prompt ran out), &"catalyze_bank" (Catalyze ran out with
## nothing committed), &"return_bank" (Taln died deciding), &"fire". fired
## lists the Cataclysms, in firing order; committed, what was committed when
## the fill resolved (fired, or banked anyway).
signal resolved(choice: StringName, fired: Array[SkillDef], committed: Array[SkillDef])
signal prompt_opened
signal welcomed
## A point went to MetaState. first: it was the first ever (Catalysis unlocked).
signal banked(first: bool)
signal committed(skill: SkillDef, budget_left: int)

@export var tuning: AgonyTuning
@export var taln: Taln
@export var menu: LevelUpMenu
@export var camera_rig: CameraRig

var state: State = State.IDLE
## Real seconds left in the open window.
var window_left: float = 0.0
var committed_skills: Array[SkillDef] = []
var budget_left: int = 0
## Real seconds the held icon has been held.
var hold_time: float = 0.0
## Resolutions this cycle, for telemetry: {"choice", "fired" (ids), "msec"}.
var history: Array[Dictionary] = []

var _holding: SkillDef = null
var _holds: Dictionary[StringName, bool] = {}
var _pending: bool = false
var _time_scale_before: float = 1.0
## How the open window slowed the game: a full pause or the time scale.
var _paused_window: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	taln.agony.filled.connect(_on_filled)
	menu.closed.connect(func(_picked: bool) -> void: _retry_pending())


## Never leave the game slowed or paused behind a freed station.
func _exit_tree() -> void:
	_close_window()


func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	var real: float = delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	if _holding and state == State.CATALYZE:
		hold_time += real
		if hold_time >= tuning.commit_hold - 0.0001:
			var skill: SkillDef = _holding
			set_holding(null)
			commit(skill)
			if state != State.CATALYZE:
				return
	window_left -= real
	if window_left > 0.0:
		return
	if state == State.PROMPT:
		_bank(&"timeout_bank")
	elif committed_skills.is_empty():
		_bank(&"catalyze_bank")
	else:
		fire()


## True if a fill could open the prompt (Case B): Catalysis unlocked and an
## owned catalyst within the budget.
func can_catalyze() -> bool:
	if not Meta.state().catalysis_unlocked:
		return false
	for skill: SkillDef in taln.loadout.catalysts():
		if taln.loadout.catalyst_cost(skill) <= tuning.budget_ninths:
			return true
	return false


## Holds fills while source holds (the Return sequence); a fill that arrives
## meanwhile resolves once every hold is released.
func hold(source: StringName, on: bool) -> void:
	if on:
		_holds[source] = true
		return
	_holds.erase(source)
	_retry_pending()


func _retry_pending() -> void:
	if _pending and _holds.is_empty():
		_pending = false
		_resolve_fill()


func is_open() -> bool:
	return state != State.IDLE


## Prompt: Welcome → Catalyze.
func welcome() -> bool:
	if state != State.PROMPT:
		return false
	state = State.CATALYZE
	window_left = tuning.catalyze_window
	committed_skills.clear()
	budget_left = tuning.budget_ninths
	set_holding(null)
	welcomed.emit()
	return true


## Closes an open window by banking, whatever was committed (Taln died
## deciding: accepting is never a trap, and neither is dying).
func force_bank() -> bool:
	if state == State.IDLE:
		return false
	_bank(&"return_bank")
	return true


## Prompt: Bank.
func bank_now() -> bool:
	if state != State.PROMPT:
		return false
	_bank(&"bank")
	return true


## Starts (skill) or stops (null) holding a catalyst's icon.
func set_holding(skill: SkillDef) -> void:
	if skill != _holding:
		hold_time = 0.0
	_holding = skill


func holding() -> SkillDef:
	return _holding


## Catalyze: commits skill if it's an owned catalyst not yet committed that
## fits the budget left. Fires at once when nothing uncommitted still fits.
func commit(skill: SkillDef) -> bool:
	if state != State.CATALYZE or committed_skills.has(skill) or not taln.loadout.catalysts().has(skill):
		return false
	var cost: int = taln.loadout.catalyst_cost(skill)
	if cost > budget_left:
		return false
	committed_skills.append(skill)
	budget_left -= cost
	committed.emit(skill, budget_left)
	if not _anything_fits():
		fire()
	return true


## Catalyze: Release. Fires what's committed; nothing happens with nothing committed.
func release() -> bool:
	if state != State.CATALYZE or committed_skills.is_empty():
		return false
	fire()
	return true


## Every committed Cataclysm, cheapest tier first; the meter empties, nothing banks.
func fire() -> void:
	var order: Array[SkillDef] = committed_skills.duplicate()
	order.sort_custom(func(a: SkillDef, b: SkillDef) -> bool: return a.catalyst_tier < b.catalyst_tier)
	_close_window()
	for skill: SkillDef in order:
		var behavior: SkillBehavior = taln.loadout.get_behavior(skill.id)
		if behavior:
			behavior.cataclysm()
	taln.agony.empty()
	_record(&"fire", order)


func _anything_fits() -> bool:
	for skill: SkillDef in taln.loadout.catalysts():
		if not committed_skills.has(skill) and taln.loadout.catalyst_cost(skill) <= budget_left:
			return true
	return false


func _on_filled() -> void:
	if not _holds.is_empty():
		_pending = true
		return
	_resolve_fill()


func _resolve_fill() -> void:
	# Only a meter still full, with no window open, resolves; over the paused
	# Invest menu it waits for the menu to close.
	if state != State.IDLE or not taln.agony.is_locked:
		return
	# Over the paused Invest menu, or from a killing blow (the Return is about
	# to hold it): wait.
	if menu.is_open or get_tree().paused or taln.health.current <= 0.0:
		_pending = true
		return
	if not can_catalyze():
		_bank(&"auto_bank")
		return
	state = State.PROMPT
	window_left = tuning.prompt_window
	_open_window()
	prompt_opened.emit()


func _bank(choice: StringName) -> void:
	_close_window()
	var meta: Meta = Meta.state()
	var first: bool = not meta.catalysis_unlocked
	meta.bank_agony(1)
	if first:
		meta.unlock_catalysis()
	taln.agony.empty()
	banked.emit(first)
	_record(choice, [])


func _record(choice: StringName, fired: Array[SkillDef]) -> void:
	var held: Array[SkillDef] = committed_skills.duplicate() if choice != &"auto_bank" else ([] as Array[SkillDef])
	committed_skills.clear()
	history.append({"choice": choice, "fired": fired.map(func(s: SkillDef) -> StringName: return s.id),
			"committed": held.map(func(s: SkillDef) -> StringName: return s.id), "msec": Time.get_ticks_msec()})
	resolved.emit(choice, fired, held)


func _open_window() -> void:
	taln.agony.set_suspended(&"catalysis", true)
	taln.control_locked = true
	menu.blocked = true
	if camera_rig:
		camera_rig.capture_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_paused_window = tuning.catalyze_full_pause
	if _paused_window:
		get_tree().paused = true
	else:
		_time_scale_before = Engine.time_scale
		Engine.time_scale = tuning.window_time_scale


func _close_window() -> void:
	if state == State.IDLE:
		return
	state = State.IDLE
	set_holding(null)
	if _paused_window:
		get_tree().paused = false
	else:
		Engine.time_scale = _time_scale_before
	taln.agony.set_suspended(&"catalysis", false)
	# Unlock after this frame's physics: a pad B that banked is also Shoulder,
	# which Taln polls, and it mustn't read as a fresh press.
	if taln.is_inside_tree():
		taln.set_deferred(&"control_locked", false)
	else:
		taln.control_locked = false
	menu.blocked = false
	if camera_rig:
		camera_rig.capture_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
