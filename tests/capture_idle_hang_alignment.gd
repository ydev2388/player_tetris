extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var game: MainGameView = GAME_SCENE.instantiate()
	game.set_meta("stage_number", 1)
	root.add_child(game)
	await process_frame
	await physics_frame

	var character: MainCharacterController = game.character
	var board_physics: MainBoardPhysics = game.get_node("BoardPhysics")
	game.controller.state = MainGameController.GameState.PAUSED
	character.set_character_id("normal")
	character.position = Vector2(240.0, 912.0)
	character.velocity = Vector2.ZERO
	character._animation_state = MainCharacterAnimationData.IDLE
	character._animation_time = 10.0
	character._advance_character_animation(1.0)
	await _save("res://build/idle_stable_review.png")

	game.controller.board.reset()
	for row: int in range(18, 22):
		game.controller.board.cells[row][5] = MainTetrominoData.Type.J
	board_physics._sync_from_model()
	await physics_frame
	game.controller.state = MainGameController.GameState.PLAYING
	game.process_mode = Node.PROCESS_MODE_DISABLED
	character.position = Vector2(219.0, 912.0)
	character.velocity = Vector2.ZERO
	character.facing = 1
	character.sprite.flip_h = false
	character._animation_state = MainCharacterAnimationData.IDLE
	character._animation_time = 0.0
	character._apply_animation_frame()
	game.queue_redraw()
	await _save("res://build/standing_wall_aligned_review.png")

	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.controller.state = MainGameController.GameState.PAUSED
	game.controller.board.reset()
	game.controller.board.cells[9][5] = MainTetrominoData.Type.J
	board_physics._sync_from_model()
	await physics_frame
	character.position = Vector2(216.0, 360.0)
	character.velocity = Vector2.ZERO
	character.facing = 1
	character.stamina = MainCharacterController.MAX_STAMINA
	character._hang_regrab_remaining = 0.0
	character._try_start_hang()
	character._animation_state = MainCharacterAnimationData.HANG
	character._animation_time = 0.16
	character._apply_animation_frame()
	await _save("res://build/hang_wall_aligned_review.png")

	game.queue_free()
	await process_frame
	quit(0)


func _save(path: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		push_error("Failed capture: %s" % path)
		quit(1)
