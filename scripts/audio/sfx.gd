class_name SfxPlayer
extends Node
## Procedural SFX — no external audio assets, fully original synthesized sounds.
## License: original work, generated in-engine (no third-party audio).

const RATE := 22050

var enabled := true          # mirrors Progress.sfx_on (settings)
var _music_on := false
var _music_player: AudioStreamPlayer

var _streams := {}
var _players := []
var _next := 0
var _last_play := {}

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

	_streams["whoosh"] = _whoosh()
	_streams["stretch"] = _stretch()
	_streams["hook"] = _hook()
	_streams["creak"] = _creak()
	_streams["thud"] = _thud(0.55)
	_streams["crate"] = _thud(0.9)
	_streams["break"] = _break_sfx()
	_streams["combo"] = _combo()
	_streams["retry"] = _retry()
	_streams["launch"] = _launch()
	_streams["golden"] = _golden()
	_streams["mayhem"] = _mayhem()
	_streams["bounce"] = _bounce()
	_streams["snap"] = _snap()
	_streams["rope"] = _rope()
	_streams["blast"] = _blast()
	_streams["objective"] = _objective()
	_streams["menu"] = _menu()
	_streams["select"] = _select()
	_streams["unlock"] = _unlock()
	_streams["antler"] = _antler()
	_streams["start"] = _start()
	_streams["result"] = _result()

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = -16.0
	add_child(_music_player)
	_music_player.stream = _music()

func _exit_tree() -> void:
	# stop any in-flight playback so streams are released cleanly on quit
	for p in _players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	if is_instance_valid(_music_player):
		_music_player.stop()

func set_enabled(v: bool) -> void:
	enabled = v
	if not v:
		for p in _players:
			if is_instance_valid(p):
				p.stop()

func play_music(on: bool) -> void:
	if not is_instance_valid(_music_player):
		return
	if on and not _music_player.playing:
		_music_player.play()
	elif not on:
		_music_player.stop()

func play(name: String, pitch: float = 1.0, volume_db: float = -6.0) -> void:
	if not enabled or not _streams.has(name):
		return
	# Throttle identical sounds fired in the same frame (collision spam).
	var now := Time.get_ticks_msec()
	if _last_play.has(name) and now - _last_play[name] < 40:
		return
	_last_play[name] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()

# ---------------------------------------------------------------- synthesis --

func _wav(frames: PackedFloat32Array) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var data := PackedByteArray()
	data.resize(frames.size() * 2)
	for i in frames.size():
		data.encode_s16(i * 2, int(clampf(frames[i], -1.0, 1.0) * 32767.0))
	w.data = data
	return w

func _env(i: int, n: int, attack: float, curve: float) -> float:
	var t := float(i) / float(n)
	var a := minf(t / maxf(attack, 0.0001), 1.0)
	var d := pow(1.0 - t, curve)
	return a * d

func _noise() -> float:
	return randf() * 2.0 - 1.0

func _whoosh() -> AudioStreamWAV:
	var n := int(RATE * 0.28)
	var f := PackedFloat32Array()
	f.resize(n)
	var last := 0.0
	for i in n:
		var t := float(i) / n
		var freq := lerpf(500.0, 1800.0, t)
		last = lerpf(last, _noise(), 0.25 * (1.0 - t * 0.5))
		var body := sin(TAU * freq * t / RATE) * 0.25
		f[i] = (last * 0.5 + body) * _env(i, n, 0.12, 1.6) * 0.8
	return _wav(f)

func _stretch() -> AudioStreamWAV:
	var n := int(RATE * 0.22)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var freq := lerpf(220.0, 660.0, t)
		f[i] = sin(TAU * freq * t / RATE) * _env(i, n, 0.05, 1.2) * 0.5
	return _wav(f)

func _hook() -> AudioStreamWAV:
	var n := int(RATE * 0.14)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var freq := lerpf(900.0, 1500.0, t)
		var v := signf(sin(TAU * freq * t / RATE))
		f[i] = v * _env(i, n, 0.01, 2.4) * 0.35
	return _wav(f)

func _creak() -> AudioStreamWAV:
	var n := int(RATE * 0.35)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var wobble := sin(TAU * lerpf(140.0, 320.0, t) * t / RATE)
		f[i] = (wobble * 0.6 + _noise() * 0.15) * _env(i, n, 0.2, 1.4) * 0.3
	return _wav(f)

func _thud(pitch: float) -> AudioStreamWAV:
	var n := int(RATE * 0.25)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var freq := lerpf(160.0 * pitch, 55.0 * pitch, t)
		f[i] = (sin(TAU * freq * t / RATE) * 0.9 + _noise() * 0.2) * _env(i, n, 0.005, 2.2) * 0.9
	return _wav(f)

