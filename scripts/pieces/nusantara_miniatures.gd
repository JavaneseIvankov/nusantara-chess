extends RefCounted
## Builds reusable, vertex-painted miniatures. Each moving joint is baked to one mesh.

const TITLES := ["Prajurit Keris", "Mahapatih Gada", "Kavaleri Tombak", "Resi Hindu", "Ratu Nusantara", "Maharaja"]
const SHORT_TITLES := ["Prajurit", "Mahapatih", "Kavaleri", "Resi", "Ratu", "Raja"]

static var _templates: Dictionary = {}
static var _ball: SphereMesh
static var _box: BoxMesh
static var _finish: Array[StandardMaterial3D] = []

var _geometry: Dictionary = {}
var _skin: Color
var _cloth: Color
var _shadow: Color
var _metal: Color
var _edge: Color
var _gem: Color
var _hair: Color
var _wood: Color


static func instantiate(role: int, faction: int) -> Node3D:
	var key := Vector2i(role, faction)
	if not _templates.has(key):
		var template := new()._build(role, faction)
		var scene := PackedScene.new()
		scene.pack(template)
		template.free()
		_templates[key] = scene
	return _templates[key].instantiate()


func _build(role: int, faction: int) -> Node3D:
	var gold := faction == 0
	_skin = Color("#bc8158") if gold else Color("#a27256")
	_cloth = Color("#9c3431") if gold else Color("#245c70")
	_shadow = Color("#512020") if gold else Color("#172d44")
	_metal = Color("#d39a43") if gold else Color("#879ea8")
	_edge = Color("#f5d581") if gold else Color("#c6e8ec")
	_gem = Color("#65b5a4") if gold else Color("#58bdd9")
	_hair = Color("#261d21")
	_wood = Color("#6d3a2e") if gold else Color("#343047")

	var root := Node3D.new()
	root.name = "Miniature"
	var radius: float = [0.35, 0.375, 0.375, 0.38, 0.39, 0.39][role]
	_pedestal(root, radius)
	var body := _joint(root, "Figure", Vector3(0, 0.112, 0))
	if role == 2:
		body.scale.y = 1.14
		_horse(body)
	else:
		var body_scale: Vector3 = [
			Vector3(0.83, 0.99, 0.83), Vector3(1.25, 1.28, 1.14), Vector3.ONE,
			Vector3(0.98, 1.40, 0.97), Vector3(1.06, 1.53, 1.07), Vector3(1.15, 1.65, 1.13)
		][role]
		body.scale = body_scale
		_person(body, role)
	_bake(root)
	return root


func _pedestal(parent: Node3D, r: float) -> void:
	var base := _joint(parent, "Umpak", Vector3.ZERO)
	_turn(base, [[0.001, r - 0.025], [0.023, r], [0.039, r], [0.051, r - 0.025]], Vector3.ZERO, 1.0, _shadow)
	_turn(base, [[0.045, r - 0.024], [0.058, r - 0.018], [0.068, r - 0.027]], Vector3.ZERO, 1.0, _metal, true)
	_turn(base, [[0.063, r - 0.032], [0.096, r - 0.029], [0.115, r - 0.064]], Vector3.ZERO, 1.0, _cloth.darkened(0.19))
	_turn(base, [[0.097, r - 0.028], [0.106, r - 0.04]], Vector3.ZERO, 1.0, _edge, true)
	for i in range(20):
		var angle := TAU * i / 20.0
		var point := Vector3(sin(angle) * (r - 0.027), 0.08, cos(angle) * (r - 0.027))
		_block(base, point, Vector3(0.022, 0.015, 0.008), _metal, Vector3(0, angle, PI / 4), true)


