extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
const CHARACTER_IDS: Array[String] = [
	"normal",
	"boxer",
	"shield_guard",
	"firefighter",
	"cleaner",
	"chef",
	"clockmaker",
	"ninja",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: MainGameView = GAME_SCENE.instantiate()
	game.set_meta("stage_number", 1)
	root.add_child(game)
	await process_frame
	await physics_frame
	var character: MainCharacterController = game.character
	var board_physics: MainBoardPhysics = game.get_node("BoardPhysics")
	var failures: Array[String] = []

	Input.action_press(&"character_grab")
	for character_id: String in CHARACTER_IDS:
		await _prepare_boundary_diagonal_fixture(game, board_physics, character, character_id)
		# Refresh the synthetic key for every fixture. Input.parse_input_event can be
		# observed one process iteration late on the first headless fixture.
		_set_up_pressed(false)
		await process_frame
		_set_up_pressed(true)
		await process_frame
		character._try_start_hang()
		if not character.is_hanging:
			failures.append("%s: boundary grab failed" % character_id)
			continue
		var start_y: float = character.global_position.y
		var anchor_x: float = character.global_position.x
		var max_x_error: float = 0.0
		for frame_index: int in range(30):
			character._handle_hanging(1.0 / 60.0)
			max_x_error = maxf(
				max_x_error,
				absf(character.global_position.x - anchor_x)
			)
		if (
			not character.is_hanging
			or character.global_position.y >= start_y - 20.0
			or max_x_error > 0.01
		):
			failures.append(
				"%s: diagonal boundary climb stalled/jittered start=%s end=%s x_error=%s"
				% [character_id, start_y, character.global_position.y, max_x_error]
			)

	for character_id: String in CHARACTER_IDS:
		await _prepare_locked_corner_fixture(game, board_physics, character, character_id)
		_set_up_pressed(false)
		await process_frame
		_set_up_pressed(true)
		await process_frame
		character._try_start_hang()
		if not character.is_hanging:
			failures.append("%s: locked block grab failed" % character_id)
			continue
		character.global_position.y = character._hang_top_global_y
		for frame_index: int in range(120):
			if not character.is_hanging:
				break
			character._handle_hanging(1.0 / 60.0)
		var foot_y: float = (
			character.position.y
			+ MainCharacterController.CHARACTER_COLLIDER_OFFSET_Y
			+ MainCharacterController.CHARACTER_COLLIDER_HEIGHT * 0.5
		)
		var expected_top_y: float = float(10 - MainBoardModel.HIDDEN_ROWS) * MainLayout.CELL_SIZE
		if character.is_hanging or not is_equal_approx(foot_y, expected_top_y):
			failures.append(
				"%s: did not finish corner climb foot=%s expected=%s"
				% [character_id, foot_y, expected_top_y]
			)

	_set_up_pressed(false)
	Input.action_release(&"character_grab")
	print("CORNER_HANG_RUNTIME_RESULT failures=", failures)
	game.queue_free()
	await process_frame
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	quit(0)


func _prepare_boundary_diagonal_fixture(
	game: MainGameView,
	board_physics: MainBoardPhysics,
	character: MainCharacterController,
	character_id: String
) -> void:
	character._exit_hang()
	game.controller.board.reset()
	game.controller.board.cells[14][8] = MainTetrominoData.Type.O
	game.controller.board.cells[15][8] = MainTetrominoData.Type.O
	game.controller.state = MainGameController.GameState.PLAYING
	board_physics._sync_from_model()
	await physics_frame
	character.set_character_id(character_id)
	character.position = Vector2(MainCharacterController.BOARD_MAX_X, 584.0)
	character.velocity = Vector2.ZERO
	character.facing = 1
	character.stamina = MainCharacterController.MAX_STAMINA
	character._hang_regrab_remaining = 0.0
	character.right_ray.force_raycast_update()


func _prepare_locked_corner_fixture(
	game: MainGameView,
	board_physics: MainBoardPhysics,
	character: MainCharacterController,
	character_id: String
) -> void:
	character._exit_hang()
	game.controller.board.reset()
	game.controller.board.cells[10][5] = MainTetrominoData.Type.J
	game.controller.state = MainGameController.GameState.PLAYING
	board_physics._sync_from_model()
	await physics_frame
	character.set_character_id(character_id)
	character.position = Vector2(216.0, 440.0)
	character.velocity = Vector2.ZERO
	character.facing = 1
	character.stamina = MainCharacterController.MAX_STAMINA
	character._hang_regrab_remaining = 0.0
	character.right_ray.force_raycast_update()


func _set_up_pressed(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_UP
	event.physical_keycode = KEY_UP
	event.pressed = pressed
	Input.parse_input_event(event)
