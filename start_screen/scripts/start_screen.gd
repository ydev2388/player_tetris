class_name KungFuTetrisStartScreen
extends Control

signal game_loaded(game_root: Node)
signal exit_requested

const GAME_SCENE_DEFAULT: String = "res://scenes/main.tscn"
const MENU_VIEWPORT_SIZE: Vector2i = Vector2i(960, 800)
const TUTORIAL_PAGE_COUNT: int = 5
const PORTRAIT: Texture2D = preload("res://assets/sprites/characters/normal/normal_atlas.png")
const PORTRAIT_SOURCE: Rect2 = Rect2(0.0, 0.0, 128.0, 128.0)
const BLOCK_TEXTURE: Texture2D = preload("res://assets/sprites/block_sprites.png")
const CYAN_BLOCK_SOURCE: Rect2 = Rect2(80.0, 255.0, 210.0, 215.0)
const ORANGE_BLOCK_SOURCE: Rect2 = Rect2(1745.0, 255.0, 210.0, 215.0)
const TUTORIAL_CANVAS_SCRIPT: Script = preload(
	"res://start_screen/scripts/tutorial_canvas.gd"
)
const UI_SCRIPT: Script = preload("res://start_screen/scripts/start_screen_ui.gd")
const CHARACTER_DATA: Script = preload("res://scripts/character_data.gd")
const ANIMATION_DATA: Script = preload("res://scripts/character_animation_data.gd")
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
	STAGE_SELECT,
	CHARACTER,
	SHOP,
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
var selected_stage_number: int = 1

var _font: SystemFont
var _ui: RefCounted
var _screens: Dictionary = {}
var _main_buttons: Array[Button] = []
var _stage_buttons: Array[Button] = []
var _stage_labels: Array[Label] = []
var _stage_currency_label: Label
var _shop_currency_label: Label
var _shop_level_labels: Array[Label] = []
var _shop_cost_labels: Array[Label] = []
var _shop_upgrade_buttons: Array[Button] = []
var _shop_reset_button: Button
var _character_buttons: Array[Button] = []
var _character_confirm_button: Button
var _character_back_button: Button
var _character_detail_label: Label
var _selected_character_id: String = MainCharacterData.DEFAULT_CHARACTER_ID
var _character_window_start: int = 0
var _character_prev_button: Button
var _character_next_button: Button
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
var _game_exit_overlay: Control
var _game_exit_yes_button: Button
var _game_exit_no_button: Button
var _game_exit_was_playing: bool = false
var _select_sfx_player: AudioStreamPlayer
var _select_sfx_timer: Timer
var _skip_initial_select_sfx: bool = true

var _capture_overlay: Control
var _capture_label: Label
var _capture_action: StringName = &""
var _capture_slot: int = -1

var _message_overlay: Control
var _message_label: Label
var _stage_result_overlay: Control
var _stage_result_label: Label
var _stage_result_reward_label: Label
var _stage_result_button: Button
var _progress_reset_overlay: Control
var _progress_reset_yes_button: Button
var _progress_reset_no_button: Button
var _passive_reset_overlay: Control
var _passive_reset_yes_button: Button
var _passive_reset_no_button: Button


func _ready() -> void:
	set_process_input(true)
	set_process_unhandled_key_input(true)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI"])
	_ui = UI_SCRIPT.new(_font, PANEL_DARK, BORDER, TEXT)

	settings = StartScreenSettings.new(settings_file_path)
	settings.name = "StartScreenSettings"
	settings.settings_error.connect(_show_message)
	settings.bindings_changed.connect(_refresh_key_buttons)
	settings.progress_changed.connect(_refresh_stage_select)
	settings.progress_changed.connect(_refresh_shop)
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
	_hide_stage_result()
	_show_screen(Screen.MAIN)


func show_stage_select() -> void:
	_hide_stage_result()
	_refresh_stage_select()
	_show_screen(Screen.STAGE_SELECT)


func show_character_select() -> void:
	_refresh_character_selection()
	_show_screen(Screen.CHARACTER)


func show_shop() -> void:
	_refresh_shop()
	_show_screen(Screen.SHOP)


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
	tutorial_page = mini(tutorial_page + 1, TUTORIAL_PAGE_COUNT - 1)
	_refresh_tutorial()


func previous_tutorial_page() -> void:
	tutorial_page = maxi(tutorial_page - 1, 0)
	_refresh_tutorial()


func start_game(stage_number: int = -1) -> bool:
	if _selected_character_id.is_empty() or not MainCharacterData.has_character(_selected_character_id):
		_show_message("먼저 캐릭터를 선택하세요.")
		return false
	if _game_instance != null and is_instance_valid(_game_instance):
		return true
	if stage_number < 1:
		stage_number = selected_stage_number
	if not settings.is_stage_unlocked(stage_number):
		_show_message("아직 잠긴 스테이지입니다.")
		return false
	if not ResourceLoader.exists(game_scene_path, "PackedScene"):
		_show_message("게임 장면을 찾을 수 없습니다.\n%s" % game_scene_path)
		return false

	var game_resource: Resource = load(game_scene_path)
	if not game_resource is PackedScene:
		_show_message("게임 장면을 불러올 수 없습니다.\n%s" % game_scene_path)
		return false

	_game_instance = (game_resource as PackedScene).instantiate()
	_game_instance.name = "LoadedGame"
	_game_instance.set_meta("stage_number", stage_number)
	selected_stage_number = stage_number
	_game_host.add_child(_game_instance)
	var selected_character: MainCharacterController = _game_instance.get_node_or_null(
		"BoardPhysics/Character"
	) as MainCharacterController
	if selected_character != null:
		selected_character.set_character_id(_selected_character_id)
		selected_character.set_passive_levels(settings.get_passive_levels())
	var game_controller: MainGameController = _loaded_game_controller()
	if game_controller != null:
		game_controller.stage_cleared.connect(_on_survival_stage_cleared)
	_show_screen(Screen.GAME)
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


