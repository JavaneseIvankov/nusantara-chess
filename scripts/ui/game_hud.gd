class_name GameHUD
extends Control

signal camera_reset_requested
signal auto_flip_toggled(enabled: bool)
signal camera_top_view_requested
signal restart_requested
signal forfeit_requested
signal menu_requested
signal retry_requested
signal promotion_piece_selected(chosen_type: ChessPiece.PieceType)
signal layout_changed(compact: bool)

const MINIATURES := preload("res://scripts/pieces/nusantara_miniatures.gd")
const REPLAY := preload("res://scripts/ui/capture_replay.gd")
const DUEL := preload("res://assets/ui/art/duel.png")
const WARRIOR := preload("res://assets/ui/art/prajurit.png")
const PIECE_NAMES := ["Pion", "Benteng", "Kuda", "Gajah", "Ratu", "Raja"]
const PIECE_ICONS := ["♟", "♜", "♞", "♝", "♛", "♚"]

var _status: PanelContainer
var _info: PanelContainer
var _controls: HBoxContainer
var _replay_host: MarginContainer
var _replay: PanelContainer
var _details: Button
var _auto_flip: Button
var _forfeit: Button
var _turn_text: Label
var _status_art: TextureRect
var _role: Label
var _check: Label
var _context: Label
var _history: RichTextLabel
var _captures: Array[HBoxContainer] = []
var _captured := [[], []]
var _icons: Array[Texture2D] = []
var _modal: ColorRect
var _modal_body: VBoxContainer
var _modal_buttons: HFlowContainer
var _control_buttons: Array[Control] = []
var _previous_focus: Control
var _solo := false
var _human_faction := 0
var _auto := true
var _compact := false
var _details_open := false
var _moves := PackedStringArray()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in PIECE_NAMES.size():
		var path := "res://assets/ui/art/piece-%d.png" % i
		_icons.append(load(path) as Texture2D if ResourceLoader.exists(path) else null)
	_build_status()
	_build_info()
	_build_controls()
	_build_replay()
	_build_modal()
	resized.connect(_fit)
	_fit()


func configure(solo: bool, human_faction: int, difficulty: int) -> void:
	_close_modal(false)
	_solo = solo
	_human_faction = human_faction
	_auto = not solo
	_auto_flip.visible = not solo
	_auto_flip.text = "Kamera otomatis: aktif"
	_forfeit.disabled = false
	_details_open = false
	_context.text = "Lawan Bot · %s" % StockfishClient.PRESETS[difficulty].label if solo else "Dua Pemain Lokal"
	_role.hide()
	_check.hide()
	_moves.clear()
	_history.clear()
	_captured = [[], []]
	for faction in range(2):
		_refresh_captures(faction)
	_replay.reset()
	update_turn(ChessPiece.Faction.GOLD)
	_fit()


func update_turn(faction: ChessPiece.Faction, thinking: bool = false) -> void:
	_status_art.texture = TakhtaTheme.faction_art(faction)
	var name_text := TakhtaTheme.faction_name(faction)
	_turn_text.text = "%s · Giliran" % name_text
	if _solo:
		_turn_text.text = "%s · %s" % [name_text, "Giliran Anda" if faction == _human_faction else ("Bot berpikir" if thinking else "Giliran bot")]
	_turn_text.add_theme_color_override("font_color", TakhtaTheme.faction_color(faction))
	_status.reset_size()


func set_check_warning(in_check: bool) -> void:
	_check.visible = in_check
	_status.reset_size()


func show_selected_role(role: int) -> void:
	_role.visible = role >= 0
	if role >= 0:
		var title: String = MINIATURES.SHORT_TITLES[role]
		_role.text = PIECE_NAMES[role] if title == PIECE_NAMES[role] else "%s · %s" % [PIECE_NAMES[role], title]
	_status.reset_size()


func add_captured_piece(faction: ChessPiece.Faction, captured_type: ChessPiece.PieceType) -> void:
	_captured[faction].append(captured_type)
	_refresh_captures(faction)


func _refresh_captures(faction: int) -> void:
	var row := _captures[faction]
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	if _captured[faction].is_empty():
		row.add_child(TakhtaTheme.label("—", 17, TakhtaTheme.MUTED))
		return
	for i in range(5):
		var count: int = _captured[faction].count(i)
		if count > 0:
			var token := HBoxContainer.new()
			token.add_theme_constant_override("separation", 1)
			row.add_child(token)
			if _icons[i]:
				token.add_child(TakhtaTheme.picture(_icons[i], Vector2(18, 23)))
			else:
				token.add_child(TakhtaTheme.label(PIECE_ICONS[i], 16, TakhtaTheme.faction_color(faction)))
			if count > 1:
				token.add_child(TakhtaTheme.label(str(count), 15))


