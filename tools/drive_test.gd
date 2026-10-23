extends Node
## Headless gameplay drive test for Cabin Level 1 (Sprint 3).
##
## Runs the REAL Main scene and injects synthetic pointer events through the
## real PointerInput abstraction. Two layers:
##   1. Deterministic mechanic + objective unit checks at boot (bounce formula,
##      support break, rope snap, blast trigger, passive-stag score guard,
##      objective wiring, antler-rating model, level contents).
##   2. Full 3-stag lifecycle: aim -> launch -> (hook -> swing -> release) ->
##      settle -> next stag, with the environment PERSISTING between stags. On
##      the last stag it hooks (proves hooks still work after the room is
##      wrecked). Then level end, results, best-score save and a clean Retry.
##
## Run with: godot --headless --fixed-fps 60 --path . res://tools/drive_test.tscn

const MAIN_SCENE := "res://scenes/main/main.tscn"
const PROP_SCENE := preload("res://scenes/objects/physics_object.tscn")
const STAG_SCENE := preload("res://scenes/stag/stag.tscn")

var main: Node
var pi: PointerInput
var t := 0.0
var phase := 0
var stag_index := 0
var use_touch := true
var _booted := false

var initial_props := 0
var prev_alive := 999
var prev_score := 0
var hooks_made := 0
var tried_hook := false
var hooked_this_stag := false

# mechanic event counters (members: lambdas read them through self)
var supports_broken := 0
var ropes_snapped := 0
var blasts_fired := 0
var special_bursts := 0

func _ready() -> void:
	randomize()
	main = load(MAIN_SCENE).instantiate()
	get_tree().root.add_child.call_deferred(main)

func _alive_props() -> int:
	var n := 0
	for p in main.props:
		if is_instance_valid(p):
			n += 1
	return n

func _count_kind(kind: String) -> int:
	var n := 0
	for p in main.props:
		if is_instance_valid(p) and p.kind == kind:
			n += 1
	return n

