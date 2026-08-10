extends SceneTree

## [역할 / C++ 대응]
## 시작 화면의 설정 migration, Z 메뉴 확인, Esc 복귀 modal과 X 취소를 실제 scene으로 검증한다.
## C++로 보면 임시 설정 파일과 UI object graph를 조립하는 integration-test executable에 가깝다.

const START_SCREEN_SCENE: PackedScene = preload(
	"res://start_screen/scenes/start_screen.tscn"
) # 테스트마다 새 시작 화면을 만드는 scene factory.
const TEST_SETTINGS_PATH: String = "res://build/main_ui_test_settings.cfg" # workspace 내부 임시 cfg 경로.

var _checks: int = 0 # 수행한 assertion 총수.
var _failures: int = 0 # 실패 assertion 수와 process exit code.


## 상황: SceneTree test runner 생성 직후 호출된다.
## 결과: scene tree 초기화 뒤 async `_run()`을 실행하도록 deferred 예약한다.
func _init() -> void:
	call_deferred("_run")


## 상황: UI 통합 테스트의 단일 진입점이다.
## 순서: legacy cfg 작성 → 화면 생성/migration 검사 → Z 시작 → Esc/X/Yes 흐름 → 리소스 정리.
## 결과: 실패 수를 종료 코드로 반환하고 테스트 파일과 audio 참조를 남기지 않는다.
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var legacy_config: ConfigFile = ConfigFile.new() # 구버전/충돌 키를 재현할 fixture serializer.
	legacy_config.set_value("input", "pause_game", [KEY_ESCAPE])
	legacy_config.set_value("input", "character_left", [KEY_ESCAPE, KEY_F])
	legacy_config.set_value("input", "character_punch", [KEY_Q])
	legacy_config.set_value("input", "character_grab", [KEY_K])
	legacy_config.set_value("input", "character_rotation_kick", [KEY_BACKSPACE])
	legacy_config.save(TEST_SETTINGS_PATH)
	var screen: KungFuTetrisStartScreen = START_SCREEN_SCENE.instantiate() # 테스트가 소유할 실제 UI root.
	screen.settings_file_path = TEST_SETTINGS_PATH
	screen.suppress_quit_for_tests = true
	root.add_child(screen)
	await process_frame
	await process_frame
	var reserved_escape_result: Dictionary = screen.settings.set_binding( # 예약키 재지정 시도 결과.
		&"pause_game",
		0,
		KEY_ESCAPE
	)
	_expect(
		not bool(reserved_escape_result.get("ok", false))
			and screen.settings.get_action_keys(&"pause_game") == [KEY_P],
		"저장된 Esc 일시정지 키는 P로 복원되고 Esc 재지정은 거부한다."
	)
	_expect(
		screen.settings.get_action_keys(&"character_left") == [KEY_F],
		"저장된 Esc만 제거하고 다른 사용자 키는 유지한다."
	)
	_expect(
		screen.settings.get_action_keys(&"character_self_respawn") == [KEY_NONE],
		"Q·K·Backspace가 사용 중이면 자력 재스폰을 미지정으로 둔다."
	)

	var enter_event: InputEventKey = InputEventKey.new() # 메뉴가 Enter를 확인으로 쓰지 않는지 볼 합성 event.
	enter_event.pressed = true
	enter_event.physical_keycode = KEY_ENTER
	_expect(screen._handle_menu_confirm_input(enter_event), "Enter는 메뉴 선택으로 처리하지 않는다.")
	_expect(screen.current_screen == KungFuTetrisStartScreen.Screen.MAIN, "Enter는 시작 메뉴를 유지한다.")
	var menu_confirm_event: InputEventKey = InputEventKey.new() # Z 확인 경로를 직접 호출할 합성 event.
	menu_confirm_event.pressed = true
	menu_confirm_event.physical_keycode = KEY_Z
	Input.action_press(&"character_jump")
	_expect(screen._handle_menu_confirm_input(menu_confirm_event), "Z가 초점 메뉴 버튼을 선택한다.")
	_expect(
		screen.current_screen == KungFuTetrisStartScreen.Screen.CHARACTER,
		"첫 Z는 게임 전에 캐릭터 선택 화면을 연다."
	)
	_expect(screen._character_buttons.size() == 8, "선택 화면에 확정 캐릭터 카드 여덟 개가 구성된다.")
	var visible_cards: int = 0
	for card: Button in screen._character_buttons:
		visible_cards += 1 if card.visible else 0
	_expect(visible_cards == 3, "캐릭터 캐러셀에는 카드 세 장만 표시된다.")
	screen._select_character("normal")
	screen._shift_character_window(1)
	screen._shift_character_window(1)
	screen._shift_character_window(1)
	_expect(
		screen._selected_character_id.is_empty() and screen._character_confirm_button.disabled,
		"선택 카드가 창 밖으로 나가면 선택과 시작 버튼을 해제한다."
	)
	screen._shift_character_window(1)
	screen._shift_character_window(1)
	screen._select_character("clockmaker")
	_expect(
		screen._character_detail_label.text.contains("시간을 멈추려면 먼저 시간을 견뎌라"),
		"시계공 상세 패널에는 정확한 수치 대신 조건 해금 힌트를 표시한다."
	)
	screen._select_character("ninja")
	screen._character_confirm_button.grab_focus()
	_expect(screen._handle_menu_confirm_input(menu_confirm_event), "선택 확정도 Z로 처리한다.")
	_expect(screen.current_screen == KungFuTetrisStartScreen.Screen.GAME, "확정 후 게임 장면을 연다.")
	await process_frame
	await physics_frame
	var character: MainCharacterController = screen._game_instance.get_node("BoardPhysics/Character") # Z 점프 누수 관찰 대상.
	_expect(character.character_id == "ninja", "선택한 닌자 ID와 atlas가 실제 게임 캐릭터에 전달된다.")
	_expect(character.velocity.y >= 0.0, "메뉴 Z를 누른 채 시작해도 캐릭터가 점프하지 않는다.")
	Input.action_release(&"character_jump")
	var controller: MainGameController = screen._loaded_game_controller() # modal pause/resume 상태 관찰 대상.
	_expect(controller != null, "실행 중인 게임 controller를 찾는다.")
	if controller != null:
		_expect(
			InputMap.action_get_events(&"character_self_respawn").is_empty(),
			"미지정 자력 재스폰에 GameController 기본 Q를 중복 추가하지 않는다."
		)
		var escape_event: InputEventKey = InputEventKey.new()
		escape_event.pressed = true
		escape_event.physical_keycode = KEY_ESCAPE
		var handled: bool = screen._handle_game_exit_prompt_input(escape_event)
		var overlay: Control = screen.find_child("GameExitOverlay", true, false) as Control
		_expect(handled and overlay != null and overlay.visible, "게임 중 Esc가 확인창을 연다.")
		_expect(controller.state == MainGameController.GameState.PAUSED, "Esc 메뉴가 게임 상태를 일시정지로 바꾼다.")
		_expect(not controller.is_physics_processing(), "확인창이 physics process를 잠근다.")
		var cancel_event: InputEventKey = InputEventKey.new()
		cancel_event.pressed = true
		cancel_event.physical_keycode = KEY_X
		_expect(screen._handle_game_exit_prompt_input(cancel_event), "X가 확인창 취소를 처리한다.")
		_expect(
			not overlay.visible
				and controller.is_physics_processing()
				and controller.state == MainGameController.GameState.PLAYING,
			"X가 일시정지 전 게임 상태를 복원한다."
		)
		screen._handle_game_exit_prompt_input(escape_event)
		await process_frame
		var move_event: InputEventKey = InputEventKey.new()
		move_event.pressed = true
		move_event.physical_keycode = KEY_UP
		_expect(screen._handle_game_exit_prompt_input(move_event), "위 화살표가 메뉴 선택을 이동한다.")
		var yes_button: Button = screen.find_child("GameExitYesButton", true, false) as Button
		_expect(yes_button != null and yes_button.has_focus(), "Yes 선택에 초점이 이동한다.")
		if yes_button != null:
			var confirm_event: InputEventKey = InputEventKey.new()
			confirm_event.pressed = true
			confirm_event.physical_keycode = KEY_Z
			screen._handle_game_exit_prompt_input(confirm_event)
			await process_frame
			await process_frame
		_expect(
			screen.current_screen == KungFuTetrisStartScreen.Screen.MAIN
				and screen._game_instance == null
				and screen.find_child("LoadedGame", true, false) == null,
			"Yes는 게임 인스턴스를 제거하고 메인 메뉴로 돌아간다."
		)

	screen._select_sfx_player.stop()
	screen._select_sfx_player.stream = null
	screen._select_sfx_timer.stop()
	await create_timer(0.12).timeout
	screen.free()
	await process_frame
	var settings_path: String = ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(settings_path)
	if _failures == 0:
		print("성공: 메인 UI 테스트 %d개 통과" % _checks)
	else:
		push_error("실패: 시작 화면 통합 테스트 %d/%d개 실패" % [_failures, _checks])
	quit(_failures)


## 상황: 각 UI 계약의 boolean 결과를 누적하고 콘솔에 통과/실패를 출력할 때 호출된다.
## 결과: check는 항상 증가하고 false 조건에서만 failure가 증가한다.
func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  [통과] %s" % description)
	else:
		_failures += 1
		push_error("  [실패] %s" % description)
