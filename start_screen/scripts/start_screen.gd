class_name KungFuTetrisStartScreen
extends Control

## [역할 / C++ 대응]
## 시작 메뉴·튜토리얼·옵션·게임 host와 modal overlay를 소유하는 최상위 UI controller다.
## C++로 보면 화면 상태 enum을 가진 finite-state UI controller이자 scene factory/facade에 가깝다.
## 각 `Control` 자식은 parent가 수명을 소유하고, 이 클래스의 `_...` 멤버는 non-owning cache pointer처럼 쓴다.
## signal은 게임 로드와 종료 요청을 외부 shell에 알리는 observer callback이다.
##
## 호출자: start_screen.tscn, UI 테스트, Button signal.
## 호출 대상: StartScreenSettings, StartScreenUI, StartScreenTutorialCanvas, MainGameView scene.

signal game_loaded(game_root: Node) # 새 게임 scene이 host에 연결된 직후 외부에 전달한다.
signal exit_requested # 실제 quit 전에 상위 launcher가 요청을 관찰할 수 있게 한다.

const GAME_SCENE_DEFAULT: String = "res://scenes/main.tscn" # GAME START가 instantiate할 기본 PackedScene 경로.
const MENU_VIEWPORT_SIZE: Vector2i = Vector2i(960, 800) # 게임 종료 뒤 복원할 메뉴 논리 해상도.
const TUTORIAL_PAGE_COUNT: int = 5 # prev/next clamp와 counter가 공유할 페이지 수.
const PORTRAIT: Texture2D = preload(
	"res://assets/sprites/characters/normal/normal_atlas.png"
) # 메인 화면 기본 일반인 atlas.
const PORTRAIT_SOURCE: Rect2 = Rect2(0.0, 0.0, 128.0, 128.0) # idle 0 frame.
const BLOCK_TEXTURE: Texture2D = preload("res://assets/sprites/block_sprites.png") # 배경 장식 블록 atlas.
const CYAN_BLOCK_SOURCE: Rect2 = Rect2(80.0, 255.0, 210.0, 215.0) # cyan 장식 source rect.
const ORANGE_BLOCK_SOURCE: Rect2 = Rect2(1745.0, 255.0, 210.0, 215.0) # orange 장식 source rect.
const TUTORIAL_CANVAS_SCRIPT: Script = preload(
	"res://start_screen/scripts/tutorial_canvas.gd"
)
const UI_SCRIPT: Script = preload("res://start_screen/scripts/start_screen_ui.gd") # widget factory class resource.
const CHARACTER_DATA: Script = preload("res://scripts/character_data.gd")
const ANIMATION_DATA: Script = preload("res://scripts/character_animation_data.gd")
const SFX_SELECT: AudioStream = preload("res://assets/sfx/08_select.wav") # focus 이동 시 재생할 짧은 cue.

const BACKGROUND: Color = Color("#f7f8fb") # 전체 메뉴 배경.
const PANEL: Color = Color("#ffffff") # 밝은 카드 표면.
const PANEL_DARK: Color = Color("#eef2f7") # 보조 카드/버튼 표면.
const BORDER: Color = Color("#8390a3") # 공통 외곽선.
const TEXT: Color = Color("#152033") # 주 텍스트.
const MUTED: Color = Color("#344158") # 보조 설명 텍스트.
const CYAN: Color = Color("#2c8fd6") # 시작·이동·긍정 강조색.
const ORANGE: Color = Color("#e47719") # 튜토리얼·볼륨 강조색.
const PURPLE: Color = Color("#6f57c9") # 옵션·뒤로가기 강조색.
const DANGER: Color = Color("#d9485f") # 종료·취소 강조색.

enum Screen { # C++의 `enum class Screen`처럼 한 번에 보일 화면 상태를 제한한다.
	MAIN,
	CHARACTER,
	TUTORIAL,
	OPTIONS,
	KEY_CUSTOM,
	VOLUME,
	GAME,
}

@export_file("*.tscn") var game_scene_path: String = GAME_SCENE_DEFAULT # editor에서 교체 가능한 game factory 경로.
@export var settings_file_path: String = StartScreenSettings.DEFAULT_SETTINGS_PATH # cfg 저장 경로 injection point.
@export var suppress_quit_for_tests: bool = false # true면 EXIT signal만 보내고 process는 종료하지 않는다.

