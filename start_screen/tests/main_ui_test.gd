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
		screen.settings.get_action_keys(&"character_self_respawn") == [KEY_Q],
		"삭제된 차지 펀치 키 Q는 자력 재스폰 기본키로 쓴다."
	)
	_expect(
		screen.settings.is_stage_unlocked(1)
			and not screen.settings.is_stage_unlocked(2)
			and screen.settings.star_currency == 0,
		"처음에는 1-1만 열리고 별 화폐는 0이다."
	)
	var zero_clear: Dictionary = screen.settings.complete_stage(1, 0)
	_expect(
		not bool(zero_clear.get("ok", false))
			and screen.settings.get_stage_best_stars(1) == 0
			and screen.settings.star_currency == 0,
		"줄을 하나도 삭제하지 않으면 스테이지 클리어에 실패한다."
	)
	var first_clear: Dictionary = screen.settings.complete_stage(1, 1)
	_expect(
		bool(first_clear.get("ok", false))
			and screen.settings.get_stage_best_stars(1) == 1
			and screen.settings.is_stage_unlocked(2)
			and screen.settings.star_currency == 1,
		"1-1의 1별 클리어가 다음 스테이지와 별 1개를 연다."
	)
	var repeated_clear: Dictionary = screen.settings.complete_stage(1, 1)
	_expect(
		int(repeated_clear.get("reward", -1)) == 0
			and screen.settings.star_currency == 1,
		"같은 별 수 재클리어는 별을 추가하지 않는다."
	)
	var upgraded_clear: Dictionary = screen.settings.complete_stage(1, 3)
	_expect(
		int(upgraded_clear.get("reward", -1)) == 2
			and screen.settings.get_stage_best_stars(1) == 3
			and screen.settings.star_currency == 3,
		"1별에서 3별로 올리면 차이만큼 별 2개를 준다."
	)
	var reloaded_settings: StartScreenSettings = StartScreenSettings.new(TEST_SETTINGS_PATH)
	reloaded_settings.load_settings()
	_expect(
		reloaded_settings.get_stage_best_stars(1) == 3
			and reloaded_settings.star_currency == 3,
		"스테이지 별과 별 화폐가 설정 파일에 저장된다."
	)
	reloaded_settings.free()
	var back_event: InputEventKey = InputEventKey.new()
	back_event.pressed = true
	back_event.physical_keycode = KEY_X
	screen.show_tutorial()
	_expect(
		screen._handle_back_navigation(back_event)
			and screen.current_screen == KungFuTetrisStartScreen.Screen.MAIN,
		"게임 설명에서 X가 메인 메뉴로 돌아간다."
	)
	screen.show_options()
	_expect(
		screen._handle_back_navigation(back_event)
			and screen.current_screen == KungFuTetrisStartScreen.Screen.MAIN,
		"OPTION에서 X가 메인 메뉴로 돌아간다."
	)
	screen.show_options()
	screen._show_progress_reset_prompt()
	screen._confirm_progress_reset()
	_expect(
		screen.settings.star_currency == 0
			and screen.settings.get_stage_best_stars(1) == 0
			and not screen.settings.is_stage_unlocked(2),
		"진행 데이터 삭제는 스테이지 별, 해금, 별 재화만 초기화한다."
	)
	await process_frame
	_expect(
		screen._options_first_button.has_focus(),
		"진행 데이터 삭제 확인 뒤 OPTION 첫 버튼에 초점을 돌린다."
	)
	screen.show_main_menu()
	await process_frame

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
	_expect(screen.current_screen == KungFuTetrisStartScreen.Screen.STAGE_SELECT, "GAME START가 스테이지 선택을 연다.")
	await process_frame
	var stage_button: Button = screen.find_child("StageButton1", true, false) as Button
	_expect(stage_button != null and not stage_button.disabled, "1-1 스테이지 버튼을 선택할 수 있다.")
	if stage_button != null:
		stage_button.pressed.emit()
	_expect(screen.current_screen == KungFuTetrisStartScreen.Screen.GAME, "스테이지 선택이 게임 장면을 연다.")
	await process_frame
	await physics_frame
	var character: MainCharacterController = screen._game_instance.get_node("BoardPhysics/Character")
	_expect(character.velocity.y >= 0.0, "메뉴 Z를 누른 채 시작해도 캐릭터가 점프하지 않는다.")
	Input.action_release(&"character_jump")
	var controller: MainGameController = screen._loaded_game_controller()
	_expect(controller != null, "실행 중인 게임 controller를 찾는다.")
	if controller != null:
		_expect(
			InputMap.action_get_events(&"character_self_respawn").size() == 1,
			"자력 재스폰은 기본 Q 하나를 사용한다."
		)
		var escape_event: InputEventKey = InputEventKey.new()
		escape_event.pressed = true
		escape_event.physical_keycode = KEY_ESCAPE
		var handled: bool = screen._handle_game_exit_prompt_input(escape_event)
		var overlay: Control = screen.find_child("GameExitOverlay", true, false) as Control
		var exit_panel: Panel = null
		if overlay != null:
			exit_panel = overlay.find_child("GameExitPanel", true, false) as Panel
		_expect(
			handled
				and overlay != null
				and overlay.visible
				and exit_panel != null
				and exit_panel.position == Vector2(60.0, 440.0),
			"게임 중 Esc가 화면 중앙 확인창을 연다."
		)
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

	screen.show_stage_select()
	await process_frame
	stage_button = screen.find_child("StageButton1", true, false) as Button
	if stage_button != null:
		stage_button.pressed.emit()
	await process_frame
	var debug_enter_event: InputEventKey = InputEventKey.new()
	debug_enter_event.pressed = true
	debug_enter_event.physical_keycode = KEY_ENTER
	var debug_release_event: InputEventKey = InputEventKey.new()
	debug_release_event.physical_keycode = KEY_ENTER
	screen._input(debug_release_event)
	var debug_echo_event: InputEventKey = InputEventKey.new()
	debug_echo_event.pressed = true
	debug_echo_event.echo = true
	debug_echo_event.physical_keycode = KEY_ENTER
	screen._input(debug_echo_event)
	_expect(
		screen.current_screen == KungFuTetrisStartScreen.Screen.GAME
			and screen._game_instance != null,
		"Enter를 놓거나 반복 입력한 것은 디버그 완료를 실행하지 않는다."
	)
	screen._input(debug_enter_event)
	var result_overlay: Control = screen.find_child("StageResultOverlay", true, false) as Control
	_expect(
		OS.is_debug_build()
			and screen.current_screen == KungFuTetrisStartScreen.Screen.STAGE_SELECT
			and screen._game_instance == null
			and result_overlay != null
			and result_overlay.visible,
		"디버그 Enter가 3별 완료 결과를 표시하고 스테이지 선택으로 돌아간다."
	)
	var result_button: Button = screen.find_child("StageResultButton", true, false) as Button
	if result_button != null:
		result_button.pressed.emit()
	_expect(
		result_overlay != null and not result_overlay.visible
			and screen.current_screen == KungFuTetrisStartScreen.Screen.STAGE_SELECT,
		"완료 결과 확인이 스테이지 선택을 유지한다."
	)
	for stage_number: int in range(2, 5):
		var unlock_result: Dictionary = screen.settings.complete_stage(stage_number, 3)
		_expect(
			bool(unlock_result.get("ok", false)),
			"Stage %d 디버그 테스트를 위해 이전 스테이지를 해금한다." % stage_number
		)
	screen.start_game(5)
	await process_frame
	var boss_controller: MainGameController = screen._loaded_game_controller()
	_expect(
		boss_controller != null
			and boss_controller.is_boss_stage()
			and boss_controller.boss_health == MainGameController.BOSS_MAX_HEALTH,
		"Stage 5 Enter 테스트에서 보스 체력 3으로 게임을 시작한다."
	)
	screen._input(debug_enter_event)
	_expect(
		boss_controller != null
			and boss_controller.boss_health == 0
			and boss_controller.state == MainGameController.GameState.BOSS_FALLING
			and screen.current_screen == KungFuTetrisStartScreen.Screen.GAME
			and screen._game_instance != null,
		"Stage 5의 Enter는 즉시 결과 처리 대신 보스 체력을 0으로 만든다."
	)
	if boss_controller != null:
		boss_controller._advance_boss_fall(
			MainGameController.BOSS_DOWN_DURATION_SECONDS + 2.0
		)
		boss_controller._advance_boss_fall(MainGameController.BOSS_FALLEN_HOLD_SECONDS)
	await process_frame
	_expect(
		screen.current_screen == KungFuTetrisStartScreen.Screen.STAGE_SELECT
			and screen._game_instance == null
			and result_overlay != null
			and result_overlay.visible
			and screen.settings.get_stage_best_stars(5) == 3,
		"Stage 5 보스가 쓰러지면 3별 결과 화면으로 전환한다."
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
