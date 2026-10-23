class_name StagVisual
extends Node2D
## Original vector-art stag, drawn entirely with Godot draw_* calls.
## VISUAL is deliberately separate from the physics body so the art can be
## replaced with sprites later without touching physics / gameplay code.
##
## Character: oversized head, tiny body, enormous branching antlers,
## big expressive eyes, warm orange/brown fur. "Cute little idiot."

# The stag is the star: art is drawn larger than the physics body on purpose.
# Visual and physics are kept separate so the hitbox stays fair.
const BASE_SCALE := 1.65

const FUR := Color("#C9762F")
const FUR_DARK := Color("#9C5820")
const FUR_LIGHT := Color("#E8A863")
const BELly := Color("#F0C08A")
const ANTLER := Color("#E9D6A8")
const ANTLER_DARK := Color("#C9B483")
const EYE_WHITE := Color("#FFF6E6")
const PUPIL := Color("#2A1B33")
const NOSE := Color("#4A2C40")

# --- cosmetic character profile (Buck / Mochi / Bruno) -----------------------
# IMPORTANT: these change ART ONLY. The physics body and all gameplay behavior
# are identical for every character, so variety costs nothing in balance.
var character := "buck"
var base_scale := BASE_SCALE
var _body_scale := 1.0        # body/head size multiplier
var _eye_scale := 1.0         # eye size multiplier
var _antler_scale := 1.0      # antler thickness multiplier
var _eyelid := 0.0            # 0..1 permanent lid droop (Bruno: unimpressed)
var _look := 0.0              # pupil horizontal offset (looking around)
var _blink_lo := 1.8
var _blink_hi := 4.0
var _breath := 0.0
var drowsy := false
var col_fur := FUR
var col_fur_dark := FUR_DARK
var col_fur_light := FUR_LIGHT
var col_belly := BELly

# --- animation state ---
var eye_open := 1.0
var eye_widen := 1.0
var _blink := 0.0
var _blink_timer := 2.0
var _idle := true
var speed_ratio := 0.0

var _lean := 0.0
var _stretch := Vector2.ONE

var _antler_x := 0.0
var _antler_v := 0.0

var _dizzy := 0.0
var _squash := 0.0
var _spin := 0.0
var _pull := Vector2.ZERO
var _aim_stretch := 0.0
var _hook_glow := 0.0
var _grab_glow := 0.0
var _perfect_glow := 0.0
var _perfect_ready := false
var _passive := false
var _passive_timer := 0.0

