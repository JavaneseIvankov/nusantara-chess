extends Node3D

@onready var camera_rig: Node3D = $CameraRig
@onready var chess_board: Node3D = $ChessBoard
@onready var game_hud: GameHUD = $GameHUD

func _ready() -> void:
	chess_board.turn_changed.connect(_on_turn_changed)
	chess_board.check_state_changed.connect(_on_check_state_changed)
	chess_board.piece_captured.connect(_on_piece_captured)
	chess_board.move_recorded.connect(_on_move_recorded)
	chess_board.game_over.connect(_on_game_over)
	
	game_hud.camera_reset_requested.connect(_on_camera_reset)
	game_hud.restart_requested.connect(_on_restart_game)
	game_hud.forfeit_requested.connect(_on_forfeit_game)

func _on_turn_changed(new_faction: ChessPiece.Faction) -> void:
	game_hud.update_turn(new_faction)

func _on_check_state_changed(is_in_check: bool) -> void:
	game_hud.set_check_warning(is_in_check)

func _on_piece_captured(capturer_faction: ChessPiece.Faction, captured_type: ChessPiece.PieceType) -> void:
	game_hud.add_captured_piece(capturer_faction, captured_type)

func _on_move_recorded(faction: ChessPiece.Faction, notation: String) -> void:
	game_hud.add_move_record(faction, notation)

func _on_game_over(winner_faction: ChessPiece.Faction, reason: String) -> void:
	game_hud.show_winner(winner_faction, reason)

func _on_camera_reset() -> void:
	if camera_rig.has_method("reset_camera"):
		camera_rig.reset_camera()

func _on_restart_game() -> void:
	get_tree().reload_current_scene()

func _on_forfeit_game() -> void:
	if chess_board.is_game_over:
		return
	chess_board.is_game_over = true
	var winner := ChessPiece.Faction.OBSIDIAN if chess_board.current_turn == ChessPiece.Faction.GOLD else ChessPiece.Faction.GOLD
	game_hud.show_winner(winner, "LAWAN MENYERAH!")
