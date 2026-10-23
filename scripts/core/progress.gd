extends Node
## Persistent progression, settings and character selection.
##
## Deliberately tiny and offline-only: a single local ConfigFile in `user://`.
## No accounts, no cloud, no backend. Missing or corrupted data falls back to
## safe defaults instead of crashing the game.
##
## Save format v2 (Sprint 5). The old Prototype-004 `cabin_1` section is
## migrated automatically on first load.

const SAVE_PATH := "user://antler_mayhem.cfg"
const SAVE_VERSION := 2

const SECTION_META := "meta"
const SECTION_SETTINGS := "settings"
const SECTION_LEGACY := "cabin_1"
const LEVEL_PREFIX := "level_"

# --- per-level results (level_id -> value) ---
var _best_score := {}       # String -> int
var _best_antlers := {}     # String -> int
var _objectives := {}       # String -> Array[String] (optional objective ids)

# --- meta ---
var selected_character := "buck"

# --- settings ---
var music_on := true
var sfx_on := true
var vibration_on := true
var debug_unlock := false   # developer "unlock all levels" toggle (never set in play)

# --- session only (not saved) ---
var launched_once := false
var hooked_once := false
var grabbed_once := false

func _ready() -> void:
	_load()

# ------------------------------------------------------------------- reads --

## Legacy aliases: "best score on Cabin 1". Kept so older tooling keeps working.
var best_score: int:
	get: return int(_best_score.get("cabin_1", 0))

var best_antlers: int:
	get: return int(_best_antlers.get("cabin_1", 0))

func best_score_for(level_id: String) -> int:
	return int(_best_score.get(level_id, 0))

func best_antlers_for(level_id: String) -> int:
	return int(_best_antlers.get(level_id, 0))

func objectives_for(level_id: String) -> Array:
	var v: Array = _objectives.get(level_id, [])
	return v.duplicate()

func objective_done(level_id: String, objective_id: String) -> bool:
	return objective_id in objectives_for(level_id)

func total_antlers() -> int:
	var t := 0
	for id in _best_antlers:
		t += int(_best_antlers[id])
	return t

func max_antlers() -> int:
	return Levels.total_max_antlers()

func is_level_unlocked(level_id: String) -> bool:
	if debug_unlock:
		return true
	return Levels.is_unlocked(level_id, _best_antlers)

## Cosmetic progression milestones for the Lodge, keyed by completed level.
## A level "counts as completed" once it earned at least one antler.
func milestone_done(index: int) -> bool:
	var ids := ["cabin_1", "cabin_2", "cabin_3"]
	if index < 0 or index >= ids.size():
		return false
	return best_antlers_for(ids[index]) >= 1

# ------------------------------------------------------------------ writes --

func record_level_run(level_id: String, score: int, antlers: int, completed_objectives: Array) -> bool:
	## Saves only improvements. Returns true if anything improved.
	var prev_score := best_score_for(level_id)
	var prev_antlers := best_antlers_for(level_id)
	var prev_obj := objectives_for(level_id)
	var improved := score > prev_score or antlers > prev_antlers
	if score > prev_score:
		_best_score[level_id] = score
	if antlers > prev_antlers:
		_best_antlers[level_id] = antlers
	var merged := prev_obj.duplicate()
	for o in completed_objectives:
		var s := str(o)
		if s != "" and not (s in merged):
			merged.append(s)
			improved = true
	_objectives[level_id] = merged
	if improved:
		_save()
	return improved

func select_character(id: String) -> void:
	if id not in ["buck", "mochi", "bruno"]:
		return
	if selected_character == id:
		return
	selected_character = id
	_save()

func set_music(v: bool) -> void:
	music_on = v
	_save()

func set_sfx(v: bool) -> void:
	sfx_on = v
	_save()

func set_vibration(v: bool) -> void:
	vibration_on = v
	_save()

func set_debug_unlock(v: bool) -> void:
	debug_unlock = v
	_save()

func reset_save() -> void:
	## Full wipe (debug tool + corrupted-data recovery).
	_best_score = {}
	_best_antlers = {}
	_objectives = {}
	selected_character = "buck"
	music_on = true
	sfx_on = true
	vibration_on = true
	debug_unlock = false
	_save()

