extends SceneTree

const INPUT_ACTIONS: Script = preload("res://scripts/input_actions.gd")
const GAME_CONTROLLER: Script = preload("res://scripts/game_controller.gd")
const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _checks: int = 0
var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	INPUT_ACTIONS.ensure_defaults()
	_expect(
		INPUT_ACTIONS.get_default_keys(&"character_punch") == [KEY_X],
		"일반 공격 기본 키는 X다."
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
		is_equal_approx(MainGameController.LOCK_DELAY_SECONDS, 0.5)
			and is_equal_approx(MainGameController.GRAVITY_INTERVAL_SECONDS, 7.0 / 15.0)
			and MainGameController.MEDITATION_TIME_SCALE == 2.0,
		"기본 낙하·고정 시간은 고정값이며 명상 중 낙하만 2배다."
	)
	_expect(
		MainGameController.stage_stars_for_lines(0) == 0
			and MainGameController.stage_stars_for_lines(1) == 1
			and MainGameController.stage_stars_for_lines(2) == 2
			and MainGameController.stage_stars_for_lines(3) == 3,
		"스테이지 줄 클리어 수는 1·2·3줄에서 0·1·2·3별 기준을 적용한다."
	)
	var controller: MainGameController = GAME_CONTROLLER.new()
	controller.reset_game(20260801)
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
	var attack_origin: Vector2i = controller.active_origin
	_expect(
		controller.push_active_piece(1, 1)
			and controller.active_origin == attack_origin + Vector2i.RIGHT,
		"일반 공격용 피스 밀기는 비어 있는 경로에서 한 칸 이동한다."
	)
	_expect(
		controller.has_method("_physics_process")
			and not controller.has_method("_process"),
		"게임 진행은 현재 physics process 경로를 사용한다."
	)
	var stage_clear_count: Array[int] = [0]
	var stage_cleared_lines: Array[int] = [-1]
	controller.stage_cleared.connect(func(cleared_lines: int) -> void:
		stage_clear_count[0] += 1
		stage_cleared_lines[0] = cleared_lines
	)
	controller.reset_game(20260801)
	controller._advance_stage_timer(MainGameController.SURVIVAL_TIME_SECONDS)
	_expect(
		stage_clear_count[0] == 0
			and controller.state == MainGameController.GameState.GAME_OVER,
		"일반 스테이지에서 한 줄도 지우지 못하면 클리어가 아니라 게임오버다."
	)
	controller.reset_game(20260801)
	controller.total_lines = 3
	controller._advance_stage_timer(MainGameController.SURVIVAL_TIME_SECONDS)
	_expect(
		stage_clear_count[0] == 1
			and stage_cleared_lines[0] == 3
			and controller.stage_time_remaining == 0.0
			and controller.state == MainGameController.GameState.PAUSED,
		"일반 스테이지는 누적 줄 수와 함께 90초 생존 시 클리어된다."
	)
	controller.stage_number = 5
	controller.reset_game(20260801)
	controller._advance_stage_timer(MainGameController.SURVIVAL_TIME_SECONDS)
	_expect(
		stage_clear_count[0] == 1
			and controller.stage_time_remaining == MainGameController.SURVIVAL_TIME_SECONDS
			and controller.state == MainGameController.GameState.PLAYING,
		"보스 스테이지에는 생존 타이머 클리어가 없다."
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
		FileAccess.file_exists("res://assets/sprites/thron_sprite.png")
			and MainGameView.THORN_SOURCE_REGION.size == Vector2(128.0, 104.0),
		"가시 스프라이트 시트와 48px overlay source 영역을 사용한다."
	)
	_expect(
		FileAccess.file_exists("res://assets/sprites/bind_sprite.png")
			and MainGameView.BIND_SOURCE_REGION.size == Vector2(277.0, 364.0),
		"속박 스프라이트 시트와 source 영역을 사용한다."
	)
	await _test_top_hud()
	await _test_fixed_support_grab()
	await _test_hang_face_bounds()
	await _test_stage_gimmicks()
	await _test_stage5_boss()
	if _failures == 0:
		print("성공: 메인 게임 테스트 %d개 통과" % _checks)
	else:
		push_error("실패: 최종 방향 통합 테스트 %d/%d개 실패" % [_failures, _checks])
	quit(_failures)


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  [통과] %s" % description)
	else:
		_failures += 1
		push_error("  [실패] %s" % description)


