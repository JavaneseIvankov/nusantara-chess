class_name ChessPiece
extends Node3D

enum PieceType { PAWN, ROOK, KNIGHT, BISHOP, QUEEN, KING }
enum Faction { GOLD, OBSIDIAN }
enum HighlightState { NONE, HOVERED, SELECTED, CHECK }

@export var type: PieceType = PieceType.PAWN
@export var faction: Faction = Faction.GOLD
@export var override_faction_material: bool = true

var grid_pos: Vector2i = Vector2i.ZERO
var has_moved: bool = false
var is_hovered: bool = false
var visual_root: Node3D
var overlay_material: ShaderMaterial
var hover_tween: Tween

const FRESNEL_SHADER: Shader = preload("res://assets/shaders/fresnel_rim_highlight.gdshader")

const MODEL_PATHS := {
	PieceType.PAWN: "res://assets/models/pieces/piece_pawn.glb",
	PieceType.ROOK: "res://assets/models/pieces/piece_rook.glb",
	PieceType.KNIGHT: "res://assets/models/pieces/piece_knight.glb",
	PieceType.BISHOP: "res://assets/models/pieces/piece_bishop.glb",
	PieceType.QUEEN: "res://assets/models/pieces/piece_queen.glb",
	PieceType.KING: "res://assets/models/pieces/piece_king.glb"
}

func setup(p_type: PieceType, p_faction: Faction, start_grid: Vector2i, world_pos: Vector3) -> void:
	type = p_type
	faction = p_faction
	grid_pos = start_grid
	position = world_pos
	_init_overlay_material()
	_build_visual()

func _init_overlay_material() -> void:
	overlay_material = ShaderMaterial.new()
	overlay_material.shader = FRESNEL_SHADER