## 상황: 게임 화면의 자식 노드나 GUI가 키를 소비하기 전에 Esc 메뉴 입력을 확인한다.
## 결과: 실제 키 이벤트 경로에서도 메뉴 복귀 Yes/No 창이 항상 최우선으로 열린다.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if _handle_game_exit_prompt_input(key_event):
		get_viewport().set_input_as_handled()
	elif _handle_debug_completion_input(key_event):
		get_viewport().set_input_as_handled()
	elif _handle_progress_reset_prompt_input(key_event):
		get_viewport().set_input_as_handled()
	elif _handle_passive_reset_prompt_input(key_event):
		get_viewport().set_input_as_handled()
	elif _handle_character_select_input(key_event):
		get_viewport().set_input_as_handled()
	elif _handle_menu_confirm_input(key_event):
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if (
		_handle_key_capture(key_event)
		or _handle_back_navigation(key_event)
	):
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


## 결과: 게임 중 Esc로 확인창을 열고, 열린 뒤에는 방향키·Z·X를 처리한다.
func _handle_game_exit_prompt_input(key_event: InputEventKey) -> bool:
	if _game_exit_overlay != null and _game_exit_overlay.visible:
		var key_code: int = key_event.physical_keycode
		if key_code == KEY_NONE:
			key_code = key_event.keycode
		if key_code == KEY_UP or key_code == KEY_DOWN:
			if _game_exit_yes_button.has_focus():
				_game_exit_no_button.grab_focus()
			else:
				_game_exit_yes_button.grab_focus()
			return true
		if key_code == KEY_Z:
			if _game_exit_yes_button.has_focus():
				_confirm_return_to_main_menu()
			else:
				_hide_game_exit_prompt()
			return true
		if key_code == KEY_X:
			_hide_game_exit_prompt()
			return true
		return _is_escape_key(key_event)
	if current_screen != Screen.GAME or not _is_escape_key(key_event):
		return false
	var game_controller: MainGameController = _loaded_game_controller()
	if game_controller == null:
		return false
	_show_game_exit_prompt()
	return true


func _handle_debug_completion_input(key_event: InputEventKey) -> bool:
	if not OS.is_debug_build() or current_screen != Screen.GAME:
		return false
	if _game_instance == null or not is_instance_valid(_game_instance):
		return false
	if _game_exit_overlay != null and _game_exit_overlay.visible:
		return false
	if not _is_enter_key(key_event):
		return false
	_complete_stage_for_debug()
	return true


## 결과: 캐릭터 화면에서 좌우는 카드 이동, 끝 칸은 표시 window 이동, Z는 즉시 확정한다.
func _handle_character_select_input(key_event: InputEventKey) -> bool:
	if current_screen != Screen.CHARACTER:
		return false
	var key_code: int = key_event.physical_keycode
	if key_code == KEY_NONE:
		key_code = key_event.keycode
	if key_code == KEY_LEFT:
		_move_character_focus(-1)
		return true
	if key_code == KEY_RIGHT:
		_move_character_focus(1)
		return true
	if key_code == KEY_Z:
		if not _selected_character_id.is_empty() and MainCharacterData.has_character(_selected_character_id):
			show_stage_select()
		return true
	return false


func _move_character_focus(direction: int) -> void:
	var focused_button: Button = get_viewport().gui_get_focus_owner() as Button
	var current_index: int = _character_buttons.find(focused_button)
	if current_index < 0:
		current_index = MainCharacterData.CHARACTER_ORDER.find(_selected_character_id)
	if current_index < 0:
		current_index = _character_window_start
	var target_index: int = current_index + signi(direction)
	if target_index < 0 or target_index >= _character_buttons.size():
		return
	if target_index < _character_window_start:
		_shift_character_window(-1)
	elif target_index >= _character_window_start + 3:
		_shift_character_window(1)
	_character_buttons[target_index].grab_focus()
	_select_character(MainCharacterData.CHARACTER_ORDER[target_index])


## 결과: 게임 밖의 초점 버튼은 Z로 누르고 Enter는 선택키로 쓰지 않는다.
func _handle_menu_confirm_input(key_event: InputEventKey) -> bool:
	if current_screen == Screen.GAME or _capture_overlay.visible:
		return false
	var key_code: int = key_event.physical_keycode
	if key_code == KEY_NONE:
		key_code = key_event.keycode
	if key_code == KEY_ENTER or key_code == KEY_KP_ENTER:
		return true
	if key_code != KEY_Z:
		return false
	var focused_button: Button = get_viewport().gui_get_focus_owner() as Button
	if focused_button != null:
		focused_button.pressed.emit()
	return true


## 결과: 물리 키와 논리 키 중 하나가 Esc이면 true이며 event를 변경하지 않는다.
func _is_escape_key(key_event: InputEventKey) -> bool:
	return key_event.physical_keycode == KEY_ESCAPE or key_event.keycode == KEY_ESCAPE


func _is_x_key(key_event: InputEventKey) -> bool:
	return key_event.physical_keycode == KEY_X or key_event.keycode == KEY_X


func _handle_progress_reset_prompt_input(key_event: InputEventKey) -> bool:
	if _progress_reset_overlay == null or not _progress_reset_overlay.visible:
		return false
	var key_code: int = key_event.physical_keycode
	if key_code == KEY_NONE:
		key_code = key_event.keycode
	if key_code == KEY_LEFT or key_code == KEY_RIGHT:
		if _progress_reset_yes_button.has_focus():
			_progress_reset_no_button.grab_focus()
		else:
			_progress_reset_yes_button.grab_focus()
		return true
	if key_code == KEY_Z:
		if _progress_reset_yes_button.has_focus():
			_confirm_progress_reset()
		else:
			_hide_progress_reset_prompt()
		return true
	if _is_escape_key(key_event) or _is_x_key(key_event):
		_hide_progress_reset_prompt()
		return true
	return false


