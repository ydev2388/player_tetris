extends SceneTree

## [역할 / C++ 대응]
## headless Godot에서 입력 정의와 메인 게임의 핵심 계약을 검증하는 통합 test runner다.
## C++로 보면 `main()`을 가진 작은 테스트 실행 파일과 assertion helper의 조합에 가깝다.
## SceneTree를 상속해 frame/physics frame을 기다리고 실제 scene 수명을 직접 관리한다.

const INPUT_ACTIONS: Script = preload("res://scripts/input_actions.gd") # static 입력 API 의존성.
const GAME_CONTROLLER: Script = preload("res://scripts/game_controller.gd") # 단독 controller 생성용 class resource.
const ANIMATION_DATA: Script = preload("res://scripts/character_animation_data.gd")
const CHARACTER_DATA: Script = preload("res://scripts/character_data.gd")
const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn") # 펀치 통합 테스트용 object graph factory.
const CLOCK_WAVE_VFX: Texture2D = preload("res://assets/sprites/effects/clockmaker/clock_wave.png")
const CLOCK_GEAR_VFX: Texture2D = preload("res://assets/sprites/effects/clockmaker/clock_gear_ring.png")
const SHURIKEN_SPIN_VFX: Texture2D = preload("res://assets/sprites/effects/ninja/shuriken_spin.png")
const SHURIKEN_IMPACT_VFX: Texture2D = preload("res://assets/sprites/effects/ninja/shuriken_impact.png")
const BOSS_SEED_TEXTURE: Texture2D = preload("res://assets/sprites/boss/1_5_boss/seed_sprite.png")
const HANG_WALL_VISUAL_TOLERANCE: float = 2.0

var _checks: int = 0 # 수행한 assertion 총수.
var _failures: int = 0 # false였던 assertion 수이자 process exit code.
var _stage_cleared_captured: bool = false # stage_cleared 발생 감지용. lambda는 지역 변수를 값 캡처하므로 멤버를 쓴다.
var _stage_failed_captured: bool = false # stage_failed 발생 감지용.


func _on_stage_cleared_captured(_cleared_lines: int) -> void:
	_stage_cleared_captured = true


func _on_stage_failed_captured() -> void:
	_stage_failed_captured = true


## 상황: SceneTree test runner가 생성될 때 자동 호출된다.
## 결과: 엔진 초기화가 끝난 뒤 async 테스트를 시작하도록 `_run`을 deferred 예약한다.
func _init() -> void:
	call_deferred("_run")


## 상황: test runner의 단일 진입점으로 입력·수식·scene 통합 계약을 순서대로 검증한다.
## 순서: 사용자 키 보존 → 기본 정의/수식 → controller loop → tutorial/SFX
##       → spawn 좌우 여백/벽 옆 fallback → release punch.
## 결과: 임시 입력 객체를 정리하고 실패 수를 프로세스 종료 코드로 반환한다.
func _run() -> void:
	INPUT_ACTIONS.ensure_defaults()
	InputMap.action_erase_events(&"character_punch")
	var custom_event: InputEventKey = InputEventKey.new() # 기본값 보장이 사용자 event를 덮지 않는지 볼 fixture.
	custom_event.physical_keycode = KEY_F8
	InputMap.action_add_event(&"character_punch", custom_event)
	INPUT_ACTIONS.ensure_defaults()
	var custom_events: Array[InputEvent] = InputMap.action_get_events(&"character_punch") # 적용 후 snapshot.
	_expect(
		custom_events.size() == 1
			and custom_events[0] is InputEventKey
			and (custom_events[0] as InputEventKey).physical_keycode == KEY_F8,
		"사용자 키가 기본값으로 오염되지 않는다."
	)
	_expect(
		INPUT_ACTIONS.get_default_keys(&"character_rotation_kick") == [KEY_S],
		"블록 플립 기본 키는 S다."
	)
	_expect(
		INPUT_ACTIONS.get_default_keys(&"pause_game") == [KEY_P],
		"일시정지는 P 하나만 사용한다."
	)
	_expect(
		INPUT_ACTIONS.get_definition(&"character_pull").is_empty(),
		"최종 입력 목록에 당기기 동작은 없다."
	)
	_expect(
		INPUT_ACTIONS.get_default_keys(&"character_special") == [KEY_V],
		"특수 스킬 기본 키는 V다."
	)
	var controller: MainGameController = GAME_CONTROLLER.new() # scene 없이 process API만 검사할 임시 객체.
	controller.reset_game(20260801)
	var boss_board_rect: Rect2 = Rect2(MainLayout.BOARD_ORIGIN, MainLayout.BOARD_SIZE)
	var boss_alive_rect: Rect2 = Rect2(
		MainLayout.BOARD_PHYSICS_ORIGIN
			+ MainGameController.BOSS_POSITION
			- MainGameController.BOSS_DISPLAY_SIZE * 0.5,
		MainGameController.BOSS_DISPLAY_SIZE
	)
	var boss_down_rect: Rect2 = Rect2(
		MainLayout.BOARD_PHYSICS_ORIGIN
			+ MainGameController.BOSS_POSITION
			- MainGameController.BOSS_DOWN_DISPLAY_SIZE * 0.5,
		MainGameController.BOSS_DOWN_DISPLAY_SIZE
	)
	var falling_entry_center: Vector2 = (
		MainLayout.BOARD_PHYSICS_ORIGIN
		+ MainGameController.BOSS_POSITION
		+ Vector2(
			0.0,
			MainGameController.BOSS_DOWN_DISPLAY_SIZE.y * 0.5
				- MainGameController.BOSS_DISPLAY_SIZE.y * 0.5
		)
	)
	var boss_falling_entry_rect: Rect2 = Rect2(
		falling_entry_center - MainGameController.BOSS_DISPLAY_SIZE * 0.5,
		MainGameController.BOSS_DISPLAY_SIZE
	)
	var boss_attack_rect: Rect2 = Rect2(
		MainLayout.BOARD_PHYSICS_ORIGIN
			+ MainGameController.BOSS_POSITION
			+ MainGameController.BOSS_ATTACK_HITBOX_OFFSET
			- MainGameController.BOSS_ATTACK_HITBOX_SIZE * 0.5,
		MainGameController.BOSS_ATTACK_HITBOX_SIZE
	)
	_expect(
		boss_board_rect.encloses(boss_alive_rect)
			and boss_board_rect.encloses(boss_down_rect)
			and boss_board_rect.encloses(boss_falling_entry_rect)
			and boss_board_rect.encloses(boss_attack_rect)
			and not MainGameView.HUD_RECT.intersects(boss_alive_rect)
			and not MainGameView.HUD_RECT.intersects(boss_down_rect)
			and not MainGameView.HUD_RECT.intersects(boss_falling_entry_rect),
		"보스의 일반·속박·가시·다운·낙하 시작 프레임과 공격 판정은 상단 HUD를 침범하지 않는다."
	)
	controller.board.reset()
	var spawn_cells_valid: bool = true
	for piece_type: int in range(MainTetrominoData.TYPE_COUNT):
		var cells: Array[Vector2i] = MainTetrominoData.get_cells(piece_type, 0)
		var minimum_x: int = cells[0].x
		var maximum_x: int = cells[0].x
		for cell: Vector2i in cells:
			minimum_x = mini(minimum_x, cell.x)
			maximum_x = maxi(maximum_x, cell.x)
		var candidates: Array[Vector2i] = controller._valid_spawn_origins(piece_type)
		var expected_count: int = MainBoardModel.WIDTH - 2 - (maximum_x - minimum_x)
		spawn_cells_valid = spawn_cells_valid and candidates.size() == expected_count
		for origin: Vector2i in candidates:
			for cell: Vector2i in cells:
				var board_cell: Vector2i = origin + cell
				spawn_cells_valid = (
					spawn_cells_valid
					and board_cell.x >= 1
					and board_cell.x <= MainBoardModel.WIDTH - 2
				)
	_expect(
		spawn_cells_valid,
		"모든 테트로미노 spawn 후보는 양쪽 경계 열을 비운다."
	)
	_expect(
		controller.has_method("_physics_process")
			and not controller.has_method("_process"),
		"게임 진행은 현재 physics process 경로를 사용한다."
	)
	controller.free()
	_expect(
		StartScreenTutorialCanvas.PAGE_DURATIONS.size() == 5,
		"메인 애니메이션 튜토리얼은 5페이지다."
	)
	_expect(
		FileAccess.file_exists("res://assets/sfx/08_select.wav"),
		"현재 선택 효과음 리소스를 유지한다."
	)
	_expect(
		ANIMATION_DATA.has_character("normal")
			and ANIMATION_DATA.display_name_for("normal") == "일반인",
		"일반인 animation profile이 기본 캐릭터로 등록된다."
	)
	var normal_atlas: Texture2D = ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, "normal")
	_expect(
		normal_atlas.get_width() == 1024
			and normal_atlas.get_height() == 768
			and normal_atlas.resource_path.ends_with("normal_reference_atlas_v8.png")
			and ANIMATION_DATA.uses_fixed_geometry("normal")
		and ANIMATION_DATA.fixed_scale_for("normal").is_equal_approx(Vector2.ONE)
			and ANIMATION_DATA.fixed_offset_for("normal").is_equal_approx(Vector2(0.0, 3.0)),
		"일반인 atlas는 1024×768 균일 격자다."
	)
	var scene_atlas_check: MainGameView = GAME_SCENE.instantiate()
	var scene_normal_atlas: Texture2D = (
		scene_atlas_check.get_node("BoardPhysics/Character/Sprite") as Sprite2D
	).texture
	_expect(
		scene_normal_atlas.resource_path.ends_with("normal_reference_atlas_v8.png"),
		"게임 씬의 초기 일반인 Sprite도 runtime v8 atlas를 사용한다."
	)
	scene_atlas_check.free()
	var boxer_atlas: Texture2D = ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, "boxer")
	_expect(
		ANIMATION_DATA.has_character("boxer")
			and ANIMATION_DATA.display_name_for("boxer") == "복서"
			and boxer_atlas.get_width() == 1024
			and boxer_atlas.get_height() == 768
			and boxer_atlas != normal_atlas,
		"복서 profile은 독립된 1024×768 atlas를 사용한다."
	)
	var shield_guard_atlas: Texture2D = ANIMATION_DATA.texture_for(
		ANIMATION_DATA.IDLE,
		"shield_guard"
	)
	_expect(
		ANIMATION_DATA.has_character("shield_guard")
			and ANIMATION_DATA.display_name_for("shield_guard") == "방패병"
			and shield_guard_atlas.get_width() == 1024
			and shield_guard_atlas.get_height() == 768
			and shield_guard_atlas != normal_atlas
			and shield_guard_atlas != boxer_atlas,
		"방패병 profile은 독립된 1024×768 atlas를 사용한다."
	)
	var firefighter_atlas: Texture2D = ANIMATION_DATA.texture_for(
		ANIMATION_DATA.IDLE,
		"firefighter"
	)
	_expect(
		ANIMATION_DATA.has_character("firefighter")
			and ANIMATION_DATA.display_name_for("firefighter") == "소방관"
			and firefighter_atlas.get_width() == 1024
			and firefighter_atlas.get_height() == 768
			and firefighter_atlas != normal_atlas
			and firefighter_atlas != boxer_atlas
			and firefighter_atlas != shield_guard_atlas,
		"소방관 profile은 독립된 1024×768 atlas를 사용한다."
	)
	var cleaner_atlas: Texture2D = ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, "cleaner")
	_expect(
		ANIMATION_DATA.has_character("cleaner")
			and ANIMATION_DATA.display_name_for("cleaner") == "청소부"
			and cleaner_atlas.get_width() == 1024
			and cleaner_atlas.get_height() == 768
			and cleaner_atlas != normal_atlas
			and cleaner_atlas != boxer_atlas
			and cleaner_atlas != shield_guard_atlas
			and cleaner_atlas != firefighter_atlas,
		"청소부 profile은 독립된 1024×768 atlas를 사용한다."
	)
	var chef_atlas: Texture2D = ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, "chef")
	_expect(
		ANIMATION_DATA.has_character("chef")
			and ANIMATION_DATA.display_name_for("chef") == "성녀"
			and chef_atlas.get_width() == 1024
			and chef_atlas.get_height() == 768
			and chef_atlas != normal_atlas
			and chef_atlas != boxer_atlas
			and chef_atlas != shield_guard_atlas
			and chef_atlas != firefighter_atlas
			and chef_atlas != cleaner_atlas,
		"Saintess profile은 독립된 1024×768 atlas를 사용한다."
	)
	for beta_id: String in CHARACTER_DATA.CHARACTER_ORDER:
		var beta_atlas: Texture2D = ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, beta_id)
		var expected_atlas_suffix: String = (
			"normal_reference_atlas_v8.png"
			if beta_id == "normal"
			else (
				"saintess_reference_atlas_v2.png"
				if beta_id == "chef"
				else "%s_reference_atlas_v6.png" % beta_id
			)
		)
		_expect(
			ANIMATION_DATA.has_character(beta_id)
				and CHARACTER_DATA.has_character(beta_id)
				and beta_atlas.get_width() == 1024
				and beta_atlas.get_height() == 768
				and beta_atlas.resource_path.ends_with(expected_atlas_suffix)
				and ANIMATION_DATA.uses_fixed_geometry(beta_id)
				and ANIMATION_DATA.fixed_scale_for(beta_id).is_equal_approx(Vector2.ONE)
				and ANIMATION_DATA.fixed_offset_for(beta_id).is_equal_approx(Vector2(0.0, 3.0)),
			"%s 선택 캐릭터는 데이터와 1024×768 atlas를 함께 가진다." % beta_id
		)
	_expect(
		is_equal_approx(CHARACTER_DATA.jump_cells("normal"), 2.3333333)
			and is_equal_approx(CHARACTER_DATA.jump_cells("chef"), 1.6666667)
			and is_equal_approx(CHARACTER_DATA.jump_cells("ninja"), 3.0)
			and is_equal_approx(CHARACTER_DATA.rotation_cooldown("boxer"), 1.2)
			and is_equal_approx(CHARACTER_DATA.rotation_cooldown("ninja"), 1.3)
			and is_equal_approx(CHARACTER_DATA.special_cooldown("chef"), 7.92)
			and is_equal_approx(CHARACTER_DATA.special_cooldown("clockmaker"), 9.84)
			and is_equal_approx(CHARACTER_DATA.special_cooldown("ninja"), 5.0)
			and is_equal_approx(CHARACTER_DATA.attack_cooldown("boxer"), 0.4)
			and not CHARACTER_DATA.profile_for("normal").has("special_cost"),
		"점프·공속·특수스킬 능력치가 지정된 칸 수와 쿨다운으로 변환된다."
	)
	_expect(
		ANIMATION_DATA.REGIONS[ANIMATION_DATA.IDLE].size() == 4
			and ANIMATION_DATA.REGIONS[ANIMATION_DATA.ATTACK].size() == 4
			and ANIMATION_DATA.frame_count_for(ANIMATION_DATA.HANG, "normal") == 8
			and ANIMATION_DATA.frame_count_for(ANIMATION_DATA.HANG, "boxer") == 4
			and ANIMATION_DATA.REGIONS[ANIMATION_DATA.JUMP].size() == 8
			and ANIMATION_DATA.REGIONS[ANIMATION_DATA.ROTATION_KICK].size() == 8
			and ANIMATION_DATA.REGIONS[ANIMATION_DATA.SPECIAL].size() == 8,
		"일반인은 매달림 8 frame, 기존 7명은 매달림 4 frame 계약을 지킨다."
	)
	_expect(
		CLOCK_WAVE_VFX.get_width() == 1152
			and CLOCK_WAVE_VFX.get_height() == 192
			and CLOCK_GEAR_VFX.get_width() == 512
			and CLOCK_GEAR_VFX.get_height() == 128
			and SHURIKEN_SPIN_VFX.get_width() == 128
			and SHURIKEN_SPIN_VFX.get_height() == 32
			and SHURIKEN_IMPACT_VFX.get_width() == 256
			and SHURIKEN_IMPACT_VFX.get_height() == 128,
		"시계공·닌자 VFX 시트가 지정된 frame 크기와 행 구성을 지킨다."
	)
	_test_board_coordinate_alignment()
	_test_stage_rule_contracts()
	_test_spawn_side_margin()
	await _test_restart_state_invariance()
	await _test_runtime_cleanup()
	await _test_boss_seeds()
	await _test_release_punch()
	await _test_beta_specials()
	await _test_fixed_support_grab()
	await _test_standing_wall_visual_alignment()
	await _test_hang_face_bounds()
	InputMap.action_erase_events(&"character_punch")
	custom_events.clear()
	custom_event = null
	await process_frame
	await create_timer(0.25).timeout
	if _failures == 0:
		print("성공: 메인 게임 테스트 %d개 통과" % _checks)
	else:
		push_error("실패: 최종 방향 통합 테스트 %d/%d개 실패" % [_failures, _checks])
	quit(_failures)


