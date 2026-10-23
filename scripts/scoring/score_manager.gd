class_name ScoreManager
extends Node
## Scoring + combo. Deliberately conservative: every object can only pay out
## a limited number of times, so bouncing on the same crate forever earns
## nothing. Only *unique, meaningful* events build the combo.

signal score_changed(total: int)
signal combo_changed(multiplier: int)
signal mayhem_changed(value: float, stage: int)
signal popup_requested(text: String, pos: Vector2, color: Color, size: int)
signal banner_requested(text: String, color: Color, size: int)
signal punch_requested()

const COMBO_WINDOW := 2.2
const MAX_MULT := 10

# Mayhem meter stages (feedback only, not a gameplay system).
const STAGE_CALM := 0
const STAGE_MESSY := 1
const STAGE_CHAOS := 2
const STAGE_MAYHEM := 3

const POINTS := {
	"direct": 100,    # stag smashes an object
	"knock": 60,      # object is displaced / knocked down
	"chain": 90,      # object smashes into another object
	"shatter": 150,   # something breaks
	"support": 200,   # a breakable support snaps and drops a structure
	"rope": 220,      # a hanging object's rope snaps
	"special": 400,   # the golden acorn
	"blast": 600,     # the acorn blast crate
	# --- Sprint 4 trick shots (the antlers are the tool) ---
	"grab": 150,          # ANTLER GRAB: the antlers clamp onto a prop
	"perfect": 300,       # PERFECT RELEASE: released in the sweet spot
	"double": 500,        # DOUBLE HOOK: two rings in one launch
	"rip": 350,           # RIP IT!: a weak joint is torn loose
	"assist": 250,        # STAG ASSIST: a spent stag's body causes the damage
	"bounce": 200,        # BOUNCE COMBO: bounced, then broke something
	"chain_react": 500,   # CHAIN REACTION: a big, sustained run of mayhem
}

var score := 0
var combo := 0
var multiplier := 1
var armed := false   # no scoring until the stag is launched (ignores settling)

var mayhem := 0.0    # 0..1 feedback meter
var stage := STAGE_CALM
var biggest_combo := 0
var specials_destroyed := 0
var blasts_triggered := 0
var reached_x10 := false

var _timer := 0.0
var _awarded := {}   # "type:id" -> timestamp ms, prevents re-scoring

func _process(delta: float) -> void:
	if combo > 0:
		_timer -= delta
		if _timer <= 0.0:
			_reset_combo()
	if mayhem > 0.0:
		mayhem = maxf(0.0, mayhem - delta * 0.06)
		_update_stage()

func reset() -> void:
	score = 0
	combo = 0
	multiplier = 1
	armed = false
	mayhem = 0.0
	stage = STAGE_CALM
	biggest_combo = 0
	specials_destroyed = 0
	blasts_triggered = 0
	reached_x10 = false
	_timer = 0.0
	_awarded.clear()
	emit_signal("score_changed", score)
	emit_signal("combo_changed", multiplier)
	emit_signal("mayhem_changed", mayhem, stage)

func _update_stage() -> void:
	var new_stage := STAGE_CALM
	if mayhem >= 0.75:
		new_stage = STAGE_MAYHEM
	elif mayhem >= 0.5:
		new_stage = STAGE_CHAOS
	elif mayhem >= 0.25:
		new_stage = STAGE_MESSY
	if new_stage != stage:
		stage = new_stage
	emit_signal("mayhem_changed", mayhem, stage)

func register(kind: String, pos: Vector2, obj: Node = null) -> void:
	if not armed:
		return
	var id := kind
	if obj and is_instance_valid(obj):
		id += ":%d" % obj.get_instance_id()
	var now := Time.get_ticks_msec()
	if _awarded.has(id):
		# same event on the same object can only pay out every 1.5s
		if now - int(_awarded[id]) < 1500:
			return
	_awarded[id] = now

	combo += 1
	multiplier = clampi(combo, 1, MAX_MULT)
	biggest_combo = maxi(biggest_combo, combo)
	if multiplier >= MAX_MULT:
		reached_x10 = true
	_timer = COMBO_WINDOW
	var base: int = POINTS.get(kind, 50)
	var gained := base * multiplier
	score += gained
	if kind == "special":
		specials_destroyed += 1
	elif kind == "blast":
		blasts_triggered += 1

	# Meaningful destruction feeds the feedback meter (not a gameplay system).
	mayhem = clampf(mayhem + gained / 5000.0, 0.0, 1.0)

	emit_signal("score_changed", score)
	emit_signal("combo_changed", multiplier)
	_update_stage()

	# feedback
	var col := Color("#FFF4E0")
	match kind:
		"direct": col = Color("#FFD166")
		"chain": col = Color("#FFB48A")
		"shatter": col = Color("#FF8A6A")
		"knock": col = Color("#7FE0C4")
		"support": col = Color("#CE8B4F")
		"rope": col = Color("#E9D6A8")
		"special": col = Color("#F2C14E")
		"blast": col = Color("#FFD166")
		"grab": col = Color("#FFF4E0")
		"perfect": col = Color("#7FE0C4")
		"double": col = Color("#FFD166")
		"rip": col = Color("#FF5A3C")
		"assist": col = Color("#7FE0C4")
		"bounce": col = Color("#E0668A")
		"chain_react": col = Color("#FF8A6A")
	var txt := "+%d" % gained
	match kind:
		"special": txt = "GOLDEN +%d" % gained
		"blast": txt = "ACORN BLAST +%d" % gained
		"grab": txt = "ANTLER GRAB +%d" % gained
		"perfect": txt = "PERFECT +%d" % gained
		"double": txt = "DOUBLE HOOK +%d" % gained
		"rip": txt = "RIP IT! +%d" % gained
		"assist": txt = "STAG ASSIST +%d" % gained
		"bounce": txt = "BOUNCE +%d" % gained
		"chain_react": txt = "CHAIN REACTION +%d" % gained
		_: 
			if multiplier > 1:
				txt = "+%d  x%d" % [gained, multiplier]
	emit_signal("popup_requested", txt, pos, col, 22 + min(multiplier * 2, 16))

	if kind == "special":
		emit_signal("banner_requested", "GOLDEN ACORN!", Color("#F2C14E"), 64)
		emit_signal("punch_requested")
	elif kind == "blast":
		emit_signal("banner_requested", "ACORN BLAST!", Color("#F2C14E"), 68)
		emit_signal("punch_requested")
	elif kind == "support":
		emit_signal("banner_requested", "SUPPORT DOWN!", Color("#CE8B4F"), 48)
	elif kind == "rope":
		emit_signal("banner_requested", "SNAP!", Color("#E9D6A8"), 48)
	elif kind == "shatter" or multiplier >= 3:
		emit_signal("punch_requested")
	if multiplier == 3:
		emit_signal("banner_requested", "COMBO x3", Color("#FFD166"), 56)
	elif multiplier == 5:
		emit_signal("banner_requested", "MAYHEM!", Color("#FF8A6A"), 68)
	elif multiplier >= MAX_MULT:
		emit_signal("banner_requested", "ABSOLUTE MAYHEM x10!", Color("#FF8A6A"), 74)

func _reset_combo() -> void:
	combo = 0
	multiplier = 1
	_timer = 0.0
	emit_signal("combo_changed", multiplier)
