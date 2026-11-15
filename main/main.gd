extends Node3D

@onready var camera_rig: Node3D = $CameraRig
@onready var chess_board: Node3D = $ChessBoard
@onready var game_hud: GameHUD = $GameHUD
@onready var main_menu: MainMenu = $MainMenu

var auto_flip_camera: bool = true

func _ready() -> void:
	# Sembunyikan HUD permainan saat berada di Menu Utama
	game_hud.visible = false
	game_hud.modulate.a = 0.0
	
	# Sinyal Menu Utama
	main_menu.start_game_requested.connect(_on_start_game)
	main_menu.quit_game_requested.connect(_on_quit_game)
	
	# Sinyal Papan Catur
	chess_board.turn_changed.connect(_on_turn_changed)
	chess_board.check_state_changed.connect(_on_check_state_changed)
	chess_board.piece_captured.connect(_on_piece_captured)
	chess_board.move_recorded.connect(_on_move_recorded)
	chess_board.promotion_required.connect(_on_promotion_required)
	chess_board.game_over.connect(_on_game_over)
	
	# Sinyal HUD Permainan
	game_hud.camera_reset_requested.connect(_on_camera_reset)
	game_hud.auto_flip_toggled.connect(_on_auto_flip_toggled)
	game_hud.camera_top_view_requested.connect(_on_camera_top_view)
	game_hud.promotion_piece_selected.connect(_on_promotion_piece_selected)
	game_hud.restart_requested.connect(_on_restart_game)
	game_hud.forfeit_requested.connect(_on_forfeit_game)

func _on_start_game() -> void:
	AudioManager.play_ui_click()
	chess_board.is_in_menu = false
	if camera_rig.has_method("start_gameplay_camera"):
		camera_rig.start_gameplay_camera()
	
	game_hud.visible = true
	var hud_tween := create_tween()
	hud_tween.tween_property(game_hud, "modulate:a", 1.0, 0.4)

func _on_quit_game() -> void:
	AudioManager.play_ui_click()
	get_tree().quit()

func _on_turn_changed(new_faction: ChessPiece.Faction) -> void:
	game_hud.update_turn(new_faction)
	if auto_flip_camera and not chess_board.is_game_over:
		await get_tree().create_timer(0.32).timeout
		if not chess_board.is_game_over and camera_rig.has_method("set_faction_side"):
			camera_rig.set_faction_side(new_faction)

func _on_auto_flip_toggled(enabled: bool) -> void:
	AudioManager.play_ui_click()
	auto_flip_camera = enabled
	if auto_flip_camera and camera_rig.has_method("set_faction_side"):
		camera_rig.set_faction_side(chess_board.current_turn)

func _on_check_state_changed(is_in_check: bool) -> void:
	game_hud.set_check_warning(is_in_check)
	if is_in_check:
		AudioManager.play_check()

func _on_piece_captured(capturer_faction: ChessPiece.Faction, captured_type: ChessPiece.PieceType) -> void:
	AudioManager.play_capture()
	game_hud.add_captured_piece(capturer_faction, captured_type)

func _on_move_recorded(faction: ChessPiece.Faction, notation: String) -> void:
	AudioManager.play_move()
	game_hud.add_move_record(faction, notation)

func _on_promotion_required() -> void:
	game_hud.show_promotion_choices()

func _on_promotion_piece_selected(chosen_type: ChessPiece.PieceType) -> void:
	AudioManager.play_ui_click()
	chess_board.complete_pawn_promotion(chosen_type)

func _on_game_over(winner_faction: ChessPiece.Faction, reason: String) -> void:
	AudioManager.play_game_over()
	game_hud.show_winner(winner_faction, reason)

func _on_camera_reset() -> void:
	AudioManager.play_ui_click()
	if camera_rig.has_method("reset_camera"):
		camera_rig.reset_camera()

func _on_camera_top_view() -> void:
	AudioManager.play_ui_click()
	if camera_rig.has_method("toggle_top_view"):
		camera_rig.toggle_top_view()

func _on_restart_game() -> void:
	AudioManager.play_ui_click()
	get_tree().reload_current_scene()

func _on_forfeit_game() -> void:
	if chess_board.is_game_over:
		return
	chess_board.is_game_over = true
	var winner := ChessPiece.Faction.OBSIDIAN if chess_board.current_turn == ChessPiece.Faction.GOLD else ChessPiece.Faction.GOLD
	AudioManager.play_game_over()
	game_hud.show_winner(winner, "LAWAN MENYERAH!")
