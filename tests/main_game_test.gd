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
			and is_equal_approx(MainGameController.GRAVITY_INTERVAL_START, 7.0 / 15.0)
			and MainGameController.MEDITATION_TIME_SCALE == 2.0,
		"기본 낙하·고정 시간은 1.5배 속도값 자체이며 명상 중에는 2배다."
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
	await _test_top_hud()
	await _test_fixed_support_grab()
	await _test_hang_face_bounds()
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
	var level_label: Label = scene.find_child("LevelLabel", true, false) as Label
	var next_label: Label = scene.find_child("NextLabel", true, false) as Label
	var timer_label: Label = scene.find_child("TimerLabel", true, false) as Label
	_expect(
		lines_label != null
			and lines_label.text.contains("파괴")
			and level_label != null
			and level_label.text.contains("LEVEL")
			and next_label != null
			and timer_label != null
			and timer_label.text == "01:30"
			and timer_label.position.y < MainLayout.BOARD_ORIGIN.y
			and next_label.position.x > MainLayout.BOARD_ORIGIN.x + MainLayout.BOARD_SIZE.x * 0.5
			and next_label.position.y < MainLayout.BOARD_ORIGIN.y,
		"보드 폭에 맞춘 상단 HUD에 타이머·레벨·다음 블록 카드를 표시한다."
	)
	_expect(
		scene.find_child("StatsLabel", true, false) == null
			and scene.find_child("StaminaLabel", true, false) == null
			and scene.find_child("PunchLabel", true, false) == null
			and scene.find_child("RotationKickLabel", true, false) == null,
		"점수·스태미나·펀치·회전 킥 우측 HUD는 없다."
	)

	var character: MainCharacterController = scene.get_node("BoardPhysics/Character")
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
