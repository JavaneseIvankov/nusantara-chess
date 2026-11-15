class_name GameHUD
extends Control

signal camera_reset_requested
signal auto_flip_toggled(enabled: bool)
signal camera_top_view_requested
signal restart_requested
signal forfeit_requested
signal promotion_piece_selected(chosen_type: ChessPiece.PieceType)


var turn_label: Label
var game_over_panel: PanelContainer
var winner_label: Label
var promotion_panel: PanelContainer

# UI Tawanan Materi (Pojok Kiri Bawah)
var gold_captured_label: Label
var obsidian_captured_label: Label
var gold_captures: Array[ChessPiece.PieceType] = []
var obsidian_captures: Array[ChessPiece.PieceType] = []

# UI Riwayat Langkah (Pojok Kanan Atas)
var history_scroll: ScrollContainer
var history_list_label: RichTextLabel
var move_pairs: Array[String] = []
var pending_gold_move: String = ""

const PIECE_VALUES := {
	ChessPiece.PieceType.PAWN: 1,
	ChessPiece.PieceType.KNIGHT: 3,
	ChessPiece.PieceType.BISHOP: 3,
	ChessPiece.PieceType.ROOK: 5,
	ChessPiece.PieceType.QUEEN: 9,
	ChessPiece.PieceType.KING: 0
}

const PIECE_ICONS := {
	ChessPiece.PieceType.PAWN: "♟",
	ChessPiece.PieceType.KNIGHT: "♞",
	ChessPiece.PieceType.BISHOP: "♝",
	ChessPiece.PieceType.ROOK: "♜",
	ChessPiece.PieceType.QUEEN: "♛",
	ChessPiece.PieceType.KING: "♚"
}

var auto_flip_enabled: bool = true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_build_top_left_header()
	_build_top_right_history()
	_build_bottom_left_captured_tray()
	_build_bottom_right_controls()
	_build_game_over_modal()

func _create_nusantara_panel_style(border_color: Color = Color(0.76, 0.58, 0.24)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.05, 0.86)
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _create_button_style(is_hover: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.16, 0.10, 0.95) if is_hover else Color(0.11, 0.08, 0.06, 0.90)
	style.border_color = Color(0.95, 0.78, 0.35) if is_hover else Color(0.72, 0.54, 0.22)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

# 1. Header Judul & Indikator Giliran (Pojok Kiri Atas)
func _build_top_left_header() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 28)
	panel.add_theme_stylebox_override("panel", _create_nusantara_panel_style())
	add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	var title := Label.new()
	title.text = "Nusantara: Takhta Delapan Petak"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.52))
	vbox.add_child(title)
	
	var sep := HSeparator.new()
	sep.modulate = Color(0.76, 0.58, 0.24, 0.6)
	vbox.add_child(sep)
	
	turn_label = Label.new()
	turn_label.text = "GILIRAN: FAKSI EMAS"
	turn_label.add_theme_font_size_override("font_size", 14)
	turn_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	vbox.add_child(turn_label)

# 2. Panel Riwayat Langkah (Pojok Kanan Atas)
func _build_top_right_history() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 28)
	add_child(margin)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(235, 165)
	panel.add_theme_stylebox_override("panel", _create_nusantara_panel_style())
	margin.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	var heading := Label.new()
	heading.text = "RIWAYAT LANGKAH"
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(0.96, 0.84, 0.52))
	vbox.add_child(heading)
	
	var sep := HSeparator.new()
	sep.modulate = Color(0.76, 0.58, 0.24, 0.5)
	vbox.add_child(sep)
	
	history_scroll = ScrollContainer.new()
	history_scroll.custom_minimum_size = Vector2(200, 110)
	history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(history_scroll)
	
	history_list_label = RichTextLabel.new()
	history_list_label.bbcode_enabled = true
	history_list_label.fit_content = true
	history_list_label.custom_minimum_size = Vector2(195, 0)
	history_list_label.add_theme_font_size_override("normal_font_size", 13)
	history_list_label.text = "[color=#9c8e78]Belum ada langkah...[/color]"
	history_scroll.add_child(history_list_label)