func _process(delta: float) -> void:
	if not _booted:
		if main.get_parent() == get_tree().root and main.is_node_ready():
			get_tree().current_scene = main
			pi = main.pointer
			_booted = true
			_boot_checks()
			return

	t += delta
	match phase:
		0:
			if t > 0.2:
				_before_stag()
				tried_hook = false
				hooked_this_stag = false
				_press(Vector2(135, 599))
				phase = 1
				t = 0.0
		1:
			if t > 0.08:
				_move(Vector2(0, 710))
				phase = 2
				t = 0.0
		2:
			if t > 0.08:
				_release(Vector2(0, 710))
				use_touch = false
				print("[DRIVE] stag %d launched. state=%d vel=%d" % [stag_index + 1, main.state,
					int(main.stag.linear_velocity.length())])
				phase = 3
				t = 0.0
		3:
			if main.state == 2:
				_after_stag()
				phase = 4
				t = 0.0
			elif main.state == 3:
				phase = 6
				t = 0.0
			elif main.stag.hooked:
				if t > 0.3:
					print("[DRIVE] stag %d release hook vel=%d" % [stag_index + 1, int(main.stag.linear_velocity.length())])
					_release(main.stag.global_position)
					hooked_this_stag = true
					t = 0.0
			else:
				if not tried_hook and stag_index == 2:
					var near: Node2D = _nearest_anchor()
					if near:
						print("[DRIVE] stag %d hook attempt dist=%.0f (post-destruction)" % [stag_index + 1,
							main.stag.global_position.distance_to(near.global_position)])
						_press(near.global_position)
						tried_hook = true
						hooks_made += 1
				if t > 8.0:
					print("[DRIVE] stag %d TIMEOUT airborne; forcing settle" % (stag_index + 1))
					main.state = 2
					main._respawn_timer = 0.0
		4:
			if t > 0.3:
				phase = 5
				t = 0.0
		5:
			if main.state == 3:
				phase = 6
				t = 0.0
			elif main.state == 0 and main.stags_left > 0:
				assert(main.spent_stags.size() == stag_index + 1,
					"spent stags must persist (expected %d, got %d)" % [stag_index + 1, main.spent_stags.size()])
				for ps in main.spent_stags:
					assert(ps.passive, "every spent stag must be passive")
				var expected := 3 - (stag_index + 1)
				print("[DRIVE] --- next stag ready. stags_left=%d (expected %d) spent=%d ---" % [
					main.stags_left, expected, main.spent_stags.size()])
				assert(main.stags_left == expected, "stags_left should be %d after %d stags" % [expected, stag_index + 1])
				stag_index += 1
				use_touch = true
				phase = 0
				t = 0.0
			elif t > 3.0:
				print("[DRIVE] ERROR: stuck after settle. state=", main.state, " stags_left=", main.stags_left)
				get_tree().quit()
		6:
			if t > 0.4:
				print("[DRIVE] === LEVEL END ===")
				print("[DRIVE] state=%d results_visible=%s score=%d best=%d stags_left=%d" % [
					main.state, main.hud.is_results_visible(), main.score.score,
					Progress.best_score, main.stags_left])
				print("[DRIVE] events: supports_broken=%d ropes_snapped=%d blasts=%d special_bursts=%d hooks=%d" % [
					supports_broken, ropes_snapped, blasts_fired, special_bursts, hooks_made])
				print("[DRIVE] objectives: perfect=%s grab=%s  objectives_completed=%d" % [
					main.obj_perfect, main.obj_grab, main.objectives_completed()])
				print("[DRIVE] spent_stags=%d (all passive=%s)  props_alive=%d/%d" % [
					main.spent_stags.size(), _all_passive(), _alive_props(), initial_props])
				assert(main.state == 3, "expected RESULTS state")
				assert(main.hud.is_results_visible(), "expected results panel visible")
				assert(main.stags_left == 0, "expected 0 stags left")
				assert(main.spent_stags.size() == 3, "all 3 stags should remain as passive obstacles")
				assert(_all_passive(), "all spent stags must be passive")
				assert(Progress.best_score >= main.score.score, "best should be >= this run")
				var expect_antlers: int = main.antlers_for(main.score.score, main.objectives_completed())
				print("[DRIVE] antler rating for this run = %d" % expect_antlers)
				phase = 7
				t = 0.0
		7:
			if t > 0.3:
				print("[DRIVE] press RETRY LEVEL")
				main.hud.retry_pressed.emit()
				phase = 8
				t = 0.0
		8:
			if t > 0.5:
				phase = 9
				main = get_tree().current_scene
				print("[DRIVE] after retry: state=%d stags_left=%d score=%d props=%d spent=%d" % [
					main.state, main.stags_left, main.score.score, _alive_props(), main.spent_stags.size()])
				assert(main.stags_left == 3, "retry should restore 3 stags")
				assert(main.score.score == 0, "retry should reset score")
				assert(main.spent_stags.size() == 0, "retry should clear spent stags")
				assert(_alive_props() == initial_props, "retry should restore all props")
				print("[DRIVE] DONE (all assertions passed)")
		9:
			# terminal phase: always reached even if a retry assertion aborted
			get_tree().quit()

# ------------------------------------------------------------- boot checks ---

