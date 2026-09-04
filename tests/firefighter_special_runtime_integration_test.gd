extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _runtime_controller: MainGameController
var _runtime_view: MainGameView
var _water_commit_count: int = 0
var _committed_state_was_visible: bool = false
var _view_pulse_started: bool = false


func _init() -> void:
	call_deferred("_run")


func _on_game_event_committed(event: MainGameEvent) -> void:
	if event.kind != MainGameEvent.Kind.FIREFIGHTER_WATER_COMMITTED:
		return
	_water_commit_count += 1
	_committed_state_was_visible = (
		is_instance_valid(_runtime_controller)
		and _runtime_controller.water_path_snapshot() == event.cells
		and _runtime_controller.water_path_direction() == event.direction
	)
	_view_pulse_started = (
		is_instance_valid(_runtime_view)
		and _runtime_view._water_path_commit_pulse_remaining > 0.0
	)


func _run() -> void:
	var game: MainGameView = GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var controller: MainGameController = game.controller
	var character: MainCharacterController = game.character
	_runtime_controller = controller
	_runtime_view = game
	controller.game_event_committed.connect(_on_game_event_committed)

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
		and character._pending_prepared_ability != null
		and character._pending_prepared_ability.command is MainFirefighterCastCommand
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
		controller.water_path_direction() == 1
		and controller.water_path_snapshot()
		== [Vector2i(6, 21), Vector2i(7, 21), Vector2i(8, 21)]
		and controller.water_path_remaining() > 0.0
		and is_equal_approx(character.water_remaining(), controller.water_path_remaining())
		and _water_commit_count == 1
		and _committed_state_was_visible
		and _view_pulse_started
	)
	print(
		"FIREFIGHTER_SPECIAL_RUNTIME_RESULT input=", input_was_accepted,
		" cast_pose=", cast_pose_was_preserved,
		" cells=", controller.water_path_snapshot(),
		" events=", _water_commit_count,
		" view_pulse=", _view_pulse_started
	)
	Input.action_release(&"character_special")
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	if not input_was_accepted or not cast_pose_was_preserved:
		push_error("Firefighter V input did not preserve its cast path.")
		quit(1)
		return
	quit(0)
