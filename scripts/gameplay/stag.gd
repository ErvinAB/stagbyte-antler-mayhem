class_name Stag
extends RigidBody2D
## ANTLER MAYHEM — the stag.
##
## Physics body is intentionally simple (CircleShape2D). All the character
## personality lives in the child "Visual" node (stag_visual.gd).
##
## Sprint 4: the antlers are the tool. Besides HOOKING rings, the stag can now
## GRAB a grabbable prop (antlers clamp on), CARRY/SWING it, and THROW it on
## release. Pulling a weak joint (a "rippable" prop) builds TENSION until it
## rips free. Releasing a swing in the perfect window is a PERFECT RELEASE.

signal launched(dir: Vector2, power: float)
signal hook_attached(anchor: Node2D)
signal hook_released()
signal perfect_released(power: float)
signal grabbed(body: Node)
signal released_grab(body: Node, thrown: bool)
signal impacted(energy: float, other: Node)
signal landed_hard(energy: float)

const HOOK_RADIUS := 130.0
const MIN_ROPE := 70.0
const MAX_ROPE := 220.0
const MAX_ANGULAR := 9.0
const SETTLE_TIME := 0.75
const MAX_SPEED := 2400.0

# --- antler grab -------------------------------------------------------------
const GRAB_RADIUS := 120.0
const GRAB_HOLD := 44.0     # rest distance the held object is kept at
const GRAB_STIFF := 14.0    # spring stiffness pulling the object to the hold point
const GRAB_MAX_DV := 900.0  # cap on the per-step velocity correction
const THROW_BOOST := 1.18
const THROW_MIN := 260.0

# --- perfect release ---------------------------------------------------------
const PERFECT_MIN_SPEED := 520.0
const PERFECT_ANGLE := 0.30   # radians (~17°) from horizontal

@onready var visual: StagVisual = $Visual

## Cosmetic character id (buck / mochi / bruno). Gameplay physics is identical
## for every character — only the art and idle personality differ.
@export var character := "buck"

var airborne := false
var hooked := false
var grabbing := false
## A spent stag stays in the room as a comedic physics obstacle. Passive stags
## cannot hook, cannot be launched, and do not emit gameplay signals (so they
## can knock things around without farming score).
var passive := false

var _hook_pivot := Vector2.ZERO
var _hook_rest := 0.0
var _anchor: Node2D
var _grab_body: PhysicsProp = null
var _grab_hold := Vector2.ZERO
var _spawn_transform: Transform2D
var _settle_speed := 0.0
var _has_impacted_ground := false

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)
	_spawn_transform = global_transform
	visual.set_character(character)
	visual.set_idle(true)

func store_spawn() -> void:
	_spawn_transform = global_transform

func make_passive() -> void:
	## Called when a stag's attempt is over: it becomes a rolling prop.
	if passive:
		return
	passive = true
	hooked = false
	airborne = false
	_drop_grab()
	if _anchor and is_instance_valid(_anchor) and _anchor.has_method("set_linked"):
		_anchor.call("set_linked", null)
	_anchor = null
	angular_damp = 1.5
	linear_damp = 0.25
	visual.set_passive()

func set_aiming(_on: bool) -> void:
	airborne = false
	visual.set_idle(true)

# ------------------------------------------------------------------ launch --
func launch(dir: Vector2, impulse: float) -> void:
	freeze = false
	airborne = true
	hooked = false
	_drop_grab()
	call_deferred("apply_impulse", dir * impulse)
	visual.launch(dir)
	emit_signal("launched", dir, impulse)

# -------------------------------------------------------------------- hook --
func can_hook() -> bool:
	return airborne and not hooked and not freeze and not passive and _grab_body == null