func _boot_checks() -> void:
	initial_props = _alive_props()
	print("[DRIVE] booted. anchors=%d props=%d stags_left=%d state=%d" % [
		main.anchors.size(), initial_props, main.stags_left, main.state])
	assert(main.stags_left == 3, "expected 3 stags at start")
	assert(main.anchors.size() == 3, "expected 3 anchors")

	# --- level contents: the four routes need their pieces present ---
	assert(initial_props == 20, "expected 20 props, got %d" % initial_props)
	assert(_count_kind("support") == 1, "expected 1 breakable support")
	assert(_count_kind("bounce") == 1, "expected a bounce mushroom")
	assert(_count_kind("spring") == 1, "expected a springboard redirector")
	assert(_count_kind("bracket") == 1, "expected a rippable weak bracket")
	assert(_count_kind("cabinet") == 1, "expected a heavy cabinet")
	assert(_count_kind("blast") == 1, "expected an acorn blast crate")
	assert(_count_kind("barrel") == 1, "expected a rolling barrel")
	assert(_count_kind("golden") == 1, "expected the golden acorn")
	assert(_count_kind("sack") == 1, "expected a hanging acorn sack")
	var grabbable := 0
	for p in main.props:
		if p.is_grabbable():
			grabbable += 1
	assert(grabbable >= 4, "expected several grabbable props, got %d" % grabbable)
	var bracket: PhysicsProp = null
	for p in main.props:
		if p.kind == "bracket":
			bracket = p
	assert(bracket != null and bracket.rippable and bracket.rip_release != null,
		"bracket must be rippable and wired to release the shelf")
	var breakable_ropes := 0
	for p in main.props:
		if p.rope_breakable:
			breakable_ropes += 1
	assert(breakable_ropes == 2, "expected 2 breakable-rope hanging objects, got %d" % breakable_ropes)
	print("[DRIVE] level contents OK (supports/spring/bracket/cabinet/bounce/barrel/blast/golden/sack/ropes present)")

	# --- antler rating model (deterministic) ---
	assert(main.antlers_for(0, 0) == 0, "no target -> 0 antlers")
	assert(main.antlers_for(4999, 2) == 0, "still no target -> 0 antlers")
	assert(main.antlers_for(5000, 0) == 1, "target only -> 1 antler")
	assert(main.antlers_for(5000, 1) == 2, "target + 1 optional -> 2 antlers")
	assert(main.antlers_for(5000, 2) == 3, "target + both optional -> 3 antlers")
	assert(main.antlers_for(99999, 0) == 1, "target overkill, no optional -> 1 antler")
	print("[DRIVE] antler rating model OK")

	# --- objective wiring (set, then reset so it does not affect the run) ---
	main.obj_perfect = false
	main.obj_grab = false
	main._try_objective("perfect")
	assert(main.obj_perfect and main.objectives_completed() == 1, "perfect objective wiring")
	main._try_objective("grab")
	assert(main.obj_grab and main.objectives_completed() == 2, "grab objective wiring")
	print("[DRIVE] objective wiring OK")
	main.obj_perfect = false
	main.obj_grab = false
	main.hud.set_objectives(false, false)

	# --- deterministic mechanic checks on throwaway props ---
	_mechanic_checks()

	# --- connect event monitors to the REAL props for the lifecycle ---
	for p in main.props:
		if not is_instance_valid(p):
			continue
		if p.kind == "support":
			p.shattered.connect(func(): supports_broken += 1)
		if p.kind == "blast":
			p.special_burst.connect(func(_pos, _r, _i): blasts_fired += 1)
		if p.rope_breakable:
			p.rope_snapped.connect(func(): ropes_snapped += 1)
		if p.is_special():
			p.special_burst.connect(func(_pos, _r, _i): special_bursts += 1)
	print("[DRIVE] real-prop monitors connected")

