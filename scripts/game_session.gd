class_name MainGameSession
extends RefCounted

## Pure one-run aggregate with no SceneTree or Node dependency.
## Owns board, piece queue, progress, deterministic random streams, persistent skill results,
## and player gameplay resources. GameController adapts lifecycle/delta/signals to this model.
var board_state: MainBoardModel = MainBoardModel.new()
var piece_queue: MainPieceBag = MainPieceBag.new()
var active_piece: MainActivePieceState = MainActivePieceState.new()
var game_state: int = 0
var meditation_active: bool = false

var active_type: int:
	get: return active_piece.piece_type
	set(value): active_piece.piece_type = value
var active_rotation: int:
	get: return active_piece.rotation
	set(value): active_piece.rotation = value
var active_origin: Vector2i:
	get: return active_piece.origin
	set(value): active_piece.origin = value
var active_cell_indices: Array[int]:
	get: return active_piece.cell_indices
	set(value): active_piece.cell_indices = value
var next_type: int = MainTetrominoData.Type.I
var active_piece_has_thorns: bool:
	get: return active_piece.has_thorns
	set(value): active_piece.has_thorns = value
var thorn_visible: bool:
	get: return active_piece.thorn_visible
	set(value): active_piece.thorn_visible = value
var thorn_phase_timer: float:
	get: return active_piece.thorn_phase_timer
	set(value): active_piece.thorn_phase_timer = value
var fall_accumulator: float:
	get: return active_piece.fall_accumulator
	set(value): active_piece.fall_accumulator = value
var lock_accumulator: float:
	get: return active_piece.lock_accumulator
	set(value): active_piece.lock_accumulator = value
var lock_resets: int:
	get: return active_piece.lock_resets
	set(value): active_piece.lock_resets = value

var score: int = 0
var level: int = 1
var total_lines: int = 0
var stage_number: int = 1
var challenge_mode: bool = false
var stage_time_remaining: float = 0.0
var shown_stage_seconds: int = 0

var boss_health: int = 0
var boss_fall_position: Vector2 = Vector2.ZERO
var boss_fall_target_y: float = 0.0
var boss_down_timer: float = 0.0
var boss_dying_timer: float = 0.0
var boss_fall_hold_timer: float = 0.0
var boss_down: bool = false
var boss_falling: bool = false
var boss_fallen: bool = false
var boss_seeds: Array[Dictionary] = []
var boss_seed_timer: float = 0.0
var boss_seed_first_cast_done: bool = false
var icicles: Array[Dictionary] = []
var icicle_check_timer: float = 0.0
var icicle_probability: float = 0.0
var icicle_first_check_pending: bool = true

var spawn_random: RandomNumberGenerator = RandomNumberGenerator.new()
var gimmick_random: RandomNumberGenerator = RandomNumberGenerator.new()
var gimmick_roll_overrides: Array[bool] = []
var binding_check_timer: float = 0.0
var binding_probability: float = 0.0
var binding_first_check_pending: bool = true

# Board에 투영되는 스킬 결과의 authoritative state.
# 외부에는 값/복제 스냅샷만 공개하고 변경은 아래 명령 메서드에서만 수행한다.
var fall_freeze_remaining: float:
	get: return _fall_freeze_remaining
var future_gimmick_freeze_remaining: float:
	get: return _future_gimmick_freeze_remaining
var transient_blocker_cells: Array[Vector2i]:
	get: return _transient_blocker_cells.duplicate()
var barrier_remaining: float:
	get: return _barrier_remaining
var barrier_direction: int:
	get: return _barrier_direction
var water_path_cells: Array[Vector2i]:
	get: return _water_path_cells.duplicate()
var water_path_direction: int:
	get: return _water_path_direction
var water_path_remaining: float:
	get: return _water_path_remaining

var _fall_freeze_remaining: float = 0.0
var _future_gimmick_freeze_remaining: float = 0.0
var _transient_blocker_cells: Array[Vector2i] = []
var _barrier_remaining: float = 0.0
var _barrier_direction: int = 0
var _water_path_cells: Array[Vector2i] = []
var _water_path_direction: int = 0
var _water_path_remaining: float = 0.0

