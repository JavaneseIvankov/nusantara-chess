extends Node3D

@onready var pitch_pivot: Node3D = $PitchPivot
@onready var camera: Camera3D = $PitchPivot/Camera3D

@export var orbit_sensitivity: float = 0.005
@export var zoom_speed: float = 0.8
@export var min_zoom: float = 5.5
@export var max_zoom: float = 16.0
@export var min_pitch_deg: float = -85.0
@export var max_pitch_deg: float = -15.0

var target_yaw: float = 0.0
var target_pitch: float = deg_to_rad(-45.0)
var target_zoom: float = 10.5

var is_orbiting: bool = false
var is_showcase_mode: bool = true
var is_obsidian_side: bool = false
var is_top_view: bool = false

func _ready() -> void:
	rotation.y = target_yaw
	pitch_pivot.rotation.x = target_pitch
	camera.position.z = target_zoom

func _unhandled_input(event: InputEvent) -> void:
	if is_showcase_mode:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_orbiting = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_zoom = clamp(target_zoom - zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_zoom = clamp(target_zoom + zoom_speed, min_zoom, max_zoom)
	
	elif event is InputEventMouseMotion and is_orbiting:
		target_yaw -= event.relative.x * orbit_sensitivity
		var new_pitch: float = target_pitch - (event.relative.y * orbit_sensitivity)
		target_pitch = clamp(new_pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))

func _process(delta: float) -> void:
	if is_showcase_mode:
		target_yaw += delta * 0.14
		target_pitch = deg_to_rad(-32.0)
		target_zoom = 11.8
	
	rotation.y = lerp_angle(rotation.y, target_yaw, delta * 6.0)
	pitch_pivot.rotation.x = lerp(pitch_pivot.rotation.x, target_pitch, delta * 6.0)
	camera.position.z = lerp(camera.position.z, target_zoom, delta * 6.0)

func start_gameplay_camera() -> void:
	is_showcase_mode = false
	reset_camera()

func reset_camera() -> void:
	is_obsidian_side = false
	is_top_view = false
	target_yaw = 0.0
	target_pitch = deg_to_rad(-45.0)
	target_zoom = 10.5

func set_faction_side(faction: ChessPiece.Faction) -> void:
	is_obsidian_side = (faction == ChessPiece.Faction.OBSIDIAN)
	target_yaw = PI if is_obsidian_side else 0.0

func toggle_top_view() -> void:
	is_top_view = not is_top_view
	if is_top_view:
		target_pitch = deg_to_rad(-82.0)
		target_zoom = 11.2
	else:
		target_pitch = deg_to_rad(-45.0)
		target_zoom = 10.5