func _process(delta: float) -> void:
	var body := get_parent() as RigidBody2D
	var speed := 0.0
	if body:
		speed = body.linear_velocity.length()
	speed_ratio = clampf(speed / 750.0, 0.0, 1.0)

	# eyes widen with speed, relax when calm
	var widen_target := 1.0 + speed_ratio * 0.55
	eye_widen = lerpf(eye_widen, widen_target, delta * 6.0)

	# idle blink
	if _idle:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blink = 1.0
			_blink_timer = randf_range(_blink_lo, _blink_hi)
	# a dozing lodge stag blinks long and slow
	if drowsy:
		_blink = maxf(_blink, 0.65 + 0.2 * sin(Time.get_ticks_msec() * 0.0016))
	_blink = maxf(0.0, _blink - delta * 7.0)
	eye_open = 1.0 - _blink
	# looking around relaxes back to centre
	_look = lerpf(_look, 0.0, delta * 1.6)
	_breath = maxf(0.0, _breath - delta * 2.0)

	# lean into travel direction (capped so it never looks broken)
	if body:
		var target_lean := 0.0
		if speed > 40.0:
			var diff := wrapf(body.linear_velocity.angle() - body.global_rotation, -PI, PI)
			target_lean = clampf(diff, -0.6, 0.6)
		_lean = lerpf(_lean, target_lean, delta * 5.0)
		rotation = _lean

	# stretch relaxes back to normal
	_stretch = _stretch.lerp(Vector2.ONE, delta * 7.0)
	# squash relaxes back
	_squash = maxf(0.0, _squash - delta * 4.0)

	var squash_x := 1.0 + _squash * 0.35
	var squash_y := 1.0 - _squash * 0.3
	var aim_x := 1.0 + _aim_stretch * 0.18
	var aim_y := 1.0 - _aim_stretch * 0.14
	var breathe := 1.0 + (0.02 * sin(Time.get_ticks_msec() * 0.0018) + _breath * 0.12) if _idle else 1.0
	scale = base_scale * Vector2(_stretch.x * squash_x * aim_x, _stretch.y * squash_y * aim_y) * breathe
	position = position.lerp(_pull, delta * 20.0)

	# antler spring wobble
	_antler_v += (-_antler_x * 24.0 - _antler_v * 5.0) * delta
	_antler_x += _antler_v * delta

	_hook_glow = maxf(0.0, _hook_glow - delta * 2.2)
	_grab_glow = maxf(0.0, _grab_glow - delta * 1.7)
	_perfect_glow = maxf(0.0, _perfect_glow - delta * 1.3)
	# Query the body so the player can SEE when a Perfect Release is available
	# (the antlers glow while the swing is flat and fast).
	var p := get_parent()
	if p is Stag:
		_perfect_ready = p.perfect_ready()
		if p.grabbing:
			_grab_glow = maxf(_grab_glow, 0.45)
	else:
		_perfect_ready = false
	_dizzy = maxf(0.0, _dizzy - delta)
	# A passive (spent) stag occasionally shakes its head, bemused.
	if _passive:
		_passive_timer -= delta
		if _passive_timer <= 0.0:
			_passive_timer = randf_range(3.0, 6.0)
			_antler_v += 4.0
			_squash = 0.4
	_spin += delta * 6.0
	queue_redraw()

func set_passive() -> void:
	_passive = true
	_idle = false
	_passive_timer = randf_range(2.0, 4.0)

func set_idle(v: bool) -> void:
	_idle = v

func set_character(id: String) -> void:
	## Cosmetic only — no gameplay/physics impact whatsoever.
	character = id
	base_scale = BASE_SCALE
	_body_scale = 1.0
	_eye_scale = 1.0
	_antler_scale = 1.0
	_eyelid = 0.0
	_blink_lo = 1.8
	_blink_hi = 4.0
	col_fur = FUR
	col_fur_dark = FUR_DARK
	col_fur_light = FUR_LIGHT
	col_belly = BELly
	match id:
		"mochi":
			# smaller body, huge eyes, hyperactive: quick blinks, bouncy
			base_scale = BASE_SCALE * 0.86
			_body_scale = 0.86
			_eye_scale = 1.4
			_antler_scale = 0.78
			_blink_lo = 0.7
			_blink_hi = 1.8
			col_fur = Color("#E8A05A")
			col_fur_dark = Color("#C77E38")
			col_fur_light = Color("#F6D3A6")
			col_belly = Color("#FFF0D8")
		"bruno":
			# chunkier body, heavy antlers, permanently unimpressed
			base_scale = BASE_SCALE * 1.02
			_body_scale = 1.22
			_eye_scale = 0.9
			_antler_scale = 1.45
			_eyelid = 0.42
			_blink_lo = 3.2
			_blink_hi = 6.5
			col_fur = Color("#A9673A")
			col_fur_dark = Color("#7E4A26")
			col_fur_light = Color("#CE8B4F")
			col_belly = Color("#E0B487")
		_:
			pass   # buck: the classic
	queue_redraw()

func drowsy_sleep(v: bool) -> void:
	drowsy = v

func look_around(amount: float) -> void:
	## Small horizontal head/pupil glance for lodge idle behavior.
	_look = clampf(amount, -1.0, 1.0)

func breathe() -> void:
	_breath = 1.0

func set_pull(v: Vector2) -> void:
	_pull = v
	_aim_stretch = clampf(v.length() / 40.0, 0.0, 1.0)

