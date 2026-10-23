extends Node2D
## World Map: pick a cabin.
##
## Keeps the meta loop legible: a simple left-to-right trail of cabins, each
## showing its best score and antlers, with locked cabins greyed and hinting
## what unlocks them. No minimap, no fog, no inventory — just "go here next".

signal level_chosen(level_id: String)
signal back_pressed

const W := 1280.0
const H := 720.0
const NODE_POS := [Vector2(320, 400), Vector2(560, 330), Vector2(800, 420), Vector2(1040, 360)]

var _buttons: Array[Button] = []

func _ready() -> void:
	_build_ui()

func refresh() -> void:
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	_build_nodes()

func _build_ui() -> void:
	var title := UiKit.label("THE CABIN TRAIL", 44, UiKit.CREAM)
	title.position = Vector2(64, 48)
	add_child(title)

	var total := UiKit.label("ANTLERS  %d / %d" % [Progress.total_antlers(), Progress.max_antlers()], 24, UiKit.GOLD)
	total.position = Vector2(64, 108)
	add_child(total)

	var back := UiKit.button("← LODGE", UiKit.PLUM_LIGHT, UiKit.CREAM, 22)
	back.position = Vector2(64, 630)
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)

	_build_nodes()

func _build_nodes() -> void:
	for i in Levels.LEVEL_IDS.size():
		var id: String = Levels.LEVEL_IDS[i]
		var level: Dictionary = Levels.get_level(id)
		var unlocked := Progress.is_level_unlocked(id)
		var best := Progress.best_score_for(id)
		var antlers := Progress.best_antlers_for(id)
		var stars := ""
		for s in 3:
			stars += "★" if s < antlers else "☆"
		var text := "%s  %s" % [str(level.get("code", "")), str(level.get("name", ""))]
		if unlocked:
			text += "\nBEST %s    %s" % [_fmt(best), stars]
		else:
			text += "\nLOCKED — earn an antler to open"
		var b := UiKit.button(text, UiKit.MINT if unlocked else UiKit.PLUM_LIGHT,
			UiKit.PLUM if unlocked else Color(UiKit.CREAM.r, UiKit.CREAM.g, UiKit.CREAM.b, 0.4), 22)
		b.custom_minimum_size = Vector2(240, 96)
		b.disabled = not unlocked
		var pos: Vector2 = NODE_POS[i]
		b.position = pos - b.custom_minimum_size * 0.5
		b.pressed.connect(func() -> void: level_chosen.emit(id))
		add_child(b)
		_buttons.append(b)

func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out

func _draw() -> void:
	# night sky + hills + a distant cabin, purely decorative
	for i in 12:
		var t := float(i) / 11.0
		draw_rect(Rect2(0, H * t, W, H / 12 + 1), Color("#1B1230").lerp(Color("#3A2447"), t))
	draw_circle(Vector2(1080, 120), 46.0, Color("#FFF0C0"))
	draw_circle(Vector2(1096, 110), 42.0, Color("#1B1230"))
	for st in [Vector2(200, 120), Vector2(420, 80), Vector2(700, 140), Vector2(900, 90)]:
		draw_circle(st, 2.0, UiKit.CREAM)
	# hills
	draw_colored_polygon(PackedVector2Array([
		Vector2(-40, 620), Vector2(300, 430), Vector2(640, 620)]), Color("#241A38"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(500, 640), Vector2(880, 420), Vector2(1320, 640)]), Color("#2C2140"))
	draw_rect(Rect2(0, 600, W, H - 600), Color("#211734"))
	# trail dots connecting cabins
	for i in NODE_POS.size() - 1:
		var a: Vector2 = NODE_POS[i]
		var b: Vector2 = NODE_POS[i + 1]
		for k in 10:
			var t := float(k) / 9.0
			var p := a.lerp(b, t) + Vector2(0, sin(t * PI) * -18.0)
			draw_circle(p, 3.0, Color(UiKit.CREAM.r, UiKit.CREAM.g, UiKit.CREAM.b, 0.18))
