extends Node2D
## ANTLER MAYHEM — the level runner.
##
## One engine, many levels. The level's SHAPE comes from Levels (level_data.gd):
## anchors, props, hanging objects, rip joints, target, optional objectives.
## This script owns the attempt state machine, objectives, trick-shot scoring,
## and the wiring between input, stag, scoring, HUD and the App shell.
##
## Core loop: AIM -> LAUNCH -> HOOK / GRAB -> SWING / CARRY -> RELEASE / THROW
## -> SMASH -> CHAIN -> SCORE, repeated across THREE stags. The environment
## PERSISTS between stags; only Retry Level (or the end of all three) rebuilds.

const STAG_SCENE := preload("res://scenes/stag/stag.tscn")
const PROP_SCENE := preload("res://scenes/objects/physics_object.tscn")
const ANCHOR_SCENE := preload("res://scenes/environment/hook_anchor.tscn")

const GRAVITY := 980.0 * 0.95
const HOOK_ENERGY := 120.0
const STRONG_ENERGY := 380.0
const HOOK_RANGE := 130.0
const RESPAWN_DELAY := 0.55

enum State { AIM, AIRBORNE, SETTLED, RESULTS }

const PROP_SIZE := {
	"crate": Vector2(52, 52),
	"barrel": Vector2(48, 48),
	"jar": Vector2(26, 26),
	"plank": Vector2(200, 16),
	"sign": Vector2(96, 52),
	"golden": Vector2(52, 52),
	"support": Vector2(22, 64),
	"ramp": Vector2(140, 16),
	"bounce": Vector2(72, 72),
	"spring": Vector2(96, 40),
	"bracket": Vector2(30, 46),
	"cabinet": Vector2(70, 84),
	"blast": Vector2(54, 54),
	"sack": Vector2(44, 48),
}

# trick-shot windows (seconds)
const BOUNCE_WINDOW := 1.6
const ASSIST_WINDOW := 1.8
const THROWN_WINDOW := 4.0

const OBJECTIVE_BANNERS := {
	"perfect": "PERFECT RELEASE!",
	"grab": "ANTLER GRAB!",
	"throw": "CLEAN THROW!",
	"barrel": "BARREL CHAIN!",
	"rip": "RIP IT!",
	"double": "DOUBLE HOOK!",
}
const OBJECTIVE_COLORS := {
	"perfect": Color("#7FE0C4"),
	"grab": Color("#FFF4E0"),
	"throw": Color("#FFD166"),
	"barrel": Color("#FFB48A"),
	"rip": Color("#FF5A3C"),
	"double": Color("#FFD166"),
}

@onready var world: Node2D = $World
@onready var aim: AimController = $World/Aim
@onready var background: Node2D = $World/Background
@onready var anchors_root: Node2D = $World/Anchors
@onready var hanging_root: Node2D = $World/Hanging
@onready var props_root: Node2D = $World/Props
@onready var camera: Camera2D = $Camera2D
@onready var fx: Fx = $Effects
@onready var pointer: PointerInput = $PointerInput
@onready var debug: DebugOverlay = $DebugOverlay
@onready var score: ScoreManager = $ScoreManager
@onready var hud: Hud = $HUD

## Set by the App shell before the node enters the tree. Standalone runs
## (tools/drive_test) simply use the default.
var level_id := "cabin_1"
var level: Dictionary = {}
var level_target := 5000
var stags_total := 3

var state: State = State.AIM
var stag: Stag
var anchors: Array = []
var props: Array = []
var spent_stags: Array = []
var stags_left := 3

## Generic optional-objective state: objective_id -> completed.
var obj_state := {}

var obj_perfect: bool:
	get: return bool(obj_state.get("perfect", false))
	set(v): obj_state["perfect"] = v
var obj_grab: bool:
	get: return bool(obj_state.get("grab", false))
	set(v): obj_state["grab"] = v

var _settle_pulse := 0.0
var _respawn_timer := 0.0
var _current_hint := ""
var _last_stage := 0

# per-launch trick-shot state
var _hooks_this_launch := 0
var _assist_awarded := false
var _assist_marks := {}
var _bounce_time := -99999
var _bounce_awarded := false
var _chain_awarded := false
var _thrown_props := {}

