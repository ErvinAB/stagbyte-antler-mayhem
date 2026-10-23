class_name PhysicsProp
extends RigidBody2D
## One reusable physics prop for the whole sandbox. Original vector art per kind.
##
## Families:
##   DYNAMIC  (crate, barrel, jar, plank, sign, sack, golden, blast, cabinet)
##            normal RigidBody2D, detected through contact_monitor.
##   STATIC   (support, ramp, bounce, spring, bracket)
##            frozen in place (level geometry) and detected through an Area2D
##            trigger where relevant (bounce / spring / support), because
##            static-mode bodies do not reliably report contacts in this build.
##
## Sprint 4 adds two design axes on top of the Sprint 3 kinds:
##   WEIGHT CLASS  (LIGHT / MEDIUM / HEAVY) — how a prop responds to being
##                 grabbed and thrown. Only meaningful for grabbable props.
##   GRAB / RIP    grabbable props can be caught by the antlers; rippable props
##                 (weak joints) build TENSION while pulled and finally snap.
##
## Emits gameplay signals; the ScoreManager decides what is worth points.

signal impacted(energy: float, other: Node)
signal knocked(distance: float)
signal shattered()
signal special_burst(pos: Vector2, radius: float, impulse: float)
signal rope_snapped()
signal ripped()

@export var kind: String = "crate"
@export var size: Vector2 = Vector2(52, 52)

# --- weight classes (grab feel only; not an RPG stat system) ------------------
const WEIGHT_LIGHT := 0
const WEIGHT_MEDIUM := 1
const WEIGHT_HEAVY := 2

@export var grabbable := false
@export var weight_class := WEIGHT_MEDIUM
@export var rippable := false

var rip_release: Node2D = null   # structural piece freed when this rips

const STATIC_KINDS := ["support", "ramp", "bounce", "spring", "bracket"]

const WOOD := Color("#B0703C")
const WOOD_DARK := Color("#7C4A26")
const WOOD_LIGHT := Color("#CE8B4F")
const IRON := Color("#5E3A22")
const GLASS := Color("#BFE3DE")
const ACORN := Color("#D89B4A")
const GOLD := Color("#F2C14E")
const GOLD_DARK := Color("#B8862B")
const GOLD_LIGHT := Color("#FFE7A0")
const MUSH := Color("#E0668A")
const MUSH_LIGHT := Color("#F49BB6")
const MUSH_STEM := Color("#F0E0C8")
const BLAST_RED := Color("#C0392B")
const BLAST_DARK := Color("#7E2318")
const SACK := Color("#C9A15E")
const SACK_DARK := Color("#9C7736")
const STEEL := Color("#8C97A8")
const STEEL_DARK := Color("#5B6472")
const STRAIN := Color("#FF5A3C")
const SPRING := Color("#5AC8E0")
const SPRING_DARK := Color("#2E7F93")
const HANDLE := Color("#FFF4E0")

# --- break / trigger thresholds (energy = relative speed * heavier mass) ------
const JAR_BREAK := 150.0
const SUPPORT_BREAK := 300.0
const ROPE_BREAK := 420.0
const CRATE_BREAK := 420.0
const PLANK_BREAK := 550.0
const BARREL_BREAK := 1500.0
const CABINET_BREAK := 2600.0
const BRACKET_BREAK := 260.0
const GOLDEN_TRIGGER := 200.0
const BLAST_TRIGGER := 220.0

const BOUNCE_SPEED := 1010.0   # fixed launch speed off a bounce pad (deterministic)
const BOUNCE_COOLDOWN_MS := 220
const SPRING_BOOST := 560.0    # extra speed added along a springboard normal
const SPRING_RESTITUTION := 0.9
const SPRING_COOLDOWN_MS := 220

const RIP_FILL_SPEED := 430.0  # pull speed that fills rip tension in ~1s

var _spawn_pos: Vector2
var _damage := 0.0
var _knocked := false
var _rattle := 0.0
var _bounce_squash := 0.0
var _bounce_cd := {}   # body -> last bounce tick
var _spring_cd := {}

# Optional rope-like tether. See stag.gd for why it is solved directly.
var tether_node: Node2D = null
var tether_len := 0.0
var tether_offset := Vector2.ZERO
var rope_breakable := false