func _person(body: Node3D, role: int) -> void:
	var royal := role >= 4
	var priest := role == 3
	var stocky := role == 1
	var skirt_color := _cloth.lightened(0.22) if priest else _cloth
	var skirt_width := 0.23 if royal else 0.18
	var skin := _skin.lightened(0.12) if royal else _skin

	var leg_l := _joint(body, "LegL", Vector3(-0.079, 0.27, 0))
	var leg_r := _joint(body, "LegR", Vector3(0.079, 0.27, 0))
	for leg in [leg_l, leg_r]:
		_bone(leg, Vector3.ZERO, Vector3(0, -0.208, 0.024), 0.057, 0.041, skin)
		_ellipsoid(leg, Vector3(0, -0.229, -0.028), Vector3(0.096, 0.056, 0.166), _hair)
		_band(leg, Vector3(0, -0.161, 0.017), 0.052, 0.023)

	var robe := _joint(body, "Cloth", Vector3(0, 0.315, 0))
	_turn(robe, [[-0.205 if royal or priest else -0.135, skirt_width], [-0.085, skirt_width * 0.91],
		[0.04, 0.138]], Vector3.ZERO, 0.72, skirt_color)
	var hem_y := -0.189 if royal or priest else -0.119
	_turn(robe, [[hem_y - 0.012, skirt_width], [hem_y + 0.006, skirt_width * 0.986]], Vector3.ZERO, 0.73, _metal, true)
	_batik(robe, 0.0, hem_y + 0.051, skirt_width * 0.95, 0.74, 10)
	_batik(robe, 0.21, hem_y + 0.097, skirt_width * 0.89, 0.74, 10)
	if royal or priest:
		_plate(robe, Vector3(0, -0.014, -0.103), [
			Vector2(-0.069, 0.075), Vector2(-0.049, -0.193), Vector2(0, -0.225),
			Vector2(0.05, -0.193), Vector2(0.069, 0.075)
		], 0.025, _shadow)
		for i in range(5):
			_block(robe, Vector3(0, -0.018 - i * 0.04, -0.124), Vector3(0.029, 0.029, 0.006), _edge, Vector3(0, 0, PI / 4), true)

	var torso := _joint(body, "Torso", Vector3(0, 0.345, 0))
	var chest_color := skin if stocky else (_shadow if not priest else skirt_color)
	_turn(torso, [[-0.021, 0.133], [0.06, 0.174 if stocky else 0.127], [0.16, 0.159],
		[0.238, 0.137], [0.269, 0.068]], Vector3.ZERO, 0.65, chest_color)
	_turn(torso, [[-0.015, 0.142], [0.014, 0.141]], Vector3.ZERO, 0.71, _metal, true)
	_ellipsoid(torso, Vector3(0, 0.0, -0.108), Vector3(0.071, 0.049, 0.021), _edge, true)
	_ellipsoid(torso, Vector3(0, 0.003, -0.121), Vector3(0.026, 0.027, 0.012), _gem, true)
	if royal or priest or stocky:
		_sash(torso, priest)
	else:
		_plate(torso, Vector3(0, 0.14, -0.093), [
			Vector2(-0.13, 0.085), Vector2(-0.1, -0.07), Vector2(0, -0.108),
			Vector2(0.1, -0.07), Vector2(0.13, 0.085), Vector2(0, 0.036)
		], 0.029, _metal, true)
		_ellipsoid(torso, Vector3(0, 0.14, -0.137), Vector3(0.069, 0.07, 0.022), _edge, true)
	for side in [-1, 1]:
		_bone(torso, Vector3(side * 0.075, 0.257, -0.032), Vector3(0, 0.165, -0.111), 0.013, 0.012, _edge, true)
		_bone(torso, Vector3(side * 0.074, 0.261, 0.026), Vector3(0, 0.179, 0.100), 0.012, 0.012, _edge, true)
	_ellipsoid(torso, Vector3(0, 0.162, -0.117), Vector3(0.039, 0.045, 0.02), _gem, true)

	var head := _joint(torso, "Head", Vector3(0, 0.328, -0.008))
	_face(head, skin, role)
	if royal:
		var cape := _joint(torso, "Cape", Vector3(0, 0.235, 0.081))
		_plate(cape, Vector3(0, 0, 0.025), [
			Vector2(-0.129, 0.003), Vector2(-0.19, -0.494), Vector2(0, -0.458),
			Vector2(0.178, -0.5), Vector2(0.129, 0.001)
		], 0.026, _shadow)
		for side in [-1, 1]:
			_bone(cape, Vector3(side * 0.12, -0.016, 0.041), Vector3(side * 0.171, -0.457, 0.041), 0.008, 0.007, _metal, true)
		for i in range(4):
			_block(cape, Vector3(0, -0.15 - i * 0.071, 0.043), Vector3(0.045, 0.045, 0.012), _edge, Vector3(0, 0, PI / 4), true)

	var arm_l := _arm(torso, "ArmL", -1, skin, not priest)
	var arm_r := _arm(torso, "ArmR", 1, skin, not priest)
	if role == 0:
		_keris(arm_r, Vector3(0.094, -0.179, -0.111), 0.9, -0.34)
		_shield(arm_l, Vector3(-0.089, -0.16, -0.139))
	elif stocky:
		_mace(arm_r, Vector3(0.086, -0.176, -0.126))
	elif priest:
		_staff(arm_r, Vector3(0.073, -0.175, -0.106), false)
		_prayer_beads(arm_l)
	elif role == 4:
		_staff(arm_r, Vector3(0.074, -0.176, -0.11), true)
	else:
		_keris(arm_r, Vector3(0.086, -0.17, -0.112), 1.14, -0.29)


