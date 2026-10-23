extends Node2D
## Stag Lodge: the cozy home screen.
##
## One clear reason to hang out here (idle stag + trophy shelf that fills in as
## you clear cabins) and one obvious next action (PLAY). Everything else is a
## single tap away. Art is drawn, not imported, to match the rest of the game.

signal play_pressed
signal closet_pressed
signal settings_pressed

const W := 1280.0
const H := 720.0

var _stag: StagVisual

func _ready() -> void:
	_build_stag()
	_build_ui()

func _build_stag() -> void:
	_stag = StagVisual.new()
	_stag.set_character(Progress.selected_character)
	_stag.set_idle(true)
	_stag.position = Vector2(900, 470)
	_stag.z_index = 5
	add_child(_stag)

func _build_ui() -> void:
	var title := UiKit.label("ANTLER  MAYHEM", 64, UiKit.CREAM)
	title.position = Vector2(70, 60)
	add_child(title)

	var sub := UiKit.label("Stagbyte's First Cabin — Vertical Slice", 22, UiKit.MINT)
	sub.position = Vector2(74, 138)
	add_child(sub)

	var play := UiKit.button("PLAY", UiKit.MINT, UiKit.PLUM, 34)
	play.custom_minimum_size = Vector2(300, 84)
	play.position = Vector2(74, 360)
	play.pressed.connect(func() -> void: play_pressed.emit())
	add_child(play)

	var closet := UiKit.button("DRESSING ROOM", UiKit.YELLOW, UiKit.PLUM, 24)
	closet.position = Vector2(74, 466)
	closet.pressed.connect(func() -> void: closet_pressed.emit())
	add_child(closet)

	var settings := UiKit.button("SETTINGS", UiKit.PLUM_LIGHT, UiKit.CREAM, 24)
	settings.position = Vector2(74, 542)
	settings.pressed.connect(func() -> void: settings_pressed.emit())
	add_child(settings)

	var antlers := Progress.total_antlers()
	var trophy := UiKit.label("ANTLERS  %d / %d" % [antlers, Progress.max_antlers()], 24, UiKit.GOLD)
	trophy.position = Vector2(74, 250)
	add_child(trophy)

func _process(_delta: float) -> void:
	if _stag and randf() < 0.006:
		_stag.look_around(randf_range(-1.0, 1.0))

func _draw() -> void:
	_draw_room()

func _draw_room() -> void:
	for i in 12:
		var t := float(i) / 11.0
		draw_rect(Rect2(0, H * t, W, H / 12 + 1), Color("#2A1B33").lerp(Color("#4A2F5C"), t))
	# floor
	draw_rect(Rect2(0, 560, W, H - 560), Color("#6B4426"))
	draw_rect(Rect2(0, 560, W, 8), Color("#4A2E18"))
	# rug
	draw_rect(Rect2(560, 600, 620, 90), Color("#B0492F"))
	draw_rect(Rect2(580, 612, 580, 66), Color("#C9762F"))
	# fireplace
	var fp := Vector2(300, 300)
	draw_rect(Rect2(fp.x, fp.y, 260, 260), Color("#5E3A22"))
	draw_rect(Rect2(fp.x + 30, fp.y + 60, 200, 200), Color("#1E1430"))
	draw_rect(Rect2(fp.x - 16, fp.y - 20, 292, 24), Color("#B0703C"))
	for i in 4:
		var fx := fp.x + 70 + i * 30
		var fh := 40.0 + randf() * 30.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(fx, fp.y + 250), Vector2(fx + 16, fp.y + 250 - fh),
			Vector2(fx + 32, fp.y + 250)]), Color(1.0, 0.62 + randf() * 0.2, 0.25, 0.9))
	draw_circle(fp + Vector2(130, 200), 70.0, Color(1.0, 0.7, 0.3, 0.06))
	# trophy shelf: one decoration per cleared cabin
	var sx := 90.0
	for i in 3:
		var done := Progress.milestone_done(i)
		draw_rect(Rect2(sx + i * 70, 210, 60, 10), Color("#B0703C"))
		if done:
			draw_circle(Vector2(sx + i * 70 + 30, 190), 18.0, UiKit.GOLD)
			draw_circle(Vector2(sx + i * 70 + 30, 190), 10.0, Color("#FFF0C0"))
		else:
			draw_rect(Rect2(sx + i * 70 + 16, 192, 28, 18), Color(0.2, 0.15, 0.25, 0.6))
	# "first deer" banner lights up once any level is cleared
	if Progress.total_antlers() > 0:
		var lc := Vector2(660, 150)
		draw_line(Vector2(0, 120), lc, Color("#3A2447"), 4.0)
		draw_line(Vector2(1280, 120), lc, Color("#3A2447"), 4.0)
		draw_colored_polygon(PackedVector2Array([
			lc + Vector2(0, -18), lc + Vector2(0, 30),
			lc + Vector2(60, 20), lc + Vector2(60, -8)]), UiKit.CORAL)
