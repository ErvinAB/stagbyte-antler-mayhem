class_name AimController
extends Node2D
## Launch / aim controller. Slingshot model: the player drags AWAY from the
## desired launch direction and the pull length sets the power.
## Draws the drag band, an arrow and a dotted trajectory prediction.

const MAX_DRAG := 185.0
const MIN_POWER := 0.1
const MAX_IMPULSE := 1160.0
const DEADZONE := 14.0
const TRAJECTORY_STEPS := 34

const CREAM := Color("#FFF4E0")
const MINT := Color("#7FE0C4")
const CORAL := Color("#FF8A6A")
const YELLOW := Color("#FFD166")

var stag: Stag
var gravity := 931.0
var aiming := false
var drag_from := Vector2.ZERO
var drag_to := Vector2.ZERO

func setup(stag_node: Stag, gravity_value: float) -> void:
	stag = stag_node
	gravity = gravity_value
	z_index = 5

func begin(pos: Vector2) -> void:
	aiming = true
	drag_from = stag.global_position
	drag_to = pos
	queue_redraw()

func update(pos: Vector2) -> void:
	if not aiming:
		return
	drag_to = pos
	var pull := _pull_vector()
	if stag.visual:
		stag.visual.set_pull(pull * 0.16)
	queue_redraw()

func cancel() -> void:
	aiming = false
	if stag and stag.visual:
		stag.visual.clear_pull()
	queue_redraw()

func commit() -> Dictionary:
	var pull := _pull_vector()
	var power := power_from_pull(pull.length())
	var dir := launch_dir(pull)
	aiming = false
	if stag and stag.visual:
		stag.visual.clear_pull()
	queue_redraw()
	return {
		"dir": dir,
		"power": power,
		"impulse": impulse_for(power),
	}

func power_from_pull(length: float) -> float:
	if length < DEADZONE:
		return 0.0
	return clampf(length / MAX_DRAG, MIN_POWER, 1.0)

func impulse_for(power: float) -> float:
	return MAX_IMPULSE * power

func launch_dir(_pull: Vector2) -> Vector2:
	var pull := _pull_vector()
	if pull.length() < DEADZONE:
		return Vector2.RIGHT
	return pull.normalized()

func _pull_vector() -> Vector2:
	return drag_from - drag_to

# ------------------------------------------------------------------ drawing --

func _draw() -> void:
	if not aiming or stag == null:
		return
	var origin := stag.global_position
	var pull := _pull_vector()
	var power := power_from_pull(pull.length())
	var dir := launch_dir(pull)

	# rubber band
	draw_line(origin, drag_to, Color(CREAM.r, CREAM.g, CREAM.b, 0.55), 3.0)
	draw_circle(drag_to, 9.0, Color(CREAM.r, CREAM.g, CREAM.b, 0.25))

	# power arrow
	var arrow_end := origin + dir * (60.0 + power * 90.0)
	var col := MINT.lerp(CORAL, power)
	_draw_arrow(origin + dir * 18.0, arrow_end, col, 4.0)

	# power gauge arc around the drag point
	draw_arc(drag_to, 26.0, -PI * 0.5, -PI * 0.5 + TAU * power, 24, col, 4.0)
	draw_arc(drag_to, 26.0, 0, TAU, 32, Color(col.r, col.g, col.b, 0.18), 2.0)

	# predicted trajectory (short + readable; matches the stag's real arc)
	var mass: float = maxf(stag.mass, 0.01)
	var v: Vector2 = dir * (impulse_for(power) / mass)
	var p: Vector2 = origin
	var dt := 1.0 / 60.0
	for i in TRAJECTORY_STEPS:
		v.y += gravity * dt
		p += v * dt
		if p.y > 646.0 or p.x < 20.0 or p.x > 1260.0:
			break
		if i % 3 == 0:
			var a := 0.55 * (1.0 - float(i) / float(TRAJECTORY_STEPS))
			var dot := Color(YELLOW.r, YELLOW.g, YELLOW.b, a)
			draw_circle(p, 3.2, dot)

func _draw_arrow(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	draw_line(a, b, col, width)
	var back := (a - b).normalized()
	var left := back.rotated(0.5) * 14.0
	var right := back.rotated(-0.5) * 14.0
	draw_colored_polygon(PackedVector2Array([b, b + left, b + right]), col)