func _ready() -> void:
	Engine.time_scale = 1.0
	randomize()
	level = Levels.get_level(level_id)
	level_target = int(level.get("target", 5000))
	stags_total = int(level.get("stags", 3))
	obj_state = {}
	for id in Levels.optional_ids(level):
		obj_state[id] = false
	if background and background.has_method("set_level"):
		background.call("set_level", level_id, str(level.get("theme", "workshop")))
	_setup_score()
	_build_level()
	_setup_input()
	_setup_hud()
	debug.anchors = anchors
	debug.aim = aim
	debug.main = self
	_spawn_stag()
	stags_left = stags_total
	hud.set_stags(stags_left, stags_total)
	hud.set_objectives_state(obj_state)
	_set_hint("launch", str(level.get("hint", "DRAG BACK TO AIM  →  RELEASE TO LAUNCH")))
	hud.show_intro()

# ------------------------------------------------------------------ building --

func _build_level() -> void:
	for p in (level.get("anchors", []) as Array):
		var a: StaticBody2D = ANCHOR_SCENE.instantiate()
		a.position = p
		anchors_root.add_child(a)
		anchors.append(a)
	for h in (level.get("hanging", []) as Array):
		_build_hanging(h)
	for entry in (level.get("props", []) as Array):
		var nm := str(entry[3]) if entry.size() > 3 else ""
		_make_prop(str(entry[0]), entry[1], float(entry[2]), nm)
	_link_rip_joints()

func _build_hanging(h: Array) -> void:
	var kind := str(h[0])
	var pos: Vector2 = h[1]
	var pivot_pos: Vector2 = h[2]
	var offset: Vector2 = h[3]
	var breakable := bool(h[4]) if h.size() > 4 else true
	var size_override = h[5] if h.size() > 5 else null
	var pivot := _make_pivot(pivot_pos, "%sPivot" % kind.capitalize())
	var prop := _make_prop(kind, pos, 0.0, "", size_override)
	if kind == "sign":
		prop.name = "HangingSign"
	elif kind == "sack":
		prop.name = "HangingSack"
	prop.set_tether(pivot, (pos + offset).distance_to(pivot_pos), offset, breakable)

func _make_pivot(pos: Vector2, name_: String) -> StaticBody2D:
	var pivot := StaticBody2D.new()
	pivot.name = name_
	pivot.position = pos
	pivot.collision_layer = 0
	pivot.collision_mask = 0
	hanging_root.add_child(pivot)
	return pivot

func _link_rip_joints() -> void:
	## A rippable prop names the structural piece it frees when it tears loose.
	for link in (level.get("rip_links", []) as Array):
		var from_name := str(link[0])
		var to_name := str(link[1])
		var a := _find_prop(from_name)
		var b := _find_prop(to_name)
		if a and b:
			a.rip_release = b

func _find_prop(prop_name: String) -> PhysicsProp:
	for p in props:
		if is_instance_valid(p) and p.name == prop_name:
			return p
	return null

func _make_prop(kind: String, pos: Vector2, rot: float, prop_name: String = "", size_override = null) -> PhysicsProp:
	var p: PhysicsProp = PROP_SCENE.instantiate()
	p.kind = kind
	p.size = size_override if size_override != null else PROP_SIZE[kind]
	p.position = pos
	p.rotation = rot
	if prop_name != "":
		p.name = prop_name
	props_root.add_child(p)
	p.impacted.connect(_on_prop_impacted.bind(p))
	p.knocked.connect(_on_prop_knocked.bind(p))
	p.shattered.connect(_on_prop_shattered.bind(p))
	p.special_burst.connect(_on_prop_special_burst.bind(p))
	p.rope_snapped.connect(_on_prop_rope_snapped.bind(p))
	p.ripped.connect(_on_prop_ripped.bind(p))
	props.append(p)
	return p

