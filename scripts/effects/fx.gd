class_name Fx
extends Node2D
## Mayhem feedback: impact particles, debris, score popups, combo banner,
## restrained camera shake and very short time punches.
## All effects are pooled / auto-freed and are safe to nuke on retry.

const CREAM := Color("#FFF4E0")
const CORAL := Color("#FF8A6A")
const PEACH := Color("#FFB48A")
const YELLOW := Color("#FFD166")

var trauma := 0.0
var _particle_tex: Texture2D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_particle_tex = _make_particle_texture()

func _process(delta: float) -> void:
	trauma = maxf(0.0, trauma - delta * 1.6)

func shake(power: float) -> void:
	trauma = clampf(trauma + power, 0.0, 1.0)

func shake_offset() -> Vector2:
	var amt := trauma * trauma * 16.0
	return Vector2(_rng.randf_range(-amt, amt), _rng.randf_range(-amt, amt))

func clear() -> void:
	trauma = 0.0
	for c in get_children():
		c.queue_free()

# ------------------------------------------------------------------ effects --

func impact(pos: Vector2, power: float, color: Color = PEACH) -> void:
	var p := _spawn_particles(pos, color, int(clampf(6.0 + power * 10.0, 6, 24)))
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 240.0 * clampf(power, 0.5, 1.8)
	p.lifetime = 0.45 + power * 0.15
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0

func debris(pos: Vector2, color: Color = CORAL, amount: int = 18) -> void:
	var p := _spawn_particles(pos, color, amount)
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 420.0
	p.lifetime = 0.7
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 2.5
	p.scale_amount_max = 6.5
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.color = color

func _spawn_particles(pos: Vector2, color: Color, amount: int) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.texture = _particle_tex
	p.emitting = true
	p.one_shot = true
	p.amount = amount
	p.explosiveness = 0.9
	p.randomness = 0.7
	p.spread = 180.0
	p.gravity = Vector2(0, 700)
	p.color = color
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 6.0
	add_child(p)
	# auto free
	var t := get_tree().create_timer(1.6, true, false, true)
	t.timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())
	return p

func _make_particle_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex

# ------------------------------------------------------------------- popups --

func popup(text: String, pos: Vector2, color: Color = CREAM, size: int = 26) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#2A1B33"))
	l.add_theme_constant_override("outline_size", 6)
	l.position = pos
	l.z_index = 100
	add_child(l)
	l.rotation = _rng.randf_range(-0.12, 0.12)
	l.pivot_offset = l.get_minimum_size() * 0.5
	var t := create_tween()
	t.set_parallel(true)
	t.set_ignore_time_scale(true)
	t.tween_property(l, "position", pos + Vector2(_rng.randf_range(-14, 14), -70), 0.7)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	t.chain().tween_callback(l.queue_free)

func banner(text: String, color: Color = YELLOW, size: int = 68) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#2A1B33"))
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(1280, 0)
	l.position = Vector2(0, 210)
	l.z_index = 200
	add_child(l)
	l.pivot_offset = Vector2(640, size * 0.5)
	l.scale = Vector2(0.4, 0.4)
	l.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.set_ignore_time_scale(true)
	t.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 1.0, 0.12)
	t.chain().tween_interval(0.45)
	t.chain().tween_property(l, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(l.queue_free)

func time_punch(scale: float = 0.75, duration: float = 0.08) -> void:
	Engine.time_scale = scale
	var t := get_tree().create_timer(duration, true, false, true)
	t.timeout.connect(func():
		if is_inside_tree():
			var tw := create_tween()
			tw.set_ignore_time_scale(true)
			tw.tween_property(Engine, "time_scale", 1.0, 0.18))