# 3. Tray Bidak yang Tertawan (Pojok Kiri Bawah)
func _build_bottom_left_captured_tray() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 96)
	panel.add_theme_stylebox_override("panel", _create_nusantara_panel_style())
	margin.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	var heading := Label.new()
	heading.text = "TAWANAN PERANG & SKOR MATERI"
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", Color(0.96, 0.84, 0.52))
	vbox.add_child(heading)
	
	gold_captured_label = Label.new()
	gold_captured_label.text = "Emas: -"
	gold_captured_label.add_theme_font_size_override("font_size", 15)
	gold_captured_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))
	vbox.add_child(gold_captured_label)
	
	obsidian_captured_label = Label.new()
	obsidian_captured_label.text = "Obsidian: -"
	obsidian_captured_label.add_theme_font_size_override("font_size", 15)
	obsidian_captured_label.add_theme_color_override("font_color", Color(0.75, 0.84, 0.98))
	vbox.add_child(obsidian_captured_label)

# 4. Tombol Kontrol (Pojok Kanan Bawah)
func _build_bottom_right_controls() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	var btn_auto_flip := _make_styled_button("KAMERA AUTO: ON")
	btn_auto_flip.pressed.connect(func():
		auto_flip_enabled = not auto_flip_enabled
		btn_auto_flip.text = "KAMERA AUTO: ON" if auto_flip_enabled else "KAMERA AUTO: OFF"
		auto_flip_toggled.emit(auto_flip_enabled)
	)
	vbox.add_child(btn_auto_flip)
	
	var btn_top := _make_styled_button("SUDUT ATAS")
	btn_top.pressed.connect(func(): camera_top_view_requested.emit())
	vbox.add_child(btn_top)
	
	var btn_camera := _make_styled_button("KAMERA (RESET)")
	btn_camera.pressed.connect(func(): camera_reset_requested.emit())
	vbox.add_child(btn_camera)
	
	var btn_restart := _make_styled_button("ULANGI LAGA")
	btn_restart.pressed.connect(func(): restart_requested.emit())
	vbox.add_child(btn_restart)
	
	var btn_forfeit := _make_styled_button("MENYERAH")
	btn_forfeit.pressed.connect(func(): forfeit_requested.emit())
	vbox.add_child(btn_forfeit)

func _make_styled_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(185, 42)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.8))
	btn.add_theme_stylebox_override("normal", _create_button_style(false))
	btn.add_theme_stylebox_override("hover", _create_button_style(true))
	btn.add_theme_stylebox_override("pressed", _create_button_style(true))
	btn.pressed.connect(func(): AudioManager.play_ui_click())
	return btn

# 5. Panel Pengumuman Pemenang (Tengah Layar)
func _build_game_over_modal() -> void:
	game_over_panel = PanelContainer.new()
	game_over_panel.visible = false
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	game_over_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	game_over_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	game_over_panel.add_theme_stylebox_override("panel", _create_nusantara_panel_style(Color(1.0, 0.82, 0.3)))
	add_child(game_over_panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	game_over_panel.add_child(vbox)
	
	var heading := Label.new()
	heading.text = "TAKHTA TELAH DIREBUT"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color(0.96, 0.84, 0.52))
	vbox.add_child(heading)
	
	winner_label = Label.new()
	winner_label.text = "PEMENANG: FAKSI EMAS"
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", 18)
	winner_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	vbox.add_child(winner_label)
	
	var btn_play_again := _make_styled_button("MAIN LAGI")
	btn_play_again.pressed.connect(func(): restart_requested.emit())
	vbox.add_child(btn_play_again)

# ==============================================================================
# PEMBARUAN DATA DINAMIS HUD
# ==============================================================================
func update_turn(faction: ChessPiece.Faction) -> void:
	if faction == ChessPiece.Faction.GOLD:
		turn_label.text = "GILIRAN: FAKSI EMAS"
		turn_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	else:
		turn_label.text = "GILIRAN: FAKSI OBSIDIAN"
		turn_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.96))

func set_check_warning(is_in_check: bool) -> void:
	if is_in_check:
		turn_label.text += "  [⚠ RAJA TERANCAM SKAK!]"
		turn_label.add_theme_color_override("font_color", Color(1.0, 0.32, 0.25))

