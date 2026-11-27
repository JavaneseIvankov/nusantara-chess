class_name TakhtaTheme
extends RefCounted

const DISPLAY_FONT := preload("res://assets/ui/fonts/Asul-Bold.ttf")
const BODY_FONT := preload("res://assets/ui/fonts/SourceSans3-Regular.ttf")
const CONTROL_FONT := preload("res://assets/ui/fonts/SourceSans3-Semibold.ttf")

const STONE := Color("#171a1b")
const SURFACE := Color("#252726")
const IVORY := Color("#f2e5c9")
const MUTED := Color("#c6b99f")
const BRASS := Color("#d4ab63")
const GOLD := Color("#e3bb72")
const OBSIDIAN := Color("#afc5d6")
const ALERT := Color("#ffaa96")
const EDGE := Color("#6b5a3f")
const GOLD_ART := preload("res://assets/ui/art/mahkota.png")
const OBSIDIAN_ART := preload("res://assets/ui/art/candi.png")


static func make() -> Theme:
	var shared := Theme.new()
	shared.default_font = BODY_FONT
	shared.default_font_size = 19
	shared.set_color("font_color", "Label", IVORY)
	shared.set_color("default_color", "RichTextLabel", IVORY)
	shared.set_stylebox("panel", "PanelContainer", panel(SURFACE, EDGE, 14))
	for type in ["Button", "OptionButton"]:
		shared.set_font("font", type, CONTROL_FONT)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var foreground := MUTED if state == "disabled" else IVORY
			shared.set_color("font_color" if state == "normal" else "font_%s_color" % state, type, foreground)
			var background := SURFACE if state == "normal" else Color("#343632")
			shared.set_stylebox(state, type, panel(background, EDGE if state != "hover" else BRASS, 10, 5))
		shared.set_color("font_focus_color", type, IVORY)
		shared.set_stylebox("focus", type, focus_ring())
	shared.set_font("font", "PopupMenu", CONTROL_FONT)
	shared.set_stylebox("panel", "PopupMenu", panel(SURFACE, EDGE, 8))
	shared.set_stylebox("hover", "PopupMenu", panel(Color("#38372e"), BRASS, 6))
	shared.set_color("font_color", "PopupMenu", IVORY)
	shared.set_color("font_hover_color", "PopupMenu", IVORY)
	return shared


static func panel(background: Color, border: Color, horizontal: int, vertical: int = -1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin(SIDE_LEFT, horizontal)
	style.set_content_margin(SIDE_RIGHT, horizontal)
	style.set_content_margin(SIDE_TOP, horizontal if vertical < 0 else vertical)
	style.set_content_margin(SIDE_BOTTOM, horizontal if vertical < 0 else vertical)
	return style


static func focus_ring() -> StyleBoxFlat:
	var style := panel(Color.TRANSPARENT, BRASS, 0)
	style.set_border_width_all(2)
	style.set_expand_margin_all(2.0)
	style.draw_center = false
	return style


static func label(value: String, size: int, tint: Color = IVORY, title: bool = false) -> Label:
	var item := Label.new()
	item.text = value
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", tint)
	if title:
		item.add_theme_font_override("font", DISPLAY_FONT)
	return item


static func button(value: String, callback: Callable, primary: bool = false) -> Button:
	var item := Button.new()
	item.text = value
	item.custom_minimum_size.y = 44
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		for state in ["normal", "hover", "pressed"]:
			var fill := BRASS if state == "normal" else GOLD
			item.add_theme_stylebox_override(state, panel(fill, fill, 16, 6))
		for property in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			item.add_theme_color_override(property, STONE)
	item.pressed.connect(func():
		AudioManager.play_ui_click()
		callback.call()
	)
	return item


static func picture(texture: Texture2D, minimum: Vector2) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.custom_minimum_size = minimum
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


static func faction_name(faction: int) -> String:
	return "Emas" if faction == ChessPiece.Faction.GOLD else "Obsidian"


static func faction_color(faction: int) -> Color:
	return GOLD if faction == ChessPiece.Faction.GOLD else OBSIDIAN


static func faction_art(faction: int) -> Texture2D:
	return GOLD_ART if faction == ChessPiece.Faction.GOLD else OBSIDIAN_ART


static func link_focus(items: Array[Control]) -> void:
	for i in items.size():
		items[i].focus_next = items[i].get_path_to(items[(i + 1) % items.size()])
		items[i].focus_previous = items[i].get_path_to(items[posmod(i - 1, items.size())])
