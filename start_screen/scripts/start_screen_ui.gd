class_name StartScreenUI
extends RefCounted

var _font: Font
var _panel_background: Color
var _border_color: Color
var _text_color: Color


func _init(
	font: Font,
	panel_background: Color,
	border_color: Color,
	text_color: Color
) -> void:
	_font = font
	_panel_background = panel_background
	_border_color = border_color
	_text_color = text_color


func create_panel(
	parent: Control,
	rect: Rect2,
	background: Color,
	border: Color,
	radius: int
) -> Panel:
	var panel: Panel = Panel.new()
	panel.position = rect.position
	panel.size = rect.size

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.08, 0.13, 0.20, 0.18)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func create_label(
	parent: Control,
	text_value: String,
	rect: Rect2,
	font_size: int,
	color: Color,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var label: Label = Label.new()
	label.name = text_value if not text_value.is_empty() else "DynamicLabel"
	label.text = text_value
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func create_button(
	parent: Control,
	text_value: String,
	rect: Rect2,
	accent: Color,
	font_size: int
) -> Button:
	var button: Button = Button.new()
	button.name = text_value if not text_value.is_empty() else "KeyButton"
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", _text_color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)

	button.add_theme_stylebox_override(
		"normal",
		_button_style(_panel_background, _border_color, 7, 1)
	)
	button.add_theme_stylebox_override(
		"hover",
		_button_style(accent.darkened(0.68), accent, 7, 2)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_button_style(accent.darkened(0.52), accent.lightened(0.15), 7, 2)
	)
	button.add_theme_stylebox_override(
		"focus",
		_button_style(accent.darkened(0.72), accent, 7, 3)
	)
	button.add_theme_stylebox_override(
		"disabled",
		_button_style(Color("#e2e7ee"), Color("#b2bcc9"), 7, 1)
	)
	parent.add_child(button)
	return button


func create_slider(parent: Control, rect: Rect2, initial_value: float) -> HSlider:
	var slider: HSlider = HSlider.new()
	slider.position = rect.position
	slider.size = rect.size
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = initial_value
	slider.focus_mode = Control.FOCUS_ALL
	parent.add_child(slider)
	return slider


func _button_style(
	background: Color,
	border: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style