func clear_pull() -> void:
	_pull = Vector2.ZERO
	_aim_stretch = 0.0

func launch(dir: Vector2) -> void:
	_stretch = Vector2(0.78, 1.28).rotated(dir.angle())
	_antler_v -= 12.0
	eye_widen = 1.7
	_idle = false

func impact(power: float) -> void:
	_squash = clampf(power, 0.3, 1.4)
	_antler_v += 9.0 * clampf(power, 0.2, 1.5)

func wobble(amount: float) -> void:
	_antler_v += amount

func hook_flash() -> void:
	# Antlers light up and kick when they catch a ring.
	_hook_glow = 1.0
	_antler_v -= 10.0
	eye_widen = 1.4

func grab_flash() -> void:
	# Antlers clamp down on a grabbable prop.
	_grab_glow = 1.0
	_antler_v -= 7.0
	_squash = 0.5
	eye_widen = 1.3

func perfect_flash() -> void:
	# Bright, satisfying pop when the swing is released in the sweet spot.
	_perfect_glow = 1.0
	_hook_glow = maxf(_hook_glow, 0.7)
	eye_widen = 1.8
	_antler_v -= 14.0

func dizzy(duration: float = 2.0) -> void:
	_dizzy = maxf(_dizzy, duration)
	_idle = false

# ------------------------------------------------------------------ drawing --

func _draw() -> void:
	var flip := 1.0

	# swing / flight trail (drawn behind everything, along -x since the stag
	# leans into its motion direction)
	if get_parent() is RigidBody2D:
		var spd: float = (get_parent() as RigidBody2D).linear_velocity.length()
		var tr := clampf((spd - 260.0) / 700.0, 0.0, 1.0)
		for i in 3:
			var f := 1.0 - float(i) / 3.0
			var a := tr * 0.18 * f
			draw_circle(Vector2(-10.0 - i * 9.0, 0), 9.0 * f + 2.0, Color(col_fur_light.r, col_fur_light.g, col_fur_light.b, a))

	# legs (tiny)
	for lx in [-7.0, -2.0, 3.0]:
		draw_line(Vector2(lx, 6), Vector2(lx + 1.5 * flip, 13), col_fur_dark, 3.0)
	# tail fluff
	draw_circle(Vector2(-12, 2), 3.5, col_fur_light)

	_draw_antlers()
	# grab clamp: small pincer in front of the antlers while carrying something
	if _grab_glow > 0.05:
		var ga := Color("#FFF4E0", minf(1.0, _grab_glow))
		var g := Vector2(20, -12)
		draw_line(g, g + Vector2(7, -3), ga, 2.4)
		draw_line(g, g + Vector2(7, 4), ga, 2.4)
	# perfect-release-ready halo (drawn behind the body, in local space)
	if _perfect_ready:
		var pa := Color("#FFF6D8", 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.012))
		draw_arc(Vector2(0, -6), 26.0, 0, TAU, 32, pa, 2.6)
	# perfect-release flash pop
	if _perfect_glow > 0.05:
		var fa := Color("#FFF6D8", _perfect_glow * 0.6)
		draw_arc(Vector2(0, -6), 18.0 + (1.0 - _perfect_glow) * 26.0, 0, TAU, 32, fa, 3.0)
	# body (small)
	draw_set_transform(Vector2(0, 3), 0.0, Vector2(1.15, 0.85) * _body_scale)
	draw_circle(Vector2.ZERO, 9.0, col_fur)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0, 2), 6.5 * _body_scale, col_belly)
	# head (oversized)
	draw_circle(Vector2(5, -6), 12.0 * _body_scale, col_fur)
	# ears
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3, -15), Vector2(1, -20), Vector2(4, -14)]), col_fur_dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, -16), Vector2(13, -20), Vector2(13, -13)]), col_fur)
	# muzzle
	draw_circle(Vector2(15, -3), 5.5 * _body_scale, col_fur_light)
	draw_circle(Vector2(16, -4), 2.0, NOSE)
	# eyes
	_draw_eyes()
	# determined/panicked brows while hooked
	if _hook_glow > 0.15:
		var a := Color(NOSE.r, NOSE.g, NOSE.b, clampf(_hook_glow, 0.0, 1.0))
		draw_line(Vector2(-1, -12), Vector2(4, -10), a, 2.0)
		draw_line(Vector2(11, -10), Vector2(8, -12), a, 2.0)
	# dizzy stars
	if _dizzy > 0.0:
		_draw_dizzy()

