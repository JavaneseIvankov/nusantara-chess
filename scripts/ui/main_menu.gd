class_name MainMenu
extends Control

signal start_game_requested
signal quit_game_requested

var menu_container: CenterContainer
var guide_panel: PanelContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_menu_ui()
	_build_guide_modal()

func _create_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.04, 0.88)
	style.border_color = Color(0.85, 0.66, 0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 32
	style.content_margin_bottom = 32
	return style

func _create_button_style(is_hover: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.26, 0.19, 0.11, 0.96) if is_hover else Color(0.12, 0.09, 0.06, 0.92)
	style.border_color = Color(1.0, 0.84, 0.40) if is_hover else Color(0.76, 0.58, 0.24)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _build_menu_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.02, 0.02, 0.38)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	
	menu_container = CenterContainer.new()
	menu_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_container)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	menu_container.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	var subtitle := Label.new()
	subtitle.text = "STRATEGI TAKTIS NUSANTARA 3D"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
	vbox.add_child(subtitle)
	
	var title := Label.new()
	title.text = "NUSANTARA:\nTAKHTA DELAPAN PETAK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.48))
	vbox.add_child(title)
	
	var sep := HSeparator.new()
	sep.modulate = Color(0.85, 0.66, 0.28, 0.6)
	vbox.add_child(sep)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)
	
	var btn_start := _make_button("MULAI LAGA")
	btn_start.pressed.connect(_on_start_pressed)
	vbox.add_child(btn_start)
	
	var btn_guide := _make_button("PANDUAN KONTROL")
	btn_guide.pressed.connect(func(): guide_panel.visible = true)
	vbox.add_child(btn_guide)
	
	var btn_quit := _make_button("KELUAR")
	btn_quit.pressed.connect(func(): quit_game_requested.emit())
	vbox.add_child(btn_quit)

func _build_guide_modal() -> void:
	guide_panel = PanelContainer.new()
	guide_panel.visible = false
	guide_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	guide_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	guide_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	guide_panel.custom_minimum_size = Vector2(460, 0)
	guide_panel.add_theme_stylebox_override("panel", _create_panel_style())
	add_child(guide_panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	guide_panel.add_child(vbox)
	
	var heading := Label.new()
	heading.text = "PANDUAN KONTROL & ATURAN"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color(0.98, 0.85, 0.48))
	vbox.add_child(heading)
	
	var body := Label.new()
	body.text = "• Klik Kiri Bidak: Pilih bidak & lihat petak langkah sah.\n" + \
				"• Klik Petak Tujuan: Gerakkan bidak atau tawan bidak lawan.\n" + \
				"• Klik Kanan + Geser Mouse: Putar kamera orbit 360°.\n" + \
				"• Scroll Wheel Mouse: Perbesar / perkecil jarak pandang.\n" + \
				"• Kamera Auto: Memutar sudut pandang otomatis tiap ganti giliran."
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
	vbox.add_child(body)
	
	var btn_close := _make_button("MENGERTI")
	btn_close.pressed.connect(func(): guide_panel.visible = false)
	vbox.add_child(btn_close)

func _make_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(260, 46)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color(0.96, 0.90, 0.76))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.78))
	btn.add_theme_stylebox_override("normal", _create_button_style(false))
	btn.add_theme_stylebox_override("hover", _create_button_style(true))
	btn.add_theme_stylebox_override("pressed", _create_button_style(true))
	btn.pressed.connect(func(): AudioManager.play_ui_click())
	return btn

func _on_start_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	await tween.finished
	visible = false
	start_game_requested.emit()
