class_name KungFuTetrisStartScreen
extends Control

signal game_loaded(game_root: Node)
signal exit_requested

const GAME_SCENE_DEFAULT: String = "res://scenes/main.tscn"
const PORTRAIT: Texture2D = preload("res://assets/sprites/player_animations.png")
const PORTRAIT_SOURCE: Rect2 = Rect2(45.0, 55.0, 165.0, 270.0)
const BLOCK_TEXTURE: Texture2D = preload("res://assets/sprites/block_sprites.png")
const CYAN_BLOCK_SOURCE: Rect2 = Rect2(80.0, 255.0, 210.0, 215.0)
const ORANGE_BLOCK_SOURCE: Rect2 = Rect2(1745.0, 255.0, 210.0, 215.0)
const TUTORIAL_CANVAS_SCRIPT: Script = preload(
	"res://start_screen/scripts/tutorial_canvas.gd"
)
const UI_SCRIPT: Script = preload("res://start_screen/scripts/start_screen_ui.gd")
const SFX_SELECT: AudioStream = preload("res://assets/sfx/08_select.wav")

const BACKGROUND: Color = Color("#f7f8fb")
const PANEL: Color = Color("#ffffff")
const PANEL_DARK: Color = Color("#eef2f7")
const BORDER: Color = Color("#8390a3")
const TEXT: Color = Color("#152033")
const MUTED: Color = Color("#344158")
const CYAN: Color = Color("#2c8fd6")
const ORANGE: Color = Color("#e47719")
const PURPLE: Color = Color("#6f57c9")
const DANGER: Color = Color("#d9485f")

enum Screen {
	MAIN,
	TUTORIAL,
	OPTIONS,
	KEY_CUSTOM,
	VOLUME,
	GAME,
}

@export_file("*.tscn") var game_scene_path: String = GAME_SCENE_DEFAULT
@export var settings_file_path: String = StartScreenSettings.DEFAULT_SETTINGS_PATH
@export var suppress_quit_for_tests: bool = false

var settings: StartScreenSettings
var current_screen: Screen = Screen.MAIN
var tutorial_page: int = 0

var _font: SystemFont
var _ui: RefCounted
var _screens: Dictionary = {}
var _main_buttons: Array[Button] = []
var _options_first_button: Button
var _key_buttons: Dictionary = {}
var _key_status: Label
var _tutorial_canvas: StartScreenTutorialCanvas
var _tutorial_counter: Label
var _tutorial_prev_button: Button
var _tutorial_next_button: Button
var _music_value_label: Label
var _sfx_value_label: Label
var _game_host: Control
var _game_instance: Node
var _select_sfx_player: AudioStreamPlayer
var _select_sfx_timer: Timer
var _skip_initial_select_sfx: bool = true

var _capture_overlay: Control
var _capture_label: Label
var _capture_action: StringName = &""
var _capture_slot: int = -1

var _message_overlay: Control
var _message_label: Label


func _ready() -> void:
	set_process_unhandled_key_input(true)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI"])
	_ui = UI_SCRIPT.new(_font, PANEL_DARK, BORDER, TEXT)

	settings = StartScreenSettings.new(settings_file_path)
	settings.name = "StartScreenSettings"
	settings.settings_error.connect(_show_message)
	settings.bindings_changed.connect(_refresh_key_buttons)
	add_child(settings)
	_select_sfx_player = AudioStreamPlayer.new()
	_select_sfx_player.bus = &"SFX"
	_select_sfx_player.volume_db = -20.0
	add_child(_select_sfx_player)
	_select_sfx_timer = Timer.new()
	_select_sfx_timer.one_shot = true
	_select_sfx_timer.wait_time = 0.06
	_select_sfx_timer.timeout.connect(_select_sfx_player.stop)
	add_child(_select_sfx_timer)

	_build_interface()
	_refresh_key_buttons()
	show_main_menu()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	for x_value: int in range(0, int(size.x) + 1, 48):
		draw_line(
			Vector2(float(x_value), 0.0),
			Vector2(float(x_value), size.y),
			Color(0.52, 0.56, 0.64, 0.14),
			1.0
		)
	for y_value: int in range(0, int(size.y) + 1, 48):
		draw_line(
			Vector2(0.0, float(y_value)),
			Vector2(size.x, float(y_value)),
			Color(0.52, 0.56, 0.64, 0.14),
			1.0
		)
	_draw_decorative_blocks(Vector2(34.0, 42.0), CYAN, 0.22)
	_draw_decorative_blocks(Vector2(size.x - 130.0, size.y - 130.0), ORANGE, 0.18)


