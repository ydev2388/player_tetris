extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
var _boxer_commit_count: int = 0


func _on_game_event(event: MainGameEvent) -> void:
	if event.kind == MainGameEvent.Kind.ABILITY_COMMITTED and event.ability_id == &"boxer":
		_boxer_commit_count += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: MainGameView = GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var controller: MainGameController = game.controller
	var character: MainCharacterController = game.character
	var board_physics: MainBoardPhysics = game.get_node("BoardPhysics")
	controller.game_event_committed.connect(_on_game_event)

	character.set_character_id("boxer")
	character.position = Vector2(5.5 * MainLayout.CELL_SIZE, 912.0)
	character.velocity = Vector2.ZERO
	character.facing = 1
	controller.board.reset()
	controller.board.set_cell(Vector2i(6, 21), MainTetrominoData.Type.T)
	controller.state = MainGameController.GameState.PLAYING
	board_physics._sync_from_model()
	character._cancel_character_skill_effects()
	character.special_cooldown_remaining = 0.0
	await physics_frame

	Input.action_release(&"character_special")
	await physics_frame
	Input.action_press(&"character_special")
	await physics_frame
	await physics_frame
	var input_was_accepted: bool = (
		character.special_cooldown_remaining > 0.0
		or character._pending_special_id == "boxer"
		or character.is_special_animating()
	)
	Input.action_release(&"character_special")
	# Wind-up 도중 이동·회전해도 입력 순간 후보와 방향을 유지해야 한다.
	character.position.x -= MainLayout.CELL_SIZE
	character.facing = -1
	for _frame: int in range(24):
		await physics_frame

	var floor_block_moved: bool = (
		controller.board.get_cell(Vector2i(6, 21)) == MainBoardModel.EMPTY
		and controller.board.get_cell(Vector2i(9, 21)) == MainTetrominoData.Type.T
		and character.last_special_succeeded()
		and _boxer_commit_count == 1
	)
	print(
		"BOXER_SPECIAL_RUNTIME_RESULT input=", input_was_accepted,
		" floor_block_moved=", floor_block_moved,
		" events=", _boxer_commit_count
	)
	Input.action_release(&"character_special")
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	if not input_was_accepted or not floor_block_moved:
		push_error("Boxer V input did not move the lower front block.")
		quit(1)
		return
	quit(0)
