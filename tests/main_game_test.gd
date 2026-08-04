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
