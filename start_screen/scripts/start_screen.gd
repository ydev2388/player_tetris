class_name BlockFighterStartScreen
extends Control

signal game_loaded(game_root: Node)
signal exit_requested

const GAME_SCENE_DEFAULT: String = "res://scenes/main.tscn"
const MENU_VIEWPORT_SIZE: Vector2i = Vector2i(960, 800)
const TUTORIAL_PAGE_COUNT: int = 5
const PORTRAIT_SOURCE: Rect2 = Rect2(0.0, 0.0, 128.0, 128.0)
const BLOCK_TEXTURE: Texture2D = preload("res://assets/sprites/block_sprites.png")
const UI_FONT: FontFile = preload("res://assets/fonts/NotoSansKR-VF.ttf")
const CYAN_BLOCK_SOURCE: Rect2 = Rect2(80.0, 255.0, 210.0, 215.0)
const ORANGE_BLOCK_SOURCE: Rect2 = Rect2(1745.0, 255.0, 210.0, 215.0)
const TUTORIAL_CANVAS_SCRIPT: Script = preload(
	"res://start_screen/scripts/tutorial_canvas.gd"
)
const UI_SCRIPT: Script = preload("res://start_screen/scripts/start_screen_ui.gd")
const CHARACTER_DATA: Script = preload("res://scripts/character_data.gd")
const ANIMATION_DATA: Script = preload("res://scripts/character_animation_data.gd")
const LOCALIZATION: Script = preload("res://scripts/localization.gd")
const MUSIC_MANAGER_SCRIPT: Script = preload(
	"res://start_screen/scripts/music_manager.gd"
)
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
const SHOP_GOLD: Color = Color("#d8b23a")
const _CHARACTER_INSELECT_MODULATE: Color = Color(0.82, 0.85, 0.90, 0.88)
const _SHOP_CARD_COLUMNS: int = 4
const _FLOORS_PER_GROUP: int = 5
const _FLOOR_GROUP_COUNT: int = 2
const _SHOP_CARD_SIZE: Vector2 = Vector2(160.0, 158.0)
const _SHOP_CARD_GAP: float = 16.0
const _SHOP_GRID_WIDTH: float = 760.0
const _SHOP_ICON_DIR: String = "res://assets/sprites/shop/"
const _SHOP_ICON_FILES: Array[String] = [
	"attack_speed.png",
	"movement_speed.png",
	"jump.png",
	"stamina.png",
	"special_attack.png",
	"health.png",
]
const ENGLISH_TEXT: Dictionary = {
	"게임 설명": "GAME GUIDE", "↑ ↓ 선택    Z 확인": "UP/DOWN Select    Z Confirm",
	"별 0개": "0 Stars", "캐릭터 선택": "SELECT CHARACTER", "블록 깨러 가기": "START STAGE",
	"상점": "SHOP", "메인으로": "MAIN MENU", "상점 선택": "SHOP",
	"강화": "UPGRADES", "도전 모드": "CHALLENGE MODE",
	"최고 기록 %d줄": "BEST %d LINES", "10층 클리어 후 해금": "CLEAR 10F TO UNLOCK",
	"선택 후 Z로 강화": "Press Z to upgrade", "스테이지 선택으로": "STAGE SELECT",
	"패시브 초기화": "RESET PASSIVES", "키 설정과 사운드 크기를 조절합니다": "Adjust key bindings, language, and sound.",
	"이동·액션·시스템 키를\n원하는 키로 변경합니다.": "Change movement, action, and\nsystem keys.",
	"키 설정 열기": "OPEN KEY SETTINGS", "BGM과 효과음의 크기를\n각각 조절합니다.": "Adjust BGM and sound\neffect volume.",
	"볼륨 설정 열기": "OPEN VOLUME SETTINGS", "진행 데이터 초기화": "RESET PROGRESS",
	"스테이지 해금과 별 재화를 지웁니다.": "Deletes stage unlocks and stars.",
	"진행 상황 삭제": "DELETE PROGRESS", "버튼을 누른 뒤 새 키를 입력하세요": "Select a button, then press a new key.",
	"동작": "ACTION", "주 키": "PRIMARY", "보조 키": "SECONDARY", "지우기": "CLEAR",
	"기본값 복원": "RESTORE DEFAULTS", "OPTION으로": "BACK TO OPTIONS",
	"향후 추가되는 음악과 효과음에도 설정이 유지됩니다": "These settings apply to future music and effects too.",
	"BGM은 추후 추가되며 현재는 효과음만 조절합니다.": "BGM will be added later; only sound effects can be adjusted now.",
	"BGM은 추후 추가 예정입니다.\n0%는 음소거입니다.": "BGM will be added later.\n0% is muted.",
	"0%는 음소거입니다. 음악은 BGM 버스,\n효과음은 SFX 버스를 지정하면 이 설정을 사용합니다.": "0% is muted. Music uses BGM and effects use SFX.",
	"새 키 입력": "NEW KEY", "취소": "CANCEL", "안내": "NOTICE", "확인": "OK",
	"진행 데이터를 삭제할까요?": "Delete progress data?", "스테이지 해금, 도전 기록, 별 재화와 패시브가 초기화됩니다.": "Stage unlocks, challenge records, stars, and passives will be reset.",
	"삭제": "DELETE", "패시브를 초기화할까요?": "Reset passive upgrades?",
	"투자한 별을 모두 돌려받습니다.": "All invested stars will be refunded.", "초기화": "RESET",
	"메뉴로 나가겠습니까?": "Return to the main menu?", "뒤로": "BACK",
	"실패": "FAILED", "스테이지 제한시간이 끝났습니다.": "The stage time limit expired.", "재시도": "RETRY",
}
const CHINESE_TEXT: Dictionary = {
	"게임 설명": "游戏说明", "↑ ↓ 선택    Z 확인": "上下选择    Z确认",
	"캐릭터 선택": "选择角色", "블록 깨러 가기": "开始关卡", "상점": "商店", "메인으로": "主菜单",
	"상점 선택": "选择商店", "강화": "强化", "도전 모드": "挑战模式",
	"최고 기록 %d줄": "最高纪录 %d 行", "10층 클리어 후 해금": "通关 10 层后解锁",
	"선택 후 Z로 강화": "选择后按 Z 强化", "스테이지 선택으로": "关卡选择",
	"패시브 초기화": "重置被动", "키 설정과 사운드 크기를 조절합니다": "调整按键、语言和音量。",
	"이동·액션·시스템 키를\n원하는 키로 변경합니다.": "修改移动、动作和\n系统按键。",
	"키 설정 열기": "打开按键设置", "BGM과 효과음의 크기를\n각각 조절합니다.": "分别调整 BGM 和\n音效音量。",
	"볼륨 설정 열기": "打开音量设置", "진행 데이터 초기화": "重置进度数据",
	"스테이지 해금과 별 재화를 지웁니다.": "删除关卡解锁和星星。",
	"진행 상황 삭제": "删除进度", "버튼을 누른 뒤 새 키를 입력하세요": "选择按钮后输入新按键。",
	"동작": "动作", "주 키": "主键", "보조 키": "副键", "지우기": "清除",
	"기본값 복원": "恢复默认", "OPTION으로": "返回选项",
	"향후 추가되는 음악과 효과음에도 설정이 유지됩니다": "此设置也会用于之后添加的音乐和音效。",
	"BGM은 추후 추가되며 현재는 효과음만 조절합니다.": "背景音乐将在之后添加；目前只能调节音效。",
	"BGM은 추후 추가 예정입니다.\n0%는 음소거입니다.": "背景音乐将在之后添加。\n0% 为静音。",
	"0%는 음소거입니다. 음악은 BGM 버스,\n효과음은 SFX 버스를 지정하면 이 설정을 사용합니다.": "0% 为静音。音乐使用 BGM 总线，\n音效使用 SFX 总线。",
	"새 키 입력": "输入新按键", "취소": "取消", "안내": "提示", "확인": "确定",
	"진행 데이터를 삭제할까요?": "要删除进度数据吗？", "스테이지 해금, 도전 기록, 별 재화와 패시브가 초기화됩니다.": "关卡解锁、挑战记录、星星和被动强化将被重置。",
	"삭제": "删除", "패시브를 초기화할까요?": "要重置被动强化吗？",
	"투자한 별을 모두 돌려받습니다.": "将返还所有投入的星星。", "초기화": "重置",
	"메뉴로 나가겠습니까?": "要返回主菜单吗？", "뒤로": "返回",
	"실패": "失败", "스테이지 제한시간이 끝났습니다.": "关卡限制时间已结束。", "재시도": "重试",
	"DATA 초기화": "重置数据", "뒤로가기": "返回", "LANGUAGE": "语言",
	"GAME START": "开始游戏", "OPTION": "选项", "EXIT": "退出", "STAGE SELECT": "关卡选择",
	"KEY": "按键", "VOLUME": "音量", "KEY CUSTOM": "按键设置", "BGM": "背景音乐", "SFX": "音效",
	"← 이전": "← 上一页", "다음 →": "下一页 →", "  보스": "  首领",
	"별 %d개": "%d 颗星", "입장 가능": "可进入", "잠김": "未解锁",
	"현재 효과: 목숨 +%d · Lv. %d / %d": "当前效果：生命 +%d · 等级 %d / %d",
	"현재 효과: %s%d%% · Lv. %d / %d": "当前效果：%s%d%% · 等级 %d / %d",
	"최대 레벨": "最高等级", "다음 비용 ★ %d": "下一级费用 ★ %d",
	"%d층 클리어!\n%s": "%d层通关！\n%s", "별 보상 +%d   (보유 %d)": "星星奖励 +%d   (持有 %d)",
}

