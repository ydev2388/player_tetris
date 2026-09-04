extends SceneTree

const START_SCREEN_SCENE: PackedScene = preload(
	"res://start_screen/scenes/start_screen.tscn"
)
const INPUT_ACTIONS: Script = preload("res://scripts/input_actions.gd")
const TEST_SETTINGS_PATH: String = "res://build/main_ui_test_settings.cfg"

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
	var screen: BlockFighterStartScreen = START_SCREEN_SCENE.instantiate()
	screen.settings_file_path = TEST_SETTINGS_PATH
	screen.suppress_quit_for_tests = true
	root.add_child(screen)
	await process_frame
	await process_frame
	var required_web_glyphs: String = "한中★←→×！■"
	var missing_web_glyphs: Array[String] = []
	for glyph: String in required_web_glyphs:
		if not screen._font.has_char(glyph.unicode_at(0)):
			missing_web_glyphs.append(glyph)
	_expect(
		missing_web_glyphs.is_empty(),
		"내장 Web 폰트가 한글·중국어·메뉴 기호를 모두 포함한다. 누락: %s"
		% ", ".join(missing_web_glyphs)
	)
	var web_game_layout: Dictionary = BlockFighterStartScreen.calculate_web_game_layout(
		Vector2(960.0, 800.0),
		Vector2(560.0, 1140.0)
	)
	var expected_web_scale: float = 800.0 / 1140.0
	var expected_web_x: float = (960.0 - 560.0 * expected_web_scale) * 0.5
	_expect(
		is_equal_approx(float(web_game_layout["scale"]), expected_web_scale)
			and is_equal_approx((web_game_layout["position"] as Vector2).x, expected_web_x)
			and is_equal_approx((web_game_layout["position"] as Vector2).y, 0.0),
		"웹 게임 화면은 560×1140 전체를 960×800 안에 비율 유지로 중앙 정렬한다."
	)
	_expect(
		screen._game_viewport != null
			and screen._game_viewport.size == Vector2i(560, 1140)
			and screen._game_viewport_container != null
			and screen._game_viewport_container.stretch
			and screen._game_host.size.is_equal_approx(Vector2(560.0, 1140.0)),
		"게임 물리는 고정 560×1140 SubViewport에서 실행되고 표시 surface만 맞춤 확대한다."
	)
	_expect(
		screen._screen_router is BlockFighterScreenRouter
			and screen.current_screen == screen._screen_router.current_screen,
		"화면 전환 상태는 StartScreen이 아니라 ScreenRouter가 소유한다."
	)
	var all_screen_views_connected: bool = screen._screen_router._views.size() == 9
	for screen_id: Variant in screen._screens:
		var registered_view: BlockFighterScreenView = screen._screen_router.view_for(int(screen_id))
		all_screen_views_connected = all_screen_views_connected and (
			registered_view != null
			and registered_view.root == screen._screens[screen_id]
		)
	_expect(
		all_screen_views_connected,
		"게임 외 각 메뉴 화면은 독립 ScreenView 인스턴스로 Router에 등록된다."
	)
	var main_screen_view: BlockFighterScreenView = screen._screen_router.view_for(
		BlockFighterStartScreen.Screen.MAIN
	)
	_expect(
		main_screen_view._focus_candidates.size() == screen._main_buttons.size()
			and not main_screen_view._focus_candidates.is_empty(),
		"화면 진입 포커스 후보 선택은 StartScreen match가 아니라 각 ScreenView가 소유한다."
	)
	_expect(
		screen._screen_router.view_for(BlockFighterStartScreen.Screen.MAIN).root.visible
			and not screen._game_host.visible,
		"현재 화면 View만 표시되고 게임 host는 메뉴에서 숨겨진다."
	)
	var screen_before_invalid_route: int = screen.current_screen
	_expect(
		not screen._screen_router.route(999, BlockFighterStartScreen.Screen.GAME)
			and screen.current_screen == screen_before_invalid_route,
		"등록되지 않은 화면 요청은 현재 화면 상태를 바꾸지 않는다."
	)
	screen.show_tutorial()
	await process_frame
	var tutorial_view: BlockFighterScreenView = screen._screen_router.view_for(
		BlockFighterStartScreen.Screen.TUTORIAL
	)
	_expect(
		screen.current_screen == BlockFighterStartScreen.Screen.TUTORIAL
			and tutorial_view.root.visible
			and not screen._screen_router.view_for(BlockFighterStartScreen.Screen.MAIN).root.visible,
		"ScreenRouter가 화면 전환과 대상 View 진입을 한 경계에서 처리한다."
	)
	screen.show_main_menu()
	await process_frame
	_expect(
		screen.settings._progression_service is BlockFighterProgressionService
			and screen.settings._audio_settings_adapter is BlockFighterAudioSettingsAdapter
			and screen.settings._settings_repository is BlockFighterSettingsRepository,
		"진행도 규칙, 오디오 적용, 설정 저장은 서로 다른 객체가 소유한다."
	)
	_expect(
		screen.settings.star_currency
			== screen.settings._progression_service.star_currency
			and screen.settings.music_percent
			== screen.settings._audio_settings_adapter.music_percent,
		"기존 Settings 공개 API는 분리된 원본 상태를 위임하는 호환 facade다."
	)
	_expect(
		screen.settings._settings_repository.settings_path == TEST_SETTINGS_PATH,
		"SettingsRepository만 현재 ConfigFile 저장 경로를 소유한다."
	)
	var repository_source := FileAccess.get_file_as_string(
		"res://start_screen/scripts/settings_repository.gd"
	)
	var settings_source := FileAccess.get_file_as_string(
		"res://start_screen/scripts/start_screen_settings.gd"
	)
	var codec_source := FileAccess.get_file_as_string(
		"res://start_screen/scripts/settings_codec.gd"
	)
	_expect(
		repository_source.find("set_value") == -1
			and settings_source.find("get_value") == -1
			and codec_source.find("set_value") >= 0
			and codec_source.find("get_value") >= 0,
		"ConfigFile schema key는 Codec, 파일 경로는 Repository, 값 검증은 Settings로 분리된다."
	)
	var detached_progress_snapshot: Dictionary = (
		screen.settings._progression_service.snapshot()
	)
	(detached_progress_snapshot["stage_best_stars"] as Array)[0] = 3
	_expect(
		screen.settings.get_stage_best_stars(1) == 0,
		"ProgressionService 스냅샷을 외부에서 바꿔도 원본 진행도는 오염되지 않는다."
	)
	_expect(
		AudioServer.get_bus_index(BlockFighterAudioSettingsAdapter.MUSIC_BUS) >= 0
			and AudioServer.get_bus_index(BlockFighterAudioSettingsAdapter.SFX_BUS) >= 0,
		"AudioSettingsAdapter가 BGM/SFX AudioServer 경계를 생성하고 적용한다."
	)
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
		screen.settings.language == StartScreenSettings.ENGLISH,
		"언어 기본값은 english다."
	)
	screen.settings.set_language(StartScreenSettings.ENGLISH)
	_expect(
		screen.settings.language == StartScreenSettings.ENGLISH,
		"언어 설정은 english로 유지된다."
	)
	_expect(
		screen.settings.get_action_label(&"character_jump") == "Jump"
			and screen.settings.get_passive_name(2) == "Jump"
			and screen.settings.get_passive_description(2) == "Increases jump height.",
		"영어 액션·패시브 이름과 설명이 적용된다."
	)
	_expect(
		screen._text("OPTION") == "OPTION"
			and screen._text("도전 모드", "CHALLENGE MODE") == "CHALLENGE MODE"
			and screen._text("%d구역\n%d-%d층", "AREA %d\nFLOORS %d-%d")
				== "AREA %d\nFLOORS %d-%d"
			and screen._text("새 develop 문구", "NEW DEVELOP TEXT") == "NEW DEVELOP TEXT",
		"영어 메뉴 문구와 폴백이 적용된다."
	)
	var localized_game_view := MainGameView.new()
	_expect(
		localized_game_view._text("목숨: %d", "LIVES: %d") == "LIVES: %d"
			and localized_game_view._text("새 게임 문구", "NEW GAME TEXT") == "NEW GAME TEXT",
		"게임 HUD는 영어 문구를 사용한다."
	)
	localized_game_view.free()
	_expect(
		screen.settings.is_stage_unlocked(1)
			and not screen.settings.is_stage_unlocked(2)
			and not screen.settings.is_challenge_unlocked()
			and screen.settings.challenge_best_lines == 0
			and screen.settings.is_character_unlocked("normal")
			and not screen.settings.is_character_unlocked("boxer")
			and screen.settings.star_currency == 0,
		"처음에는 1-1과 일반인만 열리고 도전 모드·다음 스테이지·다른 캐릭터는 잠겨 있다."
	)
	_expect(
		screen.settings.is_stage_unlocked(6) == false,
		"6층은 5층을 클리어하기 전에는 잠겨 있다."
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
			and reloaded_settings.star_currency == 3
			and reloaded_settings.is_character_unlocked("boxer"),
		"스테이지 별·별 화폐와 캐릭터 해금이 설정 파일에서 복원된다."
	)
	var migrated_config: ConfigFile = ConfigFile.new()
	var migration_load_error: Error = migrated_config.load(TEST_SETTINGS_PATH)
	_expect(
		migration_load_error == OK
			and migrated_config.get_value("meta", "version", 0) == StartScreenSettings.SETTINGS_SCHEMA_VERSION
			and migrated_config.has_section_key("input", "character_self_respawn"),
		"키 migration 결과와 schema version을 설정 파일에 저장한다."
	)
	reloaded_settings.free()
	var corrupt_path: String = "res://build/main_ui_corrupt_settings.cfg"
	var corrupt_config: ConfigFile = ConfigFile.new()
	corrupt_config.set_value("input", "character_left", ["bad"])
	corrupt_config.set_value("audio", "music_percent", "bad")
	corrupt_config.set_value("audio", "sfx_percent", 150.0)
	corrupt_config.set_value("options", "language", "bad")
	corrupt_config.set_value("progress", "star_currency", -5)
	corrupt_config.set_value("progress", "passive_levels", [9, "bad"])
	corrupt_config.save(corrupt_path)
	var corrupt_settings: StartScreenSettings = StartScreenSettings.new(corrupt_path)
	corrupt_settings.load_settings()
	_expect(
		corrupt_settings.get_action_keys(&"character_left") == INPUT_ACTIONS.get_default_keys(&"character_left")
			and corrupt_settings.music_percent == 100.0
			and corrupt_settings.sfx_percent == 100.0
			and corrupt_settings.language == StartScreenSettings.ENGLISH
			and corrupt_settings.star_currency == 0
			and corrupt_settings.get_passive_level("attack_speed") == 3
			and corrupt_settings.get_passive_level("move") == 0,
		"잘못된 설정값은 안전한 기본값과 범위 안의 값으로 복구한다."
	)
	corrupt_settings.free()
	var save_failure_settings: StartScreenSettings = StartScreenSettings.new(
		"user://missing_settings_directory/settings.cfg"
	)
	save_failure_settings.load_settings()
	var original_left_keys: Array[int] = save_failure_settings.get_action_keys(&"character_left")
	var failed_binding_result: Dictionary = save_failure_settings.set_binding(
		&"character_left",
		0,
		KEY_F9
	)
	var failed_music_result: Dictionary = save_failure_settings.set_music_percent(25.0)
	var failed_reset_result: Dictionary = save_failure_settings.reset_bindings_to_defaults()
	save_failure_settings.set_language(StartScreenSettings.ENGLISH)
	_expect(
		save_failure_settings.get_action_keys(&"character_left") == original_left_keys
			and save_failure_settings.music_percent == 100.0
			and save_failure_settings.language == StartScreenSettings.ENGLISH,
		"설정 저장 실패 시 키·볼륨·언어의 메모리 값을 이전 상태로 되돌린다."
	)
	_expect(
		not bool(failed_binding_result.get("ok", true))
			and not bool(failed_music_result.get("ok", true))
			and not bool(failed_reset_result.get("ok", true))
			and "저장" in String(failed_binding_result.get("message", ""))
			and "저장" in String(failed_music_result.get("message", ""))
			and "저장" in String(failed_reset_result.get("message", "")),
		"설정 명령은 저장 실패를 구체적 실패 결과로 호출자에게 전달한다."
	)
	save_failure_settings.free()

	var original_screen_settings_path: String = screen.settings.settings_path
	var committed_music_percent: float = screen.settings.music_percent
	screen.settings.settings_path = "user://missing_settings_directory/settings.cfg"
	screen._on_music_changed(25.0)
	_expect(
		screen.settings.music_percent == committed_music_percent
			and is_equal_approx(screen._music_slider.value, committed_music_percent)
			and screen._music_value_label.text == "%d%%" % roundi(committed_music_percent),
		"볼륨 저장 실패 후 slider와 label은 롤백된 committed 값을 다시 표시한다."
	)
	screen.settings.settings_path = original_screen_settings_path
	screen._hide_message()

	var no_damage_path: String = "res://build/main_ui_no_damage_settings.cfg"
	var no_damage_settings := StartScreenSettings.new(no_damage_path)
	for stage_number: int in range(1, StartScreenSettings.STAGE_COUNT):
		no_damage_settings.complete_stage(stage_number, 3, 3, true)
	_expect(
		not no_damage_settings.is_character_unlocked("ninja"),
		"1~9층만 무피해이면 전 스테이지 조건의 닌자는 잠겨 있다."
	)
	no_damage_settings.complete_stage(StartScreenSettings.STAGE_COUNT, 3, 2, false)
	_expect(
		not no_damage_settings.is_character_unlocked("ninja"),
		"10층을 피해 입고 클리어해도 닌자는 잠겨 있다."
	)
	no_damage_settings.complete_stage(StartScreenSettings.STAGE_COUNT, 3, 3, true)
	_expect(
		no_damage_settings.is_character_unlocked("ninja"),
		"1~10층을 모두 무피해로 클리어해야 닌자가 해금된다."
	)
	var no_damage_reload := StartScreenSettings.new(no_damage_path)
	no_damage_reload.load_settings()
	_expect(
		no_damage_reload.is_stage_cleared_without_damage(10)
			and no_damage_reload.is_character_unlocked("ninja"),
		"10층 무피해 기록과 닌자 해금이 재실행 후에도 유지된다."
	)
	no_damage_settings.free()
	no_damage_reload.free()

	var legacy_no_damage_path: String = "res://build/main_ui_legacy_no_damage_settings.cfg"
	var legacy_no_damage_config := ConfigFile.new()
	legacy_no_damage_config.set_value("meta", "version", 3)
	for stage_number: int in range(1, 6):
		legacy_no_damage_config.set_value(
			"progress",
			"stage_%d_no_damage" % stage_number,
			true
		)
	legacy_no_damage_config.save(legacy_no_damage_path)
	var migrated_no_damage_settings := StartScreenSettings.new(legacy_no_damage_path)
	migrated_no_damage_settings.load_settings()
	_expect(
		migrated_no_damage_settings.is_stage_cleared_without_damage(5)
			and not migrated_no_damage_settings.is_stage_cleared_without_damage(6)
			and not migrated_no_damage_settings.is_character_unlocked("ninja"),
		"구버전 5층 무피해 세이브는 새 6~10층 기록을 false로 안전하게 확장한다."
	)
	migrated_no_damage_settings.free()
	_expect(
		screen.settings.get_passive_level("attack_speed") == 0
			and screen.settings.get_passive_cost("attack_speed") == 1
			and screen.settings.get_passive_level("health") == 0
			and screen.settings.get_passive_cost("health") == 1,
		"패시브는 처음에 0레벨이고 첫 강화 비용은 별 1개다."
	)
	var attack_level_one: Dictionary = screen.settings.upgrade_passive("attack_speed")
	var attack_level_two: Dictionary = screen.settings.upgrade_passive("attack_speed")
	_expect(
		bool(attack_level_one.get("ok", false))
			and bool(attack_level_two.get("ok", false))
			and screen.settings.get_passive_level("attack_speed") == 2
			and screen.settings.star_currency == 0,
		"공속 1·2레벨은 각각 별 1·2개를 차감한다."
	)
	var attack_level_three_without_stars: Dictionary = screen.settings.upgrade_passive(
		"attack_speed"
	)
	_expect(
		not bool(attack_level_three_without_stars.get("ok", false))
			and screen.settings.get_passive_cost("attack_speed") == 3,
		"별이 부족하면 3레벨 강화를 막고 다음 비용을 별 3개로 표시한다."
	)
	var second_stage_reward: Dictionary = screen.settings.complete_stage(2, 3)
	var attack_level_three: Dictionary = screen.settings.upgrade_passive("attack_speed")
	_expect(
		bool(second_stage_reward.get("ok", false))
			and bool(attack_level_three.get("ok", false))
			and screen.settings.get_passive_level("attack_speed") == 3
			and screen.settings.star_currency == 0,
		"공속을 최대 레벨까지 올리는 총 비용은 별 6개다."
	)
	var passive_reset: Dictionary = screen.settings.reset_passive_upgrades()
	var move_upgrade: Dictionary = screen.settings.upgrade_passive("move")
	var health_upgrade: Dictionary = screen.settings.upgrade_passive("health")
	_expect(
		bool(passive_reset.get("ok", false))
			and int(passive_reset.get("refund", -1)) == 6
			and bool(move_upgrade.get("ok", false))
			and bool(health_upgrade.get("ok", false))
			and screen.settings.get_passive_level("move") == 1
			and screen.settings.get_passive_level("health") == 1
			and screen.settings.star_currency == 4,
		"패시브 초기화는 투자 별을 전액 환급하고 체력 강화도 구매할 수 있다."
	)
	var passive_reloaded: StartScreenSettings = StartScreenSettings.new(TEST_SETTINGS_PATH)
	passive_reloaded.load_settings()
	_expect(
		passive_reloaded.get_passive_level("move") == 1
			and passive_reloaded.get_passive_level("health") == 1
			and passive_reloaded.star_currency == 4,
		"패시브 레벨과 남은 별이 설정 파일에 저장된다."
	)
	passive_reloaded.free()
	_expect(
		MainCharacterData.health_life_bonus([0, 0, 0, 0, 0, 2]) == 2,
		"체력 패시브 레벨마다 캐릭터 목숨이 1개씩 증가한다."
	)
	screen.settings.record_challenge_lines(8)
	var challenge_reloaded: StartScreenSettings = StartScreenSettings.new(TEST_SETTINGS_PATH)
	challenge_reloaded.load_settings()
	_expect(
		challenge_reloaded.challenge_best_lines == 8,
		"도전 모드 최고 삭제 줄 수를 설정 파일에 저장한다."
	)
	challenge_reloaded.free()
	var back_event: InputEventKey = InputEventKey.new()
	back_event.pressed = true
	back_event.physical_keycode = KEY_X
	screen.show_tutorial()
	_expect(
		screen._handle_back_navigation(back_event)
			and screen.current_screen == BlockFighterStartScreen.Screen.MAIN,
		"게임 설명에서 X가 메인 메뉴로 돌아간다."
	)
	screen.show_options()
	_expect(
		screen._handle_back_navigation(back_event)
			and screen.current_screen == BlockFighterStartScreen.Screen.MAIN,
		"OPTION에서 X가 메인 메뉴로 돌아간다."
	)
	screen.show_volume()
	await process_frame
	_expect(
		screen.find_child("MusicSlider", true, false) != null
			and screen.find_child("SfxSlider", true, false) != null
			and screen._music_manager._active_mode == &"menu",
		"BGM과 SFX slider를 함께 표시하고 메뉴 음악을 유지한다."
	)
	screen.show_options()
	screen._show_progress_reset_prompt()
	screen._confirm_progress_reset()
	_expect(
		screen.settings.star_currency == 0
			and screen.settings.get_stage_best_stars(1) == 0
			and screen.settings.challenge_best_lines == 0
			and not screen.settings.is_character_unlocked("boxer")
			and not screen.settings.is_stage_cleared_without_damage(1)
			and screen.settings.get_passive_level("move") == 0
			and screen.settings.get_passive_level("health") == 0
			and not screen.settings.is_stage_unlocked(2),
		"진행 데이터 삭제는 스테이지 별, 도전 기록, 해금, 별 재화와 패시브를 초기화한다."
	)
	screen._hide_progress_reset_prompt()
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
	_expect(screen.current_screen == BlockFighterStartScreen.Screen.MAIN, "Enter는 시작 메뉴를 유지한다.")
	var menu_confirm_event: InputEventKey = InputEventKey.new()
	menu_confirm_event.pressed = true
	menu_confirm_event.physical_keycode = KEY_Z
	Input.action_press(&"character_jump")
	_expect(screen._handle_menu_confirm_input(menu_confirm_event), "Z가 초점 메뉴 버튼을 선택한다.")
	_expect(
		screen.current_screen == BlockFighterStartScreen.Screen.FLOOR_SELECT,
		"메인 메뉴 GAME START가 탑 선택 화면으로 바로 이동한다."
	)
	await process_frame
	var floor_group_two: Button = screen.find_child(
		"FloorGroupButton2", true, false
	) as Button
	var floor_group_one: Button = screen.find_child(
		"FloorGroupButton1", true, false
	) as Button
	_expect(
		floor_group_two != null
			and floor_group_one != null
			and floor_group_two.position.y < floor_group_one.position.y,
		"탑 선택 화면은 위에 높은 층(6-10), 아래에 낮은 층(1-5)을 세로로 배치한다."
	)
	_expect(
		floor_group_one != null
			and floor_group_two != null
			and floor_group_one.text.contains(screen._floor_group_label(0))
			and floor_group_two.text.contains(screen._floor_group_label(1)),
		"아래 버튼은 1구역(1-5층), 위 버튼은 2구역(6-10층) 라벨을 표시한다."
	)
	var character_select_button: Button = screen.find_child(
		"CharacterSelectButton", true, false
	) as Button
	var shop_button: Button = screen.find_child("ShopButton", true, false) as Button
	var challenge_button: Button = screen.find_child("ChallengeModeButton", true, false) as Button
	if floor_group_one != null:
		floor_group_one.pressed.emit()
	await process_frame
	_expect(
		screen.current_screen == BlockFighterStartScreen.Screen.STAGE_SELECT
			and screen._selected_floor_group == 0
			and screen._stage_title_labels[0].text == screen._text("1층", "1F")
			and screen._stage_title_labels[4].text
				== screen._text("5층", "5F") + screen._text("  보스", "  BOSS"),
		"1구역(1-5층) 선택이 해당 층 선택 화면을 연다."
	)
	var locked_stage_label: Label = screen._stage_labels[1]
	_expect(
		character_select_button != null
			and shop_button != null
			and challenge_button != null
			and not challenge_button.disabled
			and challenge_button.position.y < 140.0
			and locked_stage_label.text.contains("■")
			and screen._stage_panels[1].modulate.a < 1.0
			and not screen._stage_buttons[1].disabled
			and screen._stage_buttons[1].get_theme_color("font_color").a == 1.0
			and screen._stage_buttons[1].get_theme_color("font_focus_color").a == 1.0
			and screen._stage_buttons[1].focus_mode == Control.FOCUS_ALL
			and screen._stage_buttons[0].focus_mode == Control.FOCUS_ALL
			and character_select_button.position.x > shop_button.position.x
			and character_select_button.position.y >= 640.0
			and shop_button.position.y >= 640.0,
		"잠긴 스테이지는 자물쇠와 낮은 명도로 표시하고 상하단 메뉴를 유지한다."
	)
	screen._stage_buttons[1].grab_focus()
	await process_frame
	_expect(
		screen._stage_buttons[1].has_focus()
			and screen.current_screen == BlockFighterStartScreen.Screen.STAGE_SELECT,
		"잠긴 스테이지도 포커스할 수 있지만 입장 상태는 바뀌지 않는다."
	)
	if shop_button != null:
		shop_button.pressed.emit()
	var shop_cards_exist: bool = true
	for passive_id: String in StartScreenSettings.PASSIVE_IDS:
		if screen.find_child("ShopCard_%s" % passive_id, true, false) == null:
			shop_cards_exist = false
	_expect(
		screen.current_screen == BlockFighterStartScreen.Screen.SHOP
			and shop_cards_exist
			and screen.find_child("ShopDetailPanel", true, false) != null
			and screen.find_child("PassiveResetButton", true, false) != null,
		"상점에서 패시브 아이콘 카드와 하단 상세·초기화 UI를 사용할 수 있다."
	)
	await process_frame
	var shop_back_button: Button = screen.find_child("ShopBackButton", true, false) as Button
	var shop_reset_button: Button = screen.find_child("PassiveResetButton", true, false) as Button
	var bottom_buttons_have_expected_focus_links: bool = (
		shop_back_button != null and shop_reset_button != null
	)
	if bottom_buttons_have_expected_focus_links:
		bottom_buttons_have_expected_focus_links = (
			shop_reset_button.focus_neighbor_left
			== shop_reset_button.get_path_to(shop_back_button)
			and shop_back_button.focus_neighbor_right
			== shop_back_button.get_path_to(shop_reset_button)
			and shop_back_button.focus_neighbor_top
			== shop_back_button.get_path_to(screen._shop_cards[screen._shop_cards.size() - 2])
			and shop_reset_button.focus_neighbor_top
			== shop_reset_button.get_path_to(screen._shop_cards[screen._shop_cards.size() - 1])
		)
	_expect(
		bottom_buttons_have_expected_focus_links,
		"상점 하단 버튼은 좌우로 서로 이동하고 위로 각 스탯 카드로 돌아간다."
	)
	var bottom_cards_point_to_stage_select: bool = shop_back_button != null
	for card_index: int in range(screen._shop_cards.size() - 2, screen._shop_cards.size()):
		var card: Button = screen._shop_cards[card_index]
		var target_button: Button = shop_back_button if card_index == screen._shop_cards.size() - 2 else shop_reset_button
		bottom_cards_point_to_stage_select = (
			bottom_cards_point_to_stage_select
			and card.focus_neighbor_bottom == card.get_path_to(target_button)
		)
	_expect(
		bottom_cards_point_to_stage_select,
		"상점 마지막 카드 행에서 아래 방향키가 대응하는 하단 버튼으로 이동한다."
	)
	var bottom_card: Button = screen._shop_cards[screen._shop_cards.size() - 1]
	bottom_card.grab_focus()
	await process_frame
	shop_reset_button.grab_focus()
	await process_frame
	var cards_cleared_on_bottom_focus: bool = shop_reset_button.has_focus()
	for card: Button in screen._shop_cards:
		var card_style: StyleBox = card.get_theme_stylebox("normal")
		if (
			card_style is StyleBoxFlat
			and (card_style as StyleBoxFlat).bg_color == Color("#fff8e6")
		):
			cards_cleared_on_bottom_focus = false
	_expect(
		cards_cleared_on_bottom_focus,
		"하단 버튼에 초점을 옮기면 기존 스탯 카드 선택 표시가 사라진다."
	)
	screen._show_passive_reset_prompt()
	await process_frame
	screen._passive_reset_no_button.grab_focus()
	var passive_reset_up_event: InputEventKey = InputEventKey.new()
	passive_reset_up_event.pressed = true
	passive_reset_up_event.physical_keycode = KEY_UP
	var passive_reset_down_event: InputEventKey = InputEventKey.new()
	passive_reset_down_event.pressed = true
	passive_reset_down_event.physical_keycode = KEY_DOWN
	var passive_reset_left_event: InputEventKey = InputEventKey.new()
	passive_reset_left_event.pressed = true
	passive_reset_left_event.physical_keycode = KEY_LEFT
	var passive_reset_arrows_blocked: bool = (
		screen._handle_passive_reset_prompt_input(passive_reset_up_event)
		and screen._handle_passive_reset_prompt_input(passive_reset_down_event)
		and screen._passive_reset_no_button.has_focus()
	)
	_expect(
		passive_reset_arrows_blocked,
		"패시브 초기화 확인창에서는 위아래 방향키가 포커스를 이동시키지 않는다."
	)
	screen._handle_passive_reset_prompt_input(passive_reset_left_event)
	_expect(
		screen._passive_reset_yes_button.has_focus(),
		"패시브 초기화 확인창에서는 좌우 방향키로만 버튼을 전환한다."
	)
	screen._hide_passive_reset_prompt()
	await process_frame
	var attack_card: Button = screen.find_child(
		"ShopCard_attack_speed", true, false
	) as Button
	var icons_loaded: bool = screen._shop_icon_textures.size() == StartScreenSettings.PASSIVE_IDS.size()
	for icon_variant: Variant in screen._shop_icon_textures:
		icons_loaded = icons_loaded and icon_variant != null
	_expect(icons_loaded, "상점 아이콘 파일 6개가 패시브 카드에 연결된다.")
	var shop_z_event: InputEventKey = InputEventKey.new()
	shop_z_event.pressed = true
	shop_z_event.physical_keycode = KEY_Z
	if attack_card != null:
		screen.settings.star_currency = 7
		screen._refresh_shop()
		attack_card.grab_focus()
		await process_frame
		for _level: int in range(3):
			screen._handle_menu_confirm_input(shop_z_event)
			await process_frame
		_expect(
			screen.settings.get_passive_level("attack_speed") == 3
				and attack_card.has_focus(),
			"화살표로 선택한 패시브는 Z를 누르면 바로 강화된다."
		)
		screen._handle_menu_confirm_input(shop_z_event)
		await process_frame
		_expect(
			not screen._message_overlay.visible,
			"최대 레벨 패시브에 Z를 눌러도 안내 문구를 표시하지 않는다."
		)
	var health_card: Button = screen.find_child(
		"ShopCard_health", true, false
	) as Button
	if health_card != null:
		health_card.grab_focus()
		screen._handle_menu_confirm_input(shop_z_event)
		await process_frame
		_expect(
			screen.settings.get_passive_level("health") == 1,
			"체력 카드를 선택하고 Z를 누르면 목숨 강화가 구매된다."
		)
	var jump_card: Button = screen.find_child(
		"ShopCard_jump", true, false
	) as Button
	if jump_card != null:
		jump_card.pressed.emit()
		await process_frame
		_expect(
			screen._selected_shop_index == StartScreenSettings.PASSIVE_IDS.find("jump")
				and screen._shop_detail_name.text == "Jump"
				and screen._shop_detail_description.text == screen.settings.get_passive_description(2),
			"아이콘 카드를 선택하면 하단 상세 패널에 해당 패시브 정보가 표시된다."
		)
	screen.show_stage_select()
	if character_select_button != null:
		character_select_button.pressed.emit()
	_expect(
		screen.current_screen == BlockFighterStartScreen.Screen.CHARACTER,
		"캐릭터 선택 버튼이 기존 캐릭터 선택 화면을 연다."
	)
	await process_frame
	var boxer_button: Button = screen.find_child("Character_boxer", true, false) as Button
	_expect(boxer_button != null, "캐릭터 선택 화면에 복서 카드가 있다.")
	_expect(
		not screen.settings.is_character_unlocked("boxer"),
		"진행 초기화 뒤 복서는 실제 선택 잠금 상태다."
	)
	var boxer_unlock_result: Dictionary = screen.settings.complete_stage(1, 3, 3, true)
	_expect(
		bool(boxer_unlock_result.get("ok", false))
			and screen.settings.is_character_unlocked("boxer"),
		"3별 완료가 복서를 해금하고 캐릭터 화면에 즉시 반영된다."
	)
	var stat_bars: Array[ProgressBar] = []
	if boxer_button != null:
		for child: Node in boxer_button.get_children():
			if child is ProgressBar:
				stat_bars.append(child)
	_expect(
		stat_bars.size() == 5
			and stat_bars[0].value == 9.0
			and stat_bars[1].value == 7.0
			and stat_bars[2].value == 5.0
			and stat_bars[3].value == 3.0
			and stat_bars[4].value == 2.0,
		"카드마다 다섯 능력치를 막대그래프로 표시한다."
	)
	var right_event: InputEventKey = InputEventKey.new()
	right_event.pressed = true
	right_event.physical_keycode = KEY_RIGHT
	var left_event: InputEventKey = InputEventKey.new()
	left_event.pressed = true
	left_event.physical_keycode = KEY_LEFT
	if boxer_button != null:
		screen._character_buttons[0].grab_focus()
		await process_frame
		screen._input(right_event)
		await process_frame
		_expect(
			screen._selected_character_id == "boxer",
			"캐릭터 카드에서 오른쪽 방향키를 누르면 다음 카드로 바로 이동한다."
		)
		var white_labels: bool = true
		for child: Node in screen._character_buttons[1].get_children():
			if child is Label and not String(child.name).begins_with("CharacterUnlockLabel_"):
				if (child as Label).get_theme_color("font_color") != Color.WHITE:
					white_labels = false
		var dark_labels: bool = true
		for child: Node in screen._character_buttons[0].get_children():
			if child is Label and not String(child.name).begins_with("CharacterUnlockLabel_"):
				if (child as Label).get_theme_color("font_color") != Color("#152033"):
					dark_labels = false
		_expect(
			white_labels and dark_labels,
			"포커스된 카드의 글자는 흰색, 옆 카드는 어두운 색으로 표시된다."
		)
		screen._input(right_event)
		await process_frame
		_expect(
			screen._selected_character_id == "shield_guard",
			"복서에서 오른쪽 방향키를 누르면 방패병으로 바로 이동한다."
		)
		screen._input(right_event)
		await process_frame
		var firefighter_button: Button = screen.find_child(
			"Character_firefighter", true, false
		) as Button
		_expect(
			screen._selected_character_id == "firefighter"
				and firefighter_button != null
				and firefighter_button.visible
				and firefighter_button.position == Vector2(335.0, 142.0),
			"캐러셀에서 선택 캐릭터는 항상 중앙 칸에 표시된다."
		)
		screen._input(left_event)
		await process_frame
		screen._input(left_event)
		await process_frame
		screen._input(left_event)
		await process_frame
		_expect(
			screen._selected_character_id == "normal"
				and screen._character_buttons[0].position == Vector2(335.0, 142.0),
			"캐러셀에서 왼쪽 방향키를 누르면 이전 캐릭터로 이동한다."
		)
		_expect(
			screen._character_position_labels.size() == 8
				and screen._character_position_labels[7].text == screen._text("이전")
				and screen._character_position_labels[0].text == screen._text("현재")
				and screen._character_position_labels[1].text == screen._text("다음"),
			"세 칸 캐러셀의 위치 라벨이 이전/현재/다음을 표시한다."
		)
		_expect(
			screen._character_prev_button.focus_mode == Control.FOCUS_NONE
				and screen._character_next_button.focus_mode == Control.FOCUS_NONE
				and screen._character_buttons[2].focus_neighbor_right
				== screen._character_buttons[2].get_path_to(screen._character_buttons[2])
				and screen._character_buttons[2].focus_neighbor_bottom
				== screen._character_buttons[2].get_path_to(screen._character_back_button),
			"좌우 화살표는 포커스 상호작용을 받지 않고 캐릭터 카드는 BACK으로 이동한다."
		)
		screen._input(right_event)
		await process_frame
	var z_character_event: InputEventKey = InputEventKey.new()
	z_character_event.pressed = true
	z_character_event.physical_keycode = KEY_Z
	screen._input(z_character_event)
	_expect(
		screen.current_screen == BlockFighterStartScreen.Screen.STAGE_SELECT
			and screen._selected_character_id == "boxer",
		"캐릭터 카드에서 Z를 누르면 선택완료 버튼 없이 복서를 확정하고 층 선택으로 간다."
	)
	if floor_group_one != null:
		floor_group_one.pressed.emit()
	await process_frame
	var stage_button: Button = screen.find_child("StageButton1", true, false) as Button
	_expect(stage_button != null and not stage_button.disabled, "1-1 스테이지 버튼을 선택할 수 있다.")
	if stage_button != null:
		stage_button.pressed.emit()
	_expect(screen.current_screen == BlockFighterStartScreen.Screen.GAME, "스테이지 선택이 게임 장면을 연다.")
	_expect(
		screen._music_manager._active_mode == &"battle",
		"게임 화면을 열면 전투 BGM으로 전환한다."
	)
	await process_frame
	await physics_frame
	var character: MainCharacterController = screen._game_instance.get_node("BoardPhysics/Character")
	_expect(character.character_id == "boxer", "스테이지 게임이 선택한 복서로 시작한다.")
	_expect(
		screen._game_instance.get_parent() == screen._game_viewport,
		"로드된 게임의 물리 노드는 배율이 적용되지 않는 고정 SubViewport의 직접 자식이다."
	)
	_expect(
		character.lives == MainCharacterController.MAX_LIVES + 1,
		"구매한 체력 패시브가 게임 시작 목숨에 적용된다."
	)
	_expect(character.velocity.y >= 0.0, "메뉴 Z를 누른 채 시작해도 캐릭터가 점프하지 않는다.")
	Input.action_release(&"character_jump")
	var controller: MainGameController = screen._loaded_game_controller()
	_expect(controller != null, "실행 중인 게임 controller를 찾는다.")
	if controller != null:
		_expect(
			InputMap.action_get_events(&"character_self_respawn").size() == 1,
			"자력 재스폰은 기본 Q 하나를 사용한다."
		)
		var unlock_event: InputEventKey = InputEventKey.new()
		unlock_event.pressed = true
		unlock_event.physical_keycode = KEY_0
		screen._input(unlock_event)
		await process_frame
		_expect(
			screen._message_overlay.visible
				and controller.state == MainGameController.GameState.PAUSED
				and not controller.is_physics_processing(),
			"게임 중 0 해금 안내는 뒤의 게임 진행과 입력을 함께 멈춘다."
		)
		Input.action_press(&"character_jump")
		screen._hide_message()
		_expect(
			controller.state == MainGameController.GameState.PLAYING
				and controller.is_physics_processing()
				and character._ignore_initial_jump_until_released,
			"해금 안내를 닫은 Z 입력은 게임 재개 직후 점프로 전달되지 않는다."
		)
		Input.action_release(&"character_jump")
		var keypad_unlock_event: InputEventKey = InputEventKey.new()
		keypad_unlock_event.pressed = true
		keypad_unlock_event.physical_keycode = KEY_KP_0
		_expect(
			screen._handle_debug_unlock_all_characters_input(keypad_unlock_event)
				and screen._message_overlay.visible,
			"키패드 0도 전체 캐릭터 해금 입력으로 처리한다."
		)
		screen._hide_message()
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
		_expect(overlay.visible, "Esc로 메뉴 복귀 확인창을 다시 연다.")
		screen._handle_game_exit_prompt_input(escape_event)
		_expect(
			not overlay.visible
				and controller.is_physics_processing()
				and controller.state == MainGameController.GameState.PLAYING,
			"확인창에서 Esc를 다시 누르면 취소한다."
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
			screen.current_screen == BlockFighterStartScreen.Screen.MAIN
				and screen._game_instance == null
				and screen.find_child("LoadedGame", true, false) == null
				and screen._music_manager._active_mode == &"menu",
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
		screen.current_screen == BlockFighterStartScreen.Screen.GAME
			and screen._game_instance != null,
		"Enter를 놓거나 반복 입력한 것은 디버그 완료를 실행하지 않는다."
	)
	screen._input(debug_enter_event)
	var result_overlay: Control = screen.find_child("StageResultOverlay", true, false) as Control
	_expect(
		OS.is_debug_build()
			and screen.current_screen == BlockFighterStartScreen.Screen.STAGE_SELECT
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
			and screen.current_screen == BlockFighterStartScreen.Screen.STAGE_SELECT,
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
	var boss_timer_label: Label = screen.find_child("TimerLabel", true, false) as Label
	_expect(
		boss_controller != null
			and boss_controller.is_boss_stage()
			and boss_controller.boss_health == MainGameController.BOSS_MAX_HEALTH
			and boss_timer_label != null
			and boss_timer_label.visible
			and boss_timer_label.text == "05:00",
		"Stage 5 Enter 테스트에서 보스 체력 3으로 게임을 시작한다."
	)
	screen._input(debug_enter_event)
	_expect(
		boss_controller != null
			and boss_controller.boss_health == 0
			and boss_controller.state == MainGameController.GameState.BOSS_FALLING
			and screen.current_screen == BlockFighterStartScreen.Screen.GAME
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
		screen.current_screen == BlockFighterStartScreen.Screen.STAGE_SELECT
			and screen._game_instance == null
			and result_overlay != null
			and result_overlay.visible
			and screen.settings.get_stage_best_stars(5) == 3,
		"Stage 5 보스가 쓰러지면 3별 결과 화면으로 전환한다."
	)
	if result_button != null:
		result_button.pressed.emit()
	_expect(
		challenge_button != null
			and not screen.settings.is_challenge_unlocked()
			and screen.settings.is_stage_unlocked(6),
		"5층을 클리어하면 6층이 해금되지만 도전 모드는 아직 잠겨 있다."
	)
	for stage_number: int in range(6, 10):
		var floor_unlock_result: Dictionary = screen.settings.complete_stage(stage_number, 3)
		_expect(
			bool(floor_unlock_result.get("ok", false)),
			"Floor %d 디버그 테스트를 위해 이전 층을 해금한다." % stage_number
		)
	screen.start_game(10)
	await process_frame
	boss_controller = screen._loaded_game_controller()
	boss_timer_label = screen.find_child("TimerLabel", true, false) as Label
	_expect(
		boss_controller != null
			and boss_controller.is_boss_stage()
			and boss_controller.boss_health == MainGameController.BOSS_MAX_HEALTH
			and boss_timer_label != null
			and boss_timer_label.visible
			and boss_timer_label.text == "05:00",
		"Floor 10 테스트에서 보스 체력 3으로 게임을 시작한다."
	)
	screen._input(debug_enter_event)
	_expect(
		boss_controller != null
			and boss_controller.boss_health == 0
			and boss_controller.state == MainGameController.GameState.BOSS_DYING
			and not boss_controller.is_boss_down()
			and not boss_controller.is_boss_falling()
			and not boss_controller.is_boss_fallen()
			and screen.current_screen == BlockFighterStartScreen.Screen.GAME
			and screen._game_instance != null,
		"Floor 10의 Enter는 down/fall/fallen 없이 즉시 die 애니메이션을 시작한다."
	)
	if boss_controller != null:
		boss_controller._advance_boss_dying(
			MainGameController.BOSS_DYING_DURATION_SECONDS
		)
		_expect(
			boss_controller.state == MainGameController.GameState.BOSS_DYING
				and screen._game_instance != null,
			"Floor 10 die 애니메이션 직후 0.5초 동안 게임 화면을 유지한다."
		)
		boss_controller._advance_boss_dying(MainGameController.BOSS_CLEAR_DELAY_SECONDS)
	await process_frame
	_expect(
		screen.current_screen == BlockFighterStartScreen.Screen.STAGE_SELECT
			and screen._game_instance == null
			and result_overlay != null
			and result_overlay.visible
			and screen.settings.get_stage_best_stars(10) == 3,
		"Floor 10 보스가 쓰러지면 3별 결과 화면으로 전환한다."
	)
	if result_button != null:
		result_button.pressed.emit()
	_expect(
		challenge_button != null
			and not challenge_button.disabled
			and screen.settings.is_challenge_unlocked(),
		"10층을 클리어하면 스테이지 선택 상단의 도전 모드가 해금된다."
	)
	var stars_before_challenge: int = screen.settings.star_currency
	if challenge_button != null:
		challenge_button.pressed.emit()
	await process_frame
	var challenge_controller: MainGameController = screen._loaded_game_controller()
	var challenge_character: MainCharacterController
	if screen._game_instance != null:
		challenge_character = screen._game_instance.get_node_or_null(
			"BoardPhysics/Character"
		) as MainCharacterController
	var challenge_timer_label: Label = screen.find_child("TimerLabel", true, false) as Label
	_expect(
		challenge_controller != null
			and challenge_controller.is_challenge_mode()
			and challenge_controller.state == MainGameController.GameState.PLAYING
			and challenge_timer_label != null
			and not challenge_timer_label.visible
			and challenge_character != null
			and challenge_character.character_id == screen._selected_character_id
			and challenge_character.lives == challenge_character.get_max_lives(),
		"도전 모드는 선택 캐릭터·패시브 목숨을 적용하고 타이머 없이 시작한다."
	)
	if challenge_controller != null:
		challenge_controller.total_lines = 12
		challenge_controller.end_game()
	await process_frame
	_expect(
		screen.settings.challenge_best_lines == 12
			and screen.settings.star_currency == stars_before_challenge,
		"도전 모드 게임오버는 최고 줄만 기록하고 별 재화는 지급하지 않는다."
	)
	screen._dispose_game_instance()
	screen.show_stage_select()
	await process_frame
	_expect(
		challenge_button != null and challenge_button.text.contains("12"),
		"도전 모드 버튼에 저장된 최고 삭제 줄 수를 표시한다."
	)

	screen.show_floor_select()
	await process_frame
	if floor_group_two != null:
		floor_group_two.pressed.emit()
	await process_frame
	_expect(
		screen.current_screen == BlockFighterStartScreen.Screen.STAGE_SELECT
			and screen._selected_floor_group == 1
			and screen._stage_title_labels[0].text == screen._text("6층", "6F")
			and screen._stage_title_labels[4].text
				== screen._text("10층", "10F") + screen._text("  보스", "  BOSS")
			and screen.settings.is_stage_unlocked(6),
		"2구역을 선택하면 6~10층 카드가 표시되고 6층은 해금 상태다."
	)
	screen.show_floor_select()
	await process_frame
	if floor_group_one != null:
		floor_group_one.pressed.emit()
	await process_frame
	_expect(
		screen.current_screen == BlockFighterStartScreen.Screen.STAGE_SELECT
			and screen._selected_floor_group == 0
			and screen._stage_title_labels[0].text == screen._text("1층", "1F")
			and screen._stage_title_labels[4].text
				== screen._text("5층", "5F") + screen._text("  보스", "  BOSS"),
		"1구역을 다시 선택하면 1~5층 카드로 돌아온다."
	)

	screen.start_game(5)
	await process_frame
	var fail_controller: MainGameController = screen._loaded_game_controller()
	var stars_before_fail: int = screen.settings.star_currency
	var failed_state: int = -1
	if fail_controller != null:
		fail_controller.stage_time_remaining = 0.01
		fail_controller._advance_stage_timer(0.01)
		failed_state = fail_controller.state
	await process_frame
	var fail_overlay: Control = screen.find_child("StageFailOverlay", true, false) as Control
	var fail_retry_button: Button = screen.find_child("StageFailRetryButton", true, false) as Button
	_expect(
		failed_state == MainGameController.GameState.GAME_OVER
			and screen.current_screen == BlockFighterStartScreen.Screen.STAGE_SELECT
			and screen._game_instance == null
			and fail_overlay != null
			and fail_overlay.visible
			and screen.settings.star_currency == stars_before_fail,
		"스테이지 제한시간 초과가 실패 UI를 표시하고 별·해금을 지급하지 않는다."
	)
	if fail_retry_button != null:
		fail_retry_button.pressed.emit()
	await process_frame
	var retry_controller: MainGameController = screen._loaded_game_controller()
	_expect(
		screen.current_screen == BlockFighterStartScreen.Screen.GAME
			and screen._game_instance != null
			and retry_controller != null
			and retry_controller.boss_health == MainGameController.BOSS_MAX_HEALTH,
		"실패 UI의 재시도가 같은 스테이지를 새 게임으로 시작한다."
	)
	if screen._game_instance != null and is_instance_valid(screen._game_instance):
		screen._game_instance.queue_free()
	screen._game_instance = null
	await process_frame

	screen._select_sfx_player.stop()
	screen._select_sfx_player.stream = null
	screen.free()
	await process_frame
	var settings_path: String = ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(settings_path)
	var corrupt_settings_path: String = ProjectSettings.globalize_path(corrupt_path)
	if FileAccess.file_exists(corrupt_settings_path):
		DirAccess.remove_absolute(corrupt_settings_path)
	for generated_path: String in [no_damage_path, legacy_no_damage_path]:
		var absolute_generated_path: String = ProjectSettings.globalize_path(generated_path)
		if FileAccess.file_exists(absolute_generated_path):
			DirAccess.remove_absolute(absolute_generated_path)
	await create_timer(0.25).timeout
	if _failures == 0:
		print("성공: 메인 UI 테스트 %d개 통과" % _checks)
		print("TEST_RESULT suite=main_ui checks=%d failures=0" % _checks)
	else:
		push_error("실패: 시작 화면 통합 테스트 %d/%d개 실패" % [_failures, _checks])
		print("TEST_RESULT suite=main_ui checks=%d failures=%d" % [_checks, _failures])
	quit(_failures)


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  [통과] %s" % description)
	else:
		_failures += 1
		push_error("  [실패] %s" % description)