## 상황: 새 피스가 벽에서 한 칸 떨어져 spawn하되 중앙이 막히면 벽 옆으로 fallback하는지 검사한다.
## 순서: 7종 빈 보드 후보 수/실제 셀 여백 검사 → 선택 함수의 안전 후보 우선 검사
##       → I 피스 중앙 차단 fallback → 전체 차단 GAME_OVER 검사.
## 결과: 스폰 여백의 정상 경로와 예외 경로가 모두 설계 계약을 지키는지 assertion으로 기록한다.
func _test_board_coordinate_alignment() -> void:
	var scene: Node = GAME_SCENE.instantiate()
	var board_physics: Node2D = scene.get_node("BoardPhysics") as Node2D
	_expect(
		board_physics.position.is_equal_approx(MainLayout.BOARD_PHYSICS_ORIGIN)
			and (
				MainLayout.BOARD_PHYSICS_ORIGIN + MainLayout.BOARD_VISUAL_OFFSET
			).is_equal_approx(MainLayout.BOARD_ORIGIN),
		"물리 보드 원점과 시각 보드 원점은 명시적인 오프셋으로 정렬된다."
	)
	scene.free()


func _test_stage_rule_contracts() -> void:
	var controller: MainGameController = GAME_CONTROLLER.new()
	var expected_probabilities: Array[float] = [0.0, 0.15, 0.25, 0.25, 0.33]
	var stage_data_is_complete: bool = true
	for stage_number: int in range(1, 6):
		controller.stage_number = stage_number
		var config: Dictionary = controller.get_stage_gimmick_config()
		stage_data_is_complete = stage_data_is_complete and is_equal_approx(
			float(config.get("thorn_probability", -1.0)),
			expected_probabilities[stage_number - 1]
		)
		stage_data_is_complete = stage_data_is_complete and is_equal_approx(
			controller.stage_time_limit(),
			300.0 if stage_number == 5 else 90.0
		)
	_expect(stage_data_is_complete, "1-1~1-5의 제한시간과 가시 확률을 스테이지 데이터로 관리한다.")
	_expect(
		MainGameController.stage_stars_for_lines(0) == 1
			and MainGameController.stage_stars_for_lines(1) == 1
			and MainGameController.stage_stars_for_lines(2) == 2
			and MainGameController.stage_stars_for_lines(3) == 3,
		"생존 스테이지는 0~1/2/3줄 이상을 각각 1/2/3별로 계산한다."
	)
	_expect(
		MainGameController.line_clear_score(1, 2) == 200
			and MainGameController.line_clear_score(2, 2) == 600
			and MainGameController.line_clear_score(3, 2) == 1100
			and MainGameController.line_clear_score(4, 2) == 1800
			and MainGameController.level_for_lines(9) == 1
			and MainGameController.level_for_lines(10) == 2,
		"줄 점수와 누적 10줄 레벨 증가 공식을 유지한다."
	)
	_expect(
		MainGameController.BOSS_ATTACK_HITBOX_SIZE == Vector2(54.0, 132.0)
			and MainGameController.BOSS_ATTACK_HITBOX_OFFSET == Vector2(0.0, -16.0),
		"보스 공격 판정은 54×132px이며 표시 중심보다 16px 위에 있다."
	)
	controller.stage_cleared.connect(_on_stage_cleared_captured)
	controller.stage_failed.connect(_on_stage_failed_captured)
	for stage_number: int in range(1, 5):
		controller.stage_number = stage_number
		controller.reset_game(7)
		_stage_cleared_captured = false
		_stage_failed_captured = false
		controller.total_lines = 0
		controller.stage_time_remaining = 0.01
		controller._advance_stage_timer(0.01)
		_expect(
			controller.state == MainGameController.GameState.GAME_OVER
				and _stage_failed_captured
				and not _stage_cleared_captured,
			"1-%d는 0줄로 제한시간이 끝나면 클리어하지 않고 실패한다." % stage_number
		)
		controller.reset_game(7)
		_stage_cleared_captured = false
		_stage_failed_captured = false
		controller.total_lines = 1
		controller.stage_time_remaining = 0.01
		controller._advance_stage_timer(0.01)
		_expect(
			controller.state == MainGameController.GameState.PAUSED
				and _stage_cleared_captured
				and not _stage_failed_captured,
			"1-%d는 1줄 이상 파괴하면 제한시간 종료 시 클리어한다." % stage_number
		)
	controller.stage_number = 5
	controller.reset_game(7)
	_stage_failed_captured = false
	controller.stage_time_remaining = 0.01
	controller._advance_stage_timer(0.01)
	_expect(
		controller.state == MainGameController.GameState.GAME_OVER
			and _stage_failed_captured,
		"1-5는 300초 경계에서 보스가 살아 있으면 실패한다."
	)
	controller.reset_game(7)
	controller.boss_health = 0
	controller.stage_time_remaining = 0.01
	controller._advance_stage_timer(0.01)
	_expect(
		controller.state == MainGameController.GameState.PLAYING,
		"보스 HP 0과 제한시간 0이 겹치면 제한시간 실패를 적용하지 않는다."
	)
	controller.challenge_mode = true
	controller.stage_number = 4
	controller.reset_game(7)
	var challenge_started_without_gimmick: bool = (
		not controller.active_piece_has_thorns and not controller.thorn_visible
	)
	controller.active_piece_has_thorns = true
	controller.thorn_visible = false
	controller.thorn_phase_timer = 0.0
	controller.stage_time_remaining = 0.0
	controller._advance_stage_gimmicks(999.0)
	controller._advance_stage_timer(999.0)
	_expect(
		controller.is_challenge_mode()
			and not controller.is_survival_stage()
			and not controller.is_boss_stage()
			and challenge_started_without_gimmick
			and controller.state == MainGameController.GameState.PLAYING
			and not controller.thorn_visible,
		"도전 모드는 시간 제한·스테이지 기믹·보스 없이 계속 진행한다."
	)
	controller.challenge_mode = false

	controller.binding_probability = MainGameController.BINDING_PROBABILITY
	controller._gimmick_roll_overrides = [false, false, true]
	controller._attempt_binding_roll()
	controller._attempt_binding_roll()
	var accumulated_probability: float = controller.binding_probability
	controller._attempt_binding_roll()
	_expect(
		is_equal_approx(accumulated_probability, 0.25)
			and is_equal_approx(
				controller.binding_probability,
				MainGameController.BINDING_PROBABILITY
			),
		"속박 확률은 실패마다 5%p 증가하고 성공 시 15%로 초기화한다."
	)
	controller.free()


## 상황: PAUSED/GAME_OVER/BOSS_FALLING 어느 상태에서 R 재시작을 누를 때의 상태 불변성을 검사한다.
## 순서: 상태별로 점수·레벨·timer·기믹·보스·blocker·물길·freeze를 오염시킨 뒤
##       Input.action_press로 R을 누르고 physics frame을 기다려 실제 입력 경로로 reset_game을 호출한다.
## 결과: 어떤 상태에서 재시작해도 score/level/줄/timer/기믹/보스/blocker/물길/freeze가 초기값이 된다.
func _test_restart_state_invariance() -> void:
	var restart_controller: MainGameController = GAME_CONTROLLER.new()
	restart_controller.stage_number = 4
	for restart_state: int in [
		MainGameController.GameState.PAUSED,
		MainGameController.GameState.GAME_OVER,
		MainGameController.GameState.BOSS_FALLING,
	]:
		restart_controller.reset_game(20260812)
		restart_controller.score = 500
		restart_controller.total_lines = 12
		restart_controller.level = 2
		restart_controller.stage_time_remaining = 3.0
		restart_controller.transient_blocker_cells = [Vector2i(3, 5)]
		restart_controller.water_path_cells = [Vector2i(4, 6)]
		restart_controller.water_path_direction = -1
		restart_controller.fall_freeze_remaining = 1.5
		restart_controller.future_gimmick_freeze_remaining = 1.5
		restart_controller.boss_health = 1
		restart_controller.boss_down = true
		restart_controller.boss_seeds = [{"position": Vector2.ZERO}]
		restart_controller._fall_accumulator = 0.2
		restart_controller._lock_accumulator = 0.3
		restart_controller._lock_resets = 4
		restart_controller.state = restart_state
		Input.action_press(&"restart_game")
		await physics_frame
		restart_controller._physics_process(0.016)
		Input.action_release(&"restart_game")
		_expect(
			restart_controller.score == 0
				and restart_controller.total_lines == 0
				and restart_controller.level == 1
				and is_equal_approx(
					restart_controller.stage_time_remaining,
					restart_controller.stage_time_limit()
				)
				and restart_controller.transient_blocker_cells.is_empty()
				and restart_controller.water_path_cells.is_empty()
				and restart_controller.water_path_direction == 0
				and restart_controller.fall_freeze_remaining == 0.0
				and restart_controller.future_gimmick_freeze_remaining == 0.0
				and restart_controller.boss_health == 0
				and not restart_controller.boss_down
				and restart_controller.boss_seeds.is_empty()
				and restart_controller._fall_accumulator == 0.0
				and restart_controller._lock_accumulator == 0.0
				and restart_controller._lock_resets == 0
				and restart_controller.state == MainGameController.GameState.PLAYING,
			"상태 %d에서 R 재시작이 점수·레벨·줄·timer·기믹·보스·blocker·물길·freeze를 초기화한다."
				% restart_state
		)
	restart_controller.free()


