class_name MainGameEvent
extends RefCounted

## 규칙 상태가 실제로 커밋된 뒤 외부 소비자에게 전달하는 읽기 전용 사건 값이다.
## 셀 배열 getter는 매번 복제본을 반환해 View나 테스트가 원본 사건을 변형하지 못하게 한다.

enum Kind {
	FIREFIGHTER_WATER_COMMITTED,
	FIREFIGHTER_WATER_CLEARED,
	ABILITY_COMMITTED,
	ABILITY_CLEARED,
	ABILITY_CONSUMED,
	NINJA_PROJECTILE_IMPACTED,
}

enum ClearReason {
	NONE,
	EXPIRED,
	CHARACTER_RESET,
	CHARACTER_CHANGED,
	GAME_RESET,
	MANUAL,
}

const FIREFIGHTER_ABILITY_ID: StringName = &"firefighter"

var kind: Kind:
	get:
		return _kind
var ability_id: StringName:
	get:
		return _ability_id
var direction: int:
	get:
		return _direction
var duration_seconds: float:
	get:
		return _duration_seconds
var replaced_existing: bool:
	get:
		return _replaced_existing
var clear_reason: ClearReason:
	get:
		return _clear_reason
var cells: Array[Vector2i]:
	get:
		return _cells.duplicate()
var amount: int:
	get:
		return _amount
var position: Vector2:
	get:
		return _position
var contact: StringName:
	get:
		return _contact
var succeeded: bool:
	get:
		return _succeeded

var _kind: Kind
var _ability_id: StringName
var _cells: Array[Vector2i]
var _direction: int
var _duration_seconds: float
var _replaced_existing: bool
var _clear_reason: ClearReason
var _amount: int
var _position: Vector2
var _contact: StringName
var _succeeded: bool


func _init(
	event_kind: Kind,
	event_ability_id: StringName,
	event_cells: Array[Vector2i] = [],
	event_direction: int = 0,
	event_duration_seconds: float = 0.0,
	event_replaced_existing: bool = false,
	event_clear_reason: ClearReason = ClearReason.NONE,
	event_amount: int = 0,
	event_position: Vector2 = Vector2.ZERO,
	event_contact: StringName = &"",
	event_succeeded: bool = true
) -> void:
	_kind = event_kind
	_ability_id = event_ability_id
	_cells = event_cells.duplicate()
	_direction = event_direction
	_duration_seconds = event_duration_seconds
	_replaced_existing = event_replaced_existing
	_clear_reason = event_clear_reason
	_amount = event_amount
	_position = event_position
	_contact = event_contact
	_succeeded = event_succeeded


static func firefighter_water_committed(
	committed_cells: Array[Vector2i],
	committed_direction: int,
	committed_duration_seconds: float,
	did_replace_existing: bool
) -> MainGameEvent:
	return MainGameEvent.new(
		Kind.FIREFIGHTER_WATER_COMMITTED,
		FIREFIGHTER_ABILITY_ID,
		committed_cells,
		committed_direction,
		committed_duration_seconds,
		did_replace_existing
	)


static func firefighter_water_cleared(reason: ClearReason) -> MainGameEvent:
	return MainGameEvent.new(
		Kind.FIREFIGHTER_WATER_CLEARED,
		FIREFIGHTER_ABILITY_ID,
		[],
		0,
		0.0,
		false,
		reason
	)


static func ability_committed(
	committed_ability_id: StringName,
	committed_cells: Array[Vector2i] = [],
	committed_direction: int = 0,
	committed_duration_seconds: float = 0.0,
	committed_amount: int = 0,
	committed_position: Vector2 = Vector2.ZERO
) -> MainGameEvent:
	return MainGameEvent.new(
		Kind.ABILITY_COMMITTED,
		committed_ability_id,
		committed_cells,
		committed_direction,
		committed_duration_seconds,
		false,
		ClearReason.NONE,
		committed_amount,
		committed_position
	)


static func ability_cleared(
	cleared_ability_id: StringName,
	reason: ClearReason
) -> MainGameEvent:
	return MainGameEvent.new(
		Kind.ABILITY_CLEARED,
		cleared_ability_id,
		[],
		0,
		0.0,
		false,
		reason
	)


static func ability_consumed(
	consumed_ability_id: StringName,
	remaining_duration_seconds: float
) -> MainGameEvent:
	return MainGameEvent.new(
		Kind.ABILITY_CONSUMED,
		consumed_ability_id,
		[],
		0,
		remaining_duration_seconds,
		false,
		ClearReason.NONE,
		1
	)


static func ninja_projectile_impacted(
	impact_position: Vector2,
	impact_direction: int,
	impact_contact: StringName,
	impact_succeeded: bool
) -> MainGameEvent:
	return MainGameEvent.new(
		Kind.NINJA_PROJECTILE_IMPACTED,
		&"ninja",
		[],
		impact_direction,
		0.0,
		false,
		ClearReason.NONE,
		0,
		impact_position,
		impact_contact,
		impact_succeeded
	)
