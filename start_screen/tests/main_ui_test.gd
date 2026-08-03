extends SceneTree

const START_SCREEN_SCENE: PackedScene = preload(
	"res://start_screen/scenes/start_screen.tscn"
)
const TEST_SETTINGS_PATH: String = "user://main_ui_test_settings.cfg"

var _checks: int = 0
var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var legacy_config: ConfigFile = ConfigFile.new()
	legacy_config.set_value("input", "pause_game", [KEY_ESCAPE])
	legacy_config.set_value("input", "character_left", [KEY_ESCAPE, KEY_F])
	legacy_config.set_value("input", "character_punch", [KEY_Q])
	legacy_config.set_value("input", "character_grab", [KEY_K])
	legacy_config.set_value("input", "character_rotation_kick", [KEY_BACKSPACE])
	legacy_config.save(TEST_SETTINGS_PATH)
	var screen: KungFuTetrisStartScreen = START_SCREEN_SCENE.instantiate()
	screen.settings_file_path = TEST_SETTINGS_PATH
	screen.suppress_quit_for_tests = true
	root.add_child(screen)
	await process_frame
	await process_frame
	var reserved_escape_result: Dictionary = screen.settings.set_binding(
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

	var enter_event: InputEventKey = InputEventKey.new()
	enter_event.pressed = true
	enter_event.physical_keycode = KEY_ENTER
	_expect(screen._handle_menu_confirm_input(enter_event), "Enter는 메뉴 선택으로 처리하지 않는다.")
	_expect(screen.current_screen == KungFuTetrisStartScreen.Screen.MAIN, "Enter는 시작 메뉴를 유지한다.")
	var menu_confirm_event: InputEventKey = InputEventKey.new()
	menu_confirm_event.pressed = true
	menu_confirm_event.physical_keycode = KEY_Z
	Input.action_press(&"character_jump")
	_expect(screen._handle_menu_confirm_input(menu_confirm_event), "Z가 초점 메뉴 버튼을 선택한다.")
	_expect(screen.current_screen == KungFuTetrisStartScreen.Screen.GAME, "Z로 게임 장면을 연다.")
	await process_frame
	await physics_frame
	var character: MainCharacterController = screen._game_instance.get_node("BoardPhysics/Character")
	_expect(character.velocity.y >= 0.0, "메뉴 Z를 누른 채 시작해도 캐릭터가 점프하지 않는다.")
	Input.action_release(&"character_jump")
	var controller: MainGameController = screen._loaded_game_controller()
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


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  [통과] %s" % description)
	else:
		_failures += 1
		push_error("  [실패] %s" % description)
