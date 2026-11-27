class_name ChessBoard
extends Node3D

signal turn_changed(new_faction: ChessPiece.Faction)
signal check_state_changed(is_in_check: bool)
signal piece_captured(capturer_faction: ChessPiece.Faction, captured_type: ChessPiece.PieceType)
signal capture_replay_requested(attacker: ChessPiece.PieceType, defender: ChessPiece.PieceType, faction: ChessPiece.Faction)
signal move_recorded(faction: ChessPiece.Faction, notation: String)
signal selected_role_changed(role: int)
signal promotion_required
signal game_over(winner_faction: ChessPiece.Faction, reason: String)

@export var tile_size: float = 1.0
@export var tile_height: float = 0.2
@export var light_color: Color = Color("#e2cda6")
@export var dark_color: Color = Color("#516161")

const PIECE_SCENE: PackedScene = preload("res://scenes/pieces/chess_piece.tscn")
const BOARD_TILE_SHADER: Shader = preload("res://assets/shaders/board_tile.gdshader")

var light_material: ShaderMaterial
var dark_material: ShaderMaterial
var selection_highlight: Node3D
var last_move_from_highlight: Node3D
var last_move_to_highlight: Node3D
var king_check_highlight: Node3D
var valid_moves_container: Node3D

var current_turn: ChessPiece.Faction = ChessPiece.Faction.GOLD
var is_game_over: bool = false
var is_in_menu: bool = true
var awaiting_promotion: bool = false
var human_input_enabled := true
var resolving_move := false
var uci_history := PackedStringArray()

const PROMOTION_TYPES := {
	"q": ChessPiece.PieceType.QUEEN,
	"r": ChessPiece.PieceType.ROOK,
	"b": ChessPiece.PieceType.BISHOP,
	"n": ChessPiece.PieceType.KNIGHT,
}
const DRAW := -1

var selected_grid: Vector2i = Vector2i(-1, -1)
var selected_piece: ChessPiece = null
var checked_king_piece: ChessPiece = null
var hovered_piece: ChessPiece = null
var valid_moves: Array[Vector2i] = []
var board_state: Dictionary = {} # Vector2i -> ChessPiece

# Status khusus En Passant & Promosi tertunda
var en_passant_target: Vector2i = Vector2i(-1, -1)
var pending_promotion_pawn: ChessPiece = null
var pending_promotion_from: Vector2i = Vector2i(-1, -1)
var pending_promotion_to: Vector2i = Vector2i(-1, -1)
var pending_promotion_capture: bool = false


func _ready() -> void:
	_setup_materials()
	_generate_board()
	_create_highlights()
	_create_valid_moves_container()
	_spawn_initial_pieces()

func _setup_materials() -> void:
	light_material = ShaderMaterial.new()
	light_material.shader = BOARD_TILE_SHADER
	light_material.set_shader_parameter("base_color", light_color)
	light_material.set_shader_parameter("vein_color", Color("#b6a385"))
	light_material.set_shader_parameter("is_wood_grain", false)
	light_material.set_shader_parameter("pattern_scale", 3.2)
	light_material.set_shader_parameter("bump_strength", 0.36)
	light_material.set_shader_parameter("base_roughness", 0.57)
	
	dark_material = ShaderMaterial.new()
	dark_material.shader = BOARD_TILE_SHADER
	dark_material.set_shader_parameter("base_color", dark_color)
	dark_material.set_shader_parameter("vein_color", Color("#343f43"))
	dark_material.set_shader_parameter("is_wood_grain", true)
	dark_material.set_shader_parameter("pattern_scale", 4.5)
	dark_material.set_shader_parameter("bump_strength", 0.3)
	dark_material.set_shader_parameter("base_roughness", 0.63)

