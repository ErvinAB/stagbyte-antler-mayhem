class_name UiKit
extends RefCounted
## Shared meta-UI helpers, so the Lodge / Map / Closet / Settings screens share
## one palette and one set of touch-sized, custom-styled controls instead of
## default Godot widgets.

const PLUM := Color("#2A1B33")
const PLUM_DEEP := Color("#1E1430")
const PLUM_MID := Color("#3A2447")
const PLUM_LIGHT := Color("#4A2F5C")
const WOOD := Color("#8A5330")
const WOOD_DARK := Color("#5E3A22")
const WOOD_LIGHT := Color("#B0703C")
const CREAM := Color("#FFF4E0")
const MINT := Color("#7FE0C4")
const YELLOW := Color("#FFD166")
const CORAL := Color("#FF8A6A")
const GOLD := Color("#F2C14E")

const TOUCH_MIN := Vector2(150, 64)   # comfortable landscape touch target

static func button(text: String, bg: Color, fg: Color = Color("#2A1B33"), font_size: int = 26) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", fg)
	b.custom_minimum_size = Vector2(180, 62)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	# a slightly darker lip gives the button a chunky, hand-made feel
	sb.border_width_bottom = 5
	sb.border_color = bg.darkened(0.28)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = bg.lightened(0.12)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	var sbd := sb.duplicate()
	sbd.bg_color = bg.darkened(0.2)
	b.add_theme_stylebox_override("disabled", sbd)
	b.add_theme_color_override("font_disabled_color", Color(fg.r, fg.g, fg.b, 0.4))
	b.focus_mode = Control.FOCUS_NONE
	return b

static func label(text: String, size: int, col: Color = CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l