func _spawn_stag() -> void:
	stag = STAG_SCENE.instantiate()
	stag.character = Progress.selected_character
	stag.position = level.get("spawn", Vector2(135, 599))
	world.add_child(stag)
	stag.store_spawn()
	stag.freeze = true
	stag.airborne = false
	stag.launched.connect(_on_stag_launched)
	stag.hook_attached.connect(_on_stag_hooked)
	stag.hook_released.connect(_on_stag_released)
	stag.perfect_released.connect(_on_stag_perfect)
	stag.grabbed.connect(_on_stag_grabbed)
	stag.released_grab.connect(_on_stag_released_grab)
	stag.impacted.connect(_on_stag_impacted.bind(stag))
	stag.landed_hard.connect(_on_stag_landed_hard.bind(stag))
	aim.setup(stag, GRAVITY)
	debug.stag = stag

func _setup_hud() -> void:
	hud.configure_level(level)
	hud.retry_pressed.connect(_retry_level)
	hud.continue_pressed.connect(_continue)

func _setup_score() -> void:
	score.score_changed.connect(_on_score_changed)
	score.combo_changed.connect(_on_combo_changed)
	score.mayhem_changed.connect(_on_mayhem_changed)
	score.popup_requested.connect(_on_popup)
	score.banner_requested.connect(_on_banner)
	score.punch_requested.connect(_on_punch)
	_on_score_changed(0)
	_on_combo_changed(1)

func _setup_input() -> void:
	pointer.pointer_pressed.connect(_on_pointer_pressed)
	pointer.pointer_moved.connect(_on_pointer_moved)
	pointer.pointer_released.connect(_on_pointer_released)

# ------------------------------------------------------------------- input ---

func _on_pointer_pressed(pos: Vector2) -> void:
	if hud.is_over_ui(pos):
		return
	if state == State.AIM and hud.is_intro_visible():
		hud.hide_intro()   # "tap to begin" cuts the intro short
	match state:
		State.AIM:
			aim.begin(pos)
		State.AIRBORNE:
			if stag.hooked or stag.grabbing:
				return
			# One press resolves to EITHER a hook or a grab, whichever
			# interactable is closest (anchors get a small assist bias).
			var anchor: Node2D = stag.nearest_anchor(anchors, pos)
			var grab: PhysicsProp = stag.nearest_grabbable(props, pos)
			var da := 1.0e9
			var dg := 1.0e9
			if anchor:
				da = stag.global_position.distance_to(anchor.global_position)
			if grab:
				dg = stag.global_position.distance_to(grab.global_position)
			if anchor and da <= dg + 20.0:
				stag.hook(anchor)
			elif grab:
				stag.grab(grab)
		State.SETTLED:
			_respawn_timer = minf(_respawn_timer, 0.0)   # allow skipping the wait
		_:
			pass

func _on_pointer_moved(pos: Vector2) -> void:
	if state == State.AIM and aim.aiming:
		aim.update(pos)

