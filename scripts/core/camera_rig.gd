extends Node3D

@export var rotation_speed: float = 0.005
@export var zoom_speed: float = 1.0
@export var min_zoom: float = 5.5
@export var max_zoom: float = 16.0
@export var min_pitch_deg: float = -80.0 # Batas lihat dari atas (top-down)
@export var max_pitch_deg: float = -18.0 # Batas lihat rendah agar tidak tembus bawah papan
@export var smoothness: float = 12.0

@onready var pitch_pivot: Node3D = $PitchPivot
@onready var camera: Camera3D = $PitchPivot/Camera3D

var target_yaw: float = 0.0
var target_pitch: float = deg_to_rad(-45.0)
var target_zoom: float = 10.5
var is_rotating: bool = false

func _ready() -> void:
	target_yaw = rotation.y
	target_pitch = pitch_pivot.rotation.x
	target_zoom = camera.position.z

func _unhandled_input(event: InputEvent) -> void:
	# Mulai/berhenti memutar kamera saat klik kanan atau klik tengah ditahan
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			is_rotating = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_zoom = clamp(target_zoom - zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_zoom = clamp(target_zoom + zoom_speed, min_zoom, max_zoom)
	
	# Hitung perubahan sudut saat mouse digeser sambil menahan tombol putar
	elif event is InputEventMouseMotion and is_rotating:
		target_yaw -= event.relative.x * rotation_speed
		target_pitch -= event.relative.y * rotation_speed
		target_pitch = clamp(target_pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))

func _process(delta: float) -> void:
	# Interpolasi halus (lerp) untuk gerakan kamera
	var weight: float = clamp(smoothness * delta, 0.0, 1.0)
	rotation.y = lerp_angle(rotation.y, target_yaw, weight)
	pitch_pivot.rotation.x = lerp(pitch_pivot.rotation.x, target_pitch, weight)
	camera.position.z = lerp(camera.position.z, target_zoom, weight)