func add_captured_piece(capturer_faction: ChessPiece.Faction, captured_type: ChessPiece.PieceType) -> void:
	if capturer_faction == ChessPiece.Faction.GOLD:
		gold_captures.append(captured_type)
		gold_captures.sort_custom(func(a, b): return PIECE_VALUES[a] > PIECE_VALUES[b])
	else:
		obsidian_captures.append(captured_type)
		obsidian_captures.sort_custom(func(a, b): return PIECE_VALUES[a] > PIECE_VALUES[b])
	
	_refresh_captured_display()

func _refresh_captured_display() -> void:
	var gold_score := 0
	var gold_icons := ""
	for t in gold_captures:
		gold_score += PIECE_VALUES[t]
		gold_icons += PIECE_ICONS[t] + " "
	
	var obs_score := 0
	var obs_icons := ""
	for t in obsidian_captures:
		obs_score += PIECE_VALUES[t]
		obs_icons += PIECE_ICONS[t] + " "
	
	var diff := gold_score - obs_score
	var gold_adv := " (+%d)" % diff if diff > 0 else ""
	var obs_adv := " (+%d)" % (-diff) if diff < 0 else ""
	
	gold_captured_label.text = "Emas: %s%s" % [gold_icons if gold_icons != "" else "-", gold_adv]
	obsidian_captured_label.text = "Obsidian: %s%s" % [obs_icons if obs_icons != "" else "-", obs_adv]

func add_move_record(faction: ChessPiece.Faction, notation: String) -> void:
	if faction == ChessPiece.Faction.GOLD:
		pending_gold_move = notation
		var turn_num := move_pairs.size() + 1
		var preview := "[color=#d4af37]%d.[/color] [color=#ffe082]%s[/color]" % [turn_num, pending_gold_move]
		var lines := move_pairs.duplicate()
		lines.append(preview)
		history_list_label.text = "\n".join(lines)
	else:
		var turn_num := move_pairs.size() + 1
		var full_line := "[color=#d4af37]%d.[/color] [color=#ffe082]%s[/color]   [color=#b8cce8]%s[/color]" % [turn_num, pending_gold_move, notation]
		move_pairs.append(full_line)
		pending_gold_move = ""
		history_list_label.text = "\n".join(move_pairs)
	
	await get_tree().process_frame
	history_scroll.scroll_vertical = int(history_scroll.get_v_scroll_bar().max_value)

func show_winner(winner_faction: ChessPiece.Faction, reason: String = "SKAKMAT!") -> void:
	if winner_faction == ChessPiece.Faction.GOLD:
		winner_label.text = "%s\nPEMENANG: FAKSI EMAS" % reason
	else:
		winner_label.text = "%s\nPEMENANG: FAKSI OBSIDIAN" % reason
	game_over_panel.visible = true

# 6. Modal Pilihan Promosi Pion (Tengah Layar)
func _build_promotion_modal() -> void:
	promotion_panel = PanelContainer.new()
	promotion_panel.visible = false
	promotion_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	promotion_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	promotion_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	promotion_panel.add_theme_stylebox_override("panel", _create_nusantara_panel_style(Color(1.0, 0.82, 0.3)))
	add_child(promotion_panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	promotion_panel.add_child(vbox)
	
	var heading := Label.new()
	heading.text = "KENAIKAN PANGKAT PRAJURIT"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color(0.96, 0.84, 0.52))
	vbox.add_child(heading)
	
	var sub := Label.new()
	sub.text = "Pilih gelar baru untuk pion yang menembus garis musuh:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	vbox.add_child(sub)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	var options := [
		{"label": "♕ MENTERI", "type": ChessPiece.PieceType.QUEEN},
		{"label": "♖ BENTENG", "type": ChessPiece.PieceType.ROOK},
		{"label": "♗ GAJAH", "type": ChessPiece.PieceType.BISHOP},
		{"label": "♘ KUDA", "type": ChessPiece.PieceType.KNIGHT}
	]
	
	for opt in options:
		var btn := _make_styled_button(opt["label"])
		btn.custom_minimum_size = Vector2(130, 46)
		var p_type: ChessPiece.PieceType = opt["type"]
		btn.pressed.connect(func():
			promotion_panel.visible = false
			promotion_piece_selected.emit(p_type)
		)
		hbox.add_child(btn)

func show_promotion_choices() -> void:
	promotion_panel.visible = true