func show_main_menu() -> void:
	_show_screen(Screen.MAIN)


func show_tutorial() -> void:
	tutorial_page = 0
	_refresh_tutorial()
	_show_screen(Screen.TUTORIAL)


func show_options() -> void:
	_show_screen(Screen.OPTIONS)


func show_key_custom() -> void:
	_refresh_key_buttons()
	_show_screen(Screen.KEY_CUSTOM)


func show_volume() -> void:
	_show_screen(Screen.VOLUME)


func next_tutorial_page() -> void:
	tutorial_page = mini(tutorial_page + 1, 3)
	_refresh_tutorial()


func previous_tutorial_page() -> void:
	tutorial_page = maxi(tutorial_page - 1, 0)
	_refresh_tutorial()


func start_game() -> bool:
	if _game_instance != null and is_instance_valid(_game_instance):
		return true
	if not ResourceLoader.exists(game_scene_path, "PackedScene"):
		_show_message("게임 장면을 찾을 수 없습니다.\n%s" % game_scene_path)
		return false

	var game_resource: Resource = load(game_scene_path)
	if not game_resource is PackedScene:
		_show_message("게임 장면을 불러올 수 없습니다.\n%s" % game_scene_path)
		return false

	_game_instance = (game_resource as PackedScene).instantiate()
	_game_instance.name = "LoadedGame"
	_game_host.add_child(_game_instance)
	_show_screen(Screen.GAME)
	settings.apply_bindings.call_deferred()
	game_loaded.emit(_game_instance)
	return true


func request_exit() -> void:
	exit_requested.emit()
	if not suppress_quit_for_tests:
		get_tree().quit()


func begin_key_capture(action_name: StringName, slot_index: int) -> void:
	_capture_action = action_name
	_capture_slot = slot_index
	_capture_label.text = (
		"%s의 %s 키를 누르세요."
		% [
			settings.get_action_label(action_name),
			"주" if slot_index == 0 else "보조",
		]
	)
	_capture_overlay.visible = true
	_capture_overlay.move_to_front()


func cancel_key_capture() -> void:
	_capture_action = &""
	_capture_slot = -1
	_capture_overlay.visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if _handle_key_capture(key_event) or _handle_back_navigation(key_event):
		get_viewport().set_input_as_handled()


func _handle_key_capture(key_event: InputEventKey) -> bool:
	if not _capture_overlay.visible:
		return false
	var key_code: int = int(key_event.physical_keycode)
	if key_code == KEY_NONE:
		key_code = int(key_event.keycode)
	var result: Dictionary = settings.set_binding(
		_capture_action,
		_capture_slot,
		key_code
	)
	_show_binding_result(result)
	if bool(result.get("ok", false)):
		cancel_key_capture()
	return true


func _handle_back_navigation(key_event: InputEventKey) -> bool:
	if current_screen == Screen.GAME:
		return false
	if key_event.physical_keycode != KEY_ESCAPE and key_event.keycode != KEY_ESCAPE:
		return false

	match current_screen:
		Screen.TUTORIAL, Screen.OPTIONS:
			show_main_menu()
		Screen.KEY_CUSTOM, Screen.VOLUME:
			show_options()
		_:
			return false
	return true


func _build_interface() -> void:
	_game_host = Control.new()
	_game_host.name = "GameHost"
	_game_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_host.visible = false
	add_child(_game_host)

	_build_main_screen()
	_build_tutorial_screen()
	_build_options_screen()
	_build_key_screen()
	_build_volume_screen()
	_build_capture_overlay()
	_build_message_overlay()


