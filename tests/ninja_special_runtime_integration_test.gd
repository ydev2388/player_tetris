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

	controller.state = MainGameController.GameState.PLAYING
	controller.board.reset()
	controller.active_type = MainTetrominoData.Type.O
	controller.active_rotation = 0
	controller.active_origin = Vector2i(6, 19)
	controller.active_cell_indices = [0, 1, 2, 3]
	character.set_character_id("ninja")
	character.position = Vector2(5.5 * MainLayout.CELL_SIZE, 912.0)
	character.velocity = Vector2.ZERO
	character.facing = 1
	character._cancel_character_skill_effects()
	character.special_cooldown_remaining = 0.0
	var origin_before: Vector2i = controller.active_origin

	Input.action_release(&"character_special")
	await physics_frame
	Input.action_press(&"character_special")
	await physics_frame
	await physics_frame
	var input_was_accepted: bool = (
		character._pending_special_id == "ninja"
		or character.is_special_animating()
		or character.special_cooldown_remaining > 0.0
	)
	Input.action_release(&"character_special")
	for _frame: int in range(32):
		await physics_frame

	var result: Dictionary = character.ninja_special_result()
	var collision_succeeded: bool = (
		not result.is_empty()
		and not bool(result.get("in_flight", true))
		and bool(result.get("success", false))
		and result.get("contact") == MainGameController.SHURIKEN_CONTACT_ACTIVE
		and controller.active_origin.x == origin_before.x + 1
	)
	var visual_position_matches: bool = false
	if result.has("position"):
		var board_position: Vector2 = result["position"] as Vector2
		var canvas_position: Vector2 = game.ninja_shuriken_canvas_position(board_position)
		visual_position_matches = (
			canvas_position == MainLayout.BOARD_ORIGIN + board_position
			and Rect2(MainLayout.BOARD_ORIGIN, MainLayout.BOARD_SIZE).has_point(canvas_position)
		)

	print(
		"NINJA_SPECIAL_RUNTIME_RESULT input=", input_was_accepted,
		" collision=", collision_succeeded,
		" visual=", visual_position_matches,
		" result=", result
	)
	Input.action_release(&"character_special")
	game.queue_free()
	await process_frame
	if not input_was_accepted or not collision_succeeded or not visual_position_matches:
		push_error("Ninja V input, projectile collision, or board-space VFX contract failed.")
		quit(1)
		return
	quit(0)