# 캐릭터 Node가 사용하는 gameplay resource. 물리·애니메이션 시간은 포함하지 않는다.
var lives: int:
	get: return _lives
var rotation_cooldown_remaining: float:
	get: return _rotation_cooldown_remaining
var special_cooldown_remaining: float:
	get: return _special_cooldown_remaining

var _lives: int = 3
var _rotation_cooldown_remaining: float = 0.0
var _special_cooldown_remaining: float = 0.0


func reset_board_and_random(
	seed_value: int,
	spawn_seed_offset: int,
	gimmick_seed_offset: int
) -> void:
	board_state.reset()
	piece_queue = MainPieceBag.new(seed_value)
	if seed_value >= 0:
		spawn_random.seed = seed_value + spawn_seed_offset
		gimmick_random.seed = seed_value + gimmick_seed_offset
	else:
		spawn_random.randomize()
		gimmick_random.randomize()
	score = 0
	level = 1
	total_lines = 0
	fall_accumulator = 0.0
	lock_accumulator = 0.0
	lock_resets = 0


func reset_player_gameplay(max_lives: int) -> void:
	_lives = maxi(max_lives, 0)
	_rotation_cooldown_remaining = 0.0
	_special_cooldown_remaining = 0.0


func set_player_lives(value: int) -> void:
	_lives = maxi(value, 0)


func set_rotation_cooldown(value: float) -> void:
	_rotation_cooldown_remaining = maxf(value, 0.0)


func set_special_cooldown(value: float) -> void:
	_special_cooldown_remaining = maxf(value, 0.0)


func advance_player_cooldowns(delta: float) -> void:
	var elapsed := maxf(delta, 0.0)
	_rotation_cooldown_remaining = maxf(0.0, _rotation_cooldown_remaining - elapsed)
	_special_cooldown_remaining = maxf(0.0, _special_cooldown_remaining - elapsed)


func lose_life(amount: int = 1) -> int:
	_lives = maxi(0, _lives - maxi(amount, 0))
	return _lives


func board_snapshot() -> Dictionary:
	return board_state.create_snapshot()


func active_piece_snapshot() -> Dictionary:
	return active_piece.create_snapshot(next_type)


func progress_snapshot() -> Dictionary:
	return {
		"score": score,
		"level": level,
		"total_lines": total_lines,
		"stage_number": stage_number,
		"challenge_mode": challenge_mode,
		"stage_time_remaining": stage_time_remaining,
		"lives": _lives,
		"rotation_cooldown_remaining": _rotation_cooldown_remaining,
		"special_cooldown_remaining": _special_cooldown_remaining,
	}


func skill_effect_snapshot() -> Dictionary:
	return {
		"fall_freeze_remaining": _fall_freeze_remaining,
		"future_gimmick_freeze_remaining": _future_gimmick_freeze_remaining,
		"barrier_cells": _transient_blocker_cells.duplicate(),
		"barrier_direction": _barrier_direction,
		"barrier_remaining": _barrier_remaining,
		"water_path_cells": _water_path_cells.duplicate(),
		"water_path_direction": _water_path_direction,
		"water_path_remaining": _water_path_remaining,
	}


func has_water_path() -> bool:
	return not _water_path_cells.is_empty()


func execute_clockmaker_cast(command: MainAbilityCastCommand) -> MainCommandResult:
	var validation := _validate_ability_command(command, &"clockmaker", _is_playing())
	if not validation.ok:
		return validation
	_fall_freeze_remaining = MainGameRules.CLOCK_FREEZE_DURATION_SECONDS
	_future_gimmick_freeze_remaining = MainGameRules.CLOCK_FREEZE_DURATION_SECONDS
	var event := MainGameEvent.ability_committed(
		&"clockmaker", [], 0, MainGameRules.CLOCK_FREEZE_DURATION_SECONDS
	)
	return MainCommandResult.succeeded([event])


