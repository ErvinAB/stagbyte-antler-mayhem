class_name DebugOverlay
extends Node2D
## Optional debug visualization. Toggle with F3 (off by default so the
## prototype looks clean). Shows the stag physics body, hook radius,
## anchors, launch vector and current velocity.

const CREAM := Color("#FFF4E0")
const MINT := Color("#7FE0C4")
const CORAL := Color("#FF8A6A")
const YELLOW := Color("#FFD166")
const HANDLE_DBG := Color("#FFF4E0")

var enabled := false
var stag: Stag
var anchors: Array = []
var aim: AimController = null
var main: Node = null
var _flash := 0.0

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if not OS.is_debug_build() and not Progress.debug_unlock:
		return
	match event.keycode:
		KEY_F3:
			enabled = not enabled
			queue_redraw()
		KEY_F4:
			if main and main.has_method("debug_complete_level"):
				main.call("debug_complete_level")
		KEY_F5:
			Progress.set_debug_unlock(true)
			_flash = 1.2
		KEY_F6:
			if main and main.has_method("debug_score_bonus"):
				main.call("debug_score_bonus", 10000)


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()
	if _flash > 0.0:
		_flash -= _delta

func _draw() -> void:
	if _flash > 0.0:
		var font0 := ThemeDB.fallback_font
		draw_string(font0, Vector2(16, 640), "DEBUG: ALL LEVELS UNLOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, MINT)
	if not enabled:
		return
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(16, 700), "DEBUG (F3): shapes, hook+grab range, tension, velocity | F4 finish  F5 unlock-all  F6 +10k", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CREAM)
	draw_string(font, Vector2(16, 686), "FPS %d  bodies %d" % [Engine.get_frames_per_second(), get_tree().get_nodes_in_group("bodies").size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CREAM)

	for a in anchors:
		if not is_instance_valid(a):
			continue
		draw_arc(a.global_position, 12.0, 0, TAU, 20, MINT, 2.0)
		draw_line(a.global_position - Vector2(14, 0), a.global_position + Vector2(14, 0), MINT, 1.0)
		draw_line(a.global_position - Vector2(0, 14), a.global_position + Vector2(0, 14), MINT, 1.0)

	for b in get_tree().get_nodes_in_group("bodies"):
		if not is_instance_valid(b) or not (b is RigidBody2D):
			continue
		var col := Color(0.6, 0.9, 0.8, 0.5)
		if b.is_in_group("props"):
			col = Color(1.0, 0.7, 0.5, 0.5)
		_draw_body_shape(b, col)

	if stag and is_instance_valid(stag):
		draw_arc(stag.global_position, stag.HOOK_RADIUS, 0, TAU, 48, Color(MINT.r, MINT.g, MINT.b, 0.5), 2.0)
		draw_arc(stag.global_position, stag.GRAB_RADIUS, 0, TAU, 48, Color(YELLOW.r, YELLOW.g, YELLOW.b, 0.35), 2.0)
		var v: Vector2 = stag.linear_velocity
		draw_line(stag.global_position, stag.global_position + v * 0.2, YELLOW, 3.0)
		draw_string(font, stag.global_position + v * 0.2 + Vector2(6, 0), "%d px/s" % int(v.length()), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, YELLOW)
		if stag.hooked:
			draw_string(font, stag.global_position + Vector2(-30, -50), "HOOKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MINT)
			if stag.perfect_ready():
				draw_string(font, stag.global_position + Vector2(-30, -34), "PERFECT!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CREAM)
		if stag.grabbing:
			draw_string(font, stag.global_position + Vector2(-30, -34), "GRABBING", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, YELLOW)
	# grabbable / rip state readout
	for b in get_tree().get_nodes_in_group("props"):
		if not is_instance_valid(b) or not (b is PhysicsProp):
			continue
		var prop: PhysicsProp = b
		if prop.is_grabbable():
			var gc := Color(HANDLE_DBG.r, HANDLE_DBG.g, HANDLE_DBG.b, 0.9)
			draw_arc(prop.global_position, 8.0, 0, TAU, 16, gc, 1.5)
		if prop.rippable and prop.get_tension() > 0.01:
			var ta := Color(CORAL.r, CORAL.g, CORAL.b, 0.9)
			draw_arc(prop.global_position, 14.0, -PI * 0.5, -PI * 0.5 + TAU * prop.get_tension(), 20, ta, 3.0)
	if aim and aim.aiming:
		draw_line(aim.drag_from, aim.drag_to, CORAL, 2.0)
		draw_circle(aim.drag_from, 4.0, CORAL)

func _draw_body_shape(body: PhysicsBody2D, col: Color) -> void:
	for c in body.get_children():
		if c is CollisionShape2D and c.shape:
			var s: Shape2D = c.shape
			if s is CircleShape2D:
				draw_arc(body.global_position + c.position, s.radius, 0, TAU, 24, col, 2.0)
			elif s is RectangleShape2D:
				var pts := PackedVector2Array()
				for corner in [
					Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
					pts.append(body.global_position + (corner * s.size * 0.5).rotated(body.global_rotation))
				draw_polyline(pts, col, 2.0)
			elif s is CapsuleShape2D:
				draw_arc(body.global_position, s.radius, 0, TAU, 24, col, 2.0)
