extends Node3D

@export var board_size: float = 8.0
@export var board_thickness: float = 0.2

const ENV_PATHS := {
	"floor": "res://assets/models/environment/courtyard_floor.glb",
	"frame": "res://assets/models/environment/board_frame.glb",
	"torch": "res://assets/models/environment/torch_pillar.glb",
	"candi": "res://assets/models/environment/candi_bentar.glb"
}

func _ready() -> void:
	_build_courtyard_floor()
	_build_board_frame()
	_build_torch_pillars()
	_build_candi_bentar()

func _try_load_glb(key: String) -> Node3D:
	var path: String = ENV_PATHS.get(key, "")
	if path != "" and ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		if scene != null:
			return scene.instantiate()
	return null

# 1. Pelataran Batu Candi
func _build_courtyard_floor() -> void:
	var custom_floor := _try_load_glb("floor")
	if custom_floor != null:
		custom_floor.name = "CourtyardFloorGLB"
		custom_floor.position = Vector3(0, -board_thickness, 0)
		add_child(custom_floor)
		return
	
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "CourtyardFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(36.0, 36.0)
	floor_mesh.mesh = plane
	
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.14, 0.14, 0.15)
	stone_mat.roughness = 0.88
	floor_mesh.material_override = stone_mat
	floor_mesh.position = Vector3(0, -board_thickness, 0)
	add_child(floor_mesh)

# 2. Bingkai Papan Kayu Jati Ukir
func _build_board_frame() -> void:
	var custom_frame := _try_load_glb("frame")
	if custom_frame != null:
		custom_frame.name = "BoardFrameGLB"
		custom_frame.position = Vector3(0, -board_thickness, 0)
		add_child(custom_frame)
		return
	
	var frame_root := Node3D.new()
	frame_root.name = "BoardFrame"
	add_child(frame_root)
	
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.16, 0.08, 0.03)
	wood_mat.roughness = 0.55
	
	var border_width: float = 0.45
	var frame_height: float = 0.24
	var outer_span: float = board_size + (border_width * 2.0)
	var offset: float = (board_size / 2.0) + (border_width / 2.0)
	var pos_y: float = -board_thickness + (frame_height / 2.0) - 0.02
	
	var sides := [
		{"size": Vector3(outer_span, frame_height, border_width), "pos": Vector3(0, pos_y, -offset)},
		{"size": Vector3(outer_span, frame_height, border_width), "pos": Vector3(0, pos_y, offset)},
		{"size": Vector3(border_width, frame_height, board_size), "pos": Vector3(-offset, pos_y, 0)},
		{"size": Vector3(border_width, frame_height, board_size), "pos": Vector3(offset, pos_y, 0)}
	]
	
	for s in sides:
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = s["size"]
		bar.mesh = box
		bar.material_override = wood_mat
		bar.position = s["pos"]
		frame_root.add_child(bar)

# 3. Empat Tiang Obor Batu di Sudut Papan + Partikel Percikan Api
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
	ember_mat.emission_energy_multiplier = 3.5
	
	var particle_mat := ParticleProcessMaterial.new()
	particle_mat.direction = Vector3(0, 1, 0)
	particle_mat.spread = 22.0
	particle_mat.initial_velocity_min = 0.5
	particle_mat.initial_velocity_max = 1.2
	particle_mat.gravity = Vector3(0, 0.3, 0)
	particle_mat.scale_min = 0.03
	particle_mat.scale_max = 0.07
	
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.5
	spark_mesh.height = 1.0
	spark_mesh.material = ember_mat
	
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
		
		var custom_torch := _try_load_glb("torch")
		if custom_torch != null:
			torch_node.add_child(custom_torch)
		else:
			var column := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.16
			cyl.bottom_radius = 0.24
			cyl.height = 2.2
			column.mesh = cyl
			column.material_override = pillar_mat
			column.position.y = 1.1
			torch_node.add_child(column)
			
			var ember := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.18
			sphere.height = 0.25
			ember.mesh = sphere
			ember.material_override = ember_mat
			ember.position.y = 2.25
			torch_node.add_child(ember)
		
		# Efek partikel percikan api tetap menyala di atas obor
		var sparks := GPUParticles3D.new()
		sparks.amount = 18
		sparks.lifetime = 1.4
		sparks.process_material = particle_mat
		sparks.draw_pass_1 = spark_mesh
		sparks.position.y = 2.3
		torch_node.add_child(sparks)

# 4. Gerbang Candi Bentar Latar Belakang (Otomatis muncul jika candi_bentar.glb tersedia)
func _build_candi_bentar() -> void:
	var north_candi := _try_load_glb("candi")
	if north_candi != null:
		north_candi.name = "CandiBentarNorth"
		north_candi.position = Vector3(0, -board_thickness, -8.5)
		add_child(north_candi)
	
	var south_candi := _try_load_glb("candi")
	if south_candi != null:
		south_candi.name = "CandiBentarSouth"
		south_candi.position = Vector3(0, -board_thickness, 8.5)
		south_candi.rotation.y = PI
		add_child(south_candi)
