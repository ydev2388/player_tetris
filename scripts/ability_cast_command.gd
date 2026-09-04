class_name MainAbilityCastCommand
extends RefCounted

## 입력이 받아들여진 순간의 캐릭터 특수 스킬 문맥을 고정하는 읽기 전용 값이다.
## 각 스킬은 필요한 필드만 사용하며, 셀 배열은 별칭 오염을 막기 위해 복제한다.

var ability_id: StringName:
	get:
		return _ability_id
var origin_position: Vector2:
	get:
		return _origin_position
var start_cell: Vector2i:
	get:
		return _start_cell
var direction: int:
	get:
		return _direction
var cells: Array[Vector2i]:
	get:
		return _cells.duplicate()

var _ability_id: StringName
var _origin_position: Vector2
var _start_cell: Vector2i
var _direction: int
var _cells: Array[Vector2i]


func _init(
	cast_ability_id: StringName,
	cast_origin_position: Vector2 = Vector2.ZERO,
	cast_start_cell: Vector2i = Vector2i.ZERO,
	cast_direction: int = 0,
	cast_cells: Array[Vector2i] = []
) -> void:
	_ability_id = cast_ability_id
	_origin_position = cast_origin_position
	_start_cell = cast_start_cell
	_direction = cast_direction
	_cells = cast_cells.duplicate()