var settings: StartScreenSettings # 키·오디오 설정의 소유 child와 typed cache.
var current_screen: Screen = Screen.MAIN # 화면 state machine의 현재 enum 값.
var tutorial_page: int = 0 # 0부터 시작하는 현재 튜토리얼 page index.

var _font: SystemFont # 모든 메뉴 label/draw가 공유하는 한글 font resource.
var _ui: RefCounted # StartScreenUI factory 인스턴스.
var _screens: Dictionary = {} # Screen enum → 최상위 Control의 lookup table.
var _main_buttons: Array[Button] = [] # MAIN 화면 focus 순서와 첫 focus용 배열.
var _character_buttons: Array[Button] = [] # 캐릭터 카드 focus 순서.
var _character_confirm_button: Button # 선택 확정 후 게임을 여는 버튼.
var _character_detail_label: Label # 선택 캐릭터의 무기·특수 스킬 설명.
var _selected_character_id: String = MainCharacterData.DEFAULT_CHARACTER_ID
var _character_window_start: int = 0
var _character_prev_button: Button
var _character_next_button: Button
var _options_first_button: Button # OPTIONS 진입 시 focus를 줄 첫 카드 버튼.
var _key_buttons: Dictionary = {} # action → 주/보조 Button 배열.
var _key_status: Label # 키 변경 성공·실패 메시지 label.
var _tutorial_canvas: StartScreenTutorialCanvas # 12FPS 설명 그림을 그리는 child.
var _tutorial_counter: Label # `현재 / 전체` 페이지 표시.
var _tutorial_prev_button: Button # 이전 페이지 탐색 버튼 cache.
var _tutorial_next_button: Button # 다음 페이지 탐색 버튼 cache.
var _music_value_label: Label # BGM slider 옆 퍼센트 표시.
var _sfx_value_label: Label # SFX slider 옆 퍼센트 표시.
var _game_host: Control # instantiate한 MainGameView를 소유할 container.
var _game_instance: Node # 현재 실행 게임 root의 nullable cache.
var _game_exit_overlay: Control # 게임 중 메뉴 복귀 modal root.
var _game_exit_yes_button: Button # modal Yes focus/동작 cache.
var _game_exit_no_button: Button # modal No focus/동작 cache.
var _game_exit_was_playing: bool = false # modal 전 PLAYING이었는지 복원할 snapshot.
var _select_sfx_player: AudioStreamPlayer # menu focus cue 전용 channel.
var _select_sfx_timer: Timer # cue를 0.06초 뒤 잘라 중첩을 줄이는 one-shot timer.
var _skip_initial_select_sfx: bool = true # 첫 자동 focus에서 불필요한 cue를 막는 latch.

var _capture_overlay: Control # 다음 물리 키 하나를 받는 modal root.
var _capture_label: Label # 어떤 action/slot을 기다리는지 표시한다.
var _capture_action: StringName = &"" # 캡처 결과를 적용할 action; 빈 값은 비활성 sentinel.
var _capture_slot: int = -1 # 0=주 키, 1=보조 키, -1=비활성 sentinel.

var _message_overlay: Control # 설정/로드 오류를 표시할 단일 확인 modal.
var _message_label: Label # modal에서 동적으로 바뀌는 본문.


## 상황: start_screen.tscn의 root가 scene tree에 들어올 때 Godot가 한 번 호출한다.
## 순서: 입력 활성화 → font/factory/settings/audio 준비 → 모든 화면 build → 설정 표시 → MAIN 전환.
## 결과: 첫 frame 전에 화면 object graph와 signal 연결이 완성된다.
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


## 상황: queue_redraw 또는 첫 CanvasItem draw pass에서 메뉴 공통 배경을 그릴 때 호출된다.
## 순서: 단색 배경 → 48px 세로/가로 grid → 양쪽 장식 블록.
## 결과: retained UI child 뒤에 상태와 무관한 배경 픽셀이 그려진다.
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


