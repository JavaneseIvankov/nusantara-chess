extends RefCounted
## Joint poses shared by the board and the capture viewport.

var _joints: Dictionary = {}


func _init(model: Node3D) -> void:
	for joint_name in ["Figure", "Torso", "Head", "ArmL", "ArmR", "LegL", "LegR", "Cloth", "Cape",
		"Mount", "FrontL", "FrontR", "HindL", "HindR", "HorseHead", "Tail"]:
		var node := model.find_child(joint_name, true, false) as Node3D
		if node:
			_joints[joint_name] = [node, node.position]


func stride(role: int, t: float, distance: float) -> void:
	var envelope := sin(PI * t)
	var steps := clampf(distance * 0.95, 1.0, 3.25)
	var gait := sin(TAU * steps * t) * envelope
	var bounce := absf(gait)
	match role:
		0: # Prajurit berlari dengan keris dan taming.
			_pose("Figure", Vector3(0, bounce * 0.035, 0), Vector3(-0.16 * envelope, 0, 0))
			_legs(gait * 0.72)
			_arms(-gait * 0.49 + 0.15 * envelope, gait * 0.4)
		1: # Mahapatih menapak berat sambil mengimbangi gada.
			var stomp := sin(TAU * maxf(1.0, steps * 0.66) * t) * envelope
			_pose("Figure", Vector3(0, absf(stomp) * 0.043, 0), Vector3(-0.07 * envelope, 0, stomp * 0.16))
			_legs(stomp * 0.53)
			_arms(-stomp * 0.26, -0.42 * envelope + stomp * 0.12)
		2: # Kuda melompat dan mengayuh pasangan kaki depan/belakang.
			var gallop := sin(t * TAU * 2.0) * envelope
			_pose("Mount", Vector3(0, maxf(gallop, 0) * 0.065, 0), Vector3(-cos(PI * t) * envelope * 0.24, 0, 0))
			_pose("Torso", Vector3(0, absf(gallop) * 0.045, 0), Vector3(gallop * 0.21, 0, 0))
			_spin("HorseHead", -gallop * 0.27)
			_spin("FrontL", 0.8 * gallop + 0.34 * envelope)
			_spin("FrontR", 0.68 * gallop + 0.19 * envelope)
			_spin("HindL", -gallop * 0.73 - 0.16 * envelope)
			_spin("HindR", -gallop * 0.62 - 0.28 * envelope)
			_pose("Tail", Vector3.ZERO, Vector3(0.18 * envelope, gallop * 0.4, 0))
			_arms(gallop * 0.17, -0.8 * envelope)
		3: # Resi melangkah pelan, tongkat terangkat lalu menapak.
			_pose("Figure", Vector3(0, 0.018 * envelope, 0), Vector3(-0.052 * envelope, 0, gait * 0.038))
			_legs(gait * 0.29)
			_arms(-gait * 0.13, -0.33 * envelope + gait * 0.12)
			_spin("Head", 0.09 * envelope)
			_spin("Cloth", gait * 0.09)
		4: # Ratu melangkah ringan dengan jubah berayun.
			_pose("Figure", Vector3(0, (0.044 + bounce * 0.019) * envelope, 0), Vector3(0, gait * 0.15, -gait * 0.09))
			_legs(gait * 0.34)
			_arms(gait * 0.18, -0.23 * envelope)
			_pose("Cape", Vector3.ZERO, Vector3(-0.28 * envelope, 0, gait * 0.22))
			_spin("Cloth", -0.113 * envelope, gait * 0.17)
		5: # Raja bergerak tegap dengan satu langkah mantap.
			var royal_step := sin(TAU * t) * envelope
			_pose("Figure", Vector3(0, absf(royal_step) * 0.039, 0), Vector3(-0.082 * envelope, 0, 0))
			_legs(royal_step * 0.43)
			_arms(royal_step * 0.16, -0.23 * envelope)
			_pose("Cape", Vector3.ZERO, Vector3(-0.19 * envelope, 0, royal_step * 0.13))


func attack(role: int, windup: float, strike: float) -> void:
	var weight := windup + strike
	_pose("Figure", Vector3(0, 0.03 * strike, 0), Vector3(windup * 0.15 - strike * 0.25, 0, 0))
	_pose("Torso", Vector3.ZERO, Vector3(0, windup * 0.43 - strike * 0.59, 0.1 * weight))
	match role:
		0: _arms(windup * 0.21 - strike * 0.63, -windup * 1.22 - strike * 1.59)
		1: _arms(-strike * 0.54, -windup * 2.06 - strike * 0.94)
		2:
			_spin("Mount", windup * 0.32 - strike * 0.31)
			_spin("FrontL", -weight * 0.55)
			_spin("FrontR", -weight * 0.6)
			_arms(-strike * 0.34, -windup * 0.8 + strike * 1.25)
		3: _arms(-windup * 0.69 - strike * 0.79, -windup * 1.03 - strike * 0.65)
		4:
			_arms(-strike * 0.79, -windup * 1.28 - strike * 1.68)
			_spin("Cape", -weight * 0.32, strike * 0.33)
		5:
			_arms(-strike * 0.62, -windup * 1.42 - strike * 1.33)
			_spin("Cape", -weight * 0.31, strike * 0.2)


func recoil(amount: float) -> void:
	_pose("Figure", Vector3(0, amount * 0.15, 0.12 * amount), Vector3(amount * 0.68, 0, amount * 0.28))
	_arms(-amount * 0.66, -amount * 0.79)


func reset() -> void:
	for entry: Array in _joints.values():
		var node: Node3D = entry[0]
		node.position = entry[1]
		node.rotation = Vector3.ZERO


func _legs(step: float) -> void:
	_spin("LegL", step)
	_spin("LegR", -step)


func _arms(left: float, right: float) -> void:
	_spin("ArmL", left)
	_spin("ArmR", right)


func _spin(joint_name: String, x: float, y: float = 0.0) -> void:
	_pose(joint_name, Vector3.ZERO, Vector3(x, y, 0))


func _pose(joint_name: String, offset: Vector3, angles: Vector3) -> void:
	if _joints.has(joint_name):
		var entry: Array = _joints[joint_name]
		var joint: Node3D = entry[0]
		joint.rotation = angles
		joint.position = entry[1] + offset