func _sash(parent: Node3D, priest: bool) -> void:
	for side in [-1, 1]:
		var sash := _block(parent, Vector3(0, 0.139, side * 0.094), Vector3(0.087, 0.27, 0.023),
			_cloth.lightened(0.18) if priest else _cloth, Vector3(0, 0, -side * 0.74))
		_block(sash, Vector3(0.035, 0, side * 0.016), Vector3(0.012, 0.26, 0.006), _metal, Vector3.ZERO, true)


func _arm(parent: Node3D, joint_name: String, side: int, skin: Color, armored: bool) -> Node3D:
	var arm := _joint(parent, joint_name, Vector3(side * 0.135, 0.205, -0.004))
	var elbow := Vector3(side * 0.085, -0.124, -0.004)
	var wrist := Vector3(side * 0.082, -0.177, -0.107)
	_bone(arm, Vector3.ZERO, elbow, 0.058, 0.043, skin)
	_bone(arm, elbow, wrist, 0.045, 0.031, skin)
	_ellipsoid(arm, wrist, Vector3(0.068, 0.067, 0.077), skin)
	_bone(arm, elbow.lerp(wrist, 0.65), elbow.lerp(wrist, 0.88), 0.039, 0.038, _metal, true)
	if armored:
		_ellipsoid(arm, Vector3(side * 0.009, -0.022, 0), Vector3(0.146, 0.092, 0.157), _metal, true)
		_ellipsoid(arm, Vector3(side * 0.01, 0.009, 0), Vector3(0.104, 0.046, 0.116), _edge, true)
	return arm


func _face(head: Node3D, skin: Color, role: int) -> void:
	_ellipsoid(head, Vector3(0, -0.079, 0.003), Vector3(0.086, 0.087, 0.088), skin)
	_ellipsoid(head, Vector3(0, 0.015, 0.008), Vector3(0.172, 0.198, 0.17), _hair)
	_ellipsoid(head, Vector3(0, -0.003, -0.036), Vector3(0.147, 0.173, 0.137), skin)
	_ellipsoid(head, Vector3(0, -0.02, -0.1), Vector3(0.041, 0.055, 0.042), skin.lightened(0.14))
	_block(head, Vector3(0, -0.059, -0.086), Vector3(0.043, 0.007, 0.006), _hair)
	for side in [-1, 1]:
		_ellipsoid(head, Vector3(side * 0.035, 0.003, -0.091), Vector3(0.027, 0.013, 0.019), _hair)
		_ellipsoid(head, Vector3(side * 0.071, -0.02, -0.017), Vector3(0.032, 0.045, 0.036), skin)
		_ellipsoid(head, Vector3(side * 0.079, -0.042, -0.026), Vector3(0.029, 0.034, 0.027), _edge, true)
	if role == 3:
		var gray := Color("#d4c2ab")
		_ellipsoid(head, Vector3(0, -0.078, -0.061), Vector3(0.117, 0.099, 0.096), gray)
		_turn(head, [[-0.153, 0.011], [-0.086, 0.047]], Vector3(0, 0, -0.06), 0.65, gray)
		_ellipsoid(head, Vector3(0, 0.098, 0.038), Vector3(0.112, 0.117, 0.118), gray.darkened(0.23))
		for i in range(3):
			_block(head, Vector3(0, 0.018 + i * 0.011, -0.102), Vector3(0.036, 0.004, 0.004), gray)
	elif role == 1 or role == 5:
		for side in [-1, 1]:
			_ellipsoid(head, Vector3(side * 0.021, -0.049, -0.093), Vector3(0.046, 0.017, 0.012), _hair)
	if role == 4:
		_ellipsoid(head, Vector3(0, -0.024, 0.073), Vector3(0.169, 0.234, 0.129), _hair)
		_ellipsoid(head, Vector3(0, -0.107, 0.099), Vector3(0.107, 0.112, 0.082), _hair)
		_ellipsoid(head, Vector3(0, -0.089, 0.142), Vector3(0.055, 0.038, 0.026), _edge, true)
	if role >= 4:
		_crown(head, role == 5)
	else:
		_turn(head, [[0.032, 0.086], [0.058, 0.089], [0.074, 0.077]], Vector3.ZERO, 1.0, _cloth)
		_turn(head, [[0.052, 0.091], [0.061, 0.091]], Vector3.ZERO, 1.0, _edge, true)
		_ellipsoid(head, Vector3(0, 0.058, -0.091), Vector3(0.039, 0.037, 0.019), _metal, true)
		if role == 0:
			_plate(head, Vector3(0.064, 0.059, 0.034),
				[Vector2(-0.02, 0), Vector2(0.043, 0.054), Vector2(0.092, 0.04), Vector2(0.057, -0.009)], 0.013, _cloth)