func _break_sfx() -> AudioStreamWAV:
	var n := int(RATE * 0.4)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var crack := 0.0
		if randf() < 0.06 + (1.0 - t) * 0.3:
			crack = _noise()
		f[i] = (crack * 0.8 + sin(TAU * 300.0 * t / RATE) * 0.2) * _env(i, n, 0.004, 1.8) * 0.8
	return _wav(f)

func _combo() -> AudioStreamWAV:
	var n := int(RATE * 0.3)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var s := 0.0
		if t < 0.5:
			s = sin(TAU * 660.0 * t / RATE)
		else:
			s = sin(TAU * 990.0 * t / RATE)
		f[i] = s * _env(i, n, 0.02, 1.2) * 0.45
	return _wav(f)

func _retry() -> AudioStreamWAV:
	var n := int(RATE * 0.2)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var freq := lerpf(660.0, 330.0, t)
		f[i] = sin(TAU * freq * t / RATE) * _env(i, n, 0.03, 1.6) * 0.5
	return _wav(f)

func _launch() -> AudioStreamWAV:
	var n := int(RATE * 0.18)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var freq := lerpf(300.0, 500.0, t)
		f[i] = (sin(TAU * freq * t / RATE) + _noise() * 0.3) * _env(i, n, 0.02, 1.8) * 0.6
	return _wav(f)

func _golden() -> AudioStreamWAV:
	# bright ascending sparkle for the golden acorn
	var n := int(RATE * 0.5)
	var f := PackedFloat32Array()
	f.resize(n)
	var notes := [660.0, 880.0, 1320.0]
	for i in n:
		var t := float(i) / n
		var idx := clampi(int(t * notes.size()), 0, notes.size() - 1)
		var freq: float = notes[idx]
		var s := sin(TAU * freq * t / RATE) * 0.5 + sin(TAU * freq * 2.0 * t / RATE) * 0.15
		f[i] = s * _env(i, n, 0.01, 1.2) * 0.7
	return _wav(f)

func _mayhem() -> AudioStreamWAV:
	# short triumphant two-note hit for reaching MAYHEM
	var n := int(RATE * 0.34)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var s := 0.0
		s += sin(TAU * 523.25 * t / RATE) * 0.4
		s += sin(TAU * 784.0 * (t + 0.05) / RATE) * 0.35
		s += sin(TAU * 1046.5 * (t + 0.1) / RATE) * 0.25
		f[i] = s * _env(i, n, 0.02, 1.4) * 0.7
	return _wav(f)

func _bounce() -> AudioStreamWAV:
	# springy "boing": pitch sweeps up then down
	var n := int(RATE * 0.26)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var freq := 220.0 + sin(t * PI) * 520.0
		f[i] = sin(TAU * freq * t / RATE) * _env(i, n, 0.01, 1.0) * 0.55
	return _wav(f)

func _snap() -> AudioStreamWAV:
	# dry wooden SNAP: short bright crack
	var n := int(RATE * 0.18)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var burst := 0.0
		if t < 0.25:
			burst = _noise()
		var tone := sin(TAU * 1400.0 * t / RATE) * 0.4
		f[i] = (burst * 0.8 + tone) * _env(i, n, 0.002, 3.0) * 0.8
	return _wav(f)

func _rope() -> AudioStreamWAV:
	# taut string twang with a fraying tail
	var n := int(RATE * 0.3)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var freq := lerpf(900.0, 300.0, t)
		var body := sin(TAU * freq * t / RATE)
		f[i] = (body * 0.6 + _noise() * 0.2 * (1.0 - t)) * _env(i, n, 0.005, 2.0) * 0.6
	return _wav(f)

func _blast() -> AudioStreamWAV:
	# big cartoon boom: low thump + noise whoomph
	var n := int(RATE * 0.55)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var low := sin(TAU * lerpf(180.0, 40.0, t) * t / RATE) * 0.9
		var noise := _noise() * (1.0 - t) * 0.5
		f[i] = (low + noise) * _env(i, n, 0.004, 1.6) * 0.9
	return _wav(f)

func _objective() -> AudioStreamWAV:
	# bright, satisfied two-note check-off chime
	var n := int(RATE * 0.26)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var s := 0.0
		if t < 0.5:
			s = sin(TAU * 880.0 * t / RATE)
		else:
			s = sin(TAU * 1320.0 * t / RATE)
		f[i] = s * _env(i, n, 0.02, 1.5) * 0.5
	return _wav(f)

