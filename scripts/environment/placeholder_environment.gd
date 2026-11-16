extends Node3D

@export var board_size: float = 8.0
@export var board_thickness: float = 0.2

const FLAME := preload("res://assets/shaders/torch_flame.gdshader")
const ENV_PATHS := {
	"floor": "res://assets/models/environment/courtyard_floor.glb",
	"frame": "res://assets/models/environment/board_frame.glb",
	"torch": "res://assets/models/environment/torch_pillar.glb",
	"candi": "res://assets/models/environment/candi_bentar.glb"
}

var _batch: Dictionary = {}
var _lights: Array[OmniLight3D] = []
var _time := 0.0


func _ready() -> void:
	_build_courtyard()
	_build_frame()
	_build_gate(-1)
	_build_gate(1)
	_build_torches()
	_build_coordinates()
	_flush_boxes()


func _process(delta: float) -> void:
	_time += delta
	for i in range(_lights.size()):
		var wave := sin(_time * 10.4 + i * 1.9) * 0.13 + cos(_time * 16.5 + i * 2.3) * 0.075
		_lights[i].light_energy = 1.4 + wave


func _build_courtyard() -> void:
	if _import_model("floor", self, Vector3(0, -board_thickness, 0)):
		return
	var floor_y := -board_thickness - 0.13
	_box(Vector3(0, floor_y - 0.13, 0), Vector3(60, 0.14, 60), _material("#212d30", 0.96))
	var stones := [
		_material("#344144", 0.91), _material("#39464a", 0.87), _material("#404b4b", 0.88),
		_material("#2d393c", 0.91), _material("#374044", 0.93), _material("#424b50", 0.88)
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 21721
	for z in range(-11, 12):
		for x in range(-11, 12):
			var pos := Vector3((x + 0.5 * (z & 1)) * 1.57, floor_y, z * 1.025)
			var paver: StandardMaterial3D = stones[rng.randi_range(0, stones.size() - 1)]
			_box(pos, Vector3(1.542, 0.12, 0.997), paver, rng.randf_range(-0.009, 0.009))
	var border := _material("#273438", 0.86)
	var cap := _material("#475754", 0.83)
	for side in [-1, 1]:
		_box(Vector3(side * 8.8, -0.118, 0), Vector3(0.77, 0.32, 21.2), border)
		_box(Vector3(side * 8.8, 0.063, 0), Vector3(0.89, 0.095, 21.35), cap)
		for z in [-10.25, -5.2, 0, 5.2, 10.25]:
			_taper(Vector3(side * 8.8, 0.22, z), 0.33, 0.47, 0.32, cap, 8)
			_taper(Vector3(side * 8.8, 0.47, z), 0.15, 0.32, 0.21, border, 8)
			_taper(Vector3(side * 8.8, 0.605, z), 0.045, 0.16, 0.16, cap, 8)


func _build_frame() -> void:
	if _import_model("frame", self, Vector3(0, -board_thickness, 0)):
		return
	var wood := _material("#4c2a23", 0.57)
	var molding := _material("#6d3d2a", 0.49)
	var shadow := _material("#352324", 0.72)
	var brass := _material("#bd8e50", 0.37, 0.48)
	var line := _material("#806042", 0.48, 0.31)
	var half := board_size * 0.5
	var span := board_size + 1.06
	_box(Vector3(0, -0.253, 0), Vector3(span + 0.16, 0.14, span + 0.16), shadow)
	for edge in range(4):
		var angle := edge * PI * 0.5
		_frame_bar(half + 0.26, -0.106, Vector3(span, 0.22, 0.52), angle, wood)
		_frame_bar(half + 0.485, -0.005, Vector3(span + 0.025, 0.1, 0.095), angle, molding)
		_frame_bar(half + 0.397, 0.015, Vector3(span - 0.095, 0.018, 0.018), angle, brass)
		_frame_bar(half + 0.07, 0.01, Vector3(board_size + 0.161, 0.029, 0.024), angle, line)
		for i in range(28):
			var x := (i - 13.5) * 0.298
			var center := Vector3(x, -0.069, half + 0.525).rotated(Vector3.UP, angle)
			_box(center, Vector3(0.052, 0.052, 0.018), line, angle, PI * 0.25)
		var corner := Vector3(half + 0.27, 0.042, half + 0.27).rotated(Vector3.UP, angle)
		_taper(corner, 0.151, 0.173, 0.031, brass, 8)
		_taper(corner + Vector3.UP * 0.022, 0.072, 0.104, 0.019, shadow, 8)
		_taper(corner + Vector3.UP * 0.033, 0.037, 0.051, 0.017, brass, 8)


func _frame_bar(distance: float, y: float, size: Vector3, angle: float, material: Material) -> void:
	_box(Vector3(0, y, distance).rotated(Vector3.UP, angle), size, material, angle)


func _build_gate(direction: int) -> void:
	var z := direction * 7.4
	if _import_model("candi", self, Vector3(0, -board_thickness, z), 0.0 if direction < 0 else PI):
		return
	var base := _material("#514344", 0.87)
	var ledge := _material("#765b4f", 0.79)
	var carving := _material("#996d4c", 0.73)
	var bricks := [
		_material("#704c45", 0.86), _material("#77514a", 0.84),
		_material("#684742", 0.87), _material("#81564c", 0.84)
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1532
	for side in [-1, 1]:
		var x: float = side * 2.02
		_box(Vector3(x, -0.07, z), Vector3(2.20, 0.4, 1.83), base)
		_box(Vector3(x, 0.16, z), Vector3(2.10, 0.095, 1.74), ledge)
		for course in range(14):
			var y := 0.285 + course * 0.147
			var width := 1.78 - course * 0.021
			for column in range(5):
				var xi: float = x + (column - 2) * width / 5.0
				var depth := 1.24 + rng.randf_range(0.0, 0.075)
				_box(Vector3(xi, y, z), Vector3(width / 5.0 - 0.008, 0.141, depth), bricks[rng.randi_range(0, 3)])
			if course in [2, 5, 9, 12]:
				_box(Vector3(x, y, z), Vector3(width + 0.042, 0.034, 1.39), ledge)
		for tier in range(10):
			var width := 1.84 - tier * 0.145
			var y := 2.36 + tier * 0.151
			var xi: float = x - side * tier * 0.047
			_box(Vector3(xi, y, z), Vector3(width, 0.15, 1.35 - tier * 0.092), bricks[tier % 4])
			_box(Vector3(xi, y + 0.075, z), Vector3(width + 0.08, 0.041, 1.42 - tier * 0.093), ledge)
		for face in [-1, 1]:
			for strip in [-1, 1]:
				var xi: float = x + strip * 0.53
				_box(Vector3(xi, 0.92, z + face * 0.693), Vector3(0.115, 1.45, 0.11), base)
				for row in range(6):
					_box(Vector3(xi, 0.425 + row * 0.197, z + face * 0.759), Vector3(0.068, 0.068, 0.038), carving, 0.0, PI / 4.0)
			_box(Vector3(x, 1.195, z + face * 0.667), Vector3(0.49, 0.77, 0.084), base)
			_box(Vector3(x, 1.204, z + face * 0.72), Vector3(0.24, 0.24, 0.075), carving, 0.0, PI / 4.0)
			_box(Vector3(x, 1.204, z + face * 0.766), Vector3(0.108, 0.108, 0.035), ledge, 0.0, PI / 4.0)


func _build_torches() -> void:
	var basalt := _material("#394442", 0.9)
	var sculpt := _material("#505852", 0.82)
	var bronze := _material("#9b6939", 0.49, 0.52)
	var bowl := _material("#4e3a2f", 0.67, 0.32)
	var ember := _material("#f4ac43", 0.57)
	ember.emission_enabled = true
	ember.emission = Color("#ffc677")
	ember.emission_energy_multiplier = 2.5
	var spark_mesh := SphereMesh.new()
	spark_mesh.radial_segments = 6
	spark_mesh.rings = 3
	spark_mesh.material = ember

	var physics := ParticleProcessMaterial.new()
	physics.direction = Vector3.UP
	physics.spread = 25.0
	physics.initial_velocity_min = 0.46
	physics.initial_velocity_max = 1.07
	physics.gravity = Vector3(0.11, 0.19, -0.14)
	physics.scale_min = 0.012
	physics.scale_max = 0.033
	var life := Curve.new()
	life.add_point(Vector2(0.0, 1.0))
	life.add_point(Vector2(0.71, 0.65))
	life.add_point(Vector2(1.0, 0.0))
	var curve := CurveTexture.new()
	curve.curve = life
	physics.scale_curve = curve

	for x in [-5.19, 5.19]:
		for z in [-4.77, 4.77]:
			var torch := Node3D.new()
			torch.position = Vector3(x, -0.27, z)
			add_child(torch)
			var model := _import_model("torch", torch, Vector3.ZERO)
			var height := 2.2 if model else 1.64
			if not model:
				var center := torch.position
				_taper(center + Vector3.UP * 0.085, 0.30, 0.38, 0.19, basalt, 8)
				_taper(center + Vector3.UP * 0.20, 0.26, 0.31, 0.14, sculpt, 8)
				_taper(center + Vector3.UP * 0.81, 0.124, 0.20, 1.16, basalt, 8)
				for rim_y in [0.31, 0.52, 1.27, 1.39]:
					var radius := lerpf(0.209, 0.15, (rim_y - 0.3) / 1.15)
					_taper(center + Vector3.UP * rim_y, radius, radius + 0.02, 0.075, sculpt, 8)
				_taper(center + Vector3.UP * 1.5, 0.265, 0.138, 0.17, bowl, 14)
				_taper(center + Vector3.UP * 1.596, 0.278, 0.256, 0.051, bronze, 16)
				_taper(center + Vector3.UP * 1.637, 0.20, 0.225, 0.028, bowl, 16)
			for i in range(3):
				var flame := MeshInstance3D.new()
				var shape := SphereMesh.new()
				shape.radial_segments = 14
				shape.rings = 8
				flame.mesh = shape
				var material := ShaderMaterial.new()
				material.shader = FLAME
				material.set_shader_parameter("phase", i * 1.9 + x + z * 0.41)
				flame.material_override = material
				flame.scale = Vector3(0.19 - i * 0.018, 0.51 - i * 0.087, 0.24 - i * 0.017)
				flame.position = Vector3((i - 1) * 0.063, height + 0.17 - i * 0.028, i * 0.026)
				flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				torch.add_child(flame)
			var sparks := GPUParticles3D.new()
			sparks.amount = 22
			sparks.lifetime = 1.77
			sparks.preprocess = 1.3
			sparks.process_material = physics
			sparks.draw_pass_1 = spark_mesh
			sparks.position.y = height + 0.2
			torch.add_child(sparks)
			var light := OmniLight3D.new()
			light.light_color = Color("#ffc980")
			light.light_energy = 1.4
			light.omni_range = 4.85
			light.omni_attenuation = 1.38
			light.position.y = height + 0.22
			torch.add_child(light)
			_lights.append(light)


func _build_coordinates() -> void:
	var files := "ABCDEFGH"
	var rim := board_size * 0.5 + 0.232
	for i in range(8):
		var along := i - 3.5
		_coordinate(files[i], Vector3(along, 0.042, rim), 0.0)
		_coordinate(files[i], Vector3(along, 0.042, -rim), PI)
		_coordinate(str(8 - i), Vector3(-rim, 0.042, along), 0.0)
		_coordinate(str(8 - i), Vector3(rim, 0.042, along), PI)


func _coordinate(text: String, pos: Vector3, yaw: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.0045
	label.outline_size = 5
	label.modulate = Color("#f5db9d")
	label.outline_modulate = Color("#382628")
	label.position = pos
	label.rotation = Vector3(-PI * 0.5, yaw, 0)
	add_child(label)


func _import_model(key: String, parent: Node3D, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var path: String = ENV_PATHS[key]
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var instance := scene.instantiate() as Node3D
	instance.position = pos
	instance.rotation.y = yaw
	parent.add_child(instance)
	return instance


func _material(hex: String, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.roughness = roughness
	material.metallic = metallic
	return material


func _box(pos: Vector3, size: Vector3, material: Material, yaw: float = 0.0, roll: float = 0.0) -> void:
	if not _batch.has(material):
		_batch[material] = []
	var rotation_basis := Basis.from_euler(Vector3(0, yaw, roll))
	_batch[material].append(Transform3D(rotation_basis * Basis.from_scale(size), pos))


func _flush_boxes() -> void:
	for material: Material in _batch:
		var box := BoxMesh.new()
		box.material = material
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.mesh = box
		var transforms: Array = _batch[material]
		mesh.instance_count = transforms.size()
		for i in range(transforms.size()):
			mesh.set_instance_transform(i, transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = mesh
		add_child(instance)
	_batch.clear()


func _taper(pos: Vector3, top: float, bottom: float, height: float, material: Material, sides: int) -> void:
	var primitive := CylinderMesh.new()
	primitive.top_radius = top
	primitive.bottom_radius = bottom
	primitive.height = height
	primitive.radial_segments = sides
	primitive.rings = 0
	primitive.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = primitive
	mesh.position = pos
	add_child(mesh)