func _crown(head: Node3D, king: bool) -> void:
	var height := 0.208 if king else 0.158
	_turn(head, [[0.036, 0.096], [0.061, 0.106], [0.088, 0.084], [height - 0.04, 0.052],
		[height, 0.013]], Vector3.ZERO, 0.88, _metal, true)
	_turn(head, [[0.048, 0.108], [0.059, 0.109], [0.066, 0.1]], Vector3.ZERO, 0.91, _edge, true)
	for i in range(8):
		var angle := float(i) * TAU / 8.0
		var leaf := _joint(head, "CrownLeaf", Vector3(sin(angle) * 0.081, 0.067, -cos(angle) * 0.076))
		leaf.rotation.y = -angle
		var tip := 0.105 if i == 0 or (king and i == 4) else 0.052
		_plate(leaf, Vector3.ZERO, [Vector2(-0.029, 0), Vector2(-0.023, tip * 0.58),
			Vector2(0, tip), Vector2(0.023, tip * 0.58), Vector2(0.029, 0)], 0.018, _edge, true)
		_ellipsoid(leaf, Vector3(0, tip * 0.32, -0.011), Vector3(0.027, 0.043, 0.017), _gem, true)
	_ellipsoid(head, Vector3(0, height, 0), Vector3(0.044, 0.052, 0.044), _edge, true)