func _test_runtime_cleanup() -> void:
	var scene: MainGameView = GAME_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var controller: MainGameController = scene.get_node("GameController")
	var character: MainCharacterController = scene.get_node("BoardPhysics/Character")
	character.is_meditating = true
	character._meditation_loop_player.play()
	character.is_bound = true
	character.binding_timer = 2.0
	character._barrier_remaining = 2.0
	character._water_remaining = 2.0
	character._ninja_projectile = {"active": true}
	controller.transient_blocker_cells = [Vector2i(2, 2)]
	controller.water_path_cells = [Vector2i(3, 3)]
	controller.fall_freeze_remaining = 2.0
	controller.future_gimmick_freeze_remaining = 2.0
	controller.boss_seeds = [{"position": Vector2.ZERO}]
	controller.end_game()
	_expect(
		controller.state == MainGameController.GameState.GAME_OVER
			and not character.is_meditating
			and not character.is_bound
			and is_zero_approx(character.binding_timer)
			and is_zero_approx(character._barrier_remaining)
			and is_zero_approx(character._water_remaining)
			and character._ninja_projectile.is_empty()
			and controller.transient_blocker_cells.is_empty()
			and controller.water_path_cells.is_empty()
			and is_zero_approx(controller.fall_freeze_remaining)
			and is_zero_approx(controller.future_gimmick_freeze_remaining)
			and controller.boss_seeds.is_empty()
			and not character._meditation_loop_player.playing
			and character._sfx_player.stream == null
			and character._sfx_cue_player.stream == null
			and character._meditation_loop_player.stream == null,
		"게임 종료는 명상·투사체·보호벽·물길·freeze·결박 상태를 한 번에 정리한다."
	)
	character._sfx_player.stop()
	character._sfx_cue_player.stop()
	character._meditation_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	scene.free()
	await process_frame


func _test_spawn_side_margin() -> void:
	var controller: MainGameController = GAME_CONTROLLER.new() # scene 없이 spawn 규칙만 검증할 임시 controller.
	controller.reset_game(20260804)
	controller.board.reset()
	var expected_counts: PackedInt32Array = [5, 6, 6, 7, 6, 6, 6] # I/J/L/O/S/T/Z 안전 후보 수.
	for piece_type: int in range(MainTetrominoData.TYPE_COUNT):
		var candidates: Array[Vector2i] = controller._valid_spawn_origins(
			piece_type,
			MainGameController.SPAWN_SIDE_MARGIN_CELLS
		)
		_expect(
			candidates.size() == expected_counts[piece_type],
			"%s 피스의 한 칸 여백 spawn 후보 수가 %d개다."
				% [MainTetrominoData.get_display_name(piece_type), expected_counts[piece_type]]
		)
		var all_candidates_safe: bool = true # 네 실제 셀 중 하나라도 x=0/9면 false가 된다.
		for origin: Vector2i in candidates:
			for local_cell: Vector2i in MainTetrominoData.get_cells(piece_type, 0):
				var occupied_x: int = origin.x + local_cell.x
				if (
					occupied_x < MainGameController.SPAWN_SIDE_MARGIN_CELLS
					or occupied_x
					>= MainBoardModel.WIDTH - MainGameController.SPAWN_SIDE_MARGIN_CELLS
				):
					all_candidates_safe = false
		_expect(
			all_candidates_safe,
			"%s 피스의 모든 우선 spawn 실제 셀이 좌우 한 칸 여백을 지킨다."
				% MainTetrominoData.get_display_name(piece_type)
		)
		var chosen_origin: Variant = controller._choose_random_spawn_origin(piece_type)
		_expect(
			chosen_origin != null and candidates.has(chosen_origin as Vector2i),
			"%s 피스는 안전 후보가 있으면 벽 옆 후보를 선택하지 않는다."
				% MainTetrominoData.get_display_name(piece_type)
		)

	# 회전 0 I 피스는 SPAWN_Y+1 행에 가로 4칸을 차지한다. 가운데 x=4,5를 막으면
	# 한 칸 여백 후보는 모두 막히지만 x=0..3과 x=6..9의 벽 접촉 후보는 남는다.
	controller.board.reset()
	var i_spawn_row: int = MainGameController.SPAWN_Y + 1
	controller.board.cells[i_spawn_row][4] = MainTetrominoData.Type.T
	controller.board.cells[i_spawn_row][5] = MainTetrominoData.Type.T
	_expect(
		controller._valid_spawn_origins(
			MainTetrominoData.Type.I,
			MainGameController.SPAWN_SIDE_MARGIN_CELLS
		).is_empty(),
		"I 피스의 중앙 안전 spawn 영역을 완전히 막을 수 있다."
	)
	var fallback_origin: Variant = controller._choose_random_spawn_origin(MainTetrominoData.Type.I)
	var fallback_x: int = (fallback_origin as Vector2i).x if fallback_origin != null else -1
	_expect(
		fallback_origin != null and (fallback_x == 0 or fallback_x == 6),
		"안전 후보가 없으면 I 피스가 벽 옆의 유효 후보로 fallback한다."
	)

	controller.board.reset()
	for x: int in range(MainBoardModel.WIDTH):
		controller.board.cells[i_spawn_row][x] = MainTetrominoData.Type.T
	controller.next_type = MainTetrominoData.Type.I
	_expect(
		not controller.spawn_next_piece()
			and controller.state == MainGameController.GameState.GAME_OVER,
		"여백 후보와 벽 옆 후보가 모두 없을 때만 GAME_OVER가 된다."
	)
	controller.free()


func _test_boss_seeds() -> void:
	var controller: MainGameController = GAME_CONTROLLER.new()
	controller.stage_number = 5
	controller.reset_game(20260811)
	_expect(
			controller.get_stage_gimmick_config()["binding_enabled"]
			and is_equal_approx(
				float(controller.get_stage_gimmick_config()["binding_first_delay"]),
				5.0
			)
			and MainGameController.BOSS_SEED_SIZE == Vector2.ONE * MainLayout.CELL_SIZE
			and is_equal_approx(
				MainGameController.BOSS_SEED_FIRST_DELAY_SECONDS,
				10.0
			)
			and is_equal_approx(MainGameController.BOSS_SEED_INTERVAL_SECONDS, 20.0)
			and is_equal_approx(MainGameController.BOSS_SEED_LIFETIME_SECONDS, 5.0),
		"Stage 1-5는 5초 시작 속박과 10초 시작·20초 주기의 씨앗 기믹을 함께 사용한다."
	)
	_expect(
		controller.boss_seeds.is_empty()
			and is_zero_approx(controller.boss_seed_timer),
		"보스 씨앗은 게임 시작 직후 생성되지 않는다."
	)
	controller._advance_stage_gimmicks(9.9)
	_expect(
		controller.boss_seeds.is_empty()
			and controller.boss_seed_timer < MainGameController.BOSS_SEED_FIRST_DELAY_SECONDS,
		"첫 씨앗 발사 전 10초 동안 씨앗 타이머만 진행된다."
	)
	controller._advance_stage_gimmicks(0.1)
	var first_columns: Array[int] = []
	for seed: Dictionary in controller.boss_seeds:
		var position: Vector2 = seed["position"] as Vector2
		first_columns.append(floori(position.x / MainLayout.CELL_SIZE))
	var columns_are_unique: bool = true
	for index: int in range(first_columns.size()):
		if first_columns.slice(index + 1).has(first_columns[index]):
			columns_are_unique = false
	_expect(
		controller.boss_seeds.size() == MainGameController.BOSS_SEED_COUNT
			and columns_are_unique
			and is_zero_approx(controller.boss_seed_timer),
		"첫 발사에서 보스 아래 서로 다른 랜덤 열에 씨앗 3개가 생성된다."
	)
	_expect(
		BOSS_SEED_TEXTURE.get_width() > 0
			and BOSS_SEED_TEXTURE.get_height() > 0
			and BOSS_SEED_TEXTURE.get_size() == Vector2.ONE * MainLayout.CELL_SIZE
			and BOSS_SEED_TEXTURE.get_image().get_format() == Image.FORMAT_RGBA8,
		"씨앗 스프라이트는 블럭 한 칸 크기의 RGBA 이미지로 등록된다."
	)
	var seed_region: Rect2 = ANIMATION_DATA.opaque_region_for(
		BOSS_SEED_TEXTURE,
		Rect2(Vector2.ZERO, BOSS_SEED_TEXTURE.get_size())
	)
	_expect(
		seed_region.position == Vector2.ZERO
			and seed_region.size == BOSS_SEED_TEXTURE.get_size(),
		"씨앗 스프라이트는 보이는 영역에 맞게 투명 여백을 제거한다."
	)

	var active_column: int = first_columns[1]
	var fixed_column: int = first_columns[2]
	if fixed_column == active_column or fixed_column == active_column + 1:
		fixed_column = first_columns[0]
	controller.active_origin = Vector2i(active_column, 8)
	controller.active_type = MainTetrominoData.Type.O
	controller.active_rotation = 0
	controller.active_cell_indices = [0, 1, 2, 3]
	controller.board.cells[8][fixed_column] = MainTetrominoData.Type.T
	controller._advance_stage_gimmicks(0.4)
	var fixed_seed_settled: bool = false
	var fixed_seed_y: float = 0.0
	var active_seed_remaining: bool = false
	for seed: Dictionary in controller.boss_seeds:
		var seed_position: Vector2 = seed["position"] as Vector2
		var seed_column: int = floori(seed_position.x / MainLayout.CELL_SIZE)
		if seed_column == fixed_column:
			fixed_seed_settled = bool(seed["settled"])
			fixed_seed_y = seed_position.y
		if seed_column == active_column:
			active_seed_remaining = true
	_expect(
		fixed_seed_settled
			and is_equal_approx(
				fixed_seed_y,
				float(8 - MainBoardModel.HIDDEN_ROWS) * MainLayout.CELL_SIZE
					- MainGameController.BOSS_SEED_SIZE.y * 0.5
			)
			and not active_seed_remaining,
		"씨앗은 떨어지는 활성 블록에 닿으면 사라지고 비활성 블록 윗면에서 멈춘다."
	)
	_expect(
		not is_finite(
			controller._boss_seed_landing_y(
				MainGameController.BOSS_SEED_SIZE.x * 0.5,
				MainGameController.BOSS_POSITION.y
					+ MainGameController.BOSS_DISPLAY_SIZE.y * 0.5
					+ MainGameController.BOSS_SEED_SPAWN_MARGIN,
				MainGameController.BOSS_POSITION.y
					+ MainGameController.BOSS_DISPLAY_SIZE.y * 0.5
					+ MainGameController.BOSS_SEED_SPAWN_MARGIN
					+ MainGameController.BOSS_SEED_FALL_SPEED * 0.1
			)
		),
		"게임판 가장자리 씨앗도 벽에 붙지 않고 계속 낙하한다."
	)
	controller._advance_stage_gimmicks(3.0)
	var all_seeds_settled: bool = true
	for seed: Dictionary in controller.boss_seeds:
		all_seeds_settled = all_seeds_settled and bool(seed["settled"])
	_expect(all_seeds_settled, "고정 블록이 없는 씨앗은 바닥에 착지한다.")
	controller._advance_stage_gimmicks(5.0)
	_expect(controller.boss_seeds.is_empty(), "착지한 씨앗은 5초 뒤 모두 사라진다.")

	controller._advance_stage_gimmicks(11.5)
	_expect(
		controller.boss_seeds.is_empty(),
		"두 번째 씨앗 발사 전 20초 주기를 지킨다."
	)
	controller._advance_stage_gimmicks(0.1)
	_expect(
		controller.boss_seeds.size() == MainGameController.BOSS_SEED_COUNT,
		"첫 발사 후 20초가 지나면 씨앗 3개를 다시 뿌린다."
	)
	var lock_controller: MainGameController = GAME_CONTROLLER.new()
	lock_controller.stage_number = 5
	lock_controller.reset_game(20260811)
	lock_controller.board.reset()
	lock_controller.board.cells[20][4] = MainTetrominoData.Type.T
	lock_controller.active_type = MainTetrominoData.Type.O
	lock_controller.active_rotation = 0
	lock_controller.active_origin = Vector2i(3, 18)
	lock_controller.active_cell_indices = [0, 1, 2, 3]
	lock_controller.boss_seeds.append({
		"position": Vector2(
			4.5 * MainLayout.CELL_SIZE,
			float(20 - MainBoardModel.HIDDEN_ROWS) * MainLayout.CELL_SIZE
				- MainGameController.BOSS_SEED_SIZE.y * 0.5
		),
		"settled": true,
		"remaining": MainGameController.BOSS_SEED_LIFETIME_SECONDS,
	})
	lock_controller.boss_seeds.append({
		"position": Vector2(
			8.5 * MainLayout.CELL_SIZE,
			float(MainBoardModel.VISIBLE_HEIGHT) * MainLayout.CELL_SIZE
				- MainGameController.BOSS_SEED_SIZE.y * 0.5
		),
		"settled": true,
		"remaining": MainGameController.BOSS_SEED_LIFETIME_SECONDS,
	})
	lock_controller.lock_active_piece()
	_expect(
		lock_controller.boss_seeds.size() == 1,
		"블럭이 고정될 때 겹친 씨앗만 사라지고 다른 씨앗은 유지된다."
	)
	lock_controller.free()
	var paused_seed_timer: float = controller.boss_seed_timer
	controller.state = MainGameController.GameState.PAUSED
	controller._advance_stage_gimmicks(20.0)
	_expect(
		is_equal_approx(controller.boss_seed_timer, paused_seed_timer)
			and controller.boss_seeds.size() == MainGameController.BOSS_SEED_COUNT,
		"PAUSED에서는 씨앗 발사·수명 시간이 멈춘다."
	)
	controller.free()

	var damage_controller: MainGameController = GAME_CONTROLLER.new()
	damage_controller.stage_number = 5
	damage_controller.reset_game(20260811)
	for clear_index: int in range(MainGameController.BOSS_MAX_HEALTH):
		damage_controller.board.reset()
		damage_controller.boss_health = MainGameController.BOSS_MAX_HEALTH - clear_index
		for column: int in range(MainBoardModel.WIDTH):
			damage_controller.board.cells[20][column] = MainTetrominoData.Type.T
		damage_controller.active_type = MainTetrominoData.Type.O
		damage_controller.active_rotation = 0
		damage_controller.active_origin = Vector2i(3, 18)
		damage_controller.active_cell_indices = [0, 1, 2, 3]
		damage_controller.lock_active_piece()
		if clear_index < MainGameController.BOSS_MAX_HEALTH - 1:
			_expect(
				damage_controller.boss_health == MainGameController.BOSS_MAX_HEALTH - clear_index - 1
					and damage_controller.state == MainGameController.GameState.PLAYING,
				"정상 라인 1줄 삭제가 보스 체력을 %d에서 %d로 줄인다." % [
					MainGameController.BOSS_MAX_HEALTH - clear_index,
					MainGameController.BOSS_MAX_HEALTH - clear_index - 1,
				]
			)
		else:
			_expect(
				damage_controller.boss_health == 0
					and damage_controller.state == MainGameController.GameState.BOSS_FALLING
					and damage_controller.boss_down,
				"정상 라인 삭제로 보스 체력이 0이 되면 down으로 전환한다."
			)
	_stage_cleared_captured = false
	damage_controller.stage_cleared.connect(_on_stage_cleared_captured)
	damage_controller._advance_boss_fall(MainGameController.BOSS_DOWN_DURATION_SECONDS + 2.0)
	damage_controller._advance_boss_fall(MainGameController.BOSS_FALLEN_HOLD_SECONDS)
	_expect(
		_stage_cleared_captured
			and damage_controller.boss_fallen
			and damage_controller.state == MainGameController.GameState.PAUSED,
		"보스 체력 0 뒤 down -> fall -> stage clear 흐름을 유지한다."
	)
	damage_controller.free()

	var scene: MainGameView = GAME_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var scene_controller: MainGameController = scene.get_node("GameController")
	var character: MainCharacterController = scene.get_node("BoardPhysics/Character")
	scene_controller.stage_number = 5
	scene_controller.reset_game(20260811)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene_controller._advance_stage_gimmicks(10.0)
	var seed_count_before_contact: int = scene_controller.boss_seeds.size()
	character.position = (scene_controller.boss_seeds[0]["position"] as Vector2)
	var contact_position: Vector2 = character.position
	scene_controller._advance_stage_gimmicks(0.0)
	var seed_is_still_at_contact: bool = false
	for child: Node in scene.get_node("BoardPhysics").get_children():
		if not child is Sprite2D:
			continue
		var seed_sprite_node: Sprite2D = child as Sprite2D
		if (
			seed_sprite_node.name.begins_with("BossSeed")
			and seed_sprite_node.visible
			and seed_sprite_node.position.is_equal_approx(contact_position)
		):
			seed_is_still_at_contact = true
	_expect(
		character.is_bound
			and is_equal_approx(
				character.binding_timer,
				MainGameController.BOSS_BINDING_DURATION_SECONDS
			)
			and scene_controller.boss_seeds.size() == seed_count_before_contact - 1
			and not seed_is_still_at_contact,
		"씨앗에 닿은 플레이어는 3초 속박되고 해당 씨앗은 즉시 사라진다."
	)
	character._sfx_player.stop()
	character._sfx_cue_player.stop()
	character._meditation_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	scene.free()
	await process_frame