func execute_shield_guard_cast(
	command: MainAbilityCastCommand,
	active_cells: Array[Vector2i]
) -> MainCommandResult:
	var validation := _validate_ability_command(
		command, &"shield_guard", _is_playing(), true
	)
	if not validation.ok:
		return validation
	var available: Array[Vector2i] = []
	for cell: Vector2i in command.cells:
		if not board_state.is_inside(cell):
			continue
		if board_state.get_cell(cell) == MainBoardModel.EMPTY and cell not in active_cells:
			available.append(cell)
	if available.is_empty():
		return MainCommandResult.failed(
			MainCommandResult.NO_VALID_TARGET,
			"Shield guard cast has no free barrier cell."
		)
	_transient_blocker_cells = available.duplicate()
	_barrier_direction = command.direction
	_barrier_remaining = MainGameRules.SHIELD_BARRIER_DURATION_SECONDS
	var event := MainGameEvent.ability_committed(
		&"shield_guard", _transient_blocker_cells, _barrier_direction, _barrier_remaining
	)
	return MainCommandResult.succeeded([event])


func execute_firefighter_cast(command: MainFirefighterCastCommand) -> MainCommandResult:
	if not _is_playing():
		return MainCommandResult.failed(
			MainCommandResult.GAME_NOT_PLAYING,
			"Firefighter ability requires a playing game."
		)
	if command == null or not board_state.is_inside(command.start_cell):
		return MainCommandResult.failed(
			MainCommandResult.INVALID_START_CELL,
			"Firefighter cast start cell is outside the board."
		)
	if not MainGameRules.is_direction_valid(command.direction):
		return MainCommandResult.failed(
			MainCommandResult.INVALID_DIRECTION,
			"Firefighter cast direction must be -1 or 1."
		)

	var candidate_cells: Array[Vector2i] = []
	var cursor: Vector2i = command.start_cell
	for _step: int in range(MainGameRules.FIREFIGHTER_WATER_MAX_STEPS):
		if cursor.x < 0 or cursor.x >= MainBoardModel.WIDTH:
			break
		while cursor.y < MainBoardModel.HEIGHT - 1:
			var below := cursor + Vector2i.DOWN
			if board_state.get_cell(below) != MainBoardModel.EMPTY:
				break
			cursor = below
		if board_state.get_cell(cursor) != MainBoardModel.EMPTY:
			break
		if cursor not in candidate_cells:
			candidate_cells.append(cursor)
		var next := cursor + Vector2i(command.direction, 0)
		if next.x < 0 or next.x >= MainBoardModel.WIDTH:
			break
		if board_state.get_cell(next) != MainBoardModel.EMPTY:
			break
		cursor = next
	if candidate_cells.is_empty():
		return MainCommandResult.failed(
			MainCommandResult.PATH_BLOCKED,
			"Firefighter cast could not create a water path."
		)

	var replaced_existing: bool = has_water_path()
	_water_path_cells = candidate_cells.duplicate()
	_water_path_direction = command.direction
	_water_path_remaining = MainGameRules.FIREFIGHTER_WATER_DURATION_SECONDS
	var event := MainGameEvent.firefighter_water_committed(
		_water_path_cells, _water_path_direction, _water_path_remaining, replaced_existing
	)
	return MainCommandResult.succeeded([event])


func clear_clockmaker(reason: int) -> MainCommandResult:
	if _fall_freeze_remaining <= 0.0 and _future_gimmick_freeze_remaining <= 0.0:
		return MainCommandResult.failed(
			MainCommandResult.NO_ACTIVE_EFFECT,
			"There is no active clockmaker freeze to clear."
		)
	_fall_freeze_remaining = 0.0
	_future_gimmick_freeze_remaining = 0.0
	return MainCommandResult.succeeded([MainGameEvent.ability_cleared(&"clockmaker", reason)])


func clear_barrier(reason: int) -> MainCommandResult:
	if _transient_blocker_cells.is_empty():
		return MainCommandResult.failed(
			MainCommandResult.NO_ACTIVE_EFFECT,
			"There is no active shield barrier to clear."
		)
	_transient_blocker_cells.clear()
	_barrier_remaining = 0.0
	_barrier_direction = 0
	return MainCommandResult.succeeded([MainGameEvent.ability_cleared(&"shield_guard", reason)])


func clear_water_path(reason: int) -> MainCommandResult:
	if not has_water_path():
		return MainCommandResult.failed(
			MainCommandResult.NO_ACTIVE_EFFECT,
			"There is no active firefighter water path to clear."
		)
	_water_path_cells.clear()
	_water_path_direction = 0
	_water_path_remaining = 0.0
	return MainCommandResult.succeeded([MainGameEvent.firefighter_water_cleared(reason)])


