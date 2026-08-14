extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")


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

	character.set_character_id("boxer")
	character.position = Vector2(5.5 * MainLayout.CELL_SIZE, 912.0)
	character.velocity = Vector2.ZERO
	character.facing = 1
	controller.board.reset()
	controller.board.cells[21][6] = MainTetrominoData.Type.T
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
	for _frame: int in range(24):
		await physics_frame

	var floor_block_moved: bool = (
		controller.board.get_cell(Vector2i(6, 21)) == MainBoardModel.EMPTY
		and controller.board.get_cell(Vector2i(9, 21)) == MainTetrominoData.Type.T
		and character.last_special_succeeded()
	)
	print(
		"BOXER_SPECIAL_RUNTIME_RESULT input=", input_was_accepted,
		" floor_block_moved=", floor_block_moved
	)
	Input.action_release(&"character_special")
	game.queue_free()
	await process_frame
	if not input_was_accepted or not floor_block_moved:
		push_error("Boxer V input did not move the lower front block.")
		quit(1)
		return
	quit(0)
