extends Node
## Sound effects synthesized in code at startup (no audio files needed).
## Usage: sfx.play("explode"), sfx.play("shoot_e", -8.0)

const RATE := 22050
const VOICES := 14

var streams := {}
var players: Array = []
var last_play := {}
var muted := false


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	build_all()


func play(sound: String, vol_db := 0.0, pitch_jitter := 0.06) -> void:
	if muted or not streams.has(sound):
		return
	var now := Time.get_ticks_msec()
	if now - int(last_play.get(sound, -1000)) < 45:
		return
	last_play[sound] = now
	var best: AudioStreamPlayer = null
	for p in players:
		if not p.playing:
			best = p
			break
	if best == null:
		best = players[randi() % players.size()]
	best.stream = streams[sound]
	best.volume_db = vol_db
	best.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	best.play()


func set_muted(m: bool) -> void:
	muted = m
	if muted:
		for p in players:
			p.stop()


# ---------------------------------------------------------------- synthesis helpers

func to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	# short fade-out so no sound ends with a click
	var fade := mini(330, samples.size())
	for i in fade:
		samples[samples.size() - 1 - i] *= float(i) / fade
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


func square(phase: float) -> float:
	return 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0


## Frequency sweep tone. wave: "sine", "square", "tri"
func sweep(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, amp: float, wave := "square", decay := 3.0) -> void:
	var phase := 0.0
	var n := int(dur * RATE)
	var s0 := int(start * RATE)
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += f / RATE
		var v := 0.0
		match wave:
			"sine": v = sin(phase * TAU)
			"tri": v = 1.0 - 4.0 * absf(fposmod(phase, 1.0) - 0.5)
			_: v = square(phase)
		var env := exp(-decay * t) * minf(1.0, i / 60.0)
		var idx := s0 + i
		if idx < b.size():
			b[idx] += v * amp * env


## Low-passed noise burst; cutoff goes from c0 to c1 (0..1 smoothing factors)
func noise(b: PackedFloat32Array, start: float, dur: float, amp: float, c0 := 0.5, c1 := 0.05, decay := 4.0) -> void:
	var n := int(dur * RATE)
	var s0 := int(start * RATE)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		var c := lerpf(c0, c1, t)
		y += (randf_range(-1.0, 1.0) - y) * c
		var env := exp(-decay * t) * minf(1.0, i / 30.0)
		var idx := s0 + i
		if idx < b.size():
			b[idx] += y * amp * env * 2.0


func notes(b: PackedFloat32Array, freqs: Array, step: float, amp: float, wave := "square", hold := 1.0) -> void:
	for k in freqs.size():
		if freqs[k] > 0.0:
			sweep(b, k * step, step * hold, freqs[k], freqs[k], amp, wave, 2.5)


func normalize(b: PackedFloat32Array, peak := 0.9) -> PackedFloat32Array:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in b.size():
		b[i] *= k
	return b