## 상황: 시작 직후 또는 하위 화면/게임에서 MAIN으로 돌아갈 때 호출된다.
## 결과: 화면 state를 MAIN으로 바꾸고 첫 버튼 focus를 deferred 예약한다.
func show_main_menu() -> void:
	_show_screen(Screen.MAIN)


func show_character_select() -> void:
	_refresh_character_selection()
	_show_screen(Screen.CHARACTER)


## 상황: 사용자가 `게임 설명` 버튼을 선택했을 때 호출된다.
## 순서: page=0 → canvas/counter 갱신 → TUTORIAL 화면 전환.
## 결과: 항상 첫 설명 페이지부터 시작한다.
func show_tutorial() -> void:
	tutorial_page = 0
	_refresh_tutorial()
	_show_screen(Screen.TUTORIAL)


## 상황: MAIN의 OPTION 버튼 또는 하위 설정 화면의 뒤로가기로 호출된다.
## 결과: OPTIONS 카드 화면만 표시한다.
func show_options() -> void:
	_show_screen(Screen.OPTIONS)


## 상황: OPTIONS에서 키 설정 카드를 선택했을 때 호출된다.
## 순서: 최신 binding text refresh → KEY_CUSTOM 화면 전환.
## 결과: 저장된 키와 실제 버튼 문구가 일치한 상태로 열린다.
func show_key_custom() -> void:
	_refresh_key_buttons()
	_show_screen(Screen.KEY_CUSTOM)


## 상황: OPTIONS에서 볼륨 설정 카드를 선택했을 때 호출된다.
## 결과: 기존에 만든 VOLUME 화면을 표시한다.
func show_volume() -> void:
	_show_screen(Screen.VOLUME)


## 상황: 튜토리얼의 `다음` 버튼을 눌렀을 때 호출된다.
## 결과: 마지막 index를 넘지 않게 1 증가시키고 canvas/counter를 갱신한다.
func next_tutorial_page() -> void:
	tutorial_page = mini(tutorial_page + 1, TUTORIAL_PAGE_COUNT - 1)
	_refresh_tutorial()


## 상황: 튜토리얼의 `이전` 버튼을 눌렀을 때 호출된다.
## 결과: 0보다 작아지지 않게 1 감소시키고 canvas/counter를 갱신한다.
func previous_tutorial_page() -> void:
	tutorial_page = maxi(tutorial_page - 1, 0)
	_refresh_tutorial()


## 상황: MAIN의 GAME START가 선택되었을 때 호출된다.
## 순서: 기존 instance guard → PackedScene 경로/타입 검사 → instantiate/add_child → GAME 전환/signal.
## 결과: 성공하면 true와 실행 중 instance를 남기고, 실패하면 modal을 띄운 뒤 false를 반환한다.
func start_game() -> bool:
	if _selected_character_id.is_empty() or not MainCharacterData.has_character(_selected_character_id):
		_show_message("먼저 화면에 보이는 캐릭터를 선택하세요.")
		return false
	if _game_instance != null and is_instance_valid(_game_instance):
		return true
	if not ResourceLoader.exists(game_scene_path, "PackedScene"):
		_show_message("게임 장면을 찾을 수 없습니다.\n%s" % game_scene_path)
		return false

	var game_resource: Resource = load(game_scene_path) # runtime type 검사 전의 범용 resource handle.
	if not game_resource is PackedScene:
		_show_message("게임 장면을 불러올 수 없습니다.\n%s" % game_scene_path)
		return false

	_game_instance = (game_resource as PackedScene).instantiate()
	_game_instance.name = "LoadedGame"
	_game_host.add_child(_game_instance)
	var selected_character: MainCharacterController = _game_instance.get_node_or_null(
		"BoardPhysics/Character"
	) as MainCharacterController
	if selected_character != null:
		selected_character.set_character_id(_selected_character_id)
	_show_screen(Screen.GAME)
	game_loaded.emit(_game_instance)
	return true


## 상황: MAIN의 EXIT 버튼이 선택되었을 때 호출된다.
## 순서: 외부 signal emit → 테스트 억제 flag가 false일 때 SceneTree quit.
## 결과: launcher 관찰 기회를 보장하면서 실제 앱 종료를 요청한다.
func request_exit() -> void:
	exit_requested.emit()
	if not suppress_quit_for_tests:
		get_tree().quit()


