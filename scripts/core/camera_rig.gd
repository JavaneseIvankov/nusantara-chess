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
var target_pitch: float = deg_to_rad(-52.0)
var target_zoom: float = 10.15
var showcase_time := 0.0

var is_orbiting: bool = false
var is_showcase_mode: bool = true
var is_obsidian_side: bool = false
var is_top_view: bool = false
var compact_layout := false

func _ready() -> void:
	rotation.y = target_yaw
	pitch_pivot.rotation.x = target_pitch
	camera.position.z = target_zoom

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		is_orbiting = false


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
		showcase_time += delta
		target_yaw = -0.32 + sin(showcase_time * 0.28) * 0.34
		target_pitch = deg_to_rad(-47.0)
		target_zoom = 10.9
	
	var blend := 1.0 - exp(-delta * 6.0)
	rotation.y = lerp_angle(rotation.y, target_yaw, blend)
	pitch_pivot.rotation.x = lerpf(pitch_pivot.rotation.x, target_pitch, blend)
	var view_size := get_viewport().get_visible_rect().size
	var aspect := view_size.x / maxf(view_size.y, 1.0)
	var fit := maxf(1.0, 1.55 / aspect)
	camera.position.z = lerpf(camera.position.z, target_zoom * fit, blend)
	var sidebar_offset := 0.10 if compact_layout else 1.31
	var menu_offset := -2.47 if aspect >= 1.53 else -1.85
	camera.h_offset = lerpf(camera.h_offset, menu_offset if is_showcase_mode else sidebar_offset, blend)
	camera.v_offset = lerpf(camera.v_offset, 0.12 if is_showcase_mode else -0.20, blend)

func set_compact_layout(compact: bool) -> void:
	compact_layout = compact


func start_showcase() -> void:
	is_showcase_mode = true
	is_orbiting = false


func start_gameplay_camera() -> void:
	is_showcase_mode = false
	reset_camera()

func reset_camera() -> void:
	is_obsidian_side = false
	is_top_view = false
	target_yaw = 0.0
	target_pitch = deg_to_rad(-52.0)
	target_zoom = 10.15

func set_faction_side(faction: ChessPiece.Faction) -> void:
	is_obsidian_side = (faction == ChessPiece.Faction.OBSIDIAN)
	target_yaw = PI if is_obsidian_side else 0.0

func toggle_top_view() -> void:
	is_top_view = not is_top_view
	if is_top_view:
		target_pitch = deg_to_rad(-82.0)
		target_zoom = 10.0
	else:
		target_pitch = deg_to_rad(-52.0)
		target_zoom = 10.15