## 상황: 각 테스트 조건을 기록하고 사람이 읽는 결과를 stdout/stderr에 출력할 때 호출된다.
## 결과: check는 항상 1 증가하고, 실패 조건에서만 failure를 증가시킨다.
func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  [통과] %s" % description)
	else:
		_failures += 1
		push_error("  [실패] %s" % description)


## 상황: 실제 main scene에서 X press/release와 hitbox 기반 피스 이동을 검증할 때 호출된다.
## 순서: scene 생성/정지 → 맞는 위치의 hit → 빗나가는 위치의 miss → audio/node 정리.
## 결과: release 전에는 움직이지 않고 release 판정 창에서만 피스가 이동한다는 계약을 검사한다.
func _test_release_punch() -> void:
	var scene: MainGameView = GAME_SCENE.instantiate() # 테스트가 소유해 마지막에 free할 실제 scene 인스턴스.
	root.add_child(scene)
	await process_frame
	await physics_frame
	await process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED

	var controller: MainGameController = scene.get_node("GameController") # 논리 피스 상태 관찰 대상.
	var character: MainCharacterController = scene.get_node("BoardPhysics/Character") # 입력·hitbox 실행 대상.
	_test_character_frame_normalization(controller, character)
	_test_binding_overlay_alignment(scene, character)
	character.facing = 1
	_expect(
		character._rotation_direction_for_arrows(true, false) == 1
			and character._rotation_direction_for_arrows(false, true) == -1
			and character._rotation_direction_for_arrows(false, false) == 1,
		"위+S는 기존 방향, 아래+S는 반대 방향이며 단독 S는 기존 동작을 유지한다."
	)
	character.facing = -1
	_expect(
		character._rotation_direction_for_arrows(true, false) == -1
			and character._rotation_direction_for_arrows(false, true) == 1,
		"회전 화살표 방향은 캐릭터 facing을 기준으로 반전된다."
	)
	character._start_rotation_spin(-1)
	var reverse_spin_started: bool = character._spin_direction == -1
	character._spin_remaining = 0.0
	character._start_rotation_spin(1)
	_expect(
		reverse_spin_started and character._spin_direction == 1,
		"블록 회전과 캐릭터 회전 연출이 같은 방향을 사용한다."
	)
	character._spin_remaining = 0.0
	character.is_hanging = true
	character.stamina = 0.0
	character._update_sprite_modulation()
	var exhausted_hang_is_red: bool = character.sprite.modulate.is_equal_approx(Color(1.0, 0.0, 0.0, 1.0))
	character.is_hanging = false
	character.stamina = MainCharacterController.MAX_STAMINA
	character._update_sprite_modulation()
	_expect(
		exhausted_hang_is_red and character.sprite.modulate.is_equal_approx(Color.WHITE),
		"스테미나가 소진된 매달리기는 고정 빨간색이고 평상시는 기존 색으로 돌아온다."
	)
	_expect(
		MainGameView.SPECIAL_BAR_RECT.position.y
			> MainLayout.BOARD_ORIGIN.y + MainLayout.BOARD_SIZE.y
			and MainGameView.SPECIAL_BAR_RECT.size.x == MainLayout.BOARD_SIZE.x,
		"현재 캐릭터 스킬 쿨타임 바는 게임판 아래 전체 너비를 사용한다."
	)
	character.position = Vector2(-100.0, -100.0)
	character.velocity = Vector2(-1.0, -1.0)
	character._clamp_to_board_bounds()
	var clamped_to_board: bool = (
		character.position.x == MainCharacterController.BOARD_MIN_X
		and character.position.y == MainCharacterController.BOARD_MIN_Y
		and character.velocity == Vector2.ZERO
	)
	character.position = Vector2(1000.0, 1000.0)
	character.velocity = Vector2(1.0, 1.0)
	character._clamp_to_board_bounds()
	clamped_to_board = clamped_to_board and (
		character.position.x == MainCharacterController.BOARD_MAX_X
		and character.position.y == MainCharacterController.BOARD_MAX_Y
		and character.velocity == Vector2.ZERO
	)
	_expect(
		clamped_to_board,
		"캐릭터 collider가 게임판 상하좌우 경계를 벗어나지 않는다."
	)
	character.position = Vector2(240.0, 912.0)
	character.velocity = Vector2.ZERO
	_expect(
		character.character_id == "normal"
			and not character.set_character_id("missing_character"),
		"알 수 없는 캐릭터 ID는 기본 profile을 바꾸지 않는다."
	)
	var crush_sensor: ShapeCast2D = character.get_node("CrushSensor")
	var crush_sensor_shape: RectangleShape2D = crush_sensor.shape as RectangleShape2D
	var crush_sensor_rect: Rect2 = character._crush_sensor_rect()
	var character_rect: Rect2 = character._character_collider_rect()
	_expect(
		crush_sensor_shape != null
			and crush_sensor_shape.size == Vector2(30.0, 12.0)
			and crush_sensor_rect.position.y == character_rect.position.y
			and crush_sensor_rect.end.y < character_rect.end.y
			and crush_sensor_rect.position.x > character_rect.position.x
			and crush_sensor_rect.end.x < character_rect.end.x,
		"CrushSensor는 모든 캐릭터에 공통인 머리 상단 30x12px 영역이며 collider 안쪽에 있다."
	)
	_expect(
		character.set_character_id("chef")
			and character.character_id == "chef"
			and character.sprite.texture
			== ANIMATION_DATA.texture_for(ANIMATION_DATA.IDLE, "chef")
			and character.character_profile()["display_name"] == "성녀",
		"Chef 슬롯은 Saintess atlas와 프로필을 사용한다."
	)
	var crush_results: Array[bool] = []
	for character_id: String in CHARACTER_DATA.CHARACTER_ORDER:
		character.set_character_id(character_id)
		crush_results.append(
			character._active_piece_overlaps_crush_sensor(
				Vector2i(4, 18),
				crush_sensor_rect
			)
		)
	var shared_crush_result: bool = true
	for result: bool in crush_results:
		if result != crush_results[0]:
			shared_crush_result = false
			break
	_expect(
		shared_crush_result,
		"모든 캐릭터는 외형과 무관한 동일한 CrushSensor 판정을 사용한다."
	)
	character.play_special_animation()
	_expect(
		character._get_animation_state() == ANIMATION_DATA.SPECIAL
			and character._special_animation_remaining
			== MainCharacterController.SPECIAL_ANIMATION_DURATION,
		"특수 스킬 호출은 8 frame SPECIAL 상태를 시작한다."
	)
	character._special_animation_remaining = 0.0
	_prepare_punch(controller, character, Vector2i(3, 19), Vector2(165.0, 912.0))
	var start_origin: Vector2i = controller.active_origin # release 전후를 비교할 immutable 기준값.
	Input.action_release(&"character_punch")
	character._perform_tap_punch()
	_expect(
		character._pending_punch_stage == 1
			and controller.active_origin == start_origin,
		"X를 누르면 즉시 공통 1칸 밀치기 판정이 예약된다."
	)
	character._resolve_pending_punch(0.0)
	_expect(
		controller.active_origin == start_origin + Vector2i.RIGHT,
		"전방 hitbox에 닿은 블록은 정확히 1칸 이동한다."
	)
	Input.action_release(&"character_punch")

	_prepare_punch(controller, character, Vector2i(3, 19), Vector2(165.0, 912.0))
	controller.active_cell_indices = [0]
	var expected_front_cells: Array[Vector2i] = [Vector2i(4, 20), Vector2i(4, 19)]
	_expect(
		character._basic_attack_target_cells() == expected_front_cells,
		"X target is exactly the lower and upper cells in the immediately facing column."
	)
	character._pending_punch_stage = 1
	character._pending_punch_hit_remaining = 0.1
	character._resolve_pending_punch(0.0)
	_expect(
		controller.active_origin == Vector2i(4, 19),
		"An active cell in the upper front target moves the whole active piece once."
	)

	_prepare_punch(controller, character, Vector2i(3, 19), Vector2(165.0, 912.0))
	controller.active_type = MainTetrominoData.Type.O
	controller.active_cell_indices = [0, 1, 2, 3]
	character._pending_punch_stage = 1
	character._pending_punch_hit_remaining = 0.1
	character._resolve_pending_punch(0.0)
	_expect(
		controller.active_origin == Vector2i(4, 19),
		"Touching both front target cells still pushes the active tetromino only once."
	)

	_prepare_punch(controller, character, Vector2i(3, 19), Vector2(165.0, 912.0))
	controller.active_type = MainTetrominoData.Type.O
	controller.active_cell_indices = [0, 1, 2, 3]
	controller.board.cells[19][6] = MainTetrominoData.Type.J
	character._pending_punch_stage = 1
	character._pending_punch_hit_remaining = 0.1
	character._resolve_pending_punch(0.0)
	_expect(
		controller.active_origin == Vector2i(3, 19),
		"A blocked destination keeps the active tetromino in place."
	)

	var excluded_origins: Array[Vector2i] = [
		Vector2i(3, 18), # above the two-cell window
		Vector2i(4, 20), # below the two-cell window
		Vector2i(1, 19), # behind the character
	]
	var excluded_indices: Array[int] = [0, 1, 0]
	var excluded_cells_do_not_move: bool = true
	for excluded_index: int in range(excluded_origins.size()):
		var excluded_origin: Vector2i = excluded_origins[excluded_index]
		_prepare_punch(controller, character, excluded_origin, Vector2(165.0, 912.0))
		controller.active_cell_indices = [excluded_indices[excluded_index]]
		character._pending_punch_stage = 1
		character._pending_punch_hit_remaining = 0.1
		character._resolve_pending_punch(0.0)
		excluded_cells_do_not_move = (
			excluded_cells_do_not_move and controller.active_origin == excluded_origin
		)
	_expect(
		excluded_cells_do_not_move,
		"Active cells above, below, or behind the exact two-cell X window do not move."
	)
	controller.active_cell_indices = [0, 1, 2, 3]

	_prepare_punch(controller, character, Vector2i(7, 1), Vector2(24.0, 912.0))
	character._perform_tap_punch()
	character._resolve_pending_punch(0.1)
	_expect(
		controller.active_origin == Vector2i(7, 1),
		"전방 hitbox 밖의 블록은 놓아도 이동하지 않는다."
	)
	Input.action_release(&"character_punch")

	_prepare_punch(controller, character, Vector2i(7, 1), Vector2(165.0, 912.0))
	controller.board.cells[20][4] = MainTetrominoData.Type.J
	character._perform_tap_punch()
	character._resolve_pending_punch(0.1)
	_expect(
		controller.board.get_cell(Vector2i(4, 20)) == MainTetrominoData.Type.J
			and controller.board.get_cell(Vector2i(5, 20)) == MainBoardModel.EMPTY,
		"기본 공격은 전방의 고정된 비활성 블록을 이동시키지 않는다."
	)
	Input.action_release(&"character_punch")
	character._sfx_player.stop()
	character._sfx_cue_player.stop()
	character._meditation_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	await create_timer(0.12).timeout
	scene.free()
	await process_frame


