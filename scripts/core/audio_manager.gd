extends Node

var sfx_move: AudioStream
var sfx_capture: AudioStream
var sfx_check: AudioStream
var sfx_game_over: AudioStream
var sfx_ui_click: AudioStream

var player_pool: Array[AudioStreamPlayer] = []
var pool_index: int = 0

func _ready() -> void:
	# Buat 6 channel AudioStreamPlayer agar efek suara tidak saling memotong
	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		player_pool.append(p)
	
	# Muat file eksternal jika tersedia, atau generate suara prosedural bawaan
	sfx_move = _load_or_generate("res://assets/audio/move.wav", _gen_stone_tap(190.0, 0.09, 0.45))
	sfx_capture = _load_or_generate("res://assets/audio/capture.wav", _gen_capture_impact())
	sfx_check = _load_or_generate("res://assets/audio/check.wav", _gen_gong_warning())
	sfx_game_over = _load_or_generate("res://assets/audio/gameover.wav", _gen_victory_chime())
	sfx_ui_click = _load_or_generate("res://assets/audio/click.wav", _gen_stone_tap(420.0, 0.045, 0.25))

func play_move() -> void:
	_play_stream(sfx_move, randf_range(0.95, 1.05))

func play_capture() -> void:
	_play_stream(sfx_capture, randf_range(0.94, 1.04))

func play_check() -> void:
	_play_stream(sfx_check, 1.0)

func play_game_over() -> void:
	_play_stream(sfx_game_over, 1.0)

func play_ui_click() -> void:
	_play_stream(sfx_ui_click, randf_range(0.98, 1.03))

func _play_stream(stream: AudioStream, pitch: float) -> void:
	if stream == null:
		return
	var player := player_pool[pool_index]
	pool_index = (pool_index + 1) % player_pool.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.play()

func _load_or_generate(path: String, fallback: AudioStreamWAV) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	return fallback

# ==============================================================================
# GENERATOR SINTESIS SUARA PROSEDURAL (16-bit Mono 22050 Hz)
# ==============================================================================
func _create_wav_buffer(samples: PackedFloat32Array, mix_rate: int = 22050) -> AudioStreamWAV:
	var byte_data := PackedByteArray()
	byte_data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var clamped := clampf(samples[i], -1.0, 1.0)
		var pcm16 := int(clamped * 32767.0)
		byte_data[i * 2] = pcm16 & 0xFF
		byte_data[i * 2 + 1] = (pcm16 >> 8) & 0xFF
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = byte_data
	return wav

# 1. Ketukan bidak kayu/batu candi saat mendarat
func _gen_stone_tap(base_freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	for i in range(count):
		var t := float(i) / rate
		var env := exp(-t * 48.0)
		var freq := base_freq * (1.0 - (t / duration) * 0.45)
		var tone := sin(TAU * freq * t) + 0.35 * sin(TAU * freq * 2.4 * t)
		samples[i] = tone * env * volume
	
	return _create_wav_buffer(samples, rate)

# 2. Benturan berat saat menawan bidak lawan
func _gen_capture_impact() -> AudioStreamWAV:
	var rate := 22050
	var duration := 0.22
	var count := int(rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	for i in range(count):
		var t := float(i) / rate
		var env := exp(-t * 22.0)
		var low_thud := sin(TAU * (135.0 * exp(-t * 8.0)) * t)
		var metal_ring := 0.4 * sin(TAU * 520.0 * t) * exp(-t * 32.0)
		var grit := randf_range(-0.25, 0.25) * exp(-t * 45.0)
		samples[i] = (low_thud + metal_ring + grit) * env * 0.65
	
	return _create_wav_buffer(samples, rate)

# 3. Dentang gong pelog Nusantara saat SKAK!
func _gen_gong_warning() -> AudioStreamWAV:
	var rate := 22050
	var duration := 0.75
	var count := int(rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	for i in range(count):
		var t := float(i) / rate
		var env := exp(-t * 4.5)
		var shimmer := 1.0 + 0.12 * sin(TAU * 6.5 * t)
		var f1 := sin(TAU * 220.0 * t)
		var f2 := 0.6 * sin(TAU * 330.0 * t)
		var f3 := 0.35 * sin(TAU * 466.16 * t)
		samples[i] = (f1 + f2 + f3) * 0.32 * env * shimmer
	
	return _create_wav_buffer(samples, rate)

# 4. Dentang kemenangan / akhir laga saat SKAKMAT!
func _gen_victory_chime() -> AudioStreamWAV:
	var rate := 22050
	var duration := 1.25
	var count := int(rate * duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	
	var notes := [261.63, 329.63, 392.00, 523.25] # Akor C Major Nusantara
	for i in range(count):
		var t := float(i) / rate
		var sig := 0.0
		for n_idx in range(notes.size()):
			var delay := n_idx * 0.11
			if t >= delay:
				var lt := t - delay
				var env := exp(-lt * 3.2)
				sig += sin(TAU * notes[n_idx] * lt) * env
		samples[i] = sig * 0.25
	
	return _create_wav_buffer(samples, rate)