func _build_main_screen() -> void:
	var screen: Control = _create_screen("MainScreen", Screen.MAIN)
	var panel: Panel = _create_panel(
		screen,
		Rect2(60.0, 60.0, 840.0, 680.0),
		Color(1.0, 1.0, 1.0, 0.98),
		BORDER,
		14
	)

	var kicker: Label = _create_label(
		panel,
		"KUNG FU × FALLING BLOCKS",
		Rect2(64.0, 60.0, 430.0, 28.0),
		15,
		CYAN
	)
	kicker.add_theme_constant_override("outline_size", 4)
	kicker.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.72))
	_create_label(
		panel,
		"KUNG FU\nTETRIS",
		Rect2(62.0, 92.0, 430.0, 138.0),
		48,
		TEXT
	).add_theme_constant_override("line_spacing", -4)
	_create_label(
		panel,
		"블록 위에서 펼쳐지는 쿵푸 액션",
		Rect2(66.0, 239.0, 420.0, 34.0),
		18,
		MUTED
	)

	var portrait_texture: AtlasTexture = AtlasTexture.new()
	portrait_texture.atlas = PORTRAIT
	portrait_texture.region = PORTRAIT_SOURCE
	var portrait: TextureRect = TextureRect.new()
	portrait.name = "CharacterPortrait"
	portrait.position = Vector2(520.0, 64.0)
	portrait.size = Vector2(260.0, 500.0)
	portrait.texture = portrait_texture
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(portrait)

	var button_data: Array = [
		["GAME START", CYAN, start_game],
		["게임 설명", ORANGE, show_tutorial],
		["OPTION", PURPLE, show_options],
		["EXIT", DANGER, request_exit],
	]
	for index: int in range(button_data.size()):
		var data: Array = button_data[index]
		var button: Button = _create_button(
			panel,
			String(data[0]),
			Rect2(64.0, 318.0 + index * 67.0, 350.0, 54.0),
			data[1],
			18
		)
		button.pressed.connect(data[2])
		button.focus_entered.connect(_play_select_sfx)
		_main_buttons.append(button)

	_create_label(
		panel,
		"↑ ↓ 선택    ENTER 확인",
		Rect2(66.0, 604.0, 340.0, 28.0),
		13,
		MUTED
	)


