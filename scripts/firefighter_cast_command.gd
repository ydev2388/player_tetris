class_name MainFirefighterCastCommand
extends RefCounted

## 소방관 입력이 접수된 순간의 위치와 방향을 고정하는 cast context다.
## 물길 길이와 지속시간은 플레이 규칙이므로 이 입력 값 객체에는 포함하지 않는다.

var start_cell: Vector2i:
	get:
		return _start_cell
var direction: int:
	get:
		return _direction

var _start_cell: Vector2i
var _direction: int


func _init(cast_start_cell: Vector2i, cast_direction: int) -> void:
	_start_cell = cast_start_cell
	_direction = cast_direction
