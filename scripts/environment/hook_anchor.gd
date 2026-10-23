class_name HookAnchor
extends StaticBody2D
## A hook anchor: a wooden peg with a mint/teal iron ring.
## The stag's antlers catch the ring. Visual + highlight only; it never
## collides with anything (collision_layer/mask = 0), it only acts as the
## static end of the antler tether joint.

const MINT := Color("#7FE0C4")
const MINT_DEEP := Color("#3FA98A")
const WOOD := Color("#7C4A26")
const CREAM := Color("#FFF4E0")

var highlight := 0.0
var range_hint := 0.0   # 0..1, set by Main when the current stag is near
var linked: Node2D = null
var _pulse := 0.0
var _snap := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	add_to_group("anchors")

func _process(delta: float) -> void:
	_pulse += delta
	highlight = maxf(0.0, highlight - delta * 1.6)
	_snap = maxf(0.0, _snap - delta * 2.2)
	# Pull back toward a gentle idle intensity when not highlighted.
	queue_redraw()

func set_highlight(v: bool) -> void:
	if v:
		highlight = 1.0
	else:
		highlight = maxf(highlight, 0.0)

func set_linked(node: Node2D) -> void:
	if node != null and linked == null:
		_snap = 1.0   # just caught the antlers
	linked = node

func _draw() -> void:
	var idle := 0.5 + 0.5 * sin(_pulse * 2.6)
	var glow := clampf(maxf(highlight, idle * 0.3), 0.0, 1.0)

	# soft glow (grows and breathes when the player is in range)
	var breathe := 1.0 + idle * 0.08
	draw_circle(Vector2.ZERO, (30.0 + glow * 14.0) * breathe, Color(MINT.r, MINT.g, MINT.b, 0.12 * glow))
	draw_circle(Vector2.ZERO, (20.0 + glow * 9.0) * breathe, Color(MINT.r, MINT.g, MINT.b, 0.20 * glow))

	# snap ring when the antlers catch it
	if _snap > 0.0:
		var a := Color(MINT.r, MINT.g, MINT.b, _snap)
		draw_arc(Vector2.ZERO, 22.0 + (1.0 - _snap) * 26.0, 0, TAU, 32, a, 3.0)

	# wooden peg bracket
	draw_rect(Rect2(Vector2(-7, -3), Vector2(14, 8)), WOOD)
	draw_line(Vector2(-4, -22), Vector2(0, -3), WOOD, 4.0)
	draw_line(Vector2(4, -22), Vector2(0, -3), WOOD, 4.0)

	# mint iron ring
	draw_arc(Vector2.ZERO, 11.0, 0, TAU, 28, MINT_DEEP, 5.0)
	draw_arc(Vector2.ZERO, 11.0, 0, TAU, 28, MINT, 3.0)

	# hook hint arrows when the player is close
	if highlight > 0.35:
		var a := Color(CREAM.r, CREAM.g, CREAM.b, highlight)
		draw_arc(Vector2.ZERO, 20.0, PI * 0.1, PI * 0.9, 12, a, 2.0)
		draw_arc(Vector2.ZERO, 20.0, PI * 1.1, PI * 1.9, 12, a, 2.0)

	# faint reach ring so the player can read whether the stag is close enough
	if range_hint > 0.01:
		var ra := Color(MINT.r, MINT.g, MINT.b, 0.4 * range_hint)
		for k in 16:
			var a0 := float(k) * TAU / 16.0
			draw_arc(Vector2.ZERO, 130.0, a0, a0 + TAU / 32.0, 4, ra, 2.0)

	# the tether to the hooked stag (drawn in world space)
	if linked and is_instance_valid(linked):
		var target := to_local(linked.global_position)
		draw_line(Vector2.ZERO, target, MINT, 3.0)
		draw_line(Vector2.ZERO, target, Color(CREAM.r, CREAM.g, CREAM.b, 0.5), 1.0)
		draw_circle(Vector2.ZERO, 4.0, MINT)