enum Screen {
	MAIN,
	FLOOR_SELECT,
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

var _font: Font
var _ui: RefCounted
var _screens: Dictionary = {}
var _main_buttons: Array[Button] = []
var _stage_panels: Array[Panel] = []
var _stage_buttons: Array[Button] = []
var _stage_labels: Array[Label] = []
var _stage_title_labels: Array[Label] = []
var _floor_group_buttons: Array[Button] = []
var _selected_floor_group: int = 0
var _stage_currency_label: Label
var _challenge_button: Button
var _shop_currency_label: Label
var _shop_cards: Array[Button] = []
var _shop_level_labels: Array[Label] = []
var _shop_icon_textures: Array = []
var _selected_shop_index: int = 0
var _shop_detail_name: Label
var _shop_detail_description: Label
var _shop_detail_effect: Label
var _shop_detail_cost: Label
var _shop_reset_button: Button
var _shop_back_button: Button
var _character_buttons: Array[Button] = []
var _character_unlock_labels: Array[Label] = []
var _character_confirm_button: Button
var _character_back_button: Button
var _character_position_labels: Array[Label] = []
var _selected_character_id: String = MainCharacterData.DEFAULT_CHARACTER_ID
var _character_card_selected_style: StyleBoxFlat
var _character_card_normal_style: StyleBoxFlat
var _character_prev_button: Button
var _character_next_button: Button
var _options_first_button: Button
var _language_button: Button
var _selected_language: String = StartScreenSettings.ENGLISH
var _key_buttons: Dictionary = {}
var _key_status: Label
var _tutorial_canvas: StartScreenTutorialCanvas
var _tutorial_counter: Label
var _tutorial_prev_button: Button
var _tutorial_next_button: Button
var _music_value_label: Label
var _sfx_value_label: Label
var _game_host: Control
var _game_viewport_container: SubViewportContainer
var _game_viewport: SubViewport
var _game_instance: Node
var _game_exit_overlay: Control
var _game_exit_yes_button: Button
var _game_exit_no_button: Button
var _game_exit_was_playing: bool = false
var _message_game_was_playing: bool = false
var _select_sfx_player: AudioStreamPlayer
var _select_sfx_timer: Timer
var _skip_initial_select_sfx: bool = true
var _menu_confirm_z_armed: bool = true
var _music_manager: BlockFighterMusicManager

var _capture_overlay: Control
var _capture_label: Label
var _capture_action: StringName = &""
var _capture_slot: int = -1

var _message_overlay: Control
var _message_label: Label
var _message_okay_button: Button
var _message_previous_focus: Control
var _stage_result_overlay: Control
var _stage_result_label: Label
var _stage_result_reward_label: Label
var _stage_result_button: Button
var _stage_fail_overlay: Control
var _stage_fail_retry_button: Button
var _stage_fail_select_button: Button
var _progress_reset_overlay: Control
var _progress_reset_yes_button: Button
var _progress_reset_no_button: Button
var _passive_reset_overlay: Control
var _passive_reset_yes_button: Button
var _passive_reset_no_button: Button


func _ready() -> void:
	set_process_input(true)
	set_process_unhandled_key_input(true)
	_font = UI_FONT
	_ui = UI_SCRIPT.new(_font, PANEL_DARK, BORDER, TEXT)

	settings = StartScreenSettings.new(settings_file_path)
	settings.name = "StartScreenSettings"
	settings.settings_error.connect(_show_message)
	settings.bindings_changed.connect(_refresh_key_buttons)
	settings.progress_changed.connect(_refresh_stage_select)
	settings.progress_changed.connect(_refresh_shop)
	settings.progress_changed.connect(_refresh_character_selection)
	add_child(settings)
	_music_manager = MUSIC_MANAGER_SCRIPT.new() as BlockFighterMusicManager
	_music_manager.name = "MusicManager"
	add_child(_music_manager)
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


func _exit_tree() -> void:
	if is_instance_valid(_select_sfx_timer):
		_select_sfx_timer.stop()
	if is_instance_valid(_select_sfx_player):
		_select_sfx_player.stop()
		_select_sfx_player.stream = null


func _draw() -> void:
	if current_screen == Screen.GAME:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0b0f17"))
		return
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
	_hide_stage_fail()
	_show_screen(Screen.MAIN)


func _on_main_game_start_pressed() -> void:
	show_floor_select()


func show_stage_select() -> void:
	_hide_stage_result()
	_selected_floor_group = clampi(
		(selected_stage_number - 1) / _FLOORS_PER_GROUP,
		0,
		_FLOOR_GROUP_COUNT - 1
	)
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
	_selected_language = settings.language
	_refresh_language_button()
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


func start_game(stage_number: int = -1, challenge_mode: bool = false) -> bool:
	if _selected_character_id.is_empty() or not MainCharacterData.has_character(_selected_character_id):
		_show_message(_text("먼저 캐릭터를 선택하세요.", "Select a character first."))
		return false
	if not settings.is_character_unlocked(_selected_character_id):
		_show_message(
			_text(
				"아직 해금되지 않은 캐릭터입니다.",
				"This character is still locked."
			)
		)
		return false
	if _game_instance != null and is_instance_valid(_game_instance):
		return true
	if stage_number < 1:
		stage_number = selected_stage_number
	if challenge_mode and not settings.is_challenge_unlocked():
		_show_message(_text("10층 클리어 후 해금", "CLEAR 10F TO UNLOCK"))
		return false
	if not challenge_mode and not settings.is_stage_unlocked(stage_number):
		_show_message(_text("아직 잠긴 스테이지입니다.", "This stage is locked."))
		return false
	if not ResourceLoader.exists(game_scene_path, "PackedScene"):
		_show_message(_text("게임 장면을 찾을 수 없습니다.\n%s", "Game scene not found.\n%s") % game_scene_path)
		return false

	var game_resource: Resource = load(game_scene_path)
	if not game_resource is PackedScene:
		_show_message(_text("게임 장면을 불러올 수 없습니다.\n%s", "Could not load game scene.\n%s") % game_scene_path)
		return false

