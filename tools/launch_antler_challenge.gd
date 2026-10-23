# Quick access script to launch Antler Challenge in the editor
tool
extends EditorScript

func _run():
	var main_scene = load("res://scenes/main/main.tscn")
	var inst = main_scene.instantiate()
	inst.level_id = "antler_challenge"
	var root = EditorInterface.get_editor_main_screen()
	# This is a simple dev helper; just print guidance.
	print("[Dev] To test Antler Challenge, open scenes/main/main.tscn and set level_id=antler_challenge, or run from App and pick it in code.")
	print("[Dev] Level registered as: antler_challenge (EX-01 THE ANTLER CHALLENGE)")
