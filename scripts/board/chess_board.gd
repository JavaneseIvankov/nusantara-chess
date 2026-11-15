extends Node3D

signal turn_changed(new_faction: ChessPiece.Faction)
signal game_over(winner_faction: ChessPiece.Faction)

@export var tile_size: float = 1.0
@export var tile_height: float = 0.2
@export var light_color: Color = Color(0.87, 0.77, 0.60)
@export var dark_color: Color = Color(0.28, 0.16, 0.09)

const PIECE_SCENE: PackedScene = preload("res://scenes/pieces/chess_piece.tscn")

var light_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var selection_highlight: Node3D
var valid_moves_container: Node3D

var current_turn: ChessPiece.Faction = ChessPiece.Faction.GOLD
var is_game_over: bool = false

var selected_grid: Vector2i = Vector2i(-1, -1)
var selected_piece: ChessPiece = null
var valid_moves: Array[Vector2i] = []
var board_state: Dictionary = {} # Vector2i -> ChessPiece

func _ready() -> void:
	_setup_materials()
	_generate_board()
	_create_highlight_frame()
	_create_valid_moves_container()
	_spawn_initial_pieces()
	print("=== GILIRAN: FAKSI EMAS (GOLD) ===")

func _setup_materials() -> void:
	light_material = StandardMaterial3D.new()
	light_material.albedo_color = light_color
	
	dark_material = StandardMaterial3D.new()
	dark_material.albedo_color = dark_color

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
			mesh_instance.material_override = light_material if is_light else dark_material
			
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

func _create_highlight_frame() -> void:
	selection_highlight = Node3D.new()
	selection_highlight.name = "SelectionHighlight"
	selection_highlight.visible = false
	
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.85, 0.3)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.78, 0.2)
	glow_mat.emission_energy_multiplier = 2.5
	
	var thickness: float = 0.05
	var height: float = 0.015
	var edge_len: float = tile_size * 0.94
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
		selection_highlight.add_child(bar)
	
	add_child(selection_highlight)

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
	if is_game_over:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_raycast_board(event.position)