func _handle_passive_reset_prompt_input(key_event: InputEventKey) -> bool:
	if _passive_reset_overlay == null or not _passive_reset_overlay.visible:
		return false
	var key_code: int = key_event.physical_keycode
	if key_code == KEY_NONE:
		key_code = key_event.keycode
	if key_code == KEY_LEFT or key_code == KEY_RIGHT:
		if _passive_reset_yes_button.has_focus():
			_passive_reset_no_button.grab_focus()
		else:
			_passive_reset_yes_button.grab_focus()
		return true
	if key_code == KEY_Z:
		if _passive_reset_yes_button.has_focus():
			_confirm_passive_reset()
		else:
			_hide_passive_reset_prompt()
		return true
	if _is_escape_key(key_event) or _is_x_key(key_event):
		_hide_passive_reset_prompt()
		return true
	return false


func _show_progress_reset_prompt() -> void:
	_progress_reset_overlay.visible = true
	_progress_reset_overlay.move_to_front()
	_progress_reset_no_button.grab_focus.call_deferred()


func _show_passive_reset_prompt() -> void:
	_passive_reset_overlay.visible = true
	_passive_reset_overlay.move_to_front()
	_passive_reset_no_button.grab_focus.call_deferred()


func _hide_progress_reset_prompt() -> void:
	_progress_reset_overlay.visible = false
	_options_first_button.grab_focus.call_deferred()


func _hide_passive_reset_prompt() -> void:
	_passive_reset_overlay.visible = false
	_shop_reset_button.grab_focus.call_deferred()


func _confirm_progress_reset() -> void:
	var reset_error: Error = settings.reset_stage_progress()
	if reset_error != OK:
		_show_message("진행 데이터를 삭제하지 못했습니다: %s" % error_string(reset_error))
		return
	_hide_progress_reset_prompt()


func _confirm_passive_reset() -> void:
	var result: Dictionary = settings.reset_passive_upgrades()
	if not bool(result.get("ok", false)):
		_show_message(String(result.get("message", "패시브를 초기화할 수 없습니다.")))
		return
	_hide_passive_reset_prompt()


func _handle_back_navigation(key_event: InputEventKey) -> bool:
	if current_screen == Screen.GAME:
		return false
	if not (_is_escape_key(key_event) or _is_x_key(key_event)):
		return false

	match current_screen:
		Screen.STAGE_SELECT:
			show_main_menu()
		Screen.CHARACTER:
			show_stage_select()
		Screen.SHOP:
			show_stage_select()
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
	_build_stage_select_screen()
	_build_character_screen()
	_build_shop_screen()
	_build_tutorial_screen()
	_build_options_screen()
	_build_key_screen()
	_build_volume_screen()
	_build_capture_overlay()
	_build_message_overlay()
	_build_progress_reset_overlay()
	_build_passive_reset_overlay()
	_build_game_exit_overlay()
	_build_stage_result_overlay()


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
		["GAME START", CYAN, show_stage_select],
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
		"↑ ↓ 선택    Z 확인",
		Rect2(66.0, 604.0, 340.0, 28.0),
		13,
		MUTED
	)