func build_all() -> void:
	var b: PackedFloat32Array
	# player shot: bright "pew"
	b = buf(0.14)
	sweep(b, 0.0, 0.14, 1100.0, 260.0, 0.5, "square", 4.0)
	noise(b, 0.0, 0.05, 0.3, 0.8, 0.3, 6.0)
	streams["shoot_p"] = to_stream(normalize(b, 0.55))
	# enemy shot: lower thud-pew
	b = buf(0.14)
	sweep(b, 0.0, 0.14, 620.0, 160.0, 0.5, "square", 4.0)
	noise(b, 0.0, 0.05, 0.3, 0.5, 0.2, 6.0)
	streams["shoot_e"] = to_stream(normalize(b, 0.45))
	# bullet hits something soft
	b = buf(0.08)
	noise(b, 0.0, 0.08, 0.5, 0.6, 0.1, 5.0)
	streams["hit"] = to_stream(normalize(b, 0.4))
	# brick cracks / breaks
	b = buf(0.3)
	noise(b, 0.0, 0.3, 0.6, 0.5, 0.03, 5.0)
	sweep(b, 0.0, 0.12, 140.0, 60.0, 0.5, "sine", 4.0)
	streams["brick"] = to_stream(normalize(b, 0.6))
	# steel ping
	b = buf(0.25)
	sweep(b, 0.0, 0.25, 1500.0, 1450.0, 0.4, "sine", 6.0)
	sweep(b, 0.0, 0.2, 2250.0, 2200.0, 0.25, "sine", 8.0)
	noise(b, 0.0, 0.02, 0.3, 0.9, 0.5, 4.0)
	streams["steel"] = to_stream(normalize(b, 0.45))
	# armour clank (enemy hit but not destroyed)
	b = buf(0.18)
	sweep(b, 0.0, 0.18, 420.0, 380.0, 0.4, "square", 9.0)
	noise(b, 0.0, 0.06, 0.4, 0.7, 0.2, 5.0)
	streams["clank"] = to_stream(normalize(b, 0.5))
	# tank explosion
	b = buf(0.7)
	noise(b, 0.0, 0.7, 0.8, 0.35, 0.02, 4.0)
	sweep(b, 0.0, 0.45, 120.0, 35.0, 0.7, "sine", 3.0)
	streams["explode"] = to_stream(normalize(b, 0.85))
	# big explosion (bomb, artillery, mine)
	b = buf(1.0)
	noise(b, 0.0, 1.0, 0.9, 0.25, 0.01, 3.0)
	sweep(b, 0.0, 0.7, 90.0, 28.0, 0.9, "sine", 2.5)
	streams["boom"] = to_stream(normalize(b, 0.95))
	# player hit: alarm buzz
	b = buf(0.3)
	sweep(b, 0.0, 0.3, 260.0, 110.0, 0.5, "square", 2.0)
	noise(b, 0.0, 0.1, 0.4, 0.6, 0.1, 4.0)
	streams["player_hit"] = to_stream(normalize(b, 0.7))
	# item dropped: rising sparkle
	b = buf(0.35)
	notes(b, [880.0, 1175.0, 1568.0], 0.09, 0.3, "tri", 1.4)
	streams["item_drop"] = to_stream(normalize(b, 0.5))
	# item picked up: happy arpeggio
	b = buf(0.42)
	notes(b, [523.0, 659.0, 784.0, 1047.0], 0.08, 0.3, "square", 1.6)
	streams["pickup"] = to_stream(normalize(b, 0.55))
	# item stolen by a thief: sad descending
	b = buf(0.55)
	notes(b, [784.0, 622.0, 523.0, 392.0], 0.11, 0.3, "square", 1.4)
	streams["steal"] = to_stream(normalize(b, 0.55))
	# mine placed: short beep
	b = buf(0.08)
	sweep(b, 0.0, 0.08, 1800.0, 1800.0, 0.3, "sine", 6.0)
	streams["mine"] = to_stream(normalize(b, 0.3))
	# artillery shell whistle
	b = buf(1.3)
	sweep(b, 0.0, 1.3, 2000.0, 700.0, 0.3, "sine", 0.6)
	streams["whistle"] = to_stream(normalize(b, 0.25))
	# flamethrower crackle
	b = buf(0.35)
	noise(b, 0.0, 0.35, 0.5, 0.15, 0.08, 1.5)
	for k in 6:
		noise(b, randf() * 0.3, 0.02, 0.5, 0.9, 0.6, 3.0)
	streams["flame"] = to_stream(normalize(b, 0.4))
	# enemy spawn: soft rising whoosh
	b = buf(0.35)
	sweep(b, 0.0, 0.35, 200.0, 700.0, 0.25, "sine", 2.0)
	noise(b, 0.0, 0.35, 0.15, 0.05, 0.3, 2.0)
	streams["spawn"] = to_stream(normalize(b, 0.3))
	# freeze: icy shimmer
	b = buf(0.6)
	notes(b, [1568.0, 2093.0, 1760.0, 2349.0, 2637.0], 0.08, 0.25, "sine", 2.5)
	streams["freeze"] = to_stream(normalize(b, 0.45))
	# ui click
	b = buf(0.05)
	sweep(b, 0.0, 0.05, 1200.0, 900.0, 0.3, "square", 8.0)
	streams["click"] = to_stream(normalize(b, 0.3))
	# jingles
	b = buf(0.9)
	notes(b, [392.0, 523.0, 659.0, 784.0], 0.15, 0.3, "square", 1.3)
	sweep(b, 0.6, 0.3, 1047.0, 1047.0, 0.25, "tri", 2.0)
	streams["level_start"] = to_stream(normalize(b, 0.55))
	b = buf(1.5)
	notes(b, [523.0, 523.0, 523.0, 659.0, 0.0, 784.0, 659.0, 784.0], 0.13, 0.3, "square", 1.1)
	sweep(b, 1.05, 0.45, 1047.0, 1047.0, 0.3, "square", 2.0)
	streams["level_clear"] = to_stream(normalize(b, 0.6))
	b = buf(1.6)
	notes(b, [392.0, 370.0, 349.0, 330.0], 0.3, 0.3, "square", 1.2)
	sweep(b, 1.2, 0.4, 262.0, 200.0, 0.3, "square", 2.0)
	streams["game_over"] = to_stream(normalize(b, 0.6))
	b = buf(2.0)
	notes(b, [523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0, 1319.0, 1568.0], 0.15, 0.3, "square", 1.2)
	sweep(b, 1.2, 0.8, 2093.0, 2093.0, 0.25, "tri", 1.5)
	streams["victory"] = to_stream(normalize(b, 0.6))
