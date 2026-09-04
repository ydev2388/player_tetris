extends SceneTree

## Layer 1 evidence: RefCounted domain contracts only.
## This suite never instantiates a PackedScene or gameplay Node. Each command is checked as
## previous snapshot + command -> committed snapshot + events, or unchanged snapshot on failure.

const PLAYING_STATE: int = MainGameRules.PLAYING_STATE
const EFFECT_DURATION: float = MainGameRules.FIREFIGHTER_WATER_DURATION_SECONDS

var _checks: int = 0
var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_board_contracts()
	_test_game_session_contracts()
	_test_progression_contracts()
	if _failures == 0:
		print("성공: 순수 계약 테스트 %d개 통과" % _checks)
		print("TEST_RESULT suite=pure_contract checks=%d failures=0" % _checks)
	else:
		push_error("실패: 순수 계약 테스트 %d/%d개 실패" % [_failures, _checks])
		print("TEST_RESULT suite=pure_contract checks=%d failures=%d" % [_checks, _failures])
	quit(_failures)


func _test_board_contracts() -> void:
	var board := MainBoardModel.new()
	var local_cells: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
	]
	var initial_snapshot: Dictionary = board.create_snapshot()
	_expect(
		board.lock_cells(MainTetrominoData.Type.O, local_cells, Vector2i(3, 5), true),
		"Board 유효 lock 명령은 성공한다."
	)
	_expect(
		board.get_cell(Vector2i(3, 5)) == MainTetrominoData.Type.O
			and board.is_ice_cell(Vector2i(4, 6)),
		"Board 성공 lock은 셀과 얼음 metadata를 함께 커밋한다."
	)
	_expect(
		board.create_snapshot() != initial_snapshot,
		"Board 성공 명령 뒤 snapshot은 이전 상태와 다르다."
	)

	var before_duplicate: Dictionary = board.create_snapshot()
	var duplicate_cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]
	_expect(
		not board.lock_cells(
			MainTetrominoData.Type.I, duplicate_cells, Vector2i(0, 0)
		),
		"Board 중복 좌표 lock은 실패한다."
	)
	_expect(
		board.create_snapshot() == before_duplicate,
		"Board 중복 좌표 실패는 전체 snapshot을 유지한다."
	)

	var before_occupied: Dictionary = board.create_snapshot()
	_expect(
		not board.lock_cells(
			MainTetrominoData.Type.I, [Vector2i.ZERO], Vector2i(3, 5)
		),
		"Board 점유 셀 lock은 실패한다."
	)
	_expect(
		board.create_snapshot() == before_occupied,
		"Board 점유 실패는 셀과 metadata snapshot을 모두 유지한다."
	)

	var detached_board_snapshot: Dictionary = board.create_snapshot()
	var detached_rows: Array = detached_board_snapshot["cells"] as Array
	var detached_row: PackedInt32Array = detached_rows[0]
	detached_row[0] = MainTetrominoData.Type.T
	_expect(
		board.get_cell(Vector2i.ZERO) == MainBoardModel.EMPTY,
		"Board snapshot 변경은 원본 보드를 오염시키지 않는다."
	)


