extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
var _cleaner_removed_count: int = 0


func _on_game_event(event: MainGameEvent) -> void:
	if event.kind == MainGameEvent.Kind.ABILITY_COMMITTED and event.ability_id == &"cleaner":
		_cleaner_removed_count = event.amount


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

	controller.board.reset()
	for x: int in range(4, 7):
		controller.board.set_cell(Vector2i(x, 21), MainTetrominoData.Type.T)
	controller.state = MainGameController.GameState.PLAYING
	board_physics._sync_from_model()
	character.set_character_id("cleaner")
	character.position = Vector2(5.5 * MainLayout.CELL_SIZE, 864.0)
	character.velocity = Vector2(0.0, 10.0)
	character._cancel_character_skill_effects()
	character.special_cooldown_remaining = 0.0
	await physics_frame
	await physics_frame

	var stood_on_fixed_blocks: bool = (
		character.is_on_floor()
		and character._cell_below_feet() == Vector2i(5, 21)
	)
	Input.action_release(&"character_special")
	await physics_frame
	Input.action_press(&"character_special")
	await physics_frame
	await physics_frame
	var input_was_accepted: bool = (
		character._pending_special_id == "cleaner"
		and character.special_cooldown_remaining > 0.0
	)
	Input.action_release(&"character_special")
	await physics_frame

	# Move away during the 0.4 second sweep. The cast-time cells must remain
	# authoritative even after the character leaves their supporting blocks.
	character.position.x += MainLayout.CELL_SIZE * 2.0
	for _frame: int in range(28):
		await physics_frame

	var original_targets_removed: bool = true
	for x: int in range(4, 7):
		original_targets_removed = (
			original_targets_removed
			and controller.board.get_cell(Vector2i(x, 21)) == MainBoardModel.EMPTY
		)
	original_targets_removed = original_targets_removed and _cleaner_removed_count == 3
	print(
		"CLEANER_SPECIAL_RUNTIME_RESULT grounded=", stood_on_fixed_blocks,
		" input=", input_was_accepted,
		" original_targets_removed=", original_targets_removed,
		" removed_event=", _cleaner_removed_count
	)
	Input.action_release(&"character_special")
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	if not stood_on_fixed_blocks or not input_was_accepted or not original_targets_removed:
		push_error("Cleaner V input did not clean its cast-time support cells.")
		quit(1)
		return
	quit(0)