func _test_beta_specials() -> void:
	var scene: MainGameView = GAME_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var controller: MainGameController = scene.get_node("GameController")
	var character: MainCharacterController = scene.get_node("BoardPhysics/Character")
	character.position = Vector2(5.5 * MainCharacterController.CELL_SIZE, 912.0)
	character.velocity = Vector2(0.0, 10.0)
	await physics_frame
	await physics_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	character.facing = 1
	_expect(character.is_on_floor(), "특수 스킬 테스트 캐릭터를 물리 바닥에 명시적으로 정착시킨다.")

	character.set_character_id("normal")
	var normal_speed: float = MainCharacterData.move_speed("normal") * MainCharacterController.GIT_GRID_SCALE
	var stamina_before: float = character.stamina
	_expect(
		character._attempt_special_skill()
			and is_equal_approx(character.stamina, stamina_before)
			and is_equal_approx(character.current_move_speed(), normal_speed * 1.6),
		"일반인 전력 질주는 스태미나를 쓰지 않고 2초 동안 이동속도를 60% 높인다."
	)

	controller.board.reset()
	character.set_character_id("boxer")
	controller.board.cells[20][6] = MainTetrominoData.Type.T
	stamina_before = character.stamina
	var boxer_started: bool = character._attempt_special_skill()
	character._resolve_pending_special()
	_expect(
		boxer_started
			and is_equal_approx(character.stamina, stamina_before)
			and controller.board.get_cell(Vector2i(9, 20)) == MainTetrominoData.Type.T,
		"복서 가드 브레이크는 전방 노출 고정 블록을 최대 3칸 밀고 스태미나를 쓰지 않는다."
	)
	controller.board.reset()
	character.special_cooldown_remaining = 0.0
	controller.board.cells[21][6] = MainTetrominoData.Type.T
	var boxer_floor_target_started: bool = character._attempt_special_skill()
	character._resolve_pending_special()
	_expect(
		boxer_floor_target_started
			and character._boxer_special_target_cells()
			== [Vector2i(6, 21), Vector2i(6, 20)]
			and controller.board.get_cell(Vector2i(6, 21)) == MainBoardModel.EMPTY
			and controller.board.get_cell(Vector2i(9, 21)) == MainTetrominoData.Type.T,
		"복서 가드 브레이크는 발 바로 옆의 하단 전방 블록도 최대 3칸 민다."
	)
	controller.board.reset()
	character.special_cooldown_remaining = 0.0
	controller.board.cells[21][6] = MainTetrominoData.Type.J
	controller.board.cells[20][6] = MainTetrominoData.Type.T
	var boxer_upper_fallback_started: bool = character._attempt_special_skill()
	character._resolve_pending_special()
	_expect(
		boxer_upper_fallback_started
			and controller.board.get_cell(Vector2i(6, 21)) == MainTetrominoData.Type.J
			and controller.board.get_cell(Vector2i(6, 20)) == MainBoardModel.EMPTY
			and controller.board.get_cell(Vector2i(9, 20)) == MainTetrominoData.Type.T,
		"하단 블록이 위 블록에 덮여 움직일 수 없으면 복서는 노출된 상단 블록 하나만 민다."
	)
	controller.board.reset()
	character.special_cooldown_remaining = 0.0
	var boxer_failed_started: bool = character._attempt_special_skill()
	character._resolve_pending_special()
	_expect(
		boxer_failed_started
			and is_equal_approx(
				character.special_cooldown_remaining,
				character.current_special_cooldown()
			),
		"복서 가드 브레이크는 0칸 이동 실패에도 특수 쿨다운의 100%를 적용한다."
	)
	character.lives = 3
	character._invulnerability_remaining = 0.0
	controller.active_type = MainTetrominoData.Type.T
	controller.active_rotation = 0
	controller.active_origin = Vector2i(6, 18)
	controller.active_cell_indices = [0, 1, 2, 3]
	character.take_damage()
	_expect(
		character.lives == 2,
		"복서 가드 브레이크는 블록 이동 뒤 추가 피해 무효 효과를 부여하지 않는다."
	)
	character.lives = 3
	character._invulnerability_remaining = 0.0
	controller.active_origin = Vector2i(3, 1)

	controller.board.reset()
	character.set_character_id("shield_guard")
	character.position = Vector2(5.5 * MainCharacterController.CELL_SIZE, 912.0)
	character.facing = 1
	var shield_started: bool = character._attempt_special_skill()
	# Preserve the cast pose throughout the shield wind-up.
	character.position.x -= MainCharacterController.CELL_SIZE
	character.facing = -1
	character._resolve_pending_special()
	_expect(
		shield_started
			and character.barrier_remaining() > 0.0
			and character._barrier_direction == 1
			and controller.transient_blocker_cells.size() == 3
			and Vector2i(6, 21) in controller.transient_blocker_cells
			and Vector2i(6, 20) in controller.transient_blocker_cells
			and Vector2i(6, 19) in controller.transient_blocker_cells,
		"방패병은 시전 방향 앞에 세로 3칸의 임시 보호벽을 만든다."
	)
	character._cancel_character_skill_effects()

	# Occupied candidates are omitted, while generated cells remain the sole
	# collision/display state. The barrier itself must never roll movement back.
	controller.board.reset()
	character.position = Vector2(5.5 * MainCharacterController.CELL_SIZE, 912.0)
	character.facing = 1
	character.special_cooldown_remaining = 0.0
	controller.board.cells[20][6] = MainTetrominoData.Type.T
	var partial_shield_started: bool = character._attempt_special_skill()
	character._resolve_pending_special()
	_expect(
		partial_shield_started
			and controller.transient_blocker_cells.size() == 2
			and Vector2i(6, 21) in controller.transient_blocker_cells
			and Vector2i(6, 19) in controller.transient_blocker_cells
			and not Vector2i(6, 20) in controller.transient_blocker_cells,
		"방패병은 점유 칸을 제외하고 실제 생성된 보호막 칸만 판정에 사용한다."
	)
	character._cancel_character_skill_effects()
	character.position = Vector2(5.5 * MainCharacterController.CELL_SIZE, 912.0)
	character.facing = 1

	controller.board.reset()
	character.set_character_id("firefighter")
	character.special_cooldown_remaining = 0.0
	character.position = Vector2(5.5 * MainCharacterController.CELL_SIZE, 912.0)
	character.facing = 1
	var firefighter_started: bool = character._attempt_special_skill()
	# Turning during the hose wind-up must not redirect or relocate the path.
	character.position.x -= MainCharacterController.CELL_SIZE
	character.facing = -1
	if firefighter_started:
		character._resolve_pending_special()
	_expect(
		firefighter_started
			and controller.water_path_direction == 1
			and controller.water_path_cells
			== [Vector2i(6, 21), Vector2i(7, 21), Vector2i(8, 21)],
		"소방관은 고정 지형을 따라 최대 3셀 중력 물길을 만든다."
	)
	var water_visual_is_attached: bool = false
	if not controller.water_path_cells.is_empty():
		var water_cell: Vector2i = controller.water_path_cells[0]
		var water_cell_rect: Rect2 = scene._cell_rect(water_cell)
		var water_display_rect: Rect2 = scene._water_path_display_rect(water_cell)
		var water_source_rect: Rect2 = scene._water_path_source_rect(0)
		water_visual_is_attached = (
			water_display_rect.size == Vector2(
				MainLayout.CELL_SIZE,
				MainGameView.WATER_PATH_DISPLAY_HEIGHT
			)
			and water_display_rect.position.y < water_cell_rect.end.y
			and water_display_rect.end.y > water_cell_rect.end.y
			and water_source_rect.size.y
				== MainGameView.WATER_PATH_SOURCE_VISIBLE_HEIGHT
		)
	_expect(
		water_visual_is_attached,
		"소방관 물길은 실제 물 픽셀을 확대해 블록 윗면과 겹치도록 밀착 표시한다."
	)

	controller.board.reset()
	controller.active_type = MainTetrominoData.Type.O
	controller.active_rotation = 0
	controller.active_origin = Vector2i(3, 20)
	controller.active_cell_indices = [0, 1, 2, 3]
	var water_creation_origin: Vector2i = controller.active_origin
	var overlapping_water_created: bool = controller.create_water_path(
		Vector2i(4, 21),
		1,
		3
	)
	_expect(
		overlapping_water_created and controller.active_origin == water_creation_origin,
		"소방관 물길은 생성 순간 활성 블록을 밀지 않고 다음 자동 낙하 단계를 기다린다."
	)

	controller.board.reset()
	controller.active_type = MainTetrominoData.Type.O
	controller.active_rotation = 0
	controller.active_origin = Vector2i(3, 5)
	controller.active_cell_indices = [0, 1, 2, 3]
	controller.board.cells[5][6] = MainTetrominoData.Type.T
	controller.water_path_cells = [Vector2i(4, 6)]
	controller.water_path_direction = 1
	controller._fall_accumulator = 0.0
	controller._advance_gravity(MainGameController.GRAVITY_INTERVAL_SECONDS)
	var blocked_slide_still_descended: bool = controller.active_origin == Vector2i(3, 6)
	controller._advance_gravity(MainGameController.GRAVITY_INTERVAL_SECONDS)
	_expect(
		blocked_slide_still_descended and controller.active_origin == Vector2i(4, 7),
		"물길은 각 자동 낙하 단계에서 옆 이동을 한 번 먼저 시도하고 막혀도 아래로 낙하한다."
	)
	character._cancel_character_skill_effects()
	character.position = Vector2(5.5 * MainCharacterController.CELL_SIZE, 912.0)
	character.facing = 1

	controller.board.reset()
	character.set_character_id("cleaner")
	character.special_cooldown_remaining = 0.0
	character.position = Vector2(5.5 * MainCharacterController.CELL_SIZE, 864.0)
	for x: int in range(4, 7):
		controller.board.cells[MainBoardModel.HEIGHT - 1][x] = MainTetrominoData.Type.T
	_expect(
		character._cell_below_feet() == Vector2i(5, 21),
		"청소부의 발밑 행은 고정 블록 위에서도 공통 42×90 콜라이더 아랫면을 따른다."
	)
	var cleaner_started: bool = character._attempt_special_skill()
	# Moving during the sweep must not move the three cast-time target cells.
	character.position.x += MainCharacterController.CELL_SIZE * 2.0
	if cleaner_started:
		character._resolve_pending_special()
	_expect(
		cleaner_started
			and controller.board.get_cell(Vector2i(4, MainBoardModel.HEIGHT - 1)) == MainBoardModel.EMPTY
			and controller.board.get_cell(Vector2i(5, MainBoardModel.HEIGHT - 1)) == MainBoardModel.EMPTY
			and controller.board.get_cell(Vector2i(6, MainBoardModel.HEIGHT - 1)) == MainBoardModel.EMPTY,
		"청소부 대청소는 캐릭터 발밑 중심의 노출 고정 블록을 최대 세 개 제거한다."
	)

	controller.board.reset()
	controller.active_type = MainTetrominoData.Type.T
	controller.active_rotation = 0
	controller.active_origin = Vector2i(4, 20)
	controller.active_cell_indices = [0]
	for x: int in range(4, 7):
		controller.board.cells[21][x] = MainTetrominoData.Type.J
	var removed_around_active: int = controller.clean_exposed_cells(Vector2i(5, 21))
	_expect(
		removed_around_active == 2
			and controller.board.get_cell(Vector2i(4, 21)) == MainBoardModel.EMPTY
			and controller.board.get_cell(Vector2i(5, 21)) == MainTetrominoData.Type.J
			and controller.board.get_cell(Vector2i(6, 21)) == MainBoardModel.EMPTY,
		"청소부는 활성 블록이 바로 위에 있는 고정 블록을 노출 대상으로 잘못 삭제하지 않는다."
	)
	character.position = Vector2(5.5 * MainCharacterController.CELL_SIZE, 912.0)

	controller.board.reset()
	character.set_character_id("chef")
	character.special_cooldown_remaining = 0.0
	var chef_base_speed: float = MainCharacterData.move_speed("chef") * MainCharacterController.GIT_GRID_SCALE
	var chef_started: bool = character._attempt_special_skill()
	if chef_started:
		character._resolve_pending_special()
	_expect(
		chef_started
			and is_equal_approx(character.chef_meat_remaining(), 3.0)
			and character.chef_meat_guard_available()
			and is_equal_approx(character.current_move_speed(), chef_base_speed * 1.2),
		"성녀의 성역의 가호는 3초 동안 이동속도를 20% 높이고 다음 피해 방어를 준비한다."
	)
	character.lives = 3
	character._invulnerability_remaining = 0.0
	character.take_damage()
	_expect(
		character.lives == 2
			and not character.chef_meat_guard_available(),
		"성녀의 가호는 블록 압착 피해를 막지 못한다."
	)
	character.lives = 3
	character._invulnerability_remaining = 0.0
	character.position = Vector2(5.5 * MainCharacterController.CELL_SIZE, 912.0)
	character.special_cooldown_remaining = 0.0
	character._attempt_special_skill()
	character._resolve_pending_special()
	character.apply_binding(2.0)
	_expect(
		not character.is_bound
			and character.lives == 3
			and not character.chef_meat_guard_available()
			and character.chef_meat_remaining() > 0.0,
		"성녀의 다음 위험 1회 방어는 결박을 무효화하고 속도 강화는 유지한다."
	)
	character.apply_binding(2.0)
	_expect(
		character.is_bound,
		"성녀의 가호를 소모한 뒤의 다음 결박은 정상 적용된다."
	)
	character._end_binding()
	character.special_cooldown_remaining = 0.0
	character._attempt_special_skill()
	character._resolve_pending_special()
	character.take_thorn_damage()
	_expect(
		character.lives == 3
			and not character.chef_meat_guard_available()
			and is_equal_approx(character.current_move_speed(), chef_base_speed * 1.2),
		"성녀의 다음 피해 1회 무효는 가시 피해를 소비하고 이동 강화는 남은 시간 동안 유지한다."
	)
	character.take_thorn_damage()
	_expect(
		character.lives == 2,
		"성녀의 가호를 소비한 뒤의 다음 피해는 정상적으로 목숨을 차감한다."
	)
	character._update_timers(3.0)
	_expect(
		is_zero_approx(character.chef_meat_remaining())
			and is_equal_approx(character.current_move_speed(), chef_base_speed),
		"요리사의 고기 섭취 이동 강화와 남은 방어는 3초 뒤 함께 종료된다."
	)
	character.lives = 3
	character._invulnerability_remaining = 0.0

	controller.board.reset()
	character.set_character_id("clockmaker")
	character.special_cooldown_remaining = 0.0
	stamina_before = character.stamina
	var frozen_origin: Vector2i = controller.active_origin
	var clockmaker_started: bool = character._attempt_special_skill()
	character._resolve_pending_special()
	controller._physics_process(1.0)
	_expect(
		clockmaker_started
			and is_equal_approx(character.stamina, stamina_before)
			and controller.active_origin == frozen_origin
			and is_equal_approx(controller.fall_freeze_remaining, 2.0),
		"시계공 정지 태엽은 3초 동안 활성 블록의 낙하와 고정 시간을 멈춘다."
	)
	character._cancel_character_skill_effects()
	_expect(
		is_zero_approx(controller.fall_freeze_remaining),
		"시계공의 시간 정지는 캐릭터 변경·피격용 임시 효과 정리에서 해제된다."
	)

	controller.board.reset()
	controller.active_type = MainTetrominoData.Type.O
	controller.active_rotation = 0
	controller.active_origin = Vector2i(6, 19)
	controller.active_cell_indices = [0, 1, 2, 3]
	character.set_character_id("ninja")
	character.special_cooldown_remaining = 0.0
	stamina_before = character.stamina
	var ninja_origin_before: Vector2i = controller.active_origin
	var ninja_started: bool = character._attempt_special_skill()
	character._resolve_pending_special()
	var ninja_waits_for_visual_contact: bool = controller.active_origin == ninja_origin_before
	character._advance_ninja_projectile(0.5)
	_expect(
		ninja_started
			and is_equal_approx(character.stamina, stamina_before)
			and ninja_waits_for_visual_contact
			and controller.active_origin == ninja_origin_before + Vector2i.RIGHT,
		"닌자 표창은 활성 미노에 명중하면 도형 전체를 정확히 1칸 민다."
	)
	var ninja_result: Dictionary = character.ninja_special_result()
	var ninja_board_position: Vector2 = ninja_result["position"] as Vector2
	_expect(
		scene.ninja_shuriken_canvas_position(ninja_board_position)
			== MainLayout.BOARD_ORIGIN + ninja_board_position,
		"닌자 표창 VFX는 캐릭터 위치·바라보는 방향을 다시 더하지 않고 실제 보드 충돌 좌표에 표시된다."
	)
	_expect(
		MainCharacterController.SHURIKEN_COLLISION_SIZE == Vector2(32.0, 32.0),
		"닌자 표창 충돌 판정은 화면에 표시되는 32×32 스프라이트 크기와 일치한다."
	)

	controller.board.reset()
	controller.active_type = MainTetrominoData.Type.O
	controller.active_rotation = 0
	controller.active_origin = Vector2i(6, 10)
	controller.active_cell_indices = [0, 1, 2, 3]
	var range_six_origin: Vector2i = controller.active_origin
	var range_six_result: Dictionary = controller.throw_shuriken_at_active_piece(
		Vector2i(1, 10),
		1,
		6
	)
	_expect(
		bool(range_six_result["success"])
			and range_six_result["contact"] == MainGameController.SHURIKEN_CONTACT_ACTIVE
			and int(range_six_result["travel_cells"]) == 6
			and range_six_result["impact_cell"] == Vector2i(7, 10)
			and controller.active_origin == range_six_origin + Vector2i.RIGHT,
		"닌자 표창은 정확히 6칸 거리의 활성 블록 명중 위치를 결과에 기록한다."
	)

	controller.board.reset()
	controller.active_origin = Vector2i(6, 10)
	controller.board.cells[10][4] = MainTetrominoData.Type.Z
	var blocked_origin: Vector2i = controller.active_origin
	var fixed_result: Dictionary = controller.throw_shuriken_at_active_piece(
		Vector2i(1, 10),
		1,
		6
	)
	_expect(
		not bool(fixed_result["success"])
			and fixed_result["contact"] == MainGameController.SHURIKEN_CONTACT_FIXED
			and int(fixed_result["travel_cells"]) == 3
			and fixed_result["impact_cell"] == Vector2i(4, 10)
			and controller.active_origin == blocked_origin
			and controller.board.get_cell(Vector2i(4, 10)) == MainTetrominoData.Type.Z,
		"닌자 표창은 첫 고정 블록의 충돌 위치를 기록하고 그 블록을 이동시키지 않는다."
	)

	controller.board.reset()
	controller.active_origin = Vector2i(6, 10)
	controller.board.cells[10][9] = MainTetrominoData.Type.J
	var destination_blocked: Dictionary = controller.throw_shuriken_at_active_piece(
		Vector2i(1, 10),
		1,
		6
	)
	controller.board.reset()
	var forbidden_blocked: Dictionary = controller.throw_shuriken_at_active_piece(
		Vector2i(1, 10),
		1,
		6,
		[Vector2i(9, 11)]
	)
	_expect(
		not bool(destination_blocked["success"])
			and destination_blocked["contact"] == MainGameController.SHURIKEN_CONTACT_ACTIVE
			and not bool(forbidden_blocked["success"])
			and forbidden_blocked["contact"] == MainGameController.SHURIKEN_CONTACT_ACTIVE
			and controller.active_origin == Vector2i(6, 10),
		"닌자 표창은 목적지의 고정 블록·금지 셀·캐릭터 충돌에 활성 도형을 이동하지 않는다."
	)

	controller.board.reset()
	controller.active_origin = Vector2i(3, 1)
	character.special_cooldown_remaining = 0.0
	var ninja_miss_started: bool = character._attempt_special_skill()
	character._resolve_pending_special()
	character._advance_ninja_projectile(0.5)
	_expect(
		ninja_miss_started
			and not character.last_special_succeeded()
			and character.ninja_special_result()["contact"] == MainGameController.SHURIKEN_CONTACT_NONE
			and not bool(character.ninja_special_result()["in_flight"])
			and is_equal_approx(
				character.special_cooldown_remaining,
				character.current_special_cooldown()
			),
		"닌자 표창은 대상이 없어 실패해도 계산된 특수 쿨다운의 100%를 적용한다."
	)
	character._update_timers(1.0)
	_expect(
		not character.ninja_special_result().is_empty(),
		"닌자 표창 충돌 이펙트는 캐릭터 특수 동작이 끝나도 자체 표시 시간 동안 유지된다."
	)
	character._advance_ninja_projectile(MainCharacterController.SHURIKEN_IMPACT_DURATION)
	_expect(
		character.ninja_special_result().is_empty(),
		"닌자 표창 판정 결과는 충돌 이펙트 표시 시간이 끝난 뒤 정리된다."
	)

	character.set_character_id("normal")
	character.rotation_cooldown_remaining = 0.0
	character.position = Vector2(5.5 * MainCharacterController.CELL_SIZE, 912.0)
	character._attempt_rotation_kick()
	_expect(
		is_equal_approx(character.rotation_cooldown_remaining, character.current_rotation_cooldown()),
		"회전킥은 대상이 없어 실패해도 성공과 동일한 100% 쿨다운을 적용한다."
	)

	character.rotation_cooldown_remaining = 0.0
	character.is_meditating = true
	character._attempt_rotation_kick()
	_expect(
		is_zero_approx(character.rotation_cooldown_remaining),
		"명상처럼 회전킥 입력 자체가 차단된 상태에서는 쿨다운을 시작하지 않는다."
	)
	character.is_meditating = false

	controller.board.reset()
	controller.active_type = MainTetrominoData.Type.T
	controller.active_rotation = 0
	controller.active_origin = Vector2i(4, 19)
	controller.active_cell_indices = [0, 1, 2, 3]
	character.position = Vector2(5.5 * MainCharacterController.CELL_SIZE, 912.0)
	for y: int in range(16, MainBoardModel.HEIGHT):
		for x: int in range(2, 9):
			var blocking_cell := Vector2i(x, y)
			if blocking_cell not in controller.active_board_cells():
				controller.board.cells[y][x] = MainTetrominoData.Type.J
	character.rotation_cooldown_remaining = 0.0
	character._attempt_rotation_kick()
	_expect(
		is_equal_approx(character.rotation_cooldown_remaining, character.current_rotation_cooldown()),
		"회전 공간과 금지 셀 때문에 실패한 회전킥도 성공과 동일한 100% 쿨다운을 적용한다."
	)
	controller.board.reset()
	controller.active_type = MainTetrominoData.Type.T
	controller.active_rotation = 0
	controller.active_origin = Vector2i(4, 10)
	controller.active_cell_indices = [0, 1, 2, 3]
	var rotation_origin: Vector2i = controller.active_origin
	var clockwise_in_place: bool = controller.try_rotate(1, [], true)
	controller.active_rotation = 0
	controller.active_origin = rotation_origin
	var counterclockwise_in_place: bool = controller.try_rotate(-1, [], true)
	_expect(
		clockwise_in_place
			and counterclockwise_in_place
			and controller.active_origin == rotation_origin,
		"위·아래 방향 블록 플립은 SRS kick 없이 같은 원점에서 회전한다."
	)

	character._sfx_player.stop()
	character._sfx_cue_player.stop()
	character._meditation_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	scene.free()
	await process_frame