func _horse(body: Node3D) -> void:
	var mount := _joint(body, "Mount", Vector3(0, 0.015, 0))
	var coat := _wood.lightened(0.08)
	_ellipsoid(mount, Vector3(0, 0.3, 0.058), Vector3(0.29, 0.299, 0.52), coat)
	_ellipsoid(mount, Vector3(0, 0.333, 0.193), Vector3(0.316, 0.263, 0.257), coat)
	var neck := _joint(mount, "HorseHead", Vector3(0, 0.304, -0.116))
	_bone(neck, Vector3.ZERO, Vector3(0, 0.25, -0.127), 0.123, 0.066, coat)
	_bone(neck, Vector3(0, 0.03, 0.08), Vector3(0, 0.253, -0.059), 0.057, 0.043, _hair)
	_ellipsoid(neck, Vector3(0, 0.232, -0.164), Vector3(0.154, 0.146, 0.205), coat)
	_ellipsoid(neck, Vector3(0, 0.181, -0.234), Vector3(0.114, 0.112, 0.153), _hair)
	_ellipsoid(neck, Vector3(0, 0.232, -0.216), Vector3(0.159, 0.042, 0.128), _metal, true)
	for side in [-1, 1]:
		_bone(neck, Vector3(side * 0.043, 0.275, -0.132), Vector3(side * 0.067, 0.344, -0.148), 0.03, 0.012, coat)
		_ellipsoid(neck, Vector3(side * 0.068, 0.254, -0.182), Vector3(0.019, 0.022, 0.028), _hair)
		_bone(neck, Vector3(side * 0.06, 0.193, -0.235), Vector3(side * 0.065, 0.265, -0.113), 0.012, 0.012, _metal, true)
		_bone(mount, Vector3(side * 0.072, 0.49, -0.214), Vector3(side * 0.13, 0.55, 0.036), 0.009, 0.009, _hair)
		for row in [-1, 1]:
			var leg_name := ("Front" if row == -1 else "Hind") + ("L" if side == -1 else "R")
			var leg := _joint(mount, leg_name, Vector3(side * 0.102, 0.269, row * 0.17 + 0.021))
			var knee := Vector3(side * 0.014, -0.085, -row * 0.053)
			var hoof := Vector3(side * 0.027, -0.235, row * 0.013)
			_bone(leg, Vector3.ZERO, knee, 0.052, 0.033, coat)
			_bone(leg, knee, hoof, 0.035, 0.027, coat)
			_ellipsoid(leg, hoof, Vector3(0.069, 0.059, 0.103), _hair)
			_bone(leg, knee.lerp(hoof, 0.63), knee.lerp(hoof, 0.8), 0.035, 0.035, _metal, true)
	var tail := _joint(mount, "Tail", Vector3(0, 0.379, 0.26))
	_bone(tail, Vector3.ZERO, Vector3(0, -0.057, 0.074), 0.044, 0.039, _hair)
	_bone(tail, Vector3(0, -0.05, 0.07), Vector3(0.029, -0.223, 0.107), 0.044, 0.015, _hair)
	_ellipsoid(mount, Vector3(0, 0.382, 0.069), Vector3(0.323, 0.166, 0.317), _cloth)
	for side in [-1, 1]:
		_ellipsoid(mount, Vector3(side * 0.153, 0.322, 0.066), Vector3(0.044, 0.129, 0.211), _metal, true)
		_ellipsoid(mount, Vector3(side * 0.175, 0.328, 0.067), Vector3(0.013, 0.066, 0.099), _shadow)

	var rider := _joint(body, "Torso", Vector3(0, 0.442, 0.067))
	_turn(rider, [[0, 0.109], [0.05, 0.121], [0.176, 0.116], [0.197, 0.065]], Vector3.ZERO, 0.73, _cloth)
	_turn(rider, [[0.033, 0.123], [0.057, 0.123]], Vector3.ZERO, 0.74, _metal, true)
	_ellipsoid(rider, Vector3(0, 0.122, -0.081), Vector3(0.135, 0.1, 0.02), _metal, true)
	var head := _joint(rider, "Head", Vector3(0, 0.234, -0.006))
	head.scale = Vector3.ONE * 0.85
	_face(head, _skin, 2)
	_arm(rider, "ArmL", -1, _skin, true).scale = Vector3.ONE * 0.8
	var arm := _arm(rider, "ArmR", 1, _skin, true)
	arm.position.y -= 0.037
	arm.scale = Vector3.ONE * 0.8
	_spear(arm, Vector3(0.09, -0.153, -0.126))
	for side in [-1, 1]:
		_bone(rider, Vector3(side * 0.079, 0.01, 0), Vector3(side * 0.17, -0.082, -0.042), 0.049, 0.043, _cloth)
		_bone(rider, Vector3(side * 0.17, -0.082, -0.042), Vector3(side * 0.18, -0.193, 0.024), 0.046, 0.032, _hair)
		_ellipsoid(rider, Vector3(side * 0.18, -0.2, 0.001), Vector3(0.073, 0.047, 0.125), _wood)


func _keris(parent: Node3D, pos: Vector3, size_factor: float, tilt: float) -> void:
	var blade := _joint(parent, "Keris", pos)
	blade.scale = Vector3.ONE * size_factor
	blade.rotation.z = tilt
	_bone(blade, Vector3(0, -0.061, 0), Vector3(0, 0.039, 0), 0.022, 0.019, _wood)
	_ellipsoid(blade, Vector3(0, -0.06, 0.009), Vector3(0.047, 0.061, 0.047), _metal, true)
	_ellipsoid(blade, Vector3(0, 0.043, 0), Vector3(0.121, 0.033, 0.054), _edge, true)
	_plate(blade, Vector3(0, 0.047, 0), [
		Vector2(-0.049, 0), Vector2(-0.019, 0.048), Vector2(0.009, 0.083),
		Vector2(-0.02, 0.123), Vector2(-0.03, 0.153), Vector2(0.003, 0.191),
		Vector2(-0.003, 0.251), Vector2(0.031, 0.195), Vector2(0.003, 0.151),
		Vector2(0.036, 0.11), Vector2(0.044, 0.079), Vector2(0.015, 0.038), Vector2(0.054, 0)
	], 0.016, Color("#c9d7d5"), true)