func add_move_record(faction: ChessPiece.Faction, notation: String) -> void:
	if faction == ChessPiece.Faction.GOLD:
		_moves.append("[color=#e3bb72]%d.  %s[/color]" % [_moves.size() + 1, notation])
	elif not _moves.is_empty():
		_moves[_moves.size() - 1] += "    [color=#afc5d6]%s[/color]" % notation
	_history.text = "\n".join(_moves)


func show_capture_replay(attacker: ChessPiece.PieceType, defender: ChessPiece.PieceType, faction: ChessPiece.Faction) -> void:
	_replay.play(attacker, defender, faction)


func show_promotion_choices() -> void:
	_open_modal("Promosi Pion", "Pilih bidak pengganti.", WARRIOR)
	var items: Array[Control] = []
	for role in [ChessPiece.PieceType.QUEEN, ChessPiece.PieceType.ROOK, ChessPiece.PieceType.BISHOP, ChessPiece.PieceType.KNIGHT]:
		var chosen: ChessPiece.PieceType = role
		var button := _action(PIECE_NAMES[role], func():
			_close_modal()
			promotion_piece_selected.emit(chosen)
		)
		button.icon = _icons[role]
		button.add_theme_constant_override("icon_max_width", 26)
		items.append(button)
	_focus_modal(items)


func show_result(winner: int, reason: String) -> void:
	_forfeit.disabled = true
	var title := "Laga Berakhir Seri" if winner == ChessBoard.DRAW else "%s Menang" % TakhtaTheme.faction_name(winner)
	var art := DUEL if winner == ChessBoard.DRAW else TakhtaTheme.faction_art(winner)
	_open_modal(title, reason, art)
	_focus_modal([
		_action("Ulangi Laga", func(): restart_requested.emit(), true),
		_action("Kembali ke Menu", func(): menu_requested.emit()),
	])


func show_bot_error(message: String) -> void:
	_open_modal("Bot Tidak Merespons", message)
	_focus_modal([
		_action("Coba Lagi", _retry, true),
		_action("Kembali ke Menu", func(): menu_requested.emit()),
	])


func _retry() -> void:
	_close_modal()
	retry_requested.emit()


func _build_status() -> void:
	_status = PanelContainer.new()
	add_child(_status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	_status.add_child(row)
	_status_art = TakhtaTheme.picture(TakhtaTheme.GOLD_ART, Vector2(51, 55))
	row.add_child(_status_art)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	row.add_child(stack)
	_context = TakhtaTheme.label("", 17, TakhtaTheme.MUTED)
	_turn_text = TakhtaTheme.label("", 23, TakhtaTheme.GOLD, true)
	_check = TakhtaTheme.label("!  Raja sedang diskak", 17, TakhtaTheme.ALERT)
	_role = TakhtaTheme.label("", 15, TakhtaTheme.MUTED)
	for item in [_context, _turn_text, _check, _role]:
		stack.add_child(item)


func _build_info() -> void:
	_info = PanelContainer.new()
	add_child(_info)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	_info.add_child(list)
	list.add_child(TakhtaTheme.label("Riwayat Langkah", 19, TakhtaTheme.IVORY, true))
	_history = RichTextLabel.new()
	_history.bbcode_enabled = true
	_history.scroll_following = true
	_history.custom_minimum_size.y = 110
	_history.add_theme_font_size_override("normal_font_size", 17)
	list.add_child(_history)
	list.add_child(HSeparator.new())
	list.add_child(TakhtaTheme.label("Bidak Tawanan", 19, TakhtaTheme.IVORY, true))
	for faction in range(2):
		var line := HBoxContainer.new()
		list.add_child(line)
		var caption := TakhtaTheme.label(TakhtaTheme.faction_name(faction), 16, TakhtaTheme.faction_color(faction))
		caption.custom_minimum_size.x = 74
		line.add_child(caption)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		line.add_child(row)
		_captures.append(row)


func _build_controls() -> void:
	_controls = HBoxContainer.new()
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.add_theme_constant_override("separation", 6)
	add_child(_controls)
	_details = _control("Catatan Laga", func():
		_details_open = not _details_open
		_fit()
	)
	_control("Sudut Atas", func(): camera_top_view_requested.emit())
	_control("Reset Kamera", func(): camera_reset_requested.emit())
	_auto_flip = _control("Kamera otomatis: aktif", func():
		_auto = not _auto
		_auto_flip.text = "Kamera otomatis: aktif" if _auto else "Kamera otomatis: mati"
		auto_flip_toggled.emit(_auto)
	)
	_control("Ulangi", _confirm_restart)
	_forfeit = _control("Menyerah", _confirm_forfeit)
	_control("Menu", _confirm_menu)


func _control(title: String, callback: Callable) -> Button:
	var button := TakhtaTheme.button(title, callback)
	button.add_theme_font_size_override("font_size", 17)
	_controls.add_child(button)
	_control_buttons.append(button)
	return button


func _build_replay() -> void:
	_replay_host = MarginContainer.new()
	_replay_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_replay_host)
	_replay = REPLAY.new()
	_replay_host.add_child(_replay)


