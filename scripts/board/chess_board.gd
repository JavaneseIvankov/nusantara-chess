extends Node3D

@export var tile_size: float = 1.0
@export var tile_height: float = 0.2
@export var light_color: Color = Color(0.87, 0.77, 0.60) # Warna kayu terang / gading
@export var dark_color: Color = Color(0.28, 0.16, 0.09)  # Warna kayu jati gelap

var light_material: StandardMaterial3D
var dark_material: StandardMaterial3D

func _ready() -> void:
	_setup_materials()
	_generate_board()

func _setup_materials() -> void:
	light_material = StandardMaterial3D.new()
	light_material.albedo_color = light_color
	
	dark_material = StandardMaterial3D.new()
	dark_material.albedo_color = dark_color

func _generate_board() -> void:
	# Offset agar titik tengah papan berada tepat di koordinat (0, 0, 0)
	var offset: float = (8.0 * tile_size) / 2.0 - (tile_size / 2.0)
	
	for row in range(8):
		for col in range(8):
			var tile_body := StaticBody3D.new()
			tile_body.name = "Tile_%d_%d" % [row, col]
			
			# Simpan koordinat grid (x, z) ke dalam metadata node agar mudah dibaca saat diklik
			tile_body.set_meta("grid_pos", Vector2i(col, row))
			
			# Mesh visual kotak
			var mesh_instance := MeshInstance3D.new()
			var box_mesh := BoxMesh.new()
			box_mesh.size = Vector3(tile_size, tile_height, tile_size)
			mesh_instance.mesh = box_mesh
			
			# Selang-seling warna terang dan gelap
			var is_light: bool = (row + col) % 2 == 0
			mesh_instance.material_override = light_material if is_light else dark_material
			
			# Collider untuk deteksi klik mouse (Raycasting)
			var collision_shape := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(tile_size, tile_height, tile_size)
			collision_shape.shape = box_shape
			
			tile_body.add_child(mesh_instance)
			tile_body.add_child(collision_shape)
			
			# Posisikan petak sehingga permukaan atasnya rata di Y = 0
			var pos_x: float = (col * tile_size) - offset
			var pos_z: float = (row * tile_size) - offset
			tile_body.position = Vector3(pos_x, -tile_height / 2.0, pos_z)
			
			add_child(tile_body)

# Fungsi helper untuk mendapatkan posisi dunia (3D) dari koordinat grid (0..7, 0..7)
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var offset: float = (8.0 * tile_size) / 2.0 - (tile_size / 2.0)
	var pos_x: float = (grid_pos.x * tile_size) - offset
	var pos_z: float = (grid_pos.y * tile_size) - offset
	return Vector3(pos_x, 0.0, pos_z)