func _test_fixed_support_grab() -> void:
	var scene: MainGameView = GAME_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	await process_frame

	var controller: MainGameController = scene.get_node("GameController")
	var board_physics: MainBoardPhysics = scene.get_node("BoardPhysics")
	var character: MainCharacterController = scene.get_node("BoardPhysics/Character")
	controller.board.reset()
	for x: int in range(MainBoardModel.WIDTH):
		controller.board.cells[18][x] = MainTetrominoData.Type.J
	controller.board.cells[16][5] = MainTetrominoData.Type.J
	board_physics._sync_from_model()
	await physics_frame

	character.position = Vector2(216.0, 721.0)
	character._exit_hang()
	character.facing = 1
	character.stamina = MainCharacterController.MAX_STAMINA
	character._hang_regrab_remaining = 0.0
	character.right_ray.force_raycast_update()
	Input.action_release(&"character_grab")
	Input.action_press(&"character_grab")
	_expect(
		character._has_fixed_support_underfoot(),
		"고정 지지면 위 C-grab 회귀 테스트가 발밑 지지를 확인한다."
	)
	_expect(
		character.right_ray.is_colliding(),
		"고정 지지면 위 C-grab 회귀 테스트가 옆 벽을 감지한다."
	)
	character._try_start_hang()
	_expect(
		not character.is_hanging
			and character._hang_body == null,
		"고정 지지면 위 C-grab은 매달림 상태로 전환되지 않는다."
	)
	Input.action_release(&"character_grab")
	character._sfx_player.stop()
	character._sfx_cue_player.stop()
	character._meditation_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	scene.free()
	await process_frame


