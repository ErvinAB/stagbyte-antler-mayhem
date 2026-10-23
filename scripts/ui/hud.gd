class_name Hud
extends CanvasLayer
## The whole in-game UI, built in code so the main scene stays readable.
##
## Layout philosophy: the gameplay is the star. The HUD is small, pushed to the
## corners, and the centre of the screen is kept clear. Tutorial hints are
## contextual, animated and fade away — never permanent.
##
## Sprint 5: the intro card, objective list and results panel are driven by the
## active level's data, so one HUD serves every level.

signal retry_pressed
signal continue_pressed

const CREAM := Color("#FFF4E0")
const PLUM := Color("#2A1B33")
const MINT := Color("#7FE0C4")
const YELLOW := Color("#FFD166")
const CORAL := Color("#FF8A6A")
const GOLD := Color("#F2C14E")

const STAGE_NAMES := ["CALM", "MESSY", "CHAOS", "MAYHEM!"]
const STAGE_COLORS := [Color("#8FA6C0"), MINT, YELLOW, CORAL]

var _score_label: Label
var _combo_label: Label
var _stage_label: Label
var _hint_label: Label
var _retry_btn: Button

var _meter: Control
var _stags: Control
var _obj_label: Label
var _obj_flash := 0.0
var _intro: Control
var _intro_tween: Tween
var _intro_title: Label
var _intro_tagline: Label
var _intro_main: Label
var _intro_opt_box: VBoxContainer
var _results: Control
var _res_title: Label
var _res_sub: Label
var _res_lines: Label
var _res_obj: Label
var _res_antlers: Control
var _res_newbest: Label
var _res_unlock: Label

var _obj_defs: Array = []     # [{id, label}] from the active level
var _obj_state := {}

var _target := 5000
var _score := 0
var _mayhem := 0.0
var _stage := 0
var _stags_left := 3
var _stags_total := 3
var _hint_tween: Tween

func _ready() -> void:
	layer = 10
	_build()

# ------------------------------------------------------------------- build ---

func _build() -> void:
	_score_label = _label(Vector2(24, 12), 26)
	_score_label.text = "MAYHEM\n0 / 5,000"

	_combo_label = _label(Vector2(520, 12), 40)
	_combo_label.size = Vector2(240, 0)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.add_theme_color_override("font_color", YELLOW)
	_combo_label.modulate.a = 0.0

	_meter = Control.new()
	_meter.position = Vector2(24, 92)
	_meter.size = Vector2(260, 16)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.draw.connect(_draw_meter)
	add_child(_meter)

	_stage_label = _label(Vector2(24, 110), 16)
	_stage_label.text = "CALM"
	_stage_label.add_theme_color_override("font_color", STAGE_COLORS[0])

	# Optional objectives, kept small and out of the way under the meter.
	_obj_label = _label(Vector2(24, 134), 15)
	_obj_label.add_theme_color_override("font_outline_color", PLUM)
	_obj_label.add_theme_constant_override("outline_size", 6)

	_stags = Control.new()
	_stags.position = Vector2(1020, 18)
	_stags.size = Vector2(220, 44)
	_stags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stags.draw.connect(_draw_stags)
	add_child(_stags)

	_retry_btn = Button.new()
	_retry_btn.text = "RETRY"
	_retry_btn.add_theme_font_size_override("font_size", 18)
	_retry_btn.add_theme_color_override("font_color", PLUM)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CREAM.r, CREAM.g, CREAM.b, 0.85)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	_retry_btn.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = YELLOW
	_retry_btn.add_theme_stylebox_override("hover", sbh)
	_retry_btn.add_theme_stylebox_override("pressed", sbh)
	_retry_btn.anchor_left = 1.0
	_retry_btn.anchor_right = 1.0
	_retry_btn.offset_left = -110.0
	_retry_btn.offset_right = -24.0
	_retry_btn.offset_top = 16.0
	_retry_btn.offset_bottom = 54.0
	_retry_btn.pressed.connect(func(): retry_pressed.emit())
	add_child(_retry_btn)

	_hint_label = _label(Vector2(0, 540), 30)
	_hint_label.size = Vector2(1280, 0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.modulate.a = 0.0

	_build_intro()
	_build_results()

func _process(delta: float) -> void:
	if _obj_flash > 0.0:
		_obj_flash = maxf(0.0, _obj_flash - delta)
		_obj_label.modulate = Color(1, 1, 1, 1).lerp(YELLOW, _obj_flash)
		_obj_label.scale = Vector2.ONE * (1.0 + _obj_flash * 0.12)
		_obj_label.pivot_offset = _obj_label.size * 0.5
		if _obj_flash == 0.0:
			_obj_label.modulate = Color.WHITE
			_obj_label.scale = Vector2.ONE

func _build_intro() -> void:
	_intro = Control.new()
	_intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.visible = false
	add_child(_intro)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = -120.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(center)

	var panel := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.13, 0.08, 0.16, 0.84)
	psb.set_corner_radius_all(18)
	psb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", psb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	_intro_title = Label.new()
	_intro_title.text = "1-1  THE WORKSHOP"
	_intro_title.add_theme_font_size_override("font_size", 40)
	_intro_title.add_theme_color_override("font_color", CREAM)
	_intro_title.add_theme_color_override("font_outline_color", PLUM)
	_intro_title.add_theme_constant_override("outline_size", 10)
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_intro_title)

	_intro_tagline = Label.new()
	_intro_tagline.add_theme_font_size_override("font_size", 17)
	_intro_tagline.add_theme_color_override("font_color", MINT)
	_intro_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_intro_tagline)

	_intro_main = Label.new()
	_intro_main.text = "CAUSE 5,000 MAYHEM"
	_intro_main.add_theme_font_size_override("font_size", 26)
	_intro_main.add_theme_color_override("font_color", YELLOW)
	_intro_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_intro_main)

	var opt_head := Label.new()
	opt_head.text = "OPTIONAL"
	opt_head.add_theme_font_size_override("font_size", 15)
	opt_head.add_theme_color_override("font_color", MINT)
	opt_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(opt_head)

	_intro_opt_box = VBoxContainer.new()
	_intro_opt_box.add_theme_constant_override("separation", 2)
	box.add_child(_intro_opt_box)

	var tap := Label.new()
	tap.text = "TAP TO BEGIN"
	tap.add_theme_font_size_override("font_size", 15)
	tap.add_theme_color_override("font_color", Color(CREAM.r, CREAM.g, CREAM.b, 0.7))
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tap)