func _build_modal() -> void:
	_modal = ColorRect.new()
	_modal.color = Color("#101213db")
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 390
	center.add_child(panel)
	panel.add_theme_stylebox_override("panel", TakhtaTheme.panel(TakhtaTheme.SURFACE, TakhtaTheme.BRASS, 24))
	_modal_body = VBoxContainer.new()
	_modal_body.add_theme_constant_override("separation", 12)
	panel.add_child(_modal_body)
	_modal.hide()


func _open_modal(title: String, message: String, art: Texture2D = null) -> void:
	if not _modal.visible:
		_previous_focus = get_viewport().gui_get_focus_owner()
	for control in _control_buttons:
		control.focus_mode = Control.FOCUS_NONE
	for child in _modal_body.get_children():
		_modal_body.remove_child(child)
		child.queue_free()
	if art:
		_modal_body.add_child(TakhtaTheme.picture(art, Vector2(90, 80)))
	var headline := TakhtaTheme.label(title, 34, TakhtaTheme.IVORY, true)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_body.add_child(headline)
	var detail := TakhtaTheme.label(message, 19, TakhtaTheme.MUTED)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_body.add_child(detail)
	_modal_buttons = HFlowContainer.new()
	_modal_buttons.alignment = FlowContainer.ALIGNMENT_CENTER
	_modal_buttons.add_theme_constant_override("h_separation", 8)
	_modal_buttons.add_theme_constant_override("v_separation", 8)
	_modal_body.add_child(_modal_buttons)
	_modal.show()


func _focus_modal(buttons: Array[Control]) -> void:
	TakhtaTheme.link_focus(buttons)
	buttons[0].grab_focus()


func _action(title: String, callback: Callable, primary: bool = false) -> Button:
	var button := TakhtaTheme.button(title, callback, primary)
	_modal_buttons.add_child(button)
	return button


func _close_modal(restore_focus: bool = true) -> void:
	_modal.hide()
	for control in _control_buttons:
		control.focus_mode = Control.FOCUS_ALL
	if restore_focus and is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	_previous_focus = null


func _confirm_forfeit() -> void:
	_open_modal("Menyerah?", "Lawan akan memenangkan laga ini.")
	_focus_modal([
		_action("Lanjut Bermain", _close_modal, true),
		_action("Menyerah", func(): forfeit_requested.emit()),
	])


func _confirm_restart() -> void:
	_open_modal("Ulangi Laga?", "Posisi sekarang akan dikosongkan.")
	_focus_modal([
		_action("Lanjut Bermain", _close_modal, true),
		_action("Ulangi", func(): restart_requested.emit()),
	])


func _confirm_menu() -> void:
	_open_modal("Kembali ke Menu?", "Laga sekarang akan berakhir.")
	_focus_modal([
		_action("Lanjut Bermain", _close_modal, true),
		_action("Kembali ke Menu", func(): menu_requested.emit()),
	])


func is_compact_layout() -> bool:
	return _compact


func _fit() -> void:
	var compact := size.x / maxf(1.0, size.y) < 1.53 or get_window().size.x < 1000
	if _compact != compact:
		_compact = compact
		layout_changed.emit(compact)
	_status.position = Vector2(20, 18)
	_info.visible = not compact or _details_open
	_details.visible = compact
	_details.text = "Tutup Catatan" if _details_open else "Catatan Laga"
	_info.position = Vector2(size.x - 254, 20)
	_info.size.x = 234
	_controls.position = Vector2((size.x - _controls.get_combined_minimum_size().x) * 0.5, size.y - 59)
	_controls.size = _controls.get_combined_minimum_size()
	_replay_host.position = Vector2(size.x - 254, 70 if compact and not _details_open else 318)
	_replay_host.size.x = 234
