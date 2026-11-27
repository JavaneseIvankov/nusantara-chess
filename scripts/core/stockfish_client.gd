class_name StockfishClient
extends Node

signal best_move(received_move: String)
signal failed(message: String)

const PRESETS := [
	{"label": "Pemula", "skill": 0, "time_ms": 300},
	{"label": "Menengah", "skill": 5, "time_ms": 500},
	{"label": "Mahir", "skill": 12, "time_ms": 850},
]

const HANDSHAKE_TIMEOUT_MS := 10000

enum State { IDLE, WAIT_UCI, WAIT_READY, SEARCHING }

var _state := State.IDLE
var _pid := 0
var _stdio: FileAccess
var _stderr: FileAccess
var _output := PackedByteArray()
var _deadline := 0
var _moves := PackedStringArray()
var _preset: Dictionary


func request_move(moves: PackedStringArray, difficulty: int) -> void:
	if _state != State.IDLE:
		return
	_moves = moves.duplicate()
	_preset = PRESETS[difficulty]
	if _pid > 0 and OS.is_process_running(_pid):
		_search()
		return

	var directory := OS.get_executable_path().get_base_dir()
	if OS.has_feature("editor"):
		directory = ProjectSettings.globalize_path("res://").simplify_path()
	var binary := "stockfish.exe" if OS.get_name() == "Windows" else "stockfish"
	var path := directory.path_join("engine").path_join(binary)
	if not FileAccess.file_exists(path):
		_fail("Stockfish tidak ditemukan. Periksa folder engine.")
		return

	var process := OS.execute_with_pipe(path, PackedStringArray(), false)
	if process.is_empty():
		_fail("Stockfish tidak dapat dijalankan.")
		return
	_pid = process["pid"]
	_stdio = process["stdio"]
	_stderr = process["stderr"]
	_state = State.WAIT_UCI
	_deadline = Time.get_ticks_msec() + HANDSHAKE_TIMEOUT_MS
	_send("uci\n")


func stop() -> void:
	var pid := _pid
	_pid = 0
	_state = State.IDLE
	_output.clear()
	if pid > 0 and OS.is_process_running(pid):
		if _stdio:
			_stdio.store_buffer("quit\n".to_ascii_buffer())
		if OS.is_process_running(pid):
			OS.kill(pid)
	_stdio = null
	_stderr = null


func _exit_tree() -> void:
	stop()


func _process(_delta: float) -> void:
	if _state == State.IDLE:
		return
	if not OS.is_process_running(_pid):
		_fail("Stockfish berhenti sebelum mengirim langkah.")
		return
	if Time.get_ticks_msec() >= _deadline:
		_fail("Waktu respons Stockfish habis.")
		return

	# Limit the pipe work per frame and retain any incomplete UCI line.
	var stderr_bytes := mini(_stderr.get_length(), 4096)
	if stderr_bytes > 0:
		_stderr.get_buffer(stderr_bytes)
	var available := mini(_stdio.get_length(), 16384)
	if available <= 0:
		return
	_output.append_array(_stdio.get_buffer(available))
	var start := 0
	var parsing_pid := _pid
	for i in range(_output.size()):
		if _output[i] != 10:
			continue
		var line := _output.slice(start, i).get_string_from_ascii().strip_edges()
		start = i + 1
		_read_line(line)
		if _pid != parsing_pid:
			return
	_output = _output.slice(start)
	if _output.size() > 65536:
		_fail("Respons Stockfish tidak dapat dibaca.")


func _read_line(line: String) -> void:
	if _state == State.WAIT_UCI and line == "uciok":
		_state = State.WAIT_READY
		_deadline = Time.get_ticks_msec() + HANDSHAKE_TIMEOUT_MS
		_send("setoption name Threads value 1\nsetoption name Hash value 16\nsetoption name Ponder value false\nsetoption name UCI_LimitStrength value false\nsetoption name Skill Level value %d\nucinewgame\nisready\n" % _preset.skill)
	elif _state == State.WAIT_READY and line == "readyok":
		_search()
	elif _state == State.SEARCHING and line.begins_with("bestmove"):
		var parts := line.split(" ", false)
		if parts.size() < 2 or parts[0] != "bestmove":
			_fail("Respons langkah Stockfish tidak sah.")
			return
		_state = State.IDLE
		best_move.emit(parts[1])


func _search() -> void:
	var position := "position startpos"
	if not _moves.is_empty():
		position += " moves " + " ".join(_moves)
	_state = State.SEARCHING
	_deadline = Time.get_ticks_msec() + int(_preset.time_ms) + 3500
	_send("%s\ngo movetime %d\n" % [position, _preset.time_ms])


func _send(command: String) -> void:
	if not _stdio.store_buffer(command.to_ascii_buffer()):
		_fail("Perintah tidak dapat dikirim ke Stockfish.")


func _fail(message: String) -> void:
	stop()
	failed.emit(message)