func clear_skill_effects(reason: int) -> Array[MainGameEvent]:
	var events: Array[MainGameEvent] = []
	if _fall_freeze_remaining > 0.0 or _future_gimmick_freeze_remaining > 0.0:
		events.append(MainGameEvent.ability_cleared(&"clockmaker", reason))
	if not _transient_blocker_cells.is_empty():
		events.append(MainGameEvent.ability_cleared(&"shield_guard", reason))
	if has_water_path():
		events.append(MainGameEvent.firefighter_water_cleared(reason))
	_fall_freeze_remaining = 0.0
	_future_gimmick_freeze_remaining = 0.0
	_transient_blocker_cells.clear()
	_barrier_remaining = 0.0
	_barrier_direction = 0
	_water_path_cells.clear()
	_water_path_direction = 0
	_water_path_remaining = 0.0
	return events


func advance_clockmaker(delta: float) -> MainCommandResult:
	if _fall_freeze_remaining <= 0.0 and _future_gimmick_freeze_remaining <= 0.0:
		return MainCommandResult.failed(
			MainCommandResult.NO_ACTIVE_EFFECT,
			"There is no active clockmaker freeze to advance."
		)
	var elapsed := maxf(delta, 0.0)
	_fall_freeze_remaining = maxf(0.0, _fall_freeze_remaining - elapsed)
	_future_gimmick_freeze_remaining = maxf(0.0, _future_gimmick_freeze_remaining - elapsed)
	if (
		_fall_freeze_remaining <= MainGameRules.TIMER_EPSILON_SECONDS
		and _future_gimmick_freeze_remaining <= MainGameRules.TIMER_EPSILON_SECONDS
	):
		_fall_freeze_remaining = 0.0
		_future_gimmick_freeze_remaining = 0.0
		return MainCommandResult.succeeded([
			MainGameEvent.ability_cleared(&"clockmaker", MainGameEvent.ClearReason.EXPIRED)
		])
	return MainCommandResult.succeeded()


func advance_barrier(delta: float) -> MainCommandResult:
	if _transient_blocker_cells.is_empty():
		return MainCommandResult.failed(
			MainCommandResult.NO_ACTIVE_EFFECT,
			"There is no active shield barrier to advance."
		)
	_barrier_remaining = maxf(0.0, _barrier_remaining - maxf(delta, 0.0))
	if _barrier_remaining <= MainGameRules.TIMER_EPSILON_SECONDS:
		return clear_barrier(MainGameEvent.ClearReason.EXPIRED)
	return MainCommandResult.succeeded()


func advance_water_path(delta: float) -> MainCommandResult:
	if not has_water_path():
		return MainCommandResult.failed(
			MainCommandResult.NO_ACTIVE_EFFECT,
			"There is no active firefighter water path to advance."
		)
	_water_path_remaining = maxf(0.0, _water_path_remaining - maxf(delta, 0.0))
	if _water_path_remaining <= MainGameRules.TIMER_EPSILON_SECONDS:
		return clear_water_path(MainGameEvent.ClearReason.EXPIRED)
	return MainCommandResult.succeeded()


func _is_playing() -> bool:
	return game_state == MainGameRules.PLAYING_STATE


func _validate_ability_command(
	command: MainAbilityCastCommand,
	expected_ability_id: StringName,
	is_playing: bool,
	require_direction: bool = false
) -> MainCommandResult:
	if not is_playing:
		return MainCommandResult.failed(
			MainCommandResult.GAME_NOT_PLAYING,
			"Ability command requires a playing game."
		)
	if command == null or command.ability_id != expected_ability_id:
		return MainCommandResult.failed(
			MainCommandResult.INVALID_ABILITY,
			"Ability command does not match the execution boundary."
		)
	if require_direction and command.direction != -1 and command.direction != 1:
		return MainCommandResult.failed(
			MainCommandResult.INVALID_DIRECTION,
			"Ability cast direction must be -1 or 1."
		)
	return MainCommandResult.succeeded()