# --- grab / rip state --------------------------------------------------------
var grab_glow := 0.0     # contextual highlight (0..1), set by Main
var _grabbed := false
var _tension := 0.0      # 0..1 rip strain

func set_tether(anchor: Node2D, length: float, offset: Vector2 = Vector2.ZERO, breakable: bool = false) -> void:
	tether_node = anchor
	tether_len = length
	tether_offset = offset
	rope_breakable = breakable
	linear_damp = 0.05
	angular_damp = 0.35

func _ready() -> void:
	_spawn_pos = global_position
	add_to_group("bodies")
	add_to_group("props")
	_configure_kind()
	_build_shape()
	if kind in STATIC_KINDS:
		_setup_static()
	else:
		_setup_dynamic()

func _configure_kind() -> void:
	match kind:
		"barrel":
			grabbable = true
			weight_class = WEIGHT_MEDIUM
		"sack":
			grabbable = true
			weight_class = WEIGHT_LIGHT
		"plank":
			grabbable = true
			weight_class = WEIGHT_LIGHT
		"jar":
			grabbable = true
			weight_class = WEIGHT_LIGHT
		"bracket":
			grabbable = true
			weight_class = WEIGHT_LIGHT
			rippable = true
		"crate":
			weight_class = WEIGHT_MEDIUM
		"cabinet":
			weight_class = WEIGHT_HEAVY
		"bounce", "spring", "ramp", "support":
			weight_class = WEIGHT_HEAVY
		_:
			pass

func _setup_dynamic() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)
	var mat := PhysicsMaterial.new()
	mat.friction = 0.75
	mat.bounce = 0.06
	physics_material_override = mat
	match kind:
		"barrel":
			mat.friction = 0.12
			mat.bounce = 0.04
			linear_damp = 0.05
			angular_damp = 0.04
		"golden", "blast", "sack":
			angular_damp = 0.5
			linear_damp = 0.12
		"cabinet":
			angular_damp = 0.9
			linear_damp = 0.2
			mat.friction = 0.9
		_:
			angular_damp = 0.6
			linear_damp = 0.15

func _setup_static() -> void:
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	contact_monitor = false
	var mat := PhysicsMaterial.new()
	mat.friction = 0.9
	mat.bounce = 0.0
	if kind == "bounce" or kind == "spring":
		mat.friction = 0.2
	physics_material_override = mat
	if kind == "support" or kind == "bounce" or kind == "spring":
		_add_trigger()

func _add_trigger() -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.monitorable = false
	var cs := CollisionShape2D.new()
	cs.shape = _make_shape()
	area.add_child(cs)
	area.body_entered.connect(_on_body_entered)
	add_child(area)

func _make_shape() -> Shape2D:
	match kind:
		"barrel", "jar", "bounce":
			var circ := CircleShape2D.new()
			circ.radius = size.x * 0.5
			return circ
		_:
			var rect := RectangleShape2D.new()
			rect.size = size
			return rect

func _build_shape() -> void:
	var col := CollisionShape2D.new()
	col.shape = _make_shape()
	add_child(col)
	if kind in STATIC_KINDS:
		return
	match kind:
		"barrel":
			mass = 2.6
		"jar":
			mass = 0.35
		"plank":
			mass = 0.8
		"golden", "blast":
			mass = 0.9
		"sack":
			mass = 1.1
		"cabinet":
			mass = 6.0
		_:
			mass = 1.0