	_game_instance = (game_resource as PackedScene).instantiate()
	_game_instance.name = "LoadedGame"
	_game_instance.set_meta("stage_number", stage_number)
	_game_instance.set_meta("challenge_mode", challenge_mode)
	_game_instance.set_meta("language", settings.language)
	selected_stage_number = stage_number
	_game_viewport.add_child(_game_instance)
	var selected_character: MainCharacterController = _game_instance.get_node_or_null(
		"BoardPhysics/Character"
	) as MainCharacterController
	if selected_character != null:
		selected_character.set_character_id(_selected_character_id)
		selected_character.set_passive_levels(settings.get_passive_levels())
	var game_controller: MainGameController = _loaded_game_controller()
	if game_controller != null:
		game_controller.stage_cleared.connect(_on_survival_stage_cleared)
		game_controller.stage_failed.connect(_on_stage_failed)
		if challenge_mode:
			game_controller.game_changed.connect(_on_challenge_game_changed)
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
		_text("%s의 %s 키를 누르세요.", "%s: press the %s key.")
		% [
			settings.get_action_label(action_name),
			_text("주", "primary") if slot_index == 0 else _text("보조", "secondary"),
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
	var is_z_key: bool = (
		key_event.physical_keycode == KEY_Z
		or key_event.keycode == KEY_Z
	)
	if not key_event.pressed:
		if is_z_key:
			_menu_confirm_z_armed = true
		return
	if key_event.echo:
		return
	if is_z_key and _screen_uses_z_confirmation():
		if not _menu_confirm_z_armed:
			get_viewport().set_input_as_handled()
			return
		_menu_confirm_z_armed = false
	if _handle_debug_unlock_all_characters_input(key_event):
		get_viewport().set_input_as_handled()
	elif _handle_game_exit_prompt_input(key_event):
		get_viewport().set_input_as_handled()
	elif _handle_debug_completion_input(key_event):
		get_viewport().set_input_as_handled()
	elif _handle_progress_reset_prompt_input(key_event):
		get_viewport().set_input_as_handled()
	elif _handle_passive_reset_prompt_input(key_event):
		get_viewport().set_input_as_handled()
	elif _handle_character_select_input(key_event):
		get_viewport().set_input_as_handled()
	elif _handle_language_selection_input(key_event):
		get_viewport().set_input_as_handled()
	elif _handle_menu_confirm_input(key_event):
		get_viewport().set_input_as_handled()


func _screen_uses_z_confirmation() -> bool:
	if current_screen != Screen.GAME:
		return true
	return (
		(_game_exit_overlay != null and _game_exit_overlay.visible)
		or (_message_overlay != null and _message_overlay.visible)
		or (_stage_result_overlay != null and _stage_result_overlay.visible)
		or (_stage_fail_overlay != null and _stage_fail_overlay.visible)
	)


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
		if key_code == KEY_X or _is_escape_key(key_event):
			_hide_game_exit_prompt()
			return true
		return false
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


## 숫자열 0 또는 키패드 0을 누르면 배포 빌드를 포함해 모든 캐릭터 선택 제한을 해제한다.
## 키 설정을 변경하는 중에는 0을 정상적인 바인딩 입력으로 사용할 수 있도록 가로채지 않는다.
func _handle_debug_unlock_all_characters_input(key_event: InputEventKey) -> bool:
	if _capture_overlay != null and _capture_overlay.visible:
		return false
	if (
		(_game_exit_overlay != null and _game_exit_overlay.visible)
		or (_message_overlay != null and _message_overlay.visible)
		or (_progress_reset_overlay != null and _progress_reset_overlay.visible)
		or (_passive_reset_overlay != null and _passive_reset_overlay.visible)
	):
		return false
	var key_code: int = int(key_event.physical_keycode)
	if key_code == KEY_NONE:
		key_code = int(key_event.keycode)
	if key_code != KEY_0 and key_code != KEY_KP_0:
		return false
	var unlock_error: Error = settings.unlock_all_characters_for_debug()
	if unlock_error != OK:
		_show_message(
			_text(
				"캐릭터 해금 상태를 저장하지 못했습니다.",
				"Could not save the character unlock state."
			)
		)
		return true
	_refresh_character_selection()
	_show_message(
		_text(
			"버그키: 모든 캐릭터가 해금되었습니다.",
			"CHEAT: All characters unlocked."
		)
	)
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
		_confirm_character_selection()
		return true
	return false


func _handle_language_selection_input(key_event: InputEventKey) -> bool:
	if current_screen != Screen.OPTIONS or _language_button == null or not _language_button.has_focus():
		return false
	var key_code: int = key_event.physical_keycode
	if key_code == KEY_NONE:
		key_code = key_event.keycode
	if key_code != KEY_LEFT and key_code != KEY_RIGHT:
		return false
	_selected_language = _next_language(key_code == KEY_RIGHT)
	_refresh_language_button()
	return true


func _move_character_focus(direction: int) -> void:
	if _character_buttons.is_empty():
		return
	var current_index: int = MainCharacterData.CHARACTER_ORDER.find(_selected_character_id)
	if current_index < 0:
		current_index = 0
	var target_index: int = posmod(
		current_index + signi(direction),
		_character_buttons.size()
	)
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
	if current_screen == Screen.SHOP:
		var shop_index: int = _shop_cards.find(focused_button)
		if shop_index >= 0:
			_upgrade_passive(StartScreenSettings.PASSIVE_IDS[shop_index])
			return true
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
	if key_code == KEY_UP or key_code == KEY_DOWN:
		return true
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
		Screen.FLOOR_SELECT:
			show_main_menu()
		Screen.STAGE_SELECT:
			show_floor_select()
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
	_configure_game_host_layout()
	_game_host.visible = false
	add_child(_game_host)
	_game_viewport_container = SubViewportContainer.new()
	_game_viewport_container.name = "GameViewportContainer"
	_game_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_viewport_container.stretch = true
	_game_viewport_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_game_host.add_child(_game_viewport_container)
	_game_viewport = SubViewport.new()
	_game_viewport.name = "GameViewport"
	_game_viewport.size = MainLayout.GAME_VIEWPORT_SIZE
	_game_viewport.disable_3d = true
	_game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_game_viewport_container.add_child(_game_viewport)

	_build_main_screen()
	_build_floor_select_screen()
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
	_build_stage_fail_overlay()


func _build_main_screen() -> void:
	var screen: Control = _create_screen("MainScreen", Screen.MAIN)
	var panel: Panel = _create_panel(
		screen,
		Rect2(60.0, 60.0, 840.0, 680.0),
		Color(1.0, 1.0, 1.0, 0.98),
		BORDER,
		14
	)

	_create_label(
		panel,
		"BLOCK\nFIGHTER",
		Rect2(0.0, 104.0, 840.0, 138.0),
		48,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	).add_theme_constant_override("line_spacing", -4)

	var button_data: Array = [
		["GAME START", CYAN, _on_main_game_start_pressed],
		["게임 설명", ORANGE, show_tutorial],
		["OPTION", PURPLE, show_options],
		["EXIT", DANGER, request_exit],
	]
	for index: int in range(button_data.size()):
		var data: Array = button_data[index]
		var button: Button = _create_button(
			panel,
			String(data[0]),
			Rect2(245.0, 290.0 + index * 67.0, 350.0, 54.0),
			data[1],
			18
		)
		button.pressed.connect(data[2])
		button.focus_entered.connect(_play_select_sfx)
		_main_buttons.append(button)

	_create_label(
		panel,
		"↑ ↓ 선택    Z 확인",
		Rect2(250.0, 604.0, 340.0, 28.0),
		13,
		MUTED,
		HORIZONTAL_ALIGNMENT_CENTER
	)


func _build_stage_select_screen() -> void:
	var screen: Control = _create_screen("StageSelectScreen", Screen.STAGE_SELECT)
	_challenge_button = _create_button(
		screen,
		"도전 모드",
		Rect2(300.0, 48.0, 360.0, 82.0),
		CYAN,
		17
	)
	_challenge_button.name = "ChallengeModeButton"
	_challenge_button.pressed.connect(_on_challenge_selected)
	_challenge_button.focus_entered.connect(_play_select_sfx)
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
	for card_index: int in range(_FLOORS_PER_GROUP):
		var x_position: float = 145.0 + float(card_index) * 152.0
		var panel: Panel = _create_panel(
			screen,
			Rect2(x_position, 190.0, 140.0, 340.0),
			PANEL,
			accents[card_index],
			10
		)
		_stage_panels.append(panel)
		var title_label: Label = _create_label(
			panel,
			"",
			Rect2(5.0, 26.0, 130.0, 38.0),
			19,
			TEXT,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		_stage_title_labels.append(title_label)
		var status_label: Label = _create_label(
			panel,
			"",
			Rect2(5.0, 102.0, 130.0, 72.0),
			17,
			ORANGE,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		_stage_labels.append(status_label)
		var stage_button: Button = _create_button(
			panel,
			"",
			Rect2(15.0, 235.0, 110.0, 48.0),
			accents[card_index],
			12
		)
		stage_button.name = "StageButton%d" % (card_index + 1)
		stage_button.pressed.connect(_on_stage_card_pressed.bind(card_index))
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
		"구역 선택",
		Rect2(390.0, 650.0, 180.0, 48.0),
		PURPLE,
		14
	)
	back_button.name = "BackToFloorSelectButton"
	back_button.pressed.connect(show_floor_select)
	_refresh_stage_select()


## 상황: GAME START 후 처음 도착하는 층 구역 선택 화면을 만들 때 호출된다.
## 순서: 탑 모양 세로 배치(위=높은 층, 아래=낮은 층)로 구역 버튼을 생성한다.
## 결과: 구역 버튼을 누르면 해당 구역의 층 선택 화면(STAGE_SELECT)으로 이동한다.
func _build_floor_select_screen() -> void:
	var screen: Control = _create_screen("FloorSelectScreen", Screen.FLOOR_SELECT)
	_create_label(
		screen,
		_text("탑 선택", "SELECT TOWER"),
		Rect2(0.0, 16.0, 960.0, 40.0),
		30,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	var accents: Array[Color] = [CYAN, ORANGE, PURPLE, CYAN, DANGER]
	# 위(높은 층)에서 아래(낮은 층) 순서로 세로 배치해 탑을 오르는 느낌을 낸다.
	for group_index: int in range(_FLOOR_GROUP_COUNT):
		var button_y: float = 130.0 + float(group_index) * 170.0
		var group_button: Button = _create_button(
			screen,
			_floor_group_label(_FLOOR_GROUP_COUNT - 1 - group_index),
			Rect2(330.0, button_y, 300.0, 150.0),
			accents[group_index],
			18
		)
		group_button.name = "FloorGroupButton%d" % (_FLOOR_GROUP_COUNT - group_index)
		group_button.pressed.connect(
			_on_floor_group_selected.bind(_FLOOR_GROUP_COUNT - 1 - group_index)
		)
		group_button.focus_entered.connect(_play_select_sfx)
		_floor_group_buttons.append(group_button)

	var back_button: Button = _create_button(
		screen,
		"메인으로",
		Rect2(390.0, 650.0, 180.0, 48.0),
		PURPLE,
		14
	)
	back_button.pressed.connect(show_main_menu)


func show_floor_select() -> void:
	_hide_stage_result()
	_selected_floor_group = clampi(
		(selected_stage_number - 1) / _FLOORS_PER_GROUP,
		0,
		_FLOOR_GROUP_COUNT - 1
	)
	_refresh_floor_select()
	_show_screen(Screen.FLOOR_SELECT)


func _refresh_floor_select() -> void:
	if settings == null or _floor_group_buttons.size() != _FLOOR_GROUP_COUNT:
		return
	for button_index: int in range(_FLOOR_GROUP_COUNT):
		# 버튼 배열은 화면 위(높은 층)부터 저장되므로 그룹 인덱스로 변환한다.
		var group_index: int = _FLOOR_GROUP_COUNT - 1 - button_index
		var first_floor: int = group_index * _FLOORS_PER_GROUP + 1
		var last_floor: int = (group_index + 1) * _FLOORS_PER_GROUP
		var unlocked_count: int = 0
		for stage_number: int in range(first_floor, last_floor + 1):
			if settings.is_stage_unlocked(stage_number):
				unlocked_count += 1
		_floor_group_buttons[button_index].text = "%s\n%s" % [
			_floor_group_label(group_index),
			_text("%d/%d층 해금", "%d/%d floors open")
				% [unlocked_count, _FLOORS_PER_GROUP],
		]


func _floor_group_label(group_index: int) -> String:
	var first_floor: int = group_index * _FLOORS_PER_GROUP + 1
	var last_floor: int = (group_index + 1) * _FLOORS_PER_GROUP
	return _text("%d구역\n%d-%d층", "AREA %d\nFLOORS %d-%d") % [
		group_index + 1,
		first_floor,
		last_floor,
	]


func _floor_number_for_card(card_index: int) -> int:
	return _selected_floor_group * _FLOORS_PER_GROUP + card_index + 1


func _on_floor_group_selected(group_index: int) -> void:
	if group_index < 0 or group_index >= _FLOOR_GROUP_COUNT:
		return
	_selected_floor_group = group_index
	_refresh_stage_select()
	_show_screen(Screen.STAGE_SELECT)


func _on_stage_card_pressed(card_index: int) -> void:
	var stage_number: int = _floor_number_for_card(card_index)
	if settings != null and settings.is_stage_unlocked(stage_number):
		start_game(stage_number)


func _build_shop_screen() -> void:
	var screen: Control = _create_screen("ShopScreen", Screen.SHOP)
	_create_label(
		screen,
		"상점 선택",
		Rect2(0.0, 16.0, 960.0, 40.0),
		30,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_shop_currency_label = _create_label(
		screen,
		"별 0개",
		Rect2(700.0, 26.0, 220.0, 32.0),
		18,
		ORANGE,
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	_create_panel(screen, Rect2(60.0, 64.0, 840.0, 44.0), PANEL, SHOP_GOLD, 8)
	_create_label(
		screen,
		"강화",
		Rect2(60.0, 70.0, 840.0, 32.0),
		19,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_shop_icon_textures.clear()
	for file_name: String in _SHOP_ICON_FILES:
		var path: String = _SHOP_ICON_DIR + file_name
		_shop_icon_textures.append(
			load(path) if ResourceLoader.exists(path) else null
		)

	var grid_scroll: ScrollContainer = ScrollContainer.new()
	grid_scroll.name = "ShopGridScroll"
	grid_scroll.position = Vector2(100.0, 136.0)
	grid_scroll.size = Vector2(_SHOP_GRID_WIDTH, 360.0)
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen.add_child(grid_scroll)
	var grid_content: Control = Control.new()
	grid_content.name = "ShopGridContent"
	grid_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_scroll.add_child(grid_content)
	var row_count: int = ceili(
		float(StartScreenSettings.PASSIVE_IDS.size()) / float(_SHOP_CARD_COLUMNS)
	)
	var content_height: float = 12.0 + float(row_count) * (_SHOP_CARD_SIZE.y + _SHOP_CARD_GAP)
	grid_content.custom_minimum_size = Vector2(_SHOP_GRID_WIDTH, content_height)
	grid_content.size = grid_content.custom_minimum_size

	for index: int in range(StartScreenSettings.PASSIVE_IDS.size()):
		var col: int = index % _SHOP_CARD_COLUMNS
		var row: int = index / _SHOP_CARD_COLUMNS
		var row_width: float = (
			_SHOP_CARD_SIZE.x * float(_SHOP_CARD_COLUMNS)
			+ _SHOP_CARD_GAP * float(_SHOP_CARD_COLUMNS - 1)
		)
		var card_x: float = (_SHOP_GRID_WIDTH - row_width) / 2.0 + col * (_SHOP_CARD_SIZE.x + _SHOP_CARD_GAP)
		var card_y: float = 12.0 + row * (_SHOP_CARD_SIZE.y + _SHOP_CARD_GAP)
		var card: Button = _create_button(
			grid_content,
			"",
			Rect2(card_x, card_y, _SHOP_CARD_SIZE.x, _SHOP_CARD_SIZE.y),
			SHOP_GOLD,
			13
		)
		card.name = "ShopCard_%s" % StartScreenSettings.PASSIVE_IDS[index]
		card.focus_entered.connect(_select_shop_item.bind(index))
		card.focus_exited.connect(_clear_shop_card_selection.bind(index))
		card.pressed.connect(_select_shop_item.bind(index))
		_create_label(
			card,
			settings.get_passive_name(index),
			Rect2(6.0, 4.0, _SHOP_CARD_SIZE.x - 12.0, 26.0),
			15,
			TEXT,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		var icon_frame: Panel = _create_panel(
			card,
			Rect2(36.0, 32.0, 88.0, 88.0),
			PANEL,
			BORDER,
			6
		)
		icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var texture: Texture2D = _shop_icon_textures[index] as Texture2D
		if texture != null:
			var icon: TextureRect = TextureRect.new()
			icon.position = Vector2(8.0, 8.0)
			icon.size = Vector2(72.0, 72.0)
			icon.texture = texture
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_frame.add_child(icon)
		else:
			var fallback: Label = _create_label(
				icon_frame,
				settings.get_passive_name(index).left(1),
				Rect2(0.0, 0.0, 88.0, 88.0),
				34,
				TEXT,
				HORIZONTAL_ALIGNMENT_CENTER
			)
			fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var level_label: Label = _create_label(
			card,
			"",
			Rect2(6.0, 124.0, _SHOP_CARD_SIZE.x - 12.0, 30.0),
			15,
			SHOP_GOLD,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		level_label.name = "PassiveLevelLabel_%s" % StartScreenSettings.PASSIVE_IDS[index]
		_shop_cards.append(card)
		_shop_level_labels.append(level_label)
		_apply_shop_card_style(card, false)

	var detail_panel: Panel = _create_panel(
		screen,
		Rect2(40.0, 512.0, 880.0, 132.0),
		PANEL,
		SHOP_GOLD,
		10
	)
	detail_panel.name = "ShopDetailPanel"
	_shop_detail_name = _create_label(
		detail_panel,
		"",
		Rect2(24.0, 12.0, 560.0, 30.0),
		21,
		TEXT
	)
	_shop_detail_description = _create_label(
		detail_panel,
		"",
		Rect2(24.0, 43.0, 580.0, 28.0),
		13,
		MUTED
	)
	_shop_detail_effect = _create_label(
		detail_panel,
		"",
		Rect2(24.0, 76.0, 580.0, 28.0),
		15,
		TEXT
	)
	_shop_detail_cost = _create_label(
		detail_panel,
		"",
		Rect2(630.0, 30.0, 226.0, 34.0),
		16,
		ORANGE,
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	_create_label(
		detail_panel,
		"선택 후 Z로 강화",
		Rect2(630.0, 68.0, 226.0, 28.0),
		13,
		MUTED,
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	_shop_back_button = _create_button(
		screen,
		"스테이지 선택으로",
		Rect2(70.0, 674.0, 220.0, 48.0),
		PURPLE,
		14
	)
	_shop_back_button.name = "ShopBackButton"
	_shop_back_button.pressed.connect(show_stage_select)
	_shop_reset_button = _create_button(
		screen,
		"패시브 초기화",
		Rect2(670.0, 674.0, 220.0, 48.0),
		DANGER,
		14
	)
	_shop_reset_button.name = "PassiveResetButton"
	_shop_reset_button.pressed.connect(_show_passive_reset_prompt)
	_shop_reset_button.focus_entered.connect(_play_select_sfx)
	_set_shop_card_neighbors()
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
	_options_first_button = _create_button(
		screen, "KEY", Rect2(255.0, 150.0, 450.0, 54.0), CYAN, 18
	)
	_options_first_button.pressed.connect(show_key_custom)
	var volume_button: Button = _create_button(
		screen, "VOLUME", Rect2(255.0, 220.0, 450.0, 54.0), ORANGE, 18
	)
	volume_button.pressed.connect(show_volume)

	var language_panel: Panel = _create_panel(
		screen, Rect2(255.0, 290.0, 450.0, 60.0), PANEL, PURPLE, 12
	)
	_create_label(language_panel, "LANGUAGE", Rect2(24.0, 15.0, 150.0, 30.0), 18, TEXT)
	_language_button = _create_button(
		language_panel, _text("한국어", "ENGLISH"), Rect2(190.0, 12.0, 236.0, 36.0), PURPLE, 14
	)
	_language_button.name = "LanguageButton"
	_language_button.tooltip_text = "←/→ 선택    Z 적용"
	_language_button.pressed.connect(_confirm_language_selection)

	var reset_button: Button = _create_button(
		screen,
		"DATA 초기화",
		Rect2(255.0, 366.0, 450.0, 54.0),
		DANGER,
		18
	)
	reset_button.pressed.connect(_show_progress_reset_prompt)

	var back_button: Button = _create_button(
		screen,
		"뒤로가기",
		Rect2(255.0, 436.0, 450.0, 54.0),
		PURPLE,
		18
	)
	back_button.pressed.connect(show_main_menu)


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
		settings.get_action_label(action_name),
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
	_add_screen_title(screen, "VOLUME", "BGM과 효과음의 크기를\n각각 조절합니다.")
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
		149.0,
		settings.sfx_percent,
		ORANGE,
		"SfxSlider",
		_on_sfx_changed
	)

	_create_label(
		panel,
		"0%는 음소거입니다. 음악은 BGM 버스,\n효과음은 SFX 버스를 지정하면 이 설정을 사용합니다.",
		Rect2(54.0, 238.0, 552.0, 64.0),
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
	_message_okay_button = _create_button(
		panel,
		"확인",
		Rect2(180.0, 205.0, 180.0, 44.0),
		CYAN,
		14
	)
	_message_okay_button.pressed.connect(_hide_message)


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
		"스테이지 해금, 도전 기록, 별 재화와 패시브가 초기화됩니다.",
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
	_game_viewport.add_child(_game_exit_overlay)

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


func _build_stage_fail_overlay() -> void:
	_stage_fail_overlay = Control.new()
	_stage_fail_overlay.name = "StageFailOverlay"
	_stage_fail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage_fail_overlay.z_as_relative = false
	_stage_fail_overlay.z_index = 200
	_stage_fail_overlay.visible = false
	add_child(_stage_fail_overlay)

	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.78)
	_stage_fail_overlay.add_child(shade)
	var panel: Panel = _create_panel(
		_stage_fail_overlay,
		Rect2(220.0, 250.0, 520.0, 300.0),
		PANEL,
		DANGER,
		12
	)
	_create_label(
		panel,
		"실패",
		Rect2(40.0, 40.0, 440.0, 84.0),
		27,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_create_label(
		panel,
		"스테이지 제한시간이 끝났습니다.",
		Rect2(40.0, 140.0, 440.0, 42.0),
		17,
		ORANGE,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_stage_fail_retry_button = _create_button(
		panel,
		"재시도",
		Rect2(70.0, 220.0, 180.0, 46.0),
		CYAN,
		14
	)
	_stage_fail_retry_button.name = "StageFailRetryButton"
	_stage_fail_retry_button.pressed.connect(_retry_failed_stage)
	_stage_fail_select_button = _create_button(
		panel,
		"스테이지 선택으로",
		Rect2(270.0, 220.0, 180.0, 46.0),
		DANGER,
		14
	)
	_stage_fail_select_button.name = "StageFailSelectButton"
	_stage_fail_select_button.pressed.connect(_on_stage_fail_select)


func _show_stage_fail() -> void:
	if _stage_fail_overlay == null:
		return
	_stage_fail_overlay.visible = true
	_stage_fail_overlay.move_to_front()
	_stage_fail_retry_button.grab_focus.call_deferred()


func _hide_stage_fail() -> void:
	if _stage_fail_overlay != null:
		_stage_fail_overlay.visible = false


## 상황: 스테이지 제한시간이 끝나 game_controller가 stage_failed를 방송했을 때 호출한다.
## 순서: 게임 제거 → 메뉴 창 복원 → 스테이지 선택 아래에 실패 overlay 표시.
## 결과: 별·해금·별 재화는 지급되지 않으며 재시도/스테이지 선택 버튼이 입력을 받는다.
func _on_stage_failed() -> void:
	_dispose_game_instance()
	_apply_menu_viewport_size()
	_show_screen(Screen.STAGE_SELECT)
	_show_stage_fail()


func _retry_failed_stage() -> void:
	_hide_stage_fail()
	_dispose_game_instance()
	start_game(selected_stage_number)


func _on_stage_fail_select() -> void:
	_hide_stage_fail()
	show_floor_select()


func _show_stage_result(result: Dictionary) -> void:
	if _stage_result_overlay == null:
		return
	var stage_number: int = int(result.get("stage_number", selected_stage_number))
	var stars: int = int(result.get("stars", 3))
	var reward: int = int(result.get("reward", 0))
	_stage_result_label.text = _text("%d층 클리어!\n%s", "FLOOR %d CLEAR!\n%s") % [stage_number, _star_text(stars)]
	_stage_result_reward_label.text = _text("별 보상 +%d   (보유 %d)", "Stars +%d   (Total %d)") % [
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
	var loaded_character: MainCharacterController = _game_instance.get_node_or_null(
		"BoardPhysics/Character"
	) as MainCharacterController
	var remaining_lives: int = loaded_character.lives if loaded_character != null else -1
	var cleared_without_damage: bool = (
		loaded_character != null
		and loaded_character.lives == loaded_character.get_max_lives()
	)
	_complete_stage(3, remaining_lives, cleared_without_damage)


func _on_survival_stage_cleared(cleared_lines: int) -> void:
	var game_controller: MainGameController = _loaded_game_controller()
	var loaded_character: MainCharacterController = _game_instance.get_node_or_null(
		"BoardPhysics/Character"
	) as MainCharacterController
	var remaining_lives: int = loaded_character.lives if loaded_character != null else -1
	var cleared_without_damage: bool = (
		loaded_character != null
		and loaded_character.lives == loaded_character.get_max_lives()
	)
	var stars: int = MainGameController.stage_stars_for_lines(cleared_lines)
	if game_controller != null and game_controller.is_boss_stage():
		remaining_lives = loaded_character.lives if loaded_character != null else 1
		stars = clampi(remaining_lives, 1, 3)
	_complete_stage(stars, remaining_lives, cleared_without_damage)


func _on_challenge_game_changed() -> void:
	var game_controller: MainGameController = _loaded_game_controller()
	if game_controller == null or game_controller.state != MainGameController.GameState.GAME_OVER:
		return
	settings.record_challenge_lines(game_controller.total_lines)


func _complete_stage(
	stars: int,
	remaining_lives: int = -1,
	cleared_without_damage: bool = false
) -> void:
	var result: Dictionary = settings.complete_stage(
		selected_stage_number,
		stars,
		remaining_lives,
		cleared_without_damage
	)
	if not bool(result.get("ok", false)):
		_show_message(String(result.get("message", "스테이지를 완료할 수 없습니다.")))
		return
	_dispose_game_instance()
	_apply_menu_viewport_size()
	_show_screen(Screen.STAGE_SELECT)
	_show_stage_result(result)


func _show_screen(screen_type: Screen) -> void:
	current_screen = screen_type
	queue_redraw()
	if _music_manager != null:
		if screen_type == Screen.GAME:
			_music_manager.play_battle()
		else:
			_music_manager.play_menu()
	for stored_screen: Variant in _screens.values():
		(stored_screen as Control).visible = false
	_game_host.visible = screen_type == Screen.GAME
	if screen_type != Screen.GAME:
		(_screens[screen_type] as Control).visible = true

	match screen_type:
		Screen.MAIN:
			_main_buttons[0].grab_focus.call_deferred()
		Screen.FLOOR_SELECT:
			if not _floor_group_buttons.is_empty():
				_floor_group_buttons[0].grab_focus.call_deferred()
		Screen.STAGE_SELECT:
			if not _stage_buttons.is_empty():
				var focus_card: int = clampi(
					selected_stage_number - 1 - _selected_floor_group * _FLOORS_PER_GROUP,
					0,
					_stage_buttons.size() - 1
				)
				if _stage_buttons[focus_card].disabled:
					focus_card = 0
				_stage_buttons[focus_card].grab_focus.call_deferred()
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
			if not _shop_cards.is_empty():
				var index: int = clampi(
					_selected_shop_index,
					0,
					_shop_cards.size() - 1
				)
				_shop_cards[index].grab_focus.call_deferred()
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
	if (
		settings == null
		or _stage_panels.size() != _FLOORS_PER_GROUP
		or _stage_buttons.size() != _FLOORS_PER_GROUP
		or _challenge_button == null
	):
		return
	_stage_currency_label.text = _text("별 %d개" % settings.star_currency, "%d Stars" % settings.star_currency)
	var challenge_unlocked: bool = settings.is_challenge_unlocked()
	_challenge_button.text = (
		"%s\n%s" % [
			_text("도전 모드"),
			_text("최고 기록 %d줄") % settings.challenge_best_lines,
		]
		if challenge_unlocked
		else "■ %s\n%s" % [_text("도전 모드"), _text("10층 클리어 후 해금")]
	)
	for card_index: int in range(_FLOORS_PER_GROUP):
		var stage_number: int = _floor_number_for_card(card_index)
		var unlocked: bool = settings.is_stage_unlocked(stage_number)
		var is_boss: bool = stage_number % _FLOORS_PER_GROUP == 0
		_stage_title_labels[card_index].text = _text("%d층%s", "%d층%s") % [
			stage_number,
			_text("  보스", "  BOSS") if is_boss else "",
		]
		_stage_panels[card_index].modulate = Color.WHITE if unlocked else Color(0.62, 0.66, 0.72, 0.72)
		_stage_labels[card_index].text = (
			"%s\n%s" % [
				_star_text(settings.get_stage_best_stars(stage_number)),
				_text("입장 가능", "AVAILABLE"),
			]
			if unlocked
			else "■\n%s" % _text("잠김", "LOCKED")
		)
		_stage_buttons[card_index].text = (
			_text("블록 깨러 가기", "START STAGE") if unlocked else _text("잠김", "LOCKED")
		)


func _refresh_shop() -> void:
	if settings == null or _shop_cards.is_empty():
		return
	_shop_currency_label.text = _text("별 %d개" % settings.star_currency, "%d Stars" % settings.star_currency)
	for index: int in range(StartScreenSettings.PASSIVE_IDS.size()):
		var passive_id: String = StartScreenSettings.PASSIVE_IDS[index]
		var level: int = settings.get_passive_level(passive_id)
		var bars: String = ""
		for bar_index: int in range(StartScreenSettings.MAX_PASSIVE_LEVEL):
			bars += "■" if bar_index < level else "□"
			bars += "  "
		_shop_level_labels[index].text = bars.trim_suffix("  ")
	_refresh_shop_detail()


func _refresh_shop_detail() -> void:
	if settings == null or _shop_cards.is_empty():
		return
	var index: int = clampi(_selected_shop_index, 0, _shop_cards.size() - 1)
	var passive_id: String = StartScreenSettings.PASSIVE_IDS[index]
	var level: int = settings.get_passive_level(passive_id)
	var cost: int = settings.get_passive_cost(passive_id)
	var effect_percent: int = roundi(MainCharacterData.PASSIVE_EFFECT_STEP * 100.0)
	var effect_text: String = ""
	if passive_id == "health":
		effect_text = _text("현재 효과: 목숨 +%d · Lv. %d / %d", "Current effect: Lives +%d · Lv. %d / %d") % [
			level,
			level,
			StartScreenSettings.MAX_PASSIVE_LEVEL,
		]
	else:
		var effect_sign: String = "-" if index in [0, 3, 4] else "+"
		effect_text = _text("현재 효과: %s%d%% · Lv. %d / %d", "Current effect: %s%d%% · Lv. %d / %d") % [
			effect_sign,
			level * effect_percent,
			level,
			StartScreenSettings.MAX_PASSIVE_LEVEL,
		]
	_shop_detail_name.text = settings.get_passive_name(index)
	_shop_detail_description.text = settings.get_passive_description(index)
	_shop_detail_effect.text = effect_text
	_shop_detail_cost.text = (
		_text("최대 레벨", "MAX LEVEL")
		if level >= StartScreenSettings.MAX_PASSIVE_LEVEL
		else _text("다음 비용 ★ %d", "NEXT COST ★ %d") % cost
	)


func _select_shop_item(index: int) -> void:
	if _shop_cards.is_empty():
		return
	_selected_shop_index = clampi(index, 0, _shop_cards.size() - 1)
	for shop_index: int in range(_shop_cards.size()):
		_apply_shop_card_style(_shop_cards[shop_index], shop_index == _selected_shop_index)
	_refresh_shop_detail()


func _clear_shop_card_selection(index: int) -> void:
	if _shop_cards.is_empty():
		return
	_apply_shop_card_style(_shop_cards[clampi(index, 0, _shop_cards.size() - 1)], false)


func _apply_shop_card_style(card: Button, selected: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#fff8e6") if selected else PANEL
	style.border_color = SHOP_GOLD if selected else Color("#5b6b7d")
	style.set_border_width_all(3 if selected else 1)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("normal", style)
	card.add_theme_stylebox_override("hover", style)
	card.add_theme_stylebox_override("pressed", style)
	card.add_theme_stylebox_override("focus", style)


func _set_shop_card_neighbors() -> void:
	var row_count: int = ceili(
		float(_shop_cards.size()) / float(_SHOP_CARD_COLUMNS)
	)
	for index: int in range(_shop_cards.size()):
		var card: Button = _shop_cards[index]
		var col: int = index % _SHOP_CARD_COLUMNS
		var row: int = index / _SHOP_CARD_COLUMNS
		var left: int = index - 1 if col > 0 else index
		var right: int = (
			index + 1
			if (col < _SHOP_CARD_COLUMNS - 1 and index + 1 < _shop_cards.size())
			else index
		)
		var up: int = index - _SHOP_CARD_COLUMNS if row > 0 else index
		card.focus_neighbor_left = card.get_path_to(_shop_cards[left])
		card.focus_neighbor_right = card.get_path_to(_shop_cards[right])
		card.focus_neighbor_top = card.get_path_to(_shop_cards[up])
		if row + 1 < row_count:
			var next_row_start: int = (row + 1) * _SHOP_CARD_COLUMNS
			var next_row_count: int = mini(
				_SHOP_CARD_COLUMNS,
				_shop_cards.size() - next_row_start
			)
			var down: int = next_row_start + mini(col, next_row_count - 1)
			card.focus_neighbor_bottom = card.get_path_to(_shop_cards[down])
		elif _shop_back_button != null and _shop_reset_button != null:
			card.focus_neighbor_bottom = card.get_path_to(
				_shop_back_button if col == 0 else _shop_reset_button
			)

	if _shop_cards.size() < 2 or _shop_back_button == null or _shop_reset_button == null:
		return
	_shop_back_button.focus_neighbor_left = _shop_back_button.get_path_to(_shop_back_button)
	_shop_back_button.focus_neighbor_right = _shop_back_button.get_path_to(_shop_reset_button)
	_shop_back_button.focus_neighbor_top = _shop_back_button.get_path_to(
		_shop_cards[_shop_cards.size() - 2]
	)
	_shop_back_button.focus_neighbor_bottom = _shop_back_button.get_path_to(_shop_back_button)
	_shop_reset_button.focus_neighbor_left = _shop_reset_button.get_path_to(_shop_back_button)
	_shop_reset_button.focus_neighbor_right = _shop_reset_button.get_path_to(_shop_reset_button)
	_shop_reset_button.focus_neighbor_top = _shop_reset_button.get_path_to(
		_shop_cards[_shop_cards.size() - 1]
	)
	_shop_reset_button.focus_neighbor_bottom = _shop_reset_button.get_path_to(_shop_reset_button)


func _upgrade_passive(passive_id: String) -> void:
	if settings.get_passive_level(passive_id) >= StartScreenSettings.MAX_PASSIVE_LEVEL:
		return
	var result: Dictionary = settings.upgrade_passive(passive_id)
	if not bool(result.get("ok", false)):
		_show_message(String(result.get("message", "패시브를 강화할 수 없습니다.")))


func _on_stage_selected(stage_number: int) -> void:
	if settings.is_stage_unlocked(stage_number):
		start_game(stage_number)


func _on_challenge_selected() -> void:
	if settings.is_challenge_unlocked():
		start_game(1, true)


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
	_key_status.text = _text("모든 키를 기본값으로 복원했습니다.", "All keys were restored to defaults.")
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
	if not _message_overlay.visible:
		_message_previous_focus = get_viewport().gui_get_focus_owner()
		_message_game_was_playing = false
		if current_screen == Screen.GAME:
			var game_controller: MainGameController = _loaded_game_controller()
			if game_controller != null:
				_message_game_was_playing = (
					game_controller.state == MainGameController.GameState.PLAYING
				)
				if _message_game_was_playing:
					game_controller.toggle_pause()
				game_controller.set_physics_process(false)
	_message_label.text = message
	_message_overlay.visible = true
	_message_overlay.move_to_front()
	if _message_okay_button != null:
		_message_okay_button.grab_focus.call_deferred()


func _hide_message() -> void:
	_message_overlay.visible = false
	var game_controller: MainGameController = _loaded_game_controller()
	if game_controller != null:
		game_controller.set_physics_process(true)
		if (
			_message_game_was_playing
			and game_controller.state == MainGameController.GameState.PAUSED
		):
			game_controller.toggle_pause()
		var loaded_character: MainCharacterController = _game_instance.get_node_or_null(
			"BoardPhysics/Character"
		) as MainCharacterController
		if loaded_character != null and Input.is_action_pressed(&"character_jump"):
			loaded_character.suppress_jump_until_released()
	_message_game_was_playing = false
	var previous_focus: Control = _message_previous_focus
	_message_previous_focus = null
	if (
		previous_focus != null
		and is_instance_valid(previous_focus)
		and previous_focus.is_visible_in_tree()
		and previous_focus.focus_mode != Control.FOCUS_NONE
	):
		previous_focus.grab_focus.call_deferred()


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
	_dispose_game_instance()
	_apply_menu_viewport_size()
	show_main_menu()


func _dispose_game_instance() -> void:
	if _game_instance == null or not is_instance_valid(_game_instance):
		_game_instance = null
		return
	var game_controller: MainGameController = _loaded_game_controller()
	if game_controller != null:
		game_controller.clear_runtime_state()
	_game_instance.queue_free()
	_game_instance = null


## 결과: 현재 로드된 게임의 authoritative controller를 찾거나 없으면 null을 반환한다.
func _loaded_game_controller() -> MainGameController:
	if _game_instance == null or not is_instance_valid(_game_instance):
		return null
	return _game_instance.get_node_or_null("GameController") as MainGameController


## 상황: 게임 전용 560×1140 창에서 시작 메뉴로 돌아가기 직전에 호출한다.
## 결과: 데스크톱은 content scale과 실제 창 크기를 메뉴 설계 크기로 복원한다.
##       Web은 처음부터 메뉴 viewport를 유지하므로 불필요한 HTML canvas resize를 막는다.
func _apply_menu_viewport_size() -> void:
	var window: Window = get_window()
	window.content_scale_size = MENU_VIEWPORT_SIZE
	if (
		OS.get_name() != "Web"
		and not OS.has_feature("web")
		and not DisplayServer.get_name().contains("headless")
	):
		window.size = MENU_VIEWPORT_SIZE


## 상황: 메뉴 root 안에 고정 해상도의 세로 게임 viewport를 배치할 때 호출한다.
## 결과: Web은 560×1140 SubViewport 결과만 960×800 canvas에 맞춰 중앙 합성한다.
##       물리 노드 자체에는 scale을 적용하지 않아 local/global 좌표 단위가 항상 일치한다.
func _configure_game_host_layout() -> void:
	if OS.get_name() != "Web" and not OS.has_feature("web"):
		_game_host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_game_host.position = Vector2.ZERO
		_game_host.size = Vector2(MainLayout.GAME_VIEWPORT_SIZE)
		_game_host.scale = Vector2.ONE
		return
	var layout: Dictionary = calculate_web_game_layout(
		Vector2(MENU_VIEWPORT_SIZE),
		Vector2(MainLayout.GAME_VIEWPORT_SIZE)
	)
	_game_host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_game_host.position = layout["position"] as Vector2
	_game_host.size = Vector2(MainLayout.GAME_VIEWPORT_SIZE)
	_game_host.scale = Vector2.ONE * float(layout["scale"])


## 결과: content_size의 비율을 유지하면서 viewport_size 안에 모두 들어오는 scale/position을 반환한다.
static func calculate_web_game_layout(viewport_size: Vector2, content_size: Vector2) -> Dictionary:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return {"scale": 1.0, "position": Vector2.ZERO}
	if content_size.x <= 0.0 or content_size.y <= 0.0:
		return {"scale": 1.0, "position": Vector2.ZERO}
	var fit_scale: float = minf(
		viewport_size.x / content_size.x,
		viewport_size.y / content_size.y
	)
	var fitted_size: Vector2 = content_size * fit_scale
	return {
		"scale": fit_scale,
		"position": (viewport_size - fitted_size) * 0.5,
	}


func _play_select_sfx() -> void:
	if _skip_initial_select_sfx:
		_skip_initial_select_sfx = false
		return
	_select_sfx_player.stop()
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
	if not subtitle.is_empty():
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
	return _ui.create_label(parent, _text(text_value), rect, font_size, color, alignment)


func _create_button(
	parent: Control,
	text_value: String,
	rect: Rect2,
	accent: Color,
	font_size: int
) -> Button:
	return _ui.create_button(parent, _text(text_value), rect, accent, font_size)


func _text(korean: String, english: String = "") -> String:
	if settings == null or settings.language == StartScreenSettings.KOREAN:
		return korean
	if settings.language == StartScreenSettings.CHINESE:
		if CHINESE_TEXT.has(korean):
			return String(CHINESE_TEXT[korean])
		return LOCALIZATION.translated_for_language(korean, english, settings.language)
	if not english.is_empty():
		return english
	return String(ENGLISH_TEXT.get(korean, LOCALIZATION.translated(korean)))


func _set_language(language: String) -> void:
	settings.set_language(language)
	get_tree().reload_current_scene()


func _refresh_language_button() -> void:
	if _language_button != null:
		_language_button.text = _language_name(_selected_language)


func _next_language(forward: bool) -> String:
	var languages: Array[String] = [
		StartScreenSettings.ENGLISH,
		StartScreenSettings.KOREAN,
		StartScreenSettings.CHINESE,
	]
	var index: int = languages.find(_selected_language)
	return languages[posmod(index + (1 if forward else -1), languages.size())]


func _language_name(language: String) -> String:
	if language == StartScreenSettings.KOREAN:
		return "한국어"
	if language == StartScreenSettings.CHINESE:
		return "中文"
	return "ENGLISH"


func _confirm_language_selection() -> void:
	if settings.language != _selected_language:
		_set_language(_selected_language)


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
	_add_screen_title(screen, "캐릭터 선택", "")

	for index: int in range(MainCharacterData.CHARACTER_ORDER.size()):
		var character_id: String = MainCharacterData.CHARACTER_ORDER[index]
		var profile: Dictionary = MainCharacterData.profile_for(character_id)
		var card: Button = _create_button(
			screen,
			"",
			Rect2(335.0, 142.0, 270.0, 470.0),
			CYAN,
			16
		)
		card.name = "Character_%s" % character_id
		card.pressed.connect(_select_character.bind(character_id))
		card.focus_entered.connect(_select_character.bind(character_id))
		card.focus_entered.connect(_play_select_sfx)
		_character_buttons.append(card)

		var position_label: Label = _create_label(
			card,
			"",
			Rect2(10.0, 8.0, 58.0, 22.0),
			12,
			MUTED,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		_character_position_labels.append(position_label)
		var unlock_label: Label = _create_label(
			card,
			"",
			Rect2(64.0, 8.0, 194.0, 22.0),
			11,
			DANGER,
			HORIZONTAL_ALIGNMENT_RIGHT
		)
		unlock_label.name = "CharacterUnlockLabel_%s" % character_id
		_character_unlock_labels.append(unlock_label)
		var portrait_texture := AtlasTexture.new()
		portrait_texture.atlas = MainCharacterAnimationData.texture_for_character(character_id)
		portrait_texture.region = PORTRAIT_SOURCE
		var portrait := TextureRect.new()
		portrait.position = Vector2(47.0, 18.0)
		portrait.size = Vector2(176.0, 126.0)
		portrait.texture = portrait_texture
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait)

		_create_label(
			card,
			_text(str(profile["display_name"])),
			Rect2(12.0, 142.0, 246.0, 30.0),
			18,
			TEXT,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		_add_character_stat_bar(card, 174.0, _text("공격속도"), int(profile["attack_speed"]))
		_add_character_stat_bar(card, 204.0, _text("이동속도"), int(profile["move"]))
		_add_character_stat_bar(card, 234.0, _text("점프력"), int(profile["jump"]))
		_add_character_stat_bar(card, 264.0, _text("스태미나"), int(profile["stamina"]))
		_add_character_stat_bar(card, 294.0, _text("특수공격"), int(profile["special_skill"]))

		var skill_panel: Panel = _create_panel(
			card,
			Rect2(12.0, 330.0, 246.0, 127.0),
			PANEL_DARK,
			BORDER,
			7
		)
		skill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skill_panel.clip_contents = true
		_create_label(
			skill_panel,
			_text("특수 · %s") % _text(str(profile["special_name"])),
			Rect2(10.0, 5.0, 226.0, 26.0),
			14,
			TEXT,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		var skill_description: Label = _create_label(
			skill_panel,
			_text(str(profile.get("special_short_description", profile["special_description"]))),
			Rect2(10.0, 34.0, 226.0, 82.0),
			12,
			MUTED,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		skill_description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_character_prev_button = _create_button(
		screen, "<", Rect2(6.0, 210.0, 38.0, 58.0), PURPLE, 19
	)
	_character_prev_button.focus_mode = Control.FOCUS_NONE
	_character_prev_button.pressed.connect(_move_character_focus.bind(-1))
	_character_next_button = _create_button(
		screen, ">", Rect2(916.0, 210.0, 38.0, 58.0), PURPLE, 19
	)
	_character_next_button.focus_mode = Control.FOCUS_NONE
	_character_next_button.pressed.connect(_move_character_focus.bind(1))

	var back_button: Button = _create_button(
		screen,
		"뒤로",
		Rect2(720.0, 630.0, 150.0, 46.0),
		DANGER,
		16
	)
	_character_back_button = back_button
	back_button.pressed.connect(show_stage_select)
	back_button.focus_entered.connect(_play_select_sfx)
	back_button.focus_neighbor_left = back_button.get_path_to(back_button)
	back_button.focus_neighbor_right = back_button.get_path_to(back_button)
	back_button.focus_neighbor_bottom = back_button.get_path_to(back_button)
	_character_card_selected_style = _character_card_style(true)
	_character_card_normal_style = _character_card_style(false)
	_refresh_character_selection()


func _add_character_stat_bar(
	parent: Control,
	y_position: float,
	stat_name: String,
	stat_value: int
) -> void:
	_create_label(
		parent,
		stat_name,
		Rect2(12.0, y_position, 64.0, 24.0),
		12,
		TEXT
	)
	var bar: ProgressBar = ProgressBar.new()
	bar.position = Vector2(80.0, y_position + 6.0)
	bar.size = Vector2(140.0, 12.0)
	bar.min_value = 0.0
	bar.max_value = 10.0
	bar.step = 1.0
	bar.value = clampi(stat_value, 0, 10)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color("#dce3ed")
	background_style.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", background_style)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = SHOP_GOLD
	fill_style.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill_style)
	parent.add_child(bar)
	_create_label(
		parent,
		str(stat_value),
		Rect2(226.0, y_position, 30.0, 24.0),
		12,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)


func _select_character(character_id: String) -> void:
	if not MainCharacterData.has_character(character_id):
		return
	_selected_character_id = character_id
	_refresh_character_selection()


func _confirm_character_selection() -> void:
	if (
		_selected_character_id.is_empty()
		or not MainCharacterData.has_character(_selected_character_id)
	):
		return
	if not settings.is_character_unlocked(_selected_character_id):
		_show_message(
			_text(
				"아직 해금되지 않은 캐릭터입니다.",
				"This character is still locked."
			)
		)
		return
	show_stage_select()


func _refresh_character_selection() -> void:
	if _character_buttons.is_empty():
		return
	var can_browse: bool = (
		not _selected_character_id.is_empty()
		and MainCharacterData.has_character(_selected_character_id)
	)
	_character_prev_button.disabled = not can_browse
	_character_next_button.disabled = not can_browse
	var character_count: int = MainCharacterData.CHARACTER_ORDER.size()
	var selected_index: int = MainCharacterData.CHARACTER_ORDER.find(_selected_character_id)
	if selected_index < 0:
		selected_index = 0
	var visible_indices: Array[int] = [
		posmod(selected_index - 1, character_count),
		selected_index,
		posmod(selected_index + 1, character_count),
	]
	for index: int in range(_character_buttons.size()):
		var button: Button = _character_buttons[index]
		var visible_slot: int = visible_indices.find(index)
		var is_visible: bool = visible_slot >= 0
		if button.visible != is_visible:
			button.visible = is_visible
		if not is_visible:
			continue
		var target_position: Vector2 = Vector2(50.0 + float(visible_slot) * 285.0, 142.0)
		if button.position != target_position:
			button.position = target_position
		var left_button: Button = _character_buttons[visible_indices[maxi(0, visible_slot - 1)]]
		var right_button: Button = _character_buttons[visible_indices[mini(2, visible_slot + 1)]]
		button.focus_neighbor_left = button.get_path_to(left_button)
		button.focus_neighbor_right = button.get_path_to(right_button)
		button.focus_neighbor_bottom = button.get_path_to(_character_back_button)
		button.focus_neighbor_top = button.get_path_to(button)
		_character_position_labels[index].text = [
			_text("이전"),
			_text("현재"),
			_text("다음"),
		][visible_slot]
	for index: int in range(_character_buttons.size()):
		var button: Button = _character_buttons[index]
		var character_id: String = MainCharacterData.CHARACTER_ORDER[index]
		var unlocked: bool = settings != null and settings.is_character_unlocked(character_id)
		var profile: Dictionary = MainCharacterData.profile_for(character_id)
		if index < _character_unlock_labels.size():
			var unlock_label: Label = _character_unlock_labels[index]
			unlock_label.text = _character_unlock_status_text(profile, unlocked)
			unlock_label.add_theme_color_override(
				"font_color",
				CYAN if unlocked else DANGER
			)
		if not button.visible:
			continue
		_apply_card_style(
			button,
			character_id == _selected_character_id,
			unlocked
		)


func _character_unlock_status_text(profile: Dictionary, unlocked: bool) -> String:
	if unlocked:
		return _text("해금 완료", "UNLOCKED")
	if bool(profile.get("unlock_all_no_damage", false)):
		if settings != null and settings.language == StartScreenSettings.CHINESE:
			return "未解锁 · 全关卡无伤"
		return _text("잠김 · 전 스테이지 무피해", "LOCKED · NO-DAMAGE ALL STAGES")
	var required_stars: int = int(profile.get("unlock_stars", 0))
	if settings != null and settings.language == StartScreenSettings.CHINESE:
		return "未解锁 · %d 颗星" % required_stars
	return _text("잠김 · 별 %d개", "LOCKED · %d STARS") % required_stars


func _character_card_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CYAN.darkened(0.72) if selected else PANEL
	style.border_color = CYAN if selected else BORDER
	style.set_border_width_all(3 if selected else 1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style


func _apply_card_style(button: Button, selected: bool, unlocked: bool = true) -> void:
	button.add_theme_stylebox_override(
		"normal",
		_character_card_selected_style if selected else _character_card_normal_style
	)
	button.modulate = (
		Color.WHITE
		if selected and unlocked
		else _CHARACTER_INSELECT_MODULATE
		if unlocked
		else Color(0.48, 0.50, 0.54, 0.72)
	)
	for child: Node in button.get_children():
		if child is Label:
			if String(child.name).begins_with("CharacterUnlockLabel_"):
				continue
			(child as Label).add_theme_color_override(
				"font_color",
				Color.WHITE if selected else TEXT
			)


## 상황: 게임 설명의 canvas·탐색 버튼·counter·뒤로가기를 최초 조립할 때 호출된다.
## 순서: screen/title → TutorialCanvas 설정 주입 → prev/next/counter/back 생성과 signal 연결.
## 결과: page 멤버만 바꾸면 재사용 가능한 TUTORIAL 화면이 완성된다.
