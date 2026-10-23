extends Node2D
## SWING MODE — experimental isolated mode (no slingshot)
## Stag starts suspended from anchor1, already swinging with modest momentum.
## Controls: tap to release; hold near another valid anchor to attach; release to detach.

const AREA_Y_MIN := 0.0
const AREA_Y_MAX := 760.0
const AREA_X_MIN := -40.0
const AREA_X_MAX := 1320.0
const RESTART_AFTER := 2.0

@onready var world: Node2D = $World
@onready var anchors_root: Node2D = $World/Anchors
@onready var props_root: Node2D = $World/Props
@onready var background: Node2D = $World/Background
@onready var stag_node: Node2D = $World/Stag
@onready var camera: Camera2D = $Camera2D
@onready var score_mgr: Node = $ScoreManager
@onready var hud: CanvasLayer = $HUD
@onready var fx: Node2D = $Effects
@onready var pointer: Node = $PointerInput

var stag: Stag
var anchors: Array = []
var props: Array = []
var score: ScoreManager

var time_left := 45.0
var ended := false
var _out_time := -1.0
var _restart_timer := -1.0
var _prop_count := 0
var _initial_prop_count := 0
var _holding := false

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

func _ready() -> void:
	if background and background.has_method("set_level"):
		background.call("set_level", "cabin_1", "workshop")
	score = score_mgr
	_build_level()
	_setup_stag()
	_setup_input()
	_setup_hud()
	camera.make_current()

func _build_level() -> void:
	var a1 = _make_anchor(Vector2(360, 180))
	var a2 = _make_anchor(Vector2(640, 240))
	var a3 = _make_anchor(Vector2(960, 200))
	anchors = [a1, a2, a3]
	_make_prop("crate", Vector2(520, 634), 0.0)
	_make_prop("crate", Vector2(580, 634), 0.0)
	_make_prop("crate", Vector2(580, 582), 0.0)
	_make_prop("crate", Vector2(780, 634), 0.0)
	_make_prop("crate", Vector2(840, 634), 0.0)
	_make_prop("barrel", Vector2(700, 636), 0.0)
	_make_prop("plank", Vector2(920, 584), 0.0, "Platform")
	_make_prop("crate", Vector2(880, 550), 0.0)
	_make_prop("crate", Vector2(960, 550), 0.0)
	_make_prop("support", Vector2(1080, 624), 0.0)
	_make_prop("jar", Vector2(400, 631), 0.0)
	_make_prop("jar", Vector2(1180, 631), 0.0)
	_initial_prop_count = props.size()

func _make_anchor(pos: Vector2) -> Node2D:
	var scn = load("res://scenes/environment/hook_anchor.tscn")
	var a = scn.instantiate()
	a.position = pos
	anchors_root.add_child(a)
	return a

func _make_prop(kind: String, pos: Vector2, rot: float, name_: String = "") -> PhysicsProp:
	var scn = load("res://scenes/objects/physics_object.tscn")
	var p: PhysicsProp = scn.instantiate()
	p.kind = kind
	p.size = PROP_SIZE.get(kind, Vector2(48, 48))
	p.position = pos
	p.rotation = rot
	if name_ != "":
		p.name = name_
	props_root.add_child(p)
	p.impacted.connect(_on_prop_impacted.bind(p))
	p.shattered.connect(_on_prop_shattered.bind(p))
	props.append(p)
	return p

func _setup_stag() -> void:
	stag = stag_node
	stag.airborne = true
	stag.hooked = false
	_drop_grab_if_needed()
	var a1 = anchors[0] if anchors.size() > 0 else null
	if a1:
		stag.global_position = a1.global_position + Vector2(60, 20)
		stag.hook(a1)
		stag.apply_impulse(Vector2(140, -100))
	score.armed = true

func _drop_grab_if_needed() -> void:
	if stag.has_method("_drop_grab"):
		stag.call("_drop_grab")

func _setup_input() -> void:
	pointer.pointer_pressed.connect(_on_pressed)
	pointer.pointer_released.connect(_on_released)

func _setup_hud() -> void:
	hud.show_intro()
	hud.hide_results()
	hud.configure_level({"target": 0, "code": "SW", "name": "SWING MODE", "optional": []})

func _on_pressed(pos: Vector2):
	if ended:
		return
	_holding = true
	# Hold-to-attach: press while flying and in range of an anchor to hook it.
	if not stag.hooked:
		var best = null
		var bestd = 1e9
		for a in anchors:
			if not is_instance_valid(a): continue
			var d = stag.global_position.distance_to(a.global_position)
			if d < stag.HOOK_RADIUS + 40 and d < bestd:
				best = a
				bestd = d
		if best:
			stag.hook(best)

func _on_released(pos: Vector2):
	if ended:
		return
	_holding = false
	# Release-to-detach: lifting the finger lets go of the current anchor.
	if stag.hooked:
		stag.unhook()

func _on_prop_impacted(energy: float, other: Node, p: PhysicsProp) -> void:
	if not ended:
		score.register("direct" if energy > 300 else "knock", p.global_position, p)

func _on_prop_shattered(pos: Vector2, kind: String, p: PhysicsProp) -> void:
	if not ended:
		score.register("shatter", pos, p)

func _update_anchor_feedback() -> void:
	if not is_instance_valid(stag):
		return
	var free := not stag.hooked and not stag.grabbing
	for a in anchors:
		if not is_instance_valid(a):
			continue
		var d := stag.global_position.distance_to(a.global_position)
		var near := d <= stag.HOOK_RADIUS + 40.0
		a.set_highlight(free and near)
		a.range_hint = 1.0 if (free and near) else 0.0

func _process(delta: float) -> void:
	_update_anchor_feedback()
	if ended:
		_restart_timer -= delta
		if _restart_timer <= 0:
			_restart()
		return
	time_left -= delta
	hud.set_score(int(score.score))
	hud.set_mayhem(score.mayhem, score.stage)
	if time_left <= 0:
		_end("TIME UP — SWING HARDER")
		return
	if _is_out_of_bounds():
		if _out_time < 0:
			_out_time = 0.3
		else:
			_out_time -= delta
			if _out_time <= 0:
				_end("FELL OUT — RETRY")
				return
	else:
		_out_time = -1.0

func _is_out_of_bounds() -> bool:
	if not is_instance_valid(stag): return true
	var p = stag.global_position
	return p.y > AREA_Y_MAX or p.y < AREA_Y_MIN or p.x < AREA_X_MIN or p.x > AREA_X_MAX or stag.linear_velocity.length() < 5.0 and stag.global_position.y > 650 and not stag.hooked

func _end(msg: String) -> void:
	ended = true
	_restart_timer = RESTART_AFTER
	hud.show_results({
		"completed": false,
		"score": int(score.score),
		"best": int(score.score),
		"antlers": 0,
		"biggest_combo": score.biggest_combo,
		"new_best": false,
		"level_id": "swing_mode",
		"level_code": "SW-01",
		"level_name": "SWING MODE",
		"target": 0,
		"objectives": []
	})

func _restart() -> void:
	get_tree().reload_current_scene()