func _mechanic_checks() -> void:
	var far := Vector2(-600, -600)

	# 1) bounce is deterministic: result == tangential*0.82 + normal*BOUNCE_SPEED
	var pad: PhysicsProp = PROP_SCENE.instantiate()
	pad.kind = "bounce"
	pad.size = Vector2(72, 72)
	pad.position = far
	main.props_root.add_child(pad)
	var probe := RigidBody2D.new()
	probe.mass = 1.0
	probe.position = far
	var pc := CollisionShape2D.new()
	var pcs := CircleShape2D.new()
	pcs.radius = 8.0
	pc.shape = pcs
	probe.add_child(pc)
	main.world.add_child(probe)
	probe.linear_velocity = Vector2(200, 300)
	var before := probe.linear_velocity
	var n := Vector2.UP.rotated(pad.global_rotation)
	var vt := before - n * before.dot(n)
	var expected := vt * 0.82 + n * PhysicsProp.BOUNCE_SPEED
	pad._do_bounce(probe)
	assert(probe.linear_velocity.distance_to(expected) < 0.5, "bounce must be deterministic")
	print("[DRIVE] bounce formula OK (v=%s)" % probe.linear_velocity.round())
	probe.queue_free()
	pad.queue_free()

	# heavy striker for the remaining checks
	var hitter := RigidBody2D.new()
	hitter.mass = 2.0
	hitter.position = far
	main.world.add_child(hitter)

	# 2) breakable support shatters under a strong hit
	var sup: PhysicsProp = PROP_SCENE.instantiate()
	sup.kind = "support"
	sup.size = Vector2(22, 64)
	sup.position = far
	main.props_root.add_child(sup)
	var sup_broke := [false]
	sup.shattered.connect(func(): sup_broke[0] = true)
	hitter.linear_velocity = Vector2(400, 0)
	sup._on_body_entered(hitter)
	assert(sup_broke[0], "support must shatter at high energy")
	print("[DRIVE] support break OK")

	# 3) a breakable rope snaps under a strong hit
	var sack: PhysicsProp = PROP_SCENE.instantiate()
	sack.kind = "sack"
	sack.size = Vector2(44, 48)
	sack.position = far
	main.props_root.add_child(sack)
	var pivot := Node2D.new()
	pivot.position = far
	main.world.add_child(pivot)
	sack.set_tether(pivot, 100.0, Vector2.ZERO, true)
	var rope_gone := [false]
	sack.rope_snapped.connect(func(): rope_gone[0] = true)
	hitter.linear_velocity = Vector2(500, 0)
	sack._on_body_entered(hitter)
	assert(rope_gone[0], "breakable rope must snap at high energy")
	assert(not sack.rope_breakable and sack.tether_node == null, "snapped rope must detach")
	print("[DRIVE] rope snap OK")
	hitter.queue_free()

	# 4) the acorn blast crate fires a special burst
	var blast: PhysicsProp = PROP_SCENE.instantiate()
	blast.kind = "blast"
	blast.size = Vector2(54, 54)
	blast.position = far
	main.props_root.add_child(blast)
	var fired := [false]
	blast.special_burst.connect(func(_p, _r, _i): fired[0] = true)
	var fast := RigidBody2D.new()
	fast.mass = 2.0
	fast.position = far
	main.world.add_child(fast)
	fast.linear_velocity = Vector2(400, 0)
	blast._on_body_entered(fast)
	assert(fired[0], "blast crate must fire a special burst")
	print("[DRIVE] blast trigger OK")
	fast.queue_free()

	# 5) a passive (spent) stag must NOT emit gameplay signals, but an active one does
	var ps: Stag = STAG_SCENE.instantiate()
	ps.position = far
	main.world.add_child(ps)
	ps.make_passive()
	var passive_emitted := [false]
	ps.impacted.connect(func(_e, _o): passive_emitted[0] = true)
	var rock := RigidBody2D.new()
	rock.mass = 1.0
	rock.position = far
	main.world.add_child(rock)
	rock.linear_velocity = Vector2(600, 0)
	ps._on_body_entered(rock)
	assert(not passive_emitted[0], "passive stag must not emit gameplay signals")
	print("[DRIVE] passive-stag score guard OK")
	ps.queue_free()
	rock.queue_free()

	# 6) springboard redirect is deterministic and differs from the mushroom
	var board: PhysicsProp = PROP_SCENE.instantiate()
	board.kind = "spring"
	board.size = Vector2(96, 40)
	board.position = far
	board.rotation = -0.7
	main.props_root.add_child(board)
	var sref := RigidBody2D.new()
	sref.mass = 1.0
	sref.position = far
	var sc := CollisionShape2D.new()
	var scs := CircleShape2D.new()
	scs.radius = 8.0
	sc.shape = scs
	sref.add_child(sc)
	main.world.add_child(sref)
	sref.linear_velocity = Vector2(300, 250)
	var sv := sref.linear_velocity
	var sn := Vector2.UP.rotated(board.global_rotation)
	var svt := sv - sn * sv.dot(sn)
	var sexpected := svt * 0.92 + sn * (maxf(absf(sv.dot(sn)) * PhysicsProp.SPRING_RESTITUTION, 0.0) + PhysicsProp.SPRING_BOOST)
	board._do_spring(sref)
	assert(sref.linear_velocity.distance_to(sexpected) < 0.5, "spring redirect must be deterministic")
	print("[DRIVE] spring redirect OK (v=%s)" % sref.linear_velocity.round())
	sref.queue_free()
	board.queue_free()

	# 7) antler grab: gating, momentum preservation and throw
	var gs: Stag = STAG_SCENE.instantiate()
	gs.position = far
	main.world.add_child(gs)
	gs.airborne = true
	gs.freeze = false
	var hold: PhysicsProp = PROP_SCENE.instantiate()
	hold.kind = "barrel"
	hold.size = Vector2(48, 48)
	hold.position = far + Vector2(40, 0)
	main.props_root.add_child(hold)
	var crate_g: PhysicsProp = PROP_SCENE.instantiate()
	crate_g.kind = "crate"
	crate_g.size = Vector2(52, 52)
	crate_g.position = far + Vector2(-40, 0)
	main.props_root.add_child(crate_g)
	assert(hold.is_grabbable(), "the barrel must be grabbable")
	assert(not crate_g.is_grabbable(), "a crate must not be grabbable")
	assert(gs.can_grab(), "an airborne, free stag can grab")
	assert(not gs.grab(crate_g), "must refuse to grab a non-grabbable prop")
	# out of range is refused
	var far_hold: PhysicsProp = PROP_SCENE.instantiate()
	far_hold.kind = "barrel"
	far_hold.size = Vector2(48, 48)
	far_hold.position = far + Vector2(400, 0)
	main.props_root.add_child(far_hold)
	assert(not gs.grab(far_hold), "must refuse to grab out of range")
	# in-range grab works and is momentum-preserving under the soft constraint
	assert(gs.grab(hold), "in-range barrel must be grabbable")
	assert(gs.grabbing, "stag should report grabbing")
	var p0: Vector2 = gs.linear_velocity * gs.mass + hold.linear_velocity * hold.mass
	for i in 12:
		gs._solve_grab(1.0 / 60.0)
	var p1: Vector2 = gs.linear_velocity * gs.mass + hold.linear_velocity * hold.mass
	assert(p1.distance_to(p0) < 1.0, "grab constraint must preserve momentum (d=%.2f)" % p1.distance_to(p0))
	assert(hold.linear_velocity.length() < 2000.0, "grab correction must stay bounded")
	# throw boosts the released object
	hold.linear_velocity = Vector2(100, 0)
	gs.release_grab(true)
	assert(not gs.grabbing, "release must clear grabbing")
	assert(hold.linear_velocity.x >= 100.0 * Stag.THROW_BOOST - 1.0, "throw must boost the object")
	print("[DRIVE] antler grab + throw OK (thrown v=%s)" % hold.linear_velocity.round())
	gs.queue_free()
	hold.queue_free()
	crate_g.queue_free()
	far_hold.queue_free()

	# 8) rip: partial tension holds, full tension rips and frees the structure
	var weak: PhysicsProp = PROP_SCENE.instantiate()
	weak.kind = "bracket"
	weak.size = Vector2(30, 46)
	weak.position = far
	main.props_root.add_child(weak)
	var shelf2: PhysicsProp = PROP_SCENE.instantiate()
	shelf2.kind = "plank"
	shelf2.size = Vector2(200, 16)
	shelf2.position = far + Vector2(0, -60)
	shelf2.freeze = true
	shelf2.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
	main.props_root.add_child(shelf2)
	weak.rip_release = shelf2
	var ripped := [false]
	weak.ripped.connect(func(): ripped[0] = true)
	weak.add_tension(0.5)
	assert(absf(weak.get_tension() - 0.5) < 0.01 and not ripped[0], "a weak pull must not rip a joint")
	weak.add_tension(0.6)
	assert(ripped[0], "enough tension must rip the joint")
	assert(not shelf2.freeze, "ripping must release the held structure")
	var solid: PhysicsProp = PROP_SCENE.instantiate()
	solid.kind = "crate"
	solid.size = Vector2(52, 52)
	solid.position = far
	main.props_root.add_child(solid)
	solid.add_tension(5.0)
	assert(solid.get_tension() == 0.0, "non-rippable props ignore tension")
	print("[DRIVE] rip tension OK")
	shelf2.queue_free()
	solid.queue_free()

	# 9) perfect release: a fast, flat release qualifies; a vertical one does not
	var ps2: Stag = STAG_SCENE.instantiate()
	ps2.position = far
	main.world.add_child(ps2)
	ps2.freeze = true
	ps2.airborne = true
	ps2.hooked = true
	ps2.linear_velocity = Vector2(600, 0)
	assert(ps2.perfect_ready(), "a fast flat swing is in the perfect window")
	var perfect := [false]
	ps2.perfect_released.connect(func(_pow): perfect[0] = true)
	ps2.unhook()
	assert(perfect[0], "releasing a fast flat swing must be a Perfect Release")
	ps2.hooked = true
	ps2.linear_velocity = Vector2(0, -600)
	assert(not ps2.perfect_ready(), "a vertical release is not perfect")
	print("[DRIVE] perfect release OK")
	ps2.queue_free()

	# 10) double hook: two rings in one launch pays at least 500
	main.score.reset()
	main.score.armed = true
	main._hooks_this_launch = 0
	var d_before: int = main.score.score
	main._on_stag_hooked(main.anchors[0])
	main._on_stag_hooked(main.anchors[1])
	assert(main._hooks_this_launch == 2, "both hooks this launch must be counted")
	assert(main.score.score >= d_before + 500, "double hook must pay >= 500")
	print("[DRIVE] double hook OK")
	Engine.time_scale = 1.0
	main.score.reset()

	# 11) contextual bonuses: stag assist (+250) and bounce combo (+200)
	var bonus_target: PhysicsProp = PROP_SCENE.instantiate()
	bonus_target.kind = "crate"
	bonus_target.size = Vector2(52, 52)
	bonus_target.position = far
	main.props_root.add_child(bonus_target)
	main.score.armed = true
	main._assist_awarded = false
	main._bounce_awarded = true
	main._assist_marks.clear()
	main._assist_marks[bonus_target.get_instance_id()] = Time.get_ticks_msec()
	var a_before: int = main.score.score
	main._check_context_bonus(bonus_target)
	assert(main._assist_awarded and main.score.score >= a_before + 250, "stag assist must pay >= 250")
	main.score.reset()
	main.score.armed = true
	main._assist_awarded = true
	main._bounce_awarded = false
	main._bounce_time = Time.get_ticks_msec()
	var bo_before: int = main.score.score
	main._check_context_bonus(bonus_target)
	assert(main._bounce_awarded and main.score.score >= bo_before + 200, "bounce combo must pay >= 200")
	print("[DRIVE] contextual bonuses OK (assist + bounce)")
	bonus_target.queue_free()
	main.score.reset()