func _test_top_hud() -> void:
	var scene: MainGameView = GAME_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	await process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var lines_label: Label = scene.find_child("LinesLabel", true, false) as Label
	var lives_label: Label = scene.find_child("LivesLabel", true, false) as Label
	var next_label: Label = scene.find_child("NextLabel", true, false) as Label
	var timer_label: Label = scene.find_child("TimerLabel", true, false) as Label
	_expect(
		lines_label != null
			and lines_label.text.contains("파괴")
			and lives_label != null
			and lives_label.text == "목숨: 3"
			and next_label != null
			and timer_label != null
			and timer_label.text == "01:30"
			and timer_label.position.y < MainLayout.BOARD_ORIGIN.y
			and next_label.position.x > MainLayout.BOARD_ORIGIN.x + MainLayout.BOARD_SIZE.x * 0.5
			and next_label.position.y < MainLayout.BOARD_ORIGIN.y,
		"보드 폭에 맞춘 상단 HUD에 타이머·파괴 줄·다음 블록 카드를 표시한다."
	)
	_expect(
		scene.find_child("StatsLabel", true, false) == null
			and scene.find_child("StaminaLabel", true, false) == null
			and scene.find_child("PunchLabel", true, false) == null
			and scene.find_child("RotationKickLabel", true, false) == null,
		"점수·스태미나·펀치·회전 킥 우측 HUD는 없다."
	)

	var character: MainCharacterController = scene.get_node("BoardPhysics/Character")
	var binding_sprite: Sprite2D = scene.get_node_or_null("BoardPhysics/Character/BindingSprite") as Sprite2D
	_expect(
		binding_sprite != null
			and binding_sprite.z_index > character.sprite.z_index
			and binding_sprite.region_enabled
			and binding_sprite.region_rect == MainGameView.BIND_SOURCE_REGION,
		"속박 덩굴은 캐릭터 위에 표시되는 overlay Sprite2D를 사용한다."
	)
	character.stamina = 0.0
	character._update_sprite_modulation()
	_expect(
		character.sprite.modulate == Color(1.0, 0.18, 0.18, 1.0),
		"스태미나가 바닥나면 캐릭터가 완전히 붉어진다."
	)
	character._attempt_punch()
	character._advance_character_animation(0.0)
	_expect(
		character._animation_state == "attack"
			and character.sprite.texture == MainCharacterAnimationData.ATTACK_TEXTURE,
		"일반 공격은 공격 스프라이트를 표시한다."
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
	controller.board.cells[17][5] = MainTetrominoData.Type.J
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
		Vector2(216.0, 312.0)
	)
	var grab_y: float = character.global_position.y
	character._try_start_hang()
	_expect(
		character.is_hanging
			and character._hang_body != null
			and character.global_position.y == grab_y,
		"노출된 옆면 가까이의 C-grab은 세로 위치를 바꾸지 않고 성공한다."
	)
	character._exit_hang()
	controller.board.reset()
	board_physics._sync_from_model()
	await physics_frame
	character.position = Vector2(24.0, 312.0)
	character.facing = -1
	character.left_ray.force_raycast_update()
	character._try_start_hang()
	_expect(
		character.is_hanging
			and character._hang_body == board_physics.get_node("Boundaries")
			and character._hang_top_global_y <= character.global_position.y
			and character.global_position.y <= character._hang_bottom_global_y,
		"보드 경계벽은 바닥 collision과 같은 body여도 잡을 수 있다."
	)
	character._exit_hang()

	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8)],
		Vector2(195.0, 312.0)
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
		Vector2(216.0, 350.0)
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
		[Vector2i(5, 8), Vector2i(5, 9)],
		Vector2(216.0, 360.0)
	)
	character._try_start_hang()
	_expect(
		character.is_hanging
			and is_equal_approx(character._hang_top_global_y, board_physics.global_position.y + 320.0)
			and is_equal_approx(character._hang_bottom_global_y, board_physics.global_position.y + 416.0),
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
		Vector2(216.0, 360.0)
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
	var active_piece: StaticBody2D = board_physics.active_body
	var bounds_top: float = 368.0
	var bounds_bottom: float = 464.0
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
		"활성 피스의 수직 이동은 저장된 매달림 범위를 함께 이동시킨다."
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
		Vector2(216.0, 408.0)
	)
	character._try_start_hang()
	_expect(
		character.is_hanging
			and is_equal_approx(character._hang_top_global_y, board_physics.global_position.y + 416.0)
			and is_equal_approx(character._hang_bottom_global_y, board_physics.global_position.y + 464.0),
		"세로 틈이 있는 옆면은 틈을 건너 범위를 확장하지 않는다."
	)
	character._exit_hang()

	await _prepare_hang_fixture(
		controller,
		board_physics,
		character,
		[Vector2i(5, 8), Vector2i(6, 9)],
		Vector2(216.0, 312.0)
	)
	character._try_start_hang()
	_expect(
		character.is_hanging
			and is_equal_approx(character._hang_top_global_y, board_physics.global_position.y + 320.0)
			and is_equal_approx(character._hang_bottom_global_y, board_physics.global_position.y + 368.0),
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


func _test_stage_gimmicks() -> void:
	var controller: MainGameController = GAME_CONTROLLER.new()
	controller.stage_number = 1
	controller.reset_game(20260801)
	_expect(
		controller.get_stage_gimmick_config()["thorn_probability"] == 0.0
			and not controller.get_stage_gimmick_config()["binding_enabled"],
		"Stage 1-1은 가시·속박 기믹이 없다."
	)
	controller.stage_number = 2
	controller.reset_game(20260801)
	_expect(
		is_equal_approx(float(controller.get_stage_gimmick_config()["thorn_probability"]), 0.15),
		"Stage 1-2 가시 확률은 15%다."
	)
	controller.active_piece_has_thorns = true
	controller.thorn_visible = true
	controller._advance_stage_gimmicks(1.0)
	_expect(not controller.thorn_visible, "가시 piece는 1초 후 OFF가 된다.")
	controller._advance_stage_gimmicks(1.0)
	_expect(not controller.thorn_visible, "가시 OFF는 1초 경과 후에도 유지된다.")
	controller._advance_stage_gimmicks(1.0)
	_expect(controller.thorn_visible, "가시 OFF는 2초 후 다시 ON이 된다.")
	controller.state = MainGameController.GameState.PAUSED
	var paused_thorn_timer: float = controller.thorn_phase_timer
	controller._advance_stage_gimmicks(1.0)
	_expect(
		is_equal_approx(controller.thorn_phase_timer, paused_thorn_timer)
			and controller.thorn_visible,
		"PAUSED에서는 가시 ON/OFF 시간이 흐르지 않는다."
	)
	controller.state = MainGameController.GameState.PLAYING
	controller.thorn_phase_timer = 1.0
	controller.lock_active_piece()
	_expect(
		is_zero_approx(controller.thorn_phase_timer)
			and controller.thorn_visible == controller.active_piece_has_thorns,
		"active piece lock은 이전 가시 phase를 다음 piece에 전달하지 않는다."
	)
	controller.stage_number = 3
	controller.reset_game(20260801)
	_expect(
		is_equal_approx(float(controller.get_stage_gimmick_config()["thorn_probability"]), 0.25),
		"Stage 1-3 가시 확률은 25%다."
	)
	controller.stage_number = 5
	controller.reset_game(20260801)
	_expect(
		is_equal_approx(float(controller.get_stage_gimmick_config()["thorn_probability"]), 0.33)
			and controller.get_stage_gimmick_config()["binding_enabled"]
			and is_equal_approx(controller.get_binding_duration_seconds(), 3.0),
		"Stage 1-5는 33% 가시와 3초 속박 기믹을 사용한다."
	)
	controller.free()

	var scene: MainGameView = GAME_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var scene_controller: MainGameController = scene.get_node("GameController")
	var character: MainCharacterController = scene.get_node("BoardPhysics/Character")
	scene_controller.stage_number = 2
	scene_controller.reset_game(20260801)
	character.position = Vector2(240.0, 840.0)
	character.lives = MainCharacterController.MAX_LIVES
	character._invulnerability_remaining = 0.0
	character._attack_cooldown_remaining = 0.0
	scene_controller.active_origin = Vector2i(3, 18)
	scene_controller.active_piece_has_thorns = true
	scene_controller.thorn_visible = true
	_expect(
		character._punch_hits_active_piece(),
		"가시 피해 테스트는 기존 active piece punch 대상 판정을 사용한다."
	)
	var thorn_hit_position: Vector2 = character.position
	character._attempt_punch()
	_expect(
		character.lives == MainCharacterController.MAX_LIVES - 1
			and character.position == thorn_hit_position,
		"가시 ON active piece 직접 punch는 현재 위치에서 목숨 1개만 줄인다."
	)
	character._attack_cooldown_remaining = 0.0
	character._invulnerability_remaining = 0.0
	character.lives = MainCharacterController.MAX_LIVES
	scene_controller.thorn_visible = false
	character._attempt_punch()
	_expect(character.lives == MainCharacterController.MAX_LIVES, "가시 OFF punch는 목숨을 줄이지 않는다.")
	character._attack_cooldown_remaining = 0.0
	character._invulnerability_remaining = 0.0
	character.position = Vector2(240.0, 300.0)
	character._attempt_punch()
	_expect(character.lives == MainCharacterController.MAX_LIVES, "대상 없는 X 입력은 목숨을 줄이지 않는다.")
	character.position = Vector2(240.0, 840.0)
	character._finish_physics_frame(0.0)
	_expect(character.lives == MainCharacterController.MAX_LIVES, "가시 active piece와의 단순 접촉은 목숨을 줄이지 않는다.")
	scene_controller.active_type = MainTetrominoData.Type.O
	scene_controller.active_origin = Vector2i(5, 10)
	scene_controller.active_rotation = 0
	scene_controller.active_piece_has_thorns = true
	scene_controller.thorn_visible = true
	character.position = Vector2(240.0, 456.0)
	character.facing = 1
	character.lives = MainCharacterController.MAX_LIVES
	character._invulnerability_remaining = 0.0
	character.rotation_cooldown_remaining = 0.0
	character._spin_remaining = 0.0
	var rotation_hit_position: Vector2 = character.position
	character._attempt_rotation_kick()
	_expect(
		character.lives == MainCharacterController.MAX_LIVES - 1
			and character.position == rotation_hit_position,
		"가시 ON active piece 회전 킥 성공은 현재 위치에서 목숨 1개를 줄인다."
	)
	scene_controller.active_type = MainTetrominoData.Type.O
	scene_controller.active_rotation = 0
	scene_controller.active_origin = Vector2i(6, 10)
	character.position = Vector2(240.0, 456.0)
	character.facing = 1
	character.rotation_cooldown_remaining = 0.0
	character._spin_remaining = 0.0
	_expect(
		not character._punch_hits_active_piece(),
		"S 회전 대상 범위는 펀치와 같은 전방 hitbox를 사용한다."
	)
	character._attempt_rotation_kick()
	_expect(
		scene_controller.active_rotation == 0,
		"펀치 범위 밖의 활성 블록은 S 회전 대상이 아니다."
	)
	scene_controller.active_type = MainTetrominoData.Type.I
	scene_controller.active_rotation = 0
	scene_controller.active_origin = Vector2i(5, 9)
	character.position = Vector2(240.0, 474.0)
	character.facing = 1
	_expect(
		not character._punch_hits_active_piece()
			and character._rotation_hits_active_piece(),
		"S 회전은 펀치 범위 위쪽에 12px의 머리 판정을 추가한다."
	)

	scene_controller.stage_number = 4
	scene_controller.reset_game(20260801)
	character.position = Vector2(240.0, 912.0)
	character.velocity = Vector2.ZERO
	await physics_frame
	var active_body: StaticBody2D = scene.get_node("BoardPhysics/ActivePiece") as StaticBody2D
	_expect(
		is_equal_approx(float(scene_controller.get_stage_gimmick_config()["thorn_probability"]), 0.25)
			and scene_controller.get_stage_gimmick_config()["binding_enabled"]
			and is_equal_approx(scene_controller.get_binding_duration_seconds(), 2.0),
		"Stage 1-4는 25% 가시와 2초 속박 기믹을 함께 사용한다."
	)
	_expect(
		is_equal_approx(scene_controller.binding_probability, MainGameController.BINDING_PROBABILITY),
		"속박 확률은 reset 후 15%에서 시작한다."
	)
	character.is_hanging = true
	character._hang_body = active_body
	_expect(not character.can_receive_binding(), "활성 피스에 매달린 동안에는 속박 대상이 아니다.")
	character._hang_body = scene.get_node("BoardPhysics/LockedBlocks")
	_expect(character.can_receive_binding(), "고정 블록에 매달린 동안에는 속박 대상이다.")
	character._hang_body = active_body
	scene_controller._gimmick_roll_overrides.append(true)
	scene_controller._advance_stage_gimmicks(10.0)
	_expect(
		scene_controller.binding_pending and not character.is_bound,
		"활성 피스 접촉 중 속박 성공은 즉시 속박하지 않는다."
	)
	character._exit_hang()
	scene_controller.reset_game(20260801)
	character.position = Vector2(240.0, 912.0)
	character.velocity = Vector2.ZERO
	await physics_frame
	scene_controller._advance_stage_gimmicks(9.9)
	_expect(
		scene_controller.binding_check_timer < MainGameController.BINDING_CHECK_INTERVAL_SECONDS
			and not scene_controller.binding_pending
			and not character.is_bound,
		"Stage 1-4 속박 판정은 10초 전에는 발생하지 않는다."
	)
	scene_controller._gimmick_roll_overrides.append(false)
	scene_controller._advance_stage_gimmicks(0.1)
	_expect(
		not character.is_bound
			and is_equal_approx(scene_controller.binding_probability, 0.20),
		"속박 판정 실패 후 다음 확률은 5%p 증가한다."
	)
	scene_controller._gimmick_roll_overrides.append(false)
	scene_controller._advance_stage_gimmicks(10.0)
	_expect(
		is_equal_approx(scene_controller.binding_probability, 0.25),
		"속박 판정이 연속 실패하면 확률이 누적된다."
	)
	scene_controller._gimmick_roll_overrides.append(true)
	scene_controller._advance_stage_gimmicks(10.0)
	_expect(
		character.is_bound
			and is_equal_approx(scene_controller.binding_probability, MainGameController.BINDING_PROBABILITY),
		"바닥 접촉 중 성공하면 즉시 속박하고 확률을 15%로 되돌린다."
	)
	var bound_position: Vector2 = character.position
	character.velocity = Vector2(500.0, -500.0)
	character._physics_process(0.5)
	_expect(character.is_bound and character.position == bound_position and character.velocity == Vector2.ZERO, "속박 중 이동·점프 속도는 차단된다.")
	character._physics_process(1.5)
	_expect(not character.is_bound, "속박은 실제 시간 약 2초 후 해제된다.")

	scene_controller.reset_game(20260801)
	character.position = Vector2(21.0, 400.0)
	character.velocity = Vector2.ZERO
	character.facing = -1
	await physics_frame
	character.left_ray.force_raycast_update()
	character._try_start_hang()
	var wall_hanging: bool = character.is_hanging and character._hang_body == scene.get_node("BoardPhysics/Boundaries")
	scene_controller._gimmick_roll_overrides.append(true)
	scene_controller._advance_stage_gimmicks(10.0)
	_expect(wall_hanging and character.is_bound, "벽에 매달린 중 속박 확률 성공은 즉시 속박한다.")

	scene_controller.reset_game(20260801)
	character.position = Vector2(240.0, 300.0)
	character.velocity = Vector2.ZERO
	await physics_frame
	scene_controller._gimmick_roll_overrides.append(true)
	scene_controller._advance_stage_gimmicks(10.0)
	_expect(scene_controller.binding_pending and not character.is_bound, "공중 속박 성공은 pending으로 저장된다.")
	scene_controller._gimmick_roll_overrides.append(true)
	scene_controller._advance_stage_gimmicks(10.0)
	_expect(scene_controller.binding_pending, "pending 중에는 추가 속박 예약이 중첩되지 않는다.")
	character.position = Vector2(240.0, 912.0)
	character._physics_process(0.0)
	_expect(character.is_bound and not scene_controller.binding_pending, "pending 속박은 다음 바닥 접촉에서 즉시 적용된다.")
	var pending_timer: float = character.binding_timer
	character.apply_binding(2.0)
	_expect(is_equal_approx(character.binding_timer, pending_timer), "속박 중 추가 속박은 중첩되지 않는다.")

	scene_controller.toggle_pause()
	var pause_binding_timer: float = character.binding_timer
	var pause_check_timer: float = scene_controller.binding_check_timer
	character._physics_process(1.0)
	scene_controller._physics_process(1.0)
	_expect(
		is_equal_approx(character.binding_timer, pause_binding_timer)
			and is_equal_approx(scene_controller.binding_check_timer, pause_check_timer),
		"PAUSED에서는 속박 지속시간과 10초 판정 시간이 흐르지 않는다."
	)
	scene_controller.state = MainGameController.GameState.PLAYING
	scene_controller.reset_game(20260801)
	_expect(
		not scene_controller.binding_pending
			and not character.is_bound
			and is_zero_approx(scene_controller.thorn_phase_timer)
			and scene_controller.thorn_visible == scene_controller.active_piece_has_thorns,
		"reset은 가시·pending·속박 상태를 초기화한다."
	)
	character._sfx_player.stop()
	character._sfx_cue_player.stop()
	character._meditation_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	scene.free()
	await process_frame


func _test_stage5_boss() -> void:
	var controller: MainGameController = GAME_CONTROLLER.new()
	var stage_clear_count: Array[int] = [0]
	controller.stage_number = 5
	controller.stage_cleared.connect(func(_cleared_lines: int) -> void:
		stage_clear_count[0] += 1
	)
	controller.reset_game(20260809)
	_expect(
		controller.is_boss_stage()
			and controller.boss_health == MainGameController.BOSS_MAX_HEALTH
			and controller.is_boss_alive(),
		"Stage 1-5 보스는 reset 시 체력 3으로 살아 있다."
	)
	_expect(
		is_equal_approx(float(controller.get_stage_gimmick_config()["thorn_probability"]), 0.33)
			and controller.get_stage_gimmick_config()["binding_enabled"],
		"Stage 1-5 보스는 33% 가시 피스와 속박을 사용한다."
	)
	_expect(
		is_equal_approx(controller.get_binding_duration_seconds(), 3.0),
		"Stage 1-5 보스 속박은 3초 동안 지속된다."
	)
	var boss_attack_hitbox: Rect2 = controller.boss_hitbox()
	_expect(
		boss_attack_hitbox.size == MainGameController.BOSS_ATTACK_HITBOX_SIZE
			and boss_attack_hitbox.end.y
			< MainGameController.BOSS_POSITION.y + 106.0 - MainGameView.HEART_DISPLAY_SIZE.y * 0.5,
		"보스 직접 공격 판정은 하트를 제외한 중앙 스프라이트 범위만 사용한다."
	)
	_expect(
		is_equal_approx(controller.get_boss_landing_y(), 960.0),
		"보스 아래에 비활성 블록이 없으면 게임판 바닥까지 떨어질 위치를 계산한다."
	)
	controller.board.cells[4][0] = MainTetrominoData.Type.J
	_expect(
		is_equal_approx(controller.get_boss_landing_y(), 960.0),
		"보스 수평 범위 밖의 비활성 블록은 착지면으로 선택하지 않는다."
	)
	controller.board.cells[4][0] = MainBoardModel.EMPTY
	controller.board.cells[10][4] = MainTetrominoData.Type.J
	_expect(
		is_equal_approx(controller.get_boss_landing_y(), 384.0),
		"보스 아래 수평 범위의 비활성 블록 상단을 가까운 바닥으로 계산한다."
	)
	controller.reset_game(20260809)
	_prepare_boss_line_clear(controller, 1)
	controller.lock_active_piece()
	_expect(
		controller.boss_health == 2
			and controller.total_lines == 1
			and controller.state == MainGameController.GameState.PLAYING,
		"보스는 한 줄 제거 시 체력이 1 감소한다."
	)
	_prepare_boss_line_clear(controller, 2)
	controller.lock_active_piece()
	_expect(
		controller.boss_health == 0
			and controller.total_lines == 3
			and controller.state == MainGameController.GameState.BOSS_FALLING
			and controller.is_boss_down()
			and not controller.is_boss_falling()
			and stage_clear_count[0] == 0
			and controller.active_type == MainTetrominoData.Type.O,
		"보스는 2줄 제거로 남은 체력을 잃고 down 연출을 시작하며 다음 피스를 만들지 않는다."
	)
	controller._advance_boss_fall(MainGameController.BOSS_DOWN_DURATION_SECONDS)
	_expect(
		controller.is_boss_falling()
			and not controller.is_boss_down()
			and controller.state == MainGameController.GameState.BOSS_FALLING,
		"보스 down 연출이 끝나면 falling 단계로 전환한다."
	)
	controller._advance_boss_fall(2.0)
	_expect(
		controller.is_boss_fallen()
			and is_equal_approx(controller.boss_fall_position.y, 960.0)
			and controller.state == MainGameController.GameState.BOSS_FALLING
			and stage_clear_count[0] == 0,
		"보스는 게임판 바닥에 착지한 뒤에도 fallen 유지 시간 동안 클리어하지 않는다."
	)
	controller._advance_boss_fall(MainGameController.BOSS_FALLEN_HOLD_SECONDS)
	_expect(
		controller.state == MainGameController.GameState.PAUSED
			and stage_clear_count[0] == 1,
		"보스 fallen 유지가 끝나면 PAUSED와 stage_cleared를 발생시킨다."
	)
	controller.free()

	var scene: MainGameView = GAME_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var scene_controller: MainGameController = scene.get_node("GameController")
	var scene_stage_clear_count: Array[int] = [0]
	scene_controller.stage_cleared.connect(func(_cleared_lines: int) -> void:
		scene_stage_clear_count[0] += 1
	)
	var character: MainCharacterController = scene.get_node("BoardPhysics/Character")
	var boss_sprite: Sprite2D = scene.get_node("BoardPhysics/BossSprite")
	var boss_thorn_sprite: Sprite2D = scene.get_node("BoardPhysics/BossThornSprite")
	var heart_one: Sprite2D = scene.get_node("BoardPhysics/BossHeart1")
	var heart_two: Sprite2D = scene.get_node("BoardPhysics/BossHeart2")
	var heart_three: Sprite2D = scene.get_node("BoardPhysics/BossHeart3")
	_expect(
		not boss_sprite.visible
			and not heart_one.visible
			and scene.get_node_or_null("BoardPhysics/BossSprite/CollisionShape2D") == null,
		"Stage 1-1에는 보스 표시나 보스 물리 충돌체가 없다."
	)

	scene_controller.stage_number = 5
	scene_controller.reset_game(20260809)
	await process_frame
	_expect(
		boss_sprite.visible
			and boss_sprite.position == MainGameController.BOSS_POSITION
			and boss_sprite.region_rect.size == MainGameView.BOSS_SOURCE_FRAME_SIZE
			and boss_sprite.scale == MainGameController.BOSS_DISPLAY_SIZE / MainGameView.BOSS_SOURCE_FRAME_SIZE
			and heart_one.visible
			and heart_two.visible
			and heart_three.visible,
		"Stage 1-5는 보스와 체력 3개 하트를 상단 중앙에 표시한다."
	)
	scene_controller.damage_boss(1)
	_expect(
		heart_one.visible and heart_two.visible and not heart_three.visible,
		"보스 체력 2에서는 하트 2개만 표시한다."
	)
	scene_controller.damage_boss(1)
	_expect(
		heart_one.visible and not heart_two.visible and not heart_three.visible,
		"보스 체력 1에서는 하트 1개만 표시한다."
	)
	scene_controller.reset_game(20260809)
	var normal_frames: Array[int] = []
	scene._boss_frame = 0
	scene._boss_frame_timer = 0.0
	scene._apply_boss_frame()
	for _frame: int in range(MainGameView.BOSS_FRAME_COUNT):
		normal_frames.append(
			int(boss_sprite.region_rect.position.x / MainGameView.BOSS_SOURCE_FRAME_SIZE.x)
		)
		scene._advance_boss_animation(MainGameView.BOSS_FRAME_INTERVAL)
	_expect(
		normal_frames == [0, 1, 2, 3]
			and int(boss_sprite.region_rect.position.x / MainGameView.BOSS_SOURCE_FRAME_SIZE.x) == 0,
		"보스 normal/bind idle은 0-1-2-3-0 순서로 0.18초마다 반복한다."
	)
	character.apply_binding()
	_expect(
		boss_sprite.texture == MainGameView.BOSS_BIND_TEXTURE,
		"플레이어 속박 시작 시 보스 텍스처가 bind 시트로 바뀐다."
	)
	character._end_binding()
	_expect(
		boss_sprite.texture == MainGameView.BOSS_NORMAL_TEXTURE,
		"플레이어 속박 종료 시 보스 텍스처가 normal 시트로 돌아온다."
	)

	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene_controller.active_type = MainTetrominoData.Type.O
	scene_controller.active_origin = Vector2i(6, 15)
	character.position = Vector2(210.0, 48.0)
	character.facing = 1
	character.lives = MainCharacterController.MAX_LIVES
	character._attack_cooldown_remaining = 0.0
	character._invulnerability_remaining = 0.0
	var active_origin_before_punch: Vector2i = scene_controller.active_origin
	var boss_attack_count: Array[int] = [0]
	scene_controller.boss_attacked.connect(func() -> void:
		boss_attack_count[0] += 1
	)
	character._attempt_punch()
	_expect(
		character.lives == MainCharacterController.MAX_LIVES - 1
			and scene_controller.active_origin == active_origin_before_punch
			and character.feedback_text == "보스 가시 피해! 목숨 -1"
			and boss_attack_count[0] == 1
			and boss_thorn_sprite.visible,
		"X 펀치가 보스를 맞히면 블록 없이 목숨 1개를 잃고 보스가 반격한다."
	)
	character._attack_cooldown_remaining = 0.0
	character._attempt_punch()
	_expect(
		character.lives == MainCharacterController.MAX_LIVES - 1,
		"X 보스 공격은 기존 무적시간 중 목숨을 연속 차감하지 않는다."
	)
	character.rotation_cooldown_remaining = 0.0
	character._spin_remaining = 0.0
	character._attempt_rotation_kick()
	_expect(
		character.lives == MainCharacterController.MAX_LIVES - 1,
		"S 보스 공격도 기존 무적시간 중 목숨을 연속 차감하지 않는다."
	)
	character._invulnerability_remaining = 0.0
	character.lives = MainCharacterController.MAX_LIVES
	character.rotation_cooldown_remaining = 0.0
	character._spin_remaining = 0.0
	var active_rotation_before_kick: int = scene_controller.active_rotation
	character._attempt_rotation_kick()
	_expect(
		character.lives == MainCharacterController.MAX_LIVES - 1
			and scene_controller.active_rotation == active_rotation_before_kick
			and character.rotation_cooldown_remaining == MainCharacterController.ROTATION_FAILED_COOLDOWN
			and character.feedback_text == "보스 가시 피해! 목숨 -1"
			and boss_attack_count[0] == 4,
		"S 회전 킥이 보스를 맞히면 블록 회전 없이 1초 실패 쿨타임으로 반격을 받는다."
	)
	var thorn_frames: Array[int] = []
	scene._boss_thorn_frame_index = 0
	scene._boss_thorn_frame_timer = 0.0
	scene._apply_boss_thorn_frame()
	for _frame: int in range(MainGameView.BOSS_THORN_FRAME_SEQUENCE.size()):
		thorn_frames.append(
			int(boss_thorn_sprite.region_rect.position.x / MainGameView.BOSS_SOURCE_FRAME_SIZE.x)
		)
		scene._advance_boss_animation(MainGameView.BOSS_THORN_FRAME_INTERVAL)
	_expect(
		thorn_frames == MainGameView.BOSS_THORN_FRAME_SEQUENCE
			and not boss_thorn_sprite.visible,
		"보스 가시 반격은 0-1-2-3-3-2-1-0 순서로 8프레임 재생 후 숨는다."
	)
	scene_controller.damage_boss(MainGameController.BOSS_MAX_HEALTH)
	_expect(
		boss_sprite.visible
			and boss_sprite.texture == MainGameView.BOSS_DOWN_TEXTURE
			and boss_sprite.position == MainGameController.BOSS_POSITION
			and not heart_one.visible
			and not heart_two.visible
			and not heart_three.visible
			and scene_controller.state == MainGameController.GameState.BOSS_FALLING
			and scene_controller.is_boss_down()
			and not scene_controller.is_boss_falling()
			and scene_stage_clear_count[0] == 0
			and not scene._status_label.visible,
		"보스 체력이 0이면 하트가 숨고 down 스프라이트부터 표시한다."
	)
	var down_frames: Array[int] = []
	scene._boss_down_frame = 0
	scene._boss_down_frame_timer = 0.0
	scene._apply_boss_down_frame()
	for _frame: int in range(MainGameView.BOSS_FRAME_COUNT):
		down_frames.append(
			int(boss_sprite.region_rect.position.x / MainGameView.BOSS_DOWN_SOURCE_FRAME_SIZE.x)
		)
		scene._advance_boss_animation(MainGameView.BOSS_FRAME_INTERVAL)
	_expect(
		down_frames == [0, 1, 2, 3]
			and int(boss_sprite.region_rect.position.x / MainGameView.BOSS_DOWN_SOURCE_FRAME_SIZE.x) == 3,
		"보스 down은 0-1-2-3 순서로 한 번 재생한 뒤 마지막 프레임을 유지한다."
	)
	scene_controller._advance_boss_fall(MainGameController.BOSS_DOWN_DURATION_SECONDS)
	_expect(
		boss_sprite.texture == MainGameView.BOSS_FALLING_TEXTURE
			and scene_controller.is_boss_falling(),
		"보스 down이 끝나면 falling 스프라이트로 바뀐다."
	)
	var falling_frames: Array[int] = []
	scene._boss_falling_frame = 0
	scene._boss_falling_frame_timer = 0.0
	scene._apply_boss_falling_frame()
	for _frame: int in range(MainGameView.BOSS_FRAME_COUNT):
		falling_frames.append(
			int(boss_sprite.region_rect.position.x / MainGameView.BOSS_SOURCE_FRAME_SIZE.x)
		)
		scene._advance_boss_animation(MainGameView.BOSS_FRAME_INTERVAL)
	_expect(
		falling_frames == [0, 1, 2, 3]
			and int(boss_sprite.region_rect.position.x / MainGameView.BOSS_SOURCE_FRAME_SIZE.x) == 0,
		"보스 falling은 0-1-2-3-0 순서로 반복한다."
	)
	scene_controller._advance_boss_fall(2.0)
	_expect(
		boss_sprite.visible
			and boss_sprite.texture == MainGameView.BOSS_FALLEN_TEXTURE
			and is_equal_approx(
				boss_sprite.position.y,
				960.0 - MainGameView.BOSS_FALLEN_DISPLAY_SIZE.y * 0.5
			)
			and scene_controller.is_boss_fallen()
			and scene_controller.state == MainGameController.GameState.BOSS_FALLING
			and scene_stage_clear_count[0] == 0,
		"보스는 바닥에 착지하면 fallen 스프라이트로 전환하고 잠시 유지한다."
	)
	var fallen_frames: Array[int] = []
	scene._boss_fallen_frame = 0
	scene._boss_fallen_frame_timer = 0.0
	scene._apply_boss_fallen_frame()
	for _frame: int in range(MainGameView.BOSS_FRAME_COUNT + 1):
		fallen_frames.append(
			int(boss_sprite.region_rect.position.x / MainGameView.BOSS_SOURCE_FRAME_SIZE.x)
		)
		scene._advance_boss_animation(MainGameView.BOSS_FRAME_INTERVAL)
	_expect(
		fallen_frames == [0, 1, 2, 3, 0],
		"보스 fallen은 0-1-2-3-0 순서로 반복한다."
	)
	scene_controller._advance_boss_fall(MainGameController.BOSS_FALLEN_HOLD_SECONDS)
	_expect(
		scene_controller.state == MainGameController.GameState.PAUSED
			and scene_stage_clear_count[0] == 1
			and boss_sprite.visible,
		"보스 fallen 유지가 끝나면 stage_cleared를 발생시키고 화면 전환 전까지 표시한다."
	)
	character._sfx_player.stop()
	character._sfx_cue_player.stop()
	character._meditation_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	scene.free()
	await process_frame


func _prepare_boss_line_clear(controller: MainGameController, rows: int) -> void:
	controller.board.reset()
	controller.state = MainGameController.GameState.PLAYING
	controller.active_type = MainTetrominoData.Type.O
	controller.active_rotation = 0
	controller.active_origin = Vector2i(4, MainBoardModel.HEIGHT - 2)
	controller.next_type = MainTetrominoData.Type.Z
	for y: int in range(MainBoardModel.HEIGHT - rows, MainBoardModel.HEIGHT):
		for x: int in range(MainBoardModel.WIDTH):
			if x != 5 and x != 6:
				controller.board.cells[y][x] = MainTetrominoData.Type.J


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
