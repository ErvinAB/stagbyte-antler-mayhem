extends Node

func _ready():
	await get_tree().process_frame
	var scn = load("res://scenes/experiments/swing_mode.tscn")
	var inst = scn.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	print("[SW] OK anchors=", inst.anchors.size(), "props=", inst.props.size())
	get_tree().quit(0)
