class_name MainCharacterAbilityPolicy
extends RefCounted

enum ExecutorScope { CHARACTER, GAME }

var character_id: StringName
var delay_seconds: float
var requires_ground: bool
var command_builder: Callable
var executor_scope: ExecutorScope
var executor: Callable


func _init(
	p_character_id: StringName,
	p_delay_seconds: float,
	p_requires_ground: bool,
	p_command_builder: Callable,
	p_executor_scope: ExecutorScope,
	p_executor: Callable
) -> void:
	character_id = p_character_id
	delay_seconds = maxf(p_delay_seconds, 0.0)
	requires_ground = p_requires_ground
	command_builder = p_command_builder
	executor_scope = p_executor_scope
	executor = p_executor


func build_command(context: Dictionary) -> Variant:
	return command_builder.call(self, context) if command_builder.is_valid() else null


func execute_command(
	command: Variant,
	game_controller: Object,
	character_controller: Object
) -> MainCommandResult:
	if not executor.is_valid():
		return MainCommandResult.failed(
			MainCommandResult.INVALID_ABILITY,
			"Ability policy executor is unavailable."
		)
	var result: Variant = executor.call(command, game_controller, character_controller)
	if not result is MainCommandResult:
		return MainCommandResult.failed(
			MainCommandResult.INVALID_ABILITY,
			"Ability policy executor returned an invalid result."
		)
	return result as MainCommandResult