func _raycast_board(mouse_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_end := ray_origin + camera.project_ray_normal(mouse_pos) * 100.0
	
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result := space_state.intersect_ray(query)
	
	if result and result.collider.has_meta("grid_pos"):
		var clicked_grid: Vector2i = result.collider.get_meta("grid_pos")
		_handle_tile_click(clicked_grid)

func _handle_tile_click(clicked_grid: Vector2i) -> void:
	var clicked_piece: ChessPiece = board_state.get(clicked_grid, null)
	
	# Jika sudah ada bidak terpilih
	if selected_piece != null:
		if clicked_grid == selected_grid:
			_clear_selection()
			return
		
		# Ganti pilihan jika mengklik bidak lain milik faksi yang sedang mendapat giliran
		if clicked_piece != null and clicked_piece.faction == current_turn:
			_select_piece(clicked_grid, clicked_piece)
			return
		
		# Cek apakah petak tujuan termasuk dalam daftar langkah sah
		if clicked_grid in valid_moves:
			_move_selected_piece(clicked_grid, clicked_piece)
		else:
			print("Langkah tidak sah untuk bidak ini!")
		return
	
	# Hanya boleh memilih bidak milik faksi yang sedang mendapat giliran
	if clicked_piece != null:
		if clicked_piece.faction == current_turn:
			_select_piece(clicked_grid, clicked_piece)
		else:
			print("Bukan giliran faksi ini!")

func _select_piece(grid_pos: Vector2i, piece: ChessPiece) -> void:
	selected_grid = grid_pos
	selected_piece = piece
	selection_highlight.position = grid_to_world(grid_pos)
	selection_highlight.visible = true
	
	valid_moves = _get_valid_moves(piece)
	_render_valid_move_markers()

func _clear_selection() -> void:
	selected_grid = Vector2i(-1, -1)
	selected_piece = null
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
		var is_capture: bool = board_state.has(move_pos)
		if is_capture:
			mat.albedo_color = Color(1.0, 0.25, 0.2) # Merah menyala jika memakan lawan
			mat.emission = Color(1.0, 0.2, 0.15)
		else:
			mat.albedo_color = Color(1.0, 0.85, 0.35) # Emas lembut untuk petak kosong
			mat.emission = Color(1.0, 0.78, 0.25)
		
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 2.0
		marker.material_override = mat
		
		valid_moves_container.add_child(marker)

func _clear_valid_move_markers() -> void:
	for child in valid_moves_container.get_children():
		child.queue_free()

func _move_selected_piece(target_grid: Vector2i, captured_piece: ChessPiece) -> void:
	var king_captured: bool = false
	
	if captured_piece != null:
		if captured_piece.type == ChessPiece.PieceType.KING:
			king_captured = true
		captured_piece.queue_free()
	
	board_state.erase(selected_grid)
	board_state[target_grid] = selected_piece
	
	selected_piece.move_to(target_grid, grid_to_world(target_grid))
	_clear_selection()
	
	if king_captured:
		is_game_over = true
		var winner_name := "FAKSI EMAS (GOLD)" if current_turn == ChessPiece.Faction.GOLD else "FAKSI OBSIDIAN"
		print("=== PERTANDINGAN SELESAI! PEMENANG: ", winner_name, " ===")
		game_over.emit(current_turn)
		return
	
	_switch_turn()

func _switch_turn() -> void:
	if current_turn == ChessPiece.Faction.GOLD:
		current_turn = ChessPiece.Faction.OBSIDIAN
		print("=== GILIRAN: FAKSI OBSIDIAN ===")
	else:
		current_turn = ChessPiece.Faction.GOLD
		print("=== GILIRAN: FAKSI EMAS (GOLD) ===")
	turn_changed.emit(current_turn)

# ==============================================================================
# LOGIKA ATURAN GERAK BIDAK CATUR
# ==============================================================================
func _get_valid_moves(piece: ChessPiece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var pos := piece.grid_pos
	
	match piece.type:
		ChessPiece.PieceType.PAWN:
			var dir: int = -1 if piece.faction == ChessPiece.Faction.GOLD else 1
			var start_row: int = 6 if piece.faction == ChessPiece.Faction.GOLD else 1
			
			# Maju 1 langkah
			var one_step := Vector2i(pos.x, pos.y + dir)
			if _is_inside_board(one_step) and not board_state.has(one_step):
				moves.append(one_step)
				# Maju 2 langkah dari baris awal
				var two_step := Vector2i(pos.x, pos.y + (dir * 2))
				if pos.y == start_row and not board_state.has(two_step):
					moves.append(two_step)
			
			# Makan serong kiri & kanan
			for dx in [-1, 1]:
				var diag := Vector2i(pos.x + dx, pos.y + dir)
				if _is_inside_board(diag) and board_state.has(diag):
					var target: ChessPiece = board_state[diag]
					if target.faction != piece.faction:
						moves.append(diag)
		
		ChessPiece.PieceType.ROOK:
			moves.append_array(_get_sliding_moves(piece, [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
			]))
		
		ChessPiece.PieceType.BISHOP:
			moves.append_array(_get_sliding_moves(piece, [
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
			]))
		
		ChessPiece.PieceType.QUEEN:
			moves.append_array(_get_sliding_moves(piece, [
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
				if _can_land_on(piece, target_pos):
					moves.append(target_pos)
		
		ChessPiece.PieceType.KING:
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var target_pos := pos + Vector2i(dx, dy)
					if _can_land_on(piece, target_pos):
						moves.append(target_pos)
	
	return moves

func _get_sliding_moves(piece: ChessPiece, directions: Array[Vector2i]) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for dir in directions:
		var current := piece.grid_pos + dir
		while _is_inside_board(current):
			if not board_state.has(current):
				moves.append(current)
			else:
				var occupant: ChessPiece = board_state[current]
				if occupant.faction != piece.faction:
					moves.append(current)
				break
			current += dir
	return moves

func _can_land_on(piece: ChessPiece, target_pos: Vector2i) -> bool:
	if not _is_inside_board(target_pos):
		return false
	if not board_state.has(target_pos):
		return true
	var occupant: ChessPiece = board_state[target_pos]
	return occupant.faction != piece.faction

func _is_inside_board(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var offset: float = (8.0 * tile_size) / 2.0 - (tile_size / 2.0)
	var pos_x: float = (grid_pos.x * tile_size) - offset
	var pos_z: float = (grid_pos.y * tile_size) - offset
	return Vector3(pos_x, 0.0, pos_z)