func _physics_process(delta: float) -> void:
	if grab_glow > 0.0:
		grab_glow = maxf(0.0, grab_glow - delta * 1.8)
		queue_redraw()
	if _bounce_squash > 0.0:
		_bounce_squash = maxf(0.0, _bounce_squash - delta * 4.0)
		queue_redraw()
	elif _rattle > 0.0:
		_rattle = maxf(0.0, _rattle - delta * 3.0)
		queue_redraw()
	elif kind == "golden" or kind == "blast" or _tension > 0.0:
		queue_redraw()
	if rippable and not _grabbed and _tension > 0.0:
		# strain bleeds off when nobody is pulling
		_tension = maxf(0.0, _tension - delta * 0.9)
		queue_redraw()
	if kind in STATIC_KINDS:
		return
	if not _knocked and global_position.distance_to(_spawn_pos) > 42.0:
		_knocked = true
		emit_signal("knocked", global_position.distance_to(_spawn_pos))
	# physics safety: never let a prop become a bullet
	var v := linear_velocity
	if v.length() > 2600.0:
		linear_velocity = v.normalized() * 2600.0

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if tether_node == null or not is_instance_valid(tether_node):
		return
	var pivot: Vector2 = tether_node.global_position
	var r: Vector2 = tether_offset.rotated(state.transform.get_rotation())
	var point: Vector2 = state.transform.origin + r
	var d: Vector2 = point - pivot
	var length: float = d.length()
	if length < 0.001:
		return
	var dir: Vector2 = d / length
	state.transform.origin -= dir * (length - tether_len)
	var v_point: Vector2 = state.linear_velocity + Vector2(-r.y, r.x) * state.angular_velocity
	state.linear_velocity -= dir * v_point.dot(dir)

func _on_body_entered(body: Node) -> void:
	if body == self:
		return
	if not (body is RigidBody2D):
		return
	var other: RigidBody2D = body
	var rel := (linear_velocity - other.linear_velocity).length()
	var m: float = maxf(mass, other.mass)
	var energy := rel * m

	if kind == "bounce":
		_do_bounce(other)
		return
	if kind == "spring":
		_do_spring(other)
		return

	_damage = clampf(_damage + energy / 900.0, 0.0, 1.0)
	_rattle = 1.0
	if energy > 120.0:
		emit_signal("impacted", energy, body)

	if tether_node != null and rope_breakable and energy > ROPE_BREAK:
		_snap_rope()
		return

	match kind:
		"jar":
			if energy > JAR_BREAK:
				emit_signal("shattered")
				_break()
		"support":
			if energy > SUPPORT_BREAK:
				emit_signal("shattered")
				_break()
		"plank":
			if energy > PLANK_BREAK:
				emit_signal("shattered")
				_break()
		"crate":
			if energy > CRATE_BREAK:
				emit_signal("shattered")
				_break()
		"barrel":
			if energy > BARREL_BREAK:
				emit_signal("shattered")
				_break()
		"cabinet":
			if energy > CABINET_BREAK:
				emit_signal("shattered")
				_break()
		"bracket":
			# a weak joint can also be knocked loose by a hard impact
			if energy > BRACKET_BREAK:
				_rip()
		"golden":
			if energy > GOLDEN_TRIGGER:
				emit_signal("special_burst", global_position, 230.0, 620.0)
				_break()
		"blast":
			if energy > BLAST_TRIGGER:
				emit_signal("special_burst", global_position, 280.0, 980.0)
				_break()

func _do_bounce(body: RigidBody2D) -> void:
	var now := Time.get_ticks_msec()
	var id := body.get_instance_id()
	if _bounce_cd.has(id) and now - int(_bounce_cd[id]) < BOUNCE_COOLDOWN_MS:
		return
	_bounce_cd[id] = now
	var n := Vector2.UP.rotated(global_rotation)
	var v := body.linear_velocity
	var vn := v.dot(n)
	var vt := v - n * vn
	# Set velocity directly so the bounce is frame-exact and deterministic.
	body.linear_velocity = vt * 0.82 + n * BOUNCE_SPEED
	_bounce_squash = 1.0
	if has_node("/root/Sfx"):
		Sfx.play("bounce", randf_range(0.96, 1.06), -5.0)
	emit_signal("impacted", BOUNCE_SPEED, body)

func _do_spring(body: RigidBody2D) -> void:
	var now := Time.get_ticks_msec()
	var id := body.get_instance_id()
	if _spring_cd.has(id) and now - int(_spring_cd[id]) < SPRING_COOLDOWN_MS:
		return
	_spring_cd[id] = now
	# A springboard REFLECTS the incoming velocity across its surface normal and
	# adds a fixed boost along the normal. Because the board is angled, the
	# redirect is mostly sideways — deliberately different from the mushroom.
	var n := Vector2.UP.rotated(global_rotation)
	var v := body.linear_velocity
	var vn := v.dot(n)
	var vt := v - n * vn
	var out_n := maxf(absf(vn) * SPRING_RESTITUTION, 0.0) + SPRING_BOOST
	body.linear_velocity = vt * 0.92 + n * out_n
	_bounce_squash = 1.0
	if has_node("/root/Sfx"):
		Sfx.play("bounce", randf_range(1.05, 1.18), -4.0)
	emit_signal("impacted", SPRING_BOOST, body)

