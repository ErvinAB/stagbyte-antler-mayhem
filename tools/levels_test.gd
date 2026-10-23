extends Node
## Builds every level in the slice headless and checks the level runner builds
## the expected props/anchors for each, so data mistakes surface in CI instead
## of only when a player scrolls to level 3.
## Run: godot --headless --fixed-fps 60 --path . res://tools/levels_test.tscn

var _fails := 0

func _ready() -> void:
	await get_tree().process_frame
	Progress.set_debug_unlock(true)
	for id in Levels.LEVEL_IDS:
		await _check_level(id)
	if _fails == 0:
		print("[LEVELS] DONE (all assertions passed)")
	else:
		printerr("[LEVELS] DONE with %d failure(s)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)

func _check_level(id: String) -> void:
	var data: Dictionary = Levels.get_level(id)
	var lvl: Node = load("res://scenes/main/main.tscn").instantiate()
	lvl.level_id = id
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame

	var expected_props: int = (data.get("props", []) as Array).size() + (data.get("hanging", []) as Array).size()
	var expected_anchors: int = (data.get("anchors", []) as Array).size()
	_check(int(lvl.get("stags_total")) == int(data.get("stags", 3)), "%s: stag count" % id)
	_check(int(lvl.get("level_target")) == int(data.get("target", 0)), "%s: target" % id)
	_check((lvl.get("props") as Array).size() == expected_props, "%s: %d props built" % [id, expected_props])
	_check((lvl.get("anchors") as Array).size() == expected_anchors, "%s: %d anchors built" % [id, expected_anchors])
	_check(lvl.get("obj_state") != null and (lvl.get("obj_state") as Dictionary).size() == Levels.optional_ids(data).size(),
		"%s: objectives tracked" % id)
	# every prop must be a live PhysicsProp
	var all_ok := true
	for p in (lvl.get("props") as Array):
		if not is_instance_valid(p):
			all_ok = false
	_check(all_ok, "%s: all props valid" % id)
	_check(lvl.get("level_id") == id, "%s: level id round-trips" % id)
	lvl.queue_free()
	await get_tree().process_frame

func _check(cond: bool, label: String) -> void:
	if cond:
		print("[LEVELS] OK  ", label)
	else:
		_fails += 1
		printerr("[LEVELS] FAIL ", label)
