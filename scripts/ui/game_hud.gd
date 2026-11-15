class_name GameHUD
extends Control

signal camera_reset_requested
signal restart_requested
signal forfeit_requested

var turn_label: Label
var game_over_panel: PanelContainer
var winner_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE # Agar klik mouse tetap tembus ke papan 3D
	
	_build_top_left_header()
	_build_bottom_right_controls()
	_build_game_over_modal()

func _create_nusantara_panel_style(border_color: Color = Color(0.76, 0.58, 0.24)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.05, 0.85) # Kayu gelap semi-transparan
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18
	style.content_margin_right = 18
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
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.52))
	vbox.add_child(title)
	
	var sep := HSeparator.new()
	sep.modulate = Color(0.76, 0.58, 0.24, 0.6)
	vbox.add_child(sep)
	
	turn_label = Label.new()
	turn_label.text = "GILIRAN: FAKSI EMAS"
	turn_label.add_theme_font_size_override("font_size", 15)
	turn_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	vbox.add_child(turn_label)

# 2. Tombol Kontrol (Pojok Kanan Bawah)
func _build_bottom_right_controls() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
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
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75))
	btn.add_theme_stylebox_override("normal", _create_button_style(false))
	btn.add_theme_stylebox_override("hover", _create_button_style(true))
	btn.add_theme_stylebox_override("pressed", _create_button_style(true))
	return btn

# 3. Panel Pengumuman Pemenang (Tengah Layar)
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

func show_winner(winner_faction: ChessPiece.Faction, reason: String = "SKAKMAT!") -> void:
	if winner_faction == ChessPiece.Faction.GOLD:
		winner_label.text = "%s\nPEMENANG: FAKSI EMAS" % reason
	else:
		winner_label.text = "%s\nPEMENANG: FAKSI OBSIDIAN" % reason
	game_over_panel.visible = true