func _snap_rope() -> void:
	tether_node = null
	rope_breakable = false
	angular_damp = 0.6
	linear_damp = 0.15
	emit_signal("rope_snapped")

func is_special() -> bool:
	return kind == "golden" or kind == "blast"

func is_grabbable() -> bool:
	return grabbable and kind in ["barrel", "sack", "plank", "jar", "bracket"]

func set_grabbed(v: bool) -> void:
	_grabbed = v

func set_grab_highlight(v: bool) -> void:
	if v:
		grab_glow = 1.0

func get_tension() -> float:
	return _tension

# --- rip / tension -----------------------------------------------------------

func add_tension(amount: float) -> void:
	if not rippable:
		return
	_tension = clampf(_tension + amount, 0.0, 1.0)
	queue_redraw()
	if _tension >= 1.0:
		_rip()

func _rip() -> void:
	if not rippable:
		return
	rippable = false
	emit_signal("ripped")
	if rip_release and is_instance_valid(rip_release) and rip_release.has_method("release_from_structure"):
		rip_release.call("release_from_structure")
	_break()

func release_from_structure() -> void:
	# A frozen structural piece becomes a normal dynamic prop.
	if not freeze and kind not in STATIC_KINDS:
		return
	freeze = false
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	if kind in STATIC_KINDS:
		if mass < 1.5:
			mass = 2.6
		contact_monitor = true
		max_contacts_reported = 8
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		if physics_material_override == null:
			var mat := PhysicsMaterial.new()
			mat.friction = 0.7
			physics_material_override = mat
	_knocked = true
	emit_signal("knocked", 999.0)

func _break() -> void:
	set_physics_process(false)
	queue_free()

func is_knocked() -> bool:
	return _knocked

# ------------------------------------------------------------------ drawing --

func _draw() -> void:
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _rattle * 1.2
	match kind:
		"barrel":
			_draw_barrel(shake)
		"jar":
			_draw_jar(shake)
		"plank":
			_draw_plank(shake)
		"sign":
			_draw_sign(shake)
		"golden":
			_draw_golden(shake)
		"support":
			_draw_support()
		"ramp":
			_draw_ramp()
		"bounce":
			_draw_bounce()
		"spring":
			_draw_spring()
		"blast":
			_draw_blast(shake)
		"sack":
			_draw_sack(shake)
		"cabinet":
			_draw_cabinet(shake)
		"bracket":
			_draw_bracket()
		_:
			_draw_crate(shake)
	if is_grabbable():
		_draw_handle()

func _draw_handle() -> void:
	# A small antler-shaped nub so the player can read "this can be grabbed".
	var h := size * 0.5
	var c := Vector2(0, -h.y - 6.0)
	var a := Color(HANDLE.r, HANDLE.g, HANDLE.b, 0.55 + grab_glow * 0.45)
	var w := 2.2 + grab_glow * 1.4
	draw_line(c + Vector2(-4, 4), c + Vector2(-4, -4), a, w)
	draw_line(c + Vector2(-4, -4), c + Vector2(-8, -8), a, w)
	draw_line(c + Vector2(-4, -4), c + Vector2(0, -9), a, w)
	draw_line(c + Vector2(4, 4), c + Vector2(4, -4), a, w)
	draw_line(c + Vector2(4, -4), c + Vector2(0, -9), a, w)
	draw_line(c + Vector2(4, -4), c + Vector2(8, -8), a, w)
	if grab_glow > 0.02:
		var g := Color(HANDLE.r, HANDLE.g, HANDLE.b, 0.22 * grab_glow)
		draw_circle(c, 16.0 + grab_glow * 6.0, g)

