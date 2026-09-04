extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")
var _ninja_launch_count: int = 0
var _ninja_impact_count: int = 0


func _on_ability_event(event: MainGameEvent) -> void:
	if event.ability_id != &"ninja":
		return
	if event.kind == MainGameEvent.Kind.ABILITY_COMMITTED:
		_ninja_launch_count += 1
	elif event.kind == MainGameEvent.Kind.NINJA_PROJECTILE_IMPACTED:
		_ninja_impact_count += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: MainGameView = GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var controller: MainGameController = game.controller
	var character: MainCharacterController = game.character
	character.ability_event_committed.connect(_on_ability_event)

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
	# 발사 지연 중 위치·방향을 바꿔도 최초 cast context를 사용한다.
	character.position.x -= MainLayout.CELL_SIZE
	character.facing = -1
	for _frame: int in range(32):
		await physics_frame

	var result: MainNinjaProjectileSnapshot = character.ninja_projectile_snapshot()
	var collision_succeeded: bool = (
		result != null
		and not result.in_flight
		and result.succeeded
		and result.contact == MainGameController.SHURIKEN_CONTACT_ACTIVE
		and controller.active_origin.x == origin_before.x + 1
		and _ninja_launch_count == 1
		and _ninja_impact_count == 1
	)
	var visual_position_matches: bool = false
	if result != null:
		var board_position: Vector2 = result.position
		var canvas_position: Vector2 = game.ninja_shuriken_canvas_position(board_position)
		visual_position_matches = (
			canvas_position == MainLayout.BOARD_ORIGIN + board_position
			and Rect2(MainLayout.BOARD_ORIGIN, MainLayout.BOARD_SIZE).has_point(canvas_position)
		)

	print(
		"NINJA_SPECIAL_RUNTIME_RESULT input=", input_was_accepted,
		" collision=", collision_succeeded,
		" visual=", visual_position_matches,
		" launch_events=", _ninja_launch_count,
		" impact_events=", _ninja_impact_count
	)
	Input.action_release(&"character_special")
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	if not input_was_accepted or not collision_succeeded or not visual_position_matches:
		push_error("Ninja V input, projectile collision, or board-space VFX contract failed.")
		quit(1)
		return
	quit(0)