## 상황: 키 설정 화면의 주/보조 키 버튼을 눌렀을 때 호출된다.
## 순서: 대상 action/slot 저장 → 안내문 구성 → capture modal 표시/최상단 이동.
## 결과: 다음 유효 키 event를 `_handle_key_capture()`가 해당 슬롯에 적용한다.
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


## 상황: 캡처 성공 또는 취소 버튼으로 key capture를 끝낼 때 호출된다.
## 결과: 대상 sentinel을 초기화하고 overlay를 숨긴다.
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
	elif _handle_menu_confirm_input(key_event):
		get_viewport().set_input_as_handled()


## 상황: 일반 GUI가 소비하지 않은 키를 캡처·뒤로가기 용도로 처리할 때 호출된다.
## 순서: key/press/echo 검사 → capture 우선 → back navigation → 처리된 event 표시.
## 결과: 메뉴의 기본 GUI 입력과 custom global navigation이 중복 실행되지 않는다.
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


## 상황: capture overlay가 열린 동안 다음 key event가 도착하면 호출된다.
## 순서: overlay guard → physical/logical key 추출 → settings validation/commit → 결과 표시 → 성공 시 닫기.
## 결과: overlay가 처리했으면 성공 여부와 관계없이 true를 반환해 event 전파를 막는다.
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


## 상황: 게임 밖에서 Esc로 상위 메뉴로 돌아갈 수 있는지 판단할 때 호출된다.
## 순서: GAME/비Esc 조기 반환 → 현재 screen에 따라 MAIN 또는 OPTIONS로 전환.
## 결과: navigation을 수행했을 때만 true를 반환한다.
func _handle_back_navigation(key_event: InputEventKey) -> bool:
	if current_screen == Screen.GAME:
		return false
	if not _is_escape_key(key_event):
		return false

	match current_screen:
		Screen.CHARACTER, Screen.TUTORIAL, Screen.OPTIONS:
			show_main_menu()
		Screen.KEY_CUSTOM, Screen.VOLUME:
			show_options()
		_:
			return false
	return true


## 상황: `_ready()`가 모든 화면과 modal의 object graph를 한 번 구성할 때 호출된다.
## 순서: game host 생성 → 5개 화면 builder → 3개 overlay builder.
## 결과: 이후 화면 전환은 새 노드 생성 없이 visible flag만 바꿀 수 있다.
func _build_interface() -> void:
	_game_host = Control.new()
	_game_host.name = "GameHost"
	_game_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_host.visible = false
	add_child(_game_host)

	_build_main_screen()
	_build_character_screen()
	_build_tutorial_screen()
	_build_options_screen()
	_build_key_screen()
	_build_volume_screen()
	_build_capture_overlay()
	_build_message_overlay()
	_build_game_exit_overlay()


## 상황: MAIN 화면을 최초 한 번 조립할 때 호출된다.
## 순서: screen/panel/title/portrait/네 버튼/footer 생성 → callback/focus cue 연결.
## 결과: `_main_buttons`에 키보드 순서가 보존된 메뉴 화면이 완성된다.
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
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(portrait)

	var button_data: Array = [
		["GAME START", CYAN, show_character_select],
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
		portrait_texture.region = PORTRAIT_SOURCE
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
	_character_prev_button.pressed.connect(_shift_character_window.bind(-1))
	_character_prev_button.focus_entered.connect(_play_select_sfx)
	_character_next_button = _create_button(
		screen, "▶", Rect2(916.0, 286.0, 38.0, 70.0), PURPLE, 19
	)
	_character_next_button.pressed.connect(_shift_character_window.bind(1))
	_character_next_button.focus_entered.connect(_play_select_sfx)

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
		"이 캐릭터로 시작",
		Rect2(472.0, 104.0, 238.0, 42.0),
		CYAN,
		16
	)
	_character_confirm_button.pressed.connect(start_game)
	_character_confirm_button.focus_entered.connect(_play_select_sfx)
	var back_button: Button = _create_button(
		detail_panel,
		"뒤로",
		Rect2(720.0, 104.0, 150.0, 42.0),
		DANGER,
		16
	)
	back_button.pressed.connect(show_main_menu)
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
		var selected: bool = button.name == "Character_%s" % _selected_character_id
		button.add_theme_stylebox_override("normal", _character_card_style(selected))
		button.modulate = Color.WHITE if selected else Color(0.82, 0.85, 0.90, 0.88)
		for child: Node in button.get_children():
			if child is Label:
				(child as Label).add_theme_color_override(
					"font_color",
					Color.WHITE if selected else TEXT
				)


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


