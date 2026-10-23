extends Node2D
## Settings: three honest toggles. No resolution menus, no remapping, no
## "advanced" tab. Just the things a player actually reaches for.

signal back_pressed
signal changed

const W := 1280.0
const H := 720.0

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var title := UiKit.label("SETTINGS", 44, UiKit.CREAM)
	title.position = Vector2(64, 48)
	add_child(title)

	_row("MUSIC", 200, Progress.music_on, func(v: bool) -> void:
		Progress.set_music(v)
		if Sfx.has_method("play_music"):
			Sfx.call("play_music", v)
		changed.emit())
	_row("SOUND EFFECTS", 300, Progress.sfx_on, func(v: bool) -> void:
		Progress.set_sfx(v)
		if Sfx.has_method("set_enabled"):
			Sfx.call("set_enabled", v)
		if v and Sfx.has_method("play"):
			Sfx.call("play", "select", 1.0, -6.0)
		changed.emit())
	_row("VIBRATION", 400, Progress.vibration_on, func(v: bool) -> void:
		Progress.set_vibration(v)
		changed.emit())

	var back := UiKit.button("← LODGE", UiKit.PLUM_LIGHT, UiKit.CREAM, 22)
	back.position = Vector2(64, 630)
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)

func _row(name: String, y: int, value: bool, on_toggle: Callable) -> void:
	var label := UiKit.label(name, 30, UiKit.CREAM)
	label.position = Vector2(90, y + 12)
	add_child(label)
	var b := UiKit.button("ON" if value else "OFF", UiKit.MINT if value else UiKit.PLUM_LIGHT,
		UiKit.PLUM if value else UiKit.CREAM, 26)
	b.position = Vector2(560, y)
	b.pressed.connect(func() -> void:
		value = not value
		b.text = "ON" if value else "OFF"
		var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
		if sb:
			sb.bg_color = UiKit.MINT if value else UiKit.PLUM_LIGHT
		b.add_theme_color_override("font_color", UiKit.PLUM if value else UiKit.CREAM)
		on_toggle.call(value))
	add_child(b)

func _draw() -> void:
	for i in 12:
		var t := float(i) / 11.0
		draw_rect(Rect2(0, H * t, W, H / 12 + 1), Color("#2A1B33").lerp(Color("#4A2F5C"), t))
