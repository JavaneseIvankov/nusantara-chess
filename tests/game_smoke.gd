extends Node

const GAME := preload("res://main/main.tscn")
const BOARD := preload("res://scenes/board/chess_board.tscn")
const G := ChessPiece.Faction.GOLD
const O := ChessPiece.Faction.OBSIDIAN
const KING := ChessPiece.PieceType.KING
const ROOK := ChessPiece.PieceType.ROOK
const PAWN := ChessPiece.PieceType.PAWN
const QUEEN := ChessPiece.PieceType.QUEEN

var _failures := 0


func _ready() -> void:
	Engine.time_scale = 8
	await _check_chess_rules()
	await _check_bot_matches()
	Engine.time_scale = 1
	await get_tree().create_timer(2.0).timeout
	print("Smoke checks completed. Failures: ", _failures)
	get_tree().quit(1 if _failures else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)


func _board() -> ChessBoard:
	var board := BOARD.instantiate() as ChessBoard
	add_child(board)
	board.is_in_menu = false
	return board


func _play(board: ChessBoard, moves: Array) -> void:
	for move in moves:
		_expect(board.try_uci_move(move), "accepted %s" % move)
		while board.resolving_move:
			await get_tree().process_frame


func _position(board: ChessBoard, pieces: Array) -> void:
	for piece in board.board_state.values():
		board.remove_child(piece)
		piece.queue_free()
	board.board_state.clear()
	for item in pieces:
		board._spawn_piece(item[0], item[1], board._algebraic_to_grid(item[2]))


func _check_chess_rules() -> void:
	var board := _board()
	_expect(not board.try_uci_move("e7e5") and not board.try_uci_move("e2e5"), "reject wrong turn and illegal moves")
	await _play(board, ["e2e4", "a7a6", "e4e5", "d7d5", "e5d6"])
	_expect(not board.board_state.has(board._algebraic_to_grid("d5")) and board.uci_history[4] == "e5d6", "en passant removes captured pawn and records UCI")
	board.queue_free()

	for castle in ["e1g1", "e1c1"]:
		board = _board()
		_position(board, [[KING, G, "e1"], [ROOK, G, "a1"], [ROOK, G, "h1"], [KING, O, "e8"]])
		await _play(board, [castle])
		var rook_square := "f1" if castle == "e1g1" else "d1"
		_expect(board.board_state[board._algebraic_to_grid(rook_square)].type == ROOK, "castling moves rook to " + rook_square)
		board.queue_free()
	board = _board()
	_position(board, [[KING, G, "d1"], [ROOK, G, "h1"], [KING, O, "e8"]])
	_expect(not board.try_uci_move("d1g1"), "off-home king cannot castle")
	_position(board, [[KING, G, "e1"], [ROOK, O, "h1"], [KING, O, "e8"]])
	_expect(not board.try_uci_move("e1g1"), "cannot castle with opposing rook")
	board.queue_free()

	for suffix in ChessBoard.PROMOTION_TYPES:
		board = _board()
		_position(board, [[KING, G, "e1"], [PAWN, G, "a7"], [KING, O, "h8"]])
		_expect(not board.try_uci_move("a7a8") and not board.try_uci_move("a7a8k"), "bot promotion requires valid suffix")
		await _play(board, ["a7a8" + suffix])
		_expect(board.board_state[board._algebraic_to_grid("a8")].type == ChessBoard.PROMOTION_TYPES[suffix], "promotion " + suffix)
		board.queue_free()
	board = _board()
	_position(board, [[KING, G, "e1"], [PAWN, G, "a7"], [KING, O, "h8"]])
	_expect(board.try_move(board._algebraic_to_grid("a7"), board._algebraic_to_grid("a8")), "human pawn reaches promotion")
	while board.resolving_move:
		await get_tree().process_frame
	_expect(board.awaiting_promotion and board.uci_history.is_empty(), "human promotion waits for choice")
	board.complete_pawn_promotion(ROOK)
	_expect(board.uci_history == PackedStringArray(["a7a8r"]), "human promotion records completed move once")
	board.queue_free()

	board = _board()
	var results: Array[int] = []
	board.game_over.connect(func(winner: int, _reason: String): results.append(winner))
	await _play(board, ["f2f3", "e7e5", "g2g4", "d8h4"])
	_expect(results == [O] and board.is_game_over, "Fool's mate awards Obsidian")
	board.queue_free()
	board = _board()
	results.clear()
	board.game_over.connect(func(winner: int, _reason: String): results.append(winner))
	_position(board, [[KING, G, "c6"], [QUEEN, G, "b6"], [KING, O, "a8"]])
	await _play(board, ["b6c7"])
	_expect(results == [ChessBoard.DRAW] and board.is_game_over, "stalemate has no winner")
	board.queue_free()
	print("Rule checks finished")


