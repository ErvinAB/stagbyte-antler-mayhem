extends Node
## Screen-flow smoke test for the Vertical Slice.
##
## Drives App navigation (Lodge -> Map -> Closet -> Settings -> Level) the way a
## player would and checks progression/unlock rules and settings persistence.
## Run: godot --headless --fixed-fps 60 --path . res://tools/flow_test.tscn

var _fails := 0
var app: Node

func _ready() -> void:
	await get_tree().process_frame
	Progress.reset_save()
	app = load("res://scenes/app/app.tscn").instantiate()
	get_tree().root.add_child(app)
	await _settle()

	_check(_cur() == "res://scenes/meta/lodge.tscn", "boots into the Lodge")

	app.goto_map()
	await _settle()
	_check(_cur() == "res://scenes/meta/world_map.tscn", "Lodge -> World Map")

	app.goto_closet()
	await _settle()
	_check(_cur() == "res://scenes/meta/closet.tscn", "World Map -> Closet")

	app.goto_settings()
	await _settle()
	_check(_cur() == "res://scenes/meta/settings.tscn", "Closet -> Settings")

	app.goto_lodge()
	await _settle()
	_check(_cur() == "res://scenes/meta/lodge.tscn", "Settings -> Lodge")

	app.goto_level("cabin_1")
	await _settle()
	_check(_cur() == "res://scenes/main/main.tscn", "Lodge -> Level")
	var level: Node = app.get("_screen")
	_check(level != null and str(level.get("level_id")) == "cabin_1", "level received its id before _ready")
	_check(level != null and int(level.get("level_target")) == 5000, "cabin_1 built with target 5000")

	app.reload_level()
	await _settle()
	_check(_cur() == "res://scenes/main/main.tscn", "reload_level reloads the level")

	app.goto_map()
	await _settle()
	_check(Progress.is_level_unlocked("cabin_1"), "cabin_1 unlocked from the start")
	_check(not Progress.is_level_unlocked("cabin_2"), "cabin_2 locked before earning an antler")
	Progress.record_level_run("cabin_1", 6000, 1, [])
	_check(Progress.is_level_unlocked("cabin_2"), "1 antler on cabin_1 unlocks cabin_2")
	_check(not Progress.is_level_unlocked("cabin_3"), "cabin_3 still locked")

	Progress.set_music(false)
	var fresh: Object = load("res://scripts/core/progress.gd").new()
	fresh.call("_load")
	_check(bool(fresh.get("music_on")) == false, "music setting persisted to disk")
	fresh.free()

	_finish()

func _cur() -> String:
	return str(app.get("_current"))

func _settle() -> void:
	for i in 45:
		await get_tree().process_frame

func _check(cond: bool, label: String) -> void:
	if cond:
		print("[FLOW] OK  ", label)
	else:
		_fails += 1
		printerr("[FLOW] FAIL ", label)

func _finish() -> void:
	if _fails == 0:
		print("[FLOW] DONE (all assertions passed)")
	else:
		printerr("[FLOW] DONE with %d failure(s)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