func set_hovered(hovered: bool) -> void:
	if is_hovered == hovered or visual_root == null:
		return
	is_hovered = hovered
	
	if hover_tween != null and hover_tween.is_valid():
		hover_tween.kill()
	
	hover_tween = create_tween()
	var target_y: float = 0.12 if is_hovered else 0.0
	hover_tween.tween_property(visual_root, "position:y", target_y, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func set_highlight_state(state: HighlightState) -> void:
	if visual_root == null or overlay_material == null:
		return
	
	match state:
		HighlightState.NONE:
			_apply_overlay_recursive(visual_root, null)
		HighlightState.HOVERED:
			overlay_material.set_shader_parameter("rim_color", Color(1.0, 0.88, 0.45, 0.72))
			overlay_material.set_shader_parameter("fresnel_power", 3.2)
			overlay_material.set_shader_parameter("intensity", 1.15)
			overlay_material.set_shader_parameter("pulse_speed", 2.5)
			_apply_overlay_recursive(visual_root, overlay_material)
		HighlightState.SELECTED:
			overlay_material.set_shader_parameter("rim_color", Color(1.0, 0.84, 0.28, 1.0))
			overlay_material.set_shader_parameter("fresnel_power", 2.4)
			overlay_material.set_shader_parameter("intensity", 1.8)
			overlay_material.set_shader_parameter("pulse_speed", 4.0)
			_apply_overlay_recursive(visual_root, overlay_material)
		HighlightState.CHECK:
			overlay_material.set_shader_parameter("rim_color", Color(1.0, 0.18, 0.12, 1.0))
			overlay_material.set_shader_parameter("fresnel_power", 2.0)
			overlay_material.set_shader_parameter("intensity", 2.6)
			overlay_material.set_shader_parameter("pulse_speed", 7.5)
			_apply_overlay_recursive(visual_root, overlay_material)

func _apply_overlay_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_overlay = mat
	for child in node.get_children():
		_apply_overlay_recursive(child, mat)

func promote_to(new_type: PieceType) -> void:
	type = new_type
	_build_visual()

func move_to(new_grid_pos: Vector2i, target_world_pos: Vector3) -> void:
	grid_pos = new_grid_pos
	has_moved = true
	set_hovered(false)
	
	var duration: float = 0.28
	var tween := create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(self, "position:x", target_world_pos.x, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:z", target_world_pos.z, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if type == PieceType.KNIGHT:
		var arc_tween := create_tween()
		arc_tween.tween_property(self, "position:y", target_world_pos.y + 0.65, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		arc_tween.tween_property(self, "position:y", target_world_pos.y, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(self, "position:y", target_world_pos.y, duration)

func _build_visual() -> void:
	if visual_root != null:
		visual_root.queue_free()
	
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	
	if faction == Faction.OBSIDIAN:
		visual_root.rotation.y = PI
	
	var mat := _create_faction_material()
	var model_path: String = MODEL_PATHS.get(type, "")
	
	if model_path != "" and ResourceLoader.exists(model_path):
		var packed_scene: PackedScene = load(model_path)
		if packed_scene != null:
			var model_instance := packed_scene.instantiate()
			visual_root.add_child(model_instance)
			if override_faction_material:
				_apply_material_recursive(model_instance, mat)
			return
	
	_build_placeholder_mesh(visual_root, mat)

func _create_faction_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if faction == Faction.GOLD:
		mat.albedo_color = Color(0.88, 0.70, 0.25)
		mat.metallic = 0.75
		mat.roughness = 0.28
	else:
		mat.albedo_color = Color(0.14, 0.16, 0.22)
		mat.metallic = 0.45
		mat.roughness = 0.35
	return mat

func _apply_material_recursive(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)

func _build_placeholder_mesh(parent: Node3D, mat: StandardMaterial3D) -> void:
	var base := MeshInstance3D.new()
	var base_cyl := CylinderMesh.new()
	base_cyl.top_radius = 0.28
	base_cyl.bottom_radius = 0.34
	base_cyl.height = 0.14
	base.mesh = base_cyl
	base.material_override = mat
	base.position.y = 0.07
	parent.add_child(base)
	
	var body := MeshInstance3D.new()
	var head := MeshInstance3D.new()
	
	match type:
		PieceType.PAWN:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.14
			cyl.bottom_radius = 0.22
			cyl.height = 0.45
			body.mesh = cyl
			body.position.y = 0.36
			
			var sph := SphereMesh.new()
			sph.radius = 0.16
			head.mesh = sph
			head.position.y = 0.65
			
		PieceType.ROOK:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.22
			cyl.bottom_radius = 0.25
			cyl.height = 0.65
			body.mesh = cyl
			body.position.y = 0.46
			
			var crown := CylinderMesh.new()
			crown.top_radius = 0.26
			crown.bottom_radius = 0.26
			crown.height = 0.16
			head.mesh = crown
			head.position.y = 0.85
			
		PieceType.KNIGHT:
			var box := BoxMesh.new()
			box.size = Vector3(0.28, 0.62, 0.36)
			body.mesh = box
			body.position.y = 0.44
			
			var snout := BoxMesh.new()
			snout.size = Vector3(0.22, 0.22, 0.42)
			head.mesh = snout
			head.position = Vector3(0, 0.78, -0.08)
			
		PieceType.BISHOP:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.12
			cyl.bottom_radius = 0.24
			cyl.height = 0.75
			body.mesh = cyl
			body.position.y = 0.51
			
			var mitre := SphereMesh.new()
			mitre.radius = 0.16
			mitre.height = 0.38
			head.mesh = mitre
			head.position.y = 0.96
			
		PieceType.QUEEN:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.15
			cyl.bottom_radius = 0.26
			cyl.height = 0.90
			body.mesh = cyl
			body.position.y = 0.59
			
			var orb := SphereMesh.new()
			orb.radius = 0.18
			head.mesh = orb
			head.position.y = 1.12
			
		PieceType.KING:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.18
			cyl.bottom_radius = 0.28
			cyl.height = 1.05
			body.mesh = cyl
			body.position.y = 0.66
			
			var cross := BoxMesh.new()
			cross.size = Vector3(0.22, 0.24, 0.22)
			head.mesh = cross
			head.position.y = 1.28
	
	body.material_override = mat
	head.material_override = mat
	parent.add_child(body)
	parent.add_child(head)
