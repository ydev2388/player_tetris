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
	game.controller.board.reset()
	character.set_character_id("normal")
	character.position = Vector2(240.0, 180.0)
	character.velocity = Vector2.ZERO
	character._animation_state = MainCharacterAnimationData.JUMP
	character._animation_time = 0.0

	var observed_frames: Dictionary = {}
	var terminal_height: float = 0.0
	for physics_index: int in range(42):
		await physics_frame
		var frame_index: int = int(character.sprite.region_rect.position.x / 128.0)
		observed_frames[frame_index] = true
		if frame_index == 7:
			terminal_height = character._frame_alpha_bounds(
				character.sprite.region_rect
			).size.y
		if physics_index % 7 == 0:
			print(
				"FALL_RUNTIME frame=", physics_index,
				" y=", snappedf(character.global_position.y, 0.01),
				" velocity_y=", snappedf(character.velocity.y, 0.01),
				" atlas_frame=", frame_index
			)

	var reached_terminal_fall: bool = observed_frames.has(7)
	var terminal_is_extended: bool = terminal_height >= 70.0
	var fixed_scale: bool = character.sprite.scale.is_equal_approx(Vector2.ONE)
	print(
		"FALL_RUNTIME_RESULT frames=", observed_frames.keys(),
		" terminal_height=", terminal_height,
		" fixed_scale=", fixed_scale
	)
	game.queue_free()
	await process_frame
	if not reached_terminal_fall or not terminal_is_extended or not fixed_scale:
		push_error("Long fall did not hold the extended terminal-fall sprite.")
		quit(1)
		return
	quit(0)