func _on_pointer_released(pos: Vector2) -> void:
	if hud.is_over_ui(pos):
		return
	match state:
		State.AIM:
			if not aim.aiming:
				return
			var result := aim.commit()
			if result.power <= 0.0:
				_set_hint("launch", "PULL FARTHER FOR POWER")
				return
			state = State.AIRBORNE
			stag.launch(result.dir, result.impulse)
		State.AIRBORNE:
			if stag.hooked:
				stag.unhook()
			elif stag.grabbing:
				stag.release_grab(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_retry_level()

# ------------------------------------------------------------------ process --

func _process(delta: float) -> void:
	if stag == null or not is_instance_valid(stag):
		return
	# anchor + grab assists (only for the current, free stag)
	var free := state == State.AIRBORNE and not stag.hooked and not stag.grabbing
	var hover: PhysicsProp = stag.nearest_grabbable(props, stag.global_position) if free else null
	for a in anchors:
		if is_instance_valid(a):
			var d: float = stag.global_position.distance_to(a.global_position)
			a.set_highlight(free and d <= stag.HOOK_RADIUS)
			a.range_hint = 1.0 if (free and d <= HOOK_RANGE * 1.6) else 0.0
	for p in props:
		if is_instance_valid(p):
			p.set_grab_highlight(p == hover)
	# contextual onboarding
	if free and not Progress.hooked_once and not Progress.grabbed_once:
		var near := false
		for a in anchors:
			if is_instance_valid(a) and stag.global_position.distance_to(a.global_position) <= stag.HOOK_RADIUS + 40.0:
				near = true
				break
		if near or hover:
			_set_hint("hook", "HOLD NEAR A RING  →  HOOK   ·   NEAR AN OBJECT  →  GRAB")
		elif _current_hint == "hook":
			_set_hint("", "")
	# camera shake
	camera.offset = fx.shake_offset()
	if state == State.SETTLED or state == State.RESULTS:
		_settle_pulse = fmod(_settle_pulse + delta, 1.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if state == State.AIRBORNE and stag.is_resting():
		state = State.SETTLED
		_respawn_timer = RESPAWN_DELAY
		if stags_left > 1:
			_set_hint("next", "NEXT STAG  →")
		else:
			_set_hint("", "")
	elif state == State.SETTLED:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_advance_stag()

# --------------------------------------------------------------- stag flow ---

func _advance_stag() -> void:
	if state != State.SETTLED:
		return
	stags_left -= 1
	hud.set_stags(stags_left, stags_total)
	# The spent stag STAYS in the world as a passive physics obstacle.
	if stag and is_instance_valid(stag):
		stag.make_passive()
		spent_stags.append(stag)
	if stags_left <= 0:
		_end_level()
	else:
		_spawn_stag()
		state = State.AIM
		_set_hint("", "")

func _end_level() -> void:
	state = State.RESULTS
	_set_hint("", "")
	var total := score.score
	var optional := objectives_completed()
	var antlers := antlers_for(total, optional)
	var completed_ids: Array = []
	var objs: Array = []
	for o in (level.get("optional", []) as Array):
		var oid := str((o as Dictionary).get("id", ""))
		var done: bool = bool(obj_state.get(oid, false))
		if done:
			completed_ids.append(oid)
		objs.append({"id": oid, "label": str((o as Dictionary).get("label", "")), "done": done})
	var prev_total := Progress.total_antlers()
	var locked_next_before := _first_locked_after_this()
	var new_best := Progress.record_level_run(level_id, total, antlers, completed_ids)
	var gained_antler := Progress.total_antlers() > prev_total
	var unlocked_next := locked_next_before != "" and Progress.is_level_unlocked(locked_next_before)
	hud.show_results({
		"completed": total >= level_target,
		"score": total,
		"best": Progress.best_score_for(level_id),
		"antlers": antlers,
		"biggest_combo": score.biggest_combo,
		"new_best": new_best,
		"level_id": level_id,
		"level_code": str(level.get("code", "1-1")),
		"level_name": str(level.get("name", "")),
		"target": level_target,
		"unlocked": unlocked_next,
		"objectives": objs,
		"obj_perfect": bool(obj_state.get("perfect", false)),
		"obj_grab": bool(obj_state.get("grab", false)),
	})
	Sfx.play("result", 1.0, -5.0)
	if gained_antler:
		Sfx.play("antler", 1.0, -4.0)
	if unlocked_next:
		Sfx.play("unlock", 1.0, -3.0)

func _first_locked_after_this() -> String:
	for next_id in Levels.LEVEL_IDS:
		var req: Dictionary = Levels.REQUIRES.get(next_id, {})
		if str(req.get("level", "")) == level_id and not Progress.is_level_unlocked(next_id):
			return next_id
	return ""

func objectives_completed() -> int:
	var n := 0
	for id in Levels.optional_ids(level):
		if bool(obj_state.get(id, false)):
			n += 1
	return n

func antlers_for(total: int, optional: int) -> int:
	## 0 = failed the target. Otherwise 1 antler for the target, +1 per optional
	## objective completed.
	if total < level_target:
		return 0
	return clampi(1 + optional, 0, 3)

func _try_objective(which: String) -> void:
	if not obj_state.has(which) or bool(obj_state[which]):
		return
	obj_state[which] = true
	var banner := str(OBJECTIVE_BANNERS.get(which, "OBJECTIVE!"))
	var col: Color = OBJECTIVE_COLORS.get(which, Color("#7FE0C4"))
	fx.banner(banner, col, 52)
	hud.set_objectives_state(obj_state)
	Sfx.play("objective", 1.0, -4.0)

func debug_complete_level() -> void:
	## Debug only: instantly finish the current level with all objectives met.
	if state == State.RESULTS:
		return
	score.score = maxi(score.score, level_target)
	for id in Levels.optional_ids(level):
		obj_state[id] = true
	hud.set_objectives_state(obj_state)
	hud.set_score(score.score)
	stags_left = 0
	hud.set_stags(0, stags_total)
	if stag and is_instance_valid(stag):
		stag.make_passive()
		spent_stags.append(stag)
	_end_level()

func debug_score_bonus(amount: int) -> void:
	## Debug only (F6): bump the live score to explore score/UI states quickly.
	if state == State.RESULTS:
		return
	score.score += amount
	hud.set_score(score.score)

func _draw() -> void:
	# draw the rope of every hanging object (world space)
	for p in props:
		if not is_instance_valid(p):
			continue
		if p.tether_node == null or not is_instance_valid(p.tether_node):
			continue
		var top: Vector2 = p.global_position + p.tether_offset.rotated(p.global_rotation)
		draw_line(p.tether_node.global_position, top, Color("#E9D6A8"), 3.0)

# ------------------------------------------------------------- stag events ---

func _on_stag_launched(_dir: Vector2, _impulse: float) -> void:
	score.armed = true
	Progress.launched_once = true
	if not Progress.hooked_once:
		Sfx.play("start", 1.0, -10.0)
	# reset per-launch trick-shot tracking
	_hooks_this_launch = 0
	_assist_awarded = false
	_assist_marks.clear()
	_bounce_awarded = false
	_bounce_time = -99999
	_chain_awarded = false
	_thrown_props.clear()
	_set_hint("", "")
	Sfx.play("whoosh", randf_range(0.95, 1.05), -6.0)
	Sfx.play("launch", randf_range(0.9, 1.1), -8.0)
	fx.shake(0.12)

func _on_stag_impacted(energy: float, other: Node, s: Stag) -> void:
	if not is_instance_valid(s) or s.passive:
		return
	var pos: Vector2 = s.global_position
	if other is Node2D:
		pos = (s.global_position + (other as Node2D).global_position) * 0.5
	if energy > STRONG_ENERGY:
		fx.impact(pos, clampf(energy / 500.0, 0.4, 1.4), Color("#FFD166"))
		fx.shake(clampf(energy / 1600.0, 0.05, 0.8))

func _on_stag_landed_hard(energy: float, s: Stag) -> void:
	if not is_instance_valid(s) or s.passive:
		return
	Sfx.play("thud", randf_range(0.9, 1.1), clampf(-4.0 - energy / 200.0, -14.0, -2.0))
	fx.debris(s.global_position, Color("#FFB48A"), 10)

func _on_stag_hooked(anchor: Node2D) -> void:
	Progress.hooked_once = true
	_set_hint("", "")
	# DOUBLE HOOK: a second ring in the same launch is a headline trick shot.
	_hooks_this_launch += 1
	if _hooks_this_launch == 2:
		score.register("double", anchor.global_position if is_instance_valid(anchor) else stag.global_position, null)
		fx.banner("DOUBLE HOOK!", Color("#FFD166"), 58)
		fx.time_punch(0.7, 0.05)
		_try_objective("double")
	# strong, readable SNAP feedback at the ring
	if is_instance_valid(anchor):
		fx.impact(anchor.global_position, 0.7, Color("#7FE0C4"))
		Sfx.play("hook", 1.05, -7.0)
	fx.shake(0.14)

func _on_stag_released() -> void:
	if stag and is_instance_valid(stag):
		fx.impact(stag.global_position, 0.35, Color("#FFF4E0"))

func _on_stag_perfect(_power: float) -> void:
	_try_objective("perfect")
	score.register("perfect", stag.global_position, null)
	fx.impact(stag.global_position, 1.2, Color("#FFF6D8"))
	fx.shake(0.25)

func _on_stag_grabbed(body: Node) -> void:
	Progress.grabbed_once = true
	_set_hint("", "")
	_try_objective("grab")
	var pos: Vector2 = body.global_position if body is Node2D else stag.global_position
	score.register("grab", pos, null)

func _on_stag_released_grab(body: Node, thrown: bool) -> void:
	if not thrown or not (body is Node2D):
		return
	fx.impact((body as Node2D).global_position, 0.4, Color("#FFF4E0"))
	if body is PhysicsProp:
		_thrown_props[(body as PhysicsProp).get_instance_id()] = Time.get_ticks_msec()
	_try_objective("throw")

# ------------------------------------------------------------- prop events ---

func _on_prop_impacted(energy: float, other: Node, p: PhysicsProp) -> void:
	if not is_instance_valid(p) or not score.armed:
		return
	# Redirectors do not score themselves — they set up a bounce combo.
	if p.kind == "bounce" or p.kind == "spring":
		_bounce_time = Time.get_ticks_msec()
		return
	# BARREL CHAIN: a barrel the player THREW just wrecked something.
	if other is PhysicsProp:
		var op: PhysicsProp = other
		if op.kind == "barrel" and _thrown_props.has(op.get_instance_id()):
			if Time.get_ticks_msec() - int(_thrown_props[op.get_instance_id()]) < int(THROWN_WINDOW * 1000.0):
				_try_objective("barrel")
	var pos: Vector2 = p.global_position
	if energy > STRONG_ENERGY:
		fx.impact(pos, clampf(energy / 520.0, 0.35, 1.3), Color("#FFB48A"))
		fx.shake(clampf(energy / 1900.0, 0.04, 0.7))
		Sfx.play("thud", randf_range(0.85, 1.15), -9.0)
	elif energy > HOOK_ENERGY:
		Sfx.play("crate", randf_range(0.9, 1.15), -13.0)
	if other == stag and not stag.passive:
		score.register("direct", pos, p)
	elif other is Stag and other.passive:
		# a spent stag can knock things around, and if that shortly causes
		# destruction it is a STAG ASSIST (handled at break time).
		_assist_marks[p.get_instance_id()] = Time.get_ticks_msec()
		score.register("chain", pos, p)
	elif other and other.is_in_group("props"):
		score.register("chain", pos, p)

func _on_prop_knocked(distance: float, p: PhysicsProp) -> void:
	if not is_instance_valid(p) or not score.armed or distance < 46.0:
		return
	score.register("knock", p.global_position, p)

func _on_prop_shattered(p: PhysicsProp) -> void:
	if not is_instance_valid(p) or not score.armed or p.is_special():
		return
	var is_support := p.kind == "support"
	var col := Color("#CE8B4F") if is_support else (Color("#D89B4A") if p.kind == "jar" else Color("#B0703C"))
	fx.debris(p.global_position, col, 20)
	fx.impact(p.global_position, 1.0, Color("#FFD166"))
	fx.shake(0.45)
	if is_support:
		Sfx.play("snap", randf_range(0.92, 1.08), -4.0)
		score.register("support", p.global_position, p)
	else:
		Sfx.play("break", randf_range(0.9, 1.2), -5.0)
		score.register("shatter", p.global_position, p)
	_check_context_bonus(p)

func _on_prop_rope_snapped(p: PhysicsProp) -> void:
	if not is_instance_valid(p) or not score.armed:
		return
	fx.debris(p.global_position + p.tether_offset, Color("#E9D6A8"), 14)
	fx.shake(0.28)
	Sfx.play("rope", randf_range(0.95, 1.1), -4.0)
	score.register("rope", p.global_position, p)
	_check_context_bonus(p)

func _on_prop_ripped(p: PhysicsProp) -> void:
	if not is_instance_valid(p) or not score.armed:
		return
	fx.debris(p.global_position, Color("#CE8B4F"), 22)
	fx.impact(p.global_position, 1.1, Color("#FF5A3C"))
	fx.shake(0.4)
	Sfx.play("snap", randf_range(0.85, 0.98), -3.0)
	score.register("rip", p.global_position, p)
	fx.banner("RIP IT!", Color("#FF5A3C"), 52)
	_try_objective("rip")
	_check_context_bonus(p)

func _on_prop_special_burst(pos: Vector2, radius: float, impulse: float, p: PhysicsProp) -> void:
	if not score.armed:
		return
	var is_blast := is_instance_valid(p) and p.kind == "blast"
	for b in get_tree().get_nodes_in_group("bodies"):
		if b == p or not is_instance_valid(b) or not (b is RigidBody2D):
			continue
		var d: Vector2 = b.global_position - pos
		var dist := d.length()
		if dist < 0.001 or dist > radius:
			continue
		var falloff := 1.0 - dist / radius
		(b as RigidBody2D).apply_central_impulse(d.normalized() * impulse * falloff)
	if is_blast:
		fx.debris(pos, Color("#FFD166"), 40)
		fx.impact(pos, 1.8, Color("#FFE7A0"))
		fx.shake(1.0)
		Sfx.play("blast", randf_range(0.96, 1.04), -2.0)
		score.register("blast", pos, p)
	else:
		fx.debris(pos, Color("#F2C14E"), 30)
		fx.impact(pos, 1.6, Color("#FFE7A0"))
		fx.shake(0.8)
		Sfx.play("golden", randf_range(0.95, 1.05), -3.0)
		score.register("special", pos, p)

# ------------------------------------------------------- contextual bonuses --

func _check_context_bonus(p: PhysicsProp) -> void:
	## STAG ASSIST + BOUNCE COMBO are awarded when a piece of destruction can be
	## traced back to a preceding assist/bounce within a short window.
	if not score.armed:
		return
	var now := Time.get_ticks_msec()
	if not _assist_awarded and _assist_marks.has(p.get_instance_id()):
		if now - int(_assist_marks[p.get_instance_id()]) < int(ASSIST_WINDOW * 1000.0):
			_assist_awarded = true
			score.register("assist", p.global_position, null)
			fx.banner("STAG ASSIST!", Color("#7FE0C4"), 52)
	if not _bounce_awarded and now - _bounce_time < int(BOUNCE_WINDOW * 1000.0):
		_bounce_awarded = true
		score.register("bounce", p.global_position, null)
		fx.banner("BOUNCE COMBO!", Color("#E0668A"), 52)

# ------------------------------------------------------------------ scoring --

func _on_score_changed(total: int) -> void:
	hud.set_score(total)

func _on_combo_changed(mult: int) -> void:
	hud.set_combo(mult)
	if mult >= 5 and not obj_grab:
		# the "grab" objective can also be earned with a sustained 5+ chain.
		_try_objective("grab")

func _on_mayhem_changed(value: float, stage: int) -> void:
	hud.set_mayhem(value, stage)
	if stage == ScoreManager.STAGE_MAYHEM and _last_stage < ScoreManager.STAGE_MAYHEM:
		fx.banner("MAYHEM!", Color("#FF8A6A"), 72)
		fx.time_punch(0.8, 0.05)
		fx.shake(0.4)
		Sfx.play("mayhem", 1.0, -3.0)
		# CHAIN REACTION: a sustained run of mayhem is its own trick shot.
		if not _chain_awarded and score.armed:
			_chain_awarded = true
			score.register("chain_react", stag.global_position, null)
	_last_stage = stage

func _on_popup(text: String, pos: Vector2, color: Color, size: int) -> void:
	fx.popup(text, pos, color, size)

func _on_banner(text: String, color: Color, size: int) -> void:
	fx.banner(text, color, size)

func _on_punch() -> void:
	fx.time_punch(0.72, 0.06)

# -------------------------------------------------------------------- hints --

func _set_hint(id: String, text: String) -> void:
	if id == _current_hint:
		return
	_current_hint = id
	if id == "":
		hud.hide_hint()
	else:
		hud.show_hint(text)

# -------------------------------------------------------------------- retry --

func _retry_level() -> void:
	Sfx.play("retry", 1.0, -6.0)
	Engine.time_scale = 1.0
	var app := get_node_or_null("/root/App")
	if app and app.has_method("reload_level"):
		app.call("reload_level")
		return
	hud.hide_results()
	get_tree().reload_current_scene()

func _continue() -> void:
	Engine.time_scale = 1.0
	var app := get_node_or_null("/root/App")
	if app and app.has_method("goto_map"):
		app.call("goto_map")
		return
	# No App shell (standalone tool): replay the level.
	hud.hide_results()
	get_tree().reload_current_scene()
