extends Node3D

@export var tile_size: float = 1.0
@export var tile_height: float = 0.2
@export var light_color: Color = Color(0.87, 0.77, 0.60)
@export var dark_color: Color = Color(0.28, 0.16, 0.09)

const PIECE_SCENE: PackedScene = preload("res://scenes/pieces/chess_piece.tscn")

var light_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var selection_highlight: Node3D

var selected_grid: Vector2i = Vector2i(-1, -1)
var selected_piece: ChessPiece = null
var board_state: Dictionary = {} # Menyimpan pemetaan Vector2i -> ChessPiece

func _ready() -> void:
	_setup_materials()
	_generate_board()
	_create_highlight_frame()
	_spawn_initial_pieces()

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
		# Faksi Gelap (Obsidian) di baris atas (row 0 & 1)
		_spawn_piece(back_rank[col], ChessPiece.Faction.OBSIDIAN, Vector2i(col, 0))
		_spawn_piece(ChessPiece.PieceType.PAWN, ChessPiece.Faction.OBSIDIAN, Vector2i(col, 1))
		
		# Faksi Terang (Emas Nusantara) di baris bawah (row 6 & 7)
		_spawn_piece(ChessPiece.PieceType.PAWN, ChessPiece.Faction.GOLD, Vector2i(col, 6))
		_spawn_piece(back_rank[col], ChessPiece.Faction.GOLD, Vector2i(col, 7))

func _spawn_piece(p_type: ChessPiece.PieceType, p_faction: ChessPiece.Faction, grid_pos: Vector2i) -> void:
	var piece: ChessPiece = PIECE_SCENE.instantiate()
	add_child(piece)
	piece.setup(p_type, p_faction, grid_pos, grid_to_world(grid_pos))
	board_state[grid_pos] = piece

func _unhandled_input(event: InputEvent) -> void:
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
	
	# Kasus 1: Sudah ada bidak terpilih sebelumnya
	if selected_piece != null:
		# Jika klik petak yang sama -> batalkan pilihan
		if clicked_grid == selected_grid:
			_clear_selection()
			return
		
		# Jika klik bidak lain milik faksi yang sama -> ganti pilihan ke bidak itu
		if clicked_piece != null and clicked_piece.faction == selected_piece.faction:
			_select_piece(clicked_grid, clicked_piece)
			return
		
		# Jika klik petak kosong atau bidak lawan -> pindahkan bidak terpilih ke sana!
		_move_selected_piece(clicked_grid, clicked_piece)
		return
	
	# Kasus 2: Belum ada bidak terpilih, dan petak yang diklik ada bidaknya
	if clicked_piece != null:
		_select_piece(clicked_grid, clicked_piece)

func _select_piece(grid_pos: Vector2i, piece: ChessPiece) -> void:
	selected_grid = grid_pos
	selected_piece = piece
	selection_highlight.position = grid_to_world(grid_pos)
	selection_highlight.visible = true

func _clear_selection() -> void:
	selected_grid = Vector2i(-1, -1)
	selected_piece = null
	selection_highlight.visible = false

func _move_selected_piece(target_grid: Vector2i, captured_piece: ChessPiece) -> void:
	# Hapus bidak lawan jika ada di petak tujuan
	if captured_piece != null:
		captured_piece.queue_free()
	
	# Perbarui data grid
	board_state.erase(selected_grid)
	board_state[target_grid] = selected_piece
	
	# Jalankan animasi meluncur ke petak tujuan
	selected_piece.move_to(target_grid, grid_to_world(target_grid))
	_clear_selection()

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var offset: float = (8.0 * tile_size) / 2.0 - (tile_size / 2.0)
	var pos_x: float = (grid_pos.x * tile_size) - offset
	var pos_z: float = (grid_pos.y * tile_size) - offset
	return Vector3(pos_x, 0.0, pos_z)