## 상황: KEY CUSTOM과 VOLUME으로 갈 수 있는 두 카드형 선택지를 만들 때 호출된다.
## 결과: 첫 카드 참조를 focus용으로 보존하고 MAIN 복귀 버튼까지 연결한다.
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


## 상황: OPTIONS의 반복되는 제목·설명·버튼 카드 하나를 생성할 때 호출된다.
## 순서: Panel → 제목 Label → 설명 Label → Button/callback.
## 결과: 호출자가 첫 focus 등에 사용할 Button 참조를 반환한다.
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


## 상황: 전체 키 설정 화면을 최초 조립할 때 호출된다.
## 순서: screen/title → 열 header → action 행 → status/reset/back footer.
## 결과: 설정 정의 수에 맞는 KEY_CUSTOM 화면이 만들어진다.
func _build_key_screen() -> void:
	var screen: Control = _create_screen("KeyCustomScreen", Screen.KEY_CUSTOM)
	_add_screen_title(screen, "KEY CUSTOM", "버튼을 누른 뒤 새 키를 입력하세요")
	_build_key_headers(screen)
	_build_key_rows(screen)
	_build_key_footer(screen)


## 상황: 키 설정 표의 동작·주 키·보조 키 열 제목을 그릴 때 호출된다.
## 결과: 입력을 받지 않는 세 Label이 고정 위치에 추가된다.
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


## 상황: StartScreenSettings의 action 정의 전체를 화면 행으로 확장할 때 호출된다.
## 순서: typed 정의 복사 조회 → index와 정의를 `_build_key_row()`에 전달.
## 결과: 정의 순서가 화면 순서와 focus 순서가 된다.
func _build_key_rows(screen: Control) -> void:
	var definitions: Array[Dictionary] = settings.get_action_definitions() # 수정 가능한 UI용 metadata snapshot.
	for index: int in range(definitions.size()):
		_build_key_row(screen, definitions[index], index)


## 상황: 입력 action 하나를 한글 label과 주/보조 key control 행으로 만들 때 호출된다.
## 순서: y 계산/stripe → action label → primary button → secondary control → cache 등록.
## 결과: `_refresh_key_buttons()`가 action 이름으로 두 버튼을 다시 찾을 수 있다.
func _build_key_row(screen: Control, definition: Dictionary, index: int) -> void:
	var action_name: StringName = definition["action"] # signal bind와 lookup key로 쓸 내부 식별자.
	var y_value: float = 150.0 + index * 40.0 # 표의 index를 pixel y로 바꾼 값.
	_add_key_row_stripe(screen, y_value, index % 2 == 0)
	_create_label(
		screen,
		String(definition["label"]),
		Rect2(108.0, y_value + 5.0, 210.0, 26.0),
		15,
		TEXT
	)

	var action_buttons: Array[Button] = [] # 주/보조 순서를 유지하는 per-action cache.
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


## 상황: 긴 키 설정 표에서 짝수 행 배경을 넣어 가독성을 높일 때 호출된다.
## 결과: visible=false면 비용 없이 반환하고, true면 input을 막지 않는 ColorRect를 추가한다.
func _add_key_row_stripe(screen: Control, y_value: float, visible: bool) -> void:
	if not visible:
		return
	var stripe: ColorRect = ColorRect.new()
	stripe.position = Vector2(96.0, y_value - 2.0)
	stripe.size = Vector2(768.0, 38.0)
	stripe.color = Color(0.86, 0.89, 0.93, 0.82)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(stripe)


