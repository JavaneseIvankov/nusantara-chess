extends Node

const GAME := preload("res://main/main.tscn")
var _game: Node
var _preview: Window
var _target := ""

func _ready() -> void:
	_target = OS.get_environment("NUSANTARA_SCREENSHOTS")
	if _target.is_empty():
		printerr("Set NUSANTARA_SCREENSHOTS to an existing output folder.")
		get_tree().quit(1)
		return
	_preview = get_window()
	_preview.title = "Nusantara UI QA"
	_game = GAME.instantiate()
	add_child(_game)
	for size in [Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1920, 1080)]:
		var name_suffix := "%dx%d" % [size.x, size.y]
		_preview.size = size
		await _pause()
		if _preview.size != size:
			printerr("Compositor blocked the requested resolution ", size, " (got ", _preview.size, "). Make the test window floating.")
			get_tree().quit(1)
			return
		if not _page_fits(_game.main_menu._home):
			return
		await _take("menu-" + name_suffix)
		await _activate("VersusBot", _game.main_menu)
		await get_tree().process_frame
		if not _page_fits(_game.main_menu._setup):
			return
		await _take("setup-" + name_suffix)
		await _activate("StartMatch", _game.main_menu)
		await _pause()
		await _take("match-" + name_suffix)
		if _game.game_hud.is_compact_layout():
			_game.game_hud._details.pressed.emit()
			await _take("notes-" + name_suffix)
			_game.game_hud._details.pressed.emit()
		var camera := _preview.get_camera_3d()
		for square in ["e2", "e4"]:
			var tile: Vector2i = _game.chess_board._algebraic_to_grid(square)
			var center: Vector3 = _game.chess_board.grid_to_world(tile)
			_click(camera.unproject_position(center + Vector3(0, 0.22, 0)))
			await get_tree().create_timer(0.15).timeout
		var deadline := Time.get_ticks_msec() + 7500
		while _game.chess_board.uci_history.size() < 2 and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		if _game.chess_board.uci_history.size() != 2:
			printerr("UI move failed at ", size, ": ", _game.chess_board.uci_history)
			get_tree().quit(1)
			return
		await _take("reply-" + name_suffix)
		_game._return_to_menu()
		await _pause()
	get_tree().quit()


func _page_fits(page: Control) -> bool:
	var fits := page.is_visible_in_tree() and _preview.get_visible_rect().encloses(page.get_global_rect())
	if not fits:
		printerr("Menu page outside the viewport: ", page.get_global_rect(), " in ", _preview.get_visible_rect())
		get_tree().quit(1)
	return fits


func _activate(button_name: String, from: Control) -> void:
	var button := from.find_child(button_name, true, false) as Button
	button.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	_preview.push_input(key, true)
	key = key.duplicate()
	key.pressed = false
	_preview.push_input(key, true)
	await get_tree().process_frame


func _click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_preview.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	_preview.push_input(event, true)


func _pause() -> void:
	await get_tree().create_timer(0.65).timeout


func _take(name_suffix: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var screenshot := _preview.get_texture().get_image()
	print(name_suffix, " ", screenshot.get_size(), " compact: ", _game.game_hud.is_compact_layout())
	screenshot.save_png(_target.path_join(name_suffix + ".png"))
