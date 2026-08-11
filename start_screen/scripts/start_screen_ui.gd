class_name StartScreenUI
extends RefCounted

## [역할 / C++ 대응]
## 시작 화면이 반복해서 만드는 Panel/Label/Button/Slider의 생성 규칙과 theme 설정을 캡슐화한다.
## C++로 보면 UI widget을 생성해 소유자에게 넘기는 factory/helper 클래스에 가깝다.
## RefCounted이므로 Node처럼 scene tree에 들어가지 않고 StartScreen이 참조하는 동안만 살아 있다.
##
## 호출자: KungFuTetrisStartScreen의 `_create_*()` wrapper.
## 호출 대상: Godot Control 파생 클래스와 StyleBoxFlat.

var _font: Font # 모든 Label/Button이 공유하는 폰트 리소스 포인터.
var _panel_background: Color # 일반 Button 배경에 사용할 공통 색 값.
var _border_color: Color # 일반 Button/Panel 외곽선의 공통 색 값.
var _text_color: Color # Button 기본 글자색.


## 상황: StartScreen이 공통 theme 값으로 UI factory를 만들 때 C++ 생성자처럼 호출된다.
## 순서: 네 인자를 멤버에 복사하며 노드 생성은 지연한다.
## 결과: 이후 create 함수들이 같은 시각 설정을 재사용한다.
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


## 상황: 시작 화면이 위치와 크기가 정해진 둥근 container 하나를 필요로 할 때 호출된다.
## 순서: Panel 생성/배치 → StyleBoxFlat 설정 → parent에 소유권 연결.
## 결과: scene tree에 추가된 Panel 참조를 반환한다.
func create_panel(
	parent: Control,
	rect: Rect2,
	background: Color,
	border: Color,
	radius: int
) -> Panel:
	var panel: Panel = Panel.new() # C++의 `new Panel`과 달리 parent가 수명을 소유할 node.
	panel.position = rect.position
	panel.size = rect.size

	var style: StyleBoxFlat = StyleBoxFlat.new() # panel theme override에 보관될 참조형 style.
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.08, 0.13, 0.20, 0.18)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


## 상황: 고정·동적 문구를 동일한 폰트와 색으로 배치할 때 호출된다.
## 순서: Label 생성 → 데이터/정렬/입력 정책 설정 → theme override → parent에 추가.
## 결과: 호출자가 나중에 text를 갱신할 수 있는 Label 참조를 반환한다.
func create_label(
	parent: Control,
	text_value: String,
	rect: Rect2,
	font_size: int,
	color: Color,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var label: Label = Label.new() # parent가 소유하고 호출자는 non-owning 참조로 사용하는 widget.
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


## 상황: 키보드 focus와 mouse click을 모두 받는 메뉴 버튼을 만들 때 호출된다.
## 순서: Button 기본 속성 → 글자 theme → normal/hover/pressed/focus/disabled style 등록 → add_child.
## 결과: signal 연결 전 상태의 완성된 Button을 반환한다.
func create_button(
	parent: Control,
	text_value: String,
	rect: Rect2,
	accent: Color,
	font_size: int
) -> Button:
	var button: Button = Button.new() # signal은 StartScreen이 목적에 맞는 callback을 연결한다.
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


## 상황: BGM/SFX 퍼센트를 0~100 정수 단계로 조절할 slider가 필요할 때 호출된다.
## 결과: 범위·현재값·focus를 설정하고 parent에 추가한 HSlider를 반환한다.
func create_slider(parent: Control, rect: Rect2, initial_value: float) -> HSlider:
	var slider: HSlider = HSlider.new() # UI node의 수명은 parent가 관리한다.
	slider.position = rect.position
	slider.size = rect.size
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = initial_value
	slider.focus_mode = Control.FOCUS_ALL
	parent.add_child(slider)
	return slider


## 상황: create_button이 상태별 StyleBoxFlat을 같은 규칙으로 조립할 때 호출된다.
## 순서: 색/테두리/모서리/좌우 여백을 값 객체에 기록한다.
## 결과: Button theme override가 소유할 새 StyleBoxFlat을 반환한다.
func _button_style(
	background: Color,
	border: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new() # 호출마다 독립된 mutable style 객체.
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style