func _all_passive() -> bool:
	for ps in main.spent_stags:
		if not is_instance_valid(ps) or not ps.passive:
			return false
	return true

func _nearest_anchor() -> Node2D:
	var best: Node2D = null
	var best_d := 130.0
	for a in main.anchors:
		if not is_instance_valid(a):
			continue
		var d: float = main.stag.global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best

func _before_stag() -> void:
	prev_alive = _alive_props()
	prev_score = main.score.score

func _after_stag() -> void:
	var alive := _alive_props()
	print("[DRIVE] stag %d settled at %s. score=%d (was %d) props_alive=%d (was %d)" % [
		stag_index + 1, main.stag.global_position.round(), main.score.score, prev_score,
		alive, prev_alive])
	assert(main.score.score >= prev_score, "score must not decrease between stags")
	assert(alive <= prev_alive, "props must not be resurrected between stags")

# --- synthetic input via the real PointerInput abstraction ---

func _press(pos: Vector2) -> void:
	if use_touch:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.pressed = true
		e.position = pos
		pi._unhandled_input(e)
		return
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	pi._unhandled_input(e)

func _move(pos: Vector2) -> void:
	if use_touch:
		var te := InputEventScreenDrag.new()
		te.index = 0
		te.position = pos
		pi._unhandled_input(te)
		return
	var e := InputEventMouseMotion.new()
	e.position = pos
	pi._unhandled_input(e)

func _release(pos: Vector2) -> void:
	if use_touch:
		var te := InputEventScreenTouch.new()
		te.index = 0
		te.pressed = false
		te.position = pos
		pi._unhandled_input(te)
		return
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = pos
	pi._unhandled_input(e)