func _until(condition: Callable, ms: int = 6500) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return condition.call()


func _linux_process_exists(pid: int) -> bool:
	return FileAccess.file_exists("/proc/%d/stat" % pid)


func _check_bot_matches() -> void:
	var game := GAME.instantiate()
	add_child(game)
	for difficulty in range(3):
		game._replace_board()
		game.main_menu.hide()
		var faction := G if difficulty == 0 else O
		game._start_match(true, faction, difficulty)
		if faction == G:
			_expect(game.chess_board.try_uci_move("e2e4"), "Gold plays opening move")
		var expected_moves := 2 if faction == G else 1
		var response: bool = await _until(func(): return game.chess_board.uci_history.size() == expected_moves)
		_expect(response and game.chess_board.current_turn == faction and game.chess_board.human_input_enabled, "bot responds on preset %d" % difficulty)
		print("Preset %s: %s" % [StockfishClient.PRESETS[difficulty].label, game.chess_board.uci_history])
		var pid: int = game._engine._pid
		game._return_to_menu()
		_expect(pid > 0 and await _until(func(): return not _linux_process_exists(pid), 2000), "return to menu stops engine")
	_expect(game.main_menu.visible, "return home restores main menu")

	game.main_menu.hide()
	game._start_match(true, O, 0)
	var dead_pid: int = game._engine._pid
	_expect(dead_pid > 0, "engine process started before kill")
	if dead_pid > 0:
		OS.execute("/usr/bin/kill", ["-KILL", str(dead_pid)])
	_expect(await _until(func(): return game.game_hud._modal.visible), "failed process produces retry modal")
	_expect(game.chess_board.uci_history.is_empty(), "engine death preserves position")
	game.game_hud._retry()
	_expect(await _until(func(): return game.chess_board.uci_history.size() == 1), "retry continues same match")
	game._restart_match()
	game._engine._deadline = 0
	_expect(await _until(func(): return game.game_hud._modal.visible), "timeout produces retry modal")
	_expect(game.chess_board.uci_history.is_empty(), "timed out search preserves position")
	game.game_hud._retry()
	var old_pid: int = game._engine._pid
	game._restart_match()
	_expect(not game.chess_board.is_game_over and game.chess_board.uci_history.is_empty(), "restart starts at a fresh position")
	_expect(await _until(func(): return not _linux_process_exists(old_pid), 2000), "restart stops previous engine")
	var resign_pid: int = game._engine._pid
	game._forfeit()
	_expect(await _until(func(): return not _linux_process_exists(resign_pid), 2000), "forfeit stops engine")
	_expect(game.chess_board.is_game_over and game.chess_board.uci_history.is_empty(), "forfeit cancels pending bot move")
	game._return_to_menu()
	game.main_menu.hide()
	game._start_match(false, G, 0)
	await _play(game.chess_board, ["e2e4", "d7d5", "e4d5"])
	_expect(game.chess_board.human_input_enabled and game.game_hud._captured[G] == [PAWN], "local mode records capture and allows both players")
	_expect(game._engine._pid == 0, "local mode never starts the engine")
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