func _shield(parent: Node3D, pos: Vector3) -> void:
	var shield := _joint(parent, "Taming", pos)
	shield.rotation.x = PI / 2.0
	_turn(shield, [[-0.015, 0.093], [0.021, 0.092], [0.03, 0.077]], Vector3.ZERO, 1.0, _wood)
	_turn(shield, [[0.015, 0.093], [0.027, 0.093], [0.031, 0.082]], Vector3.ZERO, 1.0, _metal, true)
	_ellipsoid(shield, Vector3(0, 0.035, 0), Vector3(0.07, 0.052, 0.07), _edge, true)
	_batik(shield, 0.0, 0.034, 0.062, 1.0, 7)


func _mace(parent: Node3D, pos: Vector3) -> void:
	var mace := _joint(parent, "Gada", pos)
	mace.rotation.z = -0.23
	_bone(mace, Vector3(0, -0.215, 0), Vector3(0, 0.266, 0), 0.035, 0.029, _wood)
	_band(mace, Vector3(0, 0.065, 0), 0.04, 0.033)
	_band(mace, Vector3(0, -0.209, 0), 0.041, 0.032)
	_ellipsoid(mace, Vector3(0, 0.297, 0), Vector3(0.174, 0.202, 0.174), _metal, true)
	for i in range(8):
		var angle := i * TAU / 8.0
		_ellipsoid(mace, Vector3(sin(angle) * 0.066, 0.299, cos(angle) * 0.066), Vector3(0.052, 0.152, 0.052), _edge, true)
	_ellipsoid(mace, Vector3(0, 0.397, 0), Vector3(0.074, 0.056, 0.074), _edge, true)


func _staff(parent: Node3D, pos: Vector3, royal: bool) -> void:
	_bone(parent, pos + Vector3(0, -0.268, 0), pos + Vector3(0, 0.35, 0), 0.023, 0.019, _wood)
	for height in [-0.245, 0.063, 0.249, 0.322]:
		_band(parent, pos + Vector3(0, height, 0), 0.025, 0.027)
	var tip := pos + Vector3(0, 0.343, 0)
	if royal:
		_ellipsoid(parent, tip, Vector3(0.107, 0.104, 0.107), _metal, true)
		_ellipsoid(parent, tip + Vector3(0, 0.03, -0.028), Vector3(0.061, 0.078, 0.061), _gem, true)
		for i in range(5):
			var angle := i * TAU / 5.0
			_bone(parent, tip, tip + Vector3(sin(angle) * 0.046, 0.07, cos(angle) * 0.046), 0.02, 0.005, _edge, true)
	else:
		_turn(parent, [[-0.036, 0.043], [0.016, 0.052], [0.046, 0.033], [0.072, 0.009]], tip, 1.0, _metal, true)
		_ellipsoid(parent, tip + Vector3(0, 0.07, 0), Vector3(0.036, 0.042, 0.036), _edge, true)


func _prayer_beads(parent: Node3D) -> void:
	for i in range(9):
		var a := TAU * i / 9.0
		_ellipsoid(parent, Vector3(-0.087 + sin(a) * 0.04, -0.223 + cos(a) * 0.052, -0.124),
			Vector3.ONE * 0.022, _wood.lightened(0.25))


