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
	InputMap.action_erase_events(&"character_punch")
	var custom_event: InputEventKey = InputEventKey.new()
	custom_event.physical_keycode = KEY_F8
	InputMap.action_add_event(&"character_punch", custom_event)
	INPUT_ACTIONS.ensure_defaults()
	var custom_events: Array[InputEvent] = InputMap.action_get_events(&"character_punch")
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
		MainCharacterController.push_distance_for_charge(0.1) == 1
			and MainCharacterController.push_distance_for_charge(0.4) == 2
			and MainCharacterController.push_distance_for_charge(0.9) == 3,
		"펀치 hold 단계는 1·2·3칸 순서다."
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
	await _test_release_punch()
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


func _test_release_punch() -> void:
	var scene: MainGameView = GAME_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	await process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED

	var controller: MainGameController = scene.get_node("GameController")
	var character: MainCharacterController = scene.get_node("BoardPhysics/Character")
	_prepare_punch(controller, character, Vector2i(4, 19), Vector2(165.0, 912.0))
	var start_origin: Vector2i = controller.active_origin
	Input.action_release(&"character_punch")
	Input.action_press(&"character_punch")
	character._handle_charge(0.2)
	_expect(
		character._charging
			and character._pending_punch_stage == 0
			and controller.active_origin == start_origin,
		"X를 누르고 유지하는 동안에는 블록이 움직이지 않는다."
	)
	Input.action_release(&"character_punch")
	character._handle_charge(0.0)
	_expect(
		not character._charging
			and character._pending_punch_stage == 1
			and controller.active_origin == start_origin,
		"X를 놓은 뒤에만 1칸 펀치 판정이 예약된다."
	)
	character._resolve_pending_punch(0.0)
	_expect(
		controller.active_origin == start_origin + Vector2i.RIGHT,
		"놓은 뒤 전방 hitbox에 닿은 블록만 1칸 이동한다."
	)

	_prepare_punch(controller, character, Vector2i(7, 1), Vector2(24.0, 912.0))
	Input.action_press(&"character_punch")
	character._handle_charge(0.2)
	Input.action_release(&"character_punch")
	character._handle_charge(0.0)
	character._resolve_pending_punch(0.1)
	_expect(
		controller.active_origin == Vector2i(7, 1),
		"전방 hitbox 밖의 블록은 놓아도 이동하지 않는다."
	)
	Input.action_release(&"character_punch")
	character._sfx_player.stop()
	character._sfx_cue_player.stop()
	character._meditation_loop_player.stop()
	character._charge_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	character._charge_loop_player.stream = null
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
	character._charge_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	character._charge_loop_player.stream = null
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
			and is_equal_approx(character._hang_top_global_y, 400.0)
			and is_equal_approx(character._hang_bottom_global_y, 496.0),
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
	var active_piece: AnimatableBody2D = board_physics.active_body
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
			and is_equal_approx(character._hang_top_global_y, 496.0)
			and is_equal_approx(character._hang_bottom_global_y, 544.0),
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
			and is_equal_approx(character._hang_top_global_y, 400.0)
			and is_equal_approx(character._hang_bottom_global_y, 448.0),
		"수평으로 꺾인 step은 다른 face를 같은 범위로 합치지 않는다."
	)
	character._exit_hang()

	character._sfx_player.stop()
	character._sfx_cue_player.stop()
	character._meditation_loop_player.stop()
	character._charge_loop_player.stop()
	character._sfx_player.stream = null
	character._sfx_cue_player.stream = null
	character._meditation_loop_player.stream = null
	character._charge_loop_player.stream = null
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
	character._charging = false
	character.charge_time = 0.0
	character._attack_cooldown_remaining = 0.0
	character._attack_animation_remaining = 0.0
	character._pending_punch_stage = 0
	character._pending_punch_hit_remaining = 0.0
