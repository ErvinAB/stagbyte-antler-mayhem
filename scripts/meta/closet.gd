extends Node2D
## Dressing Room: pick your idiot.
##
## Deliberately cosmetic-only. Each character changes the ART and nothing else,
## so there is no stat comparison, no wrong choice, no meta-grind — just "who do
## you want to fling across a cabin today".

signal back_pressed

const W := 1280.0
const H := 720.0
const CHARACTERS := [
	{"id": "buck", "name": "BUCK", "tag": "Reliable. Enthusiastic. Doomed."},
	{"id": "mochi", "name": "MOCHI", "tag": "Small body. Huge eyes. Zero plan."},
	{"id": "bruno", "name": "BRUNO", "tag": "Heavy antlers. Heavy sigh."},
]

var _previews: Array = []
var _cards: Array = []

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var title := UiKit.label("DRESSING ROOM", 44, UiKit.CREAM)
	title.position = Vector2(64, 48)
	add_child(title)

	var sub := UiKit.label("Cosmetic only — every character plays exactly the same.", 20, UiKit.MINT)
	sub.position = Vector2(66, 108)
	add_child(sub)

	for i in CHARACTERS.size():
		var c: Dictionary = CHARACTERS[i]
		var cx := 260.0 + i * 380.0
		var stag := StagVisual.new()
		stag.set_character(str(c.get("id", "buck")))
		stag.set_idle(true)
		stag.position = Vector2(cx, 320)
		stag.z_index = 4
		add_child(stag)
		_previews.append(stag)

		var name_l := UiKit.label(str(c.get("name", "")), 32, UiKit.CREAM)
		name_l.position = Vector2(cx - 90, 410)
		add_child(name_l)

		var tag_l := UiKit.label(str(c.get("tag", "")), 18, UiKit.MINT)
		tag_l.position = Vector2(cx - 130, 456)
		add_child(tag_l)

		var selected := Progress.selected_character == str(c.get("id", ""))
		var b := UiKit.button("SELECTED" if selected else "SELECT",
			UiKit.MINT if selected else UiKit.PLUM_LIGHT, UiKit.PLUM if selected else UiKit.CREAM, 22)
		b.position = Vector2(cx - 90, 500)
		b.disabled = selected
		b.pressed.connect(func() -> void: _choose(str(c.get("id", ""))))
		add_child(b)
		_cards.append(b)

	var back := UiKit.button("← LODGE", UiKit.PLUM_LIGHT, UiKit.CREAM, 22)
	back.position = Vector2(64, 630)
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)

func _choose(id: String) -> void:
	if Progress.selected_character == id:
		return
	Progress.select_character(id)
	if Sfx.has_method("play"):
		Sfx.call("play", "select", 1.0, -6.0)
	for i in CHARACTERS.size():
		var c: Dictionary = CHARACTERS[i]
		var sel := Progress.selected_character == str(c.get("id", ""))
		var b: Button = _cards[i]
		b.text = "SELECTED" if sel else "SELECT"
		b.disabled = sel

func _process(_delta: float) -> void:
	for p in _previews:
		if randf() < 0.006:
			p.look_around(randf_range(-1.0, 1.0))

func _draw() -> void:
	for i in 12:
		var t := float(i) / 11.0
		draw_rect(Rect2(0, H * t, W, H / 12 + 1), Color("#2A1B33").lerp(Color("#4A2F5C"), t))
	draw_rect(Rect2(0, 560, W, H - 560), Color("#6B4426"))
	for i in 3:
		var cx := 260.0 + i * 380.0
		var selected := Progress.selected_character == str(CHARACTERS[i].get("id", ""))
		draw_rect(Rect2(cx - 150, 210, 300, 320),
			Color(UiKit.MINT.r, UiKit.MINT.g, UiKit.MINT.b, 0.10) if selected else Color(0, 0, 0, 0.18))
		draw_rect(Rect2(cx - 150, 210, 300, 6), UiKit.MINT if selected else UiKit.PLUM_LIGHT)
