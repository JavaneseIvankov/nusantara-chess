extends Node

const MINIATURES := preload("res://scripts/pieces/nusantara_miniatures.gd")
const HEIGHTS := [0.89, 1.19, 1.23, 1.30, 1.43, 1.61]

func _ready() -> void:
	var preview := SubViewport.new()
	preview.size = Vector2i(192, 192)
	preview.own_world_3d = true
	preview.transparent_bg = true
	preview.msaa_3d = Viewport.MSAA_4X
	preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(preview)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	preview.add_child(camera)
	var light := DirectionalLight3D.new()
	preview.add_child(light)
	light.rotation_degrees = Vector3(-30, -20, 0)
	light.light_energy = 1.45
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("#eadabd")
	world.environment.ambient_light_energy = 0.9
	preview.add_child(world)
	for i in HEIGHTS.size():
		var piece := MINIATURES.instantiate(i, ChessPiece.Faction.GOLD) as Node3D
		preview.add_child(piece)
		piece.rotation.y = -0.18
		var center := Vector3(0, HEIGHTS[i] * 0.50, 0)
		camera.position = center + Vector3(-1.5, 1.15, -3.9)
		camera.look_at(center)
		camera.size = maxf(1.10, HEIGHTS[i] * 1.15)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := "res://assets/ui/art/piece-%d.png" % i
		var error := preview.get_texture().get_image().save_png(path)
		if error != OK:
			printerr("Could not save icon: ", path)
			get_tree().quit(1)
			return
		preview.remove_child(piece)
		piece.queue_free()
	get_tree().quit()
