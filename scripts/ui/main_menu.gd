class_name MainMenu
extends Control

signal start_game_requested
signal quit_game_requested

var menu_container: CenterContainer
var guide_panel: PanelContainer
var _starting := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_menu_ui()
	_build_guide_modal()
	resized.connect(_fit_menu)
	_fit_menu()

func _create_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#14191bea")
	style.border_color = Color("#9d794c")
	style.set_border_width_all(1)
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
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _build_menu_ui() -> void:
	var backdrop := TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	gradient.colors = PackedColorArray([Color("#111719e9"), Color("#141a2077"), Color("#161b201a")])
	var shading := GradientTexture2D.new()
	shading.gradient = gradient
	backdrop.texture = shading
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	
	menu_container = CenterContainer.new()
	menu_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_container)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(348, 0)
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	menu_container.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	var subtitle := Label.new()
	subtitle.text = "TAKHTA DELAPAN PETAK"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
	vbox.add_child(subtitle)
	
	var title := Label.new()
	title.text = "Nusantara\nChess"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Georgia", "Noto Serif", "Times New Roman"])
	title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 43)
	title.add_theme_constant_override("line_spacing", -5)
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
	btn_guide.pressed.connect(func():
		menu_container.hide()
		guide_panel.show()
	)
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
	btn_close.pressed.connect(func():
		guide_panel.hide()
		menu_container.show()
	)
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

func _fit_menu() -> void:
	var right_edge := 0.47 if size.x / maxf(size.y, 1.0) >= 1.55 else 1.0
	menu_container.set_anchor_and_offset(SIDE_RIGHT, right_edge, 0.0)
	menu_container.set_anchor_and_offset(SIDE_BOTTOM, 1.0, 0.0)


func _on_start_pressed() -> void:
	if _starting:
		return
	_starting = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	await tween.finished
	visible = false
	start_game_requested.emit()
