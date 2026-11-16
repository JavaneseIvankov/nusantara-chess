extends PanelContainer

const MINIATURES := preload("res://scripts/pieces/nusantara_miniatures.gd")
const MOTION := preload("res://scripts/pieces/piece_motion.gd")
const LENGTH := 2.43
const IMPACT := 0.83

var _view: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _actors: Node3D
var _attacker: Node3D
var _defender: Node3D
var _attack_pose: RefCounted
var _defense_pose: RefCounted
var _sparks: Node3D
var _ring: MeshInstance3D
var _impact_light: OmniLight3D
var _trail: MeshInstance3D
var _trail_material: StandardMaterial3D
var _pending: Array[Vector3i] = []
var _framing_height := 1.0
var _caption: Label
var _role := 0
var _elapsed := 0.0
var _landed := false


func _ready() -> void:
	hide()
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 6)
	add_child(layout)
	var heading := Label.new()
	heading.text = "CUPLIKAN PENANGKAPAN"
	heading.add_theme_font_size_override("font_size", 11)
	heading.add_theme_color_override("font_color", Color("#e8c481"))
	layout.add_child(heading)

	var film := TextureRect.new()
	film.custom_minimum_size = Vector2(191, 128)
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	film.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layout.add_child(film)
	_view = SubViewport.new()
	_view.size = Vector2i(450, 304)
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)
	film.texture = _view.get_texture()

	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 11)
	_caption.add_theme_color_override("font_color", Color("#f1dfc3"))
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	layout.add_child(_caption)
	_build_stage()


func play(attacker: int, defender: int, faction: int) -> void:
	if is_processing():
		_pending.append(Vector3i(attacker, defender, faction))
	else:
		_start_clip(attacker, defender, faction)


func _start_clip(attacker: int, defender: int, faction: int) -> void:
	if _actors:
		_stage.remove_child(_actors)
		_actors.queue_free()
	_actors = Node3D.new()
	_stage.add_child(_actors)
	_attacker = MINIATURES.instantiate(attacker, faction)
	_defender = MINIATURES.instantiate(defender, 1 - faction)
	_actors.add_child(_attacker)
	_actors.add_child(_defender)
	_attack_pose = MOTION.new(_attacker)
	_defense_pose = MOTION.new(_defender)
	_caption.text = "%s menawan %s" % [MINIATURES.SHORT_TITLES[attacker], MINIATURES.SHORT_TITLES[defender]]
	_role = attacker
	var heights := [0.89, 1.19, 1.23, 1.30, 1.43, 1.61]
	_framing_height = maxf(heights[attacker], heights[defender])
	_elapsed = 0.0
	_landed = false
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	show()
	_animate(0.0)
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	if not _landed and _elapsed >= IMPACT:
		_landed = true
		AudioManager.play_capture(_role)
	if _elapsed >= LENGTH:
		if not _pending.is_empty():
			var next: Vector3i = _pending.pop_front()
			_start_clip(next.x, next.y, next.z)
			return
		hide()
		set_process(false)
		_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_animate(_elapsed)


func _animate(t: float) -> void:
	var windup := smoothstep(0.19, 0.64, t) * (1.0 - smoothstep(0.64, IMPACT + 0.02, t))
	var strike := smoothstep(0.63, IMPACT, t) * (1.0 - smoothstep(IMPACT + 0.12, 1.34, t))
	var step := smoothstep(0.63, IMPACT + 0.06, t)
	var impact_age := maxf(t - IMPACT, 0.0)
	var fall := smoothstep(IMPACT, IMPACT + 0.51, t)
	var dissolve := smoothstep(IMPACT + 0.18, IMPACT + 0.61, t)
	_attacker.position = Vector3(lerpf(-0.76, -0.25, step) - windup * 0.09, 0.015 + strike * 0.15 if _role == 2 else 0.015, 0.0)
	_attacker.rotation.y = -1.78 + windup * 0.23 - strike * 0.18
	_attack_pose.attack(_role, windup, strike)
	_defender.position = Vector3(0.68 + fall * 0.33, 0.015 + sin(fall * PI) * 0.12, -0.05)
	_defender.rotation = Vector3(0, 1.91 + fall * 0.36, -fall * 0.86)
	_defender.scale = Vector3.ONE * lerpf(1.0, 0.05, dissolve)
	_defender.visible = dissolve < 1.0
	_defense_pose.recoil(fall)
	_sparks.visible = t >= IMPACT and impact_age < 0.52
	_ring.visible = _sparks.visible
	_impact_light.light_energy = 5.0 * exp(-impact_age * 17.0) if t >= IMPACT else 0.0
	if _sparks.visible:
		for i in range(_sparks.get_child_count()):
			var spark := _sparks.get_child(i) as MeshInstance3D
			var theta := TAU * i / _sparks.get_child_count()
			var velocity := Vector3(cos(theta) * 1.28, sin(theta) * 0.78 + 0.34, cos(theta * 4.0) * 0.73)
			spark.position = Vector3(0.24, 0.67, 0.04) + velocity * impact_age * (1.2 + (i % 3) * 0.7)
			spark.rotation.z = theta + t * 4.0
			spark.scale = Vector3.ONE * (1.0 - smoothstep(0.13, 0.53, impact_age))
		_ring.scale = Vector3.ONE * (0.18 + impact_age * 3.3)
		_ring.scale.y *= 1.0 - smoothstep(0.0, 0.51, impact_age) * 0.8
	var trail_age := smoothstep(0.68, IMPACT + 0.18, t)
	_trail.visible = t >= 0.69 and t <= IMPACT + 0.24
	_trail.position = Vector3(0.12, _framing_height * 0.62, 0.24)
	_trail.rotation = Vector3(0.16, -0.18, lerpf(-1.1, 0.94, trail_age) if _role != 2 else -0.32)
	_trail.scale = Vector3(1.25 if _role == 2 else 0.96, 0.32 if _role == 2 else 0.9, 1.0)
	_trail_material.albedo_color.a = sin(trail_age * PI) * 0.64
	var shake := sin(impact_age * 94.0) * exp(-impact_age * 15.0) * 0.046 if t >= IMPACT else 0.0
	var closeup := smoothstep(0.25, 1.29, t)
	var distance := 2.91 + (_framing_height - 0.89) * 0.92 - closeup * 0.44
	_camera.position = Vector3(lerpf(-0.13, 0.22, t / LENGTH) + shake, _framing_height * 0.55 + 0.47 - t * 0.082, distance)
	_camera.look_at(Vector3(lerpf(-0.035, 0.21, step), _framing_height * 0.51, 0))
	modulate.a = smoothstep(0.0, 0.13, t) * (1.0 - smoothstep(LENGTH - 0.34, LENGTH, t))


