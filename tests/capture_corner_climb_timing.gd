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
	call_deferred("_capture")


func _capture() -> void:
	var game: MainGameView = GAME_SCENE.instantiate()
	game.set_meta("stage_number", 1)
	root.add_child(game)
	await process_frame
	await physics_frame

	var character: MainCharacterController = game.character
	var board_physics: MainBoardPhysics = game.get_node("BoardPhysics")
	Input.action_press(&"character_grab")
	for character_id: String in CHARACTER_IDS:
		for direction: int in [1, -1]:
			var prepared: bool = await _prepare_capture_fixture(
				game,
				board_physics,
				character,
				character_id,
				direction
			)
			if not prepared:
				push_error(
					"Failed corner capture fixture: %s direction=%d"
					% [character_id, direction]
				)
				quit(1)
				return
			game.controller.process_mode = Node.PROCESS_MODE_DISABLED
			character.process_mode = Node.PROCESS_MODE_DISABLED
			var direction_name: String = "right" if direction > 0 else "left"
			for frame_index: int in range(8):
				character._hang_corner_climb_progress = _sample_progress_for_frame(frame_index)
				character._advance_hang_corner_climb(0.0)
				character._advance_character_animation(0.0)
				game.queue_redraw()
				await _save(
					"res://build/corner_climb_%s_%s_frame_%d.png"
					% [character_id, direction_name, frame_index]
				)

	_set_up_pressed(false)
	Input.action_release(&"character_grab")
	game.queue_free()
	await process_frame
	quit(0)


func _prepare_capture_fixture(
	game: MainGameView,
	board_physics: MainBoardPhysics,
	character: MainCharacterController,
	character_id: String,
	direction: int
) -> bool:
	character.process_mode = Node.PROCESS_MODE_INHERIT
	game.controller.process_mode = Node.PROCESS_MODE_INHERIT
	character._exit_hang()
	game.controller.board.reset()
	var block_x: int = 5 if direction > 0 else 4
	game.controller.board.cells[10][block_x] = MainTetrominoData.Type.J
	game.controller.state = MainGameController.GameState.PLAYING
	board_physics._sync_from_model()
	await physics_frame
	character.set_character_id(character_id)
	character.position = Vector2(216.0 if direction > 0 else 264.0, 440.0)
	character.velocity = Vector2.ZERO
	character._update_facing(float(direction))
	character.stamina = MainCharacterController.MAX_STAMINA
	character._hang_regrab_remaining = 0.0
	var hang_ray: RayCast2D = character.right_ray if direction > 0 else character.left_ray
	hang_ray.force_raycast_update()
	_set_up_pressed(false)
	await process_frame
	_set_up_pressed(true)
	await process_frame
	character._try_start_hang()
	if not character.is_hanging:
		return false
	character.global_position.y = character._hang_top_global_y
	character._handle_hanging(1.0 / 60.0)
	return character._hang_corner_climb_active


func _save(path: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		push_error("Failed capture: %s" % path)
		quit(1)


func _sample_progress_for_frame(frame_index: int) -> float:
	var thresholds: Array[float] = (
		MainCharacterController.HANG_CORNER_FRAME_PROGRESS_THRESHOLDS
	)
	var start_progress: float = thresholds[frame_index]
	var end_progress: float = 1.0
	if frame_index + 1 < thresholds.size():
		end_progress = thresholds[frame_index + 1]
	return (start_progress + end_progress) * 0.5


func _set_up_pressed(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_UP
	event.physical_keycode = KEY_UP
	event.pressed = pressed
	Input.parse_input_event(event)
