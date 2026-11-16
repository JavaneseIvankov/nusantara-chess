extends Node

const RATE := 32000
const NOTE_RATIOS := [1.0, 1.14, 1.31, 1.51, 1.72]

var _players: Array[AudioStreamPlayer] = []
var _cursor := 0
var _moves: Array[AudioStreamWAV] = []
var _landings: Array[AudioStreamWAV] = []
var _strikes: Array[AudioStreamWAV] = []
var _click: AudioStream
var _check: AudioStream
var _ending: AudioStream


func _ready() -> void:
	for i in range(8):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	for role in range(6):
		_moves.append(_synthesize(0.24, func(t: float, grit: float) -> float:
			var tap := _drum(t, [164.0, 75.0, 114.0, 185.0, 225.0, 97.0][role], grit) * 0.15
			var jingle := _bronze(t - 0.055, 510.0 * NOTE_RATIOS[role % 5], 23.0)
			match role:
				0: return tap + jingle * 0.06
				1: return tap + _drum(t - 0.087, 82.0, grit) * 0.11
				2: return tap + _drum(t - 0.071, 173.0, grit) * 0.19
				3: return tap * 0.55 + _bronze(t, 392.0, 14.0) * 0.13
				4: return tap * 0.5 + jingle * 0.13 + _bronze(t - 0.095, 778.0, 19.0) * 0.08
				_: return tap + _bronze(t - 0.034, 250.0, 24.0) * 0.07
		))
		_landings.append(_synthesize(0.16, func(t: float, grit: float) -> float:
			var weight: float = [0.12, 0.26, 0.27, 0.095, 0.085, 0.19][role]
			return _drum(t, [152.0, 85.0, 112.0, 213.0, 230.0, 102.0][role], grit) * weight
		))
		_strikes.append(_synthesize(0.79, func(t: float, grit: float) -> float:
			var tone: float = [520.0, 141.0, 418.0, 300.0, 625.0, 277.0][role]
			var body := _drum(t, 82.0 if role == 1 else 122.0, grit) * 0.25
			var hit := _bronze(t, tone, 9.0) * 0.24
			var tail := _bronze(t - 0.053, 136.0, 6.1) * 0.12
			return body + hit + tail
		))
	_click = _synthesize(0.105, func(t: float, grit: float) -> float:
		return _drum(t, 286.0, grit) * 0.1 + _bronze(t, 723.0, 49.0) * 0.065
	)
	_check = _synthesize(1.02, func(t: float, grit: float) -> float:
		return _bronze(t, 152.0, 3.8) * 0.29 + _bronze(t - 0.13, 265.0, 6.0) * 0.12
	)
	_ending = _synthesize(1.85, func(t: float, grit: float) -> float:
		var signal_value := _bronze(t - 0.62, 108.0, 2.9) * 0.26
		for i in range(5):
			signal_value += _bronze(t - i * 0.132, 310.0 * NOTE_RATIOS[i], 6.1) * 0.12
		return signal_value
	)


func play_move(role: int) -> void:
	_play(_moves[role], randf_range(0.95, 1.05))


func play_landing(role: int) -> void:
	_play(_landings[role], randf_range(0.96, 1.04))


func play_capture(role: int) -> void:
	_play(_strikes[role])


func play_check() -> void:
	_play(_check)


func play_game_over() -> void:
	_play(_ending)


func play_ui_click() -> void:
	_play(_click, randf_range(0.98, 1.03))


func _play(stream: AudioStream, pitch: float = 1.0) -> void:
	var player := _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


func _synthesize(duration: float, sample: Callable) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8795
	var grit := 0.0
	for i in range(count):
		var t := float(i) / RATE
		grit = lerpf(grit, rng.randf_range(-1.0, 1.0), 0.37)
		var fade_out := clampf((duration - t) * 58.0, 0.0, 1.0)
		var value: float = sample.call(t, grit)
		data.encode_s16(i * 2, int(clampf(value * fade_out, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


func _drum(t: float, frequency: float, grit: float) -> float:
	if t < 0.0:
		return 0.0
	var phase := TAU * (frequency * t + frequency * 0.004 * (1.0 - exp(-t * 134.0)))
	var skin := sin(phase) + 0.37 * sin(2.16 * phase) * exp(-t * 45.0)
	return skin * exp(-t * 42.0) + grit * 0.37 * exp(-t * 95.0)


func _bronze(t: float, frequency: float, decay: float) -> float:
	if t < 0.0:
		return 0.0
	var phase := TAU * frequency * t
	var partials := sin(phase) * (0.86 + sin(TAU * 4.7 * t) * 0.14)
	partials += sin(phase * 2.17) * 0.39 * exp(-t * 5.8)
	partials += sin(phase * 3.41) * 0.27 * exp(-t * 10.1)
	partials += sin(phase * 5.38) * 0.16 * exp(-t * 20.3)
	return partials * exp(-t * decay)