func _generate_board() -> void:
	var offset: float = (8.0 * tile_size) / 2.0 - (tile_size / 2.0)
	
	for row in range(8):
		for col in range(8):
			var tile_body := StaticBody3D.new()
			tile_body.name = "Tile_%d_%d" % [row, col]
			tile_body.set_meta("grid_pos", Vector2i(col, row))
			
			var mesh_instance := MeshInstance3D.new()
			var box_mesh := BoxMesh.new()
			box_mesh.size = Vector3(tile_size, tile_height, tile_size)
			mesh_instance.mesh = box_mesh
			
			var is_light: bool = (row + col) % 2 == 0
			var tile_mat := (light_material if is_light else dark_material).duplicate() as ShaderMaterial
			tile_mat.set_shader_parameter("tile_seed", float(row * 8 + col))
			mesh_instance.material_override = tile_mat
			
			var collision_shape := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(tile_size, tile_height, tile_size)
			collision_shape.shape = box_shape
			
			tile_body.add_child(mesh_instance)
			tile_body.add_child(collision_shape)
			
			var pos_x: float = (col * tile_size) - offset
			var pos_z: float = (row * tile_size) - offset
			tile_body.position = Vector3(pos_x, -tile_height / 2.0, pos_z)
			
			add_child(tile_body)

func _create_highlights() -> void:
	selection_highlight = _make_border_frame("SelectionHighlight", Color(1.0, 0.85, 0.3), 2.5, 0.94)
	last_move_from_highlight = _make_border_frame("LastMoveFrom", Color(0.45, 0.75, 1.0), 1.2, 0.90)
	last_move_to_highlight = _make_border_frame("LastMoveTo", Color(0.45, 0.75, 1.0), 1.6, 0.92)
	king_check_highlight = _make_border_frame("KingCheckHighlight", Color(1.0, 0.2, 0.15), 3.2, 0.95)

func _make_border_frame(node_name: String, glow_color: Color, energy: float, scale_factor: float) -> Node3D:
	var frame := Node3D.new()
	frame.name = node_name
	frame.visible = false
	
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = glow_color
	glow_mat.emission_enabled = true
	glow_mat.emission = glow_color
	glow_mat.emission_energy_multiplier = energy
	
	var thickness: float = 0.045
	var height: float = 0.015
	var edge_len: float = tile_size * scale_factor
	var half_span: float = (edge_len - thickness) / 2.0
	
	var borders := [
		{"size": Vector3(edge_len, height, thickness), "pos": Vector3(0, height / 2.0, -half_span)},
		{"size": Vector3(edge_len, height, thickness), "pos": Vector3(0, height / 2.0, half_span)},
		{"size": Vector3(thickness, height, edge_len), "pos": Vector3(-half_span, height / 2.0, 0)},
		{"size": Vector3(thickness, height, edge_len), "pos": Vector3(half_span, height / 2.0, 0)}
	]
	
	for b in borders:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = b["size"]
		bar.mesh = mesh
		bar.material_override = glow_mat
		bar.position = b["pos"]
		frame.add_child(bar)
	
	add_child(frame)
	return frame

func _create_valid_moves_container() -> void:
	valid_moves_container = Node3D.new()
	valid_moves_container.name = "ValidMovesContainer"
	add_child(valid_moves_container)

func _spawn_initial_pieces() -> void:
	var back_rank := [
		ChessPiece.PieceType.ROOK,
		ChessPiece.PieceType.KNIGHT,
		ChessPiece.PieceType.BISHOP,
		ChessPiece.PieceType.QUEEN,
		ChessPiece.PieceType.KING,
		ChessPiece.PieceType.BISHOP,
		ChessPiece.PieceType.KNIGHT,
		ChessPiece.PieceType.ROOK
	]
	
	for col in range(8):
		_spawn_piece(back_rank[col], ChessPiece.Faction.OBSIDIAN, Vector2i(col, 0))
		_spawn_piece(ChessPiece.PieceType.PAWN, ChessPiece.Faction.OBSIDIAN, Vector2i(col, 1))
		
		_spawn_piece(ChessPiece.PieceType.PAWN, ChessPiece.Faction.GOLD, Vector2i(col, 6))
		_spawn_piece(back_rank[col], ChessPiece.Faction.GOLD, Vector2i(col, 7))