# --------------------------------------------------------------------- io --

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_META, "version", SAVE_VERSION)
	cfg.set_value(SECTION_META, "character", selected_character)
	cfg.set_value(SECTION_SETTINGS, "music", music_on)
	cfg.set_value(SECTION_SETTINGS, "sfx", sfx_on)
	cfg.set_value(SECTION_SETTINGS, "vibration", vibration_on)
	cfg.set_value(SECTION_SETTINGS, "debug_unlock", debug_unlock)
	for id in _best_score:
		cfg.set_value(LEVEL_PREFIX + str(id), "best_score", int(_best_score[id]))
	for id in _best_antlers:
		cfg.set_value(LEVEL_PREFIX + str(id), "best_antlers", int(_best_antlers[id]))
	for id in _objectives:
		cfg.set_value(LEVEL_PREFIX + str(id), "objectives", PackedStringArray(_objectives[id]))
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return   # first run or unreadable file -> defaults
	# settings + character (type-checked so a corrupted value cannot crash)
	if cfg.has_section_key(SECTION_META, "character"):
		var c = cfg.get_value(SECTION_META, "character", "buck")
		if typeof(c) == TYPE_STRING and c in ["buck", "mochi", "bruno"]:
			selected_character = c
	music_on = _get_bool(cfg, SECTION_SETTINGS, "music", true)
	sfx_on = _get_bool(cfg, SECTION_SETTINGS, "sfx", true)
	vibration_on = _get_bool(cfg, SECTION_SETTINGS, "vibration", true)
	debug_unlock = _get_bool(cfg, SECTION_SETTINGS, "debug_unlock", false)
	# per-level sections
	for section in cfg.get_sections():
		if not section.begins_with(LEVEL_PREFIX):
			continue
		var id := section.trim_prefix(LEVEL_PREFIX)
		if id == "":
			continue
		_best_score[id] = _get_int(cfg, section, "best_score", 0)
		_best_antlers[id] = clampi(_get_int(cfg, section, "best_antlers", 0), 0, 3)
		var objs = cfg.get_value(section, "objectives", PackedStringArray())
		var list: Array = []
		if typeof(objs) == TYPE_PACKED_STRING_ARRAY or typeof(objs) == TYPE_ARRAY:
			for o in objs:
				if typeof(o) == TYPE_STRING:
					list.append(str(o))
		_objectives[id] = list
	# migrate the Prototype-004 save (plain cabin_1 section, no prefix)
	if cfg.has_section(SECTION_LEGACY):
		if not _best_score.has("cabin_1"):
			_best_score["cabin_1"] = _get_int(cfg, SECTION_LEGACY, "best_score", 0)
		if not _best_antlers.has("cabin_1"):
			_best_antlers["cabin_1"] = clampi(_get_int(cfg, SECTION_LEGACY, "best_antlers", 0), 0, 3)
		# legacy objective flags -> objective ids
		var migrated: Array = []
		if _get_bool(cfg, SECTION_LEGACY, "ever_blast", false):
			migrated.append("blast")
		if _get_bool(cfg, SECTION_LEGACY, "ever_x10", false):
			migrated.append("x10")
		if not migrated.is_empty():
			_objectives["cabin_1"] = (_objectives.get("cabin_1", []) as Array).duplicate()
			for m in migrated:
				if not (m in _objectives["cabin_1"]):
					_objectives["cabin_1"].append(m)
	# if the file version is unknown/garbage, values above already fell back
	# to defaults per key; nothing else to do.

func _get_int(cfg: ConfigFile, section: String, key: String, fallback: int) -> int:
	if not cfg.has_section_key(section, key):
		return fallback
	var v = cfg.get_value(section, key, fallback)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return fallback

func _get_bool(cfg: ConfigFile, section: String, key: String, fallback: bool) -> bool:
	if not cfg.has_section_key(section, key):
		return fallback
	var v = cfg.get_value(section, key, fallback)
	if typeof(v) == TYPE_BOOL:
		return v
	return fallback
