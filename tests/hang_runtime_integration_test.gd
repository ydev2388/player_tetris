extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")


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
	game.controller.board.reset()
	# Use a tall wall so the climb cycle can expose all eight animation frames
	# before reaching the top-lip transition exercised by the corner test.
	for row: int in range(3, 18):
		game.controller.board.cells[row][5] = MainTetrominoData.Type.J
	board_physics._sync_from_model()
	await physics_frame

	character.set_character_id("normal")
	character.position = Vector2(216.0, 680.0)
	character.velocity = Vector2.ZERO
	character.facing = 1
	character.stamina = MainCharacterController.MAX_STAMINA
	character._hang_regrab_remaining = 0.0
	Input.action_press(&"character_grab")
	character._try_start_hang()
	if not character.is_hanging:
		push_error("Runtime fixture could not start hanging.")
		_cleanup_input()
		quit(1)
		return

	var up_event: InputEventKey = InputEventKey.new()
	up_event.keycode = KEY_UP
	up_event.physical_keycode = KEY_UP
	up_event.pressed = true
	Input.parse_input_event(up_event)

	var start_y: float = character.global_position.y
	var observed_frames: Dictionary = {}
	for physics_index: int in range(96):
		await physics_frame
		var frame_index: int = int(character.sprite.region_rect.position.x / 128.0)
		observed_frames[frame_index] = true
		if physics_index % 8 == 0:
			print(
				"HANG_RUNTIME frame=", physics_index,
				" y=", snappedf(character.global_position.y, 0.01),
				" atlas_frame=", frame_index,
				" direction=", character._hang_animation_direction,
				" hanging=", character.is_hanging
			)

	var climbed: bool = character.global_position.y < start_y - 1.0
	var animated: bool = observed_frames.size() == 8
	print("HANG_RUNTIME_RESULT climbed=", climbed, " frames=", observed_frames.keys())
	_cleanup_input()
	game.queue_free()
	await process_frame
	if not climbed or not animated:
		push_error("Hanging runtime did not climb through all eight sprite frames.")
		quit(1)
		return
	quit(0)


func _cleanup_input() -> void:
	Input.action_release(&"character_grab")
	var up_release: InputEventKey = InputEventKey.new()
	up_release.keycode = KEY_UP
	up_release.physical_keycode = KEY_UP
	up_release.pressed = false
	Input.parse_input_event(up_release)
