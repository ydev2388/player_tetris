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
	character.set_character_id("chef")
	character.position = Vector2(5.5 * MainLayout.CELL_SIZE, 912.0)
	character.velocity = Vector2.ZERO
	character._cancel_character_skill_effects()
	character.special_cooldown_remaining = 0.0
	character.lives = 3
	character._invulnerability_remaining = 0.0
	var base_speed: float = MainCharacterData.move_speed("chef") * MainCharacterController.GIT_GRID_SCALE

	Input.action_release(&"character_special")
	await physics_frame
	Input.action_press(&"character_special")
	await physics_frame
	await physics_frame
	var input_was_accepted: bool = character._pending_special_id == "chef"
	Input.action_release(&"character_special")
	for _frame: int in range(22):
		await physics_frame

	var buff_started: bool = (
		character.chef_meat_remaining() > 0.0
		and character.chef_meat_guard_available()
		and is_equal_approx(character.current_move_speed(), base_speed * 1.2)
		and character.sprite.texture.resource_path.ends_with("chef_reference_atlas_v9.png")
	)
	character.apply_binding(2.0)
	var stage_gimmick_blocked: bool = (
		not character.is_bound
		and not character.chef_meat_guard_available()
		and character.chef_meat_remaining() > 0.0
	)
	character.special_cooldown_remaining = 0.0
	character._attempt_special_skill()
	character._resolve_pending_special()
	character.take_damage()
	var crush_damage_applied: bool = (
		character.lives == 2
		and not character.chef_meat_guard_available()
	)
	character.lives = 3
	character._invulnerability_remaining = 0.0
	character.position = Vector2(5.5 * MainLayout.CELL_SIZE, 912.0)
	character.special_cooldown_remaining = 0.0
	character._attempt_special_skill()
	character._resolve_pending_special()
	character.take_thorn_damage("보스 공격 피해! 목숨 -1")
	var boss_hit_blocked: bool = (
		character.lives == 3
		and not character.chef_meat_guard_available()
		and character.chef_meat_remaining() > 0.0
	)
	for _frame: int in range(190):
		await physics_frame
	var expired: bool = (
		is_zero_approx(character.chef_meat_remaining())
		and is_equal_approx(character.current_move_speed(), base_speed)
	)
	print(
		"CHEF_MEAT_RUNTIME_RESULT input=", input_was_accepted,
		" buff=", buff_started,
		" gimmick=", stage_gimmick_blocked,
		" crush=", crush_damage_applied,
		" boss=", boss_hit_blocked,
		" expired=", expired
	)
	Input.action_release(&"character_special")
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	if (
		not input_was_accepted
		or not buff_started
		or not stage_gimmick_blocked
		or not crush_damage_applied
		or not boss_hit_blocked
		or not expired
	):
		push_error("Chef meat skill runtime contract failed.")
		quit(1)
		return
	quit(0)
