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
var move_tween: Tween
var motion: RefCounted
var facing: Node3D
var hit_area: Area3D

const MINIATURES := preload("res://scripts/pieces/nusantara_miniatures.gd")
const MOTION := preload("res://scripts/pieces/piece_motion.gd")
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
	_setup_hit_area()

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
	_setup_hit_area()

func move_to(new_grid_pos: Vector2i, target_world_pos: Vector3) -> Tween:
	grid_pos = new_grid_pos
	has_moved = true
	set_hovered(false)
	if move_tween and move_tween.is_valid():
		move_tween.kill()

	var origin := position
	var travel := target_world_pos - origin
	var distance := travel.length()
	var home_yaw := _rest_yaw()
	var travel_yaw := atan2(-travel.x, -travel.z)
	var duration := clampf(0.32 + distance * 0.069, 0.38, 0.81)
	if type == PieceType.KNIGHT:
		duration = 0.65
	var moving_role := type
	AudioManager.play_move(moving_role)
	move_tween = create_tween()
	move_tween.tween_method(func(t: float) -> void:
		var progress := smoothstep(0.0, 1.0, t)
		position = origin.lerp(target_world_pos, progress)
		var turn_weight := smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(0.74, 1.0, t))
		facing.rotation.y = lerp_angle(home_yaw, travel_yaw, turn_weight)
		if moving_role == PieceType.KNIGHT:
			position.y += sin(t * PI) * 0.57
		motion.stride(moving_role, t, distance)
	, 0.0, 1.0, duration)
	move_tween.tween_callback(func():
		motion.reset()
		AudioManager.play_landing(moving_role)
	)
	return move_tween


func _setup_hit_area() -> void:
	if hit_area == null:
		hit_area = Area3D.new()
		hit_area.collision_layer = 2
		hit_area.collision_mask = 0
		hit_area.monitoring = false
		hit_area.monitorable = false
		hit_area.set_meta("piece", self)
		hit_area.add_child(CollisionShape3D.new())
		add_child(hit_area)
	var collider := hit_area.get_child(0) as CollisionShape3D
	var shape := CapsuleShape3D.new()
	shape.height = [0.87, 1.12, 1.18, 1.23, 1.39, 1.53][type]
	shape.radius = 0.19 if type == PieceType.PAWN else 0.24
	collider.shape = shape
	collider.position.y = shape.height * 0.5 + 0.035


func _rest_yaw() -> float:
	return -0.48 if faction == Faction.GOLD else PI - 0.48


func _build_visual() -> void:
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
	if visual_root:
		remove_child(visual_root)
		visual_root.queue_free()
	is_hovered = false
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	facing = Node3D.new()
	facing.rotation.y = _rest_yaw()
	visual_root.add_child(facing)

	var model_path: String = MODEL_PATHS[type]
	var model: Node3D
	if ResourceLoader.exists(model_path):
		var packed_scene := load(model_path) as PackedScene
		if packed_scene:
			model = packed_scene.instantiate()
			if override_faction_material:
				_apply_material_recursive(model, _create_faction_material())
	if model == null:
		model = MINIATURES.instantiate(type, faction)
	facing.add_child(model)
	motion = MOTION.new(model)


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