func _test_standing_wall_visual_alignment() -> void:
	var scene: MainGameView = GAME_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	await process_frame

	var controller: MainGameController = scene.get_node("GameController")
	var board_physics: MainBoardPhysics = scene.get_node("BoardPhysics")
	var character: MainCharacterController = scene.get_node("BoardPhysics/Character")
	controller.board.reset()
	controller.board.cells[20][5] = MainTetrominoData.Type.J
	controller.board.cells[21][5] = MainTetrominoData.Type.J
	board_physics._sync_from_model()
	await physics_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED

	character.position = Vector2(219.0, 912.0)
	character.velocity = Vector2.ZERO
	character.is_hanging = false
	character._animation_state = ANIMATION_DATA.IDLE
	var right_alignment_is_exact: bool = character.is_on_floor()
	for profile_id: String in CHARACTER_DATA.CHARACTER_ORDER:
		character.set_character_id(profile_id)
		for frame_index: int in range(ANIMATION_DATA.REGIONS[ANIMATION_DATA.IDLE].size()):
			character._animation_time = (
				float(frame_index) * float(ANIMATION_DATA.FRAME_DURATIONS[ANIMATION_DATA.IDLE])
				+ 0.001
			)
			for flipped: bool in [false, true]:
				character.sprite.flip_h = flipped
				character._apply_animation_frame()
				var bounds: Rect2 = character._frame_alpha_bounds(character.sprite.region_rect)
				var edge_x: float = character.sprite.position.x + (
					ANIMATION_DATA.FRAME_SIZE - bounds.position.x
					if flipped
					else bounds.end.x
				) - ANIMATION_DATA.FRAME_SIZE * 0.5
				right_alignment_is_exact = (
					right_alignment_is_exact
					and is_equal_approx(
						edge_x,
						MainCharacterController.CHARACTER_COLLIDER_WIDTH * 0.5
							+ MainCharacterController.BLOCK_VISUAL_INSET
					)
				)
	_expect(
		right_alignment_is_exact,
		"Every idle frame and facing aligns its rightmost opaque pixel with a touching block wall."
	)

	character.position.x = 309.0
	var left_alignment_is_exact: bool = true
	for flipped: bool in [false, true]:
		character.sprite.flip_h = flipped
		character._animation_time = 0.001
		character._apply_animation_frame()
		var bounds: Rect2 = character._frame_alpha_bounds(character.sprite.region_rect)
		var edge_x: float = character.sprite.position.x + (
			ANIMATION_DATA.FRAME_SIZE - bounds.end.x
			if flipped
			else bounds.position.x
		) - ANIMATION_DATA.FRAME_SIZE * 0.5
		left_alignment_is_exact = left_alignment_is_exact and is_equal_approx(
			edge_x,
			-MainCharacterController.CHARACTER_COLLIDER_WIDTH * 0.5
				- MainCharacterController.BLOCK_VISUAL_INSET
		)
	_expect(
		left_alignment_is_exact,
		"Standing art also aligns its leftmost opaque pixel when the wall is behind or ahead."
	)

	character.position.x = 216.0
	character.sprite.flip_h = false
	character._animation_time = 0.001
	character._apply_animation_frame()
	_expect(
		character._standing_wall_contact_direction() == 0
			and is_zero_approx(character.sprite.position.x),
		"A nearby wall outside the collider contact tolerance does not pull the standing sprite."
	)

	character._sfx_player.stop()
	character._sfx_cue_player.stop()
	character._meditation_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	scene.free()
	await process_frame


func _test_hang_face_bounds() -> void:
	var scene: MainGameView = GAME_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	await process_frame

	var controller: MainGameController = scene.get_node("GameController")
	var board_physics: MainBoardPhysics = scene.get_node("BoardPhysics")
	var character: MainCharacterController = scene.get_node("BoardPhysics/Character")
	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8)],
		Vector2(216.0, 344.0)
	)
	var grab_y: float = character.global_position.y
	character._try_start_hang()
	_expect(
		character.is_hanging
			and character._hang_body != null
			and character.global_position.y == grab_y
			and is_equal_approx(
				character.global_position.x
					+ MainCharacterController.CHARACTER_COLLIDER_WIDTH * 0.5,
				character._hang_face_global_x
			),
		"노출된 옆면 가까이의 C-grab은 세로 위치를 바꾸지 않고 성공한다."
	)
	character._exit_hang()
	var every_back_facing_grab_rejected: bool = true
	for profile_id: String in MainCharacterData.CHARACTER_ORDER:
		character.set_character_id(profile_id)
		character.position = Vector2(216.0, 344.0)
		character.facing = -1
		character.sprite.flip_h = true
		character._try_start_hang()
		every_back_facing_grab_rejected = (
			every_back_facing_grab_rejected
			and not character.is_hanging
			and character.facing == -1
		)
		character._exit_hang()
	character.set_character_id("normal")
	_expect(
		every_back_facing_grab_rejected,
		"All eight characters reject a wall touching their back and keep their facing direction."
	)
	# Restore the original front-facing hang before exercising surface removal.
	character.position = Vector2(216.0, 344.0)
	character.facing = 1
	character.sprite.flip_h = false
	character._try_start_hang()
	controller.board.reset()
	board_physics._sync_from_model()
	await physics_frame
	Input.action_press(&"character_grab")
	character._handle_hanging(0.016)
	Input.action_release(&"character_grab")
	_expect(
		not character.is_hanging and character._hang_body == null,
		"매달린 고정 블록 면이 사라지면 입력이 없어도 즉시 매달림을 해제한다."
	)
	character.position = Vector2(24.0, 344.0)
	character.facing = -1
	character.left_ray.force_raycast_update()
	character._try_start_hang()
	var visible_center_range: Vector2 = character._visible_board_character_center_range()
	_expect(
		character.is_hanging
			and character._hang_body == board_physics.get_node("Boundaries")
			and is_equal_approx(
				character.global_position.x
					- MainCharacterController.CHARACTER_COLLIDER_WIDTH * 0.5,
				character._hang_face_global_x
			)
			and is_equal_approx(character._hang_top_global_y, visible_center_range.x)
			and is_equal_approx(character._hang_bottom_global_y, visible_center_range.y)
			and character._hang_top_global_y <= character.global_position.y
			and character.global_position.y <= character._hang_bottom_global_y,
		"보드 경계벽 매달림은 보이는 보드 내부의 캐릭터 중심 범위만 사용한다."
	)
	character._exit_hang()
	character.position = Vector2(24.0, 0.0)
	character.facing = -1
	character.left_ray.force_raycast_update()
	character._try_start_hang()
	_expect(
		not character.is_hanging and character._hang_body == null,
		"HUD 쪽으로 연장된 숨은 경계벽에서는 매달리기를 시작하지 않는다."
	)

	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8)],
		Vector2(195.0, 344.0)
	)
	character._try_start_hang()
	_expect(
		not character.is_hanging,
		"옆면에서 수평으로 먼 위치의 C-grab은 성공하지 않는다."
	)

	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8)],
		Vector2(216.0, 382.0)
	)
	character._try_start_hang()
	_expect(
		not character.is_hanging,
		"몸체가 세로로 겹쳐도 옆면 밖의 ray 높이에서는 C-grab하지 않는다."
	)

	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8)],
		Vector2(216.0, 280.0)
	)
	character._try_start_hang()
	_expect(
		not character.is_hanging,
		"블록보다 40px 위 공중에서는 C-grab하지 않는다."
	)

	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8), Vector2i(5, 9)],
		Vector2(216.0, 392.0)
	)
	character._try_start_hang()
	_expect(
		character.is_hanging
			and is_equal_approx(character._hang_top_global_y, 440.0)
			and is_equal_approx(character._hang_bottom_global_y, 536.0),
		"세로로 이어진 노출 옆면은 손 위치 기준 매달림 범위를 공유한다."
	)
	var upper_bound: float = character._hang_top_global_y
	character.global_position.y = upper_bound + 1.0
	var up_event: InputEventKey = InputEventKey.new()
	up_event.keycode = KEY_UP
	up_event.pressed = true
	Input.parse_input_event(up_event)
	character._move_while_hanging()
	var up_release_event: InputEventKey = InputEventKey.new()
	up_release_event.keycode = KEY_UP
	Input.parse_input_event(up_release_event)
	_expect(
		character.global_position.y >= upper_bound,
		"매달린 중 상승 입력은 저장된 상단 범위를 넘지 않는다."
	)
	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8), Vector2i(5, 9)],
		Vector2(216.0, 392.0)
	)
	character._try_start_hang()
	var lower_bound: float = character._hang_bottom_global_y
	character.global_position.y = lower_bound - 1.0
	Input.action_press(&"character_meditate")
	character._move_while_hanging()
	Input.action_release(&"character_meditate")
	_expect(
		character.global_position.y <= lower_bound,
		"매달린 중 하강 입력은 저장된 하단 범위를 넘지 않는다."
	)
	var active_piece: AnimatableBody2D = board_physics.active_body
	var bounds_top: float = 368.0
	var bounds_bottom: float = 464.0
	var follow_start_position: Vector2 = character.global_position
	character._hang_top_global_y = bounds_top
	character._hang_bottom_global_y = bounds_bottom
	character._hang_body = active_piece
	character._hang_last_global_position = active_piece.global_position - Vector2(
		0.0,
		MainLayout.CELL_SIZE
	)
	character._follow_hang_body()
	_expect(
		not character.is_hanging
			and character.global_position.is_equal_approx(follow_start_position),
		"하강 활성 피스가 캐릭터를 고정 블록 사이로 끌고 가려 하면 매달림을 해제한다."
	)
	controller.board.reset()
	character.global_position.y = (bounds_top + bounds_bottom) * 0.5
	character.is_hanging = true
	character._hang_top_global_y = bounds_top
	character._hang_bottom_global_y = bounds_bottom
	character._hang_body = active_piece
	character._hang_last_global_position = active_piece.global_position - Vector2(
		0.0,
		MainLayout.CELL_SIZE
	)
	character._follow_hang_body()
	_expect(
		is_equal_approx(character._hang_top_global_y, bounds_top + MainLayout.CELL_SIZE)
			and is_equal_approx(character._hang_bottom_global_y, bounds_bottom + MainLayout.CELL_SIZE),
		"고정 지형이 없으면 활성 피스의 수직 이동을 매달림 범위와 함께 따라간다."
	)
	Input.action_release(&"character_meditate")
	character.is_hanging = true
	character._move_while_hanging()
	_expect(
		character.is_hanging,
		"입력 없이 내려오는 활성 피스를 잡고 있으면 ray 갱신 frame에도 매달림을 유지한다."
	)
	character._exit_hang()
	_expect(
		is_zero_approx(character._hang_top_global_y)
			and is_zero_approx(character._hang_bottom_global_y),
		"매달림 종료는 저장된 매달림 범위를 비운다."
	)
	character._hang_top_global_y = 1.0
	character._hang_bottom_global_y = 2.0
	character._reset_character()
	_expect(
		is_zero_approx(character._hang_top_global_y)
			and is_zero_approx(character._hang_bottom_global_y),
		"캐릭터 reset은 저장된 매달림 범위를 비운다."
	)

	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8), Vector2i(5, 10)],
		Vector2(216.0, 440.0)
	)
	character._try_start_hang()
	_expect(
		character.is_hanging
			and is_equal_approx(character._hang_top_global_y, 536.0)
			and is_equal_approx(character._hang_bottom_global_y, 584.0),
		"세로 틈이 있는 옆면은 틈을 건너 범위를 확장하지 않는다."
	)
	character._exit_hang()

	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8), Vector2i(6, 9)],
		Vector2(216.0, 344.0)
	)
	character._try_start_hang()
	_expect(
		character.is_hanging
			and is_equal_approx(character._hang_top_global_y, 440.0)
			and is_equal_approx(character._hang_bottom_global_y, 488.0),
		"수평으로 꺾인 step은 다른 face를 같은 범위로 합치지 않는다."
	)
	character._exit_hang()

	character._sfx_player.stop()
	character._sfx_cue_player.stop()
	character._meditation_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	scene.free()
	await process_frame


