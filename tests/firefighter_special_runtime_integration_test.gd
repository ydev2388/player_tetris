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

	controller.board.reset()
	controller.state = MainGameController.GameState.PLAYING
	character.set_character_id("firefighter")
	character.position = Vector2(5.5 * MainLayout.CELL_SIZE, 912.0)
	character.velocity = Vector2(0.0, 10.0)
	character.facing = 1
	character._cancel_character_skill_effects()
	character.special_cooldown_remaining = 0.0
	await physics_frame
	await physics_frame

	Input.action_release(&"character_special")
	await physics_frame
	Input.action_press(&"character_special")
	await physics_frame
	await physics_frame
	var input_was_accepted: bool = (
		character._pending_special_id == "firefighter"
		and character.special_cooldown_remaining > 0.0
	)
	Input.action_release(&"character_special")
	await physics_frame

	# Turn and move during the 0.6 second cast. The water must still use the
	# original right-facing cast position.
	character.facing = -1
	character.position.x -= MainLayout.CELL_SIZE
	for _frame: int in range(42):
		await physics_frame

	var cast_pose_was_preserved: bool = (
		controller.water_path_direction == 1
		and controller.water_path_cells
		== [Vector2i(6, 21), Vector2i(7, 21), Vector2i(8, 21)]
		and character.water_remaining() > 0.0
	)
	print(
		"FIREFIGHTER_SPECIAL_RUNTIME_RESULT input=", input_was_accepted,
		" cast_pose=", cast_pose_was_preserved,
		" cells=", controller.water_path_cells
	)
	Input.action_release(&"character_special")
	game.queue_free()
	await process_frame
	if not input_was_accepted or not cast_pose_was_preserved:
		push_error("Firefighter V input did not preserve its cast path.")
		quit(1)
		return
	quit(0)
