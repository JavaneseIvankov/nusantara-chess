class_name MainMenu
extends Control

signal start_game_requested(solo: bool, faction: int, difficulty: int)
signal quit_game_requested

const BOARD_ART := preload("res://assets/ui/art/papan-ukir.png")
const TORCH_ART := preload("res://assets/ui/art/obor.png")
const DUEL_ART := preload("res://assets/ui/art/duel.png")
const HEIRLOOM_ART := preload("res://assets/ui/art/pusaka.png")

var _layout: CenterContainer
var _home: VBoxContainer
var _setup: VBoxContainer
var _guide: VBoxContainer
var _solo_button: Button
var _start_button: Button
var _guide_button: Button
var _faction_art: TextureRect
var _faction_options: OptionButton
var _difficulty_options: OptionButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.36, 0.68, 1.0])
	gradient.colors = PackedColorArray([Color("#171a1bff"), Color("#171a1bf2"), Color("#171a1b46"), Color("#171a1b12")])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	shade.texture = texture
	add_child(shade)

	_layout = CenterContainer.new()
	add_child(_layout)
	_layout.set_anchor(SIDE_BOTTOM, 1.0)
	_home = _build_home(_layout)
	_setup = _build_setup(_layout)
	_guide = _build_guide(_layout)
	resized.connect(_fit)
	_fit()
	show_home()


func show_home() -> void:
	show()
	_show_view(_home, _solo_button)


func _build_home(parent: Control) -> VBoxContainer:
	var page := _column(parent, 12)
	var kicker := HBoxContainer.new()
	kicker.add_child(TakhtaTheme.picture(TORCH_ART, Vector2(19, 32)))
	kicker.add_child(TakhtaTheme.label("TAKHTA DELAPAN PETAK", 17, TakhtaTheme.BRASS))
	page.add_child(kicker)
	var title := TakhtaTheme.label("Nusantara\nChess", 72, TakhtaTheme.IVORY, true)
	title.add_theme_constant_override("line_spacing", -17)
	page.add_child(title)
	_add_motif(page)
	_solo_button = TakhtaTheme.button("Lawan Bot", func(): _show_view(_setup, _faction_options), true)
	_solo_button.name = "VersusBot"
	page.add_child(_solo_button)
	var local := TakhtaTheme.button("Dua Pemain Lokal", func(): _start(false))
	local.name = "LocalGame"
	page.add_child(local)
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 10)
	page.add_child(secondary)
	_guide_button = TakhtaTheme.button("Panduan", func(): _show_view(_guide, _guide.get_node("GuideBack")))
	var quit := TakhtaTheme.button("Keluar", func(): quit_game_requested.emit())
	for button in [_guide_button, quit]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		secondary.add_child(button)
	TakhtaTheme.link_focus([_solo_button, local, _guide_button, quit])
	return page


func _build_setup(parent: Control) -> VBoxContainer:
	var page := _column(parent, 10)
	page.add_child(TakhtaTheme.label("Lawan Bot", 48, TakhtaTheme.IVORY, true))
	var description := TakhtaTheme.label("Pilih faksi dan kekuatan lawan.", 19, TakhtaTheme.MUTED)
	page.add_child(description)
	_add_motif(page)
	var faction_row := HBoxContainer.new()
	faction_row.add_theme_constant_override("separation", 10)
	page.add_child(faction_row)
	_faction_art = TakhtaTheme.picture(TakhtaTheme.GOLD_ART, Vector2(86, 86))
	faction_row.add_child(_faction_art)
	var side := _column(faction_row, 4)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_child(TakhtaTheme.label("Faksi Anda", 17, TakhtaTheme.MUTED))
	_faction_options = OptionButton.new()
	_faction_options.name = "Faction"
	_faction_options.custom_minimum_size.y = 44
	_faction_options.add_item("Emas · jalan pertama")
	_faction_options.add_item("Obsidian · jalan kedua")
	_faction_options.item_selected.connect(func(index: int): _faction_art.texture = TakhtaTheme.faction_art(index))
	side.add_child(_faction_options)
	page.add_child(TakhtaTheme.label("Tingkat kesulitan", 17, TakhtaTheme.MUTED))
	_difficulty_options = OptionButton.new()
	_difficulty_options.name = "Difficulty"
	_difficulty_options.custom_minimum_size.y = 44
	for preset in StockfishClient.PRESETS:
		_difficulty_options.add_item(preset.label)
	page.add_child(_difficulty_options)
	_start_button = TakhtaTheme.button("Mulai Laga", func(): _start(true), true)
	_start_button.name = "StartMatch"
	page.add_child(_start_button)
	var back := TakhtaTheme.button("Kembali", show_home)
	page.add_child(back)
	TakhtaTheme.link_focus([_faction_options, _difficulty_options, _start_button, back])
	return page


func _build_guide(parent: Control) -> VBoxContainer:
	var page := _column(parent, 12)
	page.add_child(TakhtaTheme.label("Panduan", 48, TakhtaTheme.IVORY, true))
	_add_motif(page)
	var visuals := HBoxContainer.new()
	visuals.add_child(TakhtaTheme.picture(BOARD_ART, Vector2(110, 90)))
	visuals.add_child(TakhtaTheme.picture(HEIRLOOM_ART, Vector2(65, 90)))
	visuals.add_child(TakhtaTheme.picture(DUEL_ART, Vector2(113, 90)))
	page.add_child(visuals)
	for text in [
		"Klik bidak, lalu pilih petak yang ditandai.",
		"Klik kanan dan geser untuk memutar kamera.",
		"Gulir untuk mendekat atau menjauh.",
		"Tekan Tab untuk berpindah kontrol menu.",
	]:
		var line := TakhtaTheme.label(text, 19)
		line.custom_minimum_size.x = 320
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(line)
	var back := TakhtaTheme.button("Kembali", show_home)
	back.name = "GuideBack"
	page.add_child(back)
	return page


func _column(parent: Control, gap: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	parent.add_child(column)
	return column


func _add_motif(page: VBoxContainer) -> void:
	var ornament := TakhtaTheme.label("━━ ◇ ━━━━━━━━━━━━━", 17, TakhtaTheme.BRASS)
	page.add_child(ornament)


func _fit() -> void:
	var compact := size.x / maxf(size.y, 1.0) < 1.53
	var margin := 38 if compact else 58
	var width := 390 if compact else 480
	_layout.offset_left = margin
	_layout.offset_right = margin + minf(width, size.x - 2 * margin)
	_layout.offset_top = 12
	_layout.offset_bottom = -12


func _show_view(page: VBoxContainer, first: Control) -> void:
	_home.visible = page == _home
	_setup.visible = page == _setup
	_guide.visible = page == _guide
	first.grab_focus()


func _start(solo: bool) -> void:
	hide()
	start_game_requested.emit(solo, _faction_options.selected, _difficulty_options.selected)
