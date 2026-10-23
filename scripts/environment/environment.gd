extends StaticBody2D
## Invisible static colliders: floor, walls and ceiling.
## The visual wood/plum backdrop is drawn by background.gd.

const SHAPES := [
	# [center, size]
	[Vector2(640, 690), Vector2(1440, 60)],   # floor  (top edge at y=660)
	[Vector2(0, 360), Vector2(40, 760)],      # left wall
	[Vector2(1300, 360), Vector2(40, 760)],   # right wall
	[Vector2(640, -20), Vector2(1440, 40)],   # ceiling
]

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	for s in SHAPES:
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = s[1]
		col.shape = rect
		col.position = s[0]
		add_child(col)