func _draw_crate(o: Vector2) -> void:
	var h := size * 0.5
	var r := Rect2(-h + o, size)
	draw_rect(r, WOOD)
	draw_rect(r, WOOD_DARK, false, 3.0)
	draw_line(r.position, r.end, WOOD_DARK, 2.0)
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), WOOD_DARK, 2.0)
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(size.x - 4, 5)), WOOD_LIGHT)
	_draw_damage(o, h)

func _draw_barrel(o: Vector2) -> void:
	var rad := size.x * 0.5
	draw_circle(o, rad, WOOD)
	draw_circle(o, rad * 0.82, WOOD_LIGHT)
	for i in 4:
		var a := float(i) * PI / 4.0
		draw_line(o + Vector2(cos(a), sin(a)) * rad * 0.3, o + Vector2(cos(a), sin(a)) * rad * 0.9, WOOD_DARK, 2.0)
	draw_arc(o, rad * 0.95, 0, TAU, 28, IRON, 3.5)
	draw_arc(o, rad, 0, TAU, 28, WOOD_DARK, 2.5)

func _draw_jar(o: Vector2) -> void:
	var rad := size.x * 0.5
	draw_circle(o, rad, GLASS)
	draw_circle(o + Vector2(-rad * 0.3, rad * 0.3), rad * 0.55, Color(1, 1, 1, 0.35))
	draw_circle(o + Vector2(rad * 0.35, 0.0), rad * 0.35, ACORN)
	draw_circle(o + Vector2(-rad * 0.25, -rad * 0.35), rad * 0.3, ACORN)
	draw_arc(o, rad, 0, TAU, 24, WOOD_DARK, 2.5)
	draw_rect(Rect2(o + Vector2(-rad, -rad - 5), Vector2(rad * 2, 6)), IRON)

func _draw_plank(o: Vector2) -> void:
	var h := size * 0.5
	var rect := Rect2(-h + o, size)
	draw_rect(rect, WOOD_LIGHT)
	draw_rect(rect, WOOD_DARK, false, 2.5)
	for i in 4:
		var x := rect.position.x + size.x * (0.2 + i * 0.2)
		draw_line(Vector2(x, rect.position.y + 2), Vector2(x + 6, rect.end.y - 2), WOOD, 1.5)
	_draw_damage(o, h)

func _draw_ramp() -> void:
	var h := size * 0.5
	var rect := Rect2(-h, size)
	draw_rect(rect, WOOD)
	draw_rect(rect, WOOD_DARK, false, 3.0)
	for i in 5:
		var x := rect.position.x + size.x * (0.15 + i * 0.18)
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), WOOD_LIGHT, 2.0)

func _draw_support() -> void:
	var h := size * 0.5
	var rect := Rect2(-h, size)
	draw_rect(rect, WOOD_DARK)
	draw_rect(rect, WOOD, true)
	draw_line(Vector2(-h.x, h.y), Vector2(h.x, -h.y), WOOD_LIGHT, 3.0)
	draw_line(Vector2(-h.x, -h.y * 0.4), Vector2(h.x, h.y * 0.4), WOOD_LIGHT, 2.0)
	draw_rect(rect, Color("#3A2413"), false, 2.0)