func _spawn_piece(p_type: ChessPiece.PieceType, p_faction: ChessPiece.Faction, grid_pos: Vector2i) -> void:
	var piece: ChessPiece = PIECE_SCENE.instantiate()
	add_child(piece)
	piece.setup(p_type, p_faction, grid_pos, grid_to_world(grid_pos))
	board_state[grid_pos] = piece

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over or is_in_menu or awaiting_promotion or resolving_move or not human_input_enabled:
		_clear_hover()
		return
	
	if event is InputEventMouseMotion:
		_raycast_hover(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_raycast_board(event.position)

func _grid_under_cursor(mouse_pos: Vector2) -> Vector2i:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return Vector2i(-1, -1)
	var origin := camera.project_ray_origin(mouse_pos)
	var ray_end := origin + camera.project_ray_normal(mouse_pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(origin, ray_end)
	query.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		var hit: Node = result.collider
		if hit.has_meta("piece"):
			var piece: ChessPiece = hit.get_meta("piece")
			return piece.grid_pos
		return hit.get_meta("grid_pos", Vector2i(-1, -1))
	return Vector2i(-1, -1)

func _raycast_board(mouse_pos: Vector2) -> void:
	var grid := _grid_under_cursor(mouse_pos)
	if _is_inside_board(grid):
		_handle_tile_click(grid)

func _raycast_hover(mouse_pos: Vector2) -> void:
	var new_hover: ChessPiece = board_state.get(_grid_under_cursor(mouse_pos))
	if new_hover != null and new_hover.faction != current_turn:
		new_hover = null

	if new_hover == hovered_piece:
		return
	
	_clear_hover()
	hovered_piece = new_hover
	if hovered_piece != null:
		hovered_piece.set_hovered(true)
		if hovered_piece != selected_piece and hovered_piece != checked_king_piece:
			hovered_piece.set_highlight_state(ChessPiece.HighlightState.HOVERED)

func _clear_hover() -> void:
	if hovered_piece == null:
		return
	hovered_piece.set_hovered(false)
	if hovered_piece == selected_piece:
		hovered_piece.set_highlight_state(ChessPiece.HighlightState.SELECTED)
	elif hovered_piece == checked_king_piece:
		hovered_piece.set_highlight_state(ChessPiece.HighlightState.CHECK)
	else:
		hovered_piece.set_highlight_state(ChessPiece.HighlightState.NONE)
	hovered_piece = null

func _handle_tile_click(clicked_grid: Vector2i) -> void:
	var clicked_piece: ChessPiece = board_state.get(clicked_grid, null)
	
	if selected_piece != null:
		if clicked_grid == selected_grid:
			_clear_selection()
			return
		
		if clicked_piece != null and clicked_piece.faction == current_turn:
			_select_piece(clicked_grid, clicked_piece)
			return
		
		if clicked_grid in valid_moves:
			try_move(selected_grid, clicked_grid)
		return
	
	if clicked_piece != null and clicked_piece.faction == current_turn:
		_select_piece(clicked_grid, clicked_piece)

func _select_piece(grid_pos: Vector2i, piece: ChessPiece) -> void:
	if selected_piece != null and selected_piece != checked_king_piece:
		selected_piece.set_highlight_state(ChessPiece.HighlightState.NONE)
	
	selected_grid = grid_pos
	selected_piece = piece
	selected_role_changed.emit(piece.type)
	if selected_piece != checked_king_piece:
		selected_piece.set_highlight_state(ChessPiece.HighlightState.SELECTED)
	
	selection_highlight.position = grid_to_world(grid_pos)
	selection_highlight.visible = true
	
	valid_moves = _get_legal_moves(piece)
	_render_valid_move_markers()

func _clear_selection() -> void:
	if selected_piece != null:
		if selected_piece == checked_king_piece:
			selected_piece.set_highlight_state(ChessPiece.HighlightState.CHECK)
		else:
			selected_piece.set_highlight_state(ChessPiece.HighlightState.NONE)
	
	selected_grid = Vector2i(-1, -1)
	selected_piece = null
	selected_role_changed.emit(-1)
	valid_moves.clear()
	selection_highlight.visible = false
	_clear_valid_move_markers()

func _render_valid_move_markers() -> void:
	_clear_valid_move_markers()
	
	for move_pos in valid_moves:
		var marker := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.22
		torus.outer_radius = 0.30
		marker.mesh = torus
		marker.scale = Vector3(1.0, 0.25, 1.0)
		marker.position = grid_to_world(move_pos) + Vector3(0, 0.015, 0)
		
		var mat := StandardMaterial3D.new()
		var is_ep: bool = (selected_piece.type == ChessPiece.PieceType.PAWN and move_pos == en_passant_target)
		var is_capture: bool = board_state.has(move_pos) or is_ep
		if is_capture:
			mat.albedo_color = Color(1.0, 0.25, 0.2)
			mat.emission = Color(1.0, 0.2, 0.15)
		else:
			mat.albedo_color = Color(1.0, 0.85, 0.35)
			mat.emission = Color(1.0, 0.78, 0.25)
		
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 2.0
		marker.material_override = mat
		
		valid_moves_container.add_child(marker)

func _clear_valid_move_markers() -> void:
	for child in valid_moves_container.get_children():
		child.queue_free()

func try_uci_move(move: String) -> bool:
	if move.length() != 4 and move.length() != 5:
		return false
	var from := _algebraic_to_grid(move.substr(0, 2))
	var to := _algebraic_to_grid(move.substr(2, 2))
	var promotion: int = PROMOTION_TYPES.get(move.substr(4, 1), -1)
	if not _is_inside_board(from) or not _is_inside_board(to):
		return false
	var piece: ChessPiece = board_state.get(from)
	if piece == null or _is_promotion(piece, to) != (promotion != -1):
		return false
	if move.length() == 5 and promotion == -1:
		return false
	return try_move(from, to, promotion)


func try_move(from: Vector2i, to: Vector2i, promotion: int = -1) -> bool:
	if is_in_menu or is_game_over or awaiting_promotion or resolving_move:
		return false
	var piece: ChessPiece = board_state.get(from)
	if not piece or piece.faction != current_turn or to not in _get_legal_moves(piece):
		return false
	if promotion != -1 and (promotion not in PROMOTION_TYPES.values() or not _is_promotion(piece, to)):
		return false
	_apply_move(piece, from, to, promotion)
	return true


func _apply_move(piece: ChessPiece, from: Vector2i, to: Vector2i, promotion: int) -> void:
	resolving_move = true
	_clear_hover()
	_clear_selection()
	var captured: ChessPiece = board_state.get(to)
	var capture_square := to
	var notation := ""
	if piece.type == ChessPiece.PieceType.PAWN and to == en_passant_target and captured == null:
		capture_square = Vector2i(to.x, from.y)
		captured = board_state.get(capture_square)
		notation = "%s×%s e.p." % [_grid_to_algebraic(from), _grid_to_algebraic(to)]

	var was_capture := captured != null
	if captured:
		_notify_capture(piece, captured)
		board_state.erase(capture_square)
		if captured == checked_king_piece:
			checked_king_piece = null
		captured.queue_free()

	var rook_animation: Tween
	if piece.type == ChessPiece.PieceType.KING and absi(to.x - from.x) == 2:
		var kingside := to.x > from.x
		var rook_from := Vector2i(7 if kingside else 0, from.y)
		var rook_to := Vector2i(5 if kingside else 3, from.y)
		var rook: ChessPiece = board_state[rook_from]
		board_state.erase(rook_from)
		board_state[rook_to] = rook
		rook_animation = rook.move_to(rook_to, grid_to_world(rook_to))
		notation = "O-O" if kingside else "O-O-O"

	board_state.erase(from)
	board_state[to] = piece
	en_passant_target = Vector2i(-1, -1)
	if piece.type == ChessPiece.PieceType.PAWN and absi(to.y - from.y) == 2:
		en_passant_target = Vector2i(from.x, (from.y + to.y) >> 1)

	last_move_from_highlight.position = grid_to_world(from)
	last_move_from_highlight.show()
	last_move_to_highlight.position = grid_to_world(to)
	last_move_to_highlight.show()

	var animation := piece.move_to(to, grid_to_world(to))
	await animation.finished
	if rook_animation and rook_animation.is_running():
		await rook_animation.finished
	resolving_move = false
	if is_game_over or is_queued_for_deletion():
		return
	if _is_promotion(piece, to) and promotion == -1:
		awaiting_promotion = true
		pending_promotion_pawn = piece
		pending_promotion_from = from
		pending_promotion_to = to
		pending_promotion_capture = was_capture
		promotion_required.emit()
		return
	_finish_move(piece, from, to, was_capture, promotion, notation)


func _is_promotion(piece: ChessPiece, to: Vector2i) -> bool:
	return piece.type == ChessPiece.PieceType.PAWN and to.y == (0 if piece.faction == ChessPiece.Faction.GOLD else 7)


func _finish_move(piece: ChessPiece, from: Vector2i, to: Vector2i, capture: bool, promotion: int, notation: String = "") -> void:
	if notation.is_empty():
		var notation_promotion := ChessPiece.PieceType.PAWN if promotion == -1 else promotion as ChessPiece.PieceType
		notation = _format_move_notation(piece.type, from, to, capture, notation_promotion)
	var suffix := ""
	if promotion != -1:
		suffix = PROMOTION_TYPES.find_key(promotion)
		piece.promote_to(promotion as ChessPiece.PieceType)
	uci_history.append(_grid_to_algebraic(from) + _grid_to_algebraic(to) + suffix)
	move_recorded.emit(current_turn, notation)
	_switch_turn()


func _algebraic_to_grid(square: String) -> Vector2i:
	return Vector2i("abcdefgh".find(square[0]), 7 - "12345678".find(square[1]))


func _notify_capture(attacker: ChessPiece, defender: ChessPiece) -> void:
	piece_captured.emit(attacker.faction, defender.type)
	capture_replay_requested.emit(attacker.type, defender.type, attacker.faction)

func complete_pawn_promotion(chosen_type: ChessPiece.PieceType) -> void:
	if is_game_over or not awaiting_promotion or chosen_type not in PROMOTION_TYPES.values():
		return
	var pawn := pending_promotion_pawn
	awaiting_promotion = false
	pending_promotion_pawn = null
	_finish_move(pawn, pending_promotion_from, pending_promotion_to, pending_promotion_capture, chosen_type)


func _format_move_notation(p_type: ChessPiece.PieceType, from_pos: Vector2i, to_pos: Vector2i, is_capture: bool, promo_type: ChessPiece.PieceType) -> String:
	var prefix := _piece_symbol(p_type)
	var sep := "×" if is_capture else "→"
	var promo := "=" + _piece_symbol(promo_type) if promo_type != ChessPiece.PieceType.PAWN else ""
	return "%s%s%s%s%s" % [prefix, _grid_to_algebraic(from_pos), sep, _grid_to_algebraic(to_pos), promo]

func _piece_symbol(p_type: ChessPiece.PieceType) -> String:
	match p_type:
		ChessPiece.PieceType.KING: return "K"
		ChessPiece.PieceType.QUEEN: return "Q"
		ChessPiece.PieceType.ROOK: return "R"
		ChessPiece.PieceType.BISHOP: return "B"
		ChessPiece.PieceType.KNIGHT: return "N"
	return ""

func _grid_to_algebraic(pos: Vector2i) -> String:
	var files := ["a", "b", "c", "d", "e", "f", "g", "h"]
	var rank := 8 - pos.y
	return "%s%d" % [files[pos.x], rank]

func _switch_turn() -> void:
	current_turn = ChessPiece.Faction.OBSIDIAN if current_turn == ChessPiece.Faction.GOLD else ChessPiece.Faction.GOLD
	turn_changed.emit(current_turn)
	
	var in_check: bool = _is_king_in_check(current_turn, board_state)
	
	if checked_king_piece != null:
		checked_king_piece.set_highlight_state(ChessPiece.HighlightState.NONE)
		checked_king_piece = null
	
	if in_check:
		var king_grid := _find_king_pos(current_turn, board_state)
		if king_grid != Vector2i(-1, -1):
			king_check_highlight.position = grid_to_world(king_grid)
			king_check_highlight.visible = true
			checked_king_piece = board_state.get(king_grid, null)
			if checked_king_piece != null:
				checked_king_piece.set_highlight_state(ChessPiece.HighlightState.CHECK)
	else:
		king_check_highlight.visible = false
	
	var has_any_legal_move: bool = _faction_has_legal_moves(current_turn)
	
	if not has_any_legal_move:
		is_game_over = true
		var winner := ChessPiece.Faction.OBSIDIAN if current_turn == ChessPiece.Faction.GOLD else ChessPiece.Faction.GOLD
		if in_check:
			game_over.emit(winner, "SKAKMAT!")
		else:
			game_over.emit(winner, "SERI (STALEMATE)!")
		return
	
	check_state_changed.emit(in_check)

func _find_king_pos(faction: ChessPiece.Faction, state: Dictionary) -> Vector2i:
	for pos in state.keys():
		var p: ChessPiece = state[pos]
		if p.faction == faction and p.type == ChessPiece.PieceType.KING:
			return pos
	return Vector2i(-1, -1)

# ==============================================================================
# LOGIKA VALIDASI SKAK, ROKADE & EN PASSANT
# ==============================================================================
func _get_legal_moves(piece: ChessPiece) -> Array[Vector2i]:
	var pseudo_moves := _get_pseudo_legal_moves(piece, piece.grid_pos, board_state, true)
	var legal_moves: Array[Vector2i] = []
	
	for target_pos in pseudo_moves:
		var target: ChessPiece = board_state.get(target_pos)
		if target and target.type == ChessPiece.PieceType.KING:
			continue
		if _is_move_safe_for_king(piece, target_pos):
			legal_moves.append(target_pos)
	
	return legal_moves

func _is_move_safe_for_king(piece: ChessPiece, target_pos: Vector2i) -> bool:
	var sim_state := board_state.duplicate()
	sim_state.erase(piece.grid_pos)
	
	# Simulasikan juga penghapusan pion lawan jika langkahnya En Passant
	if piece.type == ChessPiece.PieceType.PAWN and target_pos == en_passant_target and not sim_state.has(target_pos):
		sim_state.erase(Vector2i(target_pos.x, piece.grid_pos.y))
	
	if piece.type == ChessPiece.PieceType.KING and absi(target_pos.x - piece.grid_pos.x) == 2:
		var kingside := target_pos.x > piece.grid_pos.x
		var rook_from := Vector2i(7 if kingside else 0, target_pos.y)
		var rook_to := Vector2i(5 if kingside else 3, target_pos.y)
		sim_state[rook_to] = sim_state[rook_from]
		sim_state.erase(rook_from)
	sim_state[target_pos] = piece
	return not _is_king_in_check(piece.faction, sim_state, piece, target_pos)

func _is_king_in_check(faction: ChessPiece.Faction, state: Dictionary, moved_piece: ChessPiece = null, moved_pos: Vector2i = Vector2i(-1, -1)) -> bool:
	var king_pos := _find_king_pos(faction, state)
	if king_pos == Vector2i(-1, -1):
		return false
	
	for pos in state.keys():
		var enemy: ChessPiece = state[pos]
		if enemy.faction != faction:
			var effective_pos: Vector2i = moved_pos if enemy == moved_piece else pos
			var attacks := _get_pseudo_legal_moves(enemy, effective_pos, state, false)
			if king_pos in attacks:
				return true
	
	return false

func _faction_has_legal_moves(faction: ChessPiece.Faction) -> bool:
	var pieces: Array[ChessPiece] = []
	for p in board_state.values():
		if p.faction == faction:
			pieces.append(p)
	
	for p in pieces:
		if _get_legal_moves(p).size() > 0:
			return true
	return false

func _get_pseudo_legal_moves(piece: ChessPiece, pos: Vector2i, state: Dictionary, include_castling: bool = false) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	
	match piece.type:
		ChessPiece.PieceType.PAWN:
			var dir: int = -1 if piece.faction == ChessPiece.Faction.GOLD else 1
			var start_row: int = 6 if piece.faction == ChessPiece.Faction.GOLD else 1
			
			var one_step := Vector2i(pos.x, pos.y + dir)
			if _is_inside_board(one_step) and not state.has(one_step):
				moves.append(one_step)
				var two_step := Vector2i(pos.x, pos.y + (dir * 2))
				if pos.y == start_row and not state.has(two_step):
					moves.append(two_step)
			
			for dx in [-1, 1]:
				var diag := Vector2i(pos.x + dx, pos.y + dir)
				if _is_inside_board(diag):
					if state.has(diag):
						var target: ChessPiece = state[diag]
						if target.faction != piece.faction:
							moves.append(diag)
					elif diag == en_passant_target:
						moves.append(diag)
		
		ChessPiece.PieceType.ROOK:
			moves.append_array(_get_sliding_moves(piece, pos, state, [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
			]))
		
		ChessPiece.PieceType.BISHOP:
			moves.append_array(_get_sliding_moves(piece, pos, state, [
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
			]))
		
		ChessPiece.PieceType.QUEEN:
			moves.append_array(_get_sliding_moves(piece, pos, state, [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
			]))
		
		ChessPiece.PieceType.KNIGHT:
			var jumps: Array[Vector2i] = [
				Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
				Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2)
			]
			for j in jumps:
				var target_pos: Vector2i = pos + j
				if _can_land_on(piece, target_pos, state):
					moves.append(target_pos)
		
		ChessPiece.PieceType.KING:
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var target_pos: Vector2i = pos + Vector2i(dx, dy)
					if _can_land_on(piece, target_pos, state):
						moves.append(target_pos)
			
			# Rokade (Kingside & Queenside)
			var home_row := 7 if piece.faction == ChessPiece.Faction.GOLD else 0
			if include_castling and pos == Vector2i(4, home_row) and not piece.has_moved and not _is_king_in_check(piece.faction, state):
				var row: int = pos.y
				# Kingside (Benteng kolom 7)
				var k_rook: ChessPiece = state.get(Vector2i(7, row), null)
				if k_rook != null and k_rook.faction == piece.faction and k_rook.type == ChessPiece.PieceType.ROOK and not k_rook.has_moved:
					if not state.has(Vector2i(5, row)) and not state.has(Vector2i(6, row)):
						if _is_move_safe_for_king(piece, Vector2i(5, row)) and _is_move_safe_for_king(piece, Vector2i(6, row)):
							moves.append(Vector2i(6, row))
				
				# Queenside (Benteng kolom 0)
				var q_rook: ChessPiece = state.get(Vector2i(0, row), null)
				if q_rook != null and q_rook.faction == piece.faction and q_rook.type == ChessPiece.PieceType.ROOK and not q_rook.has_moved:
					if not state.has(Vector2i(1, row)) and not state.has(Vector2i(2, row)) and not state.has(Vector2i(3, row)):
						if _is_move_safe_for_king(piece, Vector2i(3, row)) and _is_move_safe_for_king(piece, Vector2i(2, row)):
							moves.append(Vector2i(2, row))
	
	return moves

func _get_sliding_moves(piece: ChessPiece, start_pos: Vector2i, state: Dictionary, directions: Array[Vector2i]) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for dir in directions:
		var current: Vector2i = start_pos + dir
		while _is_inside_board(current):
			if not state.has(current):
				moves.append(current)
			else:
				var occupant: ChessPiece = state[current]
				if occupant.faction != piece.faction:
					moves.append(current)
				break
			current += dir
	return moves

func _can_land_on(piece: ChessPiece, target_pos: Vector2i, state: Dictionary) -> bool:
	if not _is_inside_board(target_pos):
		return false
	if not state.has(target_pos):
		return true
	var occupant: ChessPiece = state[target_pos]
	return occupant.faction != piece.faction

func _is_inside_board(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var offset: float = (8.0 * tile_size) / 2.0 - (tile_size / 2.0)
	var pos_x: float = (grid_pos.x * tile_size) - offset
	var pos_z: float = (grid_pos.y * tile_size) - offset
	return Vector3(pos_x, 0.0, pos_z)
