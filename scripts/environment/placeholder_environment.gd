class_name PlaceholderEnvironment
extends Node3D

@export var board_size: float = 8.0
@export var board_thickness: float = 0.2

func _ready() -> void:
	_build_courtyard_floor()
	_build_board_frame()
	_build_torch_pillars()

# 1. Pelataran Batu Andesit Luas (24m x 24m di Y = -0.2m)
func _build_courtyard_floor() -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "CourtyardFloor"
	
	var box := BoxMesh.new()
	box.size = Vector3(24.0, 0.2, 24.0)
	floor_mesh.mesh = box
	
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.11, 0.12, 0.14) # Batu andesit candi gelap
	stone_mat.roughness = 0.85
	floor_mesh.material_override = stone_mat
	
	# Permukaan atas lantai tepat di Y = -0.2 (menopang dasar ubin papan)
	floor_mesh.position = Vector3(0.0, -board_thickness - 0.1, 0.0)
	add_child(floor_mesh)

# 2. Bingkai Kayu Jati & Lis Emas Mengelilingi Papan 8x8
func _build_board_frame() -> void:
	var frame_root := Node3D.new()
	frame_root.name = "BoardFrame"
	add_child(frame_root)
	
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.16, 0.09, 0.05) # Kayu jati tua gelap
	wood_mat.roughness = 0.55
	
	var gold_trim_mat := StandardMaterial3D.new()
	gold_trim_mat.albedo_color = Color(0.76, 0.58, 0.22) # Aksen lis perunggu emas
	gold_trim_mat.metallic = 0.75
	gold_trim_mat.roughness = 0.30
	
	var rim_width: float = 0.60
	var rim_height: float = 0.24 # Sedikit lebih tinggi (0.04m) dari permukaan papan
	var outer_span: float = board_size + (rim_width * 2.0) # 9.2m
	var offset: float = (board_size / 2.0) + (rim_width / 2.0) # 4.3m
	
	# 4 Sisi Bingkai Kayu Utama (Utara, Selatan, Barat, Timur)
	var wood_bars := [
		{"size": Vector3(outer_span, rim_height, rim_width), "pos": Vector3(0.0, -0.08, -offset)},
		{"size": Vector3(outer_span, rim_height, rim_width), "pos": Vector3(0.0, -0.08, offset)},
		{"size": Vector3(rim_width, rim_height, board_size), "pos": Vector3(-offset, -0.08, 0.0)},
		{"size": Vector3(rim_width, rim_height, board_size), "pos": Vector3(offset, -0.08, 0.0)}
	]
	
	for bar_data in wood_bars:
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = bar_data["size"]
		mesh_inst.mesh = box
		mesh_inst.material_override = wood_mat
		mesh_inst.position = bar_data["pos"]
		frame_root.add_child(mesh_inst)
	
	# Lis Emas Tipis di Bibir Dalam Bingkai
	var trim_w: float = 0.04
	var trim_h: float = 0.25
	var trim_span: float = board_size + (trim_w * 2.0)
	var trim_off: float = (board_size / 2.0) + (trim_w / 2.0)
	
	var gold_bars := [
		{"size": Vector3(trim_span, trim_h, trim_w), "pos": Vector3(0.0, -0.075, -trim_off)},
		{"size": Vector3(trim_span, trim_h, trim_w), "pos": Vector3(0.0, -0.075, trim_off)},
		{"size": Vector3(trim_w, trim_h, board_size), "pos": Vector3(-trim_off, -0.075, 0.0)},
		{"size": Vector3(trim_w, trim_h, board_size), "pos": Vector3(trim_off, -0.075, 0.0)}
	]
	
	for g_data in gold_bars:
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = g_data["size"]
		mesh_inst.mesh = box
		mesh_inst.material_override = gold_trim_mat
		mesh_inst.position = g_data["pos"]
		frame_root.add_child(mesh_inst)

# 3. Empat Tiang Obor Batu di Sudut Papan (Tinggi 2.2m sejajar TorchLight_1..4)
func _build_torch_pillars() -> void:
	var pillars_root := Node3D.new()
	pillars_root.name = "TorchPillars"
	add_child(pillars_root)
	
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.18, 0.17, 0.16)
	pillar_mat.roughness = 0.80
	
	var ember_mat := StandardMaterial3D.new()
	ember_mat.albedo_color = Color(1.0, 0.55, 0.1)
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(1.0, 0.45, 0.05)
	ember_mat.emission_energy_multiplier = 3.5 # Bara api menyala (Glow)
	
	var corners := [
		Vector3(-4.8, -0.2, -4.8),
		Vector3(4.8, -0.2, -4.8),
		Vector3(-4.8, -0.2, 4.8),
		Vector3(4.8, -0.2, 4.8)
	]
	
	for pos in corners:
		var torch_node := Node3D.new()
		torch_node.position = pos
		pillars_root.add_child(torch_node)
		
		# Tiang batu (tinggi 2.2m dari dasar lantai Y = -0.2 sampai puncak Y = 2.0)
		var column := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.16
		cyl.bottom_radius = 0.24
		cyl.height = 2.2
		column.mesh = cyl
		column.material_override = pillar_mat
		column.position.y = 1.1
		torch_node.add_child(column)
		
		# Mangkuk bara api di puncak tiang
		var ember := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.18
		sphere.height = 0.25
		ember.mesh = sphere
		ember.material_override = ember_mat
		ember.position.y = 2.25
		torch_node.add_child(ember)