# ------------------------------------------------------------ menu / meta --
# These extend the same synthesized palette for the Lodge, Map, Closet and
# Settings so the meta layer sounds like the same game as the cabins.

func _menu() -> AudioStreamWAV:
	# soft UI tick used on every screen swap
	var n := int(RATE * 0.09)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		f[i] = sin(TAU * lerpf(520.0, 380.0, t) * t / RATE) * _env(i, n, 0.01, 2.0) * 0.35
	return _wav(f)

func _select() -> AudioStreamWAV:
	# capable confirm: two quick rising notes
	var n := int(RATE * 0.2)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var freq := 700.0 if t < 0.5 else 1050.0
		f[i] = sin(TAU * freq * t / RATE) * _env(i, n, 0.02, 1.6) * 0.5
	return _wav(f)

func _unlock() -> AudioStreamWAV:
	# three-note arpeggio for a freshly opened cabin
	var n := int(RATE * 0.5)
	var f := PackedFloat32Array()
	f.resize(n)
	var notes := [523.25, 659.25, 784.0, 1046.5]
	for i in n:
		var t := float(i) / n
		var idx := clampi(int(t * notes.size()), 0, notes.size() - 1)
		var freq: float = notes[idx]
		f[i] = sin(TAU * freq * t / RATE) * _env(i, n, 0.01, 1.2) * 0.55
	return _wav(f)

func _antler() -> AudioStreamWAV:
	# single bright "ding" for earning an antler
	var n := int(RATE * 0.35)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var s := sin(TAU * 1568.0 * t / RATE) * 0.5 + sin(TAU * 2349.0 * t / RATE) * 0.2
		f[i] = s * _env(i, n, 0.005, 1.8) * 0.6
	return _wav(f)

func _start() -> AudioStreamWAV:
	# upbeat "three, two, one, fling"
	var n := int(RATE * 0.42)
	var f := PackedFloat32Array()
	f.resize(n)
	var notes := [392.0, 523.25, 659.25]
	for i in n:
		var t := float(i) / n
		var idx := clampi(int(t * notes.size()), 0, notes.size() - 1)
		var freq: float = notes[idx]
		var s := sin(TAU * freq * t / RATE) * 0.5 + signf(sin(TAU * freq * t / RATE)) * 0.08
		f[i] = s * _env(i, n, 0.01, 1.3) * 0.6
	return _wav(f)

func _result() -> AudioStreamWAV:
	# warm resolving major chord with a sparkle on top
	var n := int(RATE * 1.1)
	var f := PackedFloat32Array()
	f.resize(n)
	for i in n:
		var t := float(i) / n
		var s := 0.0
		s += sin(TAU * 392.0 * t / RATE) * 0.3
		s += sin(TAU * 493.88 * t / RATE) * 0.25
		s += sin(TAU * 587.33 * t / RATE) * 0.25
		s += sin(TAU * 1174.66 * t / RATE) * 0.12 * maxf(0.0, 1.0 - t * 2.0)
		f[i] = s * _env(i, n, 0.03, 1.1) * 0.7
	return _wav(f)

# ------------------------------------------------------------------- music --

func _music() -> AudioStreamWAV:
	## A slow, lo-fi lounge loop: simple Am–F–C–G pad with a soft bass pulse and
	## occasional twinkle. Fully generated, loops seamlessly, quiet on purpose so
	## it never fights the gameplay SFX.
	var bar := 1.6
	var bars := 8
	var n := int(RATE * bar * bars)
	var f := PackedFloat32Array()
	f.resize(n)
	var chords := [
		[220.0, 261.63, 329.63],  # Am
		[174.61, 220.0, 261.63],  # F
		[261.63, 329.63, 392.0],  # C
		[196.0, 246.94, 293.66],  # G
	]
	for i in n:
		var t := float(i) / RATE
		var bar_i := int(t / bar) % (bars / 2)
		var chord: Array = chords[bar_i % chords.size()]
		var s := 0.0
		for fr in chord:
			var freq: float = fr
			s += sin(TAU * freq * t) * 0.08
			s += sin(TAU * freq * 2.0 * t) * 0.02
		# soft bass pulse on each beat
		var beat := fmod(t, bar * 0.5)
		var pulse := exp(-beat * 6.0)
		var bass: float = chord[0] * 0.5
		s += sin(TAU * bass * t) * pulse * 0.18
		# gentle volume swell so the loop breathes
		var swell := 0.75 + 0.25 * sin(TAU * t / (bar * bars))
		f[i] = s * swell * 0.5
	var w := _wav(f)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w