func _spear(parent: Node3D, pos: Vector3) -> void:
	var spear := _joint(parent, "Tombak", pos)
	spear.rotation = Vector3(0.25, 0, -0.12)
	_bone(spear, Vector3(0, -0.48, 0), Vector3(0, 0.43, 0), 0.019, 0.017, _wood)
	for height in [-0.453, 0.07, 0.386]:
		_band(spear, Vector3(0, height, 0), 0.025, 0.047)
	var leaf := [Vector2(-0.021, 0), Vector2(-0.055, 0.075), Vector2(0, 0.196), Vector2(0.055, 0.075), Vector2(0.021, 0)]
	_plate(spear, Vector3(0, 0.41, 0), leaf, 0.021, Color("#c6d9d7"), true)
	_bone(spear, Vector3(0, 0.43, -0.011), Vector3(0, 0.57, -0.011), 0.011, 0.001, _edge, true)
	_plate(spear, Vector3(0.028, 0.319, 0), [Vector2(0, 0.051), Vector2(0.15, 0.079),
		Vector2(0.103, 0.011), Vector2(0.15, -0.028), Vector2(0, -0.001)], 0.013, _cloth)


func _batik(parent: Node3D, offset: float, y: float, radius: float, depth: float, count: int) -> void:
	for i in range(count):
		var a := offset + TAU * i / count
		var motif := _joint(parent, "Batik", Vector3(sin(a) * radius, y, cos(a) * radius * depth))
		motif.rotation.y = a
		_block(motif, Vector3.ZERO, Vector3(0.037, 0.037, 0.008), _edge, Vector3(0, 0, PI * 0.25))
		_block(motif, Vector3(0, 0, 0.007), Vector3(0.017, 0.017, 0.007), _cloth, Vector3(0, 0, PI * 0.25))


func _band(parent: Node3D, pos: Vector3, r: float, h: float) -> void:
	_turn(parent, [[-h * 0.5, r * 0.92], [0, r], [h * 0.5, r * 0.92]], pos, 1.0, _metal, true)


