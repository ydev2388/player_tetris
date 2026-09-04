class_name MainCharacterAbilityResolver
extends RefCounted

## Data-driven policy registry. New characters add one policy row and, only when needed,
## one focused command builder/handler instead of extending CharacterController matches.
var _policies: Dictionary = {}


func _init() -> void:
	_register(&"normal", 0.0, false, Callable(self, "_build_simple"), MainCharacterAbilityPolicy.ExecutorScope.CHARACTER, Callable(self, "_execute_normal"))
	_register(&"boxer", 0.25, false, Callable(self, "_build_boxer"), MainCharacterAbilityPolicy.ExecutorScope.GAME, Callable(self, "_execute_boxer"))
	_register(&"shield_guard", 0.25, false, Callable(self, "_build_shield"), MainCharacterAbilityPolicy.ExecutorScope.GAME, Callable(self, "_execute_shield"))
	_register(&"firefighter", 0.6, true, Callable(self, "_build_firefighter"), MainCharacterAbilityPolicy.ExecutorScope.GAME, Callable(self, "_execute_firefighter"))
	_register(&"cleaner", 0.4, true, Callable(self, "_build_cleaner"), MainCharacterAbilityPolicy.ExecutorScope.GAME, Callable(self, "_execute_cleaner"))
	_register(&"chef", 0.3, false, Callable(self, "_build_simple"), MainCharacterAbilityPolicy.ExecutorScope.CHARACTER, Callable(self, "_execute_chef"))
	_register(&"clockmaker", 0.4, false, Callable(self, "_build_simple"), MainCharacterAbilityPolicy.ExecutorScope.GAME, Callable(self, "_execute_clockmaker"))
	_register(&"ninja", 0.25, false, Callable(self, "_build_ninja"), MainCharacterAbilityPolicy.ExecutorScope.CHARACTER, Callable(self, "_execute_ninja"))


func policy_for(character_id: String) -> MainCharacterAbilityPolicy:
	return _policies.get(StringName(character_id)) as MainCharacterAbilityPolicy


func supported_character_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for character_id: StringName in _policies:
		result.append(character_id)
	return result


func prepare(character_id: String, context: Dictionary) -> MainPreparedCharacterAbility:
	var policy := policy_for(character_id)
	if policy == null:
		return null
	return MainPreparedCharacterAbility.new(policy, policy.build_command(context))


func execute(
	prepared: MainPreparedCharacterAbility,
	game_controller: Object,
	character_controller: Object
) -> MainCommandResult:
	if prepared == null or prepared.policy == null or prepared.command == null:
		return MainCommandResult.failed(
			MainCommandResult.INVALID_ABILITY,
			"Ability policy did not produce a command."
		)
	return prepared.policy.execute_command(
		prepared.command, game_controller, character_controller
	)


func _register(
	character_id: StringName,
	delay_seconds: float,
	requires_ground: bool,
	command_builder: Callable,
	executor_scope: int,
	executor: Callable
) -> void:
	_policies[character_id] = MainCharacterAbilityPolicy.new(
		character_id,
		delay_seconds,
		requires_ground,
		command_builder,
		executor_scope,
		executor
	)


func _build_simple(policy: MainCharacterAbilityPolicy, _context: Dictionary) -> MainAbilityCastCommand:
	return MainAbilityCastCommand.new(policy.character_id)


func _build_boxer(policy: MainCharacterAbilityPolicy, context: Dictionary) -> MainAbilityCastCommand:
	return MainAbilityCastCommand.new(
		policy.character_id,
		context["position"],
		Vector2i.ZERO,
		context["direction"],
		context["boxer_cells"]
	)


func _build_shield(policy: MainCharacterAbilityPolicy, context: Dictionary) -> MainAbilityCastCommand:
	return MainAbilityCastCommand.new(
		policy.character_id,
		context["position"],
		Vector2i.ZERO,
		context["direction"],
		context["barrier_cells"]
	)


func _build_firefighter(
	_policy: MainCharacterAbilityPolicy,
	context: Dictionary
) -> MainFirefighterCastCommand:
	return MainFirefighterCastCommand.new(context["front_cell"], context["direction"])


func _build_cleaner(policy: MainCharacterAbilityPolicy, context: Dictionary) -> MainAbilityCastCommand:
	return MainAbilityCastCommand.new(
		policy.character_id,
		context["position"],
		context["below_cell"],
		context["direction"]
	)


func _build_ninja(policy: MainCharacterAbilityPolicy, context: Dictionary) -> MainAbilityCastCommand:
	var start_cell: Vector2i = context["front_cell"] - Vector2i(context["direction"], 0)
	var start_position := Vector2(
		(float(start_cell.x) + 0.5) * MainLayout.CELL_SIZE,
		(float(start_cell.y - MainBoardModel.HIDDEN_ROWS) + 0.5) * MainLayout.CELL_SIZE
	)
	return MainAbilityCastCommand.new(
		policy.character_id,
		start_position,
		start_cell,
		context["direction"]
	)


func _require_game(target: Object) -> MainGameController:
	return target as MainGameController


func _require_character(target: Object) -> MainCharacterController:
	return target as MainCharacterController


func _execute_normal(command: Variant, _game: Object, character: Object) -> MainCommandResult:
	var target := _require_character(character)
	return target.commit_normal_ability(command) if target != null else _missing_executor()


func _execute_boxer(command: Variant, game: Object, _character: Object) -> MainCommandResult:
	var target := _require_game(game)
	return target.execute_boxer_cast(command) if target != null else _missing_executor()


func _execute_shield(command: Variant, game: Object, _character: Object) -> MainCommandResult:
	var target := _require_game(game)
	return target.execute_shield_guard_cast(command) if target != null else _missing_executor()


func _execute_firefighter(command: Variant, game: Object, _character: Object) -> MainCommandResult:
	var target := _require_game(game)
	return target.execute_firefighter_cast(command) if target != null else _missing_executor()


func _execute_cleaner(command: Variant, game: Object, _character: Object) -> MainCommandResult:
	var target := _require_game(game)
	return target.execute_cleaner_cast(command) if target != null else _missing_executor()


func _execute_chef(command: Variant, _game: Object, character: Object) -> MainCommandResult:
	var target := _require_character(character)
	return target.commit_chef_ability(command) if target != null else _missing_executor()


func _execute_clockmaker(command: Variant, game: Object, _character: Object) -> MainCommandResult:
	var target := _require_game(game)
	return target.execute_clockmaker_cast(command) if target != null else _missing_executor()


func _execute_ninja(command: Variant, _game: Object, character: Object) -> MainCommandResult:
	var target := _require_character(character)
	return target.commit_ninja_ability(command) if target != null else _missing_executor()


func _missing_executor() -> MainCommandResult:
	return MainCommandResult.failed(
		MainCommandResult.INVALID_ABILITY,
		"Ability policy executor target is unavailable."
	)
