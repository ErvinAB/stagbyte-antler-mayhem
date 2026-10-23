extends Node2D
## Hand-drawn backdrop for each level. The original "woodland workshop"
## remains the default palette; other themes are light variations so that
## the levels feel meaningfully different without spending the whole sprint
## on complex art.

const ARENA := Vector2(1280, 720)
const FLOOR_Y := 660.0

var pl_deep := Color("#2A1B33")
var pl_mid := Color("#3A2447")
var pl_light := Color("#4A2F5C")
var beam := Color("#2E1C3C")
var wood := Color("#8A5330")
var wood_dark := Color("#5E3A22")
var wood_light := Color("#B0703C")
var cream := Color("#FFF4E0")
var coral := Color("#FF8A6A")
var mint := Color("#7FE0C4")
var night := Color("#1E1430")
var accent := Color("#C9762F")

func _ready() -> void:
	add_to_group("background")
	queue_redraw()

func set_level(level_id: String, theme: String = "workshop") -> void:
	match theme:
		"cellar":
			pl_deep = Color("#1C2835")
			pl_mid = Color("#233342")
			pl_light = Color("#2E4559")
			beam = Color("#1A2733")
			wood = Color("#6B5B4F")
			wood_dark = Color("#4C3F35")
			wood_light = Color("#8A7766")
			coral = Color("#B97C5D")
			mint = Color("#7FCFCF")
			accent = Color("#8D7B6E")
		"attic":
			pl_deep = Color("#2B2538")
			pl_mid = Color("#352D47")
			pl_light = Color("#403A56")
			beam = Color("#241D2F")
			wood = Color("#8F7B52")
			wood_dark = Color("#614F32")
			wood_light = Color("#B19C6B")
			coral = Color("#F49A73")
			mint = Color("#8FD9C4")
			accent = Color("#C39D6E")
		_:
			pl_deep = Color("#2A1B33")
			pl_mid = Color("#3A2447")
			pl_light = Color("#4A2F5C")
			beam = Color("#2E1C3C")
			wood = Color("#8A5330")
			wood_dark = Color("#5E3A22")
			wood_light = Color("#B0703C")
			coral = Color("#FF8A6A")
			mint = Color("#7FE0C4")
			accent = Color("#C9762F")
	queue_redraw()

func _draw() -> void:
	_draw_wall()
	_draw_floor()
	_draw_beams()
	_draw_window()
	_draw_shelves()
	_draw_lamp()
	_draw_launch_pad()
	_draw_route_hint()

func _draw_wall() -> void:
	var strips := 16
	for i in strips:
		var t := float(i) / float(strips - 1)
		var col := pl_deep.lerp(pl_light, t)
		draw_rect(Rect2(0, ARENA.y * t, ARENA.x, ARENA.y / strips + 1), col)

func _draw_floor() -> void:
	draw_rect(Rect2(0, FLOOR_Y, ARENA.x, ARENA.y - FLOOR_Y), wood)
	draw_rect(Rect2(0, FLOOR_Y, ARENA.x, 8), wood_dark)
	for i in 13:
		var x := i * 100.0
		draw_line(Vector2(x, FLOOR_Y), Vector2(x - 20, ARENA.y), wood_dark, 2.0)
	draw_line(Vector2(0, FLOOR_Y + 34), Vector2(ARENA.x, FLOOR_Y + 34), wood_dark, 1.5)

func _draw_beams() -> void:
	draw_rect(Rect2(0, 0, ARENA.x, 26), beam)
	for x in [60.0, 360.0, 660.0, 960.0, 1250.0]:
		draw_rect(Rect2(x - 14, 0, 28, FLOOR_Y), beam)
	draw_rect(Rect2(0, 150, ARENA.x, 14), Color(beam.r, beam.g, beam.b, 0.5))

func _draw_window() -> void:
	var p := Vector2(120, 60)
	var s := Vector2(210, 170)
	draw_rect(Rect2(p - Vector2(10, 10), s + Vector2(20, 20)), beam)
	draw_rect(Rect2(p, s), night)
	draw_circle(p + Vector2(150, 46), 24.0, Color("#FFF0C0"))
	draw_circle(p + Vector2(158, 40), 22.0, night)
	for st in [Vector2(40, 30), Vector2(70, 90), Vector2(36, 120), Vector2(110, 60), Vector2(170, 110)]:
		draw_circle(p + st, 1.6, Color("#FFF4E0"))
	draw_line(p + Vector2(s.x * 0.5, 0), p + Vector2(s.x * 0.5, s.y), beam, 8.0)
	draw_line(p + Vector2(0, s.y * 0.5), p + Vector2(s.x, s.y * 0.5), beam, 8.0)

func _draw_shelves() -> void:
	for shelf in [Vector2(430, 96), Vector2(1120, 96)]:
		draw_rect(Rect2(shelf.x - 90, shelf.y, 180, 12), wood_light)
		draw_rect(Rect2(shelf.x - 90, shelf.y, 180, 4), wood_dark)
		for i in 3:
			var bx: float = shelf.x - 60 + i * 60
			draw_rect(Rect2(bx, shelf.y - 30, 24, 30), accent)
			draw_rect(Rect2(bx + 8, shelf.y - 40, 8, 12), wood_dark)

func _draw_lamp() -> void:
	var top := Vector2(700, 30)
	var shade := Vector2(700, 120)
	draw_line(top, shade, beam, 3.0)
	draw_colored_polygon(PackedVector2Array([
		shade + Vector2(-34, 0), shade + Vector2(34, 0),
		shade + Vector2(16, 30), shade + Vector2(-16, 30)]), coral)
	draw_circle(shade + Vector2(0, 40), 10.0, Color("#FFD166"))
	for i in 3:
		draw_circle(shade + Vector2(0, 50), 16.0 + i * 12.0, Color(1.0, 0.82, 0.4, 0.05))

func _draw_launch_pad() -> void:
	var base := Vector2(70, FLOOR_Y)
	draw_rect(Rect2(base.x, base.y - 16, 150, 16), wood_light)
	draw_rect(Rect2(base.x, base.y - 16, 150, 4), wood_dark)
	var cx := 145.0
	for i in 4:
		var y := base.y - 18 - i * 7
		draw_line(Vector2(cx - 12, y), Vector2(cx + 12, y + 4), mint, 3.0)
	draw_line(Vector2(cx, base.y - 16), Vector2(cx, base.y - 48), mint, 3.0)

func _draw_route_hint() -> void:
	var a := Vector2(150, 590)
	var b := Vector2(440, 370)
	var col := Color(cream.r, cream.g, cream.b, 0.10)
	for i in 15:
		var t := float(i) / 14.0
		var p := a.lerp(b, t) + Vector2(0, -sin(t * PI) * 130.0)
		draw_circle(p, 2.5, col)
	draw_circle(b, 4.0, Color(mint.r, mint.g, mint.b, 0.25))
