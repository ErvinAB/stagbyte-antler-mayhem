class_name PointerInput
extends Node
## Pointer input abstraction.
## Mouse and touch are normalized into ONE set of pointer events so that
## gameplay logic never needs to know which device produced the input.

signal pointer_pressed(pos: Vector2)
signal pointer_moved(pos: Vector2)
signal pointer_released(pos: Vector2)

var pressed := false
var position := Vector2.ZERO
var press_position := Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(event.position)
		else:
			_end(event.position)
		return
	if event is InputEventMouseMotion and pressed:
		_move(event.position)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin(event.position)
		else:
			_end(event.position)
		return
	if event is InputEventScreenDrag:
		_move(event.position)

func _begin(pos: Vector2) -> void:
	pressed = true
	position = pos
	press_position = pos
	pointer_pressed.emit(pos)

func _move(pos: Vector2) -> void:
	position = pos
	pointer_moved.emit(pos)

func _end(pos: Vector2) -> void:
	if not pressed:
		return
	pressed = false
	position = pos
	pointer_released.emit(pos)

func cancel() -> void:
	pressed = false
