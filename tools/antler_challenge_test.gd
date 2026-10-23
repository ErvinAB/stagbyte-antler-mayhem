extends Node

func _ready():
	await get_tree().process_frame
	var lvl = load("res://scenes/main/main.tscn").instantiate()
	lvl.level_id = "antler_challenge"
	add_child(lvl)
	await get_tree().process_frame
	await get_tree().process_frame
	var ok = true
	if str(lvl.level_id) != "antler_challenge":
		ok = false
		push_error("bad id")
	if lvl.anchors.size() != 1:
		ok = false
		push_error("bad anchors")
	if lvl.props.size() < 5:
		ok = false
		push_error("bad props")
	print("[AC] OK" if ok else "[AC] FAIL")
	get_tree().quit(0 if ok else 1)