func _test_game_session_contracts() -> void:
	var session := MainGameSession.new()
	session.game_state = PLAYING_STATE
	var initial_skill_snapshot: Dictionary = session.skill_effect_snapshot()
	var firefighter_command := MainFirefighterCastCommand.new(Vector2i(2, 2), 1)
	var firefighter_result: MainCommandResult = session.execute_firefighter_cast(
		firefighter_command
	)
	_expect(
		firefighter_result.ok and firefighter_result.code == MainCommandResult.OK,
		"소방관 유효 명령은 안정적인 ok 결과를 반환한다."
	)
	_expect(
		session.skill_effect_snapshot() != initial_skill_snapshot
			and session.water_path_remaining == EFFECT_DURATION
			and session.water_path_direction == 1,
		"소방관 성공 명령은 물길 셀·방향·수명을 한 번에 커밋한다."
	)
	var firefighter_events: Array[MainGameEvent] = firefighter_result.events
	var firefighter_event: MainGameEvent = firefighter_events[0]
	_expect(
		firefighter_events.size() == 1
			and firefighter_event.kind == MainGameEvent.Kind.FIREFIGHTER_WATER_COMMITTED
			and firefighter_event.cells == session.water_path_cells
			and firefighter_event.direction == session.water_path_direction
			and firefighter_event.duration_seconds == session.water_path_remaining,
		"소방관 성공 사건 payload는 커밋된 session snapshot과 일치한다."
	)
	var detached_event_cells: Array[Vector2i] = firefighter_event.cells
	detached_event_cells.clear()
	firefighter_events.clear()
	_expect(
		not firefighter_event.cells.is_empty()
			and firefighter_result.events.size() == 1
			and session.has_water_path(),
		"명령 결과와 사건 배열 변경은 사건과 session 원본을 오염시키지 않는다."
	)

	var before_invalid_direction: Dictionary = session.skill_effect_snapshot()
	var invalid_direction_result: MainCommandResult = session.execute_firefighter_cast(
		MainFirefighterCastCommand.new(Vector2i(4, 4), 0)
	)
	_expect(
		not invalid_direction_result.ok
			and invalid_direction_result.code == MainCommandResult.INVALID_DIRECTION
			and invalid_direction_result.events.is_empty(),
		"소방관 잘못된 방향은 안정적인 실패 code와 빈 사건을 반환한다."
	)
	_expect(
		session.skill_effect_snapshot() == before_invalid_direction,
		"소방관 방향 검증 실패는 기존 물길 snapshot을 유지한다."
	)

	var blocked_cell := Vector2i(5, MainBoardModel.HEIGHT - 1)
	session.board_state.set_cell(blocked_cell, MainTetrominoData.Type.T)
	var before_blocked_path: Dictionary = session.skill_effect_snapshot()
	var blocked_result: MainCommandResult = session.execute_firefighter_cast(
		MainFirefighterCastCommand.new(blocked_cell, 1)
	)
	_expect(
		not blocked_result.ok
			and blocked_result.code == MainCommandResult.PATH_BLOCKED
			and blocked_result.events.is_empty(),
		"소방관 막힌 경로는 path_blocked와 빈 사건을 반환한다."
	)
	_expect(
		session.skill_effect_snapshot() == before_blocked_path,
		"소방관 경로 실패는 이전 효과 snapshot을 유지한다."
	)

	var replacement_result: MainCommandResult = session.execute_firefighter_cast(
		MainFirefighterCastCommand.new(Vector2i(8, 1), -1)
	)
	var replacement_event: MainGameEvent = replacement_result.events[0]
	_expect(
		replacement_result.ok
			and replacement_result.events.size() == 1
			and replacement_event.replaced_existing,
		"기존 물길 교체는 중간 제거 없이 교체 사건 하나만 반환한다."
	)
	_expect(
		session.water_path_direction == -1
			and session.water_path_remaining == EFFECT_DURATION
			and replacement_event.cells == session.water_path_cells,
		"물길 교체 사건은 새 committed snapshot만 투영한다."
	)

	var clear_result: MainCommandResult = session.clear_water_path(MainGameEvent.ClearReason.MANUAL)
	_expect(
		clear_result.ok
			and clear_result.events.size() == 1
			and clear_result.events[0].kind == MainGameEvent.Kind.FIREFIGHTER_WATER_CLEARED
			and clear_result.events[0].clear_reason == MainGameEvent.ClearReason.MANUAL,
		"물길 제거 성공은 이유가 있는 제거 사건 하나를 반환한다."
	)
	_expect(
		not session.has_water_path()
			and session.water_path_direction == 0
			and session.water_path_remaining == 0.0,
		"물길 제거 뒤 빈 효과 불변식이 성립한다."
	)
	var before_empty_clear: Dictionary = session.skill_effect_snapshot()
	var empty_clear_result: MainCommandResult = session.clear_water_path(
		MainGameEvent.ClearReason.MANUAL
	)
	_expect(
		not empty_clear_result.ok
			and empty_clear_result.code == MainCommandResult.NO_ACTIVE_EFFECT
			and empty_clear_result.events.is_empty(),
		"빈 물길 제거는 no_active_effect와 빈 사건을 반환한다."
	)
	_expect(
		session.skill_effect_snapshot() == before_empty_clear,
		"빈 물길 제거 실패는 snapshot을 유지한다."
	)

	var barrier_cells: Array[Vector2i] = [
		Vector2i(1, 8), Vector2i(1, 9), Vector2i(1, 10),
	]
	var barrier_command := MainAbilityCastCommand.new(
		&"shield_guard", Vector2.ZERO, Vector2i.ZERO, 1, barrier_cells
	)
	var barrier_result: MainCommandResult = session.execute_shield_guard_cast(
		barrier_command, []
	)
	_expect(
		barrier_result.ok
			and session.transient_blocker_cells == barrier_cells
			and session.barrier_direction == 1
			and session.barrier_remaining == 2.0,
		"방패 유효 명령은 후보 셀·방향·수명을 함께 커밋한다."
	)
	_expect(
		barrier_result.events.size() == 1
			and barrier_result.events[0].ability_id == &"shield_guard"
			and barrier_result.events[0].cells == barrier_cells,
		"방패 커밋 사건은 실제 barrier snapshot과 일치한다."
	)
	var before_invalid_barrier: Dictionary = session.skill_effect_snapshot()
	var invalid_barrier_result: MainCommandResult = session.execute_shield_guard_cast(
		MainAbilityCastCommand.new(
			&"shield_guard", Vector2.ZERO, Vector2i.ZERO, 0, barrier_cells
		),
		[]
	)
	_expect(
		not invalid_barrier_result.ok
			and invalid_barrier_result.code == MainCommandResult.INVALID_DIRECTION
			and invalid_barrier_result.events.is_empty(),
		"방패 잘못된 방향은 안정적인 실패 code와 빈 사건을 반환한다."
	)
	_expect(
		session.skill_effect_snapshot() == before_invalid_barrier,
		"방패 검증 실패는 기존 barrier snapshot을 유지한다."
	)

	var clock_result: MainCommandResult = session.execute_clockmaker_cast(
		MainAbilityCastCommand.new(&"clockmaker")
	)
	_expect(
		clock_result.ok
			and session.fall_freeze_remaining == 3.0
			and session.future_gimmick_freeze_remaining == 3.0,
		"시계공 유효 명령은 두 시간정지 값을 원자적으로 커밋한다."
	)
	_expect(
		clock_result.events.size() == 1
			and clock_result.events[0].ability_id == &"clockmaker"
			and clock_result.events[0].duration_seconds == 3.0,
		"시계공 사건은 커밋된 duration을 전달한다."
	)
	var before_wrong_ability: Dictionary = session.skill_effect_snapshot()
	var wrong_ability_result: MainCommandResult = session.execute_clockmaker_cast(
		MainAbilityCastCommand.new(&"firefighter")
	)
	_expect(
		not wrong_ability_result.ok
			and wrong_ability_result.code == MainCommandResult.INVALID_ABILITY
			and wrong_ability_result.events.is_empty(),
		"잘못된 aggregate의 명령은 invalid_ability와 빈 사건을 반환한다."
	)
	_expect(
		session.skill_effect_snapshot() == before_wrong_ability,
		"ability aggregate 불일치 실패는 전체 효과 snapshot을 유지한다."
	)

	var refill_water: MainCommandResult = session.execute_firefighter_cast(
		MainFirefighterCastCommand.new(Vector2i(7, 0), -1)
	)
	_expect(refill_water.ok, "일괄 제거 fixture의 물길 명령이 성공한다.")
	var cleared_events: Array[MainGameEvent] = session.clear_skill_effects(
		MainGameEvent.ClearReason.GAME_RESET
	)
	_expect(
		cleared_events.size() == 3,
		"일괄 제거는 활성 시계공·방패·물길마다 사건을 정확히 하나 반환한다."
	)
	var cleared_snapshot: Dictionary = session.skill_effect_snapshot()
	_expect(
		float(cleared_snapshot["fall_freeze_remaining"]) == 0.0
			and float(cleared_snapshot["future_gimmick_freeze_remaining"]) == 0.0
			and (cleared_snapshot["barrier_cells"] as Array).is_empty()
			and (cleared_snapshot["water_path_cells"] as Array).is_empty(),
		"일괄 제거 뒤 모든 지속 효과가 하나의 빈 snapshot으로 커밋된다."
	)
	var all_clear_reasons_match: bool = true
	for cleared_event: MainGameEvent in cleared_events:
		if cleared_event.clear_reason != MainGameEvent.ClearReason.GAME_RESET:
			all_clear_reasons_match = false
	_expect(
		all_clear_reasons_match,
		"일괄 제거 사건은 동일한 game_reset 이유를 전달한다."
	)

	var detached_water_cells: Array[Vector2i] = session.water_path_cells
	detached_water_cells.append(Vector2i(99, 99))
	_expect(
		not session.has_water_path() and Vector2i(99, 99) not in session.water_path_cells,
		"Session의 셀 getter는 원본 컬렉션을 외부에 노출하지 않는다."
	)

	var before_inactive_cast: Dictionary = session.skill_effect_snapshot()
	session.game_state = 4
	var inactive_cast: MainCommandResult = session.execute_firefighter_cast(
		MainFirefighterCastCommand.new(Vector2i(2, 2), 1)
	)
	_expect(
		not inactive_cast.ok
			and inactive_cast.code == MainCommandResult.GAME_NOT_PLAYING
			and inactive_cast.events.is_empty(),
		"Session은 외부 playing-state 인자 없이 자신의 game_state로 명령을 검증한다."
	)
	_expect(
		session.skill_effect_snapshot() == before_inactive_cast,
		"비활성 게임의 스킬 실패는 효과 snapshot을 유지한다."
	)

	session.game_state = PLAYING_STATE
	var timed_water: MainCommandResult = session.execute_firefighter_cast(
		MainFirefighterCastCommand.new(Vector2i(3, 2), 1)
	)
	var water_progress: MainCommandResult = session.advance_water_path(EFFECT_DURATION - 0.1)
	_expect(
		timed_water.ok
			and water_progress.ok
			and water_progress.events.is_empty()
			and is_equal_approx(session.water_path_remaining, 0.1),
		"물길 시간 진행은 만료 전까지 사건 없이 양수 불변식을 유지한다."
	)
	var water_expiry: MainCommandResult = session.advance_water_path(0.1)
	_expect(
		water_expiry.ok
			and water_expiry.events.size() == 1
			and water_expiry.events[0].clear_reason == MainGameEvent.ClearReason.EXPIRED
			and not session.has_water_path()
			and session.water_path_direction == 0
			and session.water_path_remaining == 0.0,
		"물길 만료는 셀·방향·시간을 한 번에 비우고 제거 사건 하나를 만든다."
	)
	var repeated_expiry: MainCommandResult = session.advance_water_path(1.0)
	_expect(
		not repeated_expiry.ok and repeated_expiry.events.is_empty(),
		"이미 만료된 물길은 중복 제거 사건을 만들지 않는다."
	)

	session.set_player_lives(-3)
	session.set_rotation_cooldown(-1.0)
	session.set_special_cooldown(2.0)
	session.advance_player_cooldowns(0.5)
	_expect(
		session.lives == 0
			and session.rotation_cooldown_remaining == 0.0
			and is_equal_approx(session.special_cooldown_remaining, 1.5),
		"생명과 gameplay cooldown 명령은 음수 불변식과 실제 delta 감소를 지킨다."
	)

	var timed_clock: MainCommandResult = session.execute_clockmaker_cast(
		MainAbilityCastCommand.new(&"clockmaker")
	)
	var clock_expiry: MainCommandResult = session.advance_clockmaker(
		MainGameRules.CLOCK_FREEZE_DURATION_SECONDS
	)
	_expect(
		timed_clock.ok
			and clock_expiry.events.size() == 1
			and clock_expiry.events[0].clear_reason == MainGameEvent.ClearReason.EXPIRED
			and session.fall_freeze_remaining == 0.0
			and session.future_gimmick_freeze_remaining == 0.0,
		"시계공 만료도 Session 내부에서 원자적으로 정리되고 사건 하나를 반환한다."
	)