func hook(anchor: Node2D) -> bool:
	if not can_hook():
		return false
	if global_position.distance_to(anchor.global_position) > HOOK_RADIUS + 40.0:
		return false
	# The antlers catch the ring: the tether is a rigid distance constraint.
	# NOTE: Godot 4.7.2's native PinJoint2D / DampedSpringJoint2D are not stable
	# under gravity in this build (a pinned body sinks and the arm stretches
	# without bound), so the constraint is solved directly in _integrate_forces.
	# It behaves like a healthy pin: the stag swings on a fixed-radius arc and
	# only the radial velocity is cancelled, so releasing keeps the swing speed.
	_hook_pivot = anchor.global_position
	_hook_rest = clampf(global_position.distance_to(anchor.global_position), MIN_ROPE, MAX_ROPE)
	_anchor = anchor
	hooked = true
	angular_damp = 4.0
	linear_damp = 0.05
	visual.hook_flash()
	visual.wobble(-16.0)
	if anchor.has_method("set_linked"):
		anchor.call("set_linked", self)
	if has_node("/root/Sfx"):
		Sfx.play("hook", randf_range(0.95, 1.15), -8.0)
		Sfx.play("creak", randf_range(0.9, 1.1), -14.0)
	emit_signal("hook_attached", anchor)
	return true

func unhook() -> void:
	if not hooked:
		return
	var perfect := perfect_ready()
	var power := linear_velocity.length()
	if _anchor and is_instance_valid(_anchor) and _anchor.has_method("set_linked"):
		_anchor.call("set_linked", null)
	_anchor = null
	hooked = false
	angular_damp = 3.0
	linear_damp = 0.1
	if perfect:
		visual.perfect_flash()
		if has_node("/root/Sfx"):
			Sfx.play("combo", randf_range(1.05, 1.15), -6.0)
		emit_signal("perfect_released", power)
	else:
		visual.wobble(12.0)
		if has_node("/root/Sfx"):
			Sfx.play("whoosh", randf_range(1.1, 1.3), -12.0)
	emit_signal("hook_released")