func _draw_antlers() -> void:
	var origin := Vector2(2, -15)
	var sway := _antler_x
	var beams := [
		# [start offset, end offset, thickness]
		[Vector2(0, 0), Vector2(-4, -16), 3.4],
		[Vector2(-4, -16), Vector2(-13, -25), 2.6],
		[Vector2(-3, -11), Vector2(-11, -13), 2.2],
		[Vector2(-6, -18), Vector2(-14, -18), 2.0],
		[Vector2(3, -1), Vector2(9, -15), 3.2],
		[Vector2(9, -15), Vector2(19, -22), 2.5],
		[Vector2(10, -10), Vector2(17, -9), 2.1],
		[Vector2(13, -16), Vector2(22, -15), 1.9],
	]
	for b in beams:
		var a: Vector2 = origin + b[0]
		var c: Vector2 = origin + b[1]
		c.x += sway * (absf(b[1].y) / 24.0)
		var col := ANTLER if _hook_glow <= 0.0 else ANTLER.lerp(Color("#FFF6D8"), _hook_glow)
		draw_line(a, c, col, b[2] * _antler_scale)
		draw_circle(c, b[2] * 0.5 * _antler_scale, ANTLER_DARK.lerp(Color("#FFD166"), _hook_glow))
	draw_circle(origin, 3.6 * _antler_scale, ANTLER_DARK.lerp(Color("#FFD166"), _hook_glow))

func _draw_eyes() -> void:
	var eye_y := -7.0
	var openness := clampf(eye_open, 0.08, 1.0)
	for i in 2:
		var ex := 1.5 + i * 6.5
		var r := 4.0 * eye_widen * _eye_scale
		draw_circle(Vector2(ex, eye_y), r, EYE_WHITE)
		if _dizzy > 0.0:
			# spiral-ish dizzy pupil
			var pts := PackedVector2Array()
			for k in 10:
				var t := float(k) / 9.0
				var ang := t * TAU + _spin
				pts.append(Vector2(ex, eye_y) + Vector2(cos(ang), sin(ang)) * (r * 0.5 * t))
			draw_polyline(pts, PUPIL, 1.5)
		else:
			var pupil_r := r * 0.5
			var px := ex + 0.6 + _look * r * 0.6
			draw_circle(Vector2(px, eye_y + 0.4), pupil_r * openness + pupil_r * 0.5, PUPIL)
			draw_circle(Vector2(px + 1.0, eye_y - 1.2), pupil_r * 0.35, EYE_WHITE)
		# upper lid when blinking, plus a permanent half-lidded droop
		var lid := maxf(1.0 - openness, _eyelid)
		if lid > 0.05:
			draw_rect(Rect2(ex - r, eye_y - r, r * 2, r * 2 * lid), col_fur, true)
		# unimpressed flat brow for Bruno
		if _eyelid > 0.2:
			draw_line(Vector2(ex - r, eye_y - r * 0.9), Vector2(ex + r, eye_y - r * 0.9), col_fur_dark, 1.6)

func _draw_dizzy() -> void:
	var a := _spin
	for i in 3:
		var ang := a + float(i) * TAU / 3.0
		var p := Vector2(5 + cos(ang) * 10.0, -22 + sin(ang) * 3.5)
		_draw_star(p, 2.6, Color("#FFD166"))

func _draw_star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var ang := float(i) * TAU / 8.0
		var rad := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, col)
