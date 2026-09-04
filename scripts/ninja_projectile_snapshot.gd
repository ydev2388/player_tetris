class_name MainNinjaProjectileSnapshot
extends RefCounted

## 닌자 투사체의 현재 표현 상태를 외부에 전달하는 불변 snapshot이다.

var position: Vector2:
	get:
		return _position
var direction: int:
	get:
		return _direction
var succeeded: bool:
	get:
		return _succeeded
var contact: StringName:
	get:
		return _contact
var in_flight: bool:
	get:
		return _in_flight
var impact_elapsed: float:
	get:
		return _impact_elapsed
var flight_elapsed: float:
	get:
		return _flight_elapsed

var _position: Vector2
var _direction: int
var _succeeded: bool
var _contact: StringName
var _in_flight: bool
var _impact_elapsed: float
var _flight_elapsed: float


func _init(
	current_position: Vector2,
	current_direction: int,
	did_succeed: bool,
	current_contact: StringName,
	is_currently_in_flight: bool,
	current_impact_elapsed: float,
	current_flight_elapsed: float
) -> void:
	_position = current_position
	_direction = current_direction
	_succeeded = did_succeed
	_contact = current_contact
	_in_flight = is_currently_in_flight
	_impact_elapsed = current_impact_elapsed
	_flight_elapsed = current_flight_elapsed