func _draw_bounce() -> void:
	var rad := size.x * 0.5
	var sq := _bounce_squash
	var cap_scale := Vector2(1.0 + sq * 0.25, 1.0 - sq * 0.3)
	draw_rect(Rect2(Vector2(-rad * 0.28, 2), Vector2(rad * 0.56, rad * 0.9)), MUSH_STEM)
	draw_set_transform(Vector2(0, -rad * 0.15), 0.0, cap_scale)
	draw_circle(Vector2.ZERO, rad, MUSH)
	draw_circle(Vector2(0, -rad * 0.15), rad * 0.7, MUSH_LIGHT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for sp in [Vector2(-rad * 0.4, -rad * 0.3), Vector2(rad * 0.35, -rad * 0.45), Vector2(0.0, -rad * 0.05)]:
		draw_circle(sp, rad * 0.14, Color(1, 1, 1, 0.85))
	draw_arc(Vector2(0, -rad * 0.15), rad, 0, TAU, 28, MUSH_STEM, 3.0)
	_draw_handle()

func _draw_spring() -> void:
	# An angled springboard: a board over a steel coil. Reads "springy" and,
	# because it is tilted, redirects more sideways than the mushroom.
	var h := size * 0.5
	var sq := _bounce_squash
	var board := Rect2(Vector2(-h.x, -h.y - sq * 3.0), Vector2(size.x, 9.0))
	draw_rect(board, SPRING)
	draw_rect(board, SPRING_DARK, false, 2.0)
	draw_rect(Rect2(board.position + Vector2(3, 1), Vector2(size.x - 6, 2)), Color(1, 1, 1, 0.5))
	# coil
	var top := board.end.y
	var bot := h.y
	var zig := 4
	for i in zig:
		var y0 := lerpf(top, bot, float(i) / zig)
		var y1 := lerpf(top, bot, float(i + 1) / zig)
		var x0 := -10.0 if i % 2 == 0 else 10.0
		var x1 := 10.0 if i % 2 == 0 else -10.0
		draw_line(Vector2(x0, y0), Vector2(x1, y1), STEEL_DARK, 2.4)
	draw_line(Vector2(-h.x * 0.8, bot), Vector2(h.x * 0.8, bot), STEEL, 3.0)
	# direction chevrons along the normal
	var n := Vector2.UP
	draw_line(n * 6.0, n * 18.0, Color(SPRING.r, SPRING.g, SPRING.b, 0.8), 2.4)
	draw_line(n * 18.0, n * 18.0 + Vector2(-5, 5), Color(SPRING.r, SPRING.g, SPRING.b, 0.8), 2.4)
	draw_line(n * 18.0, n * 18.0 + Vector2(5, 5), Color(SPRING.r, SPRING.g, SPRING.b, 0.8), 2.4)

func _draw_blast(o: Vector2) -> void:
	var h := size * 0.5
	var r := Rect2(-h + o, size)
	draw_rect(r, BLAST_RED)
	draw_rect(r, BLAST_DARK, false, 3.0)
	draw_line(r.position, r.end, BLAST_DARK, 2.0)
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), BLAST_DARK, 2.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	var c := o
	draw_circle(c, h.x * (0.34 + pulse * 0.06), Color("#FFD166"))
	draw_circle(c, h.x * 0.22, ACORN)
	for i in 6:
		var a := float(i) * TAU / 6.0 + Time.get_ticks_msec() * 0.001
		draw_line(c + Vector2(cos(a), sin(a)) * h.x * 0.4, c + Vector2(cos(a), sin(a)) * h.x * (0.5 + pulse * 0.08), GOLD_LIGHT, 2.0)
	_draw_damage(o, h)

func _draw_sack(o: Vector2) -> void:
	var h := size * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(-h.x, h.y), Vector2(h.x, h.y),
		Vector2(h.x * 0.9, -h.y * 0.4), Vector2(h.x * 0.4, -h.y),
		Vector2(-h.x * 0.4, -h.y), Vector2(-h.x * 0.9, -h.y * 0.4)]), SACK)
	draw_arc(o, h.x * 1.1, -PI * 0.15, PI * 1.15, 18, SACK_DARK, 2.5)
	draw_circle(Vector2(0, -h.y * 0.9), 4.0, ACORN)
	draw_line(Vector2(-4, -h.y * 0.9 - 3), Vector2(4, -h.y * 0.9 - 3), IRON, 2.0)

func _draw_sign(o: Vector2) -> void:
	var h := size * 0.5
	var rect := Rect2(-h + o, size)
	draw_rect(rect, WOOD)
	draw_rect(rect, IRON, false, 4.0)
	draw_line(Vector2(rect.position.x + 6, rect.position.y + 6), Vector2(rect.end.x - 6, rect.position.y + 6), WOOD_LIGHT, 3.0)
	var font := ThemeDB.fallback_font
	var txt := "MAYHEM"
	var ts := 20
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
	draw_string(font, Vector2(-w * 0.5, 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color("#FFF4E0"))
	_draw_damage(o, h)

func _draw_golden(o: Vector2) -> void:
	var h := size * 0.5
	var r := Rect2(-h + o, size)
	draw_rect(r, GOLD)
	draw_rect(r, GOLD_DARK, false, 3.0)
	var c := o + Vector2(0, 2)
	draw_circle(c, h.x * 0.42, GOLD_LIGHT)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-h.x * 0.42, -h.x * 0.1),
		c + Vector2(h.x * 0.42, -h.x * 0.1),
		c + Vector2(h.x * 0.34, -h.x * 0.4),
		c + Vector2(-h.x * 0.34, -h.x * 0.4)]), GOLD_DARK)
	draw_line(c + Vector2(0, -h.x * 0.42), c + Vector2(0, -h.x * 0.62), GOLD_DARK, 2.0)
	var tw := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	_draw_plus(o + Vector2(h.x * 0.62, -h.y * 0.62), 4.0 + tw * 2.0, GOLD_LIGHT)
	_draw_damage(o, h)