func _build_stage() -> void:
	_stage = Node3D.new()
	_view.add_child(_stage)
	var world := WorldEnvironment.new()
	_stage.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#19232b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b7c8dc")
	environment.ambient_light_energy = 0.64
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.environment = environment

	_camera = Camera3D.new()
	_camera.fov = 32.0
	_stage.add_child(_camera)
	_camera.make_current()
	_light(Vector3(-2.5, 2.4, 2.5), Color("#ffdda4"), 2.55)
	_light(Vector3(2, 2, -1.6), Color("#9edbe9"), 3.05)
	_light(Vector3(2.2, 1.6, 2.7), Color("#c8ddff"), 1.0)

	var stone := _material(Color("#35303b"), 0.8)
	var rim := _material(Color("#aa6e34"), 0.42)
	_disc(Vector3(0, -0.105, 0), 1.68, 0.21, stone)
	_disc(Vector3(0, -0.082, 0), 1.7, 0.033, rim)
	_block(Vector3(0, -0.229, 0), Vector3(11.0, 0.05, 11.0), _material(Color("#1e242b"), 0.96))
	var brick := _material(Color("#523837"), 0.83)
	for side in [-1, 1]:
		_block(Vector3(side * 1.25, 0.32, -1.29), Vector3(0.78, 0.65, 0.4), brick)
		for tier in range(6):
			_block(Vector3(side * (1.27 + tier * 0.035), 0.68 + tier * 0.14, -1.29),
				Vector3(0.75 - tier * 0.082, 0.15, 0.35 - tier * 0.025), brick)

	_sparks = Node3D.new()
	_stage.add_child(_sparks)
	var spark_material := _material(Color("#ffde8f"), 0.4)
	spark_material.emission_enabled = true
	spark_material.emission = Color("#ffc26a")
	spark_material.emission_energy_multiplier = 2.4
	var spark_mesh := PrismMesh.new()
	spark_mesh.size = Vector3(0.059, 0.019, 0.02)
	spark_mesh.material = spark_material
	for i in range(26):
		var spark := MeshInstance3D.new()
		spark.mesh = spark_mesh
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sparks.add_child(spark)
	_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.37
	ring.outer_radius = 0.381
	ring.rings = 24
	ring.ring_segments = 8
	ring.material = spark_material
	_ring.mesh = ring
	_ring.position = Vector3(0.24, 0.036, 0.0)
	_stage.add_child(_ring)
	_impact_light = _light(Vector3(0.23, 0.88, 0.59), Color("#ffac4e"), 0.0)
	_build_trail()


func _build_trail() -> void:
	_trail_material = StandardMaterial3D.new()
	_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail_material.albedo_color = Color("#ffce76")
	_trail_material.vertex_color_use_as_albedo = true
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(25):
		var t := float(i) / 24.0
		var a := -1.22 + t * 2.52
		var radial := Vector3(sin(a), cos(a), 0)
		var taper := sin(t * PI)
		surface.set_color(Color(1.0, 0.89, 0.74, taper))
		surface.add_vertex(radial * 0.68 - Vector3.UP * 0.64)
		surface.set_color(Color(1.0, 0.68, 0.39, 0.0))
		surface.add_vertex(radial * (0.68 - 0.15 * taper) - Vector3.UP * 0.64)
	_trail = MeshInstance3D.new()
	_trail.mesh = surface.commit()
	_trail.material_override = _trail_material
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_stage.add_child(_trail)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _block(pos: Vector3, size: Vector3, mat: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	_mesh(pos, box)


func _disc(pos: Vector3, radius: float, height: float, mat: Material) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.height = height
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.radial_segments = 56
	cylinder.material = mat
	_mesh(pos, cylinder)


func _mesh(pos: Vector3, mesh: Mesh) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	_stage.add_child(instance)


func _light(pos: Vector3, color: Color, energy: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 8.0
	_stage.add_child(light)
	return light