func nearest_anchor(anchors: Array, from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := HOOK_RADIUS
	for a in anchors:
		if not is_instance_valid(a):
			continue
		var d: float = global_position.distance_to(a.global_position)
		# Player press position may bias the choice a little (assist).
		d += from.distance_to(a.global_position) * 0.25
		if d < best_d:
			best_d = d
			best = a
	return best

# -------------------------------------------------------------------- grab --
func can_grab() -> bool:
	return airborne and not hooked and not freeze and not passive and _grab_body == null

func nearest_grabbable(list: Array, from: Vector2) -> PhysicsProp:
	var best: PhysicsProp = null
	var best_d := GRAB_RADIUS
	for p in list:
		if not is_instance_valid(p):
			continue
		if not p.is_grabbable():
			continue
		var d: float = global_position.distance_to(p.global_position)
		# Player press position may bias the choice a little (assist).
		d += from.distance_to(p.global_position) * 0.25
		if d < best_d:
			best_d = d
			best = p
	return best

func grab(body: PhysicsProp) -> bool:
	if not can_grab() or body == null or not body.is_grabbable():
		return false
	if global_position.distance_to(body.global_position) > GRAB_RADIUS:
		return false
	_grab_body = body
	_grab_hold = (body.global_position - global_position).limit_length(GRAB_HOLD)
	grabbing = true
	body.set_grabbed(true)
	body.set_grab_highlight(true)
	angular_damp = 2.2
	visual.grab_flash()
	if has_node("/root/Sfx"):
		Sfx.play("hook", randf_range(0.85, 0.98), -10.0)
	emit_signal("grabbed", body)
	return true

func release_grab(thrown: bool) -> void:
	if _grab_body == null:
		grabbing = false
		return
	var b := _grab_body
	_drop_grab()
	if thrown and is_instance_valid(b):
		var v: Vector2 = b.linear_velocity
		if v.length() < 40.0:
			# predictable throw direction: keep travelling the way the stag was,
			# otherwise fling along the way the stag is facing.
			var dir := Vector2.ZERO
			if linear_velocity.length() > 50.0:
				dir = linear_velocity.normalized()
			elif absf(linear_velocity.x) > 1.0:
				dir = Vector2.RIGHT if linear_velocity.x > 0.0 else Vector2.LEFT
			else:
				dir = Vector2.RIGHT.rotated(rotation)
			v = dir * THROW_MIN
		b.linear_velocity = v * THROW_BOOST
		visual.wobble(10.0)
		if has_node("/root/Sfx"):
			Sfx.play("whoosh", randf_range(0.95, 1.1), -9.0)
	emit_signal("released_grab", b, thrown)

func _drop_grab() -> void:
	if _grab_body and is_instance_valid(_grab_body):
		_grab_body.set_grabbed(false)
	_grab_body = null
	grabbing = false

# --------------------------------------------------------- perfect release --
func perfect_ready() -> bool:
	## True when releasing now would count as a Perfect Release: moving fast and
	## travelling close to horizontal at the bottom of the swing.
	if not hooked or not airborne:
		return false
	var v := linear_velocity
	if v.length() < PERFECT_MIN_SPEED:
		return false
	var a := absf(wrapf(v.angle(), -PI, PI))
	return a < PERFECT_ANGLE or a > PI - PERFECT_ANGLE

# ----------------------------------------------------------------- physics --
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Never let the little idiot become a helicopter.
	if absf(state.angular_velocity) > MAX_ANGULAR:
		state.angular_velocity = signf(state.angular_velocity) * MAX_ANGULAR

	# Antler tether: a rigid distance constraint (a stiff arm, like a healthy
	# PinJoint2D) solved directly so the pendulum is stable and preserves the
	# tangential swing. Native joints are unstable in this engine build.
	if hooked:
		var d: Vector2 = state.transform.origin - _hook_pivot
		var length: float = d.length()
		if length > 0.001:
			var dir: Vector2 = d / length
			# keep exactly on the tether circle
			state.transform.origin -= dir * (length - _hook_rest)
			# cancel only the radial velocity, keep the swing speed
			state.linear_velocity -= dir * state.linear_velocity.dot(dir)

func _physics_process(delta: float) -> void:
	if grabbing:
		_solve_grab(delta)
	# physics safety: never let the stag become an unreadable blur
	var sp := linear_velocity
	if sp.length() > MAX_SPEED:
		linear_velocity = sp.normalized() * MAX_SPEED

	if not airborne:
		return
	var speed := linear_velocity.length()
	if speed < 30.0:
		_settle_speed += delta
		if _settle_speed > SETTLE_TIME and not hooked and not grabbing:
			airborne = false
	else:
		_settle_speed = 0.0
	# Safety: if it somehow escapes the arena, stop waiting.
	if global_position.y > 900.0 or global_position.x > 1500.0 or global_position.x < -220.0:
		airborne = false

func _solve_grab(delta: float) -> void:
	var b := _grab_body
	if not is_instance_valid(b):
		_drop_grab()
		return
	# Pulling a weak joint builds tension from how fast the antlers strain
	# against it (relative speed). A slow nudge cannot rip anything.
	if b.rippable:
		var rel_speed := (linear_velocity - b.linear_velocity).length()
		b.add_tension(rel_speed / PhysicsProp.RIP_FILL_SPEED * delta)
		if not is_instance_valid(b):
			_drop_grab()
			return
	# Frozen structural joints only strain — the stag cannot physically drag a
	# wall around, so there is no tug, just accumulating tension.
	if b.kind in PhysicsProp.STATIC_KINDS:
		return
	# Soft, MOMENTUM-PRESERVING constraint: equal-and-opposite impulses pull the
	# object to the antler hold point while the stag is pulled back the other
	# way, so grabbing feels physical instead of magnetic.
	var target := global_position + _grab_hold
	var desired := (target - b.global_position) * GRAB_STIFF
	var dv := (desired - b.linear_velocity).limit_length(GRAB_MAX_DV)
	var imp := dv * b.mass
	b.apply_central_impulse(imp)
	if not freeze:
		apply_central_impulse(-imp)

func is_resting() -> bool:
	return not airborne

# ---------------------------------------------------------------- collision --
func _on_body_entered(body: Node) -> void:
	var other_vel := Vector2.ZERO
	if body is RigidBody2D:
		other_vel = body.linear_velocity
	var rel := (linear_velocity - other_vel).length()
	var energy := rel * mass
	if energy < 90.0:
		return
	visual.impact(clampf(energy / 600.0, 0.25, 1.4))
	if energy > 380.0:
		visual.wobble(clampf(energy / 90.0, 2.0, 16.0))
		visual.dizzy(1.4 if energy > 620.0 else 0.8)
	# A passive (spent) stag still reacts visually but must not emit gameplay
	# signals, so it cannot farm score or spam impact feedback.
	if passive:
		return
	if energy > 380.0:
		emit_signal("landed_hard", energy)
	emit_signal("impacted", energy, body)