func _test_progression_contracts() -> void:
	var progress := BlockFighterProgressionService.new()
	var initial_snapshot: Dictionary = progress.snapshot()
	_expect(
		progress.is_stage_unlocked(1)
			and not progress.is_stage_unlocked(2)
			and progress.star_currency == 0,
		"진행도 기본 snapshot은 1층만 해금하고 재화가 없다."
	)
	var clear_result: Dictionary = progress.complete_stage(1, 3, 2, true)
	_expect(
		bool(clear_result.get("ok", false))
			and bool(clear_result.get("changed", false))
			and int(clear_result.get("reward", -1)) == 3,
		"진행도 유효 완료 명령은 최고 별 차액 결과를 반환한다."
	)
	_expect(
		progress.get_stage_best_stars(1) == 3
			and progress.star_currency == 3
			and progress.is_stage_unlocked(2)
			and progress.is_stage_cleared_without_damage(1),
		"진행도 완료 결과와 새 snapshot의 별·해금·무피해가 일치한다."
	)
	_expect(
		progress.snapshot() != initial_snapshot,
		"진행도 성공 명령은 이전 snapshot과 다른 새 상태를 만든다."
	)

	var before_repeat: Dictionary = progress.snapshot()
	var repeat_result: Dictionary = progress.complete_stage(1, 3, 2, true)
	_expect(
		bool(repeat_result.get("ok", false))
			and not bool(repeat_result.get("changed", true))
			and int(repeat_result.get("reward", -1)) == 0,
		"동일 성과 재완료는 성공하지만 변경·중복 보상이 없다."
	)
	_expect(
		progress.snapshot() == before_repeat,
		"동일 성과 재완료는 진행도 snapshot을 유지한다."
	)

	var before_invalid_stage: Dictionary = progress.snapshot()
	var invalid_stage_result: Dictionary = progress.complete_stage(0, 3)
	_expect(
		not bool(invalid_stage_result.get("ok", false)),
		"범위 밖 스테이지 완료 명령은 실패한다."
	)
	_expect(
		progress.snapshot() == before_invalid_stage,
		"범위 밖 진행도 명령 실패는 전체 snapshot을 유지한다."
	)

	progress.star_currency = 0
	var before_insufficient_upgrade: Dictionary = progress.snapshot()
	var insufficient_result: Dictionary = progress.upgrade_passive("health")
	_expect(
		not bool(insufficient_result.get("ok", false)),
		"재화가 부족한 패시브 강화 명령은 실패한다."
	)
	_expect(
		progress.snapshot() == before_insufficient_upgrade,
		"패시브 강화 실패는 재화와 레벨 snapshot을 유지한다."
	)

	progress.star_currency = 6
	var upgrade_result: Dictionary = progress.upgrade_passive("health")
	_expect(
		bool(upgrade_result.get("ok", false))
			and progress.get_passive_level("health") == 1
			and progress.star_currency == 5,
		"패시브 강화 성공 결과와 새 레벨·재화 snapshot이 일치한다."
	)
	var reset_result: Dictionary = progress.reset_passive_upgrades()
	_expect(
		bool(reset_result.get("ok", false))
			and int(reset_result.get("refund", -1)) == 1
			and progress.get_passive_level("health") == 0
			and progress.star_currency == 6,
		"패시브 초기화 결과와 환급된 snapshot이 일치한다."
	)

	var detached_progress_snapshot: Dictionary = progress.snapshot()
	(detached_progress_snapshot["stage_best_stars"] as Array)[0] = 0
	(detached_progress_snapshot["passive_levels"] as Array)[0] = 3
	_expect(
		progress.get_stage_best_stars(1) == 3
			and progress.get_passive_level("attack_speed") == 0,
		"진행도 snapshot 배열 변경은 서비스 원본을 오염시키지 않는다."
	)


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  [통과] %s" % description)
	else:
		_failures += 1
		push_error("  [실패] %s" % description)
