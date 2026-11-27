extends Node3D

const BOARD_SCENE := preload("res://scenes/board/chess_board.tscn")

@onready var camera_rig: Node3D = $CameraRig
@onready var chess_board: ChessBoard = $ChessBoard
@onready var game_hud: GameHUD = $GameHUD
@onready var main_menu: MainMenu = $MainMenu

var _engine := StockfishClient.new()
var _solo := false
var _human_faction := ChessPiece.Faction.GOLD
var _difficulty := 0
var _auto_flip := true
var _bot_pending := false


func _enter_tree() -> void:
	var shared := TakhtaTheme.make()
	$MainMenu.theme = shared
	$GameHUD.theme = shared


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		get_window().min_size = Vector2i(960, 540)
	game_hud.hide()
	add_child(_engine)
	_engine.best_move.connect(_on_bot_move)
	_engine.failed.connect(_on_bot_error)
	_connect_board()
	main_menu.start_game_requested.connect(_start_match)
	main_menu.quit_game_requested.connect(_quit)
	game_hud.camera_reset_requested.connect(_reset_camera)
	game_hud.camera_top_view_requested.connect(camera_rig.toggle_top_view)
	game_hud.auto_flip_toggled.connect(_set_auto_flip)
	game_hud.layout_changed.connect(camera_rig.set_compact_layout)
	game_hud.promotion_piece_selected.connect(func(role: ChessPiece.PieceType): chess_board.complete_pawn_promotion(role))
	game_hud.restart_requested.connect(_restart_match)
	game_hud.forfeit_requested.connect(_forfeit)
	game_hud.menu_requested.connect(_return_to_menu)
	game_hud.retry_requested.connect(_request_bot_move)


func _connect_board() -> void:
	chess_board.turn_ready.connect(_on_turn_ready)
	chess_board.check_state_changed.connect(_on_check)
	chess_board.piece_captured.connect(game_hud.add_captured_piece)
	chess_board.capture_replay_requested.connect(game_hud.show_capture_replay)
	chess_board.selected_role_changed.connect(game_hud.show_selected_role)
	chess_board.move_recorded.connect(game_hud.add_move_record)
	chess_board.promotion_required.connect(game_hud.show_promotion_choices)
	chess_board.game_over.connect(_on_game_over)


func _start_match(solo: bool, faction: int, difficulty: int) -> void:
	_solo = solo
	_human_faction = faction as ChessPiece.Faction if solo else ChessPiece.Faction.GOLD
	_difficulty = difficulty
	_auto_flip = not solo
	chess_board.is_in_menu = false
	camera_rig.start_gameplay_camera()
	camera_rig.set_faction_side(_human_faction)
	game_hud.show()
	game_hud.configure(solo, _human_faction, difficulty)
	camera_rig.set_compact_layout(game_hud.is_compact_layout())
	_on_turn_ready(chess_board.current_turn)


func _on_turn_ready(faction: ChessPiece.Faction) -> void:
	var bot_turn := _solo and faction != _human_faction
	chess_board.human_input_enabled = not bot_turn
	game_hud.update_turn(faction, bot_turn)
	if _auto_flip:
		camera_rig.set_faction_side(faction)
	if bot_turn:
		_request_bot_move()


func _request_bot_move() -> void:
	if not _solo or _bot_pending or chess_board.is_in_menu or chess_board.is_game_over or chess_board.current_turn == _human_faction:
		return
	_bot_pending = true
	game_hud.update_turn(chess_board.current_turn, true)
	_engine.request_move(chess_board.uci_history, _difficulty)


func _on_bot_move(move: String) -> void:
	if not _bot_pending:
		return
	_bot_pending = false
	game_hud.update_turn(chess_board.current_turn)
	if not chess_board.try_uci_move(move):
		_engine.stop()
		game_hud.show_bot_error("Stockfish mengirim langkah yang tidak sah untuk posisi ini.")


func _on_bot_error(message: String) -> void:
	if _bot_pending:
		_bot_pending = false
		game_hud.update_turn(chess_board.current_turn)
		game_hud.show_bot_error(message)


func _stop_bot() -> void:
	_bot_pending = false
	_engine.stop()


func _on_check(in_check: bool) -> void:
	game_hud.set_check_warning(in_check)
	if in_check:
		AudioManager.play_check()


func _on_game_over(winner: int, reason: String) -> void:
	_stop_bot()
	AudioManager.play_game_over()
	game_hud.show_result(winner, reason)


func _set_auto_flip(enabled: bool) -> void:
	_auto_flip = enabled and not _solo
	if _auto_flip:
		camera_rig.set_faction_side(chess_board.current_turn)


func _reset_camera() -> void:
	camera_rig.reset_camera()
	if _solo:
		camera_rig.set_faction_side(_human_faction)
	elif _auto_flip:
		camera_rig.set_faction_side(chess_board.current_turn)


func _replace_board() -> void:
	_stop_bot()
	var old_board := chess_board
	remove_child(old_board)
	old_board.queue_free()
	chess_board = BOARD_SCENE.instantiate()
	chess_board.name = "ChessBoard"
	add_child(chess_board)
	_connect_board()


func _restart_match() -> void:
	_replace_board()
	_start_match(_solo, _human_faction, _difficulty)


func _return_to_menu() -> void:
	game_hud.hide()
	_replace_board()
	game_hud.configure(false, ChessPiece.Faction.GOLD, 0)
	camera_rig.start_showcase()
	main_menu.show_home()


func _forfeit() -> void:
	var resigning := _human_faction if _solo else chess_board.current_turn
	chess_board.end_match(1 - resigning, "%s menyerah." % TakhtaTheme.faction_name(resigning))


func _quit() -> void:
	_stop_bot()
	get_tree().quit()