func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", CREAM)
	l.add_theme_color_override("font_outline_color", PLUM)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _build_results() -> void:
	_results = Control.new()
	_results.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results.mouse_filter = Control.MOUSE_FILTER_STOP
	_results.visible = false
	add_child(_results)

	var dim := ColorRect.new()
	dim.color = Color(0.10, 0.06, 0.13, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results.add_child(center)

	var panel := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color("#3A2447")
	psb.corner_radius_top_left = 22
	psb.corner_radius_top_right = 22
	psb.corner_radius_bottom_left = 22
	psb.corner_radius_bottom_right = 22
	psb.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", psb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	_res_title = Label.new()
	_res_title.add_theme_font_size_override("font_size", 44)
	_res_title.add_theme_color_override("font_color", CREAM)
	_res_title.add_theme_color_override("font_outline_color", PLUM)
	_res_title.add_theme_constant_override("outline_size", 10)
	_res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_res_title)

	_res_sub = Label.new()
	_res_sub.add_theme_font_size_override("font_size", 16)
	_res_sub.add_theme_color_override("font_color", MINT)
	_res_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_res_sub)

	_res_antlers = Control.new()
	_res_antlers.custom_minimum_size = Vector2(0, 70)
	_res_antlers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_res_antlers.draw.connect(_draw_res_antlers)
	box.add_child(_res_antlers)

	_res_lines = Label.new()
	_res_lines.add_theme_font_size_override("font_size", 24)
	_res_lines.add_theme_color_override("font_color", CREAM)
	_res_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_res_lines)

	_res_newbest = Label.new()
	_res_newbest.add_theme_font_size_override("font_size", 18)
	_res_newbest.add_theme_color_override("font_color", GOLD)
	_res_newbest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_res_newbest.visible = false
	box.add_child(_res_newbest)

	_res_obj = Label.new()
	_res_obj.add_theme_font_size_override("font_size", 19)
	_res_obj.add_theme_color_override("font_color", MINT)
	_res_obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_res_obj)

	_res_unlock = Label.new()
	_res_unlock.visible = false
	_res_unlock.text = "★  NEW CABIN UNLOCKED ON THE MAP  ★"
	_res_unlock.add_theme_font_size_override("font_size", 22)
	_res_unlock.add_theme_color_override("font_color", YELLOW)
	_res_unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_res_unlock)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)

	var retry := _result_button("RETRY", CREAM)
	retry.pressed.connect(func(): retry_pressed.emit())
	row.add_child(retry)

	var world := _result_button("WORLD MAP", MINT)
	world.pressed.connect(func(): continue_pressed.emit())
	row.add_child(world)

func _result_button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", PLUM)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = col.lerp(YELLOW, 0.4)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	return b

# ---------------------------------------------------------------- configure --