func _prepare_hang_fixture(
	controller: MainGameController,
	board_physics: MainBoardPhysics,
	character: MainCharacterController,
	cells: Array[Vector2i],
	character_position: Vector2
) -> void:
	character._exit_hang()
	controller.board.reset()
	for cell: Vector2i in cells:
		controller.board.cells[cell.y][cell.x] = MainTetrominoData.Type.J
	controller.state = MainGameController.GameState.PLAYING
	board_physics._sync_from_model()
	await physics_frame
	character.position = character_position
	character.velocity = Vector2.ZERO
	character.facing = 1
	character.stamina = MainCharacterController.MAX_STAMINA
	character._hang_regrab_remaining = 0.0


## 상황: 여러 펀치 사례가 동일한 보드·캐릭터 초기조건을 재사용할 때 호출된다.
## 순서: 빈 보드/활성 T 설정 → piece timer reset → 캐릭터 위치·방향·stamina·private flag 초기화.
## 결과: 이전 사례의 cooldown/예약 판정이 다음 사례에 섞이지 않는 test fixture가 된다.
func _test_character_frame_normalization(
	controller: MainGameController,
	character: MainCharacterController
) -> void:
	var states: Array[String] = [
		ANIMATION_DATA.IDLE,
		ANIMATION_DATA.ATTACK,
		ANIMATION_DATA.HANG,
		ANIMATION_DATA.JUMP,
		ANIMATION_DATA.ROTATION_KICK,
		ANIMATION_DATA.SPECIAL,
	]
	var visible_bounds_are_stable: bool = true
	var fixed_geometry_is_stable: bool = true
	var all_required_frames_are_opaque: bool = true
	var collision_is_frame_independent: bool = true
	var transparent_padding_is_excluded: bool = true
	var hang_animation_cycles: bool = true
	var still_hang_holds_first_frame: bool = true
	var downward_hang_reverses: bool = true
	var hang_blink_keeps_frame: bool = true
	var hang_art_meets_collider_wall: bool = true
	var stationary_idle_is_stable: bool = true
	var moving_idle_still_cycles: bool = true
	controller.active_type = MainTetrominoData.Type.O
	controller.active_rotation = 0
	controller.active_cell_indices = [0, 1, 2, 3]
	character.position = Vector2(240.0, 912.0)
	character.sprite.flip_h = false
	character.sprite.rotation = 0.0
	var crush_sensor_rect: Rect2 = character._crush_sensor_rect()

	for profile_id: String in CHARACTER_DATA.CHARACTER_ORDER:
		character.set_character_id(profile_id)
		character.is_hanging = false
		character._spin_remaining = 0.0
		character._special_animation_remaining = 0.0
		character._attack_animation_remaining = 0.0
		character._post_spin_animation_seeded = false
		character._animation_state = ANIMATION_DATA.IDLE
		character._animation_time = 0.0
		character.velocity = Vector2.ZERO
		character._advance_character_animation(
			float(ANIMATION_DATA.FRAME_DURATIONS[ANIMATION_DATA.IDLE]) + 0.001
		)
		stationary_idle_is_stable = stationary_idle_is_stable and (
			character.sprite.region_rect == ANIMATION_DATA.REGIONS[ANIMATION_DATA.IDLE][0]
		)
		character.velocity.x = 20.0
		character._advance_character_animation(
			float(ANIMATION_DATA.FRAME_DURATIONS[ANIMATION_DATA.IDLE]) + 0.001
		)
		moving_idle_still_cycles = moving_idle_still_cycles and (
			character.sprite.region_rect == ANIMATION_DATA.REGIONS[ANIMATION_DATA.IDLE][1]
		)
		character.velocity = Vector2.ZERO
		character._animation_time = 0.0
		character._apply_animation_frame()
		var expected_visible_rect: Rect2 = _sprite_visible_rect(character)
		var reference_scale: Vector2 = character.sprite.scale
		var reference_position: Vector2 = character.sprite.position
		var reference_region: Rect2 = character.sprite.region_rect
		var reference_bounds: Rect2 = character._frame_alpha_bounds(reference_region)
		transparent_padding_is_excluded = (
			transparent_padding_is_excluded
			and reference_bounds.size.x < reference_region.size.x
			and reference_bounds.size.y < reference_region.size.y
			and (
				ANIMATION_DATA.uses_fixed_geometry(profile_id)
				or is_equal_approx(
					expected_visible_rect.size.y,
					ANIMATION_DATA.visible_height_for(ANIMATION_DATA.IDLE, profile_id)
				)
			)
		)
		for state: String in states:
			character.is_hanging = false
			var frames: Array = ANIMATION_DATA.regions_for(state, profile_id)
			for frame_index: int in range(frames.size()):
				character._animation_state = state
				character._animation_time = (
					float(frame_index) * float(ANIMATION_DATA.FRAME_DURATIONS[state])
					+ 0.001
				)
				character._apply_animation_frame()
				var visible_rect: Rect2 = _sprite_visible_rect(character)
				var frame_bounds: Rect2 = character._frame_alpha_bounds(character.sprite.region_rect)
				if state == ANIMATION_DATA.HANG:
					hang_art_meets_collider_wall = (
						hang_art_meets_collider_wall
						and absf(
							frame_bounds.end.x - ANIMATION_DATA.FRAME_SIZE * 0.5
							- (MainCharacterController.CHARACTER_COLLIDER_WIDTH * 0.5 + 2.0)
						) <= HANG_WALL_VISUAL_TOLERANCE
					)
				all_required_frames_are_opaque = (
					all_required_frames_are_opaque and frame_bounds.has_area()
				)
				if ANIMATION_DATA.uses_fixed_geometry(profile_id):
					if (
						not character.sprite.scale.is_equal_approx(reference_scale)
						or not character.sprite.position.is_equal_approx(reference_position)
						or not character.sprite.scale.is_equal_approx(Vector2.ONE)
					):
						fixed_geometry_is_stable = false
				elif (
					not is_equal_approx(
						visible_rect.size.y,
						ANIMATION_DATA.visible_height_for(state, profile_id)
					)
					or not is_equal_approx(
						visible_rect.get_center().x,
						expected_visible_rect.get_center().x
					)
					or not is_equal_approx(
						visible_rect.end.y,
						expected_visible_rect.end.y
					)
					or not is_equal_approx(character.sprite.scale.x, character.sprite.scale.y)
				):
					visible_bounds_are_stable = false
				if (
					not character._active_piece_overlaps_crush_sensor(
						Vector2i(3, 19),
						crush_sensor_rect
					)
					or character._active_piece_overlaps_crush_sensor(
						Vector2i(7, 1),
						crush_sensor_rect
					)
				):
					collision_is_frame_independent = false
		character.is_hanging = true
		character._hang_animation_direction = 0.0
		character._animation_state = ANIMATION_DATA.IDLE
		character._animation_time = 0.0
		character._advance_character_animation(0.0)
		var hang_frame: Rect2 = character.sprite.region_rect
		var hang_texture: Texture2D = character.sprite.texture
		var hang_scale: Vector2 = character.sprite.scale
		var hang_position: Vector2 = character.sprite.position
		character._update_sprite_modulation()
		hang_blink_keeps_frame = hang_blink_keeps_frame and (
			character.sprite.region_rect == hang_frame
			and character.sprite.texture == hang_texture
			and character.sprite.scale.is_equal_approx(hang_scale)
			and character.sprite.position.is_equal_approx(hang_position)
		)
		character._advance_character_animation(float(ANIMATION_DATA.FRAME_DURATIONS[ANIMATION_DATA.HANG]) + 0.001)
		still_hang_holds_first_frame = still_hang_holds_first_frame and (
			character.sprite.region_rect == ANIMATION_DATA.REGIONS[ANIMATION_DATA.HANG][0]
		)
		character._hang_animation_direction = -1.0
		character._advance_character_animation(
			float(ANIMATION_DATA.FRAME_DURATIONS[ANIMATION_DATA.HANG]) + 0.001
		)
		hang_animation_cycles = hang_animation_cycles and (
			character.sprite.region_rect == ANIMATION_DATA.REGIONS[ANIMATION_DATA.HANG][1]
		)
		character._animation_time = 0.0
		character._hang_animation_direction = 1.0
		character._advance_character_animation(0.001)
		var profile_hang_frames: Array = ANIMATION_DATA.regions_for(
			ANIMATION_DATA.HANG,
			profile_id
		)
		downward_hang_reverses = downward_hang_reverses and (
			character.sprite.region_rect == profile_hang_frames[profile_hang_frames.size() - 1]
		)

	character.is_hanging = false
	_expect(
		visible_bounds_are_stable,
		"모든 캐릭터는 모션이 바뀌어도 실제 실루엣 크기와 기준 위치를 유지한다."
	)
	_expect(
		fixed_geometry_is_stable and all_required_frames_are_opaque,
		"All eight skins use one fixed scale/offset and every required atlas frame is opaque."
	)
	_expect(
		hang_animation_cycles
			and still_hang_holds_first_frame
			and downward_hang_reverses
			and hang_blink_keeps_frame,
		"Hang holds while still, cycles forward while climbing, and reverses while descending."
	)
	_expect(
		stationary_idle_is_stable and moving_idle_still_cycles,
		"Stationary characters hold idle frame zero; movement still cycles the shared idle/walk frames."
	)
	_expect(
		hang_art_meets_collider_wall,
		"All eight skins bridge the block sprite's two-pixel visual inset without changing collision."
	)
	_expect(
		transparent_padding_is_excluded,
		"모든 캐릭터의 기준 크기는 128px 투명 여백을 제외한 실제 픽셀로 계산한다."
	)
	_expect(
		collision_is_frame_independent,
		"압착 판정은 캐릭터 sprite의 투명 공백과 animation frame에 영향받지 않는다."
	)
	var jump_speed: float = absf(character.current_jump_velocity())
	_expect(
		character._jump_animation_frame_for_velocity(-jump_speed) == 0
			and character._jump_animation_frame_for_velocity(-jump_speed * 0.5) == 1
			and character._jump_animation_frame_for_velocity(0.0) == 3
			and character._jump_animation_frame_for_velocity(100.0) == 4
			and character._jump_animation_frame_for_velocity(350.0) == 5
			and character._jump_animation_frame_for_velocity(600.0) == 6
			and character._jump_animation_frame_for_velocity(900.0) == 7,
		"점프·낙하 frame은 경과시간이 아니라 실제 수직 속도로 상승·정점·하강을 선택한다."
	)
	character.set_character_id(ANIMATION_DATA.DEFAULT_CHARACTER_ID)
	character._animation_state = ANIMATION_DATA.IDLE
	character._animation_time = 0.0
	character._apply_animation_frame()


func _sprite_visible_rect(character: MainCharacterController) -> Rect2:
	var frame_region: Rect2 = character.sprite.region_rect
	var frame_bounds: Rect2 = character._frame_alpha_bounds(frame_region)
	var source_center: Vector2 = frame_region.size * 0.5
	var top_left: Vector2 = character.sprite.position + (
		frame_bounds.position - source_center
	) * character.sprite.scale
	return Rect2(top_left, frame_bounds.size * character.sprite.scale)


func _test_binding_overlay_alignment(
	scene: MainGameView,
	character: MainCharacterController
) -> void:
	var overlay_is_aligned: bool = true
	var binding_sprite: Sprite2D = scene._binding_sprite
	var visible_bind_region: Rect2 = ANIMATION_DATA.opaque_region_for(
		MainGameView.BIND_TEXTURE,
		MainGameView.BIND_SOURCE_REGION
	)
	for profile_id: String in CHARACTER_DATA.CHARACTER_ORDER:
		character.set_character_id(profile_id)
		scene._sync_binding_overlay_transform()
		var expected_height: float = (
			ANIMATION_DATA.visible_height_for(ANIMATION_DATA.IDLE, profile_id)
			+ MainGameView.BIND_HEIGHT_MARGIN
		)
		overlay_is_aligned = (
			overlay_is_aligned
			and binding_sprite.region_rect == visible_bind_region
			and binding_sprite.position.is_equal_approx(character.sprite.position)
			and is_equal_approx(binding_sprite.scale.x, binding_sprite.scale.y)
			and is_equal_approx(
				binding_sprite.region_rect.size.y * binding_sprite.scale.y,
				expected_height
			)
		)
	_expect(
		overlay_is_aligned,
		"stage-system 덩쿨 속박은 모든 캐릭터의 실제 표시 위치·높이에 균일 비율로 맞는다."
	)
	_expect(
		binding_sprite.get_parent() == character and binding_sprite.get_child_count() == 0,
		"덩쿨 속박의 투명 영역은 시각 overlay일 뿐 캐릭터 판정에 추가되지 않는다."
	)
	character.set_character_id(ANIMATION_DATA.DEFAULT_CHARACTER_ID)

func _prepare_punch(
	controller: MainGameController,
	character: MainCharacterController,
	origin: Vector2i,
	character_position: Vector2
) -> void:
	controller.board.reset()
	controller.state = MainGameController.GameState.PLAYING
	controller.active_type = MainTetrominoData.Type.T
	controller.active_rotation = 0
	controller.active_origin = origin
	controller._reset_piece_timers()
	character.position = character_position
	character.velocity = Vector2.ZERO
	character.facing = 1
	character.stamina = MainCharacterController.MAX_STAMINA
	character._attack_cooldown_remaining = 0.0
	character._attack_animation_remaining = 0.0
	character._pending_punch_stage = 0
	character._pending_punch_hit_remaining = 0.0