func _build_tutorial_screen() -> void:
	var screen: Control = _create_screen("TutorialScreen", Screen.TUTORIAL)
	_add_screen_title(screen, "게임 설명", "그림과 화살표를 따라 기능을 익혀보세요")

	_tutorial_canvas = TUTORIAL_CANVAS_SCRIPT.new()
	_tutorial_canvas.name = "TutorialCanvas"
	_tutorial_canvas.position = Vector2(70.0, 134.0)
	_tutorial_canvas.size = Vector2(820.0, 476.0)
	_tutorial_canvas.set_settings(settings)
	screen.add_child(_tutorial_canvas)

	_tutorial_prev_button = _create_button(
		screen,
		"← 이전",
		Rect2(70.0, 642.0, 150.0, 50.0),
		CYAN,
		15
	)
	_tutorial_prev_button.pressed.connect(previous_tutorial_page)
	_tutorial_next_button = _create_button(
		screen,
		"다음 →",
		Rect2(740.0, 642.0, 150.0, 50.0),
		ORANGE,
		15
	)
	_tutorial_next_button.pressed.connect(next_tutorial_page)
	_tutorial_counter = _create_label(
		screen,
		"1 / 4",
		Rect2(422.0, 652.0, 116.0, 34.0),
		17,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	var back_button: Button = _create_button(
		screen,
		"메인으로",
		Rect2(390.0, 712.0, 180.0, 46.0),
		PURPLE,
		14
	)
	back_button.pressed.connect(show_main_menu)


func _build_options_screen() -> void:
	var screen: Control = _create_screen("OptionsScreen", Screen.OPTIONS)
	_add_screen_title(screen, "OPTION", "키 설정과 사운드 크기를 조절합니다")

	_options_first_button = _create_option_card(
		screen,
		Rect2(110.0, 190.0, 340.0, 370.0),
		"KEY\nCUSTOM",
		Rect2(36.0, 44.0, 270.0, 95.0),
		"이동·액션·시스템 키를\n원하는 키로 변경합니다.",
		CYAN,
		"키 설정 열기",
		show_key_custom
	)
	_create_option_card(
		screen,
		Rect2(510.0, 190.0, 340.0, 370.0),
		"VOLUME",
		Rect2(36.0, 72.0, 270.0, 54.0),
		"BGM과 효과음의 크기를\n각각 조절합니다.",
		ORANGE,
		"볼륨 설정 열기",
		show_volume
	)

	var back_button: Button = _create_button(
		screen,
		"메인으로",
		Rect2(390.0, 650.0, 180.0, 48.0),
		PURPLE,
		14
	)
	back_button.pressed.connect(show_main_menu)


func _create_option_card(
	parent: Control,
	rect: Rect2,
	title: String,
	title_rect: Rect2,
	description: String,
	accent: Color,
	button_text: String,
	on_pressed: Callable
) -> Button:
	var panel: Panel = _create_panel(parent, rect, PANEL, accent, 12)
	_create_label(
		panel,
		title,
		title_rect,
		34,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_create_label(
		panel,
		description,
		Rect2(32.0, 170.0, 276.0, 70.0),
		16,
		MUTED,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	var button: Button = _create_button(
		panel,
		button_text,
		Rect2(50.0, 278.0, 240.0, 52.0),
		accent,
		16
	)
	button.pressed.connect(on_pressed)
	return button


func _build_key_screen() -> void:
	var screen: Control = _create_screen("KeyCustomScreen", Screen.KEY_CUSTOM)
	_add_screen_title(screen, "KEY CUSTOM", "버튼을 누른 뒤 새 키를 입력하세요")
	_build_key_headers(screen)
	_build_key_rows(screen)
	_build_key_footer(screen)


func _build_key_headers(screen: Control) -> void:
	_create_label(
		screen,
		"동작",
		Rect2(108.0, 118.0, 210.0, 26.0),
		14,
		MUTED
	)
	_create_label(
		screen,
		"주 키",
		Rect2(350.0, 118.0, 150.0, 26.0),
		14,
		MUTED,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_create_label(
		screen,
		"보조 키",
		Rect2(520.0, 118.0, 150.0, 26.0),
		14,
		MUTED,
		HORIZONTAL_ALIGNMENT_CENTER
	)


func _build_key_rows(screen: Control) -> void:
	var definitions: Array[Dictionary] = settings.get_action_definitions()
	for index: int in range(definitions.size()):
		_build_key_row(screen, definitions[index], index)


func _build_key_row(screen: Control, definition: Dictionary, index: int) -> void:
	var action_name: StringName = definition["action"]
	var y_value: float = 150.0 + index * 46.0
	_add_key_row_stripe(screen, y_value, index % 2 == 0)
	_create_label(
		screen,
		String(definition["label"]),
		Rect2(108.0, y_value + 8.0, 210.0, 28.0),
		15,
		TEXT
	)

	var action_buttons: Array[Button] = []
	var primary: Button = _create_button(
		screen,
		"",
		Rect2(350.0, y_value, 150.0, 38.0),
		CYAN,
		13
	)
	primary.pressed.connect(begin_key_capture.bind(action_name, 0))
	action_buttons.append(primary)
	_build_secondary_key_control(
		screen,
		action_name,
		int(definition["slots"]),
		y_value,
		action_buttons
	)
	_key_buttons[action_name] = action_buttons


func _add_key_row_stripe(screen: Control, y_value: float, visible: bool) -> void:
	if not visible:
		return
	var stripe: ColorRect = ColorRect.new()
	stripe.position = Vector2(96.0, y_value - 3.0)
	stripe.size = Vector2(768.0, 43.0)
	stripe.color = Color(0.86, 0.89, 0.93, 0.82)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(stripe)


func _build_secondary_key_control(
	screen: Control,
	action_name: StringName,
	slot_count: int,
	y_value: float,
	action_buttons: Array[Button]
) -> void:
	if slot_count <= 1:
		_create_label(
			screen,
			"—",
			Rect2(520.0, y_value + 8.0, 150.0, 24.0),
			15,
			Color(0.45, 0.55, 0.68),
			HORIZONTAL_ALIGNMENT_CENTER
		)
		return

	var secondary: Button = _create_button(
		screen,
		"",
		Rect2(520.0, y_value, 150.0, 38.0),
		ORANGE,
		13
	)
	secondary.pressed.connect(begin_key_capture.bind(action_name, 1))
	action_buttons.append(secondary)
	var clear_button: Button = _create_button(
		screen,
		"지우기",
		Rect2(688.0, y_value, 74.0, 38.0),
		MUTED,
		12
	)
	clear_button.pressed.connect(_clear_secondary.bind(action_name))


func _build_key_footer(screen: Control) -> void:
	_key_status = _create_label(
		screen,
		"",
		Rect2(90.0, 617.0, 780.0, 30.0),
		13,
		CYAN,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	var reset_button: Button = _create_button(
		screen,
		"기본값 복원",
		Rect2(250.0, 674.0, 190.0, 46.0),
		ORANGE,
		14
	)
	reset_button.pressed.connect(_reset_keys)
	var back_button: Button = _create_button(
		screen,
		"OPTION으로",
		Rect2(520.0, 674.0, 190.0, 46.0),
		PURPLE,
		14
	)
	back_button.pressed.connect(show_options)


func _build_volume_screen() -> void:
	var screen: Control = _create_screen("VolumeScreen", Screen.VOLUME)
	_add_screen_title(screen, "VOLUME", "향후 추가되는 음악과 효과음에도 설정이 유지됩니다")
	var panel: Panel = _create_panel(
		screen,
		Rect2(150.0, 190.0, 660.0, 390.0),
		PANEL,
		BORDER,
		12
	)

	_music_value_label = _create_volume_row(
		panel,
		"BGM",
		69.0,
		settings.music_percent,
		CYAN,
		"MusicSlider",
		_on_music_changed
	)
	_sfx_value_label = _create_volume_row(
		panel,
		"SFX",
		179.0,
		settings.sfx_percent,
		ORANGE,
		"SfxSlider",
		_on_sfx_changed
	)

	_create_label(
		panel,
		"0%는 음소거입니다. 음악은 BGM 버스,\n효과음은 SFX 버스를 지정하면 이 설정을 사용합니다.",
		Rect2(54.0, 278.0, 552.0, 64.0),
		14,
		MUTED,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	var back_button: Button = _create_button(
		screen,
		"OPTION으로",
		Rect2(390.0, 640.0, 180.0, 48.0),
		PURPLE,
		14
	)
	back_button.pressed.connect(show_options)


func _create_volume_row(
	parent: Control,
	label_text: String,
	y_position: float,
	value: float,
	accent: Color,
	slider_name: String,
	on_changed: Callable
) -> Label:
	_create_label(
		parent,
		label_text,
		Rect2(54.0, y_position + 3.0, 130.0, 34.0),
		22,
		accent
	)
	var slider: HSlider = _create_slider(
		parent,
		Rect2(185.0, y_position, 330.0, 42.0),
		value
	)
	slider.name = slider_name
	slider.value_changed.connect(on_changed)
	return _create_label(
		parent,
		"%d%%" % roundi(value),
		Rect2(530.0, y_position + 7.0, 80.0, 30.0),
		17,
		TEXT,
		HORIZONTAL_ALIGNMENT_RIGHT
	)


func _build_capture_overlay() -> void:
	_capture_overlay = Control.new()
	_capture_overlay.name = "KeyCaptureOverlay"
	_capture_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capture_overlay.visible = false
	add_child(_capture_overlay)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.78)
	_capture_overlay.add_child(shade)
	var panel: Panel = _create_panel(
		_capture_overlay,
		Rect2(220.0, 270.0, 520.0, 250.0),
		PANEL,
		CYAN,
		12
	)
	_create_label(
		panel,
		"새 키 입력",
		Rect2(50.0, 38.0, 420.0, 38.0),
		26,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_capture_label = _create_label(
		panel,
		"",
		Rect2(40.0, 100.0, 440.0, 38.0),
		16,
		MUTED,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	var cancel_button: Button = _create_button(
		panel,
		"취소",
		Rect2(170.0, 168.0, 180.0, 44.0),
		DANGER,
		14
	)
	cancel_button.pressed.connect(cancel_key_capture)


func _build_message_overlay() -> void:
	_message_overlay = Control.new()
	_message_overlay.name = "MessageOverlay"
	_message_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message_overlay.visible = false
	add_child(_message_overlay)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.72)
	_message_overlay.add_child(shade)
	var panel: Panel = _create_panel(
		_message_overlay,
		Rect2(210.0, 260.0, 540.0, 280.0),
		PANEL,
		DANGER,
		12
	)
	_create_label(
		panel,
		"안내",
		Rect2(40.0, 36.0, 460.0, 38.0),
		25,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_message_label = _create_label(
		panel,
		"",
		Rect2(44.0, 96.0, 452.0, 76.0),
		15,
		MUTED,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	var okay_button: Button = _create_button(
		panel,
		"확인",
		Rect2(180.0, 205.0, 180.0, 44.0),
		CYAN,
		14
	)
	okay_button.pressed.connect(_hide_message)


func _show_screen(screen_type: Screen) -> void:
	current_screen = screen_type
	for stored_screen: Variant in _screens.values():
		(stored_screen as Control).visible = false
	_game_host.visible = screen_type == Screen.GAME
	if screen_type != Screen.GAME:
		(_screens[screen_type] as Control).visible = true

	match screen_type:
		Screen.MAIN:
			_main_buttons[0].grab_focus.call_deferred()
		Screen.TUTORIAL:
			_tutorial_next_button.grab_focus.call_deferred()
		Screen.OPTIONS:
			if _options_first_button != null:
				_options_first_button.grab_focus.call_deferred()
		_:
			pass


func _refresh_tutorial() -> void:
	if _tutorial_canvas == null:
		return
	_tutorial_canvas.set_page(tutorial_page)
	_tutorial_counter.text = "%d / 4" % (tutorial_page + 1)
	_tutorial_prev_button.disabled = tutorial_page == 0
	_tutorial_next_button.disabled = tutorial_page == 3


func _refresh_key_buttons() -> void:
	if _key_buttons.is_empty() or settings == null:
		return
	for action_variant: Variant in _key_buttons.keys():
		var action_name: StringName = action_variant
		var buttons: Array = _key_buttons[action_name]
		for slot_index: int in range(buttons.size()):
			(buttons[slot_index] as Button).text = settings.get_slot_text(
				action_name,
				slot_index
			)
	if _tutorial_canvas != null:
		_tutorial_canvas.queue_redraw()


func _clear_secondary(action_name: StringName) -> void:
	var result: Dictionary = settings.clear_secondary_binding(action_name)
	_show_binding_result(result)


func _show_binding_result(result: Dictionary) -> void:
	_key_status.text = String(result.get("message", ""))
	_key_status.modulate = CYAN if bool(result.get("ok", false)) else DANGER


func _reset_keys() -> void:
	settings.reset_bindings_to_defaults()
	_key_status.text = "모든 키를 기본값으로 복원했습니다."
	_key_status.modulate = CYAN


func _on_music_changed(value: float) -> void:
	settings.set_music_percent(value)
	_music_value_label.text = "%d%%" % roundi(value)


func _on_sfx_changed(value: float) -> void:
	settings.set_sfx_percent(value)
	_sfx_value_label.text = "%d%%" % roundi(value)


func _show_message(message: String) -> void:
	if _message_overlay == null:
		return
	_message_label.text = message
	_message_overlay.visible = true
	_message_overlay.move_to_front()


func _hide_message() -> void:
	_message_overlay.visible = false


func _play_select_sfx() -> void:
	if _skip_initial_select_sfx:
		_skip_initial_select_sfx = false
		return
	_select_sfx_player.stream = SFX_SELECT
	_select_sfx_player.play()
	_select_sfx_timer.start()


func _create_screen(screen_name: String, screen_type: Screen) -> Control:
	var screen: Control = Control.new()
	screen.name = screen_name
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.visible = false
	add_child(screen)
	_screens[screen_type] = screen
	return screen


func _add_screen_title(parent: Control, title: String, subtitle: String) -> void:
	_create_label(parent, title, Rect2(70.0, 48.0, 430.0, 52.0), 34, TEXT)
	_create_label(parent, subtitle, Rect2(72.0, 98.0, 700.0, 28.0), 15, MUTED)
	var line: ColorRect = ColorRect.new()
	line.position = Vector2(70.0, 125.0)
	line.size = Vector2(820.0, 2.0)
	line.color = Color(0.22, 0.85, 1.0, 0.45)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _create_panel(
	parent: Control,
	rect: Rect2,
	background: Color,
	border: Color,
	radius: int
) -> Panel:
	return _ui.create_panel(parent, rect, background, border, radius)


func _create_label(
	parent: Control,
	text_value: String,
	rect: Rect2,
	font_size: int,
	color: Color,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	return _ui.create_label(parent, text_value, rect, font_size, color, alignment)


func _create_button(
	parent: Control,
	text_value: String,
	rect: Rect2,
	accent: Color,
	font_size: int
) -> Button:
	return _ui.create_button(parent, text_value, rect, accent, font_size)


func _create_slider(parent: Control, rect: Rect2, initial_value: float) -> HSlider:
	return _ui.create_slider(parent, rect, initial_value)


func _draw_decorative_blocks(origin: Vector2, color: Color, alpha: float) -> void:
	var cells: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(2, 1),
	]
	var source_region: Rect2 = CYAN_BLOCK_SOURCE if color == CYAN else ORANGE_BLOCK_SOURCE
	for cell: Vector2i in cells:
		draw_texture_rect_region(
			BLOCK_TEXTURE,
			Rect2(origin + Vector2(cell) * 30.0, Vector2(27.0, 27.0)),
			source_region,
			Color(1.0, 1.0, 1.0, alpha)
		)
