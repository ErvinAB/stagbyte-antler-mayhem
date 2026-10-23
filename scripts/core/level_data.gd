class_name Levels
extends Object
## Reusable level definition model for the vertical slice.
##
## Each level is a plain Dictionary describing WHAT the level is, never HOW
## gameplay works: Main (scripts/gameplay/main.gd) is the single engine that
## builds any level from this data. Level-specific scene arrangement lives
## here, core gameplay logic lives there.
##
## No over-engineering: three hand-authored dictionaries, read-only at runtime.

const LEVEL_IDS: Array[String] = ["cabin_1", "cabin_2", "cabin_3", "antler_challenge"]

## Antlers required from a previous level to unlock the next one.
const REQUIRES := {
	"cabin_1": {},
	"cabin_2": {"level": "cabin_1", "antlers": 1},
	"cabin_3": {"level": "cabin_2", "antlers": 1},
	"antler_challenge": {},
}

const LEVELS := {
	# ----------------------------------------------------------------- L1 ---
	"cabin_1": {
		"id": "cabin_1",
		"code": "1-1",
		"name": "THE WORKSHOP",
		"tagline": "Cause chain reactions. It's what workshops are for.",
		"theme": "workshop",
		"target": 5000,
		"stags": 3,
		"hint": "DRAG BACK TO AIM  →  RELEASE TO LAUNCH",
		"optional": [
			{"id": "perfect", "label": "Land a Perfect Release", "banner": "PERFECT RELEASE!"},
			{"id": "grab", "label": "Antler Grab (or a 5+ chain)", "banner": "ANTLER GRAB!"},
		],
		"spawn": Vector2(135, 599),
		"anchors": [Vector2(340, 400), Vector2(560, 300), Vector2(760, 250)],
		# kind, position, rotation, optional name
		"props": [
			["spring", Vector2(210, 610), -1.0],
			["bounce", Vector2(400, 624), 0.0],
			["cabinet", Vector2(480, 618), 0.0, "Cabinet"],
			["crate", Vector2(600, 634), 0.0],
			["crate", Vector2(600, 582), 0.0],
			["crate", Vector2(660, 634), 0.0],
			["barrel", Vector2(760, 636), 0.0],
			["crate", Vector2(300, 634), 0.0],
			["support", Vector2(900, 624), 0.0],
			["bracket", Vector2(1080, 615), 0.0, "Bracket"],
			["plank", Vector2(990, 584), 0.0, "Shelf"],
			["crate", Vector2(930, 550), 0.0],
			["golden", Vector2(990, 550), 0.0],
			["blast", Vector2(1050, 549), 0.0],
			["plank", Vector2(1230, 652), 0.0],
			["jar", Vector2(1170, 631), 0.0],
			["jar", Vector2(1230, 631), 0.0],
			["jar", Vector2(1290, 631), 0.0],
		],
		# kind, position, pivot, rope top-offset
		"hanging": [
			["sign", Vector2(470, 250), Vector2(470, 60), Vector2(0, -34)],
			["sack", Vector2(680, 240), Vector2(680, 40), Vector2(0, -22)],
		],
		# [prop name, prop it releases when ripped]
		"rip_links": [["Bracket", "Shelf"]],
	},

	# ----------------------------------------------------------------- L2 ---
	"cabin_2": {
		"id": "cabin_2",
		"code": "1-2",
		"name": "BARREL TROUBLE",
		"tagline": "Grab it. Swing it. Throw it. Blame the barrel.",
		"theme": "cellar",
		"target": 4200,
		"stags": 3,
		"hint": "TAP A GLOWING BARREL TO GRAB  →  RELEASE TO THROW",
		"optional": [
			{"id": "throw", "label": "Throw a grabbed object", "banner": "CLEAN THROW!"},
			{"id": "barrel", "label": "Barrel chain reaction", "banner": "BARREL CHAIN!"},
		],
		"spawn": Vector2(135, 599),
		"anchors": [Vector2(520, 300)],
		"props": [
			# launch + redirect into the crate tower
			["bounce", Vector2(330, 624), 0.0],
			["crate", Vector2(430, 634), 0.0],
			# crate tower (the intended barrel target)
			["crate", Vector2(640, 634), 0.0],
			["crate", Vector2(640, 582), 0.0],
			["crate", Vector2(640, 530), 0.0],
			["crate", Vector2(692, 634), 0.0],
			["crate", Vector2(692, 582), 0.0],
			["jar", Vector2(744, 631), 0.0],
			# THE barrel: grabbable, throwable, rollable
			["barrel", Vector2(840, 636), 0.0, "Barrel"],
			# breakable support holding the back shelf (barrel can smash it)
			["support", Vector2(980, 624), 0.0],
			["plank", Vector2(1075, 584), 0.0, "Shelf"],
			["crate", Vector2(1035, 550), 0.0],
			["golden", Vector2(1095, 550), 0.0],
			["jar", Vector2(1150, 631), 0.0],
			["jar", Vector2(1200, 631), 0.0],
			["cabinet", Vector2(1255, 618), 0.0, "Cabinet"],
		],
		# hanging object that drops onto the tower when its rope snaps
		"hanging": [
			["sack", Vector2(560, 230), Vector2(560, 40), Vector2(0, -22)],
		],
		"rip_links": [],
	},

	# ----------------------------------------------------------------- L3 ---
	"cabin_3": {
		"id": "cabin_3",
		"code": "1-3",
		"name": "RIP IT DOWN",
		"tagline": "Three rings, one weak shelf, zero patience.",
		"theme": "attic",
		"target": 6000,
		"stags": 3,
		"hint": "HOLD A WEAK JOINT UNTIL IT RIPS  ·  CHAIN YOUR HOOKS",
		"optional": [
			{"id": "rip", "label": "Rip a weak joint with antler tension", "banner": "RIP IT!"},
			{"id": "double", "label": "Perform a Double Hook", "banner": "DOUBLE HOOK!"},
		],
		"spawn": Vector2(135, 599),
		"anchors": [Vector2(330, 420), Vector2(640, 300), Vector2(930, 360)],
		"props": [
			["bounce", Vector2(300, 624), 0.0],
			["crate", Vector2(400, 634), 0.0],
			["support", Vector2(700, 624), 0.0],
			["bracket", Vector2(890, 615), 0.0, "Bracket"],
			["plank", Vector2(790, 584), 0.0, "Shelf"],
			["crate", Vector2(735, 550), 0.0],
			["crate", Vector2(790, 550), 0.0],
			["blast", Vector2(845, 549), 0.0],
			["cabinet", Vector2(1010, 618), 0.0, "Cabinet"],
			["barrel", Vector2(1110, 636), 0.0],
			["jar", Vector2(1170, 631), 0.0],
			["jar", Vector2(1220, 631), 0.0],
			["crate", Vector2(1275, 634), 0.0],
		],
		"hanging": [
			["plank", Vector2(1075, 300), Vector2(1075, 50), Vector2(0, -10), true, Vector2(240, 16)],
			["crate", Vector2(1045, 266), Vector2(1075, 50), Vector2(0, -30), true],
			["crate", Vector2(1105, 266), Vector2(1075, 50), Vector2(0, -30), true],
			["golden", Vector2(1075, 214), Vector2(1075, 50), Vector2(0, -30), true],
		],
		"rip_links": [["Bracket", "Shelf"]],
	},

	# ----------------------------------------------------------------- EXP ---
	"antler_challenge": {
		"id": "antler_challenge",
		"code": "EX-01",
		"name": "THE ANTLER CHALLENGE",
		"tagline": "Hook. Swing. Release. Watch it fall.",
		"theme": "workshop",
		"target": 3000,
		"stags": 3,
		"hint": "DIRECT LAUNCH IS POSSIBLE — A CLEAN SWING IS MORE REWARDING",
		"optional": [
			{"id": "perfect", "label": "Land a Perfect Release", "banner": "PERFECT RELEASE!"},
			{"id": "rip", "label": "Trigger a physics chain reaction", "banner": "CHAIN REACTION!"},
		],
		"spawn": Vector2(135, 599),
		"anchors": [Vector2(500, 280)],
		"props": [
			["spring", Vector2(200, 610), -1.0],
			["bounce", Vector2(350, 624), 0.0],
			["crate", Vector2(680, 634), 0.0],
			["crate", Vector2(680, 582), 0.0],
			["crate", Vector2(732, 634), 0.0],
			["crate", Vector2(732, 582), 0.0],
			["crate", Vector2(732, 530), 0.0],
			["support", Vector2(920, 624), 0.0],
			["plank", Vector2(1020, 584), 0.0, "Shelf"],
			["crate", Vector2(980, 550), 0.0],
			["crate", Vector2(1060, 550), 0.0],
			["barrel", Vector2(820, 636), 0.0],
			["jar", Vector2(1120, 631), 0.0],
			["jar", Vector2(1170, 631), 0.0],
		],
		"hanging": [
			["plank", Vector2(950, 240), Vector2(950, 60), Vector2(0, -10), true, Vector2(200, 16)],
		],
		"rip_links": [],
	},
}

static func get_level(id: String) -> Dictionary:
	if LEVELS.has(id):
		return LEVELS[id]
	return LEVELS["cabin_1"]

static func has_level(id: String) -> bool:
	return LEVELS.has(id)

static func is_unlocked(id: String, antlers_by_id: Dictionary) -> bool:
	if not LEVELS.has(id):
		return false
	var rule: Dictionary = REQUIRES.get(id, {})
	if rule.is_empty():
		return true
	var need_level := str(rule.get("level", ""))
	var need: int = int(rule.get("antlers", 1))
	return int(antlers_by_id.get(need_level, 0)) >= need

static func total_max_antlers() -> int:
	# 3 antlers per level in the vertical slice.
	return LEVELS.size() * 3

static func optional_ids(level: Dictionary) -> Array:
	var out: Array = []
	for o in (level.get("optional", []) as Array):
		out.append(str((o as Dictionary).get("id", "")))
	return out

static func find_optional(level: Dictionary, id: String) -> Dictionary:
	for o in (level.get("optional", []) as Array):
		if str((o as Dictionary).get("id", "")) == id:
			return o
	return {}