## 상황: action의 slot_count에 따라 보조 키 UI를 다르게 구성할 때 호출된다.
## 순서: 단일 슬롯이면 `—` 표시/return → 아니면 secondary와 clear 버튼 생성·callback 연결.
## 결과: 두 슬롯 action만 보조 Button이 action_buttons에 추가된다.
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


## 상황: 키 설정 표 아래 상태 메시지·기본값 복원·뒤로가기 영역을 만들 때 호출된다.
## 결과: `_key_status` cache와 두 동작 Button이 연결된다.
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


## 상황: 두 audio bus를 조절하는 VOLUME 화면을 최초 구성할 때 호출된다.
## 순서: screen/title/panel → BGM row → SFX row → 설명/back.
## 결과: slider signal과 퍼센트 label cache가 준비된다.
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


## 상황: 이름·slider·퍼센트로 구성된 볼륨 행 하나를 반복 생성할 때 호출된다.
## 순서: 이름 Label → HSlider/value_changed 연결 → 현재값 Label.
## 결과: 호출자가 이후 text를 갱신할 퍼센트 Label을 반환한다.
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
	var slider: HSlider = _create_slider( # Audio 값 변경 signal의 송신자.
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


## 상황: 새 키 하나를 받을 때 다른 화면 입력을 가리는 capture modal을 최초 구성한다.
## 순서: full-screen root/shade → panel/title/dynamic label → 취소 Button.
## 결과: 평소에는 숨고 `begin_key_capture()`가 대상 정보를 채워 표시한다.
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


## 상황: 설정 오류나 game scene load 오류를 표시할 공통 modal을 최초 구성한다.
## 순서: full-screen root/shade → panel/title/dynamic body → 확인 Button.
## 결과: `_show_message()`가 문자열만 바꿔 여러 오류에 재사용할 수 있다.
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


## 상황: 게임 중 Esc로 메인 메뉴 복귀 여부를 물을 modal UI를 준비한다.
## 호출: `_build_interface()`가 일반 화면과 다른 overlay를 모두 만든 뒤 한 번 호출한다.
## 결과: 질문과 Yes/No 버튼이 생성되며 실제 요청 전까지 숨김 상태를 유지한다.
func _build_game_exit_overlay() -> void:
	_game_exit_overlay = Control.new()
	_game_exit_overlay.name = "GameExitOverlay"
	_game_exit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
		Rect2(230.0, 390.0, 540.0, 280.0),
		PANEL,
		PURPLE,
		12
	)
	_create_label(
		panel,
		"메뉴로 나가겠습니까?",
		Rect2(40.0, 52.0, 460.0, 52.0),
		25,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_game_exit_yes_button = _create_button(
		panel,
		"Yes",
		Rect2(72.0, 166.0, 180.0, 52.0),
		CYAN,
		16
	)
	_game_exit_yes_button.name = "GameExitYesButton"
	_game_exit_yes_button.pressed.connect(_confirm_return_to_main_menu)
	_game_exit_no_button = _create_button(
		panel,
		"No",
		Rect2(288.0, 166.0, 180.0, 52.0),
		DANGER,
		16
	)
	_game_exit_no_button.name = "GameExitNoButton"
	_game_exit_no_button.pressed.connect(_hide_game_exit_prompt)


## 상황: 일반 화면 또는 GAME host 중 정확히 하나만 보이게 state transition할 때 호출된다.
## 순서: current_screen 저장 → 모든 일반 화면 숨김 → GAME host 또는 대상 screen 표시 → 기본 focus 예약.
## 결과: node를 재생성하지 않고 visible 상태와 키보드 focus가 일관되게 바뀐다.
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
		Screen.CHARACTER:
			if not _character_buttons.is_empty():
				_character_buttons[0].grab_focus.call_deferred()
		Screen.TUTORIAL:
			_tutorial_next_button.grab_focus.call_deferred()
		Screen.OPTIONS:
			if _options_first_button != null:
				_options_first_button.grab_focus.call_deferred()
		_:
			pass


## 상황: page가 바뀌거나 튜토리얼이 처음 열릴 때 호출된다.
## 순서: canvas page reset → counter text → 첫/마지막 탐색 버튼 disabled 계산.
## 결과: animation 시간과 navigation UI가 같은 page index를 나타낸다.
func _refresh_tutorial() -> void:
	if _tutorial_canvas == null:
		return
	_tutorial_canvas.set_page(tutorial_page)
	_tutorial_counter.text = "%d / %d" % [tutorial_page + 1, TUTORIAL_PAGE_COUNT]
	_tutorial_prev_button.disabled = tutorial_page == 0
	_tutorial_next_button.disabled = tutorial_page == TUTORIAL_PAGE_COUNT - 1


## 상황: 설정 load/변경 signal 또는 KEY_CUSTOM 진입 시 버튼 문구를 동기화할 때 호출된다.
## 순서: action→button cache 순회 → slot text 대입 → tutorial redraw 요청.
## 결과: 키 설정 표와 설명 화면이 같은 authoritative binding을 표시한다.
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


## 상황: 보조 키 행의 `지우기` 버튼 callback으로 호출된다.
## 결과: Settings의 검증 결과를 공통 상태 Label 표시 함수에 전달한다.
func _clear_secondary(action_name: StringName) -> void:
	var result: Dictionary = settings.clear_secondary_binding(action_name)
	_show_binding_result(result)


## 상황: 키 변경·삭제 API의 `{ok,message}` 결과를 화면에 표시할 때 호출된다.
## 결과: 본문은 message, 색은 성공 CYAN/실패 DANGER로 갱신된다.
func _show_binding_result(result: Dictionary) -> void:
	_key_status.text = String(result.get("message", ""))
	_key_status.modulate = CYAN if bool(result.get("ok", false)) else DANGER


## 상황: 사용자가 `기본값 복원`을 선택했을 때 호출된다.
## 결과: Settings reset을 실행하고 성공 안내를 고정 문구와 색으로 표시한다.
func _reset_keys() -> void:
	settings.reset_bindings_to_defaults()
	_key_status.text = "모든 키를 기본값으로 복원했습니다."
	_key_status.modulate = CYAN


## 상황: BGM slider의 value_changed signal이 float 값을 보낼 때 호출된다.
## 결과: Settings/AudioServer/파일을 갱신하고 옆 퍼센트 Label을 즉시 바꾼다.
func _on_music_changed(value: float) -> void:
	settings.set_music_percent(value)
	_music_value_label.text = "%d%%" % roundi(value)


## 상황: SFX slider의 value_changed signal이 float 값을 보낼 때 호출된다.
## 결과: Settings/AudioServer/파일을 갱신하고 옆 퍼센트 Label을 즉시 바꾼다.
func _on_sfx_changed(value: float) -> void:
	settings.set_sfx_percent(value)
	_sfx_value_label.text = "%d%%" % roundi(value)


## 상황: 설정·resource load 오류를 사용자에게 modal로 알려야 할 때 호출된다.
## 결과: overlay가 준비된 경우 본문을 교체하고 표시한 뒤 최상단으로 옮긴다.
func _show_message(message: String) -> void:
	if _message_overlay == null:
		return
	_message_label.text = message
	_message_overlay.visible = true
	_message_overlay.move_to_front()


## 상황: 공통 안내 modal의 확인 버튼이 눌렸을 때 호출된다.
## 결과: 저장된 본문은 유지하고 overlay만 숨긴다.
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
## 결과: modal만 닫고 확인창 이전의 게임 상태와 입력 처리를 복원한다.
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


## 상황: 게임 전용 1000×1080 창에서 시작 메뉴로 돌아가기 직전에 호출한다.
## 결과: content scale과 실제 창 크기를 메뉴 설계 크기 960×800으로 복원한다.
func _apply_menu_viewport_size() -> void:
	var window: Window = get_window()
	window.content_scale_size = MENU_VIEWPORT_SIZE
	if not DisplayServer.get_name().contains("headless"):
		window.size = MENU_VIEWPORT_SIZE


## 상황: menu focus가 새 Button으로 이동했을 때 짧은 선택음을 재생할 callback이다.
## 순서: 첫 자동 focus는 latch로 무시 → stream/play → stop timer 시작.
## 결과: 빠른 focus 이동에도 각 cue가 짧게 끊겨 과도한 중첩을 줄인다.
func _play_select_sfx() -> void:
	if _skip_initial_select_sfx:
		_skip_initial_select_sfx = false
		return
	_select_sfx_player.stream = SFX_SELECT
	_select_sfx_player.play()
	_select_sfx_timer.start()


## 상황: builder가 Screen enum에 대응하는 full-rect root를 하나 만들 때 호출된다.
## 순서: Control 생성/이름/anchor/숨김 → root add_child → lookup table 등록.
## 결과: parent가 소유하는 Control 참조를 반환한다.
func _create_screen(screen_name: String, screen_type: Screen) -> Control:
	var screen: Control = Control.new()
	screen.name = screen_name
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.visible = false
	add_child(screen)
	_screens[screen_type] = screen
	return screen


## 상황: TUTORIAL/OPTIONS/KEY/VOLUME 화면에 공통 제목 영역을 추가할 때 호출된다.
## 결과: 제목·부제 Label과 입력을 무시하는 구분선이 parent에 추가된다.
func _add_screen_title(parent: Control, title: String, subtitle: String) -> void:
	_create_label(parent, title, Rect2(70.0, 48.0, 430.0, 52.0), 34, TEXT)
	_create_label(parent, subtitle, Rect2(72.0, 98.0, 700.0, 28.0), 15, MUTED)
	var line: ColorRect = ColorRect.new()
	line.position = Vector2(70.0, 125.0)
	line.size = Vector2(820.0, 2.0)
	line.color = Color(0.22, 0.85, 1.0, 0.45)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


## 상황: StartScreen 내부 builder가 UI factory의 panel 생성을 짧게 호출할 때 쓰는 facade다.
## 결과: `_ui.create_panel()`의 반환값과 소유권 규칙을 그대로 전달한다.
func _create_panel(
	parent: Control,
	rect: Rect2,
	background: Color,
	border: Color,
	radius: int
) -> Panel:
	return _ui.create_panel(parent, rect, background, border, radius)


## 상황: StartScreen 내부 builder가 공통 Label factory를 호출할 때 쓰는 facade다.
## 결과: 전달받은 텍스트·rect·font·색·정렬로 생성된 Label을 반환한다.
func _create_label(
	parent: Control,
	text_value: String,
	rect: Rect2,
	font_size: int,
	color: Color,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	return _ui.create_label(parent, text_value, rect, font_size, color, alignment)


## 상황: StartScreen 내부 builder가 공통 Button factory를 호출할 때 쓰는 facade다.
## 결과: signal 연결 전의 focus 가능한 Button을 반환한다.
func _create_button(
	parent: Control,
	text_value: String,
	rect: Rect2,
	accent: Color,
	font_size: int
) -> Button:
	return _ui.create_button(parent, text_value, rect, accent, font_size)


## 상황: 볼륨 화면이 공통 Slider factory를 호출할 때 쓰는 facade다.
## 결과: 0~100 범위로 구성되어 parent에 연결된 HSlider를 반환한다.
func _create_slider(parent: Control, rect: Rect2, initial_value: float) -> HSlider:
	return _ui.create_slider(parent, rect, initial_value)


## 상황: `_draw()`가 메뉴 모서리에 반투명 테트로미노 장식을 그릴 때 호출된다.
## 순서: 네 로컬 셀 정의 → 색에 따른 atlas 영역 선택 → 셀별 destination에 texture region draw.
## 결과: scene node를 만들지 않는 즉시-mode 장식만 현재 draw pass에 남긴다.
func _draw_decorative_blocks(origin: Vector2, color: Color, alpha: float) -> void:
	var cells: Array[Vector2i] = [ # C++의 지역 고정 좌표 배열에 해당하는 S 모양 네 칸.
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(2, 1),
	]
	var source_region: Rect2 = CYAN_BLOCK_SOURCE if color == CYAN else ORANGE_BLOCK_SOURCE # atlas 선택 결과.
	for cell: Vector2i in cells:
		draw_texture_rect_region(
			BLOCK_TEXTURE,
			Rect2(origin + Vector2(cell) * 30.0, Vector2(27.0, 27.0)),
			source_region,
			Color(1.0, 1.0, 1.0, alpha)
		)
