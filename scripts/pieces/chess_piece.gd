class_name ChessPiece
extends Node3D

enum PieceType { PAWN, ROOK, KNIGHT, BISHOP, QUEEN, KING }
enum Faction { GOLD, OBSIDIAN } # GOLD = Faksi Nusantara Terang, OBSIDIAN = Faksi Gelap

var type: PieceType = PieceType.PAWN
var faction: Faction = Faction.GOLD
var grid_pos: Vector2i = Vector2i.ZERO

@onready var visual_mesh: MeshInstance3D = $VisualMesh

func setup(p_type: PieceType, p_faction: Faction, start_grid: Vector2i, world_pos: Vector3) -> void:
	type = p_type
	faction = p_faction
	grid_pos = start_grid
	position = world_pos
	
	_build_placeholder_visual()

# Membuat bentuk 3D sementara berdasarkan jenis bidak (mudah diganti model .glb nanti)
func _build_placeholder_visual() -> void:
	var mat := StandardMaterial3D.new()
	if faction == Faction.GOLD:
		mat.albedo_color = Color(0.85, 0.65, 0.25) # Perunggu emas
		mat.metallic = 0.65
		mat.roughness = 0.35
	else:
		mat.albedo_color = Color(0.18, 0.20, 0.24) # Batu candi / besi obsidian
		mat.metallic = 0.45
		mat.roughness = 0.50
	
	var mesh: Mesh
	var height: float = 0.6
	
	match type:
		PieceType.PAWN:
			var cap := CapsuleMesh.new()
			cap.radius = 0.22
			cap.height = 0.55
			mesh = cap
			height = 0.55
		PieceType.ROOK:
			var box := BoxMesh.new()
			box.size = Vector3(0.48, 0.75, 0.48)
			mesh = box
			height = 0.75
		PieceType.KNIGHT:
			var prism := PrismMesh.new()
			prism.size = Vector3(0.45, 0.80, 0.55)
			mesh = prism
			height = 0.80
		PieceType.BISHOP:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.08
			cyl.bottom_radius = 0.26
			cyl.height = 0.90
			mesh = cyl
			height = 0.90
		PieceType.QUEEN:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.20
			cyl.bottom_radius = 0.30
			cyl.height = 1.05
			mesh = cyl
			height = 1.05
		PieceType.KING:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.26
			cyl.bottom_radius = 0.32
			cyl.height = 1.20
			mesh = cyl
			height = 1.20
	
	visual_mesh.mesh = mesh
	visual_mesh.material_override = mat
	# Pastikan bagian dasar bidak tepat menempel di permukaan papan (Y = 0)
	visual_mesh.position.y = height / 2.0

# Animasi meluncur mulus saat bidak berpindah petak
func move_to(new_grid_pos: Vector2i, target_world_pos: Vector3) -> void:
	grid_pos = new_grid_pos
	
	var duration: float = 0.28
	var tween := create_tween()
	tween.set_parallel(true)
	
	# Gerak horizontal (X dan Z) mulus
	tween.tween_property(self, "position:x", target_world_pos.x, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:z", target_world_pos.z, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Khusus Kuda: melompat melengkung ke atas lalu mendarat!
	if type == PieceType.KNIGHT:
		var arc_tween := create_tween()
		arc_tween.tween_property(self, "position:y", target_world_pos.y + 0.65, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		arc_tween.tween_property(self, "position:y", target_world_pos.y, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(self, "position:y", target_world_pos.y, duration)

# Mengubah jenis dan bentuk 3D bidak saat Pion mencapai baris ujung (Promosi)
func promote_to(new_type: PieceType) -> void:
	type = new_type
	_build_placeholder_visual()