func _build_stage_select_screen() -> void:
	var screen: Control = _create_screen("StageSelectScreen", Screen.STAGE_SELECT)
	_add_screen_title(screen, "STAGE SELECT", "클리어한 스테이지의 별은 다음 도전에 이어집니다")
	_stage_currency_label = _create_label(
		screen,
		"별 0개",
		Rect2(680.0, 54.0, 210.0, 40.0),
		18,
		ORANGE,
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	var character_button: Button = _create_button(
		screen,
		"캐릭터 선택",
		Rect2(700.0, 650.0, 200.0, 48.0),
		PURPLE,
		14
	)
	character_button.name = "CharacterSelectButton"
	character_button.pressed.connect(show_character_select)
	character_button.focus_entered.connect(_play_select_sfx)

	var accents: Array[Color] = [CYAN, ORANGE, PURPLE, CYAN, DANGER]
	for stage_number: int in range(1, StartScreenSettings.STAGE_COUNT + 1):
		var x_position: float = 70.0 + float(stage_number - 1) * 166.0
		var panel: Panel = _create_panel(
			screen,
			Rect2(x_position, 190.0, 150.0, 340.0),
			PANEL,
			accents[stage_number - 1],
			10
		)
		_create_label(
			panel,
			"1-%d%s" % [stage_number, "  BOSS" if stage_number == 5 else ""],
			Rect2(10.0, 26.0, 130.0, 38.0),
			19,
			TEXT,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		var status_label: Label = _create_label(
			panel,
			"",
			Rect2(10.0, 102.0, 130.0, 72.0),
			17,
			ORANGE,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		_stage_labels.append(status_label)
		var stage_button: Button = _create_button(
			panel,
			"블록 깨러 가기",
			Rect2(10.0, 235.0, 130.0, 48.0),
			accents[stage_number - 1],
			12
		)
		stage_button.name = "StageButton%d" % stage_number
		stage_button.pressed.connect(_on_stage_selected.bind(stage_number))
		stage_button.focus_entered.connect(_play_select_sfx)
		_stage_buttons.append(stage_button)

	var shop_button: Button = _create_button(
		screen,
		"상점",
		Rect2(70.0, 650.0, 200.0, 48.0),
		ORANGE,
		14
	)
	shop_button.name = "ShopButton"
	shop_button.pressed.connect(show_shop)
	shop_button.focus_entered.connect(_play_select_sfx)

	var back_button: Button = _create_button(
		screen,
		"메인으로",
		Rect2(390.0, 650.0, 180.0, 48.0),
		PURPLE,
		14
	)
	back_button.pressed.connect(show_main_menu)
	_refresh_stage_select()


func _build_shop_screen() -> void:
	var screen: Control = _create_screen("ShopScreen", Screen.SHOP)
	_add_screen_title(screen, "상점", "스테이지에서 모은 별로 전역 패시브를 강화하세요")
	_shop_currency_label = _create_label(
		screen,
		"별 0개",
		Rect2(680.0, 54.0, 210.0, 40.0),
		18,
		ORANGE,
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	var accents: Array[Color] = [CYAN, ORANGE, PURPLE, CYAN, DANGER]
	for index: int in range(StartScreenSettings.PASSIVE_IDS.size()):
		var card: Panel = _create_panel(
			screen,
			Rect2(32.0 + float(index) * 183.0, 155.0, 168.0, 405.0),
			PANEL,
			accents[index],
			10
		)
		_create_label(
			card,
			StartScreenSettings.PASSIVE_NAMES[index],
			Rect2(10.0, 22.0, 148.0, 34.0),
			21,
			TEXT,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		_create_label(
			card,
			StartScreenSettings.PASSIVE_DESCRIPTIONS[index],
			Rect2(12.0, 70.0, 144.0, 82.0),
			13,
			MUTED,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		var level_label: Label = _create_label(
			card,
			"",
			Rect2(12.0, 174.0, 144.0, 58.0),
			17,
			TEXT,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		level_label.name = "PassiveLevelLabel_%s" % StartScreenSettings.PASSIVE_IDS[index]
		_shop_level_labels.append(level_label)
		var cost_label: Label = _create_label(
			card,
			"",
			Rect2(12.0, 245.0, 144.0, 38.0),
			15,
			ORANGE,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		cost_label.name = "PassiveCostLabel_%s" % StartScreenSettings.PASSIVE_IDS[index]
		_shop_cost_labels.append(cost_label)
		var upgrade_button: Button = _create_button(
			card,
			"강화",
			Rect2(14.0, 320.0, 140.0, 48.0),
			accents[index],
			14
		)
		upgrade_button.name = "PassiveUpgradeButton_%s" % StartScreenSettings.PASSIVE_IDS[index]
		upgrade_button.pressed.connect(
			_upgrade_passive.bind(StartScreenSettings.PASSIVE_IDS[index])
		)
		upgrade_button.focus_entered.connect(_play_select_sfx)
		_shop_upgrade_buttons.append(upgrade_button)

	var back_button: Button = _create_button(
		screen,
		"스테이지 선택으로",
		Rect2(70.0, 650.0, 220.0, 48.0),
		PURPLE,
		14
	)
	back_button.pressed.connect(show_stage_select)
	_shop_reset_button = _create_button(
		screen,
		"패시브 초기화",
		Rect2(670.0, 650.0, 220.0, 48.0),
		DANGER,
		14
	)
	_shop_reset_button.name = "PassiveResetButton"
	_shop_reset_button.pressed.connect(_show_passive_reset_prompt)
	_shop_reset_button.focus_entered.connect(_play_select_sfx)
	_refresh_shop()


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
		"1 / %d" % TUTORIAL_PAGE_COUNT,
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
	var reset_panel: Panel = _create_panel(
		screen,
		Rect2(310.0, 575.0, 340.0, 130.0),
		PANEL,
		DANGER,
		12
	)
	_create_label(
		reset_panel,
		"진행 데이터 초기화",
		Rect2(20.0, 14.0, 300.0, 30.0),
		18,
		DANGER,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_create_label(
		reset_panel,
		"스테이지 해금과 별 재화를 지웁니다.",
		Rect2(20.0, 45.0, 300.0, 24.0),
		13,
		MUTED,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	var reset_button: Button = _create_button(
		reset_panel,
		"진행 상황 삭제",
		Rect2(70.0, 78.0, 200.0, 38.0),
		DANGER,
		14
	)
	reset_button.pressed.connect(_show_progress_reset_prompt)

	var back_button: Button = _create_button(
		screen,
		"메인으로",
		Rect2(390.0, 725.0, 180.0, 40.0),
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
	var y_value: float = 150.0 + index * 40.0
	_add_key_row_stripe(screen, y_value, index % 2 == 0)
	_create_label(
		screen,
		String(definition["label"]),
		Rect2(108.0, y_value + 5.0, 210.0, 26.0),
		15,
		TEXT
	)

	var action_buttons: Array[Button] = []
	var primary: Button = _create_button(
		screen,
		"",
		Rect2(350.0, y_value, 150.0, 34.0),
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
	stripe.position = Vector2(96.0, y_value - 2.0)
	stripe.size = Vector2(768.0, 38.0)
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
			Rect2(520.0, y_value + 5.0, 150.0, 24.0),
			15,
			Color(0.45, 0.55, 0.68),
			HORIZONTAL_ALIGNMENT_CENTER
		)
		return

	var secondary: Button = _create_button(
		screen,
		"",
		Rect2(520.0, y_value, 150.0, 34.0),
		ORANGE,
		13
	)
	secondary.pressed.connect(begin_key_capture.bind(action_name, 1))
	action_buttons.append(secondary)
	var clear_button: Button = _create_button(
		screen,
		"지우기",
		Rect2(688.0, y_value, 74.0, 34.0),
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


func _build_progress_reset_overlay() -> void:
	_progress_reset_overlay = Control.new()
	_progress_reset_overlay.name = "ProgressResetOverlay"
	_progress_reset_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_progress_reset_overlay.z_as_relative = false
	_progress_reset_overlay.z_index = 150
	_progress_reset_overlay.visible = false
	add_child(_progress_reset_overlay)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.78)
	_progress_reset_overlay.add_child(shade)
	var panel: Panel = _create_panel(
		_progress_reset_overlay,
		Rect2(220.0, 270.0, 520.0, 260.0),
		PANEL,
		DANGER,
		12
	)
	_create_label(
		panel,
		"진행 데이터를 삭제할까요?",
		Rect2(40.0, 38.0, 440.0, 38.0),
		24,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_create_label(
		panel,
		"스테이지 해금과 별 재화가 초기화됩니다.",
		Rect2(40.0, 92.0, 440.0, 32.0),
		15,
		MUTED,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_progress_reset_yes_button = _create_button(
		panel,
		"삭제",
		Rect2(72.0, 170.0, 180.0, 46.0),
		DANGER,
		15
	)
	_progress_reset_yes_button.pressed.connect(_confirm_progress_reset)
	_progress_reset_no_button = _create_button(
		panel,
		"취소",
		Rect2(268.0, 170.0, 180.0, 46.0),
		CYAN,
		15
	)
	_progress_reset_no_button.pressed.connect(_hide_progress_reset_prompt)


func _build_passive_reset_overlay() -> void:
	_passive_reset_overlay = Control.new()
	_passive_reset_overlay.name = "PassiveResetOverlay"
	_passive_reset_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_passive_reset_overlay.z_as_relative = false
	_passive_reset_overlay.z_index = 150
	_passive_reset_overlay.visible = false
	add_child(_passive_reset_overlay)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.78)
	_passive_reset_overlay.add_child(shade)
	var panel: Panel = _create_panel(
		_passive_reset_overlay,
		Rect2(220.0, 270.0, 520.0, 260.0),
		PANEL,
		DANGER,
		12
	)
	_create_label(
		panel,
		"패시브를 초기화할까요?",
		Rect2(40.0, 38.0, 440.0, 38.0),
		24,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_create_label(
		panel,
		"투자한 별을 모두 돌려받습니다.",
		Rect2(40.0, 92.0, 440.0, 32.0),
		15,
		MUTED,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_passive_reset_yes_button = _create_button(
		panel,
		"초기화",
		Rect2(72.0, 170.0, 180.0, 46.0),
		DANGER,
		15
	)
	_passive_reset_yes_button.pressed.connect(_confirm_passive_reset)
	_passive_reset_no_button = _create_button(
		panel,
		"취소",
		Rect2(268.0, 170.0, 180.0, 46.0),
		CYAN,
		15
	)
	_passive_reset_no_button.pressed.connect(_hide_passive_reset_prompt)


## 상황: 게임 중 Esc로 메인 메뉴 복귀 여부를 물을 modal UI를 준비한다.
## 호출: `_build_interface()`가 일반 화면과 다른 overlay를 모두 만든 뒤 한 번 호출한다.
## 결과: 질문과 Yes/No 버튼이 생성되며 실제 요청 전까지 숨김 상태를 유지한다.
func _build_game_exit_overlay() -> void:
	_game_exit_overlay = Control.new()
	_game_exit_overlay.name = "GameExitOverlay"
	_game_exit_overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_game_exit_overlay.size = Vector2(MainLayout.GAME_VIEWPORT_SIZE)
	_game_exit_overlay.z_as_relative = false
	_game_exit_overlay.z_index = 100
	_game_exit_overlay.visible = false
	add_child(_game_exit_overlay)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.78)
	_game_exit_overlay.add_child(shade)
	var panel: Panel = _create_panel(
		_game_exit_overlay,
		Rect2(60.0, 440.0, 440.0, 260.0),
		PANEL,
		PURPLE,
		12
	)
	panel.name = "GameExitPanel"
	_create_label(
		panel,
		"메뉴로 나가겠습니까?",
		Rect2(20.0, 46.0, 400.0, 52.0),
		25,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_game_exit_yes_button = _create_button(
		panel,
		"Yes",
		Rect2(40.0, 152.0, 160.0, 52.0),
		CYAN,
		16
	)
	_game_exit_yes_button.name = "GameExitYesButton"
	_game_exit_yes_button.pressed.connect(_confirm_return_to_main_menu)
	_game_exit_no_button = _create_button(
		panel,
		"No",
		Rect2(240.0, 152.0, 160.0, 52.0),
		DANGER,
		16
	)
	_game_exit_no_button.name = "GameExitNoButton"
	_game_exit_no_button.pressed.connect(_hide_game_exit_prompt)


func _build_stage_result_overlay() -> void:
	_stage_result_overlay = Control.new()
	_stage_result_overlay.name = "StageResultOverlay"
	_stage_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_result_overlay.z_as_relative = false
	_stage_result_overlay.z_index = 200
	_stage_result_overlay.visible = false
	add_child(_stage_result_overlay)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.78)
	_stage_result_overlay.add_child(shade)
	var panel: Panel = _create_panel(
		_stage_result_overlay,
		Rect2(220.0, 250.0, 520.0, 300.0),
		PANEL,
		ORANGE,
		12
	)
	_stage_result_label = _create_label(
		panel,
		"",
		Rect2(40.0, 40.0, 440.0, 84.0),
		27,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_stage_result_reward_label = _create_label(
		panel,
		"",
		Rect2(40.0, 140.0, 440.0, 42.0),
		17,
		ORANGE,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_stage_result_button = _create_button(
		panel,
		"스테이지 선택으로",
		Rect2(150.0, 220.0, 220.0, 46.0),
		CYAN,
		14
	)
	_stage_result_button.name = "StageResultButton"
	_stage_result_button.pressed.connect(show_stage_select)


func _show_stage_result(result: Dictionary) -> void:
	if _stage_result_overlay == null:
		return
	var stage_number: int = int(result.get("stage_number", selected_stage_number))
	var stars: int = int(result.get("stars", 3))
	var reward: int = int(result.get("reward", 0))
	_stage_result_label.text = "1-%d 클리어!\n%s" % [stage_number, _star_text(stars)]
	_stage_result_reward_label.text = "별 보상 +%d   (보유 %d)" % [
		reward,
		int(result.get("star_currency", settings.star_currency)),
	]
	_stage_result_overlay.visible = true
	_stage_result_overlay.move_to_front()
	_stage_result_button.grab_focus.call_deferred()


func _hide_stage_result() -> void:
	if _stage_result_overlay != null:
		_stage_result_overlay.visible = false


func _complete_stage_for_debug() -> void:
	if _game_instance == null or not is_instance_valid(_game_instance):
		return
	var game_controller: MainGameController = _loaded_game_controller()
	if game_controller != null and game_controller.is_boss_stage():
		if game_controller.is_boss_alive():
			game_controller.damage_boss(game_controller.boss_health)
		return
	_complete_stage(3)


func _on_survival_stage_cleared(cleared_lines: int) -> void:
	var game_controller: MainGameController = _loaded_game_controller()
	var stars: int = (
		3
		if game_controller != null and game_controller.is_boss_stage()
		else MainGameController.stage_stars_for_lines(cleared_lines)
	)
	_complete_stage(stars)


func _complete_stage(stars: int) -> void:
	var result: Dictionary = settings.complete_stage(selected_stage_number, stars)
	if not bool(result.get("ok", false)):
		_show_message(String(result.get("message", "스테이지를 완료할 수 없습니다.")))
		return
	if _game_instance != null and is_instance_valid(_game_instance):
		_game_instance.queue_free()
	_game_instance = null
	_apply_menu_viewport_size()
	_show_screen(Screen.STAGE_SELECT)
	_show_stage_result(result)


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
		Screen.STAGE_SELECT:
			if not _stage_buttons.is_empty():
				var focus_index: int = clampi(selected_stage_number - 1, 0, _stage_buttons.size() - 1)
				if _stage_buttons[focus_index].disabled:
					focus_index = 0
				_stage_buttons[focus_index].grab_focus.call_deferred()
		Screen.CHARACTER:
			for button: Button in _character_buttons:
				if button.visible:
					button.grab_focus.call_deferred()
					break
		Screen.TUTORIAL:
			_tutorial_next_button.grab_focus.call_deferred()
		Screen.OPTIONS:
			if _options_first_button != null:
				_options_first_button.grab_focus.call_deferred()
		Screen.SHOP:
			if not _shop_upgrade_buttons.is_empty():
				_shop_upgrade_buttons[0].grab_focus.call_deferred()
		_:
			pass


func _refresh_tutorial() -> void:
	if _tutorial_canvas == null:
		return
	_tutorial_canvas.set_page(tutorial_page)
	_tutorial_counter.text = "%d / %d" % [tutorial_page + 1, TUTORIAL_PAGE_COUNT]
	_tutorial_prev_button.disabled = tutorial_page == 0
	_tutorial_next_button.disabled = tutorial_page == TUTORIAL_PAGE_COUNT - 1


func _refresh_stage_select() -> void:
	if settings == null or _stage_buttons.size() != StartScreenSettings.STAGE_COUNT:
		return
	_stage_currency_label.text = "별 %d개" % settings.star_currency
	for stage_number: int in range(1, StartScreenSettings.STAGE_COUNT + 1):
		var index: int = stage_number - 1
		var unlocked: bool = settings.is_stage_unlocked(stage_number)
		_stage_labels[index].text = "%s\n%s" % [
			_star_text(settings.get_stage_best_stars(stage_number)),
			"입장 가능" if unlocked else "잠김",
		]
		_stage_buttons[index].disabled = not unlocked
		_stage_buttons[index].text = "블록 깨러 가기" if unlocked else "잠김"


func _refresh_shop() -> void:
	if settings == null or _shop_upgrade_buttons.size() != StartScreenSettings.PASSIVE_IDS.size():
		return
	_shop_currency_label.text = "별 %d개" % settings.star_currency
	var effect_percent: int = roundi(MainCharacterData.PASSIVE_EFFECT_STEP * 100.0)
	for index: int in range(StartScreenSettings.PASSIVE_IDS.size()):
		var passive_id: String = StartScreenSettings.PASSIVE_IDS[index]
		var level: int = settings.get_passive_level(passive_id)
		var cost: int = settings.get_passive_cost(passive_id)
		var effect_sign: String = "-" if index in [0, 3, 4] else "+"
		_shop_level_labels[index].text = "Lv. %d / %d\n효과 %s%d%%" % [
			level,
			StartScreenSettings.MAX_PASSIVE_LEVEL,
			effect_sign,
			level * effect_percent,
		]
		var maxed: bool = level >= StartScreenSettings.MAX_PASSIVE_LEVEL
		_shop_cost_labels[index].text = "최대 레벨" if maxed else "다음 비용 ★ %d" % cost
		_shop_upgrade_buttons[index].disabled = maxed or settings.star_currency < cost
		_shop_upgrade_buttons[index].text = "최대 레벨" if maxed else "강화"


func _upgrade_passive(passive_id: String) -> void:
	var result: Dictionary = settings.upgrade_passive(passive_id)
	if not bool(result.get("ok", false)):
		_show_message(String(result.get("message", "패시브를 강화할 수 없습니다.")))


func _on_stage_selected(stage_number: int) -> void:
	if settings.is_stage_unlocked(stage_number):
		start_game(stage_number)


func _star_text(stars: int) -> String:
	var result: String = ""
	for star_index: int in range(StartScreenSettings.MAX_STAGE_STARS):
		result += "★" if star_index < stars else "☆"
	return result


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


func _is_enter_key(key_event: InputEventKey) -> bool:
	return (
		key_event.physical_keycode == KEY_ENTER
		or key_event.physical_keycode == KEY_KP_ENTER
		or key_event.keycode == KEY_ENTER
		or key_event.keycode == KEY_KP_ENTER
	)


func _show_message(message: String) -> void:
	if _message_overlay == null:
		return
	_message_label.text = message
	_message_overlay.visible = true
	_message_overlay.move_to_front()


func _hide_message() -> void:
	_message_overlay.visible = false


## 결과: modal을 최상단에 표시하고 게임 입력을 잠근 뒤 No에 초점을 둔다.
func _show_game_exit_prompt() -> void:
	if _game_exit_overlay == null:
		return
	var game_controller: MainGameController = _loaded_game_controller()
	if game_controller == null:
		return
	if _game_exit_overlay.visible:
		return
	_game_exit_was_playing = game_controller.state == MainGameController.GameState.PLAYING
	if _game_exit_was_playing:
		game_controller.toggle_pause()
	game_controller.set_physics_process(false)
	_game_exit_overlay.visible = true
	_game_exit_overlay.move_to_front()
	_game_exit_no_button.grab_focus.call_deferred()


## 상황: No 버튼 또는 열린 확인창에서 다시 Esc를 눌렀을 때 호출한다.
## 결과: modal만 닫고 현재 게임 오버 화면과 R 재시작 입력을 다시 활성화한다.
func _hide_game_exit_prompt() -> void:
	if _game_exit_overlay == null:
		return
	var was_playing: bool = _game_exit_was_playing
	_game_exit_was_playing = false
	_game_exit_overlay.visible = false
	var game_controller: MainGameController = _loaded_game_controller()
	if game_controller != null:
		game_controller.set_physics_process(true)
		if was_playing and game_controller.state == MainGameController.GameState.PAUSED:
			game_controller.toggle_pause()


## 상황: 메뉴 복귀 확인창에서 Yes를 선택했을 때 호출한다.
## 순서: modal 숨김 → 실행 중 게임 제거 예약 → 메뉴 창 크기 복원 → 메인 화면 표시.
## 결과: 다음 GAME START는 새 게임 인스턴스를 만들며 메인 메뉴 첫 버튼에 초점이 간다.
func _confirm_return_to_main_menu() -> void:
	_hide_game_exit_prompt()
	if _game_instance != null and is_instance_valid(_game_instance):
		_game_instance.queue_free()
	_game_instance = null
	_apply_menu_viewport_size()
	show_main_menu()


## 결과: 현재 로드된 게임의 authoritative controller를 찾거나 없으면 null을 반환한다.
func _loaded_game_controller() -> MainGameController:
	if _game_instance == null or not is_instance_valid(_game_instance):
		return null
	return _game_instance.get_node_or_null("GameController") as MainGameController


## 상황: 게임 전용 560×1140 창에서 시작 메뉴로 돌아가기 직전에 호출한다.
## 결과: content scale과 실제 창 크기를 메뉴 설계 크기 960×800으로 복원한다.
func _apply_menu_viewport_size() -> void:
	var window: Window = get_window()
	window.content_scale_size = MENU_VIEWPORT_SIZE
	if not DisplayServer.get_name().contains("headless"):
		window.size = MENU_VIEWPORT_SIZE


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


func _build_character_screen() -> void:
	var screen: Control = _create_screen("CharacterScreen", Screen.CHARACTER)
	_add_screen_title(screen, "캐릭터 선택", "다섯 능력치와 하나의 특수 스킬을 비교하세요")

	for index: int in range(MainCharacterData.CHARACTER_ORDER.size()):
		var character_id: String = MainCharacterData.CHARACTER_ORDER[index]
		var profile: Dictionary = MainCharacterData.profile_for(character_id)
		var card: Button = _create_button(
			screen,
			"",
			Rect2(50.0 + float(index) * 285.0, 142.0, 270.0, 354.0),
			CYAN,
			16
		)
		card.name = "Character_%s" % character_id
		card.pressed.connect(_select_character.bind(character_id))
		card.focus_entered.connect(_select_character.bind(character_id))
		card.focus_entered.connect(_play_select_sfx)
		_character_buttons.append(card)

		var portrait_texture := AtlasTexture.new()
		portrait_texture.atlas = MainCharacterAnimationData.texture_for(
			MainCharacterAnimationData.IDLE,
			character_id
		)
		portrait_texture.region = MainCharacterAnimationData.visible_region_for(
			MainCharacterAnimationData.IDLE,
			0.0,
			character_id
		)
		var portrait := TextureRect.new()
		portrait.position = Vector2(47.0, 12.0)
		portrait.size = Vector2(176.0, 158.0)
		portrait.texture = portrait_texture
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait)

		var stat_text: String = (
			"%s  [%s]\n%s\n\n공속 %d   이동 %d   점프 %d\n스태미나 %d   특수스킬 %d\n\n무기: %s"
			% [
				profile["display_name"],
				profile["unlock_text"],
				profile["role"],
				profile["attack_speed"],
				profile["move"],
				profile["jump"],
				profile["stamina"],
				profile["special_skill"],
				profile["weapon"],
			]
		)
		var info: Label = _create_label(
			card,
			stat_text,
			Rect2(12.0, 168.0, 246.0, 174.0),
			14,
			TEXT,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		info.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		info.add_theme_constant_override("line_spacing", 4)

	_character_prev_button = _create_button(
		screen, "◀", Rect2(6.0, 286.0, 38.0, 70.0), PURPLE, 19
	)
	_character_prev_button.focus_mode = Control.FOCUS_NONE
	_character_prev_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_character_next_button = _create_button(
		screen, "▶", Rect2(916.0, 286.0, 38.0, 70.0), PURPLE, 19
	)
	_character_next_button.focus_mode = Control.FOCUS_NONE
	_character_next_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var detail_panel: Panel = _create_panel(
		screen,
		Rect2(34.0, 516.0, 892.0, 160.0),
		PANEL,
		BORDER,
		10
	)
	_character_detail_label = _create_label(
		detail_panel,
		"",
		Rect2(22.0, 10.0, 848.0, 88.0),
		14,
		TEXT
	)
	_character_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_character_confirm_button = _create_button(
		detail_panel,
		"선택 완료",
		Rect2(472.0, 104.0, 238.0, 42.0),
		CYAN,
		16
	)
	_character_confirm_button.focus_mode = Control.FOCUS_NONE
	_character_confirm_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back_button: Button = _create_button(
		detail_panel,
		"뒤로",
		Rect2(720.0, 104.0, 150.0, 42.0),
		DANGER,
		16
	)
	_character_back_button = back_button
	back_button.pressed.connect(show_stage_select)
	back_button.focus_entered.connect(_play_select_sfx)
	_refresh_character_selection()


func _select_character(character_id: String) -> void:
	if not MainCharacterData.has_character(character_id):
		return
	_selected_character_id = character_id
	_refresh_character_selection()


func _shift_character_window(direction: int) -> void:
	var maximum_start: int = maxi(0, MainCharacterData.CHARACTER_ORDER.size() - 3)
	_character_window_start = clampi(_character_window_start + signi(direction), 0, maximum_start)
	if not _selected_character_id.is_empty():
		var selected_index: int = MainCharacterData.CHARACTER_ORDER.find(_selected_character_id)
		if selected_index < _character_window_start or selected_index >= _character_window_start + 3:
			_selected_character_id = ""
	_refresh_character_selection()


func _refresh_character_selection() -> void:
	if _character_detail_label == null:
		return
	var has_selection: bool = (
		not _selected_character_id.is_empty()
		and MainCharacterData.has_character(_selected_character_id)
	)
	if has_selection:
		var profile: Dictionary = MainCharacterData.profile_for(_selected_character_id)
		var detail_text: String = (
			"%s · %s\n특수 스킬: %s — %s\n기본 쿨다운 %.1f초 / 능력치 적용 %.1f초"
			% [
				profile["display_name"],
				profile["description"],
				profile["special_name"],
				profile["special_description"],
				float(profile["special_base_cooldown"]),
				MainCharacterData.special_cooldown(_selected_character_id),
			]
		)
		if profile.has("unlock_hint"):
			detail_text = (
				"%s · %s\n해금 힌트: “%s”\n특수 스킬: %s — %s\n기본 쿨다운 %.1f초 / 능력치 적용 %.1f초"
				% [
					profile["display_name"],
					profile["description"],
					profile["unlock_hint"],
					profile["special_name"],
					profile["special_description"],
					float(profile["special_base_cooldown"]),
					MainCharacterData.special_cooldown(_selected_character_id),
				]
			)
		_character_detail_label.text = detail_text
	else:
		_character_detail_label.text = "화면에 보이는 캐릭터 카드를 선택하세요.\n특수 스킬은 스태미나를 소모하지 않고 쿨다운만 사용합니다."
	_character_confirm_button.disabled = not has_selection
	var maximum_start: int = maxi(0, MainCharacterData.CHARACTER_ORDER.size() - 3)
	_character_prev_button.disabled = _character_window_start <= 0
	_character_next_button.disabled = _character_window_start >= maximum_start
	for index: int in range(_character_buttons.size()):
		var button: Button = _character_buttons[index]
		var visible_slot: int = index - _character_window_start
		button.visible = visible_slot >= 0 and visible_slot < 3
		if button.visible:
			button.position = Vector2(50.0 + float(visible_slot) * 285.0, 142.0)
			var left_button: Button = (
				_character_buttons[index - 1] if visible_slot > 0 else button
			)
			var right_button: Button = (
				_character_buttons[index + 1] if visible_slot < 2 else button
			)
			button.focus_neighbor_left = button.get_path_to(left_button)
			button.focus_neighbor_right = button.get_path_to(right_button)
			button.focus_neighbor_bottom = button.get_path_to(_character_back_button)
			button.focus_neighbor_top = button.get_path_to(button)
		var selected: bool = button.name == "Character_%s" % _selected_character_id
		button.add_theme_stylebox_override("normal", _character_card_style(selected))
		button.modulate = Color.WHITE if selected else Color(0.82, 0.85, 0.90, 0.88)
		for child: Node in button.get_children():
			if child is Label:
				(child as Label).add_theme_color_override(
					"font_color",
					Color.WHITE if selected else TEXT
				)
	if _character_back_button != null:
		_character_back_button.focus_neighbor_left = _character_back_button.get_path_to(_character_back_button)
		_character_back_button.focus_neighbor_right = _character_back_button.get_path_to(_character_back_button)
		_character_back_button.focus_neighbor_bottom = _character_back_button.get_path_to(_character_back_button)


func _character_card_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CYAN.darkened(0.72) if selected else PANEL
	style.border_color = CYAN if selected else BORDER
	style.set_border_width_all(3 if selected else 1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style


## 상황: 게임 설명의 canvas·탐색 버튼·counter·뒤로가기를 최초 조립할 때 호출된다.
## 순서: screen/title → TutorialCanvas 설정 주입 → prev/next/counter/back 생성과 signal 연결.
## 결과: page 멤버만 바꾸면 재사용 가능한 TUTORIAL 화면이 완성된다.