func _joint(parent: Node3D, joint_name: String, pos: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = joint_name
	joint.position = pos
	parent.add_child(joint, true)
	return joint


func _ellipsoid(parent: Node3D, pos: Vector3, size: Vector3, color: Color, polished: bool = false) -> void:
	if _ball == null:
		_ball = SphereMesh.new()
		_ball.radial_segments = 12
		_ball.rings = 6
	_stamp(parent, _ball.get_mesh_arrays(), Transform3D(Basis.from_scale(size), pos), color, polished)


func _block(parent: Node3D, pos: Vector3, size: Vector3, color: Color, angles: Vector3 = Vector3.ZERO, polished: bool = false) -> Node3D:
	if _box == null:
		_box = BoxMesh.new()
	var block := _joint(parent, "Detail", pos)
	block.rotation = angles
	_stamp(block, _box.get_mesh_arrays(), Transform3D(Basis.from_scale(size), Vector3.ZERO), color, polished)
	return block


func _bone(parent: Node3D, from: Vector3, to: Vector3, r0: float, r1: float, color: Color, polished: bool = false) -> void:
	var direction := to - from
	var turn := _joint(parent, "Segment", from)
	turn.quaternion = Quaternion(Vector3.UP, direction.normalized())
	_turn(turn, [[0, r0 * 0.73], [direction.length() * 0.17, r0],
		[direction.length() * 0.9, r1], [direction.length(), r1 * 0.8]], Vector3.ZERO, 1.0, color, polished, 10)


func _turn(parent: Node3D, profile: Array, pos: Vector3, depth: float, color: Color, polished: bool = false, segments: int = 22) -> void:
	var radii := [[profile.front()[0], 0.0]] + profile + [[profile.back()[0], 0.0]]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in range(radii.size() - 1):
		var bottom_y: float = radii[row][0]
		var top_y: float = radii[row + 1][0]
		var bottom_radius: float = radii[row][1]
		var top_radius: float = radii[row + 1][1]
		for i in range(segments + 1):
			var a := TAU * i / segments
			var normal := Vector3(sin(a) * (top_y - bottom_y), bottom_radius - top_radius,
				cos(a) * (top_y - bottom_y) / depth).normalized()
			var idx := vertices.size()
			vertices.append(pos + Vector3(sin(a) * bottom_radius, bottom_y, cos(a) * bottom_radius * depth))
			vertices.append(pos + Vector3(sin(a) * top_radius, top_y, cos(a) * top_radius * depth))
			normals.append(normal)
			normals.append(normal)
			if i < segments:
				indices.append_array(PackedInt32Array([idx, idx + 1, idx + 2, idx + 2, idx + 1, idx + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	_stamp(parent, arrays, Transform3D.IDENTITY, color, polished)


func _plate(parent: Node3D, pos: Vector3, outline: Array, thickness: float, color: Color, polished: bool = false) -> void:
	var polygon := PackedVector2Array(outline)
	var triangles := Geometry2D.triangulate_polygon(polygon)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for side in [-1, 1]:
		var offset := vertices.size()
		for point in polygon:
			vertices.append(pos + Vector3(point.x, point.y, side * thickness * 0.5))
			normals.append(Vector3(0, 0, side))
		for i in range(0, triangles.size(), 3):
			indices.append(offset + triangles[i])
			indices.append(offset + triangles[i + (1 if side == -1 else 2)])
			indices.append(offset + triangles[i + (2 if side == -1 else 1)])
	var clockwise := Geometry2D.is_polygon_clockwise(polygon)
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var normal := Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		if clockwise:
			normal = -normal
		var offset := vertices.size()
		for point in [a, b]:
			vertices.append(pos + Vector3(point.x, point.y, -thickness * 0.5))
			vertices.append(pos + Vector3(point.x, point.y, thickness * 0.5))
			normals.append(normal)
			normals.append(normal)
		var face := [0, 1, 2, 2, 1, 3]
		if clockwise:
			face.reverse()
		for idx in face:
			indices.append(offset + idx)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	_stamp(parent, arrays, Transform3D.IDENTITY, color, polished)


func _stamp(parent: Node3D, arrays: Array, placement: Transform3D, color: Color, polished: bool) -> void:
	# Fold decorative subnodes into the closest joint to keep the rig lightweight.
	var joint := parent
	while joint.name.begins_with("Detail") or joint.name.begins_with("Batik") or joint.name.begins_with("Segment") or joint.name.begins_with("CrownLeaf"):
		placement = joint.transform * placement
		joint = joint.get_parent()
	var finish := int(polished)
	if not _geometry.has(joint):
		_geometry[joint] = [{}, {}]
	var surface: Dictionary = _geometry[joint][finish]
	if surface.is_empty():
		surface["vertices"] = PackedVector3Array()
		surface["normals"] = PackedVector3Array()
		surface["colors"] = PackedColorArray()
		surface["indices"] = PackedInt32Array()
	var vertices: PackedVector3Array = surface["vertices"]
	var normals: PackedVector3Array = surface["normals"]
	var colors: PackedColorArray = surface["colors"]
	var indices: PackedInt32Array = surface["indices"]
	var offset := vertices.size()
	var basis := placement.basis.inverse().transposed()
	for v in arrays[Mesh.ARRAY_VERTEX]:
		vertices.append(placement * v)
		colors.append(color)
	for n in arrays[Mesh.ARRAY_NORMAL]:
		normals.append((basis * n).normalized())
	for idx in arrays[Mesh.ARRAY_INDEX]:
		indices.append(offset + idx)
	surface["vertices"] = vertices
	surface["normals"] = normals
	surface["colors"] = colors
	surface["indices"] = indices


func _bake(root: Node3D) -> void:
	if _finish.is_empty():
		for i in range(2):
			var mat := StandardMaterial3D.new()
			mat.vertex_color_use_as_albedo = true
			mat.vertex_color_is_srgb = true
			mat.metallic = 0.12 if i == 0 else 0.58
			mat.roughness = 0.68 if i == 0 else 0.32
			_finish.append(mat)
	for joint: Node3D in _geometry:
		var mesh := ArrayMesh.new()
		for i in range(2):
			var surface: Dictionary = _geometry[joint][i]
			if surface.is_empty():
				continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = surface["vertices"]
			arrays[Mesh.ARRAY_NORMAL] = surface["normals"]
			arrays[Mesh.ARRAY_COLOR] = surface["colors"]
			arrays[Mesh.ARRAY_INDEX] = surface["indices"]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, _finish[i])
		var instance := MeshInstance3D.new()
		instance.name = "Sculpt"
		instance.mesh = mesh
		joint.add_child(instance)
	_prune_details(root, root)


func _prune_details(node: Node, root: Node) -> void:
	for child in node.get_children():
		if child.name.begins_with("Detail") or child.name.begins_with("Batik") or child.name.begins_with("Segment") or child.name.begins_with("CrownLeaf"):
			child.free()
		else:
			child.owner = root
			_prune_details(child, root)
