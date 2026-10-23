extends Node
## App shell: the persistent root of the game.
##
## Owns the screen stack (Lodge -> World Map -> Level, plus Closet/Settings),
## a short fade transition, background music, and the debug build tools. Levels
## themselves never know about each other; they just ask "/root/App" to
## navigate, so any level can be run standalone for testing.

const LODGE := "res://scenes/meta/lodge.tscn"
const WORLD_MAP := "res://scenes/meta/world_map.tscn"
const CLOSET := "res://scenes/meta/closet.tscn"
const SETTINGS := "res://scenes/meta/settings.tscn"
const LEVEL := "res://scenes/main/main.tscn"

var _screen: Node = null
var _curtain: ColorRect
var _busy := false
var _debug_panel: CanvasLayer
var _current := ""
var level_id := "cabin_1"

func _ready() -> void:
	_build_curtain()
	_build_debug()
	_apply_settings()
	if Sfx.has_method("play_music"):
		Sfx.call("play_music", Progress.music_on)
	goto_lodge()

func _build_curtain() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_curtain = ColorRect.new()
	_curtain.color = Color("#1E1430")
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_curtain)

func _build_debug() -> void:
	_debug_panel = CanvasLayer.new()
	_debug_panel.layer = 90
	_debug_panel.visible = false
	add_child(_debug_panel)
	var box := HBoxContainer.new()
	box.position = Vector2(16, 660)
	box.add_theme_constant_override("separation", 10)
	_debug_panel.add_child(box)
	var unlock := UiKit.button("UNLOCK ALL", UiKit.MINT, UiKit.PLUM, 20)
	unlock.pressed.connect(_debug_unlock_all)
	box.add_child(unlock)
	var complete := UiKit.button("+10000 SCORE", UiKit.YELLOW, UiKit.PLUM, 20)
	complete.pressed.connect(_debug_score)
	box.add_child(complete)
	var reset := UiKit.button("RESET SAVE", UiKit.CORAL, UiKit.CREAM, 20)
	reset.pressed.connect(_debug_reset)
	box.add_child(reset)

func _apply_settings() -> void:
	if Sfx.has_method("set_enabled"):
		Sfx.call("set_enabled", Progress.sfx_on)

# -------------------------------------------------------------- navigation --

func goto_lodge() -> void:
	_swap(LODGE, func(s: Node) -> void:
		s.play_pressed.connect(goto_map)
		s.closet_pressed.connect(goto_closet)
		s.settings_pressed.connect(goto_settings))

func goto_map() -> void:
	_swap(WORLD_MAP, func(s: Node) -> void:
		s.level_chosen.connect(goto_level)
		s.back_pressed.connect(goto_lodge))

func goto_closet() -> void:
	_swap(CLOSET, func(s: Node) -> void:
		s.back_pressed.connect(goto_lodge))

func goto_settings() -> void:
	_swap(SETTINGS, func(s: Node) -> void:
		s.back_pressed.connect(goto_lodge)
		s.changed.connect(_apply_settings))

func goto_level(id: String) -> void:
	level_id = id
	_swap(LEVEL, func(s: Node) -> void:
		s.level_id = id)

func reload_level() -> void:
	goto_level(level_id)

func _swap(path: String, setup: Callable) -> void:
	if _busy:
		return
	_busy = true
	_current = path
	_debug_panel.visible = false
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_curtain, "modulate:a", 1.0, 0.18)
	tween.tween_callback(func() -> void:
		if _screen and is_instance_valid(_screen):
			_screen.queue_free()
		var packed := load(path) as PackedScene
		var next := packed.instantiate()
		setup.call(next)
		_screen = next
		add_child(next)
		if Sfx.has_method("play"):
			Sfx.call("play", "menu", 1.0, -10.0))
	tween.tween_property(_curtain, "modulate:a", 0.0, 0.22)
	tween.tween_callback(func() -> void:
		_busy = false
		_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE)

# ------------------------------------------------------------------ input --

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3 and _current != LEVEL:
			_debug_panel.visible = not _debug_panel.visible

# ------------------------------------------------------------------ debug --

func _debug_unlock_all() -> void:
	Progress.set_debug_unlock(true)
	if _screen and _screen.has_method("refresh"):
		_screen.call("refresh")

func _debug_score() -> void:
	var best: int = Progress.best_score_for(level_id) + 10000
	var antlers: int = Progress.best_antlers_for(level_id)
	Progress.record_level_run(level_id, best, antlers, [])
	if _screen and _screen.has_method("refresh"):
		_screen.call("refresh")

func _debug_reset() -> void:
	Progress.reset_save()
	goto_lodge()