func configure_level(level: Dictionary) -> void:
	_target = int(level.get("target", 5000))
	_obj_defs = []
	for o in (level.get("optional", []) as Array):
		_obj_defs.append({"id": str((o as Dictionary).get("id", "")), "label": str((o as Dictionary).get("label", ""))})
	_obj_state = {}
	for d in _obj_defs:
		_obj_state[d["id"]] = false
	if _intro_title:
		_intro_title.text = "%s  %s" % [str(level.get("code", "1-1")), str(level.get("name", ""))]
	if _intro_tagline:
		_intro_tagline.text = str(level.get("tagline", ""))
	if _intro_main:
		_intro_main.text = "CAUSE %s MAYHEM" % _fmt(_target)
	_rebuild_intro_options()
	_refresh_objectives()
	_refresh_score()

func _rebuild_intro_options() -> void:
	if not _intro_opt_box:
		return
	for c in _intro_opt_box.get_children():
		c.queue_free()
	for d in _obj_defs:
		var l := Label.new()
		l.text = "[ ]  %s" % str(d["label"])
		l.add_theme_font_size_override("font_size", 19)
		l.add_theme_color_override("font_color", CREAM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_intro_opt_box.add_child(l)

# ------------------------------------------------------------------ updates --

func set_target(t: int) -> void:
	_target = t
	_refresh_score()
	if _intro_main:
		_intro_main.text = "CAUSE %s MAYHEM" % _fmt(_target)

func set_score(s: int) -> void:
	_score = s
	_refresh_score()

func _refresh_score() -> void:
	_score_label.text = "MAYHEM\n%s / %s" % [_fmt(_score), _fmt(_target)]

func set_stags(left: int, total: int) -> void:
	_stags_left = left
	_stags_total = total
	_stags.queue_redraw()

func set_combo(mult: int) -> void:
	if mult <= 1:
		_combo_label.modulate.a = 0.0
		return
	_combo_label.text = "COMBO x%d" % mult
	_combo_label.modulate.a = 1.0
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(_combo_label, "scale", Vector2(1.2, 1.2), 0.06)
	t.tween_property(_combo_label, "scale", Vector2.ONE, 0.1)

func set_mayhem(value: float, stage: int) -> void:
	_mayhem = value
	_stage = stage
	_meter.queue_redraw()
	_stage_label.text = STAGE_NAMES[stage]
	_stage_label.add_theme_color_override("font_color", STAGE_COLORS[stage])

func show_hint(text: String) -> void:
	_hint_label.text = text
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.set_ignore_time_scale(true)
	_hint_tween.tween_property(_hint_label, "modulate:a", 1.0, 0.25)

func hide_hint() -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.set_ignore_time_scale(true)
	_hint_tween.tween_property(_hint_label, "modulate:a", 0.0, 0.4)

# --------------------------------------------------------------- objectives --

func _refresh_objectives() -> void:
	var lines: Array = []
	for d in _obj_defs:
		var done: bool = bool(_obj_state.get(d["id"], false))
		lines.append("%s  %s" % ["[x]" if done else "[ ]", str(d["label"])])
	_obj_label.text = "\n".join(lines)

func set_objectives_state(state: Dictionary) -> void:
	var gained := false
	for id in state:
		if bool(state[id]) and not bool(_obj_state.get(id, false)):
			gained = true
	_obj_state = state.duplicate()
	_refresh_objectives()
	if gained:
		_obj_flash = 1.0

## Back-compat helper (Cabin 1's perfect/grab objectives).
func set_objectives(perfect: bool, grab: bool) -> void:
	var s := _obj_state.duplicate()
	s["perfect"] = perfect
	s["grab"] = grab
	set_objectives_state(s)

func show_intro() -> void:
	_intro.visible = true
	_intro.modulate.a = 0.0
	if _intro_tween:
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.set_ignore_time_scale(true)
	_intro_tween.tween_property(_intro, "modulate:a", 1.0, 0.22)
	_intro_tween.tween_interval(2.4)
	_intro_tween.tween_property(_intro, "modulate:a", 0.0, 0.5)
	_intro_tween.tween_callback(hide_intro)

func hide_intro() -> void:
	if _intro_tween:
		_intro_tween.kill()
	_intro.visible = false

func is_intro_visible() -> bool:
	return _intro != null and _intro.visible

func show_results(data: Dictionary) -> void:
	var completed: bool = data.get("completed", false)
	_res_title.text = "%s %s" % [str(data.get("level_code", "1-1")), "COMPLETE" if completed else "INCOMPLETE"]
	_res_title.add_theme_color_override("font_color", YELLOW if completed else CORAL)
	var antlers := int(data.get("antlers", 0))
	_res_antlers.set_meta("antlers", antlers)
	_res_antlers.queue_redraw()
	_res_lines.text = "TOTAL MAYHEM:  %s\nBEST:  %s\nBIGGEST COMBO:  x%d\nANTLERS:  %d / 3" % [
		_fmt(int(data.get("score", 0))),
		_fmt(int(data.get("best", 0))),
		int(data.get("biggest_combo", 0)),
		antlers,
	]
	_res_sub.text = str(data.get("level_name", ""))
	if completed and antlers >= 1:
		_res_sub.text = "%s  ·  %s" % [str(data.get("level_name", "")), "ANTLER EARNED"]
	_res_newbest.visible = bool(data.get("new_best", false))
	_res_newbest.text = "★  NEW BEST  ★"

	var obj_lines: Array = ["OBJECTIVES"]
	var objs: Array = data.get("objectives", [])
	if objs.is_empty():
		# legacy fallback (pre-Sprint-5 payload)
		obj_lines.append("%s  Cause %s Mayhem" % ["[x]" if completed else "[ ]", _fmt(_target)])
		obj_lines.append("%s  Land a Perfect Release" % ("[x]" if data.get("obj_perfect", false) else "[ ]"))
		obj_lines.append("%s  Antler Grab (or 5+ chain)" % ("[x]" if data.get("obj_grab", false) else "[ ]"))
	else:
		obj_lines.append("%s  Cause %s Mayhem" % ["[x]" if completed else "[ ]", _fmt(_target)])
		for o in objs:
			var d: Dictionary = o
			obj_lines.append("%s  %s" % ["[x]" if d.get("done", false) else "[ ]", str(d.get("label", ""))])
	_res_obj.text = "\n".join(obj_lines)
	_res_unlock.visible = bool(data.get("unlocked", false))
	_results.visible = true
	_results.modulate.a = 0.0
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(_results, "modulate:a", 1.0, 0.3)
	# little pop on the antler rating
	_res_antlers.scale = Vector2(0.7, 0.7)
	_res_antlers.pivot_offset = Vector2(240, 35)
	var t2 := create_tween()
	t2.set_ignore_time_scale(true)
	t2.tween_property(_res_antlers, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_results() -> void:
	_results.visible = false

func is_results_visible() -> bool:
	return _results.visible

func is_over_ui(pos: Vector2) -> bool:
	if _results.visible:
		return true
	if _retry_btn.visible and _retry_btn.get_global_rect().has_point(pos):
		return true
	return false

# --------------------------------------------------------------------- draw --

func _draw_meter() -> void:
	var w: float = _meter.size.x
	var h: float = _meter.size.y
	_meter.draw_rect(Rect2(0, 0, w, h), Color(PLUM.r, PLUM.g, PLUM.b, 0.55), true)
	var col: Color = STAGE_COLORS[_stage]
	_meter.draw_rect(Rect2(0, 0, w * clampf(_mayhem, 0.0, 1.0), h), col, true)
	for f in [0.25, 0.5, 0.75]:
		_meter.draw_line(Vector2(w * f, 0), Vector2(w * f, h), Color(PLUM.r, PLUM.g, PLUM.b, 0.9), 2.0)

func _draw_stags() -> void:
	var s := _stags
	var icon_w := 56.0
	for i in _stags_total:
		var c := Vector2(28 + i * icon_w, 30)
		var lit := i < _stags_left
		var col := MINT if lit else Color(CREAM.r, CREAM.g, CREAM.b, 0.22)
		draw_antler_icon(s, c, 22.0, col)

static func draw_antler_icon(ci: CanvasItem, c: Vector2, sz: float, col: Color, width_scale: float = 1.0) -> void:
	ci.draw_line(c + Vector2(0, sz * 0.5), c + Vector2(-sz * 0.5, -sz * 0.5), col, 2.6 * width_scale)
	ci.draw_line(c + Vector2(-sz * 0.5, -sz * 0.5), c + Vector2(-sz * 0.75, -sz * 0.1), col, 2.2 * width_scale)
	ci.draw_line(c + Vector2(-sz * 0.5, -sz * 0.5), c + Vector2(-sz * 0.2, -sz * 0.8), col, 2.2 * width_scale)
	ci.draw_line(c + Vector2(0, sz * 0.5), c + Vector2(sz * 0.5, -sz * 0.5), col, 2.6 * width_scale)
	ci.draw_line(c + Vector2(sz * 0.5, -sz * 0.5), c + Vector2(sz * 0.75, -sz * 0.1), col, 2.2 * width_scale)
	ci.draw_line(c + Vector2(sz * 0.5, -sz * 0.5), c + Vector2(sz * 0.2, -sz * 0.8), col, 2.2 * width_scale)

func _draw_res_antlers() -> void:
	var earned := int(_res_antlers.get_meta("antlers", 0))
	var w: float = _res_antlers.size.x
	if w <= 0.0:
		w = 480.0
	var start := (w - 3.0 * 70.0) * 0.5 + 35.0
	for i in 3:
		var c := Vector2(start + i * 70.0, 40)
		var col := GOLD if i < earned else Color(CREAM.r, CREAM.g, CREAM.b, 0.18)
		draw_antler_icon(_res_antlers, c, 34.0, col)

func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
