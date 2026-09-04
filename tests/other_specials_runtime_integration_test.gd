extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _committed_ids: Array[StringName] = []


func _init() -> void:
	call_deferred("_run")


func _on_ability_event(event: MainGameEvent) -> void:
	if event.kind == MainGameEvent.Kind.ABILITY_COMMITTED:
		_committed_ids.append(event.ability_id)


func _press_special() -> void:
	Input.action_release(&"character_special")
	await physics_frame
	Input.action_press(&"character_special")
	await physics_frame
	await physics_frame
	Input.action_release(&"character_special")


func _run() -> void:
	var game: MainGameView = GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var controller: MainGameController = game.controller
	var character: MainCharacterController = game.character
	character.ability_event_committed.connect(_on_ability_event)
	controller.game_event_committed.connect(_on_ability_event)
	controller.state = MainGameController.GameState.PLAYING
	controller.board.reset()
	character.position = Vector2(5.5 * MainLayout.CELL_SIZE, 912.0)
	character.velocity = Vector2.ZERO
	character.facing = 1

	character.set_character_id("normal")
	character.special_cooldown_remaining = 0.0
	await _press_special()
	var normal_committed: bool = (
		character.sprint_remaining() > 0.0 and &"normal" in _committed_ids
	)

	character.set_character_id("shield_guard")
	character.position = Vector2(5.5 * MainLayout.CELL_SIZE, 912.0)
	character.facing = 1
	character.special_cooldown_remaining = 0.0
	await _press_special()
	character.position.x -= MainLayout.CELL_SIZE
	character.facing = -1
	for _frame: int in range(20):
		await physics_frame
	var shield_committed: bool = (
		&"shield_guard" in _committed_ids
		and controller.barrier_direction() == 1
		and controller.transient_blocker_snapshot()
		== [Vector2i(6, 21), Vector2i(6, 20), Vector2i(6, 19)]
		and controller.barrier_remaining() > 0.0
	)

	character.set_character_id("clockmaker")
	character.special_cooldown_remaining = 0.0
	await _press_special()
	for _frame: int in range(28):
		await physics_frame
	var clock_committed: bool = (
		&"clockmaker" in _committed_ids
		and controller.fall_freeze_remaining() > 0.0
		and controller.fall_freeze_remaining()
		< MainGameController.CLOCK_FREEZE_DURATION_SECONDS
	)

	print(
		"OTHER_SPECIALS_RUNTIME_RESULT normal=", normal_committed,
		" shield=", shield_committed,
		" clock=", clock_committed,
		" events=", _committed_ids
	)
	Input.action_release(&"character_special")
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	if not normal_committed or not shield_committed or not clock_committed:
		push_error("Normal, shield guard, or clockmaker command/event runtime contract failed.")
		quit(1)
		return
	quit(0)