func _draw_cabinet(o: Vector2) -> void:
	var h := size * 0.5
	var r := Rect2(-h + o, size)
	draw_rect(r, WOOD_DARK)
	draw_rect(r, WOOD, true)
	draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(size.x - 8, size.y - 8)), WOOD_LIGHT, false, 2.0)
	draw_line(Vector2(o.x, r.position.y + 4), Vector2(o.x, r.end.y - 4), WOOD_DARK, 3.0)
	draw_circle(Vector2(o.x - 6, o.y), 2.6, IRON)
	draw_circle(Vector2(o.x + 6, o.y), 2.6, IRON)
	# "HEAVY" hint: a small weight stamp
	draw_line(o + Vector2(-6, -h.y + 12), o + Vector2(6, -h.y + 12), STEEL, 3.0)
	_draw_damage(o, h)

func _draw_bracket() -> void:
	# A weak joint. Shifts toward red and cracks as tension builds.
	var h := size * 0.5
	var t := _tension
	var body := WOOD_LIGHT.lerp(STRAIN, t)
	var rect := Rect2(-h, size)
	draw_rect(rect, body)
	draw_rect(rect, WOOD_DARK, false, 2.0)
	draw_line(Vector2(-h.x, 0), Vector2(h.x, 0), WOOD_DARK, 2.0)
	# cracks grow with tension
	if t > 0.15:
		var crack := Color(0.2, 0.08, 0.04, minf(0.9, t + 0.15))
		draw_line(Vector2(-h.x * 0.4, -h.y * 0.6), Vector2(h.x * 0.1, h.y * 0.1), crack, 2.0)
		draw_line(Vector2(h.x * 0.1, h.y * 0.1), Vector2(-h.x * 0.1, h.y * 0.7), crack, 2.0)
	if t > 0.55:
		draw_line(Vector2(h.x * 0.3, -h.y * 0.7), Vector2(h.x * 0.6, h.y * 0.2), Color(0.2, 0.08, 0.04, 0.9), 2.0)
	# strain halo
	if t > 0.05:
		var a := Color(STRAIN.r, STRAIN.g, STRAIN.b, 0.25 * t)
		draw_arc(Vector2.ZERO, h.x + 8.0, 0, TAU, 24, a, 2.0)
	# mounting plate
	draw_rect(Rect2(Vector2(-h.x - 3, -4), Vector2(5, 8)), IRON)
	draw_rect(Rect2(Vector2(h.x - 2, -4), Vector2(5, 8)), IRON)

func _draw_plus(c: Vector2, s: float, col: Color) -> void:
	draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), col, 2.0)
	draw_line(c + Vector2(0, -s), c + Vector2(0, s), col, 2.0)

func _draw_damage(o: Vector2, h: Vector2) -> void:
	if _damage < 0.35:
		return
	var col := Color(0.25, 0.12, 0.06, 0.8)
	var c := o
	draw_line(c + Vector2(-h.x * 0.6, -h.y * 0.4), c + Vector2(-h.x * 0.1, 0.0), col, 2.0)
	draw_line(c + Vector2(-h.x * 0.1, 0.0), c + Vector2(-h.x * 0.35, h.y * 0.5), col, 2.0)
	if _damage > 0.7:
		draw_line(c + Vector2(h.x * 0.5, -h.y * 0.5), c + Vector2(h.x * 0.5, h.y * 0.1), col, 2.0)
		draw_line(c + Vector2(h.x * 0.5, h.y * 0.1), c + Vector2(h.x * 0.1, h.y * 0.1), col, 2.0)
